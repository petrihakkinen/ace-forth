( Print word header)

( Usage: WRD <wordname> )
( The header structure will be printed as follows)

( NFA:        Name Field Address: Word Name                            )
( LFA:      Length Field Address: Word length in decimal               )
( LNK:        Link Field Address: Link address> linked word name       )
( NLF: Name Length Field Address: Name Length Field contents in decimal)
( CFA:        Code Field Address: Code Field contents                  )
( PFA:   Parameter Field Address: Parameter Field length               )

: HEX  16 BASE C! ;
: .H ( x -- )  0 <# # # # #S #> TYPE ;
: .ADR ( adr -- adr )  DUP .H  58 EMIT  SPACE ;
: RAM? ( adr -- adr flag )  DUP 8191 > ;

: .NFA ( adr -- , print the Name Field )
 1- DUP C@ 63 AND ( Get the name length )
 SWAP RAM?
 IF  2-  THEN
 2- OVER - .ADR   ( print the Name Field Address )
 SWAP TYPE        ( print the Name)
;

: .LFA ( adr -- , print the Length Field Address )
 RAM?
 IF
  5 - .ADR        ( print the Length Field Address )
  @ DECIMAL . HEX ( print the Length )
 ELSE
  ." ----: <undefined>" DROP
 THEN
;

: .LNK ( adr -- , print the Link Field Address )
 3 - .ADR       ( print the Link Field Address )
 @ DUP .H       ( print the Link)
 ." > " 1+ .NFA ( print Name of linked word )
;

: .NLF ( adr -- , print the Name Length Field )
 1- .ADR                 ( print the Name Length Field Address )
 C@ DUP DECIMAL . HEX    ( print the Name Length )
 DUP 64 AND              ( check if IMMEDIATE word )
 IF ." IMMEDIATE " THEN
 128 AND                 ( check bit 7 )
 IF ." bit7=1" THEN
;

: .CFA ( adr -- , print the Code Field )  .ADR @ .H ;

: .PFA ( adr -- , print the Parameter Field Address )
 2+ .ADR          ( print the Parameter Field Address )
 RAM?
 IF               ( print the Parameter Field Lenght )
  7 - @ 7 -
  DECIMAL ." (" . ." bytes)" HEX
 ELSE
  ." (?)" DROP
 THEN
;

: WRD ( <word> -- , print word header )
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