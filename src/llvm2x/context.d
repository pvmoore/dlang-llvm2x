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

    // These don't require a context so probably we shouldn't include them here

    // LLVMTypeRef pointerType(LLVMTypeRef type, uint addressSpace = 0) {
    //     return LLVMPointerType(type, addressSpace);
    // }
    // LLVMTypeRef arrayType(LLVMTypeRef type, ulong size) {
    //     return LLVMArrayType2(type, size);
    // }
    // LLVMTypeRef vectorType(LLVMTypeRef type, uint size) {
    //     return LLVMScalableVectorType(type, size);
    // }

    // LLVMValueRef constI1(bool value) {
    //     return LLVMConstInt(int1Type(), value ? 1 : 0, 0);
    // }
    // LLVMValueRef constI8(ulong value, bool signed) {
    //     return LLVMConstInt(int8Type(), value, signed.toLLVMBool());
    // }
    // LLVMValueRef constI16(ulong value, bool signed) {
    //     return LLVMConstInt(int16Type(), value, signed.toLLVMBool());
    // }
    // LLVMValueRef constI32(ulong value, bool signed) {
    //     return LLVMConstInt(int32Type(), value, signed.toLLVMBool());
    // }
    // LLVMValueRef constI64(ulong value, bool signed) {
    //     return LLVMConstInt(int64Type(), value, signed.toLLVMBool());
    // }
    // LLVMValueRef constFloat(double value) {
    //     return LLVMConstReal(floatType(), value);
    // }
    // LLVMValueRef constDouble(double value) {
    //     return LLVMConstReal(doubleType(), value);
    // }
}

