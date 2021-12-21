( This is a comment )

123 variable foo
-12345 variable bar
54 const k

: hello ." world" cr ;

: hello2 hello ;

: lit -12345 . ;

: lit0 0 . ;

: test cls 32 24 1 plot cr ;

: test-if 0 if ." a" else ." b" then ;

: test-until begin ." *" 0 until ;

: test-until2 5 begin ." *" 1- dup 0= until ;

: test-loop 3 0 do i . loop ;

: test+loop -1 5 do i . -1 +loop ;

: test-ascii ascii * emit ;

create temp 10 allot ( allocate bytes )

create table 1 c, 2 c, 4 c, 8 c, 16 c, 32 c, 64 c, 128 c,

: dump-temp 10 0 do temp i + c@ . loop cr ;

: dump-table 8 0 do table i + c@ . loop cr ;
