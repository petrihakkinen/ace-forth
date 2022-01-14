( 2D starfield effect )

[hex] 2400 const SCREEN
[hex] 2C00 const CHARS
[hex] 3C3B const SPARE ( The address of the first byte past the top of the stack )

32 const SCREEN_WIDTH
24 const SCREEN_HEIGHT

50 const STAR_COUNT
127 const CHAR_COUNT

create StarX STAR_COUNT allot
create StarY STAR_COUNT allot
create StarSpeed STAR_COUNT allot
create StarChar STAR_COUNT allot
create StarScreenAddr STAR_COUNT 2* allot

create NumStars CHAR_COUNT allot

create FreeList 128 allot	( Stack of free character indices )
0 byte NumFree				( Number of items in the free list )

2 base c!
create StarBitMask
	00000001 c,
	00000010 c,
	00000100 c,
	00001000 c,
	00010000 c,
	00100000 c,
	01000000 c,
	10000000 c,
decimal

0 variable seed  ( Random number seed )

: rnd
	seed @
	259 * 3 +
	32767 and
	dup
	seed ! ;

: star-x? ( star -- x ) StarX + c@ ;
: star-y? ( star -- y ) StarY + c@ ;
: star-speed? ( star -- speed ) StarSpeed + c@ ;
: star-char? ( star -- char ) StarChar + c@ ;
: star-screen-addr? ( star - addr ) 2* StarScreenAddr + @ ;

: star-x! ( x star -- ) StarX + c! ;
: star-y! ( y star -- ) StarY + c! ;
: star-speed! ( speed star -- ) StarSpeed + c! ;
: star-char! ( char star -- ) StarChar + c! ;
: star-screen-addr! ( addr star -- ) 2* StarScreenAddr + ! ;

: num-stars? ( char -- n ) NumStars + c@ ; ( How many stars are using a char? )
: num-stars! ( n char -- ) NumStars + c! ;

: star-char-addr ( star - addr ) dup star-char? 8 * swap star-y? + CHARS + ; ( Return star's address in charset memory )

: alloc-char ( -- char )
	NumFree c@ 1- ( s: NumFree-1 )
	dup FreeList + c@ >r ( r: FreeList[NumFree-1] )
	NumFree c! ( NumFree = NumFree-1 )
	r> ;

: free-char ( char -- )
	NumFree c@ >r ( s: char, r: num-free )
	r@ FreeList + c! ( FreeList[NumFree] = char )
	r> 1+ NumFree c! ( NumFree++ )
	;

0 variable stack-guard	( Debug only )

: stk! ( store stack address for stk? )
	SPARE @ stack-guard ! ;

: stk? ( check stack guard )
	SPARE @ stack-guard @ = 0= if
		0 0 at ." STACK GUARD FAILED! "
		SPARE @ stack-guard @ - 2 / . ( print delta )
	then ;

: stars
	fast di cls

	( Clear all characters )
	[ CHARS 128 8 * + ] lit CHARS do
		0 i c!
	loop

	( Clear screen with empty char )
	[ SCREEN SCREEN_WIDTH SCREEN_HEIGHT * + ] lit SCREEN do
		127 i c!
	loop

	( Initialize stars, one star per char initially )
	STAR_COUNT 0 do
		rnd 7 and i star-x!
		rnd 7 and i star-y!
		i 3 and 1+ i star-speed!
		i i star-char!
		1 i num-stars!

		( Initialize star screen address )
		label again
		rnd [ SCREEN_WIDTH SCREEN_HEIGHT * ] lit mod SCREEN + ( s: screen-addr )
		( Make sure screen location is empty )
		dup c@ 127 = if
			i star-screen-addr! 
		else
			drop goto again
		then
	loop 

	( Insert the remaining chars to free list )
	127 STAR_COUNT do
		i free-char
	loop

	( Plot chars )
	STAR_COUNT 0 do
		i i star-screen-addr? c!
	loop

	( Main loop )
	begin
		stk!

		( Update stars )
		STAR_COUNT 0 do
			i star-x? i star-speed? + i star-x! ( StarX[i] = StarX[i] + StarSpeed[i] )

			( Did StarX overflow )
			i star-x? 7 > if
				( Wrap around to 0-7 )
				i star-x? 7 and i star-x!

				( Decrement num stars )
				i star-char? num-stars? 1- i star-char? num-stars!

				( Erase star from char )
				0 i star-char-addr c!

				( Get star's screen address )
				i star-screen-addr? ( s: screen-addr )

				( How many stars left in this char? )
				i star-char? num-stars? 0= if
					( Zero -> Erase char from screen )
					127 over c!
					( Add char to free list )
					i star-char? free-char
				then

				1- ( Move left on the screen )

				( Wrap around to end of screen )
				dup [ SCREEN 1- ] lit = if
					drop [ SCREEN SCREEN_WIDTH SCREEN_HEIGHT * + 1- ] lit
				then

				( Update star's screen address )
				dup i star-screen-addr!

				( Is there a char already in the new location? )
				dup c@ 127 c= if
					( Nope, allocate a new char )
					alloc-char ( s: screen-addr char )
					( Assign the char to the star )
					dup i star-char! ( -- )
					( Plot it to screen )
					over c!
				else
					dup c@ ( char )
					( Assign the char to the star )
					i star-char! ( -- )
				then

				drop ( drop screen-addr )

				( Increase num stars )
				i star-char? num-stars? 1+ i star-char? num-stars!
			then

			( Draw star to char )
			i star-x? StarBitMask + c@ ( bitmask )
			i star-char-addr c!
		loop

		stk?
	again ;