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
local BC_INDIRECT = 0x80
local DE_INDIRECT = 0x90
local HL_INDIRECT = 0xa0

-- system variables
local SCRPOS = 0x3c1c
local STKBOT = 0x3c37
local SPARE = 0x3c3b

local function _ld(dest, src)
	if dest == BC_INDIRECT and src == A then
		-- ld (bc), A
		emit_byte(0x02)
	elseif dest == DE_INDIRECT and src == A then
		-- ld (de), A
		emit_byte(0x12)
	elseif dest == HL_INDIRECT then
		-- ld (hl), r
		assert(src >= 0 and src <= 7, "_ld: unknown src register")
		emit_byte(0x70 + src)
	elseif dest == A and src == BC_INDIRECT then
		-- ld a, (bc)
		emit_byte(0x0a)
	elseif dest == A and src == DE_INDIRECT then
		-- ld a, (de)
		emit_byte(0x1a)
	elseif src == HL_INDIRECT then
		-- ld r, (de)
		-- LD A,(HL)	7E
		-- LD B,(HL)	46
		-- LD C,(HL)	4E
		-- LD D,(HL)	56
		-- LD E,(HL)	5E
		-- LD H,(HL)	66
		-- LD L,(HL)	6E
		assert(dest >= 0 and dest <= 7, "_ld: unknown dest register")
		emit_byte(0x46 + dest * 8)
	else
		-- ld r,r
		assert(dest >= 0 and dest <= 7, "_ld: unknown dest register")
		assert(src >= 0 and src <= 7, "_ld: unknown src register")
		emit_byte(0x40 + dest * 8 + src)
	end
end

local function _ld_const(r, value)
	-- LD A,n		3E n
	-- LD B,n		06 n
	-- LD C,n		0E n
	-- LD D,n		16 n
	-- LD E,n		1E n
	-- LD H,n		26 n
	-- LD L,n		2E n
	-- LD BC,nn		01 nn nn
	-- LD DE,nn		11 nn nn
	-- LD HL,nn		21 nn nn
	-- LD IX,nn		DD 21 nn nn
	-- LD IY,nn		FD 21 nn nn
	if r == BC then
		emit_byte(0x01)
		emit_short(value)
	elseif r == DE then
		emit_byte(0x11)
		emit_short(value)
	elseif r == HL then
		emit_byte(0x21)
		emit_short(value)
	elseif r == IX then
		emit_byte(0xdd)
		emit_byte(0x21)
		emit_short(value)
	elseif r == IY then
		emit_byte(0xfd)
		emit_byte(0x21)
		emit_short(value)
	elseif r >= 0 and r <= 7 then
		emit_byte(0x06 + r * 8)
		emit_byte(value)
	else
		error("_ld_const: unknown register")
	end
end

local function _ld_fetch(r, addr)
	-- LD A,(nn)	3A nn nn
	-- LD BC,(nn)	ED 4B nn nn
	-- LD DE,(nn)	ED 5B nn nn	
	-- LD HL,(nn)	2A nn nn
	-- LD IX,(nn)	DD 2A nn nn
	-- LD IY,(nn)	FD 2A nn nn
	-- LD SP,(nn)	ED 7B nn nn	
	if r == A then
		emit_byte(0x3a)
	elseif r == BC then
		emit_byte(0xed)
		emit_byte(0x4b)
	elseif r == DE then
		emit_byte(0xed)
		emit_byte(0x5b)
	elseif r == HL then
		emit_byte(0x2a)
	elseif r == IX then
		emit_byte(0xdd)
		emit_byte(0x2a)
	elseif r == IY then
		emit_byte(0xfd)
		emit_byte(0x2a)
	elseif r == SP then
		emit_byte(0xed)
		emit_byte(0x7b)
	else
		error("_ld_fetch: unknown register")
	end
	emit_short(addr)
end

local function _ld_store(addr, r)
	-- LD (nn),A	32 nn nn
	-- LD (nn),BC	ED 43 nn nn
	-- LD (nn),DE	ED 53 nn nn
	-- LD (nn),HL	22 nn nn
	-- LD (nn),IX	DD 22 nn nn
	-- LD (nn),IY	FD 22 nn nn
	-- LD (nn),SP	ED 73 nn nn
	if r == A then
		emit_byte(0x32)
	elseif r == BC then
		emit_byte(0xed)
		emit_byte(0x43)
	elseif r == DE then
		emit_byte(0xed)
		emit_byte(0x53)
	elseif r == HL then
		emit_byte(0x22)
	elseif r == IX then
		emit_byte(0xdd)
		emit_byte(0x22)
	elseif r == IY then
		emit_byte(0xfd)
		emit_byte(0x22)
	elseif r == SP then
		emit_byte(0xed)
		emit_byte(0x73)
	else
		error("_ld_store: unknown register")
	end
	emit_short(addr)
end

local function _ld_store_offset_const(r, offset, value)
	-- LD (IX+OFFSET),N		DD 36 o n
	-- LD (IY+OFFSET),N		FD 36 o n
	if r == IX then
		emit_byte(0xdd)
	elseif r == IY then
		emit_byte(0xfd)
	else
		error("_ld_store_offset_const: unknown register")
	end
	emit_byte(0x36)
	emit_byte(offset)
	emit_byte(value)
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

local function _scf()
	emit_byte(0x37)
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

local function _call(addr)
	emit_byte(0xcd)
	emit_short(addr)
end

local function _ret()
	emit_byte(0xc9)
end

local function _jp(addr)
	emit_byte(0xc3)
	emit_short(addr)
end

local function _jp_z(addr)
	emit_byte(0xca)
	emit_short(addr)
end

local function _jp_nz(addr)
	emit_byte(0xc2)
	emit_short(addr)
end

local function _jp_c(addr)
	emit_byte(0xda)
	emit_short(addr)
end

local function _jp_nc(addr)
	emit_byte(0xd2)
	emit_short(addr)
end

local function _jp_indirect_iy()
	emit_byte(0xfd)	-- jp (iy)
	emit_byte(0xe9)
end

local function _jr(offset)
	emit_byte(0x18)
	emit_byte(offset)
end

local function _jr_z(offset)
	emit_byte(0x28)
	emit_byte(offset)
end

local function _jr_nz(offset)
	emit_byte(0x20)
	emit_byte(offset)
end

local function _jr_c(offset)
	emit_byte(0x38)
	emit_byte(offset)
end

local function _jr_nc(offset)
	emit_byte(0x30)
	emit_byte(offset)
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

local function _rst(i)
	assert(i >= 0 and i <= 0x38 and (i & 7) == 0, "invalid reset vector")
	emit_byte(0xc7 + i)
end

-- Pushes DE on Forth stack, trashes HL.
local function stk_push_de()
	_rst(16)
end

-- Pops value from Forth stack and puts it in DE register, trashes HL.
local function stk_pop_de()
	_rst(24)
end

-- Pops value from Forth stack and puts it in BC register.
local function stk_pop_bc()
	_call(0x084e)
end

local function branch_offset(addr)
	local offset = addr - here() - 2
	if offset < -128 or offset > 127 then return end	-- branch too long
	if offset < 0 then offset = offset + 256 end
	return offset
end

-- Emits unconditional jump to <addr>.
local function jump(addr)
	local offset = branch_offset(addr)
	if offset then
		_jr(offset)
	else
		_jp(addr)
	end
end

-- Emits conditional jump which causes a jump to <target> if Z flag is set.
local function jump_z(addr)
	local offset = branch_offset(addr)
	if offset then
		_jr_z(offset)
	else
		_jp_z(offset)
	end
end

local function call_forth(name)
	local addr = compilation_addresses[name] or rom_words[string.upper(name)]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	_call(0x04b9) -- call forth
	emit_short(addr)
	emit_short(0x1a0e) -- end-forth
end

local function call_mcode(name)
	local addr = compilation_addresses[name]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	_call(addr + 7) -- call machine code, skipping the wrapper
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
	_ld_const(HL, 0)
	_ld_const(A, 16)
	-- loop:
	_add(HL, HL)
	_ex_de_hl()
	_adc(HL, HL)
	_ex_de_hl()
	_jr_nc(4) --> skip
	_add(HL, BC)
	_jr_nc(1) --> skip
	_inc(DE)
	 -- skip:
	_dec(A)
	_jr_nz(0xf2) --> loop
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
	_ld_const(L, 0)
	_sla(H)
	_jr_nc(1) --> skip
	_ld(L, E)
	-- skip:
	for i = 1, 7 do
		_add(HL, HL)
		_jr_nc(1) --> skipn
		_add(HL, DE)
		-- skipn:
	end
	_ex_de_hl()
	stk_push_de()
	_ret()
end

local function emit_mcode_wrapper()
	_call(here() + 5)	-- call machine code
	_jp_indirect_iy()
end

local function emit_literal(n)
	_ld_const(DE, n)
	_rst(16)
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
		_ld_fetch(HL, SPARE)
		_dec(HL)
		_ld(D, HL_INDIRECT)
		_dec(HL)
		_ld(E, HL_INDIRECT)
		stk_push_de()
	end,
	['?dup'] = function()
		_ld_fetch(HL, SPARE)
		_dec(HL)
		_ld(D, HL_INDIRECT)
		_dec(HL)
		_ld(E, HL_INDIRECT)
		_ld(A, D)
		_or(E)
		_jr_z(1) --> skip
		stk_push_de()
		-- skip:
	end,
	over = function()
		_ld_fetch(HL, SPARE)
		_dec(HL)
		_dec(HL)
		_dec(HL)
		_ld(D, HL_INDIRECT)
		_dec(HL)
		_ld(E, HL_INDIRECT)
		stk_push_de()
	end,
	drop = function()
		_ld_fetch(HL, SPARE)
		_dec(HL)
		_dec(HL)
		_ld_store(SPARE, HL)
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
		_call(0x094d)
	end,
	roll = function()
		_call(0x094d)
		_ex_de_hl()
		_ld_fetch(HL, STKBOT)
		_ld(H, D)
		_ld(L, E)
		_inc(HL)
		_inc(HL)
		_ldir()
		_ld_store(SPARE, DE)
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
		_call(mult16_addr)
	end,
	['c*'] = function()
		assert(mult8_addr, "mcode subroutines not found")
		_call(mult8_addr)
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
		_ld_const(DE, 0)
		_ld(A, H)
		_or(L)
		_jr_nz(1) --> neg
		_inc(E)
		-- neg:
		stk_push_de()
	end,
	['>'] = function()
		stk_pop_de()
		_push(DE)
		stk_pop_de()
		_pop(HL)
		_call(0x0c99)
		_ld_const(A, 0)
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
		_call(0x0c99)
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		stk_push_de()
	end,
	['0='] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
		_ld_const(DE, 1)
		_jr_z(1) --> skip
		_ld(E, D) -- clear e
		-- skip:
		stk_push_de()
	end,
	['0<'] = function()
		stk_pop_de()
		_rl(D)
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
        stk_push_de()
	end,
	['0>'] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
		_jr_z(3) --> skip
		_rl(D)
		_ccf()	-- invert carry flag
		-- skip:
		_ld_const(A, 0)
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
		_bit(7, D)
		_jr_z(6) --> skip
		_xor(A)
		_sub(E)
		_ld(E, A)
		_sbc(A, A)
		_sub(D)
		_ld(D, A)
		-- skip:
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
		_jr_nc(1) --> skip
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
		_jr_c(1) --> skip
		_ex_de_hl()
		-- skip:
		stk_push_de()
	end,
	['c!'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ld(A, C)
		_ld(DE_INDIRECT, A)
	end,
	['c@'] = function()
		stk_pop_de()
		_ld(A, DE_INDIRECT)
		_ld(E, A)
		_ld_const(D, 0)
		stk_push_de()
	end,
	['!'] = function()
		stk_pop_de()
		stk_pop_bc()
		_ex_de_hl()
		_ld(HL_INDIRECT, C)
		_inc(HL)
		_ld(HL_INDIRECT, B)
	end,
	['@'] = function()
		stk_pop_de()
		_ex_de_hl()
		_ld(E, HL_INDIRECT)
		_inc(HL)
		_ld(D, HL_INDIRECT)
		stk_push_de()
	end,
	ascii = function()
		compile_dict.ascii()
	end,
	emit = function()
		stk_pop_de()
		_ld(A, E)
		_rst(8)
	end,
	cr = function()
		_ld_const(A, 0x0d)
		_rst(8)
	end,
	space = function()
		_ld_const(A, 0x20)
		_rst(8)
	end,
	spaces = function()
		stk_pop_de()
		-- loop:
		_dec(DE)
		_bit(7, D)
		_jr_nz(5) --> done
		_ld_const(A, 0x20)
		_rst(8)
		_jr(0xf6) --> loop
		-- done:
	end,
	at = function()
		stk_pop_de()
		_call(0x084e)
		_ld(A, C)
		_call(0x0b28)
		_ld_store(SCRPOS, HL)
	end,
	type = function()
		stk_pop_bc()
		stk_pop_de()
		_call(0x097f) -- call print string routine
	end,
	base = function()
		_ld_const(DE, 0x3c3f)
		stk_push_de()
	end,
	decimal = function()
		_ld_store_offset_const(IX, 0x3f, 0x0a)
	end,
	out = function()
		stk_pop_bc()	-- c = port
		stk_pop_de()	-- e = value to output
		_out(C, E)
	end,
	['in'] = function()
		stk_pop_bc()
		_ld_const(D, 0)
		_in(E, C)
		stk_push_de()
	end,
	inkey = function()
		_call(0x0336) -- call keyscan routine
		_ld(E, A)
		_ld_const(D, 0)
		stk_push_de()
	end,
	['if'] = function()
		stk_pop_de()
		_ld(A, D)
		_or(E)
		push(here() + 1)
		push('if')
		-- TODO: this could be optimized to _jr_z()
		_jp_z(0)	-- placeholder jump addr
	end,
	['else'] = function()
		comp_assert(pop() == 'if', "ELSE without matching IF")
		local where = pop()
		-- emit jump to THEN
		push(here() + 1)
		push('if')
		-- TODO: this could be optimized to _jr()
		_jp(0) -- placeholder jump addr
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
			gotos[here() + 1] = label
			_jp(0)
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
		_scf() -- set carry
		_sbc(HL, DE)
		local pos = here() + 1
		_jr_c(0)	--> done (placeholder branch offset)
		_push(BC) -- push limit to return stack
		_push(DE) -- push counter to return stack
		jump(target)
		write_byte(pos, here() - pos - 1)
		-- done:
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
		_ld_const(HL, 4)
		_add(HL, SP)
		_ld(E, HL_INDIRECT)
		_inc(HL)
		_ld(D, HL_INDIRECT)
		stk_push_de()
	end,
	leave = function()
		_pop(HL) -- pop counter
		_pop(HL) -- pop limit
		_push(HL) -- push limit
		_push(HL) -- push limit as new counter
	end,
	exit = function()
		_jp_indirect_iy()
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
		_ld_const(DE, here() + 8) -- load string address to DE
		_call(0x0979) -- call print embedded string routine
		_jr(#str + 2) --> done
		emit_short(#str)
		emit_string(str)
		-- done:
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
	emit_literal = emit_literal,
	call_forth = call_forth,
	call_mcode = call_mcode,
}