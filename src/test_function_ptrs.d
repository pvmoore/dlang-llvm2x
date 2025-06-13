module test_function_ptrs;

import llvm2x;
import std.stdio : writefln;

void testFunctionPtrs(LLVMContextWrapper wrapper, LLVMTargetMachineRef targetMachine) {
    writefln("╔═══════════════════════════════════════════════════════════");
    writefln("║ Test function ptrs");
    writefln("╚═══════════════════════════════════════════════════════════");

    LLVMContextRef context = wrapper.ctx;
    LLVMBuilderRef builder = wrapper.builder;
    
    LLVMModuleRef mod = buildModule(wrapper);

    writefln("%s", mod.printModuleToString());

    if(string err = verifyModule(mod)) {
        writefln("Module verification failed: %s", err);
        return;
    }
    writefln("Module verified ok");

    writeModuleToFile(mod, targetMachine, LLVMCodeGenFileType.LLVMObjectFile, "test_function_ptrs.obj");

    msLink("test_function_ptrs", true, true);
}

LLVMModuleRef buildModule(LLVMContextWrapper wrapper) {
    LLVMContextRef context = wrapper.ctx;
    LLVMBuilderRef builder = wrapper.builder;
    
    LLVMModuleRef mod = LLVMModuleCreateWithNameInContext("test", context);

    // Add putchar function declaration
    LLVMTypeRef putcharType = LLVMFunctionType(wrapper.int32Type(), [wrapper.int32Type()]);
    LLVMValueRef putcharFunc = LLVMAddFunction(mod, "putchar", putcharType);
    LLVMSetLinkage(putcharFunc, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(putcharFunc, CallingConv.C);

    LLVMValueRef fooFunc = addFooFunction(wrapper, mod, putcharType, putcharFunc);
    
    LLVMValueRef mainValue = addMainFunction(wrapper, mod, fooFunc);

    return mod;
}

LLVMValueRef addMainFunction(LLVMContextWrapper wrapper, LLVMModuleRef mod, LLVMValueRef fooFunc) {

    LLVMContextRef context = wrapper.ctx;
    LLVMBuilderRef builder = wrapper.builder;

    LLVMTypeRef mainType = LLVMFunctionType(wrapper.int32Type(), [wrapper.int32Type()]);
    LLVMValueRef mainValue = LLVMAddFunction(mod, "main", mainType);
    LLVMSetLinkage(mainValue, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(mainValue, CallingConv.C);

    // Add the entry block
    LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(context, mainValue, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    // alloc a function ptr
    LLVMTypeRef fooType = LLVMFunctionType(wrapper.voidType(), [wrapper.int32Type()]);
    LLVMValueRef funcPtr = LLVMBuildAlloca(builder, LLVMPointerType(fooType, 0), "funcPtr");

    // Store foo() in the function ptr
    LLVMBuildStore(builder, fooFunc, funcPtr);

    // Call foo() though the function ptr
    LLVMValueRef funcPtrLoad = LLVMBuildLoad2(builder, LLVMPointerType(fooType, 0), funcPtr, "funcPtrLoad");
    LLVMBuildCall2(builder, fooType, funcPtrLoad, [LLVMConstInt(wrapper.int32Type(), 'A', 0)].ptr, 1, "");

    // Return 0
    LLVMBuildRet(builder, LLVMConstInt(wrapper.int32Type(), 0, 0));

    return mainValue;
}

LLVMValueRef addFooFunction(LLVMContextWrapper wrapper, LLVMModuleRef mod, LLVMTypeRef putcharType, LLVMValueRef putcharFunc) {
    // Add foo function
    LLVMTypeRef fooType = LLVMFunctionType(wrapper.voidType(), [wrapper.int32Type()]);
    LLVMValueRef fooFunc = LLVMAddFunction(mod, "foo", fooType);
    LLVMSetLinkage(fooFunc, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(fooFunc, CallingConv.C);

    // Add the entry block
    LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(wrapper.ctx, fooFunc, "entry");
    LLVMPositionBuilderAtEnd(wrapper.builder, entry);

    // Call putchar
    LLVMValueRef f = LLVMGetNamedFunction(mod, "putchar");
    // ptr 
    writefln("putchar.getNamedFunction() = %s, kind = %s", LLVMTypeOf(f).printTypeToString(), LLVMGetValueKind(f));

    writefln("               putcharType = %s, kind = %s", putcharType.printTypeToString(), LLVMGetValueKind(putcharFunc));

    LLVMBuildCall2(wrapper.builder, putcharType, putcharFunc, [LLVMConstInt(wrapper.int32Type(), 'Z', 0)].ptr, 1, "");

    // return
    LLVMBuildRetVoid(wrapper.builder);

    return fooFunc;
}
