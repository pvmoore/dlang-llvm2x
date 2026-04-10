module tests.jit.OrcV2IRTransforms;

/**
 * Conversion of the OrcV2CBindingsIRTransforms example from the LLVM project (LLVM 22.1.3)
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_irTransforms() {
    writefln("[OrcV2IRTransforms example]");
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
    LLVMOrcDumpObjectsRef DumpObjects = LLVMOrcCreateDumpObjects("", "");

    // Create the JIT instance.
    checkError(LLVMOrcCreateLLJIT(&J, null));

    // Use TransformLayer to set IR transform.
    {
        LLVMOrcIRTransformLayerRef TL = LLVMOrcLLJITGetIRTransformLayer(J);
        LLVMOrcIRTransformLayerSetTransform(TL, &transform, null);
    }

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
    LLVMErrorRef myModuleTransform2(void *Ctx, LLVMModuleRef Mod) {
        writefln("... optimising layer running ...");
        LLVMPassBuilderOptionsRef Options = LLVMCreatePassBuilderOptions();
        LLVMErrorRef E = LLVMRunPasses(Mod, "instcombine", null, Options);
        LLVMDisposePassBuilderOptions(Options);
        return E;
    }
    LLVMErrorRef transform(void *Ctx, LLVMOrcThreadSafeModuleRef *ModInOut, LLVMOrcMaterializationResponsibilityRef MR) {
        writefln("... IR transform layer running ...");
        return LLVMOrcThreadSafeModuleWithModuleDo(*ModInOut, &myModuleTransform2, Ctx);
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
    LLVMDisposeBuilder(Builder);
    LLVMOrcThreadSafeContextRef TSCtx = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);
    LLVMOrcThreadSafeModuleRef TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);
    LLVMOrcDisposeThreadSafeContext(TSCtx);
    return TSM;
}
