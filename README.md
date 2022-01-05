# ace-forth

ace-forth is a Forth cross-compiler for Jupiter Ace. The main benefit of cross-compiling is that it allows editing the source code on host PC and compiling it to TAP file to be executed on a real Jupiter Ace or emulator.

Features:

- Supports most standard Forth words
- Includes some non-standard extras, most notably `GOTO` and `LABEL` (see differences below)
- Inlining, dead code elimination, minimal word names and small literal optimizations
- Supports compilation to machine code for maximum speed
- Easy to customize; written in Lua


## Prerequisites

You need a Lua 5.4 interpreter executable, which can be obtained from
http://www.lua.org/download.html

Precompiled Lua binaries for many platforms are also available:
http://luabinaries.sourceforge.net/

A precompiled executable for macOS comes with the compiler in the 'tools' directory.

If you are a Sublime Text user, you might also want to install the following Forth syntax plugin with ace-forth support:
https://github.com/petrihakkinen/sublime-forth

## Usage

	compile.lua [options] <inputfile1> <inputfile2> ...

	Options:
	  -o <filename>             Sets output filename
	  -l <filename>             Write listing to file
	  --ignore-case             Treat all word names as case insensitive
	  --minimal-word-names      Rename all words as '@', except main word
	  --inline                  Inline words that are only used once
	  --eliminate-unused-words  Eliminate unused words when possible
	  --small-literals          Optimize byte-sized literals
	  --no-headers              (unsafe) Eliminate word headers, except for main word
	  --optimize                Enable all safe optimizations
	  --verbose                 Print information while compiling
	  --main <name>             Sets name of main executable word (default 'main')
	  --filename <name>         Sets the filename for tap header (default 'dict')

On Windows which does not support shebangs you need to prefix the command line with path to the Lua interpreter.


## Differences with Jupiter Ace Forth interpreter

- Word names are case sensitive by default. However, you can turn off case sensitivity using the `--ignore-case` option. When in case sensitive mode, standard word names should be written in lower case (e.g. `dup` instead of `DUP`).

- Floating point literals are not currently supported.

- Words `DEFINER`, `DOES>` and `RUNS>` are not supported. The usual interpreter words `IMMEDIATE`, `POSTPONE`, `[`, `]`, `HERE` etc. are supported though.

- `WHILE` and `REPEAT` are not currently supported. They should be easy to add if needed though.

- Some commonly used words have been shortened: `CONSTANT` -> `CONST`, `LITERAL` -> `LIT`.


## News words and features

The compiler supports many extras not found on Jupiter Ace's Forth implementation. Some of the features are unique to this compiler. The documentation is still a bit lacking, please contact me for more info.

- New control flow words `GOTO` and `LABEL`.

- Infinite loops using `BEGIN` and `AGAIN` words are supported (you can jump out of them using `EXIT` or `GOTO`).

- New word `NOINLINE` which prevents inlining of the previously added word. It can also be used to silence "Word 'foo' has side exits and cannot be inlined" warning.

- New interpreter words: `[IF]`, `[ELSE]`, `[THEN]`, and `[DEFINED]` for conditionally compiling code (e.g. for stripping debug code).

- New interpreter mode utility words: `NIP`, `2*`, `2/`, `2DUP`, and `2DROP`.

- Line comments using `\` word are supported.

- New variable defining word `BYTE`, which works like `VARIABLE` but defines byte sized variables (remember to use `C@` and `C!` to access them).

- New defining word `CODE` for embedding machine code as data.

- New defining word `:m` which compiles the word into native machine code.

- New word `C*` which is like `*` but computes the unsigned 8-bit multiplication. `C*` is a lot faster than `*` when the both operands are in range 0 - 255. Result is undefined if one or both operands are outside the valid range.

- New word `BYTES` for embedding byte data without having to use `C,` or `,` words between every element. The end of byte data is marked with `;`.

- New words `CREATE{` and `}` which work like `CREATE`, but `}` is used to mark the end of the word. This allows the compiler to eliminate unused words defined using `CREATE{`.


## Machine code compilation

The word `:m` allows compiling words into native machine code. Such words can be several times, sometimes even an order of magnitude, faster. Machine code words can be called from normal Forth words and vice versa. 

A simple example of a machine code word:

	:m stars 10 0 do ascii * emit loop ;

Machine code words, however, have some disadvantages:

- They take up more program space. If program size is important, you should consider compiling only the most often used words as machine code.

- Machine code words are not relocatable. Therefore, when you load a program containing machine code words, there should be no other user defined words defined previously.

Some words contained inside `:m` definitions cannot be compiled into machine code currently. Therefore, there is a performance penalty when the following words are used inside :m definitions:

	UFLOAT INT FNEGATE F/ F* F+ F- F.
	D+ DNEGATE U/MOD */ MOD / */MOD /MOD U* D< U<
	# #S U. . #> <# SIGN HOLD
	CLS SLOW FAST INVIS VIS ABORT QUIT
	LINE WORD NUMBER CONVERT RETYPE QUERY
	ROT PLOT BEEP EXECUTE CALL

It's strongly recommended to not use any of these words inside `:m` definitions!

Additionally it's recommended to use the new word `C*` instead of `*` when multiplying two values if those values and the result fits into 8 bits. The word `C*` is currently only supported inside `:m` definitions.