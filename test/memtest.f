( Memory tester )

: main
	fast cls 16 base c!
	( Loop through address in test range )
	[ hex ] 4000 3f00 [ decimal ] do
		." TESTING " i . space

		( Test all values )
		256 0 do
			i j c!	( Write test value )
			j c@ ( Read back value )
			i = 0= if
				." ERROR!"
				abort
			then
		loop
		." OK" cr
	loop ;