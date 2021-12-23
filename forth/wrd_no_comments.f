: hex  16 base c! ;
: .h 0 <# # # # #s #> type ;
: .adr dup .h  58 emit  space ;
: ram? dup 8191 > ;

: .nfa
 1- dup c@ 63 and
 swap ram?
 if  2-  then
 2- over - .adr
 swap type
;

: .lfa
 ram?
 if
  5 - .adr
  @ decimal . hex
 else
  ." ----: <undefined>" drop
 then
;

: .lnk
 3 - .adr
 @ dup .h
 ." > " 1+ .nfa
;

: .nlf
 1- .adr
 c@ dup decimal . hex
 dup 64 and
 if ." IMMEDIATE " then
 128 and
 if ." bit7=1" then
;

: .cfa .adr @ .h ;

: .pfa
 2+ .adr
 ram?
 if
  7 - @ 7 -
  decimal ." (" . ." bytes)" hex
 else
  ." (?)" drop
 then
;

: wrd
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