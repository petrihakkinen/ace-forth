-- Machine code compile dictionary

local labels = {}	-- label -> address for current word
local gotos = {}	-- address to be patched -> label for current word

-- Z80 registers
local A = 7
local B = 0
local C = 1
local D = 2
local E = 3
local H = 4
local L = 5
local AF = 0x10
local BC = 0x20
local DE = 0x30
local HL = 0x40
local IX = 0x50
local IY = 0x60
local SP = 0x70

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

local function _ld(dest, src)
	-- ld r,r
	assert(dest >= 0 and dest <= 7, "_ld: unknown dest register")
	assert(src >= 0 and src <= 7, "_ld: unknown src register")
	local op = 0x40 + dest * 8 + src
	emit_byte(op)
end

local function _ex_de_hl()
	emit_byte(0xeb)
end

local function _inc(r)
	-- INC A	3C
	-- INC B	04
	-- INC C	0C
	-- INC D	14
	-- INC E	1C
	-- INC H	24
	-- INC BC	03
	-- INC DE	13
	-- INC HL	23
	if r == BC then
		emit_byte(0x03)
	elseif r == DE then
		emit_byte(0x13)
	elseif r == HL then
		emit_byte(0x23)
	elseif r >= 0 and r <= 7 then 
		emit_byte(0x04 + r * 8)
	else
		error("_dec: unknown register")
	end
end

local function _dec(r)
	-- DEC A	3D
	-- DEC B	05
	-- DEC C	0D
	-- DEC D	15
	-- DEC E	1D
	-- DEC H	25
	-- DEC BC	0B
	-- DEC DE	1B
	-- DEC HL	2B
	if r == BC then
		emit_byte(0x0b)
	elseif r == DE then
		emit_byte(0x1b)
	elseif r == HL then
		emit_byte(0x2b)
	elseif r >= 0 and r <= 7 then
		emit_byte(0x05 + r * 8)
	else
		error("_dec: unknown register")
	end
end

local function _xor(r)
	assert(r >= 0 and r <= 7, "_xor: unknown register")
	emit_byte(0xa8 + r)
end

local function _and(r)
	assert(r >= 0 and r <= 7, "_and: unknown register")
	emit_byte(0xa0 + r)
end

local function _or(r)
	assert(r >= 0 and r <= 7, "_or: unknown register")
	emit_byte(0xb0 + r)
end

local function _ccf()
	emit_byte(0x3f)
end

local function _add(dest, src)
	-- ADD HL,BC	09
	-- ADD HL,DE	19
	-- ADD HL,HL	29
	-- ADD HL,SP	39
	if dest == HL then
		if src == BC then
			emit_byte(0x09)
		elseif src == DE then
			emit_byte(0x19)
		elseif src == HL then
			emit_byte(0x29)
		elseif src == SP then
			emit_byte(0x39)
		else
			error("_add: unknown src register")
		end
	elseif dest == A then
		assert(src >= 0 and src <= 7, "_add: unknown src register")
		emit_byte(0x80 + src)
	else
		error("_add: unknown operands")		
	end
end

local function _adc(dest, src)
	-- ADC HL,BC 	ED 4A
	-- ADC HL,DE 	ED 5A
	-- ADC HL,HL 	ED 6A
	-- ADC HL,SP 	ED 7A
	if dest == HL then
		if src == BC then
			emit_byte(0xed)
			emit_byte(0x4a)
		elseif src == DE then
			emit_byte(0xed)
			emit_byte(0x5a)
		elseif src == HL then
			emit_byte(0xed)
			emit_byte(0x6a)
		elseif src == SP then
			emit_byte(0xed)
			emit_byte(0x7a)
		else
			error("_adc: unknown src register")
		end
	elseif dest == A then
		assert(src >= 0 and src <= 7, "_adc: unknown src register")
		emit_byte(0x88 + src)
	else
		error("_adc: unknown operands")		
	end
end

local function _sub(r)
	assert(r >= 0 and r <= 7, "_sub: unknown register")
	emit_byte(0x90 + r)
end

local function _sbc(dest, src)
	-- SBC HL,BC	ED 42
	-- SBC HL,DE	ED 52
	-- SBC HL,HL	ED 62
	-- SBC HL,SP	ED 72
	if dest == HL then
		if src == BC then
			emit_byte(0xed)
			emit_byte(0x42)
		elseif src == DE then
			emit_byte(0xed)
			emit_byte(0x52)
		elseif src == HL then
			emit_byte(0xed)
			emit_byte(0x62)
		elseif src == SP then
			emit_byte(0xed)
			emit_byte(0x72)
		else
			error("_sbc: unknown src register")
		end
	elseif dest == A then
		assert(src >= 0 and src <= 7, "_sbc: unknown src register")
		emit_byte(0x98 + src)
	else
		error("_sbc: unknown operands")		
	end
end

local function _bit(i, r)
	assert(r >= 0 and r <= 7, "_bit: unknown register")
	emit_byte(0xcb)
	emit_byte(0x40 + 8 * i + r)
end

local function _sla(r)
	assert(r >= 0 and r <= 7, "_sla: unknown register")
	emit_byte(0xcb)
	emit_byte(0x20 + r)
end

local function _rl(r)
	assert(r >= 0 and r <= 7, "_rl: unknown register")
	emit_byte(0xcb)
	emit_byte(0x10 + r)
end

local function _rla()
	emit_byte(0x17)
end

local function _ldir()
	emit_byte(0xed)
	emit_byte(0xb0)
end

local function _push(r)
	-- PUSH AF	F5
	-- PUSH BC	C5
	-- PUSH DE	D5
	-- PUSH HL	E5
	-- PUSH IX	DD E5
	-- PUSH IY	FD E5
	if r == AF then
		emit_byte(0xf5)
	elseif r == BC then
		emit_byte(0xc5)
	elseif r == DE then
		emit_byte(0xd5)
	elseif r == HL then
		emit_byte(0xe5)
	elseif r == IX then
		emit_byte(0xdd)
		emit_byte(0xe5)
	elseif r == IY then
		emit_byte(0xfd)
		emit_byte(0xe5)
	else
		error("_push: unknown register")
	end
end

local function _pop(r)
	-- POP AF	F1
	-- POP BC	C1
	-- POP DE	D1
	-- POP HL	E1
	-- POP IX	DD E1
	-- POP IY	FD E1
	if r == AF then
		emit_byte(0xf1)
	elseif r == BC then
		emit_byte(0xc1)
	elseif r == DE then
		emit_byte(0xd1)
	elseif r == HL then
		emit_byte(0xe1)
	elseif r == IX then
		emit_byte(0xdd)
		emit_byte(0xe1)
	elseif r == IY then
		emit_byte(0xfd)
		emit_byte(0xe1)
	else
		error("_pop: unknown register")
	end
end

local function _ret()
	emit_byte(0xc9)
end

local function _in(r, port)
	-- IN A,(C)		ED 78
	-- IN B,(C)		ED 40
	-- IN C,(C)		ED 48
	-- IN D,(C)		ED 50
	-- IN E,(C)		ED 58
	-- IN H,(C)		ED 60
	-- IN L,(C)		ED 68
	-- IN F,(C)		ED 70	not implemented!
	assert(port == C, "_in: invalid port")
	assert(r >= 0 and r <= 7, "_in: unknown register")
	emit_byte(0xed)
	emit_byte(0x40 + r * 8)
end

local function _out(port, r)
	-- OUT (C),A	ED 79
	-- OUT (C),B	ED 41
	-- OUT (C),C	ED 49
	-- OUT (C),D	ED 51
	-- OUT (C),E	ED 59
	-- OUT (C),H	ED 61
	-- OUT (C),L	ED 69
	assert(port == C, "_out: invalid port")
	assert(r >= 0 and r <= 7, "_out: unknown register")
	emit_byte(0xed)
	emit_byte(0x41 + r * 8)
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

local function call_mcode(name)
	local addr = compilation_addresses[name]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	call(addr + 7) -- call machine code, skipping the wrapper
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
	_ex_de_hl()
	_adc(HL, HL)
	_ex_de_hl()
	emit_byte(0x30)		-- jr nc,skip
	emit_byte(0x04)
	_add(HL, BC)
	emit_byte(0x30)		-- jr nc,skip
	emit_byte(0x01)
	_inc(DE)
	 -- skip:
	_dec(A)
	emit_byte(0x20)		-- jr nz,loop
	emit_byte(0xf2)
	_ex_de_hl()
	stk_push_de()
	_ret()

	-- unsigned 8-bit * 8-bit multiplication routine
	-- source: http://map.grauw.nl/sources/external/z80bits.html#1.1
	mult8_addr = here()
	stk_pop_de()
	_push(DE)
	stk_pop_de()
	_pop(HL)
	_ld(H, L)
	emit_byte(0x2e)		-- ld l,0
	emit_byte(0)
	_sla(H)
	emit_byte(0x30) 	-- jr nc,$+3
	emit_byte(1)
	_ld(L, E)
	for i = 1, 7 do
		_add(HL, HL)
		emit_byte(0x30) -- jr nc,$+3
		emit_byte(1)
		_add(HL, DE)
	end
	_ex_de_hl()
	stk_push_de()
	_ret()
end

local function emit_mcode_wrapper()
	call(here() + 5)	-- call machine code
	emit_short(0xe9fd)	-- jp (iy)
end

local dict = {
	[';'] = function()
		_ret()
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
		_dec(HL)
		emit_byte(0x56) -- ld d,(hl)
		_dec(HL)
		emit_byte(0x5e) -- ld e,(hl)
		stk_push_de()
	end,
	['?dup'] = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		_dec(HL)
		emit_byte(0x56) -- ld d,(hl)
		_dec(HL)
		emit_byte(0x5e) -- ld e,(hl)
		_ld(A, D)
		_or(E)
		emit_byte(0x28)	-- jr z, skip
		emit_byte(1)
		stk_push_de()
		-- skip:
	end,
	over = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		_dec(HL)
		_dec(HL)
		_dec(HL)
		emit_byte(0x56) -- ld d,(hl)
		_dec(HL)
		emit_byte(0x5e) -- ld e,(hl)
		stk_push_de()
	end,
	drop = function()
		emit_byte(0x2a) -- ld hl,(0x3c3b)   (load spare)
		emit_short(0x3c3b)
		_dec(HL)
		_dec(HL)
		emit_byte(0x22) -- ld (0x3c3b),hl
		emit_short(0x3c3b)
	end,
	swap = function()
		stk_pop_de()
		stk_pop_bc()
		stk_push_de()
		_ld(D, B)
		_ld(E, C)
		stk_push_de()
	end,
	pick = function()
		call(0x094d)
	end,
	roll = function()
		call(0x094d)
		_ex_de_hl()
		emit_byte(0x2a) -- ld hl,(0x3c37) (load stkbot)
		emit_short(0x3c37)
		_ld(H, D)
		_ld(L, E)
		_inc(HL)
		_inc(HL)
		_ldir()
		emit_short(0x53ed) -- ld (0x3c3b),de (write spare)
		emit_short(0x3c3b)
	end,
	['r>'] = function()
		_pop(BC)
		_pop(DE)
		_push(BC)
		stk_push_de()
	end,
	['>r'] = function()
		stk_pop_de()
		_pop(BC)
		_push(DE)
		_push(BC)
	end,
    ['+'] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_add(HL, DE)
		_ex_de_hl()
		stk_push_de()
	end,
	['-'] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_ex_de_hl()
		_or(A) -- clear carry
		_sbc(HL, DE)
		_ex_de_hl()
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
		_inc(DE)
		stk_push_de()
	end,
	['1-'] = function()
		stk_pop_de()
		_dec(DE)
		stk_push_de()
	end,
	['2+'] = function()
		stk_pop_de()
		_inc(DE)
		_inc(DE)
		stk_push_de()
	end,
	['2-'] = function()
		stk_pop_de()
		_dec(DE)
		_dec(DE)
		stk_push_de()
	end,
	['='] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_or(A) -- clear carry
		_sbc(HL, DE)
		emit_byte(0x11) -- ld de, 0
		emit_short(0)
		_ld(A, H)
		_or(L)
		emit_byte(0x20)	-- jr nz, neg
		emit_byte(0x01)
		_inc(E)
		-- neg:
		stk_push_de()
	end,
	['>'] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		call(0x0c99)
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		stk_push_de()
	end,
	['<'] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_ex_de_hl()
		call(0x0c99)
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		stk_push_de()
	end,
	['0='] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
		emit_byte(0x11)	-- ld de,1
		emit_short(1)
		emit_byte(0x28)	-- jr z, skip
		emit_byte(1)
		_ld(E, D) -- clear e
		-- skip:
		stk_push_de()
	end,
	['0<'] = function()
		stk_pop_de()
		_rl(D)
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		_ld(D, A)
		_rla()
		_ld(E, A)
        stk_push_de()
	end,
	['0>'] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
		emit_byte(0x28)	-- jr z, skip
		emit_byte(3)
		emit_short(0x12cb)	-- rl d
		_ccf()
		-- skip:
		emit_byte(0x3e) -- ld a,0
		emit_byte(0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		stk_push_de()
	end,
	xor = function()
		stk_pop_de()
		stk_pop_bc()
		_ld(A, E)
		_xor(C)
		_ld(E, A)
		_ld(A, D)
		_xor(B)
		_ld(D, A)
		stk_push_de()
	end,
	['and'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ld(A, E)
		_and(C)
		_ld(E, A)
		_ld(A, D)
		_and(B)
		_ld(D, A)
		stk_push_de()
	end,
	['or'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ld(A, E)
		_or(C)
		_ld(E, A)
		_ld(A, D)
		_or(B)
		_ld(D, A)
		stk_push_de()
	end,
	negate = function()
		stk_pop_de()
		_ex_de_hl()
		_xor(A)
		_sub(L)
		_ld(L, A)
		_sbc(A, A)
		_sub(H)
		_ld(H, A)
		_ex_de_hl()
		stk_push_de()
	end,
	abs = function()
		stk_pop_de()
		emit_short(0x7acb) -- bit 7,d
		emit_byte(0x28) -- jr z,skip
		emit_byte(6)
		_xor(A)
		_sub(E)
		_ld(E, A)
		_sbc(A, A)
		_sub(D)
		_ld(D, A)
		stk_push_de()
	end,
	min = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_push(HL)
		_or(A) -- clear carry
		_sbc(HL, DE)
		_ld(A, H)
		_pop(HL)
		_rl(A)
		emit_byte(0x30) -- jr nc, skip
		emit_byte(1)
		_ex_de_hl()
		-- skip:
		stk_push_de()
	end,
	max = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_push(HL)
		_or(A) -- clear carry
		_sbc(HL, DE)
		_ld(A, H)
		_pop(HL)
		_rl(A)
		emit_byte(0x38) -- jr c, skip
		emit_byte(1)
		_ex_de_hl()
		-- skip:
		stk_push_de()
	end,
	['c!'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ld(A, C)
		emit_byte(0x12) -- ld (de),a
	end,
	['c@'] = function()
		stk_pop_de()
		emit_byte(0x1a) -- ld a,(de)
		_ld(E, A)
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		stk_push_de()
	end,
	['!'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ex_de_hl()
		emit_byte(0x71) -- ld (hl),c
		_inc(HL)
		emit_byte(0x70) -- ld (hl),b
	end,
	['@'] = function()
		stk_pop_de()
		_ex_de_hl()
		emit_byte(0x5e) -- ld e,(hl)
		_inc(HL)
		emit_byte(0x56) -- ld d,(hl)
		stk_push_de()
	end,
	ascii = function()
		compile_dict.ascii()
	end,
	emit = function()
		stk_pop_de()
		_ld(A, E)
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
		-- loop:
		_dec(DE)
		_bit(7, D)
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
		_ld(A, C)
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
		stk_pop_bc()	-- c = port
		stk_pop_de()	-- e = value to output
		_out(C, E)
	end,
	['in'] = function()
		stk_pop_bc()
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		_in(E, C)
		stk_push_de()
	end,
	inkey = function()
		call(0x0336) -- call keyscan routine
		_ld(E, A)
		emit_byte(0x16) -- ld d,0
		emit_byte(0)
		stk_push_de()
	end,
	['if'] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
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
		_ld(A, D)
		_or(E)
		jump_z(target)
	end,
	['do'] = function()
		stk_pop_de() -- pop counter
		stk_pop_bc() -- pop limit
		_push(BC) -- push limit to return stack
		_push(DE) -- push counter to return stack
		push(here())
		push('do')
	end,
	loop = function()
		comp_assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		_pop(DE) -- pop counter
		_pop(BC) -- pop limit
		_inc(DE)
		_ld(H, B)
		_ld(L, C)
		emit_byte(0x37) -- scf (set carry flag)
		_sbc(HL, DE)
		emit_byte(0x38) -- jr c, .done
		local pos = here()
		emit_byte(0)	-- placeholder branch offset
		_push(BC) -- push limit to return stack
		_push(DE) -- push counter to return stack
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
		_pop(DE)
		_push(DE)
		stk_push_de()
	end,
	['i\''] = function()
		_pop(BC)
		_pop(DE)
		_push(DE)
		_push(BC)
		stk_push_de()
	end,
	j = function()
		emit_byte(0x21)	-- ld hl,4
		emit_short(4)
		_add(HL, SP)
		emit_byte(0x5e) -- ld e,(hl)
		_inc(HL)
		emit_byte(0x56) -- ld d,(hl)
		stk_push_de()
	end,
	leave = function()
		_pop(HL) -- pop counter
		_pop(HL) -- pop limit
		_push(HL) -- push limit
		_push(HL) -- push limit as new counter
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
	emit_mcode_wrapper = emit_mcode_wrapper,
	call_forth = call_forth,
	call_mcode = call_mcode,
}