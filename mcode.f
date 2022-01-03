( Test Machine Code Compilation )

hex
2400 const SCREEN
decimal

code di 243 c, 253 c, 233 c, 
code ei 251 c, 253 c, 233 c, 

:m stack
	123 dup . . ( 123 123 )
	456 123 drop . ( 456 )
	45 67 over . . . ( 45 67 45 )
	72 ?dup . . ( 72 72 )
	0 ?dup 1 . . ( 1 0 )
	;

:m stack2
	3 4 2 pick . . . ( 3 4 3 )
	1 2 2 roll . . ( 1 2 )
	1 2 3 3 roll . . . ( 1 3 2 )
	3 7 >r . r> . ( 3 7 )
	;

( Test calling another mcode word from mcode word )
\ :m test1 1 ;
\ :m test2 test1 . ;

( Test calling another user defined Forth word from mcode word )
: push1 1 ;
:m call-forth push1 . ;

:m pull-speaker 65278 in drop ;
:m push-speaker 0 65278 out ;

: in-out
	500 0 do
		pull-speaker
		100 0 do loop
		push-speaker
		100 0 do loop
	loop ;

( This crashes! But works with regular colon definition... )
:m in-out-crash
	12345
	100 begin
		65278 in drop ( pull speaker )
		100 begin 1- dup 0= until drop 
		0 65278 out ( push speaker )
		100 begin 1- dup 0= until drop 
		1- dup 0=
	until drop . ;

:m arith
	3 4 + . ( 7 )
	3 4 - . ( -1 )
	5 1+ . ( 6 )
	5 1- . ( 4 )
	1234 negate . ( -1234 )
	-1234 negate . ( 1234 )
	1000 5 * . ( 5000 )
	-123 5 * . ( -615 )
	5 50 c* . ( 250 )
	;

:m arith-funcs
	4892 abs . ( 4892 )
	-4892 abs . ( 4892 )
	7000 123 min . ( 123 )
	-7000 123 min . ( -7000 )
	7000 123 max . ( 7000 )
	-7000 123 max . ( 123 )
	;

:m boolean-ops
 	10123 2063 xor . ( 12164 )
 	11131 1241 and . ( 89 )
 	7072 32120 or . ( 32760 )
 	;

:m rel-ops
	0 0= . ( 1 )
	256 0= . ( 0 )

	-123 0< . ( 1 )
	0 0< . ( 0 )
	123 0< . ( 0 )

	5 0> . ( 1 )
	0 0> . ( 0 )
	-5 0> . ( 0 )

	3 5 = . ( 0 )
	12345 12345 = . ( 1 )
	-12345 12345 = . ( 0 )

	3 5 > . ( 0 )
	5 -3 > . ( 1 )
	0 0 > . ( 0 )

	3 5 < . ( 1 )
	5 -3 < . ( 0 )
	0 0 < . ( 0 )
	;

:m mem 
	SCREEN c@ ( read char 'm' )
	SCREEN 20 + c! ( write char )
	SCREEN @ ( read short 'ma' )
	SCREEN 24 + ! ( write short )
	;

:m print
	cr ascii * emit
	cr space ascii * emit
	cr space space ascii * emit
	cr 3 spaces ascii * emit
	10 10 at
	15424 5 type ( print "FORTH" )
	space ." RULES"
	;

:m test-base
	16 base c! 255 . ( ff )
	decimal 255 . ( 255 )
	;

:m test-inkey 
	begin
		cr inkey .
	0 until ;

:m if-then
	1 if ." TRUE " then
	0 if ." TRUE" else ." FALSE" then
	;

:m begin-until
	ascii * emit
	1 0 0 0 0
	begin
		ascii A emit
	until 
	ascii * emit ;

:m begin-again
	begin
		ascii * emit
	again ;

:m do-loop
	2 0 do
		5 0 do
			i j + .
		loop
	loop
	100 0 do
		ascii * emit leave
	loop ;

:m test-goto
	goto skip
	." NOT PRINTED"
	label skip
	." HERE" ;

:m test-lit [ 5 3 * ] lit . ;

( 11986 -> 4714, 2.5 times faster )
:m benchmark-stack
	10000 begin
		dup dup dup dup dup drop drop drop drop drop
		1-
		dup 0=
	until drop ;

( 9 times faster! )
:m benchmark-over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	over over over over over over over over over over
	;

( 3454 -> 869 -> 4 times faster! )
:m benchmark-do-loop
	30000 0 do
	loop ;

( 3430 -> 2269 -> 1.5 times faster )
:m benchmark-*
	2
	1000 0 do
		2 * 7 * 123 * 256 * 789 *
	loop drop ;

( 2230 -> 986 -> 2.3 times faster )
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

: end-profile ( start-time -- ) time swap - ." RESULT: " . ;

: dump ( address count -- )
	16 base c!
	0 do
		i 7 and 0= if cr then ( Line break every 8 bytes )
		dup i + c@ ( Fetch byte )
		dup 16 < if ascii 0 emit then  ( Prefix with "0" if byte is less than 10 in hex )
		.
	loop
	decimal ; immediate

: main
	fast di
	cr call-forth
	cr stack
	cr stack2
	cr arith ( prints 4 6 -1 7 )
	cr arith-funcs
	cr boolean-ops ( prints 12164 89 32760 )
	cr rel-ops ( prints 1 0 1 0 0 1 0 0 )
	\ cr begin-profile speed-test end-profile
	\ cr begin-profile benchmark-stack end-profile
	\ cr begin-profile benchmark-over end-profile
	\ cr begin-profile benchmark-do-loop end-profile
	\ cr begin-profile benchmark-c* end-profile
	\ in-out
	cr test-base
	mem
	cr if-then ( prints TRUE FALSE )
	cr test-goto ( prints HERE )
	cr test-lit ( prints 15 )
	cr begin-until ( prints *AAAAA* )
	cr cr do-loop ( prints 0 1 2 3 4 1 2 3 4 5 * )
	\ begin-again
	cr print
	\ test-inkey
	;