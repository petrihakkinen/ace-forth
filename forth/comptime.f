( Compiler interpreter mode tests )

." 3 + 2  ->  " 3 2 + . CR
." 3 - 2  ->  " 3 2 - . CR
." 3 * 2  ->  " 3 2 * . CR
." 6 / 2  ->  " 6 2 / . CR
." 3 DUP + .  ->  " 3 DUP + . CR
." 3 4 DROP .  ->  " 3 4 DROP . CR
." 1 2 SWAP . .  ->  " 1 2 SWAP . . CR
." 1 2 3 ROT . . .  ->  " 1 2 3 ROT . . . CR
." 1 2 3 3 PICK . . . .  ->  " 1 2 3 3 PICK . . . . CR
." 1 2 3 3 ROLL . . . ->  " 1 2 3 3 ROLL . . . CR
." *" SPACE SPACE ." *" CR
." *" 5 SPACES ." *" CR
ASCII * EMIT CR

." HERE is " HEX HERE . DECIMAL CR

." 128 in hex is " 128 HEX . DECIMAL CR
." 128 in binary is " 128 2 BASE ! . DECIMAL CR

." hex FF in decimal is " HEX FF DECIMAL . CR
." binary 1100 in decimal is " 2 BASE ! 1100 DECIMAL . CR

: TEST[]
	[ ." Compiling Test " CR 123 ]
	CR
	[ ." Popping value " . CR ] ;

( Test [IF] )

1 [IF]
	." This should be printed" CR
[THEN]

1 [IF]
	." This should be printed" CR
[ELSE]
	." This should NOT be printed" CR
[THEN]

0 [IF]
	." This should NOT be printed" CR
[ELSE]
	." This should be printed" CR
[THEN]

[DEFINED] CR [IF] ." CR is defined" CR [THEN]
[DEFINED] ABC NOT [IF] ." ABC is not defined" CR [THEN]