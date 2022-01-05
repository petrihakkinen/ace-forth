( Test Machine Code Compilation )

hex
2400 const SCREEN
decimal

code di 243 c, 253 c, 233 c, 
code ei 251 c, 253 c, 233 c, 

: fail ." FAILED!" abort ;

: chk ( result expected -- )
	= if ." OK" else fail then ;

: chk2 ( result1 result2 expected1 expected2 -- )
	rot = >r ( s: result1 expected1 ; r: eq2 )
	= r> ( s: eq1 eq2 )
	and if ." OK" else fail then ;

: chk3 ( result1 result2 result3 expected1 expected2 expected3 -- )
	4 roll = >r ( s: result1 result2 expected1 expected2 ; r: eq3 )
	3 roll = >r ( s: result1 expected1 ; r: eq3 eq2 )
	= r> r> ( s: eq1 eq2 eq3 )
	and and if ." OK" else fail then ;

:m stack
	." DUP    " 123 dup          123 123 chk2 cr
	." DROP   " 123 456 drop     123 chk cr
	." OVER   " 123 456 over     123 456 123 chk3 cr
	." ?DUP   " 123 ?dup         123 123 chk2 space
	            123 0 ?dup 456   123 0 456 chk3 cr
	." SWAP   " 123 456 swap     456 123 chk2 cr
	." PICK   " 3 4 2 pick       3 4 3 chk3 cr
	." ROLL   " 1 2 2 roll       2 1 chk2 space
	            1 2 3 3 roll     2 3 1 chk3 cr
	." >R R>  " 3 7 >r           3 chk space r> 7 chk cr
	;

:m arith
	." +      " 3 4 +            7 chk cr
	." -      " 3 4 -            -1 chk cr
	." *      " 1000 5 *         5000 chk space
	            -123 5 *         -615 chk cr
	." C*     " 5 50 c*          250 chk cr
	." 1+     " 5 1+             6 chk cr
	." 1-     " 5 1-             4 chk cr
	." 2+     " 1000 2+          1002 chk cr
	." 2-     " 1000 2-          998 chk cr
	." NEGATE " 1234 negate      -1234 chk space
	            -1234 negate     1234 chk cr
	." ABS    " 4892 abs         4892 chk space
	            -4892 abs        4892 chk cr
	." MIN    " 7000 123 min     123 chk space
	            -7000 123 min    -7000 chk cr
	." MAX    " 7000 123 max     7000 chk space
	           -7000 123 max     123 chk cr
 	." XOR    " 10123 2063 xor   12164 chk cr
 	." AND    " 11131 1241 and   89 chk cr
 	." OR     " 7072 32120 or    32760 chk cr
	;

:m rel-ops
	." 0=     " 0 0=             1 chk space
	            256 0=           0 chk cr

	." 0<     " -5000 0<         1 chk space
	            0 0<             0 chk space
	            5000 0<          0 chk cr

	." 0>     " 5000 0>          1 chk space
	            0 0>             0 chk space
	            -5000 0>         0 chk cr

	." =      " 3 5 =            0 chk space
	            12345 12345 =    1 chk space
	            -12345 12345 =   0 chk cr

	." >      " 3000 5000 >      0 chk space
	            5000 -3000 >     1 chk space
	            0 0 >            0 chk cr

	." <      " 3000 5000 <      1 chk space
	            5000 -3000 <     0 chk space
	            0 0 <            0 chk cr
	;

0 variable v

:m mem
	." ! @    " 12345 v ! v @    12345 chk cr
	." C! C@  " 123 v c! v c@    123 chk cr
	;

:m test-again
	1
	begin
		dup +			
		dup 1000 > if exit then
	again ;

:m test-loop
	0
	2 0 do
		5 0 do
			i j + +
		loop
	loop ;

:m test-leave
	0
	100 0 do
		1+
		i 10 = if leave then
	loop ;

:m test-goto
	123 >r
	3
	label back
		r> 1- >r
		1-
	?dup if goto back then
	r> ;

:m control-flow
	." IF     " 1 2 if 3 then             1 3 chk2 space
	            1 0 if 2 else 3 then      1 3 chk2 cr

	." UNTIL  " 6 1 0 0 begin 5 >r until  r> r> r> 5 5 5 chk3 space 6 chk cr
	." AGAIN  " test-again                1024 chk cr
	." LOOP   " 0 1000 0 do i + loop      -24788 chk space
	            test-loop                 25 chk space
	            test-leave                11 chk cr
	." I'     " 0 10 0 do i' + loop       100 chk cr
	." GOTO   " 5 goto skip 6 label skip  5 chk space ( Forward goto )
	            test-goto                 120 chk cr ( Backward goto )
	;

: push1 1 ;

:m push1-mc 1 ;

:m inter-op
	." FCALL  " push1            1 chk cr ( Call Forth word from mcode word )
	." MCALL  " push1-mc         1 chk cr ( Call mcode word from mcode word )
	;

:m print
	." EMIT   " ascii * emit cr
	." SPACE  " space ascii * emit cr
	." SPACES "	2 spaces ascii * emit cr
	( 10 10 at )
	." TYPE   " 15424 5 type space ." RULES" cr
	;

:m test-in-out
	." PLAYING SOUND..."
	12345
	100 begin
		65278 in drop ( pull speaker )
		300 0 do loop
		0 65278 out ( push speaker )
		300 0 do loop
		1- dup 0=
	until drop ;

:m test-inkey 
	." *PRESS SPACE* "
	begin
		inkey 32 =
	until ;

:m misc
	." LIT    " [ 5 3 * ] lit      15 chk cr
	." CONST  " SCREEN             9216 chk cr
	." BASE   " 16 base c! 255 . cr ( ff )
	." DECIMAL " decimal 255 . cr ( 255 )
	." INKEY   " test-inkey cr
	." IN OUT  " test-in-out cr    12345 chk cr
	;

:m benchmark-stack
	10000 0 do
		dup dup dup dup dup dup dup dup dup dup
		drop drop drop drop drop drop drop drop drop drop
	loop ;

:m benchmark-over
	10 0 do
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
	loop ;

:m benchmark-loop
	30000 0 do
	loop ;

: benchmark-arith
	5
	10000 0 do
		dup + dup + dup + dup + dup - dup - dup - dup -
	loop drop ;

:m benchmark-1+
	0
	10000 0 do
		1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+
	loop drop ;

:m benchmark-*
	2
	1000 0 do
		2 * 7 * 123 * 256 * 789 *
	loop drop ;

( This benchmark cannot be run without it being compiled to machine code! )
:m benchmark-c*
	2
	1000 0 do
		2 c* 5 c* 8 c* 10 c* 7 c*
	loop drop ;

: time ( -- time )
	252 in ( lo byte )
	253 in ( hi byte )
	256 * + ;

: begin-profile ( -- start-time ) time ;

: end-profile ( start-time -- ) time swap - . cr ;

: main
	fast di cls invis
	stack
	arith
	rel-ops
	mem
	inter-op
	control-flow
	print
	\ misc
	cr ." All tests passed!" cr cr

	." Running benchmarks..." cr
	." STACK " begin-profile benchmark-stack end-profile 	( 17829 -> 5792, 3.1 times faster )
	." OVER  " begin-profile benchmark-over end-profile		( 222 -> 23, 9.7 times faster )
	." LOOP  " begin-profile benchmark-loop end-profile		( 3454 -> 943, 3.7 times faster )
	." ARITH " begin-profile benchmark-arith end-profile	( 24795 -> 5312, 4.7 times faster )
	." 1+    " begin-profile benchmark-1+ end-profile		( 12266 -> 537, 23 times faster )
	." *     " begin-profile benchmark-* end-profile		( 3430 -> 1996, 1.7 times faster )
	." C*    " begin-profile benchmark-c* end-profile		( 3430 -> 659,> 5.2 times faster )

	cr ." All done!"
	;
