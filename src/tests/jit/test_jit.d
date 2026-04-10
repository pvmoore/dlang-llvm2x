module tests.jit.test_jit;

import tests.test;
import llvm2x;

extern(C) {
    LLVMErrorRef myModuleTransform(void* Ctx, LLVMModuleRef mod) {
        writefln("... optimising ...");
        LLVMPassBuilderOptionsRef options = LLVMCreatePassBuilderOptions();
        LLVMErrorRef E = LLVMRunPasses(mod, "default<O3>", null, options);
        LLVMDisposePassBuilderOptions(options);
        return E;
    }
    /**
    * Object Tranform Layer function
    * Set via LLVMOrcObjectTransformLayerSetTransform
    */
    LLVMErrorRef objectTransformLayerFunc(void* Ctx, LLVMMemoryBufferRef* ObjInOut) {
        writefln("... object transform layer running ...");
        LLVMOrcDumpObjectsRef DumpObjects = *cast(LLVMOrcDumpObjectsRef*)Ctx;
        return LLVMOrcDumpObjects_CallOperator(DumpObjects, ObjInOut);
    }
    /**
    * IR Tranform Layer function
    * Set via LLVMOrcIRTransformLayerSetTransform
    */
    LLVMErrorRef irTransformLayerFunc(void *ctx, 
                                                LLVMOrcThreadSafeModuleRef* ModInOut,
                                                LLVMOrcMaterializationResponsibilityRef MR) 
    {
        writefln("... IR transform layer running ...");
        return LLVMOrcThreadSafeModuleWithModuleDo(*ModInOut, &myModuleTransform, ctx);
    }
    /**
     * Error reporting function
     * Set via LLVMOrcExecutionSessionSetErrorReporter function
     */
    void logJitError(void* ctx, LLVMErrorRef err) {
        writefln("JIT error = %s", LLVMGetErrorMessage(err).fromStringz());
    }
    LLVMOrcObjectLayerRef myObjectLinkingLayerCreator(void *Ctx, LLVMOrcExecutionSessionRef ES, const(char)* Triple) {
        return LLVMOrcCreateRTDyldObjectLinkingLayerWithSectionMemoryManager(ES);
    }
}
void testJitBasicUsage(LLVMTargetMachineRef targetMachine, bool dumpObjects, bool optimise) {
    // Create the jit
    LLVMOrcLLJITRef jit;
    LLVMOrcLLJITBuilderRef jitBuilder;
    static if(true) {
        // Create the jit using a builder
        jitBuilder = LLVMOrcCreateLLJITBuilder();
        LLVMOrcJITTargetMachineBuilderRef jitTargetMachineBuilder = LLVMOrcJITTargetMachineBuilderCreateFromTargetMachine(targetMachine);
        LLVMOrcLLJITBuilderSetJITTargetMachineBuilder(jitBuilder, jitTargetMachineBuilder);

        // Uncommenting this causes an error:
        //    Assertion failed: KV.second.getFlags() == I->second && "Resolving symbol with incorrect flags", 
        //    file C:\Temp\llvm-project\llvm\lib\ExecutionEngine\Orc\Core.cpp, line 2915
        //LLVMOrcLLJITBuilderSetObjectLinkingLayerCreator(jitBuilder, &myObjectLinkingLayerCreator, null);
    }
    checkError(LLVMOrcCreateLLJIT(&jit, jitBuilder));

    LLVMOrcJITDylibRef mainJITDylib = LLVMOrcLLJITGetMainJITDylib(jit);
    LLVMOrcExecutionSessionRef executionSession = LLVMOrcLLJITGetExecutionSession(jit);

    // Get a reference to the transform layers
    LLVMOrcObjectTransformLayerRef objectTransformLayer = LLVMOrcLLJITGetObjTransformLayer(jit);
    LLVMOrcIRTransformLayerRef irTransformLayer = LLVMOrcLLJITGetIRTransformLayer(jit);
    LLVMOrcObjectLayerRef objectLinkingLayer = LLVMOrcLLJITGetObjLinkingLayer(jit);
    char globalPrefixChar = LLVMOrcLLJITGetGlobalPrefix(jit);

    LLVMOrcExecutionSessionSetErrorReporter(executionSession, &logJitError, null);

    // Create definition generators
    {
        LLVMOrcDefinitionGeneratorRef pathDLSearchGenerator;
        //checkError(LLVMOrcCreateDynamicLibrarySearchGeneratorForPath(&pathDLSearchGenerator, "c:\\work\\llvm-20\\lib", globalPrefixChar, null, null));
        //LLVMOrcJITDylibAddGenerator(mainJITDylib, pathDLSearchGenerator);

        // LLVMOrcDefinitionGeneratorRef pathStaticLibSearchGenerator;
        // LLVMOrcCreateStaticLibrarySearchGeneratorForPath(&pathStaticSearchGenerator, "c:\\work\\llvm-20\\lib", null);
        // LLVMOrcJITDylibAddGenerator(mainJITDylib, pathStaticLibSearchGenerator);

        LLVMOrcDefinitionGeneratorRef processDLSearchGenerator;
        checkError(LLVMOrcCreateDynamicLibrarySearchGeneratorForProcess(&processDLSearchGenerator, globalPrefixChar, null, null));
        LLVMOrcJITDylibAddGenerator(mainJITDylib, processDLSearchGenerator);
    }
    
    if(optimise) {
        // Set the IR transform layer function
        LLVMOrcIRTransformLayerSetTransform(irTransformLayer, &irTransformLayerFunc, null);
    }

    if(dumpObjects) {
        // Set the object transform layer function
        LLVMOrcDumpObjectsRef orcDumpObjects = LLVMOrcCreateDumpObjects("", "obj");
        LLVMOrcObjectTransformLayerSetTransform(objectTransformLayer, &objectTransformLayerFunc, &orcDumpObjects);
    }

    // !! This does not work with LLVM 21. There should be a new way of accessing the
    // LLVMContextRef from a LLVMOrcThreadSafeContextRef but I don't know how to do it in the C API
    // (LLVM 21.1.0)

    // Create a thread safe context
    LLVMContextRef context = LLVMContextCreate();
    // LLVMOrcThreadSafeContextRef threadSafeContext = LLVMOrcCreateNewThreadSafeContext();
    LLVMOrcThreadSafeContextRef threadSafeContext = LLVMOrcCreateNewThreadSafeContextFromLLVMContext(context);
    
    // Create a module
    LLVMOrcThreadSafeModuleRef add1Module = createAdd1Module(context, threadSafeContext);
    LLVMModuleRef mul2Module = createMul2Module(context, threadSafeContext);

    writefln("Writing mul2Module to memory");

    // This crashes here. Sometimes with the message:
    //   LLVM ERROR: out of memory
    //   Allocation failed

    char* errorMsg;
    static if(true) {
        LLVMMemoryBufferRef mul2Mem;
        if(LLVMTargetMachineEmitToMemoryBuffer(
            targetMachine,
            mul2Module,
            LLVMCodeGenFileType.LLVMObjectFile,
            &errorMsg,
            &mul2Mem
        )) {
            writefln("Error writing module to memory: ", errorMsg.fromStringz());
        }
    } else {
        LLVMMemoryBufferRef mul2Mem = writeModuleToMemory(mul2Module, targetMachine, LLVMCodeGenFileType.LLVMObjectFile, errorMsg);
        writefln("1");
        if(mul2Mem is null) {
            writefln("Error writing module to memory: ", errorMsg.fromStringz());
        }
    }
    writefln("Disposing mul2Module");
    LLVMDisposeModule(mul2Module);

    writefln("Adding modules to jit");

    // Add a module to the jit
    checkError(LLVMOrcLLJITAddLLVMIRModule(jit, mainJITDylib, add1Module));

    // Add an object to the jit
    checkError(LLVMOrcLLJITAddObjectFile(jit, mainJITDylib, mul2Mem));


    // Lookup a function. This will trigger the transform layers
    auto add1Func = lookupFunction!(int function(int))(jit, "add1");

    auto mul2Func = lookupFunction!(int function(int))(jit, "mul2");

    writeln("add1(2) = ", add1Func(2));
    writeln("mul2(4) = ", mul2Func(4));

    LLVMOrcDisposeLLJIT(jit);
}

T lookupFunction(T)(LLVMOrcLLJITRef jit, string name) {
    LLVMOrcJITTargetAddress addr;
    checkError(LLVMOrcLLJITLookup(jit, &addr, name.toStringz()));
    return cast(T)addr;
}

void testJit(LLVMTargetMachineRef targetMachine) {
    writefln("-----------------------------------------------------------");
    writefln("test Jit");
    writefln("-----------------------------------------------------------");

    testJitBasicUsage(targetMachine, false, true);
/+
    LLVMOrcLLJITBuilderRef jitBuilder = LLVMOrcCreateLLJITBuilder();

    writefln("LLVMOrcLLJITBuilderRef = %s", jitBuilder);

    LLVMOrcJITTargetMachineBuilderRef jitTargetMachineBuilder = LLVMOrcJITTargetMachineBuilderCreateFromTargetMachine(targetMachine);
    writefln("LLVMOrcJITTargetMachineBuilderRef = %s", jitTargetMachineBuilder);

    LLVMOrcLLJITBuilderSetJITTargetMachineBuilder(jitBuilder, jitTargetMachineBuilder);

    LLVMOrcLLJITBuilderSetObjectLinkingLayerCreator(jitBuilder, &myObjectLinkingLayerCreator, null);


    LLVMOrcLLJITRef jit;
    checkError(LLVMOrcCreateLLJIT(&jit, jitBuilder));

    LLVMOrcExecutionSessionRef executionSession = LLVMOrcLLJITGetExecutionSession(jit);
    LLVMOrcJITDylibRef mainJITDylib = LLVMOrcLLJITGetMainJITDylib(jit);


    LLVMOrcExecutionSessionSetErrorReporter(executionSession, &logJitError, null);

    char globalPrefixChar = LLVMOrcLLJITGetGlobalPrefix(jit);
    writefln("globalPrefixChar = %s (%s)", globalPrefixChar, cast(int)globalPrefixChar);

    LLVMOrcDefinitionGeneratorRef dlSearchGenerator;
    //checkError(LLVMOrcCreateDynamicLibrarySearchGeneratorForPath(&dlSearchGenerator, "c:\\work\\llvm-20\\lib", globalPrefixChar, null, null));
    checkError(LLVMOrcCreateDynamicLibrarySearchGeneratorForProcess(&dlSearchGenerator, globalPrefixChar, null, null));


    LLVMOrcJITDylibAddGenerator(mainJITDylib, dlSearchGenerator);


    LLVMOrcThreadSafeContextRef threadSafeContext = LLVMOrcCreateNewThreadSafeContext();
    LLVMContextRef context = LLVMOrcThreadSafeContextGetContext(threadSafeContext);
    

    LLVMOrcThreadSafeModuleRef threadSafeModule = createAdd1Module(threadSafeContext);

    LLVMOrcObjectLayerRef objectLinkingLayer = LLVMOrcLLJITGetObjLinkingLayer(jit);
    LLVMOrcObjectTransformLayerRef objectTransformLayer = LLVMOrcLLJITGetObjTransformLayer(jit);
    LLVMOrcIRTransformLayerRef irTransformLayer = LLVMOrcLLJITGetIRTransformLayer(jit);


    LLVMOrcResourceTrackerRef resourceTracker = LLVMOrcJITDylibCreateResourceTracker(mainJITDylib);


    checkError(LLVMOrcLLJITAddLLVMIRModuleWithRT(jit, resourceTracker, threadSafeModule));
    //checkError(LLVMOrcLLJITAddLLVMIRModule(jit, mainJITDylib, threadSafeModule));

    LLVMOrcExecutorAddress addr;
    checkError(LLVMOrcLLJITLookup(jit, &addr, "add1"));

    writeln("addr = ", addr);
+/
}

/**
 * Create a module with an int add1(int) function that returns arg+1.
 */
LLVMOrcThreadSafeModuleRef createAdd1Module(LLVMContextRef context, LLVMOrcThreadSafeContextRef threadSafeContext) {
    //LLVMContextRef context = LLVMOrcThreadSafeContextGetContext(threadSafeContext);
    LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);
    
    auto mod = LLVMModuleCreateWithNameInContext("addModule", context);

    LLVMTypeRef funcType = LLVMFunctionType(LLVMInt32TypeInContext(context), [LLVMInt32TypeInContext(context)]);

    LLVMValueRef funcValue = LLVMAddFunction(mod, "add1", funcType);
    LLVMSetLinkage(funcValue, LLVMLinkage.LLVMExternalLinkage);

    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(funcValue, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    LLVMValueRef one = LLVMConstInt(LLVMInt32TypeInContext(context), 1, cast(LLVMBool)true);

    LLVMValueRef arg1 = LLVMGetFirstParam(funcValue);
    LLVMSetValueName2(arg1, "param1", 5);

    LLVMValueRef add = LLVMBuildAdd(builder, one, arg1, "add");

    LLVMBuildRet(builder, add);

    LLVMDisposeBuilder(builder);

    writefln("%s", mod.printModuleToString());

    return LLVMOrcCreateNewThreadSafeModule(mod, threadSafeContext);
}
/**
 * Create a module with a int mul2(int) function that returns arg*2.
 */
LLVMModuleRef createMul2Module(LLVMContextRef context, LLVMOrcThreadSafeContextRef threadSafeContext) {
    //LLVMContextRef context = LLVMOrcThreadSafeContextGetContext(threadSafeContext);
    LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);
    
    auto mod = LLVMModuleCreateWithNameInContext("mulModule", context);

    LLVMTypeRef funcType = LLVMFunctionType(LLVMInt32TypeInContext(context), [LLVMInt32TypeInContext(context)]);

    LLVMValueRef funcValue = LLVMAddFunction(mod, "mul2", funcType);
    LLVMSetLinkage(funcValue, LLVMLinkage.LLVMExternalLinkage);

    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(funcValue, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    LLVMValueRef two = LLVMConstInt(LLVMInt32TypeInContext(context), 2, cast(LLVMBool)true);

    LLVMValueRef arg1 = LLVMGetFirstParam(funcValue);
    LLVMSetValueName2(arg1, "param1", 5);

    LLVMValueRef mul = LLVMBuildMul(builder, two, arg1, "mul");

    LLVMBuildRet(builder, mul);

    LLVMDisposeBuilder(builder);

    writefln("%s", mod.printModuleToString());

    return mod;
}

