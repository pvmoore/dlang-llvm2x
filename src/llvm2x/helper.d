module llvm2x.helper;

import llvm2x;
import llvm = llvm2x.llvm;

/**
 * Helper functions for the LLVM C wrapper
 */

//────────────────────────────────────────────────────────────────────────────────────────────────── modules
string getModuleName(LLVMModuleRef mod) {
    ulong len;
    auto chars = LLVMGetModuleIdentifier(mod, &len);
    return cast(string)chars[0..len];
}
string printModuleToString(LLVMModuleRef mod) {
    auto chars = LLVMPrintModuleToString(mod);
    return cast(string)chars.fromStringz();
}
bool writeModuleToFileLL(LLVMModuleRef mod, string filename) {
    char* error;
    return 0==LLVMPrintModuleToFile(mod, filename.toStringz(), &error);
}
bool writeModuleToFileBC(LLVMModuleRef mod, string filename) {
    return 0==LLVMWriteBitcodeToFile(mod, filename.toStringz());
}
string writeModuleToStringASM(LLVMModuleRef mod, LLVMTargetMachineRef targetMachine) {
    char* error;
    LLVMMemoryBufferRef memBuf;
    auto result = LLVMTargetMachineEmitToMemoryBuffer(
        targetMachine,
        mod,
        LLVMCodeGenFileType.LLVMAssemblyFile,
        &error,
        &memBuf
    );
    if(result==0) {
        auto size = LLVMGetBufferSize(memBuf);
        auto ptr = LLVMGetBufferStart(memBuf);
        string str = ptr[0..size].idup;
        LLVMDisposeMemoryBuffer(memBuf);
        return str;
    }
    if(error) {
        import core.stdc.stdlib : free;
        free(error);
    }
    return null;
}
/** 
 * Write the module to a file
 *
 * @param mod The module to write
 * @param targetMachine The target machine to use for the output
 * @param genType LLVMCodeGenFileType.LLVMAssemblyFile or LLVMCodeGenFileType.LLVMObjectFile
 * @param filename The filename to write to
 * 
 * Returns true if successful
 */ 
bool writeModuleToFile(LLVMModuleRef mod, LLVMTargetMachineRef targetMachine, LLVMCodeGenFileType genType, string filename) {
    char* error;
    LLVMBool res = LLVMTargetMachineEmitToFile(
        targetMachine, 
        mod, 
        filename.toStringz,
        genType,
        &error);
    //writefln("error=%s", error.fromStringz);
    if(error) {
        import core.stdc.stdlib : free;
        free(error);
    }
    return 0==res;
}

// Links srcModules into dest and returns true if successful
bool linkModules(LLVMModuleRef dest, LLVMModuleRef[] srcModules...) {
    foreach(LLVMModuleRef o; srcModules) {
        LLVMBool res = LLVMLinkModules2(dest, o);
        if(res!=0) return false;
    }
    return true;
}

//────────────────────────────────────────────────────────────────────────────────────────────────── functions

// Create a function type
LLVMTypeRef LLVMFunctionType(LLVMTypeRef returnType, LLVMTypeRef[] paramTypes, bool isVarArg = false) {
    return llvm.LLVMFunctionType(returnType, paramTypes.ptr, cast(uint)paramTypes.length, isVarArg);
}

LLVMTypeRef[] getParamTypes(LLVMTypeRef funcType) {
    ulong count = LLVMCountParamTypes(funcType);
    LLVMTypeRef[] types = new LLVMTypeRef[count];
    LLVMGetParamTypes(funcType, types.ptr);
    return types;
}
LLVMValueRef[] getParamValues(LLVMValueRef func) {
    ulong count = LLVMCountParams(func);
    LLVMValueRef[] params = new LLVMValueRef[count];
    LLVMGetParams(func, params.ptr);
    return params;
}
LLVMAttributeRef[] getFunctionAttributes(LLVMValueRef func, uint index) {
    ulong count = LLVMGetAttributeCountAtIndex(func, index);
    LLVMAttributeRef[] attrs = new LLVMAttributeRef[count];
    LLVMGetAttributesAtIndex(func, index, attrs.ptr);
    return attrs;
}

//────────────────────────────────────────────────────────────────────────────────────────────────── structs
string getStructName(LLVMTypeRef str) {
    return cast(string)LLVMGetStructName(str).fromStringz();
}
LLVMTypeRef[] structElementTypes(LLVMTypeRef str) {
    ulong count = LLVMCountStructElementTypes(str);
    LLVMTypeRef[] types = new LLVMTypeRef[count];
    LLVMGetStructElementTypes(str, types.ptr);
    return types;
}
//────────────────────────────────────────────────────────────────────────────────────────────────── types
LLVMTypeRef[] subtypes(LLVMTypeRef type) {
    ulong count = LLVMGetNumContainedTypes(type);
    LLVMTypeRef[] types = new LLVMTypeRef[count];
    LLVMGetSubtypes(type, types.ptr);
    return types;
}
//────────────────────────────────────────────────────────────────────────────────────────────────── values
string getValueName(LLVMValueRef val) {
    return cast(string)LLVMGetValueName(val).fromStringz();
}
void setValueName(LLVMValueRef val, string name) {
    LLVMSetValueName2(val, name.toStringz(), name.length);
}
string toString(LLVMValueRef val) {
    return cast(string)LLVMPrintValueToString(val).fromStringz();
}
string getAsString(LLVMValueRef val) {
    return cast(string)LLVMGetAsString(val, null).fromStringz();
}
