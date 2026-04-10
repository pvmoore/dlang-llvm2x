module tests.jit.OrcV2AddObjectFile;

/**
 * Conversion of the OrcV2CBindingsAddObjectFile example from the LLVM project (LLVM 22.1.3)
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_addObjectFile() {
    writefln("[OrcV2AddObjectFile example]");
    LLVMOrcLLJITRef J;

    scope(exit) {
        // Destroy our JIT instance. This will clean up any memory that the JIT has
        // taken ownership of. This operation is non-trivial (e.g. it may need to
        // JIT static destructors) and may also fail. In that case we want to render
        // the error to stderr, but not overwrite any existing return value.
        if(J) {
            checkError(LLVMOrcDisposeLLJIT(J));
        }

        // Shut down LLVM.
        LLVMShutdown();
    }

    // Initialize native target codegen and asm printer.
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    // Create the JIT instance.
    checkError(LLVMOrcCreateLLJIT(&J, null));

    // Create our demo object file.
    LLVMMemoryBufferRef ObjectFileBuffer;
    {
        // Create a module.
        LLVMContextRef Ctx = LLVMContextCreate();
        LLVMModuleRef M = createDemoModule(Ctx);

        // Get the Target.
        const char* Triple = LLVMOrcLLJITGetTripleString(J);
        LLVMTargetRef Target;
        char *ErrorMsg;

        if(LLVMGetTargetFromTriple(Triple, &Target, &ErrorMsg)) {
            writefln("Error getting target for %s: %s", Triple.fromStringz(), ErrorMsg.fromStringz());
            LLVMDisposeModule(M);
            LLVMContextDispose(Ctx);
            return;
        }

        // Construct a TargetMachine.
        LLVMTargetMachineRef TM = LLVMCreateTargetMachine(Target, 
                                                          Triple, 
                                                          "",       // CPU 
                                                          "",       // features
                                                          LLVMCodeGenOptLevel.LLVMCodeGenLevelNone,
                                                          LLVMRelocMode.LLVMRelocDefault, 
                                                          LLVMCodeModel.LLVMCodeModelDefault);

        // Run CodeGen to produce the buffer.
        if(LLVMTargetMachineEmitToMemoryBuffer(TM, M, LLVMCodeGenFileType.LLVMObjectFile, &ErrorMsg, &ObjectFileBuffer)) {
            writefln("Error emitting object: %s", ErrorMsg.fromStringz());
            LLVMDisposeTargetMachine(TM);
            LLVMDisposeModule(M);
            LLVMContextDispose(Ctx);
            return;
        }

        // CodeGen succeeded -- We have our module, so free the Module, LLVMContext,
        // and TargetMachine.
        LLVMDisposeModule(M);
        LLVMContextDispose(Ctx);
        LLVMDisposeTargetMachine(TM);
    }

    // Add our object file buffer to the JIT.
    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        checkError(LLVMOrcLLJITAddObjectFile(J, MainJD, ObjectFileBuffer));
    }

    // Look up the address of our demo entry point.
    LLVMOrcJITTargetAddress SumAddr;
    checkError(LLVMOrcLLJITLookup(J, &SumAddr, "sum"));

    // If we made it here then everything succeeded. Execute our JIT'd code.
    int function(int, int) Sum = cast(int function(int, int))(SumAddr);
    int Result = Sum(1, 2);

    // Print the result.
    writefln(" 1 + 2 = %s", Result);
}

private:

LLVMModuleRef createDemoModule(LLVMContextRef Ctx) {
    // Create a new LLVM module.
    LLVMModuleRef M = LLVMModuleCreateWithNameInContext("demo", Ctx);

    // Add a "sum" function":
    //  - Create the function type and function instance.
    LLVMTypeRef Int32Type = LLVMInt32TypeInContext(Ctx);
    LLVMTypeRef[] ParamTypes = [Int32Type, Int32Type];
    LLVMTypeRef SumFunctionType = LLVMFunctionType(Int32Type, ParamTypes);

    LLVMValueRef SumFunction = LLVMAddFunction(M, "sum", SumFunctionType);
    //  - Add a basic block to the function.
    LLVMBasicBlockRef EntryBB = LLVMAppendBasicBlockInContext(Ctx, SumFunction, "entry");

    //  - Add an IR builder and point it at the end of the basic block.
    LLVMBuilderRef Builder = LLVMCreateBuilderInContext(Ctx);
    LLVMPositionBuilderAtEnd(Builder, EntryBB);

    //  - Get the two function arguments and use them co construct an "add"
    //    instruction.
    LLVMValueRef SumArg0 = LLVMGetParam(SumFunction, 0);
    LLVMValueRef SumArg1 = LLVMGetParam(SumFunction, 1);
    LLVMValueRef Result = LLVMBuildAdd(Builder, SumArg0, SumArg1, "result");

    //  - Build the return instruction.
    LLVMBuildRet(Builder, Result);

    //  - Free the builder.
    LLVMDisposeBuilder(Builder);

    return M;
}
