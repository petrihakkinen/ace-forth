16 base c! ( Print and parse all numbers as hex )

: dump ( address count -- )
	0 do
		i 7 and 0= if cr then ( Line break every 8 bytes )
		dup i + c@ ( Fetch byte )
		dup 10 < if ascii 0 emit then  ( Prefix with "0" if byte is less than 10 in hex )
		.
	loop ;

( Test code to dump )
: hello ." world" ;

invis cls
find hello 40 dump
