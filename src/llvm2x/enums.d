module llvm2x.enums;

import llvm2x;

/** 
 * Enumerations for the LLVM C wrapper
 */

// See llvm-project\llvm\include\llvm\IR\CallingConv.h
enum CallingConv : uint {
    C = 0,
    Fast = 8,
    Cold = 9,
    X86_StdCall = 64,   // mostly used by the Win32 API
    Win64 = 79,
}
