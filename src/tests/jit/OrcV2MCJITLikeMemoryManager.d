module tests.jit.OrcV2MCJITLikeMemoryManager;

/**
 * Conversion of the OrcV2CBindingsMCJITLikeMemoryManager example from the LLVM project (LLVM 22.1.3)
 *
 * 'This demo illustrates the C-API bindings for custom memory managers in
 * ORCv2. They are used here to place generated code into manually allocated
 * buffers that are subsequently marked as executable.'
 *
 * Note that this asserts on Windows in debug mode:
 * Assertion failed: KV.second.getFlags() == I->second && "Resolving symbol with incorrect flags", file C:\Temp\llvm-project\llvm\lib\ExecutionEngine\Orc\Core.cpp, line 2803
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_mcjitLikeMemoryManager() {
    writefln("[OrcV2MCJITLikeMemoryManager example]");
    LLVMOrcLLJITRef J;

    scope(exit) {
        // Destroy our JIT instance. This will clean up any memory that the JIT has
        // taken ownership of. This operation is non-trivial (e.g. it may need to
        // JIT static destructors) and may also fail. In that case we want to render
        // the error to stderr, but not overwrite any existing return value.
        if(J) {
            writefln("Disposing JIT instance");
            checkError(LLVMOrcDisposeLLJIT(J));
        }

        // Shut down LLVM.
        writefln("Shutting down");
        LLVMShutdown();
    }

    // Initialize native target codegen and asm printer.
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();

    // Create the JIT instance.
    {
        LLVMOrcLLJITBuilderRef Builder = LLVMOrcCreateLLJITBuilder();
        LLVMOrcLLJITBuilderSetObjectLinkingLayerCreator(Builder, &objectLinkingLayerCreator, null);
        checkError(LLVMOrcCreateLLJIT(&J, Builder));
    }

    // Create our demo module.
    LLVMOrcThreadSafeModuleRef TSM = createDemoModule();

    // Add our demo module to the JIT.
    {
        writefln(" Adding module to the JIT");
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
    writefln(" Looking up function");
    LLVMOrcJITTargetAddress SumAddr;
    checkError(LLVMOrcLLJITLookup(J, &SumAddr, "sum"));

    writefln(" Executing function");

    // If we made it here then everything succeeded. Execute our JIT'd code.
    // int32_t (*Sum)(int32_t, int32_t) = (int32_t(*)(int32_t, int32_t))SumAddr;
    int function(int, int) Sum = cast(int function(int, int))SumAddr;
    int Result = Sum(1, 2);

    // Print the result.
    writefln("1 + 2 = %s", Result);
}

private:

struct Section {
    void *Ptr;
    size_t Size;
    LLVMBool IsCode;
}

byte CtxCtxPlaceholder;
byte CtxPlaceholder;

enum MaxSections = 16;
size_t SectionCount;
Section[MaxSections] Sections;

void* addSection(size_t Size, LLVMBool IsCode) {
    if(SectionCount >= MaxSections) {
        throw new Exception("addSection(): Too many sections!");
    }

version(Win64) {
    import core.sys.windows.windows;
    void* Ptr = VirtualAlloc(NULL, Size, MEM_RESERVE | MEM_COMMIT, PAGE_READWRITE);
    if(!Ptr) {
        throw new Exception("addSection(): Memory allocation failed!");
    }
} else {
    // void* Ptr = mmap(NULL, Size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    // if(Ptr == MAP_FAILED) {
    //     throw new Exception("addSection(): Memory allocation failed!\n");
    // }
}

    Sections[SectionCount].Ptr = Ptr;
    Sections[SectionCount].Size = Size;
    Sections[SectionCount].IsCode = IsCode;
    SectionCount++;
    return Ptr;
}


LLVMOrcThreadSafeModuleRef createDemoModule() {
    writefln(" Creating demo module");
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
    LLVMBasicBlockRef EntryBB =
        LLVMAppendBasicBlockInContext(Ctx, SumFunction, "entry");

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

    // Create a new ThreadSafeContext to hold the context.
    LLVMOrcThreadSafeContextRef TSCtx =
        LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);

    // Our demo module is now complete. Wrap it and our ThreadSafeContext in a
    // ThreadSafeModule.
    LLVMOrcThreadSafeModuleRef TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);

    // Dispose of our local ThreadSafeContext value. The underlying LLVMContext
    // will be kept alive by our ThreadSafeModule, TSM.
    LLVMOrcDisposeThreadSafeContext(TSCtx);

    // Return the result.
    return TSM;
}

extern(C) {

    LLVMOrcObjectLayerRef objectLinkingLayerCreator(void *Opaque,
                                                    LLVMOrcExecutionSessionRef ES,
                                                    const char* Triple) 
    {
        return LLVMOrcCreateRTDyldObjectLinkingLayerWithMCJITMemoryManagerLikeCallbacks(
            ES, &CtxCtxPlaceholder, &memCreateContext, &memNotifyTerminating,
            &memAllocate, &memAllocateData, &memFinalize, &memDestroy);
    }

    // Callbacks to create the context for the subsequent functions (not used in this example)
    void* memCreateContext(void *CtxCtx) {
        assert(CtxCtx == &CtxCtxPlaceholder, "Unexpected CtxCtx value");
        return &CtxPlaceholder;
    }

    void memNotifyTerminating(void *CtxCtx) {
        assert(CtxCtx == &CtxCtxPlaceholder, "Unexpected CtxCtx value");
    }

    ubyte* memAllocate(void *Opaque, uintptr_t Size, uint Align, uint Id, const char* Name) {
        writefln("Allocated code section \"%s\"", Name.fromStringz());
        return cast(ubyte*)addSection(Size, 1);
    }

    ubyte* memAllocateData(void *Opaque, uintptr_t Size, uint Align, uint Id, const char* Name, LLVMBool ReadOnly) {
        writefln("Allocated data section \"%s\"", Name.fromStringz());
        return cast(ubyte*)addSection(Size, 0);
    }

    LLVMBool memFinalize(void* Opaque, char** Err) {
        writefln("Marking code sections as executable ..");
        for(size_t i = 0; i < SectionCount; ++i) {
            if (Sections[i].IsCode) {
                LLVMBool fail;
    version(Win64) {
                import core.sys.windows.windows;
                DWORD unused;
                fail = VirtualProtect(Sections[i].Ptr, Sections[i].Size, PAGE_EXECUTE_READ, &unused) == 0;
    } else {
                // fail = mprotect(Sections[i].Ptr, Sections[i].Size, PROT_READ | PROT_EXEC) == -1;
    }
                if(fail) {
                    throw new Exception("Could not mark code section as executable!");
                }
            }
        }
        return 0;
    }

    void memDestroy(void* Opaque) {
        assert(Opaque == &CtxPlaceholder, "Unexpected Ctx value");
        writefln("Releasing section memory ..");
        for(size_t i = 0; i < SectionCount; ++i) {
            LLVMBool fail;
    version(Win64) {
            import core.sys.windows.windows;
            fail = VirtualFree(Sections[i].Ptr, 0, MEM_RELEASE) == 0;
    } else {
            //fail = munmap(Sections[i].Ptr, Sections[i].Size) == -1;
    }
            if(fail) {
                throw new Exception("Could not release memory for section!");
            }
        }
    }

} // extern(C)
