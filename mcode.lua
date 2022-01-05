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

local reg_name = {
	[A] = "a",
	[B] = "b",
	[C] = "c",
	[D] = "d",
	[E] = "e",
	[H] = "h",
	[L] = "l",
	[AF] = "af",
	[BC] = "bc",
	[DE] = "de",
	[HL] = "hl",
	[IX] = "ix",
	[IY] = "iy",
	[SP] = "sp",
	[BC_INDIRECT] = "(bc)",
	[DE_INDIRECT] = "(de)",
	[HL_INDIRECT] = "(hl)",
}

local function _ld(dest, src)
	list_here()

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

	list_instr("ld %s,%s", reg_name[dest], reg_name[src])
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

	list_here()

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

	if r >= 0 and r <= 7 then
		list_instr("ld %s,$%02x", reg_name[r], value)
	else
		list_instr("ld %s,$%04x", reg_name[r], value)
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

	list_here()

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

	list_instr("ld %s,($%04x)", reg_name[r], addr)
end

local function _ld_store(addr, r)
	-- LD (nn),A	32 nn nn
	-- LD (nn),BC	ED 43 nn nn
	-- LD (nn),DE	ED 53 nn nn
	-- LD (nn),HL	22 nn nn
	-- LD (nn),IX	DD 22 nn nn
	-- LD (nn),IY	FD 22 nn nn
	-- LD (nn),SP	ED 73 nn nn

	list_here()

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

	list_instr("ld ($%04x),%s", addr, reg_name[r])
end

local function _ld_store_offset_const(r, offset, value)
	-- LD (IX+OFFSET),N		DD 36 o n
	-- LD (IY+OFFSET),N		FD 36 o n

	list_here()

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

	list_instr("ld (%s+$%02x),$%02x", reg_name[r], offset, value)
end

local function _exx()
	list_here()
	emit_byte(0xd9)
	list_instr("exx")
end

local function _ex_de_hl()
	list_here()
	emit_byte(0xeb)
	list_instr("ex de,hl")
end

local function _ex_af_af()
	list_here()
	emit_byte(0x08)
	list_instr("ex af,af'")
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

	list_here()

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

	list_instr("inc %s", reg_name[r])
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

	list_here()

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

	list_instr("dec %s", reg_name[r])
end

local function _xor(r)
	assert(r >= 0 and r <= 7, "_xor: unknown register")
	list_here()
	emit_byte(0xa8 + r)
	list_instr("xor %s", reg_name[r])
end

local function _and(r)
	assert(r >= 0 and r <= 7, "_and: unknown register")
	list_here()
	emit_byte(0xa0 + r)
	list_instr("and %s", reg_name[r])
end

local function _or(r)
	assert(r >= 0 and r <= 7, "_or: unknown register")
	list_here()
	emit_byte(0xb0 + r)
	list_instr("or %s", reg_name[r])
end

local function _ccf()
	list_here()
	emit_byte(0x3f)
	list_instr("ccf")
end

local function _scf()
	list_here()
	emit_byte(0x37)
	list_instr("scf")
end

local function _add(dest, src)
	-- ADD HL,BC	09
	-- ADD HL,DE	19
	-- ADD HL,HL	29
	-- ADD HL,SP	39

	list_here()

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

	list_instr("add %s,%s", reg_name[dest], reg_name[src])
end

local function _adc(dest, src)
	-- ADC HL,BC 	ED 4A
	-- ADC HL,DE 	ED 5A
	-- ADC HL,HL 	ED 6A
	-- ADC HL,SP 	ED 7A

	list_here()

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

	list_instr("adc %s,%s", reg_name[dest], reg_name[src])
end

local function _sub(r)
	assert(r >= 0 and r <= 7, "_sub: unknown register")
	list_here()
	emit_byte(0x90 + r)
	list_instr("sub %s", reg_name[r])
end

local function _sbc(dest, src)
	-- SBC HL,BC	ED 42
	-- SBC HL,DE	ED 52
	-- SBC HL,HL	ED 62
	-- SBC HL,SP	ED 72

	list_here()

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

	list_instr("sbc %s,%s", reg_name[dest], reg_name[src])
end

local function _bit(i, r)
	assert(r >= 0 and r <= 7, "_bit: unknown register")
	list_here()
	emit_byte(0xcb)
	emit_byte(0x40 + 8 * i + r)
	list_instr("bit %s,%s", i, reg_name[r])
end

local function _sla(r)
	assert(r >= 0 and r <= 7, "_sla: unknown register")
	list_here()
	emit_byte(0xcb)
	emit_byte(0x20 + r)
	list_instr("sla %s", reg_name[r])
end

local function _rl(r)
	assert(r >= 0 and r <= 7, "_rl: unknown register")
	list_here()
	emit_byte(0xcb)
	emit_byte(0x10 + r)
	list_instr("rl %s", reg_name[r])
end

local function _rla()
	list_here()
	emit_byte(0x17)
	list_instr("rla")
end

local function _ldir()
	list_here()
	emit_byte(0xed)
	emit_byte(0xb0)
	list_instr("ldir")
end

local function _push(r)
	-- PUSH AF	F5
	-- PUSH BC	C5
	-- PUSH DE	D5
	-- PUSH HL	E5
	-- PUSH IX	DD E5
	-- PUSH IY	FD E5

	list_here()

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

	list_instr("push %s", reg_name[r])
end

local function _pop(r)
	-- POP AF	F1
	-- POP BC	C1
	-- POP DE	D1
	-- POP HL	E1
	-- POP IX	DD E1
	-- POP IY	FD E1

	list_here()

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

	list_instr("pop %s", reg_name[r])
end

local function _call(addr)
	list_here()
	emit_byte(0xcd)
	emit_short(addr)
	list_instr("call $%04x", addr)
end

local function _ret()
	list_here()
	emit_byte(0xc9)
	list_instr("ret")
end

local function _jp(addr)
	list_here()
	emit_byte(0xc3)
	emit_short(addr)
	list_instr("jp ")
	list_instr("$%04x", addr)
end

local function _jp_z(addr)
	list_here()
	emit_byte(0xca)
	emit_short(addr)
	list_instr("jp z,")
	list_instr("$%04x", addr)
end

local function _jp_nz(addr)
	list_here()
	emit_byte(0xc2)
	emit_short(addr)
	list_instr("jp nz,")
	list_instr("$%04x", addr)
end

local function _jp_c(addr)
	list_here()
	emit_byte(0xda)
	emit_short(addr)
	list_instr("jp c,")
	list_instr("$%04x", addr)
end

local function _jp_nc(addr)
	list_here()
	emit_byte(0xd2)
	emit_short(addr)
	list_instr("jp nc,")
	list_instr("$%04x", addr)
end

local function _jp_indirect_iy()
	list_here()
	emit_byte(0xfd)	-- jp (iy)
	emit_byte(0xe9)
	list_instr("jp (iy)")
end

local function offset_to_absolute(offset)
	if offset > 127 then offset = offset - 256 end
	return here() + offset
end

local function patch_jump_listing(listing_pos, addr)
	local opcode = read_byte(addr)
	if opcode < 0x80 then
		-- relative jump
		local offset = read_byte(addr + 1)
		list_patch(listing_pos + 2, string.format(" %02x", offset))
		list_patch(listing_pos + 5, string.format("$%04x", addr + offset + 2))
	else
		-- absolute jump
		local target_addr = read_short(addr + 1)
		list_patch(listing_pos + 2, string.format(" %02x", target_addr & 0xff))
		list_patch(listing_pos + 3, string.format(" %02x", target_addr >> 8))
		list_patch(listing_pos + 6, string.format("$%04x", target_addr))
	end
end

local function _jr(offset)
	list_here()
	emit_byte(0x18)
	emit_byte(offset)
	list_instr("jr ")
	list_instr("$%04x", offset_to_absolute(offset))
end

local function _jr_z(offset)
	list_here()
	emit_byte(0x28)
	emit_byte(offset)
	list_instr("jr z,")
	list_instr("$%04x", offset_to_absolute(offset))
end

local function _jr_nz(offset)
	list_here()
	emit_byte(0x20)
	emit_byte(offset)
	list_instr("jr nz,")
	list_instr("$%04x", offset_to_absolute(offset))
end

local function _jr_c(offset)
	list_here()
	emit_byte(0x38)
	emit_byte(offset)
	list_instr("jr c,")
	list_instr("$%04x", offset_to_absolute(offset))
end

local function _jr_nc(offset)
	list_here()
	emit_byte(0x30)
	emit_byte(offset)
	list_instr("jr nc,")
	list_instr("$%04x", offset_to_absolute(offset))
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
	list_here()
	emit_byte(0xed)
	emit_byte(0x40 + r * 8)
	list_instr("in %s,(%s)", reg_name[r], reg_name[port])
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
	list_here()
	emit_byte(0xed)
	emit_byte(0x41 + r * 8)
	list_instr("out (%s),%s", reg_name[port], reg_name[r])
end

local function _rst(i)
	assert(i >= 0 and i <= 0x38 and (i & 7) == 0, "invalid reset vector")
	list_here()
	emit_byte(0xc7 + i)
	list_instr("rst %s", i)
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
		_jp_z(addr)
	end
end

-- Emits conditional jump which causes a jump to <target> if C flag is clear.
local function jump_nc(addr)
	local offset = branch_offset(addr)
	if offset then
		_jr_nc(offset)
	else
		_jp_nc(addr)
	end
end

local function call_forth(name)
	local addr = compilation_addresses[name] or rom_words[string.upper(name)]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	stk_push_de()
	_call(0x04b9) -- call forth
	list_comment("call forth")
	list_here()
	emit_short(addr)
	list_instr(name)
	list_here()
	emit_short(0x1a0e) -- end-forth
	list_instr("end-forth")
	stk_pop_de()
end

local function call_mcode(name)
	local addr = compilation_addresses[name]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	_call(addr + 9) -- call machine code, skipping the wrapper
	list_comment(name)
end

local mult16_addr
local mult8_addr

-- Emits invisible subroutine words to be used by mcode words.
local function emit_subroutines()
	-- signed 16-bit * 16-bit multiplication routine
	create_word(0, "_mcode", true)
	mult16_addr = here()
	list_header("mult16")
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
	_ret()

	-- unsigned 8-bit * 8-bit multiplication routine
	-- source: http://map.grauw.nl/sources/external/z80bits.html#1.1
	mult8_addr = here()
	list_header("mult8")
	stk_pop_bc()
	_ld(H, C)
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
	_ret()
end

local function emit_mcode_wrapper()
	-- calling mcode from Forth
	stk_pop_de()		-- move top of stack to DE
	_call(here() + 6)	-- call machine code
	stk_push_de()		-- push top of stack back to Forth stack
	_jp_indirect_iy()	-- return to Forth
end

local function emit_literal(n, comment)
	stk_push_de()
	_ld_const(DE, n)
	if comment then
		list_comment(comment)
	else
		list_comment("lit %d", n)
	end
end

local dict = {
	[';'] = function()
		_ret()

		interpreter_state()
		check_control_flow_stack()

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
		stk_push_de(); list_comment("dup")
	end,
	['?dup'] = function()
		_ld(A, D); list_comment("?dup")
		_or(E)
		_jr_z(1) --> skip
		stk_push_de()
		-- skip:
	end,
	over = function()
		_ld_fetch(BC, SPARE); list_comment("over")
		stk_push_de() -- push old top
		_dec(BC)
		_ld(A, BC_INDIRECT)
		_ld(D, A)
		_dec(BC)
		_ld(A, BC_INDIRECT)
		_ld(E, A)
	end,
	drop = function()
		stk_pop_de(); list_comment("drop")
	end,
	swap = function()
		stk_pop_bc(); list_comment("swap")
		stk_push_de()
		_ld(D, B)
		_ld(E, C)
	end,
	pick = function()
		stk_push_de(); list_comment("pick")
		_call(0x094d)
		stk_pop_de()
	end,
	roll = function()
		-- TODO: subroutine?
		stk_push_de(); list_comment("roll")
		_call(0x094d);
		_ex_de_hl()
		_ld_fetch(HL, STKBOT)
		_ld(H, D)
		_ld(L, E)
		_inc(HL)
		_inc(HL)
		_ldir()
		_ld_store(SPARE, DE)
		stk_pop_de()
	end,
	['r>'] = function()
		stk_push_de(); list_comment("r>")
		_pop(DE)
	end,
	['>r'] = function()
		_push(DE); list_comment(">r")
		stk_pop_de()
	end,
	['r@'] = function()
		stk_push_de(); list_comment("r@")
		_pop(DE)
		_push(DE)
	end,
    ['+'] = function()
		-- TODO: optimize <literal> + as a special case
		stk_pop_bc(); list_comment("+")
		_ex_de_hl()
		_add(HL, BC)
		_ex_de_hl()
	end,
	['-'] = function()
		-- TODO: optimize <literal> - as a special case
		_ld(B, D); list_comment("-")
		_ld(C, E)
		stk_pop_de()
		_ex_de_hl()
		_or(A) -- clear carry
		_sbc(HL, BC)
		_ex_de_hl()
	end,
	['*'] = function()
		assert(mult16_addr, "mcode subroutines not found")
		_call(mult16_addr); list_comment("*")
	end,
	['c*'] = function()
		assert(mult8_addr, "mcode subroutines not found")
		_call(mult8_addr); list_comment("c*")
	end,
	['1+'] = function()
		_inc(DE); list_comment("1+")
	end,
	['1-'] = function()
		_dec(DE); list_comment("1-")
	end,
	['2+'] = function()
		_inc(DE); list_comment("2+")
		_inc(DE)
	end,
	['2-'] = function()
		_dec(DE); list_comment("2-")
		_dec(DE)
	end,
	negate = function()
		_xor(A); list_comment("negate")
		_sub(E)
		_ld(E, A)
		_sbc(A, A)
		_sub(D)
		_ld(D, A)
	end,
	abs = function()
		_bit(7, D); list_comment("abs")
		_jr_z(6) --> skip
		_xor(A)
		_sub(E)
		_ld(E, A)
		_sbc(A, A)
		_sub(D)
		_ld(D, A)
		-- skip:
	end,
	min = function()
		stk_pop_bc(); list_comment("min")
		_ld(H, D)
		_ld(L, E)
		_or(A) -- clear carry
		_sbc(HL, BC)
		_rl(H)
		_jr_c(2) --> skip
		_ld(D, B)
		_ld(E, C)
		-- skip:
	end,
	max = function()
		stk_pop_bc(); list_comment("max")
		_ld(H, D)
		_ld(L, E)
		_or(A) -- clear carry
		_sbc(HL, BC)
		_rl(H)
		_jr_nc(2) --> skip
		_ld(D, B)
		_ld(E, C)
		-- skip:
	end,
	xor = function()
		stk_pop_bc(); list_comment("xor")
		_ld(A, E)
		_xor(C)
		_ld(E, A)
		_ld(A, D)
		_xor(B)
		_ld(D, A)
	end,
	['and'] = function()
		stk_pop_bc(); list_comment("and")
		_ld(A, E)
		_and(C)
		_ld(E, A)
		_ld(A, D)
		_and(B)
		_ld(D, A)
	end,
	['or'] = function()
		stk_pop_bc(); list_comment("or")
		_ld(A, E)
		_or(C)
		_ld(E, A)
		_ld(A, D)
		_or(B)
		_ld(D, A)
	end,
	['0='] = function()
		_ld(A, D); list_comment("0=")
		_or(E)
		_ld_const(DE, 1)
		_jr_z(1) --> skip
		_ld(E, D) -- clear e
		-- skip:
	end,
	['0<'] = function()
		_rl(D); list_comment("0<")
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
	end,
	['0>'] = function()
		_ld(A, D); list_comment("0>")
		_or(E)
		_jr_z(3) --> skip
		_rl(D)
		_ccf()	-- invert carry flag
		-- skip:
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
	end,
	['='] = function()
		stk_pop_bc(); list_comment("=")
		_ex_de_hl()
		_or(A) -- clear carry
		_sbc(HL, BC)
		_ld_const(DE, 0)
		_jr_nz(1) --> skip
		_inc(E)
		-- skip:
	end,
	['>'] = function()
		-- TODO: subroutine? (inline routine at $0c99)
		stk_pop_bc(); list_comment(">")
		_ld(H, B)
		_ld(L, C)
		_ex_de_hl()
		_call(0x0c99)	-- sign routine in ROM, in: HL = value1, DE = value2
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
	end,
	['<'] = function()
		-- TODO: subroutine? (inline routine at $0c99)
		stk_pop_bc(); list_comment(">")
		_ld(H, B)
		_ld(L, C)
		_call(0x0c99)	-- sign routine in ROM, in: HL = value1, DE = value2
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
	end,
	['!'] = function()
		-- ( n addr -- )
		stk_pop_bc(); list_comment("!")
		_ex_de_hl()
		_ld(HL_INDIRECT, C)
		_inc(HL)
		_ld(HL_INDIRECT, B)
		stk_pop_de()
	end,
	['@'] = function()
		-- ( addr -- n )
		_ex_de_hl(); list_comment("@")
		_ld(E, HL_INDIRECT)
		_inc(HL)
		_ld(D, HL_INDIRECT)
	end,
	['c!'] = function()
		-- ( n addr -- )
		stk_pop_bc(); list_comment("c!")
		_ld(A, C)
		_ld(DE_INDIRECT, A)
		stk_pop_de()
	end,
	['c@'] = function()
		-- ( addr - n )
		_ld(A, DE_INDIRECT); list_comment("c@")
		_ld(E, A)
		_ld_const(D, 0)
	end,
	ascii = function()
		(compile_dict.ascii or compile_dict.ASCII)()
	end,
	emit = function()
		_ld(A, E); list_comment("emit")
		_rst(8)
		stk_pop_de()
	end,
	cr = function()
		_ld_const(A, 0x0d); list_comment("cr")
		_rst(8)
	end,
	space = function()
		_ld_const(A, 0x20); list_comment("space")
		_rst(8)
	end,
	spaces = function()
		-- loop:
		_dec(DE); list_comment("spaces")
		_bit(7, D)
		_jr_nz(5) --> done
		_ld_const(A, 0x20)
		_rst(8)
		_jr(0xf6) --> loop
		-- done:
		stk_pop_de()
	end,
	at = function()
		_call(0x084e); list_comment("at")
		_ld(A, C)
		_call(0x0b28)
		_ld_store(SCRPOS, HL)
		stk_pop_de()
	end,
	type = function()
		-- ( addr count -- )
		_ld(B, D); list_comment("type")	-- move count from DE to BC
		_ld(C, E)
		stk_pop_de()
		_call(0x097f) -- call print string routine (BC = count, DE = addr)
		stk_pop_de()
	end,
	base = function()
		stk_push_de(); list_comment("base")
		_ld_const(DE, 0x3c3f)
	end,
	decimal = function()
		_ld_store_offset_const(IX, 0x3f, 0x0a); list_comment("decimal")
	end,
	out = function()
		-- ( n port -- )
		_ld(C, E); list_comment("out")	-- C = port
		stk_pop_de()	-- E = value to output (stk_pop_de does not trash C)
		_out(C, E)
		stk_pop_de()
	end,
	['in'] = function()
		-- ( port -- n )
		_ld(C, E); list_comment("in")	-- C = port
		_ld_const(D, 0)
		_in(E, C)
	end,
	inkey = function()
		-- ( -- n )
		stk_push_de(); list_comment("inkey")
		_call(0x0336) -- call keyscan routine
		_ld(E, A)
		_ld_const(D, 0)
	end,
	['if'] = function()
		_ld(A, D); list_comment("if")
		_or(E)
		stk_pop_de()
		cf_push(here())
		cf_push(list_pos())
		cf_push('if')
		-- TODO: this could be optimized to _jr_z()
		_jp_z(0)	-- placeholder jump addr
	end,
	['else'] = function()
		comp_assert(cf_pop() == 'if', "ELSE without matching IF")
		local listing_pos = cf_pop()
		local where = cf_pop()
		-- emit jump to THEN
		cf_push(here())
		cf_push(list_pos())
		cf_push('if')
		-- TODO: this could be optimized to _jr()
		_jp(0); list_comment("else") -- placeholder jump addr
		-- patch jump target at previous IF
		write_short(where + 1, here())
		patch_jump_listing(listing_pos, where)
	end,
	['then'] = function()
		comp_assert(cf_pop() == 'if', "THEN without matching IF")
		local listing_pos = cf_pop()
		local where = cf_pop()
		-- patch jump target at previous IF or ELSE
		write_short(where + 1, here())
		patch_jump_listing(listing_pos, where)
	end,
	label = function()
		local label = next_symbol()
		labels[label] = here()
		list_here()
		list_instr("label %s", label)
	end,
	['goto'] = function()
		local label = next_symbol()

		if labels[label] then
			-- label found -> this is a backward jump
			-- emit the jump immediately
			jump(labels[label]); list_comment("goto (backward)")
		else
			-- label not found -> this is a forward jump
			-- emit placeholder jump and resolve jump address in ;
			gotos[here() + 1] = label
			_jp(0); list_comment("goto (forward)")
		end
	end,
	begin = function()
		cf_push(here())
		cf_push('begin')
	end,
	again = function()
		comp_assert(cf_pop() == 'begin', "AGAIN without matching BEGIN")
		local target = cf_pop()
		jump(target); list_comment("again")
	end,
	['until'] = function()
		comp_assert(cf_pop() == 'begin', "UNTIL without matching BEGIN")
		local target = cf_pop()
		_ld(A, D); list_comment("until")
		_or(E)
		_ex_af_af()	-- store Z flag
		stk_pop_de()
		_ex_af_af()	-- restore Z flag
		jump_z(target)
	end,
	['do'] = function()
		-- ( limit counter -- )
		stk_pop_bc(); list_comment("do") -- pop limit
		_push(BC) -- push limit to return stack
		_push(DE) -- push counter to return stack
		stk_pop_de()
		cf_push(here())
		cf_push('do')
	end,
	loop = function()
		comp_assert(cf_pop() == 'do', "LOOP without matching DO")
		local target = cf_pop()
		_exx(); list_comment("loop")
		_pop(DE) -- pop counter
		_pop(BC) -- pop limit
		_inc(DE)
		_ld(H, B)
		_ld(L, C)
		_scf() -- set carry
		_sbc(HL, DE)
		_push(BC) -- push limit
		_push(DE) -- push counter
		_exx()
		jump_nc(target)
		_pop(BC) -- end of loop -> pop limit & counter from stack
		_pop(BC)
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
		stk_push_de(); list_comment("i")
		_pop(DE)
		_push(DE)
	end,
	['i\''] = function()
		stk_push_de(); list_comment("i'")
		_pop(BC)
		_pop(DE)
		_push(DE)
		_push(BC)
		
	end,
	j = function()
		stk_push_de(); list_comment("j")
		_ld_const(HL, 4)
		_add(HL, SP)
		_ld(E, HL_INDIRECT)
		_inc(HL)
		_ld(D, HL_INDIRECT)
	end,
	leave = function()
		_pop(HL); list_comment("leave") -- pop counter
		_pop(HL) -- pop limit
		_push(HL) -- push limit
		_push(HL) -- push limit as new counter
	end,
	exit = function()
		_ret(); list_comment("exit")
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
		(compile_dict.lit or compile_dict.LIT)()
	end,
	['."'] = function()
		local str = next_symbol_with_delimiter('"')
		local offset = #str + 2 -- branch offset for jumping over string data

		_exx(); list_comment('."')	-- preserve DE

		-- compute address of string
		local str_addr = here() + 9
		if offset >= 128 then str_addr = str_addr + 1 end

		_ld_const(DE, str_addr) -- load string address to DE
		_call(0x0979) -- call print embedded string routine
		_exx()

		-- jump over following string data
		if offset < 128 then
			_jr(offset)
		else
			_jp(here() + #str + 2)
		end

		-- emit string data
		list_here()
		emit_short(#str)
		emit_string(str)
		list_comment('"%s"', str)
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