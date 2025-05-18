module test_build_module;

import llvm2x;
import std.stdio : writefln;

void testBuildModule(LLVMContextWrapper wrapper, LLVMTargetMachineRef targetMachine) {
    writefln("╔═══════════════════════════════════════════════════════════");
    writefln("║ Test build module");
    writefln("╚═══════════════════════════════════════════════════════════");

    LLVMContextRef context = wrapper.ctx;
    LLVMBuilderRef builder = LLVMCreateBuilderInContext(context);
    LLVMModuleRef mod = LLVMModuleCreateWithNameInContext("test", context);

    // Add putchar function declaration
    LLVMTypeRef putcharType = LLVMFunctionType(LLVMInt32TypeInContext(context), [LLVMInt32TypeInContext(context)]);
    LLVMValueRef putcharFunc = LLVMAddFunction(mod, "putchar", putcharType);
    LLVMSetLinkage(putcharFunc, LLVMLinkage.LLVMExternalLinkage);
    LLVMSetFunctionCallConv(putcharFunc, CallingConv.C);
    
    // Add fakeAssert function
    LLVMTypeRef fakeAssertType = LLVMFunctionType(LLVMVoidTypeInContext(context), [LLVMInt32TypeInContext(context)]);
    LLVMValueRef fakeAssertFunc = LLVMAddFunction(mod, "fakeAssert", fakeAssertType);
    LLVMSetLinkage(fakeAssertFunc, LLVMLinkage.LLVMInternalLinkage);
    //LLVMSetFunctionCallConv(fakeAssertFunc, CallingConv.Fast);
  
    LLVMBasicBlockRef fakeAssertEntry = LLVMAppendBasicBlock(fakeAssertFunc, "entry");
    LLVMPositionBuilderAtEnd(builder, fakeAssertEntry);

    // LLVMValueRef cond = LLVMBuildAlloca(builder, LLVMInt32TypeInContext(context), "cond");
    // LLVMBuildStore(builder, LLVMGetFirstParam(fakeAssertFunc), cond);

    LLVMBasicBlockRef thenBlock = LLVMAppendBasicBlock(fakeAssertFunc, "then");
    LLVMBasicBlockRef endifBlock = LLVMAppendBasicBlock(fakeAssertFunc, "endif");
    LLVMBasicBlockRef elseBlock = LLVMAppendBasicBlock(fakeAssertFunc, "else");


    //LLVMValueRef cond1 = LLVMBuildLoad2(builder, LLVMInt32TypeInContext(context), cond, "cond1");
    LLVMValueRef eq = LLVMBuildICmp(builder, LLVMIntPredicate.LLVMIntEQ, LLVMGetFirstParam(fakeAssertFunc), LLVMConstInt(LLVMInt32TypeInContext(context), 0, 0), "cond_result");
    LLVMBuildCondBr(builder, eq, thenBlock, elseBlock); 

    // else:
    LLVMPositionBuilderAtEnd(builder, elseBlock);
    LLVMBuildBr(builder, endifBlock);
    
    // then: 
    LLVMPositionBuilderAtEnd(builder, thenBlock);
    LLVMValueRef putcharCall = LLVMBuildCall2(builder, putcharType, putcharFunc, [LLVMConstInt(LLVMInt32TypeInContext(context), 109, 0)].ptr, 1, "call_putchar");
    LLVMBuildBr(builder, endifBlock);


    // endif:
    LLVMPositionBuilderAtEnd(builder, endifBlock);
    LLVMBuildRetVoid(builder);


    // Add main function
    LLVMTypeRef mainFuncType = LLVMFunctionType(LLVMInt32TypeInContext(context), []);
    LLVMValueRef mainFunc = LLVMAddFunction(mod, "main", mainFuncType);
    LLVMSetLinkage(mainFunc, LLVMLinkage.LLVMExternalLinkage);

    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(mainFunc, "entry");
    LLVMPositionBuilderAtEnd(builder, entry);

    // Call fakeAssert function
    LLVMValueRef fakeAssertCall = LLVMBuildCall2(builder, fakeAssertType, fakeAssertFunc, [LLVMConstInt(LLVMInt32TypeInContext(context), 1, 0)].ptr, 1, null.toStringz());
    LLVMSetInstructionCallConv(fakeAssertCall, CallingConv.Fast);

    LLVMBuildRet(builder, LLVMConstInt(LLVMInt32TypeInContext(context), 0, 0));
  
    

    writefln("----------------------------------------------------------------- raw");
    writefln("%s", mod.printModuleToString());
    writefln("");

    // Write to a .bc file
    if(!writeModuleToFileBC(mod, "bug.bc")) {
        writefln("Error writing module to file");
    }

    LLVMPassBuilderOptionsRef options = createPassOptions();
    optimiseModule(targetMachine, options, mod, "default<O3>");

    writefln("%s", mod.printModuleToString());
    writefln("");
}

