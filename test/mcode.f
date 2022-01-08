( Test Machine Code Compilation )

hex
2400 const SCREEN
3C37 const STKBOT
3C3B const SPARE
decimal

100 variable v

1 variable one
2 variable two
3 variable three

-1 variable minus-one
-2 variable minus-two
-3 variable minus-three

code di 243 c, 253 c, 233 c, 
code ei 251 c, 253 c, 233 c, 

: fail ." FAILED!" abort ;

:m chk ( result expected -- )
	= if ." OK" else fail then ;

:m chk2 ( result1 result2 expected1 expected2 -- )
	rot = >r ( s: result1 expected1 ; r: eq2 )
	= r> ( s: eq1 eq2 )
	and if ." OK" else fail then ;

:m chk3 ( result1 result2 result3 expected1 expected2 expected3 -- )
	4 roll = >r ( s: result1 result2 expected1 expected2 ; r: eq3 )
	3 roll = >r ( s: result1 expected1 ; r: eq3 eq2 )
	= r> r> ( s: eq1 eq2 eq3 )
	and and if ." OK" else fail then ;

:m stack
	." DUP    " 123 dup          123 123 chk2 cr
	." DROP   " 123 456 drop     123 chk cr
	." NIP    " 1 2 3 nip        1 3 chk2 cr
	." OVER   " 123 456 over     123 456 123 chk3 cr
	." ?DUP   " 123 ?dup         123 123 chk2 space
	            123 0 ?dup 456   123 0 456 chk3 cr
	." SWAP   " 123 456 swap     456 123 chk2 cr
	." 2DUP   " 123 456 2dup     123 456 chk2 space 123 456 chk2 cr
	." 2DROP  " 1 2 3 2drop      1 chk cr
	." 2OVER  " 1 2 3 4 2over    1 2 chk2 3 4 space chk2 space 1 2 chk2 cr
	." PICK   " 3 4 2 pick       3 4 3 chk3 cr
	." ROLL   " 1 2 2 roll       2 1 chk2 space
	            1 2 3 3 roll     2 3 1 chk3 cr
	." ROT    " 1 2 3 rot        2 3 1 chk3 cr
	." >R R>  " 3 7 >r           3 chk space r> 7 chk cr
	." R@     " 1 2 >r r@        1 2 chk2 cr    ( Clean up: ) r> drop
	;

:m arith
	." +      " 3 4 +            7 chk space      ( n + literal )
	            -1000 -2000 +    -3000 chk space
	            500 v @ +        600 chk cr	      ( n + n )

	." -      " 3 4 -            -1 chk space     ( n - literal )
	            -1000 -2000 -    1000 chk space
	            500 v @ -        400 chk cr       ( n - n )    

	." *      " 1000 5 *         5000 chk space   ( n * literal )
	            -123 5 *         -615 chk space
	            -123 0 *         0 chk space      ( 0 specialization )
	            -123 1 *         -123 chk space   ( 1 specialization )
	            -123 2 *         -246 chk space   ( 2 specialization )
	            -123 4 *         -492 chk space   ( 4 specialization )
	            -123 256 *       -31488 chk space ( 256 specialization )
	            100 v @ *        10000 chk cr     ( n * n )

	." C*     " 5 50 c*          250 chk space    ( n * literal )
	            2 v @ c*         200 chk space    ( n * value )
	            3 1 c*           3 chk space      ( 1 specialization )
	            3 2 c*           6 chk space      ( 2 specialization )
	            3 4 c*           12 chk space     ( 4 specialization )
	            3 256 c*         0 chk cr         ( out of range specialization )

	." /      " 1000 3 /         333 chk space    ( Generic algorithm )
                1000 1 /         1000 chk space   ( 1 specialization )
                1000 2 /         500 chk space    ( 2 specialization )
                1000 4 /         250 chk space    ( 4 specialization )
                1000 256 /       3 chk cr         ( 256 specialization )

	." 1+     " 5 1+             6 chk cr

	." 1-     " 5 1-             4 chk cr

	." 2+     " 1000 2+          1002 chk cr

	." 2-     " 1000 2-          998 chk cr

	." 2*     " 1000 2*          2000 chk space
	            -1000 2*         -2000 chk cr

	." 2/     " 1000 2/          500 chk space
	            -1000 2/         -500 chk cr

	." NEGATE " 1234 negate      -1234 chk space
	            -1234 negate     1234 chk cr

	." ABS    " 4892 abs         4892 chk space
	            -4892 abs        4892 chk cr

	." MIN    " 7000 123 min     123 chk space
	            -7000 123 min    -7000 chk cr

	." MAX    " 7000 123 max     7000 chk space
	           -7000 123 max     123 chk cr

	[ hex ]
 	." XOR    " 1234 1111 xor    0325 chk space   ( n xor literal )
 				1fff v @ xor	 1f9b chk space   ( n xor n )
 				1234 0 xor       1234 chk space   ( 0 specialization )
 				1234 11 xor	     1225 chk space   ( lo byte only )
 				1234 1100 xor	 0334 chk cr      ( hi byte only )

 	." AND    " 7777 1f1f and    1717 chk space   ( n and literal )
 	            0ff0 v @ and     60 chk space     ( n and n )
 	            ffff 11 and      11 chk space     ( lo byte only )
 	            ffff fa00 and    fa00 chk space   ( hi byte only )
 	            1234 ff and      34 chk space     ( select lo byte )
 	            1234 ff00 and    1200 chk cr      ( select hi byte )

 	." OR     " 1234 f0f0 or     f2f4 chk space   ( n or literal )
 	            f0 v @ or        f4 chk space     ( n or n )
 	            1234 ff or       12ff chk space   ( set lo byte )
 	            1234 ff00 or     ff34 chk space   ( set hi byte )
 	[ decimal ]
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

	." C=     " 3 5 c=           0 chk space
	            50 50 c=         1 chk space
	            257 1025 c=      1 chk space	( Only hi bytes differ )
	            -50 50 c=        0 chk cr

	." >      " 3000 5000 >      0 chk space
	            5000 -3000 >     1 chk space
	            0 0 >            0 chk cr

	." <      " 3000 5000 <      1 chk space
	            5000 -3000 <     0 chk space
	            0 0 <            0 chk cr
	;

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
	." IF     " 1 2 if 3 then                  1 3 chk2 space
	            1 0 if 2 else 3 then           1 3 chk2 cr

	." UNTIL  " 6 1 0 0 begin 5 >r until       r> r> r> 5 5 5 chk3 space 6 chk cr

	." AGAIN  " test-again                     1024 chk cr

	." LOOP   " 0 1000 -100 do i + loop        -29838 chk space ( 16-bit )
				0 100 0 do i + loop            4950 chk space ( 8-bit )
	            0 three @ one @ do i + loop    3 chk space ( Non-literal counter & limit )
				0 10 20 do i + loop            20 chk space ( "Invalid loop" )
	            test-loop                      25 chk space
	            test-leave                     11 chk cr

	." +LOOP  " 0 500 -300 do i + 2 +loop      -25936 chk space ( Count up )
	            0 -300 500 do i + -3 +loop     26967 chk space ( Count down )
	            0 500 -300 do i + two @ +loop  -25936 chk space ( Generic, count up )
	            0 -300 500 do i + minus-three @ +loop     26967 chk cr ( Generic, count down )

	." I'     " 0 10 0 do i' + loop            100 chk cr

	." GOTO   " 5 goto skip 6 label skip       5 chk space ( Forward goto )
	            test-goto                      120 chk cr ( Backward goto )
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
	." BASE   " 8 base c! 255 . cr ( ff )
	." HEX    " hex 255 . cr ( ff )
	." DEC    " decimal 255 . cr ( 255 )
	." .S     " 1 2 3 .s drop drop drop cr
	;

:m i/o
	." INKEY  " test-inkey cr
	." IN OUT " test-in-out cr    12345 chk cr
	;

:m benchmark-stack
	10000 0 do
		dup dup dup dup dup dup dup dup dup dup
		drop drop drop drop drop drop drop drop drop drop
	loop ;

:m benchmark-over
	100 0 do
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
		over over over over over over over over over over
		STKBOT @ 14 + SPARE ! ( Reset stack, except profile start time )
	loop ;

:m benchmark-loop
	200 0 do
		200 0 do loop
	loop ;

:m benchmark-rstack
	5000 0 do
		>r r> >r r> >r r> >r r> >r r> >r r> >r r> >r r> 
		>r r> >r r> >r r> >r r> >r r> >r r> >r r> >r r> 
	loop ;

:m benchmark-arith
	5
	10000 0 do
		dup + dup + dup + dup + dup - dup - dup - dup -
	loop drop ;

:m benchmark-arith2
	5
	10000 0 do
		1 + 2 + 3 + 4 + 5 +
		1 - 2 - 3 - 4 - 5 -
	loop drop ;

:m benchmark-1+
	0
	10000 0 do
		1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+ 1+
	loop drop ;

:m benchmark-2*
	5000 0 do
		3 2* 2* 2* 2* 2* 2* 2* 2* 2* drop
	loop ;

:m benchmark-2/
	500 0 do
		31111 2/ 2/ 2/ 2/ 2/ 2/ 2/ 2/ 2/ drop
	loop ;

:m benchmark-*
	2
	1000 0 do
		2 * 7 * 123 * 256 * 789 *
	loop drop ;

:m benchmark-c*
	2
	1000 0 do
		2 c* 5 c* 9 c* 10 c* 7 c*
	loop drop ;

: time ( -- time )
	252 in ( lo byte )
	253 in ( hi byte )
	256 * + ;

: begin-profile ( -- start-time ) time ;

: end-profile ( start-time -- )
	time swap - .
	1- ( subtract time taken by profiling code )
	cr ;

: main
	fast di cls invis
	stack
	arith
	rel-ops
	mem
	inter-op
	control-flow
	print
	misc

	cr ." Running benchmarks..." cr
	." STACK  " begin-profile benchmark-stack end-profile 	    ( 17829 -> 5721, 3.1 times faster )
	." OVER   " begin-profile benchmark-over end-profile		( 2257 -> 237, 9.5 times faster )
	." LOOP   " begin-profile benchmark-loop end-profile		( 4676 -> 621, 7.5 times faster )
	." >R R>  " begin-profile benchmark-rstack end-profile 	    ( 11088 -> 5022, 2.2 times faster )
	." ARITH  " begin-profile benchmark-arith end-profile	    ( 24795 -> 5242, 4.7 times faster )
	." ARITH2 " begin-profile benchmark-arith2 end-profile	    ( 27137 -> 792, 34 times faster )
	." 1+     " begin-profile benchmark-1+ end-profile		    ( 12266 -> 466, 26 times faster )
	." 2*     " begin-profile benchmark-2* end-profile		    ( 14248 -> 634, 22 times faster )
	." 2/     " begin-profile benchmark-2/ end-profile		    ( 19151 -> 65, 294 times faster )
	." *      " begin-profile benchmark-* end-profile		    ( 3430 -> 1237, 2.8 times faster )
	." C*     " begin-profile benchmark-c* end-profile		    ( 3430 -> 529, 6.5 times faster )

	cr i/o

	cr ." All tests passed!"
	;
