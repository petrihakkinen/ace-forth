( Compiler interpreter mode tests )

." 3 + 2  ->  " 3 2 + . cr
." 3 - 2  ->  " 3 2 - . cr
." 3 * 2  ->  " 3 2 * . cr
." 6 / 2  ->  " 6 2 / . cr
." 3 dup + .  ->  " 3 dup + . cr
." 3 4 drop .  ->  " 3 4 drop . cr
." 1 2 swap . .  ->  " 1 2 swap . . cr
." 1 2 3 rot . . .  ->  " 1 2 3 rot . . . cr
." 1 2 3 3 pick . . . .  ->  " 1 2 3 3 pick . . . . cr
." 1 2 3 3 roll . . . ->  " 1 2 3 3 roll . . . cr
." *" space space ." *" cr
." *" 5 spaces ." *" cr
ascii * emit cr

." here is " hex here . decimal cr

." 128 in hex is " 128 hex . decimal cr
." 128 in binary is " 128 2 base ! . decimal cr

." hex ff in decimal is " hex ff decimal . cr
." binary 1100 in decimal is " 2 base ! 1100 decimal . cr

: test[]
	[ ." Compiling Test " cr 123 ]
	cr
	[ ." Popping value " . cr ] ;

( Test [if] )

1 [if]
	." This should be printed" cr
[then]

1 [if]
	." This should be printed" cr
[else]
	." This should NOT be printed" cr
[then]

0 [if]
	." This should NOT be printed" cr
[else]
	." This should be printed" cr
[then]

[defined] cr [if] ." cr is defined" cr [then]
[defined] abc not [if] ." ABC is not defined" cr [then]