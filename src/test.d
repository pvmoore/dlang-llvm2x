module test;

public:

import std.stdio  : writefln, writeln;
import std.format : format;

import llvm2x;
import test_jit;
import test_build_module;
import test_create_module_from_src;
import test_function_ptrs;

void main() {

    const binDir = "c:\\work\\llvm-20\\bin";

    // Enable this to display the required LLVM libraries
    static if(false) {
        dumpLibNames(binDir);
    }

    // Display the LLVM version
    uint major, minor, patch;
    LLVMGetVersion(&major, &minor, &patch);
    writeln("LLVM version: ", major, ".", minor, ".", patch);

    writefln("LLVMIsMultithreaded = %s", LLVMIsMultithreaded());

    auto llvmContext = new LLVMContextWrapper();

    llvmContext.setDiagnosticHandler();

    // Initialise the target(s)
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
    LLVMInitializeX86Disassembler();

    string targetTriple = "x86_64-pc-windows-msvc";

    LLVMTargetMachineRef targetMachine = createTargetMachine(targetTriple);

    static if(false) {
        LLVMPassBuilderOptionsRef passBuilderOptions = createPassOptions();

        // Create a module
        LLVMModuleRef testModule = llvmContext.createModule("test");
        LLVMSetTarget(testModule, targetTriple.toStringz());
        writefln("Module created: %s '%s'", testModule, testModule.getModuleName());

        LLVMValueRef funcValue = createTestFunction(llvmContext, testModule);
        writefln("Module:");
        writefln("%s", testModule.printModuleToString());

        // Optimize the module
        writefln("Running optimiser ...");
        // Run the optimiser on the whole module or a single function:

        checkError(LLVMRunPasses(testModule, "default<O3>", targetMachine, passBuilderOptions));
        //checkError(LLVMRunPassesOnFunction(funcValue, "adce,dse", targetMachine, passBuilderOptions));

        writefln("Optimised module:");
        writefln("%s", testModule.printModuleToString());

        writefln("Verifying function '%s'", funcValue.getValueName());
        LLVMBool fv = LLVMVerifyFunction(funcValue, LLVMVerifierFailureAction.LLVMPrintMessageAction);
        if(fv!=0) {
            writeln("Function verification failed");
        } else {
            writeln("Function verification passed");
        }

        writefln("Verifying module '%s'", testModule.getModuleName());
        char* msgs;
        LLVMBool mv = LLVMVerifyModule(testModule, LLVMVerifierFailureAction.LLVMPrintMessageAction, &msgs);
        if(mv!=0) {
            writeln("Module verification failed: ", msgs.fromStringz());
        } else {
            writeln("Module verification passed");
        }

        // Generate and dump the assembly
        LLVMSetTargetMachineAsmVerbosity(targetMachine, 1);
        LLVMSetTargetMachineGlobalISel(targetMachine, 1);
        string asmOut = writeModuleToStringASM(testModule, targetMachine);
        // writeln();
        // writeln(asmOut);
        if(testModule) {
            LLVMDisposeModule(testModule);
        }
    }

    static if(false) {
        testJit(targetMachine);
    }
    static if(false) {
        testCreateModuleFromSource(llvmContext, targetMachine);
    }
    static if(false) {
        testBuildModule(llvmContext, targetMachine);
    }
    static if(true) {
        testFunctionPtrs(llvmContext, targetMachine);
    }
}

LLVMValueRef createTestFunction(LLVMContextWrapper ctx, LLVMModuleRef mod) {
    // Create the function type
    LLVMTypeRef funcType = LLVMFunctionType(ctx.voidType(), []);

    // Add the function to the module
    LLVMValueRef funcValue = LLVMAddFunction(mod, "test", funcType);

    // Set the linkage
    LLVMSetLinkage(funcValue, LLVMLinkage.LLVMExternalLinkage);

    // Set the calling convention (The default is C)
    LLVMSetFunctionCallConv(funcValue, CallingConv.C);

    // Add the entry block
    LLVMBasicBlockRef entry = LLVMAppendBasicBlock(funcValue, "entry");
    LLVMPositionBuilderAtEnd(ctx.builder, entry);

    // int a;
    LLVMValueRef localA = LLVMBuildAlloca(ctx.builder, ctx.int32Type(), "a");

    // a = 1;
    LLVMBuildStore(ctx.builder, LLVMConstInt(ctx.int32Type(), 1, 0), localA);

    // overwrite the previous store
    // a = 10;
    LLVMBuildStore(ctx.builder, LLVMConstInt(ctx.int32Type(), 10, 0), localA);

    // return (void)
    LLVMValueRef retVoid = LLVMBuildRetVoid(ctx.builder);

    return funcValue;
}

LLVMTargetMachineRef createTargetMachine(string targetTriple) {
    auto targetTriplez = targetTriple.toStringz();
    char* error;
    LLVMTargetRef targetRef;
    LLVMBool r = LLVMGetTargetFromTriple(targetTriplez, &targetRef, &error);
    if(r!=0 || targetRef is null) {
        writeln("Target triple error: ", error);
    }

    writefln(" LLVMTargetRef = %s", targetRef);
    writefln(" LLVMTargetHasJIT = %s", LLVMTargetHasJIT(targetRef) == 1 ? "true" : "false");


    // llc -march=x86 -mattr=help

    LLVMTargetMachineOptionsRef options = LLVMCreateTargetMachineOptions();
    LLVMTargetMachineOptionsSetCPU(options, "znver3");
    LLVMTargetMachineOptionsSetFeatures(options, "+avx2");
    LLVMTargetMachineOptionsSetABI(options, "fast");
    LLVMTargetMachineOptionsSetCodeGenOptLevel(options, LLVMCodeGenOptLevel.LLVMCodeGenLevelAggressive);
    //LLVMTargetMachineOptionsSetRelocMode(options, LLVMRelocMode.LLVMRelocDefault);
    //LLVMTargetMachineOptionsSetCodeModel(options, LLVMCodeModel.LLVMCodeModelDefault);

    LLVMTargetMachineRef targetMachine = LLVMCreateTargetMachineWithOptions(targetRef, targetTriplez, options);
    writefln(" LLVMTargetMachineRef = %s", targetMachine);
    writefln(" Features: %s", LLVMGetTargetMachineFeatureString(targetMachine).fromStringz());

    //LLVMTargetDataRef dataLayout = LLVMCreateTargetDataLayout(targetMachine);
    //writefln(" LLVMTargetDataRef = %s", dataLayout);
    return targetMachine;
}

/** Setup the new pass manager */
LLVMPassBuilderOptionsRef createPassOptions() {
    // New pass manager
    LLVMPassBuilderOptionsRef passBuilderOptions = LLVMCreatePassBuilderOptions();
    LLVMPassBuilderOptionsSetVerifyEach(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetDebugLogging(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetLoopInterleaving(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetLoopVectorization(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetSLPVectorization(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetLoopUnrolling(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetAAPipeline(passBuilderOptions, "?");
    //LLVMPassBuilderOptionsSetForgetAllSCEVInLoopUnrolling(passBuilderOptions, 1);
    //LLVMPassBuilderOptionsSetLicmMssaOptCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetLicmMssaNoAccForPromotionCap(passBuilderOptions, ?);
    //LLVMPassBuilderOptionsSetCallGraphProfile(passBuilderOptions, 1);
    LLVMPassBuilderOptionsSetMergeFunctions(passBuilderOptions, 0);
    //LLVMPassBuilderOptionsSetInlinerThreshold(passBuilderOptions, 25);
    return passBuilderOptions;
}


extern(C) void myDiagnosticHandler(LLVMDiagnosticInfoRef info, void* ctx) {
    LLVMDiagnosticSeverity severity = LLVMGetDiagInfoSeverity(info);
    string msg = cast(string)LLVMGetDiagInfoDescription(info).fromStringz();
    writeln("[%s]: ", severity, msg);
}

void setDiagnosticHandler(LLVMContextWrapper wrapper) {
    // Set the Diagnostic handler
    void* diagnosticContext = null;
    LLVMContextSetDiagnosticHandler(wrapper.ctx, &myDiagnosticHandler, diagnosticContext);

    // Get the diagnostic handler
    LLVMDiagnosticHandler theDiagnosticHandler = LLVMContextGetDiagnosticHandler(wrapper.ctx);

    // Get the diagnostic context
    void* theDiagnosticContext = LLVMContextGetDiagnosticContext(wrapper.ctx);
}

void checkError(LLVMErrorRef err) {
    if(err !is null) {
        throw new Exception("%s".format(LLVMGetErrorMessage(err).fromStringz()));
    }
}
