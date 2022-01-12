32 variable x
24 variable y
1 variable dx
-1 variable dy
1 variable len

: pl ( -- ) x @ y @ abs 47 mod 3 plot ;

: !+ over @ + swap ! ;

: step ( -- ) x dx @ !+ y dy @ !+ ;

: turn ( -- ) dx @ negate dy @ dx ! dy ! ;

: main
	fast di
	begin
		len @ 0
		do
			pl step
		loop
		turn len 1 !+ 
	again ; 
