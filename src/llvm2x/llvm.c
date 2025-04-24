
/** 
 * Main LLVM C wrapper. Includes most of the function declarations.
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\Core.h"

/**
 * LLVMWriteBitcodeToFile
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\BitWriter.h"

/**
 * LLVMLinkModules2
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\Linker.h"

/**
 * LLVMCreateTargetMachineOptions
 * LLVMCreateTargetMachineWithOptions
 * LLVMTargetMachineOptionsSetCPU
 * LLVMTargetMachineOptionsSetFeatures
 * LLVMTargetMachineOptionsSetABI
 * LLVMTargetMachineOptionsSetCodeGenOptLevel
 * LLVMTargetMachineOptionsSetRelocMode
 * LLVMTargetMachineOptionsSetCodeModel
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\TargetMachine.h"


/**
 * LLVMCreatePassBuilderOptions
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\Transforms\\PassBuilder.h"

/**
 * LLVMOrcCreateLLJITBuilder
 */
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\LLJIT.h"
#include "c:\\Temp\\llvm-project\\llvm\\include\\llvm-c\\OrcEE.h"
