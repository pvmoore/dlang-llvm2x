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
    LLVMTypeRef structType(string name) {
        return LLVMStructCreateNamed(ctx, name.toStringz());
    }
    // LLVMTypeRef structType(string name, LLVMTypeRef[] types, bool packed) {
    //     LLVMTypeRef s = LLVMStructCreateNamed(ctx, name.toStringz());
    //     LLVMStructSetBody(s, types.ptr, cast(uint)types.length, cast(LLVMBool)packed);
    //     return s;
    // }
    LLVMTypeRef structType(LLVMTypeRef[] types, bool packed) {
        return LLVMStructTypeInContext(ctx, types.ptr, cast(uint)types.length, cast(LLVMBool)packed);
    }
    LLVMTypeRef voidType() {
        return LLVMVoidTypeInContext(ctx);
    } 
    LLVMTypeRef int1Type() {
        return LLVMInt1TypeInContext(ctx);
    }
    LLVMTypeRef int8Type() {
        return LLVMInt8TypeInContext(ctx);
    }
    LLVMTypeRef int16Type() {
        return LLVMInt16TypeInContext(ctx);
    }
    LLVMTypeRef int32Type() {
        return LLVMInt32TypeInContext(ctx);
    }
    LLVMTypeRef int64Type() {
        return LLVMInt64TypeInContext(ctx);
    }
    LLVMTypeRef floatType() {
        return LLVMFloatTypeInContext(ctx);
    }
    LLVMTypeRef doubleType() {
        return LLVMDoubleTypeInContext(ctx);
    }

    LLVMValueRef constString(string str) {
        return LLVMConstStringInContext2(ctx, str.toStringz(), str.length, 0);
    }
}

