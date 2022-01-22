: inl
	begin 1 again
	( Forth calls must be skipped over when relocating mcode )
	cls
	( Embedded strings must be skipped over when inlining & relocating mcode )
	( Ascii code of '8' is 0x38, which is the opcode for JR C,o )
	." 8HELLO"
	; inline

: main inl ;