module tests.jit.OrcV2VeryLazy;

/**
 * Conversion of the OrcV2CBindingsVeryLazy example from the LLVM project (LLVM 22.1.3)
 *
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_veryLazy() {
    writefln("[OrcV2VeryLazy example]");
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

    // Set up a JIT instance.
    checkError(LLVMOrcCreateLLJIT(&J, null));
    const char* TargetTriple = LLVMOrcLLJITGetTripleString(J);;

    // Add our main module to the JIT.
    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMErrorRef Err;

        LLVMOrcThreadSafeModuleRef MainTSM;
        checkError(parseExampleModule(MainMod, "main-mod", &MainTSM));

        Err = LLVMOrcLLJITAddLLVMIRModule(J, MainJD, MainTSM);
        if(Err) {
            LLVMOrcDisposeThreadSafeModule(MainTSM);
            checkError(Err);
        }
    }

    LLVMJITSymbolFlags Flags = {
        LLVMJITSymbolGenericFlags.LLVMJITSymbolGenericFlagsExported | LLVMJITSymbolGenericFlags.LLVMJITSymbolGenericFlagsCallable, 0
    };
    LLVMOrcCSymbolFlagsMapPair FooSym = {
        LLVMOrcLLJITMangleAndIntern(J, "foo_body"), Flags
    };
    LLVMOrcCSymbolFlagsMapPair BarSym = {
        LLVMOrcLLJITMangleAndIntern(J, "bar_body"), Flags
    };

    
    // add custom MaterializationUnit
    {
        LLVMOrcMaterializationUnitRef FooMU =
            LLVMOrcCreateCustomMaterializationUnit("FooMU", J, &FooSym, 1, null, &Materialize, null, &Destroy);

        LLVMOrcMaterializationUnitRef BarMU =
            LLVMOrcCreateCustomMaterializationUnit("BarMU", J, &BarSym, 1, null, &Materialize, null, &Destroy);

        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMOrcJITDylibDefine(MainJD, FooMU);
        LLVMOrcJITDylibDefine(MainJD, BarMU);
    }

    LLVMOrcIndirectStubsManagerRef ISM;
    LLVMOrcLazyCallThroughManagerRef LCTM;

    scope(exit) {
        LLVMOrcDisposeIndirectStubsManager(ISM);
        LLVMOrcDisposeLazyCallThroughManager(LCTM);
    }

    // add lazy reexports
    ISM = LLVMOrcCreateLocalIndirectStubsManager(TargetTriple);
    {
        LLVMOrcExecutionSessionRef ES = LLVMOrcLLJITGetExecutionSession(J);
        LLVMErrorRef Err = LLVMOrcCreateLocalLazyCallThroughManager(TargetTriple, ES, 0, &LCTM);
        if(Err) {
            LLVMOrcDisposeIndirectStubsManager(ISM);
            checkError(Err);
        }
    }

    LLVMOrcCSymbolAliasMapPair[2] ReExports = [
        {LLVMOrcLLJITMangleAndIntern(J, "foo"),
        {LLVMOrcLLJITMangleAndIntern(J, "foo_body"), Flags}},
        {LLVMOrcLLJITMangleAndIntern(J, "bar"),
        {LLVMOrcLLJITMangleAndIntern(J, "bar_body"), Flags}},
    ];

    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMOrcMaterializationUnitRef MU = LLVMOrcLazyReexports(LCTM, ISM, MainJD, ReExports.ptr, 2);
        LLVMOrcJITDylibDefine(MainJD, MU);
    }

    // Look up the address of our demo entry point.
    LLVMOrcJITTargetAddress EntryAddr;
    checkError(LLVMOrcLLJITLookup(J, &EntryAddr, "entry"));

    
    // If we made it here then everything succeeded. Execute our JIT'd code.
    // int32_t (*Entry)(int32_t) = (int32_t(*)(int32_t))EntryAddr;
    int argc = 7;
    int function(int) Entry = cast(int function(int))EntryAddr;
    int Result = Entry(argc);

    writefln("--- Result ---");
    writefln("entry(%s) = %s", argc, Result);
}

private:

// Example IR modules.
//
// Note that in the conditionally compiled modules, FooMod and BarMod, functions
// have been given an _body suffix. This is to ensure that their names do not
// clash with their lazy-reexports.
// For clients who do not wish to rename function bodies (e.g. because they want
// to re-use cached objects between static and JIT compiles) techniques exist to
// avoid renaming. See the lazy-reexports section of the ORCv2 design doc.

string FooMod = "  define i32 @foo_body() { \n"~
                "  entry:                   \n"~
                "    ret i32 1              \n"~
                "  }                        \n";

string BarMod = "  define i32 @bar_body() { \n"~
                "  entry:                   \n"~
                "    ret i32 2              \n"~
                "  }                        \n";

string MainMod =
    "  define i32 @entry(i32 %argc) {                                 \n"~
    "  entry:                                                         \n"~
    "    %and = and i32 %argc, 1                                      \n"~
    "    %tobool = icmp eq i32 %and, 0                                \n"~
    "    br i1 %tobool, label %if.end, label %if.then                 \n"~
    "                                                                 \n"~
    "  if.then:                                                       \n"~
    "    %call = tail call i32 @foo()                                 \n"~
    "    br label %return                                             \n"~
    "                                                                 \n"~
    "  if.end:                                                        \n"~
    "    %call1 = tail call i32 @bar()                                \n"~
    "    br label %return                                             \n"~
    "                                                                 \n"~
    "  return:                                                        \n"~
    "    %retval.0 = phi i32 [ %call, %if.then ], [ %call1, %if.end ] \n"~
    "    ret i32 %retval.0                                            \n"~
    "  }                                                              \n"~
    "                                                                 \n"~
    "  declare i32 @foo()                                             \n"~
    "  declare i32 @bar()                                             \n";

enum LLVMErrorSuccess = null;

extern(C) {
    LLVMErrorRef applyDataLayout(void *Ctx, LLVMModuleRef M) {
        LLVMSetDataLayout(M, LLVMOrcLLJITGetDataLayoutStr(cast(LLVMOrcLLJITRef)Ctx));
        return LLVMErrorSuccess;
    }
    
    void Destroy(void *Ctx) {}


    void Materialize(void *Ctx, LLVMOrcMaterializationResponsibilityRef MR) {

        int MainResult = 1;
        LLVMOrcSymbolStringPoolEntryRef FooBody;
        LLVMOrcSymbolStringPoolEntryRef BarBody;
        LLVMOrcSymbolStringPoolEntryRef* Symbols;
        LLVMOrcThreadSafeModuleRef TSM;
        LLVMOrcLLJITRef J = cast(LLVMOrcLLJITRef)Ctx;

        scope(exit) {
            LLVMOrcReleaseSymbolStringPoolEntry(BarBody);
            LLVMOrcReleaseSymbolStringPoolEntry(FooBody);
            LLVMOrcDisposeSymbols(Symbols);
            if (MainResult == 1) {
                LLVMOrcMaterializationResponsibilityFailMaterialization(MR);
                LLVMOrcDisposeMaterializationResponsibility(MR);
            } else {
                LLVMOrcIRTransformLayerRef IRLayer = LLVMOrcLLJITGetIRTransformLayer(J);
                LLVMOrcIRTransformLayerEmit(IRLayer, MR, TSM);
            }
        }

        size_t NumSymbols;
        Symbols = LLVMOrcMaterializationResponsibilityGetRequestedSymbols(MR, &NumSymbols);

        assert(NumSymbols == 1);

        LLVMOrcSymbolStringPoolEntryRef Sym = Symbols[0];

        FooBody = LLVMOrcLLJITMangleAndIntern(J, "foo_body");
        BarBody = LLVMOrcLLJITMangleAndIntern(J, "bar_body");

        if(Sym == FooBody) {
            checkError(parseExampleModule(FooMod, "foo-mod", &TSM));
        } else if (Sym == BarBody) {
            checkError(parseExampleModule(BarMod, "bar-mod", &TSM));
        } else {
            assert(false, "We shouldn't get here");
        }
        assert(TSM);

        checkError(LLVMOrcThreadSafeModuleWithModuleDo(TSM, &applyDataLayout, Ctx));

        // Success
        MainResult = 0;
    }
}


LLVMErrorRef parseExampleModule(string Source, 
                                string Name,
                                LLVMOrcThreadSafeModuleRef* TSM) {
    // Create an LLVMContext.
    LLVMContextRef Ctx = LLVMContextCreate();

    // Parse the LLVM module.
    LLVMModuleRef M;
    char *ErrMsg;
    // Wrap Source in a MemoryBuffer.
    LLVMMemoryBufferRef MB = LLVMCreateMemoryBufferWithMemoryRange(Source.ptr, Source.length, Name.ptr, 0);
    LLVMBool Ret = LLVMParseIRInContext2(Ctx, MB, &M, &ErrMsg);
    LLVMDisposeMemoryBuffer(MB);

    if(Ret) {
        LLVMErrorRef Err = LLVMCreateStringError(ErrMsg);
        LLVMDisposeMessage(ErrMsg);
        return Err;
    }

    // Create a new ThreadSafeContext to hold the context.
    LLVMOrcThreadSafeContextRef TSCtx =
        LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);

    // Our module is now complete. Wrap it and our ThreadSafeContext in a
    // ThreadSafeModule.
    *TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);

    // Dispose of our local ThreadSafeContext value. The underlying LLVMContext
    // will be kept alive by our ThreadSafeModule, TSM.
    LLVMOrcDisposeThreadSafeContext(TSCtx);

    return LLVMErrorSuccess;
}

