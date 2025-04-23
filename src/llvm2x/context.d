module llvm2x.context;

import llvm2x;

/**
 * Convenience for creating types and values that are local to a specific LLVMContextRef 
 */
final class LLVMContextWrapper {
public:
    LLVMContextRef ctx;
    LLVMBuilderRef builder;

    this() {
        ctx = LLVMContextCreate();
        builder = LLVMCreateBuilderInContext(ctx);
    }
    ~this() {
        if(builder) LLVMDisposeBuilder(builder);
        if(ctx) LLVMContextDispose(ctx);
    }

    LLVMModuleRef createModule(string name) {
        return LLVMModuleCreateWithNameInContext(name.toStringz(), ctx);
    }

    LLVMTypeRef voidType() {
        return LLVMVoidTypeInContext(ctx);
    } 
    LLVMTypeRef int32Type() {
        return LLVMInt32TypeInContext(ctx);
    }
}

