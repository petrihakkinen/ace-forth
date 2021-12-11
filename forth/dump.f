16 BASE C! ( Print and parse all numbers as hex )

: DUMP ( address count -- )
	0 DO
		I 7 AND 0= IF CR THEN ( Line break every 8 bytes )
		DUP I + C@ ( Fetch byte )
		DUP 10 < IF ASCII 0 EMIT THEN  ( Prefix with "0" if byte is less than 10 in hex )
		.
	LOOP ;

( Test code to dump )
: HELLO ." WORLD" ;

INVIS CLS
FIND HELLO 40 DUMP
