module llvm2x.helper;

import llvm2x;
import llvm = llvm2x.llvm;

public:

/**
 * Helper functions for the LLVM C wrapper
 */

LLVMBool toLLVMBool(bool b) {
    return b ? 1 : 0;
}
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
string printValueToString(LLVMValueRef val) {
    auto chars = LLVMPrintValueToString(val);
    return cast(string)chars.fromStringz();
}
string printTypeToString(LLVMTypeRef type) {
    auto chars = LLVMPrintTypeToString(type);
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
 * Write the module to a memory buffer
 *
 * @param mod The module to write
 * @param targetMachine The target machine to use for the output
 * @param genType LLVMCodeGenFileType.LLVMAssemblyFile or LLVMCodeGenFileType.LLVMObjectFile
 * 
 * Returns the memory buffer or null if there was an error (in this case the error parameter is populated)
 *
 * eg.
 * 
 * if(auto memBuf = writeModuleToMemory(mod, targetMachine, LLVMCodeGenFileType.LLVMAssemblyFile, error)) {
 *     auto size = LLVMGetBufferSize(memBuf);
 *     auto ptr = LLVMGetBufferStart(memBuf);
 *     string str = ptr[0..size].idup;
 *     LLVMDisposeMemoryBuffer(memBuf);
 *     return str;
 * }
 */
LLVMMemoryBufferRef writeModuleToMemory(LLVMModuleRef mod, LLVMTargetMachineRef targetMachine, LLVMCodeGenFileType genType, char* error) {
    LLVMMemoryBufferRef memBuf;
    LLVMTargetMachineEmitToMemoryBuffer(
        targetMachine,
        mod,
        genType,
        &error,
        &memBuf
    );
    return memBuf;
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

// Verifys the module and returns null if successful or an error message if not
string verifyModule(LLVMModuleRef mod) {
    char* msgs;
    if(LLVMVerifyModule(mod, LLVMVerifierFailureAction.LLVMPrintMessageAction, &msgs)) {
        string errorMsg =  cast(string)msgs.fromStringz();
        LLVMDisposeMessage(msgs);

        return errorMsg;
    }
    return null;
}

/**
 * Link the object file to an executable
 * 
 * Returns a tuple of (returnStatus, errorMsg)
 */
Tuple!(int, string) msLink(string targetName, bool debugMode, bool deleteObjFile) {
    string objFile = targetName ~ ".obj";
    string exeFile = targetName ~ ".exe";
    string subsystem = "console";

    auto args = [
        "link",
        "/NOLOGO",
        //"/VERBOSE",
        "/MACHINE:X64",
        "/WX",              /// Treat linker warnings as errors
        "/SUBSYSTEM:" ~ subsystem
    ];

    string[] externalLibs;
    if(debugMode) {
        args ~= [
            "/DEBUG:NONE",  /// Don't generate a PDB for now
            "/OPT:NOREF"    /// Don't remove unreferenced functions and data
        ];

        externalLibs ~= [
            //"ucrtd.lib",                  // MS universal C99 runtime (debug)
            "msvcrtd.lib",                  // MS C initialization and termination (debug)
            "legacy_stdio_definitions.lib", // Required for printf (and probably other stdio functions)
        ];
        //externalLibs ~= [
        //    "libucrtd.lib",
        //    "libcmtd.lib",
        //    "libvcruntimed.lib"
        //];
    } else {
        args ~= [
            "/RELEASE",
            "/OPT:REF",     /// Remove unreferenced functions and data
            //"/LTCG",        /// Link time code gen
        ];

        externalLibs ~= [
            "msvcrt.lib",               // MS C initialization and termination (release)
            //"ucrt.lib",                 // MS universal C99 runtime (release)
            "legacy_stdio_definitions.lib", // Required for printf (and probably other stdio functions)
        ];
        //externalLibs ~= [
        //    "libucrt.lib",
        //    "libcmt.lib",
        //    "libvcruntime.lib"
        //];
    }

    args ~= [
        objFile,
        "/OUT:" ~ exeFile
    ];

    args ~= externalLibs;

    // writefln("link args: \n%s", args.join("\n  "));

    import std.process : spawnProcess, wait;

    int returnStatus;
    string errorMsg;
    try{
        auto pid = spawnProcess(args);
        returnStatus = wait(pid);
    }catch(Exception e) {
        errorMsg     = e.msg;
        returnStatus = -1;
    }

    if(deleteObjFile) {
        import std.file : remove;
        remove(objFile);
    }

    return tuple(returnStatus, errorMsg);
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
string toString(LLVMTypeRef type) {
    return cast(string)LLVMPrintTypeToString(type).fromStringz();
}
string getAsString(LLVMValueRef val) {
    return cast(string)LLVMGetAsString(val, null).fromStringz();
}
