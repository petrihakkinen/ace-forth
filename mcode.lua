-- Machine code compile dictionary

local dict = {
	[';'] = function()
		emit_short(0xe9fd)	-- jp (iy)
		interpreter_state()
	end,
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
	ascii = function()
		compile_dict.ascii()
	end,
	emit = function()
		emit_byte(0xdf)	-- rst 24
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xcf) -- rst 8
	end,
	begin = function()
		push(here())
		push('begin')
	end,
	['until'] = function()
		comp_assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		emit_byte(0xdf)	-- rst 24
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xb3) -- or e
		emit_byte(0x28)	-- jr z,<offset>
		local offset = target - here() - 1
		if offset < 0 then offset = 256 + offset end
		assert(offset >= 0 and offset < 256, "branch too long")	-- TODO: long jumps
		emit_byte(offset)
	end,
}

return dict