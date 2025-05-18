module test_create_module_from_src;

import llvm2x;
import std.stdio : writefln;

void testCreateModuleFromSource(LLVMContextWrapper llvmContext, LLVMTargetMachineRef targetMachine) {
    writefln("-----------------------------------------------------------");
    writefln("test create module from source");
    writefln("-----------------------------------------------------------");

    string source2 = q{;
        declare i32 @putchar(i32)

        define i32 @main() {
        entry:
            %putchar = call i32 @putchar(i32 48)
            ret i32 0
        }
    };

    string source = q{;
        declare i32 @putchar(i32)

        define void @fakeAssert(i32 %0) {
        entry:
            %"==" = icmp eq i32 %0, 0
            br i1 %"==", label %then, label %else

        then:                                             ; preds = %entry
            %putchar = call i32 @putchar(i32 109)
            br label %endif

        endif:                                            ; preds = %then, %else
            ret void

        else:                                             ; preds = %entry
            br label %endif
            }

        define i32 @main() {
            entry:
                call void @fakeAssert(i32 1)
                ret i32 0
        }
    };

    static if(true) {
        LLVMModuleRef mod = createModuleFromBC(llvmContext.ctx, "bug.bc");
    } else {
        LLVMModuleRef mod = createModuleFromSource(llvmContext.ctx, source);
    }

    writefln("Created module %s", mod);

    {   
        writefln("Verifying module ...");
        char* msgs;
        if(LLVMVerifyModule(mod, LLVMVerifierFailureAction.LLVMPrintMessageAction, &msgs)) {
            writefln("Module verification failed: %s", msgs.fromStringz());
            LLVMDisposeMessage(msgs);
            return;
        }
        writefln("Module verified ok");
    }

    writefln("----------------------------------------------------------------- raw");
    writefln("%s", mod.printModuleToString());
    writefln("");

    optimiseModule(mod, targetMachine);

    writefln("---------------------------------------------------------------- optimised");
    writefln("%s", mod.printModuleToString());
    writefln("");

    char* errStr;
    LLVMSetTargetMachineAsmVerbosity(targetMachine, 1);
    //LLVMSetTargetMachineFastISel(targetMachine, 1);
    LLVMSetTargetMachineMachineOutliner(targetMachine, 1); // Enable the MachineOutliner pass

    // Enabling this causes a translation error which may be an LLVM bug?
    //LLVMSetTargetMachineGlobalISel(targetMachine, 1);

    LLVMMemoryBufferRef asmBuf = writeModuleToMemory(mod, targetMachine, LLVMCodeGenFileType.LLVMAssemblyFile, errStr);

    if(asmBuf is null) {
        writefln("Error writing module to memory: %s", errStr.fromStringz());
    } else {
        auto size = LLVMGetBufferSize(asmBuf);
        auto ptr = LLVMGetBufferStart(asmBuf);
        string str = ptr[0..size].idup;
        LLVMDisposeMemoryBuffer(asmBuf);
        writefln("---------------------------------------------------------------- assembly");
        writefln("%s", str);
    }   
}

private:

LLVMModuleRef createModuleFromSource(LLVMContextRef context, string source) {
    LLVMMemoryBufferRef buffer = LLVMCreateMemoryBufferWithMemoryRange(source.toStringz(), source.length, "Name", 0);

    // Parse the LLVM module.
    LLVMModuleRef mod;
    char *ErrMsg;

    writefln("Parsing module source");
    if(LLVMParseIRInContext(context, buffer, &mod, &ErrMsg)) {
        // LLVMErrorRef err = LLVMCreateStringError(ErrMsg);
        // string msg = LLVMGetErrorMessage(err).fromStringz();

        writefln("Error parsing module: %s", ErrMsg.fromStringz());
        LLVMDisposeMessage(ErrMsg);
    } else {
        writefln("Module parsed ok");
    }
    return mod;
}

LLVMModuleRef createModuleFromBC(LLVMContextRef context, string filename) {
    writefln("Parsing module from BC file: %s", filename);
    LLVMModuleRef mod;
    
    LLVMMemoryBufferRef buffer;
    if(LLVMCreateMemoryBufferWithContentsOfFile(filename.toStringz(), &buffer, null)) {
        writefln("Error creating memory buffer from file: %s", filename);
        return null;
    }

    LLVMBool res = LLVMParseBitcodeInContext2(context, buffer, &mod);
    if(res!=0) {
        writefln("Error parsing module: %s", filename);
        return null;
    } else {
        writefln("Module parsed ok");
    }

    return mod;
}

bool optimiseModule(LLVMModuleRef mod, LLVMTargetMachineRef targetMachine) {
    writefln("Optimising module");
    LLVMPassBuilderOptionsRef options = createPassOptions();
    if(LLVMErrorRef err = LLVMRunPasses(mod, "default<O3>", targetMachine, options)) {
        writefln("Optimisation failed: %s", LLVMGetErrorMessage(err).fromStringz());
        return false;
    }
    LLVMDisposePassBuilderOptions(options);
    writefln("Optimisation ok");
    return true;
}

LLVMPassBuilderOptionsRef createPassOptions() {
    // New pass manager
    LLVMPassBuilderOptionsRef passBuilderOptions = LLVMCreatePassBuilderOptions();
    // Toggle debug logging when running the PassBuilder. 
    LLVMPassBuilderOptionsSetDebugLogging(passBuilderOptions, 0);

    // Enable/disable loop interleaving
    LLVMPassBuilderOptionsSetLoopInterleaving(passBuilderOptions, 1);

    // Enable/disable loop vectorization
    LLVMPassBuilderOptionsSetLoopVectorization(passBuilderOptions, 1);

    // Enable/disable slp loop vectorization
    LLVMPassBuilderOptionsSetSLPVectorization(passBuilderOptions, 1);

    // Enable/disable loop unrollin
    LLVMPassBuilderOptionsSetLoopUnrolling(passBuilderOptions, 1);

    // I think this is a code size optimisation :: https://llvm.org/docs/MergeFunctions.html
    LLVMPassBuilderOptionsSetMergeFunctions(passBuilderOptions, 1);

    // Toggle adding the VerifierPass for the PassBuilder, ensuring all functions inside the module is valid. 
    LLVMPassBuilderOptionsSetVerifyEach(passBuilderOptions, 1);
    
    // Other options that could be useful but I don't know enough about them
    //LLVMPassBuilderOptionsSetAAPipeline(passBuilderOptions, "?");
    //LLVMPassBuilderOptionsSetForgetAllSCEVInLoopUnrolling(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetLicmMssaOptCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetLicmMssaNoAccForPromotionCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetCallGraphProfile(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetInlinerThreshold(passBuilderOptions, 25);

    return passBuilderOptions;
}
