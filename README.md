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

The compiler supports many extras not found on Jupiter Ace's Forth implementation. Some of the features are unique to this compiler.

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

The following table contains some benchmark results comparing the speed of machine code compiled Forth vs. interpreted Forth running on the Jupiter Ace. "Speed up" is how many times faster the machine code version runs.

| Benchmark        | Speed up  | Notes                      |
| ---------------- | --------- | -------------------------- |
| Stack ops        | 3.1       | DUP DROP                   |
| OVER             | 9.8       |                            |
| Arithmetic       | 4.7       | + -                        |
| DO LOOP          | 3.9       |                            |
| 1+               | 24        |                            |
| 2*               | 22        |                            |
| 2/               | 282       |                            |
| *                | 1.7       | 16-bit multiply            |
| C*               | 5.2       | 8-bit multiply             |

## Word Index

The following letters are used to denote values on the stack:

- `x` any value
- `n` float or integer number
- `flag` a boolean flag with possible values 1 (representing true) and 0 (representing false)
- `addr` numeric address in the memory (where compiled words and variables go)

### Stack Manipulation

| Word       | Stack                           | Description                                                         |
| ---------- | ------------------------------- | ------------------------------------------------------------------- |
| DUP        | ( x - x x )                     | Duplicate topmost stack element                                     |
| ?DUP       | ( x - x x )                     | Duplicate topmost stack element unless it is zero                   |
| DROP       | ( x - )                         | Remove topmost stack element                                        |
| NIP        | ( x1 x2 - x2 )                  | Remove the second topmost stack element                             |
| OVER       | ( x1 x2 - x1 x2 x1 )            | Duplicate the second topmost stack element                          |
| SWAP       | ( x1 x2 - x2 x1 )               | Swap two elements                                                   |
| ROT        | ( x1 x2 n3 - x2 x3 x1 )         | Rotate three topmost stack elements                                 |
| PICK       | ( n - x )                       | Duplicate the Nth topmost stack element                             |
| ROLL       | ( n - )                         | Extract the Nth element from stack, moving it to the top            |
| 2DUP       | ( x1 x2 - x1 x2 x1 x2 )         | Duplicate two topmost stack elements                                |
| 2DROP      | ( x x - )                       | Remove two topmost stack elements                                   |
| 2OVER      | ( x1 x2 n n - x1 x2 n n x1 x2 ) | Duplicates two elements on the stack                                |
| >R         | S: ( x - ) R: ( - x )           | Move value from data stack to return stack                          |
| R>         | S: ( - x ) R: ( x - )           | Move value from return stack to data stack                          |
| R@         | S: ( - x ) R: ( x - x )         | Copy value from return stack to data stack (without removing it)    |

### Arithmetic

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| +          | ( n n - n )        | Add two values                                                      |
| -          | ( n n - n )        | Subtract two values                                                 |
| *          | ( n n - n )        | Multiply two values                                                 |
| C*         | ( n n - n )        | Multiply two 8-bit values (only available inside :m definitions!)   |
| /          | ( n1 n2 - n )      | Divide n1 by n2                                                     |
| 1+         | ( n - n )          | Increment value by 1                                                |
| 1-         | ( n - n )          | Decrement value by 1                                                |
| 2+         | ( n - n )          | Increment value by 2                                                |
| 2-         | ( n - n )          | Decrement value by 2                                                |
| 2*         | ( n - n )          | Multiply value by 2                                                 |
| 2/         | ( n - n )          | Divide value by 2                                                   |
| NEGATE     | ( n - n )          | Negate value                                                        |
| ABS        | ( n - n )          | Compute the absolute value                                          |
| MIN        | ( n1 n2 - n )      | Compute the minimum of two values                                   |
| MAX        | ( n1 n2 - n )      | Compute the maximum of two values                                   |
| AND        | ( n n - n )        | Compute the bitwise and of two values                               |
| OR         | ( n n - n )        | Compute the bitwise or of two values                                |
| XOR        | ( n n - n )        | Compute the bitwise exlusive or of two values                       |
| F+         |                    |                                                                     |
| F-         |                    |                                                                     |
| F*         |                    |                                                                     |
| F/         |                    |                                                                     |
| F.         |                    |                                                                     |
| FNEGATE    |                    |                                                                     |
| D+         |                    |                                                                     |
| DNEGATE    |                    |                                                                     |
| U/MOD      |                    |                                                                     |
| */         |                    |                                                                     |
| MOD        |                    |                                                                     |
| */MOD      |                    |                                                                     |
| /MOD       |                    |                                                                     |
| U*         |                    |                                                                     |
| D<         |                    |                                                                     |
| U<         |                    |                                                                     |
| UFLOAT     |                    |                                                                     |
| INT        |                    |                                                                     |


### Memory

| Word       | Stack              | Description                                                       |
| ---------- | ------------------ | ----------------------------------------------------------------- |
| @          | ( addr - n )       | Fetch 16-bit value from address                                   |
| !          | ( n addr - )       | Store 16-bit value at address                                     |
| C@         | ( addr - n )       | Fetch 8-bit value from address                                    |
| C!         | ( n addr - )       | Store 8-bit value at address                                      |


### Compilation and Execution

| Word              | Stack              | Description                                                             |
| ----------------- | ------------------ | ----------------------------------------------------------------------  |
| : \<name\>        | ( - )              | Define new word with name \<name\> ("colon definition")                 |
| :M \<name\>       | ( - )              | Define new machine code word with name \<name\>                         |
| ;                 | ( - )              | Mark the end of colon definition, go back to interpreted state          |
| ,                 | ( n - )            | Enclose 16-bit value to next free location in dictionary                |
| C,                | ( n - )            | Enclose 8-bit value to next free location in dictionary                 |
| (                 | ( - )              | Block comment; skip characters until next )                             |
| \                 | ( - )              | Line comment; skip characters until end of line                         |
| [                 | ( - )              | Change from compile to interpreter state                                |
| ]                 | ( - )              | Change from interpreter to compile state                                |
| "                 | ( - )              | Enclose the following characters up until " into the dictionary         |
| CREATE \<name\>   | ( - )              | Add new (empty) word to dictionary with name \<name\>                   |
| CREATE{ \<name\>  | ( - )              | Same as CREATE, except the end of the word must be marked with }        |
| }                 | ( - )              | Marks the end of word created with CREATE{ (for dead code elimination)  |
| CODE \<name\>     | ( - )              | Defines a new word with machine code defined as following bytes of data |
| CONST \<name\>    | ( n - )            | Capture value to a new word with name \<name\>                          |
| VARIABLE \<name\> | ( n - )            | Create new 16-bit variable with name \<name\> and with initial value n  |
| BYTE \<name\>     | ( n - )            | Create new 8-bit variable with name \<name\> and with initial value n   |
| BYTES             | ( n - )            | Marks the start of bytes to be enclosed in dictionary (; marks the end) |
| ALLOT             | ( n - )            | Allocates space for n elements from output dictionary                   |
| ASCII \<char\>    | ( - (n) )          | Emit literal containing the ASCII code of the following symbol          |
| HERE              | ( - n )            | Push the address of the next free location in output dictionary         |
| LIT               | ( n - )            | Emit value from data stack to output dictionary                         |
| IMMEDIATE         | ( - )              | Mark the previous word to be executed immediately when compiling        |
| POSTPONE \<name\> | ( - )              | Write the compilation address of word \<name\> into the dictionary      |
| NOINLINE          | ( - )              | Prevent inlining of previously added word                               |
| FAST              | ( - )              | Turn off stack underflow check                                          |
| SLOW              | ( - )              | Turn on stack underflow check                                           |
| CALL              | ( addr - )         | Call a machine code routine. The routine must end with JP (IY)          |
| EXECUTE           | ( addr - )         | Execute a word given its compilation address                            |
| INVIS             | ( - )              | Turn off printing of executed words                                     |
| VIS               | ( - )              | Turn on printing of executed words                                      |
| ABORT             | ( - )              |                                                                         |
| QUIT              | ( - )              |                                                                         |


### Constants and Variables

| Word            | Stack              | Description                                                         |
| --------------- | ------------------ | ------------------------------------------------------------------- |
| TRUE            | ( - flag )         | Push one                                                            |
| FALSE           | ( - flag )         | Push zero                                                           |
| BL              | ( - n )            | Push 32, the ASCII code of space character                          |
| PAD             | ( - n )            | Push the address of PAD (2701 in hex)                               |
| BASE            | ( - addr )         | Push the address of built-in numeric base variable                  |
| DECIMAL         | ( - )              | Switch numeric base to decimal (shortcut for 10 BASE C!)            |
| HEX             | ( - )              | Switch numeric base to hexadecimal (shortcut for 16 BASE C!)        |

Note: names of constants (i.e. TRUE, FALSE, BL and PAD) are always written in upper-case!

### Logical Operations

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| =          | ( n1 n2 - flag )   | Compare n1 = n2 and set flag accordingly                            |
| <          | ( n1 n2 - flag )   | Compare n1 < n2 and set flag accordingly                            |
| >          | ( n1 n2 - flag )   | Compare n1 > n2 and set flag accordingly                            |
| 0=         | ( n - flag )       | Compare n = 0 and set flag accordingly                              |
| 0<         | ( n - flag )       | Compare n < 0 and set flag accordingly                              |
| 0>         | ( n - flag )       | Compare n > 0 and set flag accordingly                              |
| NOT        | ( n - flag )       | Same as 0=, used to denote inversion of a flag                      |


### Control Flow

| Word           | Stack              | Description                                                                       |
| -------------- | ------------------ | --------------------------------------------------------------------------------- |
| IF             | ( flag - )         | If flag is zero, skip to next ELSE or THEN, otherwise continue to next statement  |
| ELSE           | ( - )              | See IF                                                                            |
| THEN           | ( - )              | See IF                                                                            |
| BEGIN          | ( - )              | Mark the beginning of indefinite or until loop                                    |
| UNTIL          | ( flag - )         | If flag is zero, jump to previous BEGIN, otherwise continue to next statement     |
| AGAIN          | ( - )              | Jump (unconditionally) to previous BEGIN                                          |
| DO             | ( n1 n2 - )        | Initialize do loop, n1 is the limit value, n2 is the initial value of counter     |
| LOOP           | ( - )              | Increment loop counter by 1, jump to previous DO if counter has not reached limit |
| +LOOP          | ( n - )            | Add n to counter, jump to previous DO if counter has not reached limit            |
| REPEAT         | ( - )              | Not supported currently!                                                          |
| WHILE          | ( - )              | Not supported currently!                                                          |
| EXIT           | ( - )              | Exit immediately from current word (make sure return stack is balanced!)          |
| I              | ( - n )            | Push the loop counter of innermost loop                                           |
| I'             | ( - n )            | Push the limit value of innermost loop                                            |
| J              | ( - n )            | Push the loop counter of second innermost loop                                    |
| LEAVE          | ( - )              | Set the loop counter to limit for innermost loop                                  |
| LABEL \<name\> | ( - )              | Mark the current position in dictionary with a label                              |
| GOTO \<name\>  | ( - )              | Jump to a label defined in the current word definition                            |


### Input and Output

| Word       | Stack              | Description                                                       |
| ---------- | ------------------ | ----------------------------------------------------------------- |
| .          | ( n - )            | Print value using current numeric base followed by space          |
| ."         | ( - )              | Print the following characters until terminating "                |
| .S         | ( - )              | Print the contents of the data stack                              |
| CR         | ( - )              | Print newline character                                           |
| SPACE      | ( - )              | Print space character                                             |
| SPACES     | ( n - )            | Print n space characters                                          |
| EMIT       | ( n - )            | Print character, where n is the ASCII code                        |
| IN         | ( port - n )       | Read a 8-bit value from I/O port                                  |
| OUT        | ( n port - )       | Write a 8-bit value to I/O port                                   |
| AT         | ( y x - )          | Move the cursor to column x on row y                              |
| TYPE       | ( addr n -- )      | Print a string stored in memory                                   |
| PLOT       | ( x y n - )        | Plot a pixel at x, y with mode n (0=unplot, 1=plot, 2=move, 3=change) | 
| INKEY      | ( - n )            | Read current pressed key (0 = not pressed)                        | 
| CLS        | ( - )              | Clear the screen                                                  | 
| BEEP       | ( m n - )          | Play sounds (8*m = period in us, n = time in ms)                  | 
| #          |                    |                                                                   |
| #S         |                    |                                                                   |
| U.         |                    |                                                                   |
| #>         |                    |                                                                   |
| <#         |                    |                                                                   |
| SIGN       |                    |                                                                   |
| HOLD       |                    |                                                                   |
| LINE       |                    |                                                                   |
| WORD       |                    |                                                                   |
| NUMBER     |                    |                                                                   |
| RETYPE     |                    |                                                                   |
| QUERY      |                    |                                                                   |
| CONVERT    |                    |                                                                   |
