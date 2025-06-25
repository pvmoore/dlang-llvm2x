module test_structs;

import llvm2x;
import std.stdio : writefln;

void testStructs(LLVMContextWrapper wrapper, LLVMTargetMachineRef targetMachine) {
    writefln("╔═══════════════════════════════════════════════════════════");
    writefln("║ Test structs");
    writefln("╚═══════════════════════════════════════════════════════════");

    LLVMModuleRef mod = createModule(wrapper.ctx, wrapper.builder, targetMachine);

    writefln("%s", mod.printModuleToString());

    if(string err = verifyModule(mod)) {
        writefln("Module verification failed: %s", err);
        return;
    }
    writefln("Module verified ok");
}

LLVMModuleRef createModule(LLVMContextRef context, LLVMBuilderRef builder, LLVMTargetMachineRef targetMachine) {

    LLVMTargetDataRef targetData = LLVMCreateTargetDataLayout(targetMachine);

    LLVMModuleRef mod = LLVMModuleCreateWithNameInContext("test", context); 

    // Create global struct with no members
    LLVMTypeRef[] structMembers = [
   
    ];
    LLVMTypeRef structType = LLVMStructTypeInContext(context, structMembers.ptr, cast(int)structMembers.length, 0);
    LLVMValueRef globalStruct = LLVMAddGlobal(mod, structType, "globalStruct");

    // size = 0, align = 1
    writefln("struct size = %s", LLVMABISizeOfType(targetData, structType));
    writefln("struct align = %s", LLVMABIAlignmentOfType(targetData, structType));

    // Create main function
    LLVMTypeRef mainType = LLVMFunctionType(LLVMInt32TypeInContext(context), []);
    LLVMValueRef mainValue = LLVMAddFunction(mod, "main", mainType);
    LLVMSetLinkage(mainValue, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(mainValue, CallingConv.C);

    // Entry block
    LLVMBasicBlockRef entry = LLVMAppendBasicBlockInContext(context, mainValue, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);   

    // Create a local variable of the struct type
    LLVMValueRef localStruct = LLVMBuildAlloca(builder, structType, "localStruct");


    // Return 0
    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32TypeInContext(context), 0, 0));
    return mod;
}
