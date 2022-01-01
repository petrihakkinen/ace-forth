( Test Machine Code Compilation )

:m test swap drop dup ;

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

: main 5 3 test . . ;