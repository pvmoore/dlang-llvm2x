# Building LLVM On Windows

See also https://llvm.org/docs/GettingStarted.html#getting-the-source-code-and-building-llvm

Fetch the code from github if you don't already have it:

	git clone https://github.com/llvm/llvm-project.git


Change to the desired branch. For llvm 23 we use the llvmorg-23.1.0 branch:

	git checkout llvmorg-23.1.0
	git status

	> HEAD detached at llvmorg-23.1.0
	> nothing to commit, working tree clean

Move to the llvm directory and create a build directory and change to it:

	cd llvm
	mkdir build
	cd build

Install Python 3.11 if you don't already have it:

	winget install Python.Python.3.11

Configure the build: (These options assume you also want LLD)

	cmake -G "Visual Studio 17 2022" -A x64 -DLLVM_TARGETS_TO_BUILD="X86"  -DCMAKE_MSVC_RUNTIME_LIBRARY="MultiThreaded"
		  -DLLVM_ENABLE_PROJECTS=lld ..

Open LLVM.sln in Visual Studio and build the project.

Get the full list of required libs by running:

	llvm-config --libnames all

Add the lib files to dub.sdl eg.

	lflags "/LIBPATH:C:/work/llvm-23/lib"
	libs "LLVMCore"
	# .. add the rest of the libs

Note that I also had to add the following libs:

	libs "ntdll" # Required for RtlGetLastNtStatus in lib/Support/ErrorHandling.cpp.

Set the header directories in dub.sdl (for DLang Import-C):

	dflags "-P=-IC:/Temp/llvm-project/llvm/include/"
	dflags "-P=-IC:/Temp/llvm-project/llvm/build/include/"
