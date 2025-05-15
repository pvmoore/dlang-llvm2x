module test_create_module_from_src;

import llvm2x;
import std.stdio : writefln;

void testCreateModuleFromSource(LLVMContextWrapper llvmContext, LLVMTargetMachineRef targetMachine) {
    writefln("-----------------------------------------------------------");
    writefln("test create module from source");
    writefln("-----------------------------------------------------------");

    string source = q{;
        declare i32 @putchar(i32)

        define i32 @main() {
        entry:
            %putchar = call i32 @putchar(i32 48)
            ret i32 0
        }

    };

    LLVMModuleRef mod = createModuleFromSource(llvmContext.ctx, source);
    writefln("Created module %s", mod);

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

bool optimiseModule(LLVMModuleRef mod, LLVMTargetMachineRef targetMachine) {
    writefln("Optimising module");
    LLVMPassBuilderOptionsRef options = createPassOptions();
    if(LLVMErrorRef err = LLVMRunPasses(mod, "default<O3>", targetMachine, options)) {
        writefln("Optimisation failed: %s", LLVMGetErrorMessage(err).fromStringz());
        return false;
    }
    return true;
}

LLVMPassBuilderOptionsRef createPassOptions() {
    // New pass manager
    LLVMPassBuilderOptionsRef passBuilderOptions = LLVMCreatePassBuilderOptions();
    LLVMPassBuilderOptionsSetVerifyEach(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetDebugLogging(passBuilderOptions, 0);
    LLVMPassBuilderOptionsSetLoopInterleaving(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetLoopVectorization(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetSLPVectorization(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetLoopUnrolling(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetAAPipeline(passBuilderOptions, "?");
    //LLVMPassBuilderOptionsSetForgetAllSCEVInLoopUnrolling(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetLicmMssaOptCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetLicmMssaNoAccForPromotionCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetCallGraphProfile(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetMergeFunctions(passBuilderOptions, 0);
    //LLVMPassBuilderOptionsSetInlinerThreshold(passBuilderOptions, 25);
    return passBuilderOptions;
}
