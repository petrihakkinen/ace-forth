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
	emit_byte(0xcd)	-- call 084e 
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

local function call(addr)
	emit_byte(0xcd)
	emit_short(addr)
end

local function call_forth(name)
	local addr = rom_words[string.upper(name)]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	call(0x04b9) -- call forth
	emit_short(addr)
	emit_short(0x1A0E) -- end-forth
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
	['='] = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0xb7)	-- or a (clear carry)
		emit_short(0x52ed) -- sbc hl, de
		emit_byte(0x11) -- ld de, 0
		emit_short(0)
		emit_byte(0x7c) -- ld a, h
		emit_byte(0xb5) -- or l
		emit_byte(0x20)
		emit_byte(0x01)	-- jr nz, .neg
		emit_byte(0x1c)	-- inc e
		stk_push_de() -- .neg:
	end,
	['>'] = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		call(0x0c99)
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		emit_byte(0x57) -- ld d,a
		emit_byte(0x17) -- rla
		emit_byte(0x5f) -- ld e,a
		stk_push_de()
	end,
	['<'] = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0xeb)	-- ex de,hl
		call(0x0c99)
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		emit_byte(0x57) -- ld d,a
		emit_byte(0x17) -- rla
		emit_byte(0x5f) -- ld e,a
		stk_push_de()
	end,
	['0='] = function()
		stk_pop_de()
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		emit_byte(0x11)	-- ld de,1
		emit_short(1)
		emit_byte(0x28)	-- jr z,.skip
		emit_byte(1)
		emit_byte(0x5a) -- ld e,d (clear e)
		stk_push_de()	-- .skip
	end,
	['0<'] = function()
		stk_pop_de()
		emit_short(0x12cb)	-- rl d
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		emit_byte(0x57) -- ld d,a
		emit_byte(0x17) -- rla
		emit_byte(0x5f) -- ld e,a
        stk_push_de()
	end,
	['0>'] = function()
		stk_pop_de()
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		emit_byte(0x28)	-- jr z,.skip
		emit_byte(3)
		emit_short(0x12cb)	-- rl d
		emit_byte(0x3f) -- ccf
		emit_byte(0x3e) -- skip: ld a,0
		emit_byte(0)
		emit_byte(0x57) -- ld d,a
		emit_byte(0x17) -- rla
		emit_byte(0x5f) -- ld e,a
		stk_push_de()
	end,
	xor = function()
		stk_pop_de()
		stk_pop_bc()
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xa9) -- xor c
		emit_byte(0x5f) -- ld e,a
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xa8) -- xor b
		emit_byte(0x57) -- ld d,a
		stk_push_de()
	end,
	['and'] = function()
		stk_pop_de()
		stk_pop_bc()
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xa1) -- and c
		emit_byte(0x5f) -- ld e,a
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xa0) -- and b
		emit_byte(0x57) -- ld d,a
		stk_push_de()
	end,
	['or'] = function()
		stk_pop_de()
		stk_pop_bc()
		emit_byte(0x7b) -- ld a,e
		emit_byte(0xb1) -- or c
		emit_byte(0x5f) -- ld e,a
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb0) -- or b
		emit_byte(0x57) -- ld d,a
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
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		jr_z(target)
	end,
	['('] = function()
		compile_dict['(']()
	end,
	['\\'] = function()
		compile_dict['\\']()
	end
}

-- The following words do not have fast machine code implementation
local interpreted_words = {
	"ufloat", "int", "fnegate", "f/", "f*", "f+", "f-", "f.",
	"d+", "dnegate", "u/mod", "*/", "mod", "/", "*/mod", "/mod", "u*", "d<", "u<",
	"#", "#s", "u.", ".", "#>", "<#",
	"cls", "slow", "fast", "invis", "vis", "abort", "quit", "convert"
}

for _, name in ipairs(interpreted_words) do
	dict[name] = function()
		call_forth(name)
	end
end

--[[
	TODO:

	EXIT, [".\""], ["+LOOP"], LOOP,
	DO, REPEAT, THEN, ELSE,
	WHILE, IF, LEAVE, J, ["I'"], I,
	CALL, LITERAL,
	["C,"], [","],
	DECIMAL, MIN, MAX, ["2-"], ["2+"],
	NEGATE, ["*"],

	ABS, OUT, IN, INKEY, BEEP, PLOT, AT,
	CR, SPACES, SPACE, HOLD,
	SIGN,

	TYPE, ROLL, PICK, OVER, ROT, ["?DUP"],
	["R>"], [">R"], ["!"], ["@"], ["C!"], ["C@"],

	EXECUTE, RETYPE, QUERY, PAD, BASE,
--]]

return dict