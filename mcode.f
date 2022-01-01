( Test Machine Code Compilation )

:m test 5 3 swap drop dup . . ;

:m test-begin-until
	ascii * emit
	1 0 0 0 0
	begin
		ascii A emit
	until 
	ascii * emit ;

:m arith
	3 4 + . ( 7 )
	3 4 - . ( -1 )
	5 1+ . ( 6 )
	5 1- . ( 4 )
	12345 negate . ( -12345 )
	-12345 negate . ( 12345 )
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

: time ( -- time )
	252 in ( lo byte )
	253 in ( hi byte )
	256 * + ;

: begin-profile ( -- start-time ) time ;

: end-profile ( start-time -- ) time swap - ." RESULT: " . ;

( 3710 -> 2401 = 1.5 times faster )
:m speed-test
	10000
	begin
		1-
		dup 0=
	until
	drop ;

: dump ( address count -- )
	16 base c!
	0 do
		i 7 and 0= if cr then ( Line break every 8 bytes )
		dup i + c@ ( Fetch byte )
		dup 16 < if ascii 0 emit then  ( Prefix with "0" if byte is less than 10 in hex )
		.
	loop
	decimal ; immediate

find test 2+ 10 dump

: main
	fast
	cr test ( prints 3 3 )
	cr test-begin-until ( prints "*AAAAA*" )
	cr arith ( prints 4 6 -1 7 )
	cr arith-funcs
	cr boolean-ops ( prints 12164 89 32760 )
	cr rel-ops ( prints 1 0 1 0 0 1 0 0 )
	cr begin-profile speed-test end-profile
	;