module tests.jit.OrcV2DumpObjects;

/**
 * Conversion of the OrcV2CBindingsDumpObjects example from the LLVM project (LLVM 22.1.3)
 *
 * This will create a file named test_dumped_obj.o in the current directory
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_dumpObjects() {
    writefln("[OrcV2DumpObjects example]");

    // Delete an old dumped object file if it exists. This example will not overwrite an existing file
    // with the same name and we don't want lots of them in the current directory.
    import std.file : exists, remove;
    if(exists("test_dumped_obj.o")) {
        remove("test_dumped_obj.o");
    }

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

    // Create a DumpObjects instance to use when dumping objects to disk.
    LLVMOrcDumpObjectsRef DumpObjects = LLVMOrcCreateDumpObjects("", "test_dumped_obj"); // directory, prefix

    // Create the JIT instance.
    checkError(LLVMOrcCreateLLJIT(&J, null));

    // Set an object transform to call our DumpObjects instance for every
    // JIT'd object.
    LLVMOrcObjectTransformLayerSetTransform(LLVMOrcLLJITGetObjTransformLayer(J), &dumpObjectsTransform, &DumpObjects);

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

extern(C) {
    LLVMErrorRef dumpObjectsTransform(void *Ctx, LLVMMemoryBufferRef *ObjInOut) {
        writefln("... dump objects transform layer running ...");
        LLVMOrcDumpObjectsRef DumpObjects = *cast(LLVMOrcDumpObjectsRef *)Ctx;
        return LLVMOrcDumpObjects_CallOperator(DumpObjects, ObjInOut);
    }
}

LLVMOrcThreadSafeModuleRef createDemoModule() {
    LLVMContextRef Ctx = LLVMContextCreate();
    LLVMModuleRef M = LLVMModuleCreateWithNameInContext("demo", Ctx);
    LLVMTypeRef Int32Type = LLVMInt32TypeInContext(Ctx);
    LLVMTypeRef[] ParamTypes = [Int32Type, Int32Type];
    LLVMTypeRef SumFunctionType = LLVMFunctionType(Int32Type, ParamTypes);
    LLVMValueRef SumFunction = LLVMAddFunction(M, "sum", SumFunctionType);
    LLVMBasicBlockRef EntryBB = LLVMAppendBasicBlockInContext(Ctx, SumFunction, "entry");
    LLVMBuilderRef Builder = LLVMCreateBuilderInContext(Ctx);
    LLVMPositionBuilderAtEnd(Builder, EntryBB);
    LLVMValueRef SumArg0 = LLVMGetParam(SumFunction, 0);
    LLVMValueRef SumArg1 = LLVMGetParam(SumFunction, 1);
    LLVMValueRef Result = LLVMBuildAdd(Builder, SumArg0, SumArg1, "result");
    LLVMBuildRet(Builder, Result);
    LLVMOrcThreadSafeContextRef TSCtx = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);
    LLVMOrcThreadSafeModuleRef TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);
    LLVMOrcDisposeThreadSafeContext(TSCtx);
    return TSM;
}
