( Program for printing the contents of memory )
( For example, the following dumps the first 32 bytes of the word HELLO: FIND HELLO 32 DUMP )

: dump ( address count -- )
	hex
	0 do
		i 7 and 0= if cr then ( Line break every 8 bytes )
		dup i + c@ ( Fetch byte )
		dup 16 < if ascii 0 emit then  ( Prefix with "0" if byte is less than 10 in hex )
		.
	loop ;

( Test code to dump )
: hello ." world" ;
