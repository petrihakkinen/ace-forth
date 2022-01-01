-- Machine code compile dictionary

-- Pushes DE on Forth stack, trashes HL.
local function stk_push_de()
	emit_byte(0xd7)	 -- rst 16
end

-- Pops value from Forth stack and puts it in DE register, trashes HL.
local function stk_pop_de()
	emit_byte(0xdf)	-- rst 24
end

-- Pops value from Forth stack and puts it in BC register.
local function stk_pop_bc()
	emit_byte(0xcd);	-- call 084e 
	emit_short(0x084e)
end

-- Emits conditional jump which causes a jump to <target> if Z flag is set.
local function jr_z(target)
	emit_byte(0x28)	-- jr z,<offset>
	local offset = target - here() - 1
	if offset < 0 then offset = 256 + offset end
	assert(offset >= 0 and offset < 256, "branch too long")	-- TODO: long jumps
	emit_byte(offset)
end

local dict = {
	[';'] = function()
		emit_short(0xe9fd)	-- jp (iy)
		interpreter_state()
	end,
	dup = function()
		stk_pop_de()
		stk_push_de()
		stk_push_de()
	end,
	drop = function()
		stk_pop_de()
	end,
	swap = function()
		stk_pop_de()
		stk_pop_bc()
		stk_push_de()
		emit_byte(0x50) -- ld d,b
		emit_byte(0x59) -- ld e,c
		stk_push_de()
	end,
	['+'] = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0x19) -- add hl,de
		emit_byte(0xeb)	-- ex de,hl
		stk_push_de()
	end,
	['-'] = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0xeb)	-- ex de,hl
		emit_byte(0xb7)	-- or a (clear carry)
		emit_short(0x52ed) -- sbc hl,de
		emit_byte(0xeb)	-- ex de,hl
		stk_push_de()
	end,
	['1+'] = function()
		stk_pop_de()
		emit_byte(0x13) -- inc de
		stk_push_de()
	end,
	['1-'] = function()
		stk_pop_de()
		emit_byte(0x1b) -- dec de
		stk_push_de()
	end,
	ascii = function()
		compile_dict.ascii()
	end,
	emit = function()
		stk_pop_de()
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
		stk_pop_de()
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xb3) -- or e
		jr_z(target)
	end,
}

return dict