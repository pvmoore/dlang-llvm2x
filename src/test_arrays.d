module test_arrays;

import llvm2x;
import std.stdio : writefln;

void testArrays(LLVMContextWrapper wrapper, LLVMTargetMachineRef targetMachine) {
    writefln("╔═══════════════════════════════════════════════════════════");
    writefln("║ Test arrays");
    writefln("╚═══════════════════════════════════════════════════════════");

    LLVMContextRef context = wrapper.ctx;
    LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);

    LLVMModuleRef mod = LLVMModuleCreateWithNameInContext("test", context);

    // Create main function
    LLVMTypeRef mainType = LLVMFunctionType(LLVMInt32TypeInContext(context), []);
    LLVMValueRef mainValue = LLVMAddFunction(mod, "main", mainType);
    LLVMSetLinkage(mainValue, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(mainValue, CallingConv.C);

    // Entry block
    LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(context, mainValue, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    LLVMTypeRef elementType = wrapper.int32Type();

    // Create an array of 2 ints
    LLVMValueRef array = LLVMBuildAlloca(builder, LLVMArrayType(elementType, 2), "array");

    // Create element 0
    LLVMValueRef element0 = LLVMBuildAlloca(builder, elementType, "element0");
    LLVMBuildStore(builder, LLVMConstInt(elementType, 1, 0), element0);

    // Create element 1
    LLVMValueRef element1 = LLVMBuildAlloca(builder, elementType, "element1");
    LLVMBuildStore(builder, LLVMConstInt(elementType, 2, 0), element1);

    LLVMValueRef load0 = LLVMBuildLoad2(builder, elementType, element0, "load0");
    LLVMValueRef load1 = LLVMBuildLoad2(builder, elementType, element1, "load1");

    writefln("%s", mod.printModuleToString());

    writefln("isConst(load0) = %s", LLVMIsConstant(load0));
    writefln("isConst(load1) = %s", LLVMIsConstant(load1));

    // Create an array literal to hold the elements
    LLVMValueRef arrayLiteral = LLVMBuildAlloca(builder, LLVMArrayType(elementType, 2), "arrayLiteral");

    // Store the elements in the array literal
    LLVMBuildStore(builder, load0, arrayLiteral);
    LLVMBuildStore(builder, load1, arrayLiteral);

    // Store the array literal to the array
    LLVMValueRef arrayLiteralValue = LLVMBuildLoad2(builder, LLVMArrayType(elementType, 2), arrayLiteral, "arrayLiteralValue");
    LLVMBuildStore(builder, arrayLiteralValue, array);

    // Return 0
    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32TypeInContext(context), 0, 0));

    writefln("%s", mod.printModuleToString());

    if(string err = verifyModule(mod)) {
        writefln("Module verification failed: %s", err);
        return;
    }
    writefln("Module verified ok");
}
