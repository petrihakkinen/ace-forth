( 2D starfield effect )

[hex] 2400 const SCREEN
[hex] 2C00 const CHARS
[hex] 3C3B const SPARE ( The address of the first byte past the top of the stack )

32 const SCREEN_WIDTH
24 const SCREEN_HEIGHT

50 const STAR_COUNT		( Max 127! )
127 const CHAR_COUNT

( Star data arrays )
( These are aligned to start at page boundaries so that computing address within the array is faster. )
[hex] 5000 const StarX			( Star X coordinates within a char 0-7 )
[hex] 5100 const StarY			( Star Y coordinates within a char 0-7 )
[hex] 5200 const StarSpeed		( Star speeds as pixels per tick )
[hex] 5300 const StarChar		( Char index used by each star )
[hex] 5400 const StarScreenAddr	( Stars' screen addresses )
[hex] 5500 const StarCharAddr	( Stars' character addresses )
[hex] 5600 const NumStars		( How many stars per char )
[hex] 5700 const FreeList		( Stack of free character indices )
[hex] 5800 const StarBitMask	( Copy of StarBitMask_slow for fast access )

0 byte NumFree ( Number of items in the free list )

0 variable seed  ( Random number seed )

2 base c!
create StarBitMask_slow
	00000001 c,
	00000010 c,
	00000100 c,
	00001000 c,
	00010000 c,
	00100000 c,
	01000000 c,
	10000000 c,
	;
decimal

: rnd
	seed @
	259 * 3 +
	32767 and
	dup
	seed ! ;

: star-x? ( star -- x ) StarX + c@ ; inline
: star-y? ( star -- y ) StarY + c@ ; inline
: star-speed? ( star -- speed ) StarSpeed + c@ ; inline
: star-char? ( star -- char ) StarChar + c@ ; inline
: star-screen-addr? ( star - addr ) 2* StarScreenAddr + @ ; inline
: star-char-addr? ( star - addr ) 2* StarCharAddr + @ ; inline

: star-x! ( x star -- ) StarX + c! ; inline
: star-y! ( y star -- ) StarY + c! ; inline
: star-speed! ( speed star -- ) StarSpeed + c! ; inline
: star-char! ( char star -- ) StarChar + c! ; inline
: star-screen-addr! ( addr star -- ) 2* StarScreenAddr + ! ; inline
: star-char-addr! ( addr star -- ) 2* StarCharAddr + ! ; inline

: num-stars? ( char -- n ) NumStars + c@ ; inline ( How many stars are using a char? )
: num-stars! ( n char -- ) NumStars + c! ; inline

: alloc-char ( -- char )
	NumFree dec ( NumFree-- )
	NumFree c@ ( s: NumFree )
	FreeList + c@ ; inline ( push FreeList[NumFree] )

: free-char ( char -- )
	NumFree c@ ( s: char num-free )
	FreeList + c! ( FreeList[NumFree] = char )
	NumFree inc ; inline ( NumFree++ )

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

	( Clear num stars )
	[ NumStars CHAR_COUNT + ] lit NumStars do
		0 i c!
	loop

	( Initialize star bit masks )
	8 0 do
		i StarBitMask_slow + c@ ( Read )
		i StarBitMask + c! ( Write )
	loop

	( Initialize stars, one star per char initially )
	STAR_COUNT 0 do
		i 7 and i star-x! ( Init X )
		rnd 2 / 7 and i star-y! ( Init Y )
		i 3 and 1+ i star-speed! ( Init speed )
		i i star-char! ( Init char )
		i 8 * i star-y? + CHARS + i star-char-addr! ( Init char addr )
		1 i num-stars! ( Init NumStars )

		( Initialize star screen address )
		label again
		rnd 16 / [ SCREEN_WIDTH SCREEN_HEIGHT * ] lit mod SCREEN + ( s: screen-addr )
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
			i star-x? ( Get star x-coord )
			i star-speed? + ( Move star )

			( Did StarX overflow? )
			dup 7 c> if
				( Wrap around to 0-7 )
				7 and

				( TODO: fast path -- num stars = 1 and left side does not have a char -> move char left )

				( Decrement num stars )
				i star-char? ( char )
				NumStars + dec

				( Erase star from char )
				0 i star-char-addr? c!

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

				drop ( Drop screen-addr )

				( Recompute char address )
				i star-char? ( char )
				dup 8 * i star-y? + CHARS + i star-char-addr!

				( Increase num stars )
				NumStars + inc
			then

			( Store star X )
			dup i star-x!

			( Draw star to char )
			StarBitMask + c@ ( bitmask )
			i star-char-addr? c!
		loop

		stk?
	again ;