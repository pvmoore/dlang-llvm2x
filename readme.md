# D Language Wrapper for LLVM 20

## LLVM 20 

https://releases.llvm.org/20.1.0/docs/ReleaseNotes.html


## Building LLVM

Fetch the code from github if you don't already have it:

	git clone https://github.com/llvm/llvm-project.git

See also https://llvm.org/docs/GettingStarted.html#getting-the-source-code-and-building-llvm	

Change to the desired branch. For llvm 20 we use the llvmorg-20.1.3 branch:

	git checkout llvmorg-20.1.3
	git status

	> HEAD detached at llvmorg-20.1.3
	> nothing to commit, working tree clean

Move to the llvm directory and create a build directory and change to it:

	cd llvm
	mkdir build
	cd build

Install Python 3.8 if you don't already have it:

	winget install Python.Python.3.8

Configure the build:

	cmake -G "Visual Studio 17 2022" -A x64 -DLLVM_TARGETS_TO_BUILD="X86" -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded" ..

Open LLVM.sln in Visual Studio and build the project.

Get the full list of required libs by running:

	llvm-config --libnames all

There is a utility function in module llvm20.utils that will generate the list for you ( dumpLibNames() ).

Add the lib files to dub.sdl.

	lflags "/LIBPATH:C:/work/llvm-20/lib"
	libs "LLVMCore" 
	# .. add the rest of the libs

Note that I also had to add the following libs:

	libs "ntdll" # Required for RtlGetLastNtStatus in lib/Support/ErrorHandling.cpp.

Set the header directories in dub.sdl:

	dflags "-P=-IC:/Temp/llvm-project/llvm/include/"
	dflags "-P=-IC:/Temp/llvm-project/llvm/build/include/"
