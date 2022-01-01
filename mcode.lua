-- Machine code compile dictionary

MCODE_END = 0xe9fd		-- jp (iy)

local dict = {
	dup = function()
		emit_byte(0xdf)	-- rst 24
		emit_byte(0xd7)	-- rst 16
		emit_byte(0xd7)	-- rst 16
	end,
	drop = function()
		emit_byte(0xdf)	-- rst 24
	end,
	swap = function()
		emit_byte(0xdf) -- rst 24
		emit_byte(0xcd); emit_short(0x084e) -- stk_to_bc
		emit_byte(0xd7) -- rst 16
		emit_byte(0x50) -- ld d,b
		emit_byte(0x59) -- ld e,c
		emit_byte(0xd7) -- rst 16
	end,
}

return dict