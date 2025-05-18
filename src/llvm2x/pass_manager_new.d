module llvm2x.pass_manager_new;

import llvm2x;

import std.stdio : writefln;

/**
 *  https://llvm.org/docs/NewPassManager.html
 *
 *
 */
bool optimiseModule(LLVMTargetMachineRef targetMachine, LLVMPassBuilderOptionsRef options, 
                    LLVMModuleRef mod, string passes = null) 
{
    writefln("Optimising module using new pass manager");

    // Not working: deadargelim,phi-values,scalar-evolution
    // Working: adce,instcombine,dse,verify
    //          default<O0>,default<O3>,default<O2>,default<O1>

    // Separate by commas. No spaces allowed

    if(passes is null) {
        passes = "default<O3>";
    }

    if(LLVMErrorRef err = LLVMRunPasses(mod, passes.toStringz(), targetMachine, options)) {
        writefln("Optimisation failed: %s", LLVMGetErrorMessage(err).fromStringz());
        return false;
    }
    return true;
}

LLVMPassBuilderOptionsRef createPassOptions() {
    // New pass manager
    LLVMPassBuilderOptionsRef passBuilderOptions = LLVMCreatePassBuilderOptions();
    // Toggle debug logging when running the PassBuilder. 
    LLVMPassBuilderOptionsSetDebugLogging(passBuilderOptions, 1);

    // Enable/disable loop interleaving
    LLVMPassBuilderOptionsSetLoopInterleaving(passBuilderOptions, 1);

    // Enable/disable loop vectorization
    LLVMPassBuilderOptionsSetLoopVectorization(passBuilderOptions, 1);

    // Enable/disable slp loop vectorization
    LLVMPassBuilderOptionsSetSLPVectorization(passBuilderOptions, 1);

    // Enable/disable loop unrolling
    LLVMPassBuilderOptionsSetLoopUnrolling(passBuilderOptions, 1);

    // Enable/disable the MergeFunctions pass
    LLVMPassBuilderOptionsSetMergeFunctions(passBuilderOptions, 1);

    // Enable/disable the VerifierPass for the PassBuilder, ensuring all functions inside the module is valid. 
    LLVMPassBuilderOptionsSetVerifyEach(passBuilderOptions, 1);

    return passBuilderOptions;
}

