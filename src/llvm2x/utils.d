module llvm2x.utils;

/**
 * Extract the required static libraries in a form that can be pasted into dub.sdl
 */
void dumpLibNames(string binDir) {
    import std;

    string[] args = [ binDir ~ "\\llvm-config", "--libnames", "all" ];

    auto result = execute(
        args,
        null,   // env
        Config.stderrPassThrough
    );

    string output = result.output.strip();

    string[] libs = split(output, " ").map!(it=>it[0..$-4]).array;
    string[] sorted = libs.sort().array;

    int i;
    lp: while(true) {
        writef("libs ");
        foreach(n; 0..5) {
            if(i >= libs.length) break lp;
            writef("\"%s\" ", sorted[i]);
            i++;
        }
        writeln();
    }
    writeln();
}
