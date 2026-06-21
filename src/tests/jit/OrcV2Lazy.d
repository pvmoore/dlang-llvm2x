module tests.jit.OrcV2Lazy;

/**
 * Conversion of the OrcV2CBindingsLazy example from the LLVM project (LLVM 22.1.3)
 */

import llvm2x; 
import std.stdio : writefln;
import tests.test : checkError;

// This is equivalent to the 'main' method in the example
void jit_lazy() {
    writefln("[OrcV2Lazy example]");
    LLVMOrcLLJITRef J;

    scope(exit) {
        // Destroy our JIT instance. This will clean up any memory that the JIT has
        // taken ownership of. This operation is non-trivial (e.g. it may need to
        // JIT static destructors) and may also fail. In that case we want to render
        // the error to stderr, but not overwrite any existing return value.
        if(J) {

            // Note: in LLVM22.1.8 this asserts in debug mode. I am not sure if this was working better with earlier versions.    
            // Assertion failed: Pool.empty() && "Dangling references at pool destruction time", file C:\Temp\llvm-project\llvm\include\llvm/ExecutionEngine/Orc/SymbolStringPool.h, line 289

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

    // Set up a JIT instance.
    checkError(LLVMOrcCreateLLJIT(&J, null));

    const char *TargetTriple = LLVMOrcLLJITGetTripleString(J);
    writefln(" Target triple: %s", TargetTriple.fromStringz());

    // Add our demo modules to the JIT.
    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMErrorRef Err;

        LLVMOrcThreadSafeModuleRef FooTSM;
        checkError(parseExampleModule(FooMod, "foo-mod", &FooTSM));

        Err = LLVMOrcLLJITAddLLVMIRModule(J, MainJD, FooTSM);
        if(Err) {
            // If adding the ThreadSafeModule fails then we need to clean it up
            // ourselves. If adding it succeeds the JIT will manage the memory.
            LLVMOrcDisposeThreadSafeModule(FooTSM);
            checkError(Err);
        }

        LLVMOrcThreadSafeModuleRef BarTSM;
        checkError(parseExampleModule(BarMod, "bar-mod", &BarTSM));

        Err = LLVMOrcLLJITAddLLVMIRModule(J, MainJD, BarTSM);
        if(Err) {
            LLVMOrcDisposeThreadSafeModule(BarTSM);
            checkError(Err);
        }

        LLVMOrcThreadSafeModuleRef MainTSM;
        checkError(parseExampleModule(MainMod, "main-mod", &MainTSM));

        Err = LLVMOrcLLJITAddLLVMIRModule(J, MainJD, MainTSM);
        if(Err) {
            LLVMOrcDisposeThreadSafeModule(MainTSM);
            checkError(Err);
        }
    }

    // add lazy reexports
    LLVMOrcIndirectStubsManagerRef ISM = LLVMOrcCreateLocalIndirectStubsManager(TargetTriple);

    LLVMOrcLazyCallThroughManagerRef LCTM;
    {
        LLVMOrcExecutionSessionRef ES = LLVMOrcLLJITGetExecutionSession(J);
        LLVMErrorRef Err = LLVMOrcCreateLocalLazyCallThroughManager(TargetTriple, ES, 0, &LCTM);
        if(Err) {
            LLVMOrcDisposeIndirectStubsManager(ISM);
            checkError(Err);
        }
    }

    LLVMJITSymbolFlags flag = {
        GenericFlags: LLVMJITSymbolGenericFlags.LLVMJITSymbolGenericFlagsExported | LLVMJITSymbolGenericFlags.LLVMJITSymbolGenericFlagsCallable, 
        TargetFlags: 0
    };

    LLVMOrcCSymbolAliasMapPair[2] ReExports = [
        {LLVMOrcLLJITMangleAndIntern(J, "foo"),
        {LLVMOrcLLJITMangleAndIntern(J, "foo_body"), flag}},
        {LLVMOrcLLJITMangleAndIntern(J, "bar"),
        {LLVMOrcLLJITMangleAndIntern(J, "bar_body"), flag}},
    ];

    {
        LLVMOrcJITDylibRef MainJD = LLVMOrcLLJITGetMainJITDylib(J);
        LLVMOrcMaterializationUnitRef MU = LLVMOrcLazyReexports(LCTM, ISM, MainJD, ReExports.ptr, 2);
        LLVMOrcJITDylibDefine(MainJD, MU);
    }

    // Look up the address of our demo entry point.
    LLVMOrcJITTargetAddress EntryAddr;
    {
        checkError(LLVMOrcLLJITLookup(J, &EntryAddr, "entry"));
    }

    int argc = 7;

    // If we made it here then everything succeeded. Execute our JIT'd code.
    int function(int) Entry = cast(int function(int))EntryAddr;
    writefln(" Calling function");
    int Result = Entry(argc);

    writefln(" --- Result ---");
    writefln(" entry(%s) = %s", argc, Result);
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
                      "  entry:             \n"~
                      "    ret i32 1        \n"~
                      "  }                  \n";

string BarMod = "  define i32 @bar_body() { \n"~
                      "  entry:             \n"~
                      "    ret i32 2        \n"~
                      "  }                  \n";

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


LLVMErrorRef parseExampleModule(string Source, 
                                string Name,
                                LLVMOrcThreadSafeModuleRef *TSM) {

    writefln(" Parsing module '%s'", Name);                                

    // Create an LLVMContext for the Module.
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
    LLVMOrcThreadSafeContextRef TSCtx = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(Ctx);

    // Our module is now complete. Wrap it and our ThreadSafeContext in a
    // ThreadSafeModule.
    *TSM = LLVMOrcCreateNewThreadSafeModule(M, TSCtx);

    // Dispose of our local ThreadSafeContext value. The underlying LLVMContext
    // will be kept alive by our ThreadSafeModule, TSM.
    LLVMOrcDisposeThreadSafeContext(TSCtx);

    writefln("  Module '%s' parsed ok", Name.fromStringz());

    return null;
}
