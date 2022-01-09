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
	  --no-warn                 Disable all warnings
	  --verbose                 Print information while compiling
	  --main <name>             Sets name of main executable word (default 'main')
	  --filename <name>         Sets the filename for tap header (default 'dict')

On Windows which does not support shebangs you need to prefix the command line with path to the Lua interpreter.


## Differences with Jupiter Ace Forth Interpreter

- Word names are case sensitive by default. However, you can turn off case sensitivity using the `--ignore-case` option. When in case sensitive mode, standard word names should be written in lower case (e.g. `dup` instead of `DUP`).

- Floating point literals are not currently supported.

- Words `DEFINER`, `DOES>` and `RUNS>` are not supported. The usual interpreter words `IMMEDIATE`, `POSTPONE`, `[`, `]`, `HERE` etc. are supported though.

- `WHILE` and `REPEAT` are not currently supported. They should be easy to add if needed though.

- Some commonly used words have been shortened: `CONSTANT` -> `CONST`, `LITERAL` -> `LIT`.


## News Words and Features

The compiler supports many extras not found on Jupiter Ace's Forth implementation. Some of the features are unique to this compiler. The new features are too numerous to list here, refer to the index at the end of this document. Some highlights:

- New control flow words `GOTO` and `LABEL`.

- Infinite loops using `BEGIN` and `AGAIN` words are supported (you can jump out of them using `EXIT` or `GOTO`).

- New interpreter words: `[IF]`, `[ELSE]`, `[THEN]`, and `[DEFINED]` for conditionally compiling code (e.g. for stripping debug code).

- Line comments using `\` word are supported.

- New variable defining word `BYTE`, which works like `VARIABLE` but defines byte sized variables (remember to use `C@` and `C!` to access them).

- New defining word `:m` which compiles the word into native machine code.

- New words: `NIP` `2DUP` `2DROP` `2OVER` `R@` `2*` `2/` `C*` `.S` `HEX` `CODE` `POSTPONE` ...


## Machine Code Compilation

The word `:m` allows compiling words into native machine code. Such words can be several times sometimes even an order of magnitude, faster. Machine code words can be called from normal Forth words and vice versa. 

A simple example of a machine code word:

	:m stars 10 0 do ascii * emit loop ;

Machine code words, however, have some disadvantages:

- They take up more program space. If program size is important, you should consider compiling only the most often used words as machine code.

- Machine code words are not relocatable. Therefore, when you load a program containing machine code words, there should be no other user defined words defined previously.

### Performance Considerations

Some words contained inside `:m` definitions cannot be compiled into machine code currently. Therefore, there is a performance penalty when the following words are used inside `:m` definitions:

	FNEGATE F+ F- F* F/ F. UFLOAT INT D+ D< DNEGATE U/MOD */ MOD */MOD /MOD U. U* U<
	. # #S #> <# SIGN HOLD
	CLS SLOW FAST INVIS VIS ABORT QUIT LINE WORD NUMBER CONVERT RETYPE QUERY
	PLOT BEEP EXECUTE CALL

It's strongly recommended to not use any of these words inside `:m` definitions!

The words `*` and `/`, when compiled to machine code, have specializations for values 1, 2, 4 and 256. Multiplying or dividing by any of these values is very fast. Division by any other value falls so the Forth interpreter code which is very slow.

For 8-bit multiplication where both operands and the result fits into 8 bits, it is recommended to use the new word `C*` (it is more than twice as fast as `*` when compiled to machine code).

The following table contains some benchmark results comparing the speed of machine code compiled Forth vs. interpreted Forth running on the Jupiter Ace. "Speed up" is how many times faster the machine code version runs.

| Benchmark        | Speed up  | Notes                      |
| ---------------- | --------- | -------------------------- |
| Stack ops        | 3.1       | DUP DROP                   |
| OVER             | 9.5       |                            |
| Arithmetic       | 4.7       | + -                        |
| DO LOOP          | 7.5       |                            |
| 1+               | 26        |                            |
| 2*               | 22        |                            |
| 2/               | 294       |                            |
| *                | 2.8       | 16-bit multiply            |
| C*               | 6.5       | 8-bit multiply             |


## Word Index

The following letters are used to denote values on the stack:

- `n` number (16-bit signed integer)
- `d` double length number (32-bit signed integer) occupying two stack slots
- `f` floating point number occupying two stack slots
- `flag` a boolean flag with possible values 1 (representing true) and 0 (representing false)
- `addr` numeric address in the memory (where compiled words and variables go)

### Stack Manipulation

| Word       | Stack                           | Description                                                         |
| ---------- | ------------------------------- | ------------------------------------------------------------------- |
| DUP        | ( n - n n )                     | Duplicate topmost stack element                                     |
| ?DUP       | ( n - n n )                     | Duplicate topmost stack element unless it is zero                   |
| DROP       | ( n - )                         | Remove topmost stack element                                        |
| NIP        | ( n1 n2 - n2 )                  | Remove the second topmost stack element                             |
| OVER       | ( n1 n2 - n1 n2 n1 )            | Duplicate the second topmost stack element                          |
| SWAP       | ( n1 n2 - n2 n1 )               | Swap two elements                                                   |
| ROT        | ( n1 n2 n3 - n2 n3 n1 )         | Rotate three topmost stack elements                                 |
| PICK       | ( n - n )                       | Duplicate the Nth topmost stack element                             |
| ROLL       | ( n - )                         | Extract the Nth element from stack, moving it to the top            |
| 2DUP       | ( n1 n2 - n1 n2 n1 n2 )         | Duplicate two topmost stack elements                                |
| 2DROP      | ( n n - )                       | Remove two topmost stack elements                                   |
| 2OVER      | ( n1 n2 n n - n1 n2 n n n1 n2 ) | Duplicates two elements on the stack                                |
| >R         | S: ( n - ) R: ( - n )           | Move value from data stack to return stack                          |
| R>         | S: ( - n ) R: ( n - )           | Move value from return stack to data stack                          |
| R@         | S: ( - n ) R: ( n - n )         | Copy value from return stack to data stack (without removing it)    |

### Arithmetic

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| +          | ( n n - n )        | Add two integers                                                    |
| -          | ( n n - n )        | Subtract two integers                                               |
| *          | ( n n - n )        | Multiply two integers                                               |
| C*         | ( n n - n )        | Multiply two 8-bit integers                                         |
| /          | ( n1 n2 - n )      | Divide n1 by n2                                                     |
| 1+         | ( n - n )          | Increment value by 1                                                |
| 1-         | ( n - n )          | Decrement value by 1                                                |
| 2+         | ( n - n )          | Increment value by 2                                                |
| 2-         | ( n - n )          | Decrement value by 2                                                |
| 2*         | ( n - n )          | Multiply value by 2                                                 |
| 2/         | ( n - n )          | Divide value by 2                                                   |
| NEGATE     | ( n - n )          | Negate value                                                        |
| ABS        | ( n - n )          | Compute the absolute value                                          |
| MIN        | ( n1 n2 - n )      | Compute the minimum of two integers                                 |
| MAX        | ( n1 n2 - n )      | Compute the maximum of two integers                                 |
| AND        | ( n n - n )        | Compute the bitwise and of two integers                             |
| OR         | ( n n - n )        | Compute the bitwise or of two integers                              |
| XOR        | ( n n - n )        | Compute the bitwise exlusive or of two integers                     |
| F+         | ( f f - f )        | Add two floating point numbers                                      |
| F-         | ( f f - f )        | Subtract two floating point numbers                                 |
| F*         | ( f f - f )        | Multiply two floating point numbers                                 |
| F/         | ( f f - f )        | Divide two floating point numbers                                   |
| F.         | ( f - )            | Print floating point number                                         |
| FNEGATE    | ( f - f )          | Negate floating point number                                        |
| D+         | ( d d -  d )       | Add two double length integers                                      |
| DNEGATE    | ( d - d )          | Negate double length integer                                        |
| U/MOD      |                    |                                                                     |
| */         |                    |                                                                     |
| MOD        |                    |                                                                     |
| */MOD      |                    |                                                                     |
| /MOD       |                    |                                                                     |
| U*         |                    |                                                                     |
| UFLOAT     |                    |                                                                     |
| INT        |                    |                                                                     |


### Comparison

| Word       | Stack              | Description                                                         |
| ---------- | ------------------ | ------------------------------------------------------------------- |
| =          | ( n1 n2 - flag )   | Compare n1 = n2 and set flag accordingly                            |
| C=         | ( n1 n2 - flag )   | Compare the low byte of n1 and n2 for equality. Faster than =       |
| <          | ( n1 n2 - flag )   | Compare n1 < n2 and set flag accordingly                            |
| >          | ( n1 n2 - flag )   | Compare n1 > n2 and set flag accordingly                            |
| D<         | ( d1 d1 - flag )   | Compute less than of two double length integers                     |
| U<         | ( n1 n2 - flag )   | Compute less than of two integers, interpreting them as unsigned numbers |
| 0=         | ( n - flag )       | Compare n = 0 and set flag accordingly                              |
| 0<         | ( n - flag )       | Compare n < 0 and set flag accordingly                              |
| 0>         | ( n - flag )       | Compare n > 0 and set flag accordingly                              |
| NOT        | ( n - flag )       | Same as 0=, used to denote inversion of a flag                      |


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
| "                 | ( - )              | Enclose the following characters up until " into the dictionary         |
| (                 | ( - )              | Block comment; skip characters until next )                             |
| \                 | ( - )              | Line comment; skip characters until end of line                         |
| [                 | ( - )              | Change from compile to interpreter state                                |
| ]                 | ( - )              | Change from interpreter to compile state                                |
| CREATE \<name\>   | ( - )              | Add new (empty) word to dictionary with name \<name\>                   |
| CREATE{ \<name\>  | ( - )              | Same as CREATE, except the end of the word must be marked with }        |
| }                 | ( - )              | Marks the end of word created with CREATE{ (for dead code elimination)  |
| CODE \<name\>     | ( - )              | Defines a new word with machine code defined as following bytes of data |
| CONST \<name\>    | ( n - )            | Capture value to a new word with name \<name\>                          |
| VARIABLE \<name\> | ( n - )            | Create new 16-bit variable with name \<name\> and with initial value n  |
| BYTE \<name\>     | ( n - )            | Create new 8-bit variable with name \<name\> and with initial value n   |
| BYTES             | ( n - )            | Enclose to the dictionary all bytes pushed on the stack between BYTES and ;BYTES |
| ;BYTES            | ( - )              | Mark the end of BYTES.                                                  |
| ALLOT             | ( n - )            | Allocates space for n elements from output dictionary                   |
| ASCII \<char\>    | ( - (n) )          | Emit literal containing the ASCII code of the following symbol          |
| HERE              | ( - n )            | Push the address of the next free location in output dictionary         |
| LIT               | ( n - )            | Emit value from data stack to output dictionary                         |
| IMMEDIATE         | ( - )              | Mark the previous word to be executed immediately when compiling        |
| POSTPONE \<name\> | ( - )              | Write the compilation address of word \<name\> into the dictionary      |
| NOINLINE          | ( - )              | Prevent inlining of previously added word                               |
| [IF]              | ( flag - )         | Pop a value from compiler stack. If zero, skip until next [ELSE] or [THEN]. |
| [ELSE]            | ( - )              | See [IF]                                                                |
| [THEN]            | ( - )              | See [THEN]                                                              |
| [DEFINED] \<name\> | ( - flag )        | If word named \<name\> is defined, push 1 to compiler stack. Otherwise push 0. |
| FAST              | ( - )              | Turn off stack underflow check                                          |
| SLOW              | ( - )              | Turn on stack underflow check                                           |
| DI                | ( - )              | Disable interrupts                                                      |
| EI                | ( - )              | Enable interrupts                                                       |
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
