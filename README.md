# ace-forth

ace-forth is a Forth cross-compiler for Jupiter Ace. The main benefit of cross-compiling is that it allows editing the source code on host PC and compiling it to TAP file to be executed on a real Jupiter Ace or emulator.

Features:

- Supports most standard Forth words
- Includes some non-standard extras, most notably `GOTO` and `LABEL` (see differences below)
- Inlining, dead code elimination, minimal word names and small literal optimizations
- Easy to customize; written in Lua


## Prerequisites

You need a Lua 5.4 interpreter executable, which can be obtained from
http://www.lua.org/download.html

Precompiled Lua binaries for many platforms are also available:
http://luabinaries.sourceforge.net/

A precompiled executable for macOS comes with the compiler in the 'tools' directory.


## Usage

	compile.lua [options] <inputfile1> <inputfile2> ...

	Options:
	  -o <filename>             Sets output filename
	  --minimal-word-names      Rename all words as '@', except main word
	  --inline                  Inline words that are only used once
	  --eliminate-unused-words  Eliminate unused words when possible
	  --small-literals          Optimize byte-sized literals
	  --no-headers              (unsafe) Eliminate word headers, except for main word
	  --optimize                Enable all safe optimizations
	  --verbose                 Print information while compiling
	  --main <name>             Sets name of main executable word (default 'MAIN')
	  --filename <name>         Sets the filename for tap header (default 'dict')

On Windows which does not support shebangs you need to prefix the command line with path to the Lua interpreter.


## Differences with Jupiter Ace Forth interpreter

- Word names are case sensitive. In contrast to standard Forth most words need to be written in lower case (this is easier for the eyes).

- Floating point words are not currently supported in interpreter mode (the words can still be compiled though).

- Words `DEFINER`, `DOES>` and `RUNS>` are not supported. The usual interpreter words `IMMEDIATE`, `POSTPONE`, `[`, `]`, `HERE` etc. are supported.

- `WHILE` and `REPEAT` are not currently supported. They should be easy to add if needed though.

- New control flow words `GOTO` and `LABEL`.

- Infinite loops using `BEGIN` and `AGAIN` words are supported (you can jump out of them using `EXIT` or `GOTO`).

- Some commonly used words have been shortened: `CONSTANT` -> `CONST`, `LITERAL` -> `LIT`.

- New word `NOINLINE` which prevents inlining of the previously added word. It can also be used to silence "Word 'foo' has side exits and cannot be inlined" warning.

- New interpreter words: `[if]`, `[else]`, `[then]`, and `[defined]` for conditionally compiling code (e.g. for stripping debug code).

- New interpreter mode utility words: `NIP`, `2*`, `2/`, `2DUP`, and `2DROP`.

- Line comments using `\` word are supported.

- New variable defining word `BYTE`, which works like `VARIABLE` but defines byte sized variables (remember to use `C@` and `C!` to access them).

- New word `CODE` for embedding machine code words.

- New word `BYTES` for embedding byte data without having to use `C,` or `,` words between every element. The end of byte data is marked with `;`.

- New words `CREATE{` and `}` which work like `CREATE`, but `}` is used to mark the end of the word. This allows the compiler to eliminate unused words defined using `CREATE{`.
