( Print word header)

( Usage: WRD <wordname> )
( The header structure will be printed as follows)

( NFA:        Name Field Address: Word Name                            )
( LFA:      Length Field Address: Word length in decimal               )
( LNK:        Link Field Address: Link address> linked word name       )
( NLF: Name Length Field Address: Name Length Field contents in decimal)
( CFA:        Code Field Address: Code Field contents                  )
( PFA:   Parameter Field Address: Parameter Field length               )

: hex  16 base c! ;
: .h ( x -- )  0 <# # # # #s #> type ;
: .adr ( adr -- adr )  dup .h  58 emit  space ;
: ram? ( adr -- adr flag )  dup 8191 > ;

: .nfa ( adr -- , print the Name Field )
 1- dup c@ 63 and ( get the name length )
 swap ram?
 if  2-  then
 2- over - .adr   ( print the Name Field Address )
 swap type        ( print the Name )
;

: .lfa ( adr -- , print the Length Field Address )
 ram?
 if
  5 - .adr        ( print the Length Field Address )
  @ decimal . hex ( print the Length )
 else
  ." ----: <undefined>" drop
 then
;

: .lnk ( adr -- , print the Link Field Address )
 3 - .adr       ( print the Link Field Address )
 @ dup .h       ( print the Link )
 ." > " 1+ .nfa ( print name of linked word )
;

: .nlf ( adr -- , print the Name Length Field )
 1- .adr                 ( print the Name Length Field address )
 c@ dup decimal . hex    ( print the Name Length )
 dup 64 and              ( check if IMMEDIATE word )
 if ." IMMEDIATE " then
 128 and                 ( check bit 7 )
 if ." bit7=1" then
;

: .cfa ( adr -- , print the Code Field )  .adr @ .h ;

: .pfa ( adr -- , print the Parameter Field Address )
 2+ .adr          ( print the Parameter Field Address )
 ram?
 if               ( print the Parameter Field Length )
  7 - @ 7 -
  decimal ." (" . ." bytes)" hex
 else
  ." (?)" drop
 then
;

: wrd ( <word> -- , print word header )
 hex
 find ?dup
 if
  ." is at " dup .h
  ram? if ." (RAM)" else ." (ROM)" then
  cr ." NFA " dup .nfa
  cr ." LFA " dup .lfa
  cr ." LNK " dup .lnk
  cr ." NLF " dup .nlf
  cr ." CFA " dup .cfa
  cr ." PFA " .pfa
 else
  ." not found"
 then
 cr
;