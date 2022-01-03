-- Machine code compile dictionary

local labels = {}	-- label -> address for current word
local gotos = {}	-- address to be patched -> label for current word

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

local function branch_offset(target)
	local offset = target - here() - 2
	if offset < -128 or offset > 127 then return end	-- branch too long
	if offset < 0 then offset = offset + 256 end
	return offset
end

-- Emits unconditional jump to <target>.
local function jump(target)
	local offset = branch_offset(target)
	if offset then
		emit_byte(0x18)	-- jr <offset>
		emit_byte(offset)
	else
		emit_byte(0xc3) -- jp <addr>
		emit_short(target)
	end
end

-- Emits conditional jump which causes a jump to <target> if Z flag is set.
local function jump_z(target)
	local offset = branch_offset(target)
	if offset then
		emit_byte(0x28)	-- jr z,<offset>
		emit_byte(offset)
	else
		emit_byte(0xca) -- jp z,<addr>
		emit_short(target)
	end
end

local function call(addr)
	emit_byte(0xcd)
	emit_short(addr)
end

local function call_forth(name)
	local addr = compilation_addresses[name] or rom_words[string.upper(name)]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	call(0x04b9) -- call forth
	emit_short(addr)
	emit_short(0x1a0e) -- end-forth
end

local mult16_addr
local mult8_addr

-- Emits invisible subroutine words to be used by mcode words.
local function emit_subroutines()
	-- signed 16-bit * 16-bit multiplication routine
	create_word(0, "_mcode", true)
	mult16_addr = here()
	stk_pop_de()
	stk_pop_bc()
	emit_byte(0x21)		-- ld hl,0
	emit_short(0)
	emit_byte(0x3e)		-- ld a,16
	emit_byte(0x10)
	emit_byte(0x29)		-- loop: add hl,hl
	emit_byte(0xeb)		-- ex de,hl
	emit_short(0x6aed)	-- adc hl,hl
	emit_byte(0xeb)		-- ex de,hl
	emit_byte(0x30)		-- jr nc,skip
	emit_byte(0x04)
	emit_byte(0x09)		-- add hl,bc
	emit_byte(0x30)		-- jr nc,skip
	emit_byte(0x01)
	emit_byte(0x13)		-- inc de
	emit_byte(0x3d)		-- skip: dec a
	emit_byte(0x20)		-- jr nz,loop
	emit_byte(0xf2)
	emit_byte(0xeb)		-- ex de,hl
	stk_push_de()
	emit_byte(0xc9)		-- ret

	-- unsigned 8-bit * 8-bit multiplication routine
	-- source: http://map.grauw.nl/sources/external/z80bits.html#1.1
	mult8_addr = here()
	stk_pop_de()
	emit_byte(0xd5)		-- push de
	stk_pop_de()
	emit_byte(0xe1)		-- pop hl
	emit_byte(0x65)		-- ld h,l
	emit_byte(0x2e)		-- ld l,0
	emit_byte(0)
	emit_short(0x24cb)	-- sla h
	emit_byte(0x30) 	-- jr nc,$+3
	emit_byte(1)
	emit_byte(0x6b)		-- ld l,e
	for i = 1, 7 do
		emit_byte(0x29)	-- add hl,hl
		emit_byte(0x30) -- jr nc,$+3
		emit_byte(1)
		emit_byte(0x19) -- add hl,de
	end
	emit_byte(0xeb)		-- ex de,hl
	stk_push_de()
	emit_byte(0xc9)		-- ret
end

local dict = {
	[';'] = function()
		emit_short(0xe9fd)	-- jp (iy)
		interpreter_state()

		-- patch gotos
		for patch_loc, label in pairs(gotos) do
			local target_addr = labels[label]
			if target_addr == nil then comp_error("undefined label '%s'", label) end
			write_short(patch_loc, target_addr)
		end

		labels = {}
		gotos = {}
	end,
	dup = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x56) -- ld d,(hl)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x5e) -- ld e,(hl)
		stk_push_de()
	end,
	['?dup'] = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x56) -- ld d,(hl)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x5e) -- ld e,(hl)
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		emit_byte(0x28)	-- jr z,.skip
		emit_byte(1)
		stk_push_de()
	end,
	over = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x2b) -- dec hl
		emit_byte(0x2b) -- dec hl
		emit_byte(0x56) -- ld d,(hl)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x5e) -- ld e,(hl)
		stk_push_de()
	end,
	drop = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		emit_byte(0x2b) -- dec hl
		emit_byte(0x2b) -- dec hl
		emit_byte(0x22) -- ld (0x3c3b),hl
		emit_short(0x3c3b)
	end,
	swap = function()
		stk_pop_de()
		stk_pop_bc()
		stk_push_de()
		emit_byte(0x50) -- ld d,b
		emit_byte(0x59) -- ld e,c
		stk_push_de()
	end,
	pick = function()
		call(0x094d)
	end,
	roll = function()
		call(0x094d)
		emit_byte(0xeb) -- ex de,hl
		emit_byte(0x2a) -- ld hl,(0x3c37) (load stkbot)
		emit_short(0x3c37)
		emit_byte(0x62) -- ld h,d
		emit_byte(0x6b) -- ld l,e
		emit_byte(0x23) -- inc hl
		emit_byte(0x23) -- inc hl
		emit_short(0xb0ed) -- ldir
		emit_short(0x53ed) -- ld (0x3c3b),de (write spare)
		emit_short(0x3c3b)
	end,
	['r>'] = function()
		emit_byte(0xc1) -- pop bc
		emit_byte(0xd1) -- pop de
		emit_byte(0xc5) -- push bc
		stk_push_de()
	end,
	['>r'] = function()
		stk_pop_de()
		emit_byte(0xc1) -- pop bc
		emit_byte(0xd5)	-- push de
		emit_byte(0xc5) -- push bc
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
	['*'] = function()
		assert(mult16_addr, "mcode subroutines not found")
		call(mult16_addr)
	end,
	['c*'] = function()
		assert(mult8_addr, "mcode subroutines not found")
		call(mult8_addr)
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
	['2+'] = function()
		stk_pop_de()
		emit_byte(0x13) -- inc de
		emit_byte(0x13) -- inc de
		stk_push_de()
	end,
	['2-'] = function()
		stk_pop_de()
		emit_byte(0x1b) -- dec de
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
		emit_byte(0x20)	-- jr nz, .neg
		emit_byte(0x01)
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
	negate = function()
		stk_pop_de()
		emit_byte(0xeb) -- ex de, hl
		emit_byte(0xaf) -- xor a
		emit_byte(0x95) -- sub l
		emit_byte(0x6f) -- ld l,a
		emit_byte(0x9f) -- sbc a,a
		emit_byte(0x94) -- sub h
		emit_byte(0x67) -- ld h,a
		emit_byte(0xeb) -- ex de, hl
		stk_push_de()
	end,
	abs = function()
		stk_pop_de()
		emit_byte(0x7a) -- ld a,d
		emit_short(0x17cb) -- rl a
		emit_byte(0x30) -- jr nc, .skip
		emit_byte(8)
		emit_byte(0xeb) -- ex de, hl
		emit_byte(0xaf) -- xor a
		emit_byte(0x95) -- sub l
		emit_byte(0x6f) -- ld l,a
		emit_byte(0x9f) -- sbc a,a
		emit_byte(0x94) -- sub h
		emit_byte(0x67) -- ld h,a
		emit_byte(0xeb) -- ex de, hl
		stk_push_de()	-- .skip
	end,
	min = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0xe5) -- push hl
		emit_byte(0xb7)	-- or a (clear carry)
		emit_short(0x52ed) -- sbc hl, de
		emit_byte(0x7c)	-- ld a,h
		emit_byte(0xe1)	-- pop hl
		emit_short(0x17cb) -- rl a
		emit_byte(0x30) -- jr nc, .skip
		emit_byte(1)
		emit_byte(0xeb) -- ex de, hl
		stk_push_de()	-- .skip
	end,
	max = function()
		stk_pop_de()
		emit_byte(0xd5)	-- push de
		stk_pop_de()
		emit_byte(0xe1)	-- pop hl
		emit_byte(0xe5) -- push hl
		emit_byte(0xb7)	-- or a (clear carry)
		emit_short(0x52ed) -- sbc hl, de
		emit_byte(0x7c)	-- ld a,h
		emit_byte(0xe1)	-- pop hl
		emit_short(0x17cb) -- rl a
		emit_byte(0x38) -- jr c, .skip
		emit_byte(1)
		emit_byte(0xeb) -- ex de, hl
		stk_push_de()	-- .skip
	end,
	['c!'] = function()
		stk_pop_de()
		stk_pop_bc()
		emit_byte(0x79) -- ld a,c
		emit_byte(0x12) -- ld (de),a
	end,
	['c@'] = function()
		stk_pop_de()
		emit_byte(0x1a) -- ld a,(de)
		emit_byte(0x5f) -- ld e,a
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		stk_push_de()
	end,
	['!'] = function()
		stk_pop_de()
		stk_pop_bc()
		emit_byte(0xeb) -- ex de,hl
		emit_byte(0x71) -- ld (hl),c
		emit_byte(0x23) -- inc hl
		emit_byte(0x70) -- ld (hl),b
	end,
	['@'] = function()
		stk_pop_de()
		emit_byte(0xeb) -- ex de,hl
		emit_byte(0x5e) -- ld e,(hl)
		emit_byte(0x23) -- inc hl
		emit_byte(0x56) -- ld d,(hl)
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
	cr = function()
		emit_byte(0x3e) -- ld a,0x0d
		emit_byte(0x0d)
		emit_byte(0xcf) -- rst 8
	end,
	space = function()
		emit_byte(0x3e) -- ld a,0x20
		emit_byte(0x20)
		emit_byte(0xcf) -- rst 8
	end,
	spaces = function()
		stk_pop_de()
		emit_byte(0x1b)	-- loop: dec de
		emit_short(0x7acb) -- bit 7,d
		emit_byte(0x20) -- jr nz, done
		emit_byte(5)
		emit_byte(0x3e) -- ld a,0x20
		emit_byte(0x20)
		emit_byte(0xcf) -- rst 8
		emit_byte(0x18) -- jr loop
		emit_byte(0xf6)
	end,
	at = function()
		stk_pop_de()
		call(0x084e)
		emit_byte(0x79) --ld a,c
		call(0x0b28)
		emit_byte(0x22) --ld ($3c1c),hl (update SCRPOS)
		emit_short(0x3c1c)
	end,
	type = function()
		stk_pop_bc()
		stk_pop_de()
		call(0x097f) -- call print string routine
	end,
	base = function()
		emit_byte(0x11) -- ld de, 0x3c3f
		emit_short(0x3c3f)
		stk_push_de()
	end,
	decimal = function()
		emit_short(0x36dd) -- ld (ix+0x3f),0x0a
		emit_byte(0x3f)
		emit_byte(0x0a)
	end,
	out = function()
		stk_pop_bc()
		stk_pop_de()
		emit_short(0x59ed) -- out (c),e
	end,
	['in'] = function()
		stk_pop_bc()
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		emit_short(0x58ed) -- in e,(c)
		stk_push_de()
	end,
	inkey = function()
		call(0x0336) -- call keyscan routine
		emit_byte(0x5f) -- ld e,a
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		stk_push_de()
	end,
	['if'] = function()
		stk_pop_de()
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		emit_byte(0xca)	-- jp z,<addr>	TODO: this could be optimized to JR Z,<addr>
		push(here())
		push('if')
		emit_short(0) -- placeholder jump target
	end,
	['else'] = function()
		comp_assert(pop() == 'if', "ELSE without matching IF")
		local where = pop()
		-- emit jump to THEN
		emit_byte(0xc3) -- jp <addr>	TODO: this could be optimized to JR Z,<addr>
		push(here())
		push('if')
		emit_short(0)	-- placeholder jump target
		-- patch jump target at previous IF
		write_short(where, here())
	end,
	['then'] = function()
		comp_assert(pop() == 'if', "THEN without matching IF")
		local where = pop()
		-- patch jump target at previous IF or ELSE
		write_short(where, here())
	end,
	label = function()
		local label = next_symbol()
		labels[label] = here()
	end,
	['goto'] = function()
		local label = next_symbol()

		if labels[label] then
			-- label found -> this is a backward jump
			-- emit the jump immediately
			jump(labels[label])
		else
			-- label not found -> this is a forward jump
			-- emit placeholder jump and resolve jump address in ;
			emit_byte(0xc3) -- jp <addr>
			local addr = here()
			emit_short(0) -- placeholder jump addr
			gotos[addr] = label
		end
	end,
	begin = function()
		push(here())
		push('begin')
	end,
	again = function()
		comp_assert(pop() == 'begin', "AGAIN without matching BEGIN")
		local target = pop()
		jump(target)
	end,
	['until'] = function()
		comp_assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		stk_pop_de()
		emit_byte(0x7a) -- ld a,d
		emit_byte(0xb3) -- or e
		jump_z(target)
	end,
	['do'] = function()
		stk_pop_de() -- pop counter
		stk_pop_bc() -- pop limit
		emit_byte(0xc5)	-- push bc (push limit to return stack)
		emit_byte(0xd5) -- push de (push counter to return stack)
		push(here())
		push('do')
	end,
	loop = function()
		comp_assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		emit_byte(0xd1) -- pop de (pop counter)
		emit_byte(0xc1) -- pop bc (pop limit) 
		emit_byte(0x13) -- inc de
		emit_byte(0x60) -- ld h,b
		emit_byte(0x69) -- ld l,c
		emit_byte(0x37) -- scf (set carry flag)
		emit_short(0x52ed) -- sbc hl,de
		emit_byte(0x38) -- jr c, .done
		local pos = here()
		emit_byte(0)	-- placeholder branch offset
		emit_byte(0xc5)	-- push bc (push limit to return stack)
		emit_byte(0xd5) -- push de (push counter to return stack)
		jump(target)
		write_byte(pos, here() - pos - 1)
	end,
	['+loop'] = function()
		comp_error("mcode word +LOOP not yet implemented")
	end,
	['repeat'] = function()
		comp_error("mcode word REPEAT not yet implemented")
	end,
	['while'] = function()
		comp_error("mcode word WHILE not yet implemented")
	end,
	i = function()
		emit_byte(0xd1) -- pop de
		emit_byte(0xd5)	-- push de
		stk_push_de()
	end,
	['i\''] = function()
		emit_byte(0xc1) -- pop bc
		emit_byte(0xd1) -- pop de
		emit_byte(0xd5)	-- push de
		emit_byte(0xc5) -- push bc
		stk_push_de()
	end,
	j = function()
		emit_byte(0x21)	-- ld hl,4
		emit_short(4)
		emit_byte(0x39) -- add hl,sp
		emit_byte(0x5e) -- ld e,(hl)
		emit_byte(0x23) -- inc hl
		emit_byte(0x56) -- ld d,(hl)
		stk_push_de()
	end,
	leave = function()
		emit_byte(0xe1) -- pop hl (pop counter)
		emit_byte(0xe1) -- pop hl (pop limit)
		emit_byte(0xe5) -- push hl (push limit)
		emit_byte(0xe5) -- push hl (push limit as new counter)
	end,
	exit = function()
		emit_short(0xe9fd)	-- jp (iy)
	end,
	['('] = function()
		compile_dict['(']()
	end,
	['\\'] = function()
		compile_dict['\\']()
	end,
	['['] = function()
		compile_dict['[']()
	end,
	lit = function()
		compile_dict.lit()
	end,
	['."'] = function()
		local str = next_symbol("\"")
		assert(#str <= 128, "string too long (max length 128 bytes)")
		emit_byte(0x11) -- ld de, <addr>
		emit_short(here() + 7)
		call(0x0979) -- call print embedded string routine
		emit_byte(0x18)	-- jr <length>
		emit_byte(#str + 2)
		emit_short(#str)
		emit_string(str)
	end,
}

-- The following words do not have fast machine code implementation
local interpreted_words = {
	"ufloat", "int", "fnegate", "f/", "f*", "f+", "f-", "f.",
	"d+", "dnegate", "u/mod", "*/", "mod", "/", "*/mod", "/mod", "u*", "d<", "u<",
	"#", "#s", "u.", ".", "#>", "<#", "sign", "hold",
	"cls", "slow", "fast", "invis", "vis", "abort", "quit",
	"line", "word", "number", "convert", "retype", "query",
	"rot", "plot", "beep", "execute", "call"
}

for _, name in ipairs(interpreted_words) do
	dict[name] = function()
		call_forth(name)
	end
end

local function get_dict()
	local t = {}
	for k, v in pairs(dict) do
		t[k] = v
	end
	return t
end

return {
	get_dict = get_dict,
	emit_subroutines = emit_subroutines,
	call_forth = call_forth,
}