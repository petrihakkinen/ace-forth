: HEX  16 BASE C! ;
: .H 0 <# # # # #S #> TYPE ;
: .ADR DUP .H  58 EMIT  SPACE ;
: RAM? DUP 8191 > ;

: .NFA
 1- DUP C@ 63 AND
 SWAP RAM?
 IF  2-  THEN
 2- OVER - .ADR
 SWAP TYPE
;

: .LFA
 RAM?
 IF
  5 - .ADR
  @ DECIMAL . HEX
 ELSE
  ." ----: <undefined>" DROP
 THEN
;

: .LNK
 3 - .ADR
 @ DUP .H
 ." > " 1+ .NFA
;

: .NLF
 1- .ADR
 C@ DUP DECIMAL . HEX
 DUP 64 AND
 IF ." IMMEDIATE " THEN
 128 AND
 IF ." bit7=1" THEN
;

: .CFA .ADR @ .H ;

: .PFA
 2+ .ADR
 RAM?
 IF
  7 - @ 7 -
  DECIMAL ." (" . ." bytes)" HEX
 ELSE
  ." (?)" DROP
 THEN
;

: WRD
 HEX
 FIND ?DUP
 IF
  ." is at " DUP .H
  RAM? IF ." (RAM)" ELSE ." (ROM)" THEN
  CR ." NFA " DUP .NFA
  CR ." LFA " DUP .LFA
  CR ." LNK " DUP .LNK
  CR ." NLF " DUP .NLF
  CR ." CFA " DUP .CFA
  CR ." PFA " .PFA
 ELSE
  ." not found"
 THEN
 CR
;