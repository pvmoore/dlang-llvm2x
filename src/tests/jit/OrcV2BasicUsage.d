module tests.jit.OrcV2BasicUsage;

/**
 * Conversion of the OrcV2CBindingsBasicUsage example from the LLVM project (LLVM 22.1.3)
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_basicUsage() {
    writefln("[OrcV2BasicUsage example]");
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

    // Create our demo module.
    LLVMOrcThreadSafeModuleRef TSM = createDemoModule();

    // Add our demo module to the JIT.
    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMErrorRef Err = LLVMOrcLLJITAddLLVMIRModule(J, MainJD, TSM);
        if(Err) {
            // If adding the ThreadSafeModule fails then we need to clean it up
            // ourselves. If adding it succeeds the JIT will manage the memory.
            LLVMOrcDisposeThreadSafeModule(TSM);

            // This will throw an exception with the error message
            checkError(Err);
        }
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


LLVMOrcThreadSafeModuleRef createDemoModule() {
    // Create an LLVMContext.
    LLVMContextRef Ctx = LLVMContextCreate();

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

    // Create a new ThreadSafeContext to hold the context.
    LLVMOrcThreadSafeContextRef TSCtx = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);

    // Our demo module is now complete. Wrap it and our ThreadSafeContext in a
    // ThreadSafeModule.
    LLVMOrcThreadSafeModuleRef TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);

    // Dispose of our local ThreadSafeContext value. The underlying LLVMContext
    // will be kept alive by our ThreadSafeModule, TSM.
    LLVMOrcDisposeThreadSafeContext(TSCtx);

    // Return the result.
    return TSM;
}
