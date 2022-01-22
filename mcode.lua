-- Machine code compile dictionary

local decode_tree = require "z80_opcodes"

local labels = {}	-- label -> address for current word
local gotos = {}	-- address to be patched -> label for current word

local literal_pos	-- the dictionary position just after the newest emitted literal
local literal_pos2	-- the dictionary position of the second newest literal

local call_pos		-- the dictionary position just after the newest emitted Z80 call instruction
local jump_targets = {}	-- addresses targeted by (forward) jumps, for detecting when tail-calls can't be used

local long_jumps = {}	-- locations in source code where jumps must be long (for ELSE and THEN)

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
	list_line("ld %s,%s", reg_name[dest], reg_name[src])

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

	if r >= 0 and r <= 7 then
		list_line("ld %s,$%02x", reg_name[r], value)
	else
		list_line("ld %s,$%04x", reg_name[r], value)
	end		

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

	list_line("ld %s,($%04x)", reg_name[r], addr)

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

	list_line("ld ($%04x),%s", addr, reg_name[r])

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

	list_line("ld (%s+$%02x),$%02x", reg_name[r], offset, value)

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

local function _exx()
	list_line("exx")
	emit_byte(0xd9)
end

local function _ex_de_hl()
	list_line("ex de,hl")
	emit_byte(0xeb)
end

local function _ex_af_af()
	list_line("ex af,af'")
	emit_byte(0x08)
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
	-- INC (HL)	34

	list_line("inc %s", reg_name[r])

	if r == BC then
		emit_byte(0x03)
	elseif r == DE then
		emit_byte(0x13)
	elseif r == HL then
		emit_byte(0x23)
	elseif r == HL_INDIRECT then
		emit_byte(0x34)
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
	-- DEC (HL)	35

	list_line("dec %s", reg_name[r])

	if r == BC then
		emit_byte(0x0b)
	elseif r == DE then
		emit_byte(0x1b)
	elseif r == HL then
		emit_byte(0x2b)
	elseif r == HL_INDIRECT then
		emit_byte(0x35)
	elseif r >= 0 and r <= 7 then
		emit_byte(0x05 + r * 8)
	else
		error("_dec: unknown register")
	end
end

local function _xor(r)
	assert(r >= 0 and r <= 7, "_xor: unknown register")
	list_line("xor %s", reg_name[r])
	emit_byte(0xa8 + r)
end

local function _xor_const(n)
	list_line("xor %d", n)
	emit_byte(0xee)
	emit_byte(n)
end

local function _and(r)
	assert(r >= 0 and r <= 7, "_and: unknown register")
	list_line("and %s", reg_name[r])
	emit_byte(0xa0 + r)
end

local function _and_const(n)
	list_line("and %d", n)
	emit_byte(0xe6)
	emit_byte(n)
end

local function _or(r)
	assert(r >= 0 and r <= 7, "_or: unknown register")
	list_line("or %s", reg_name[r])
	emit_byte(0xb0 + r)
end

local function _or_const(n)
	list_line("or %d", n)
	emit_byte(0xf6)
	emit_byte(n)
end

local function _ccf()
	list_line("ccf")
	emit_byte(0x3f)
end

local function _scf()
	list_line("scf")
	emit_byte(0x37)
end

local function _add(dest, src)
	-- ADD HL,BC	09
	-- ADD HL,DE	19
	-- ADD HL,HL	29
	-- ADD HL,SP	39

	list_line("add %s,%s", reg_name[dest], reg_name[src])

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

local function _add_const(n)
	list_line("add %d", n)
	emit_byte(0xc6)
	emit_byte(n)
end

local function _adc(dest, src)
	-- ADC HL,BC 	ED 4A
	-- ADC HL,DE 	ED 5A
	-- ADC HL,HL 	ED 6A
	-- ADC HL,SP 	ED 7A

	list_line("adc %s,%s", reg_name[dest], reg_name[src])

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
	list_line("sub %s", reg_name[r])
	emit_byte(0x90 + r)
end

local function _sub_const(n)
	list_line("sub %d", n)
	emit_byte(0xd6)
	emit_byte(n)
end

local function _sbc(dest, src)
	-- SBC HL,BC	ED 42
	-- SBC HL,DE	ED 52
	-- SBC HL,HL	ED 62
	-- SBC HL,SP	ED 72

	list_line("sbc %s,%s", reg_name[dest], reg_name[src])

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

local function _cp_const(n)
	list_line("cp %d", n)
	emit_byte(0xfe)
	emit_byte(n)
end

local function _bit(i, r)
	assert(r >= 0 and r <= 7, "_bit: unknown register")
	list_line("bit %s,%s", i, reg_name[r])
	emit_byte(0xcb)
	emit_byte(0x40 + 8 * i + r)
end

local function _sla(r)
	assert(r >= 0 and r <= 7, "_sla: unknown register")
	list_line("sla %s", reg_name[r])
	emit_byte(0xcb)
	emit_byte(0x20 + r)
end

local function _sra(r)
	assert(r >= 0 and r <= 7, "_sra: unknown register")
	list_line("sra %s", reg_name[r])
	emit_byte(0xcb)
	emit_byte(0x28 + r)
end

local function _rl(r)
	assert(r >= 0 and r <= 7, "_rl: unknown register")
	list_line("rl %s", reg_name[r])
	emit_byte(0xcb)
	emit_byte(0x10 + r)
end

local function _rr(r)
	assert(r >= 0 and r <= 7, "_rr: unknown register")
	list_line("rr %s", reg_name[r])
	emit_byte(0xcb)
	emit_byte(0x18 + r)
end

local function _rla()
	list_line("rla")
	emit_byte(0x17)
end

local function _ldir()
	list_line("ldir")
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

	list_line("push %s", reg_name[r])

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

	list_line("pop %s", reg_name[r])

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
	list_line("call $%04x", addr)
	emit_byte(0xcd)
	emit_short(addr)
	call_pos = here()
end

local function _ret()
	list_line("ret")
	emit_byte(0xc9)
end

local function _ret_c()
	list_line("ret c")
	emit_byte(0xd8)
end

local function _ret_nc()
	list_line("ret nc")
	emit_byte(0xd0)
end

local function _jp(addr)
	list_line("jp $%04x", addr)
	emit_byte(0xc3)
	emit_short(addr)
end

local function _jp_z(addr)
	list_line("jp z,$%04x", addr)
	emit_byte(0xca)
	emit_short(addr)
end

local function _jp_nz(addr)
	list_line("jp nz,$%04x", addr)
	emit_byte(0xc2)
	emit_short(addr)
end

local function _jp_c(addr)
	list_line("jp c,$%04x", addr)
	emit_byte(0xda)
	emit_short(addr)
end

local function _jp_nc(addr)
	list_line("jp nc,$%04x", addr)
	emit_byte(0xd2)
	emit_short(addr)
end

local function _jp_m(addr)
	list_line("jp m,$%04x", addr)
	emit_byte(0xfa)
	emit_short(addr)
end

local function _jp_p(addr)
	list_line("jp p,$%04x", addr)
	emit_byte(0xf2)
	emit_short(addr)
end

local function _jp_indirect(r)
	assert(r == HL or r == IX or r == IY, "_jp_indirect: unknown register")
	list_line("jp (%s)", reg_name[r])
	if r == HL then
		emit_byte(0xe9)	-- jp (hl)
	elseif r == IX then
		emit_byte(0xdd)	-- jp (ix)
		emit_byte(0xe9)
	elseif r == IY then
		emit_byte(0xfd)	-- jp (iy)
		emit_byte(0xe9)
	end
end

local function _di()
	list_line("di")
	emit_byte(0xf3)
end

local function _ei()
	list_line("ei")
	emit_byte(0xfb)
end

local function offset_to_absolute(offset)
	if offset > 127 then offset = offset - 256 end
	return here() + offset + 2
end

local function _jr(offset)
	list_line("jr $%04x", offset_to_absolute(offset))
	emit_byte(0x18)
	emit_byte(offset)
end

local function _jr_z(offset)
	list_line("jr z,$%04x", offset_to_absolute(offset))
	emit_byte(0x28)
	emit_byte(offset)
end

local function _jr_nz(offset)
	list_line("jr nz,$%04x", offset_to_absolute(offset))
	emit_byte(0x20)
	emit_byte(offset)
end

local function _jr_c(offset)
	list_line("jr c,$%04x", offset_to_absolute(offset))
	emit_byte(0x38)
	emit_byte(offset)
end

local function _jr_nc(offset)
	list_line("jr nc,$%04x", offset_to_absolute(offset))
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
	list_line("in %s,(%s)", reg_name[r], reg_name[port])
	emit_byte(0xed)
	emit_byte(0x40 + r * 8)
end

local function _in_const(r, port_addr)
	assert(r == A, "_in_const: invalid register")
	assert(port_addr >= 0 and port_addr <= 255, "_in_const: invalid port")
	list_line("in a,($%02x)", port_addr)
	emit_byte(0xdb)
	emit_byte(port_addr)
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
	list_line("out (%s),%s", reg_name[port], reg_name[r])
	emit_byte(0xed)
	emit_byte(0x41 + r * 8)
end

local function _out_const(port_addr, r)
	assert(r == A, "_out_const: invalid register")
	assert(port_addr >= 0 and port_addr <= 255, "_out_const: invalid port")
	list_line("out ($%02x),a", port_addr)
	emit_byte(0xd3)
	emit_byte(port_addr)
end

local function _rst(i)
	assert(i >= 0 and i <= 0x38 and (i & 7) == 0, "invalid reset vector")
	list_line("rst %s", i)
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

local function stk_push_de_inline()
	_ld_fetch(HL, SPARE)
	_ld(HL_INDIRECT, E)
	_inc(HL)
	_ld(HL_INDIRECT, D)
	_inc(HL)
	_ld_store(SPARE, HL)
end

local function stk_pop_de_inline()
	_ld_fetch(HL, SPARE)
	_dec(HL)
	_ld(D, HL_INDIRECT)
	_dec(HL)
	_ld(E, HL_INDIRECT)
	_ld_store(SPARE, HL)
end

local function stk_pop_bc_inline()
	_ld_fetch(HL, SPARE)
	_dec(HL)
	_ld(B, HL_INDIRECT)
	_dec(HL)
	_ld(C, HL_INDIRECT)
	_ld_store(SPARE, HL)
end

local function branch_offset(jump_to_addr, instr_addr)
	instr_addr = instr_addr or here()
	local offset = jump_to_addr - instr_addr - 2
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

-- Emits conditional jump which causes a jump to <target> if C flag is set.
local function jump_c(addr)
	local offset = branch_offset(addr)
	if offset then
		_jr_c(offset)
	else
		_jp_c(addr)
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

-- Patch already emitted jump instruction to jump to a new address.
-- Returns false if the jump could not be patched (branch too long).
local function patch_jump(instr_addr, jump_to_addr)
	local opcode = read_byte(instr_addr)
	if opcode < 0x80 then
		-- relative jump
		local offset = branch_offset(jump_to_addr, instr_addr)
		if offset == nil then return false end
		write_byte(instr_addr + 1, offset)
	else
		-- absolute jump
		write_short(instr_addr + 1, jump_to_addr)
	end
	list_patch(instr_addr, "%$%x+", string.format("$%04x", jump_to_addr))
	jump_targets[jump_to_addr] = true
	return true
end

local function record_long_jump(ppos)
	if not long_jumps[ppos] then
		verbose("Deoptimizing branch to jump (%s)", ppos)
		long_jumps[ppos] = true
		more_work = true
	end
end

local function z80_decode(code, i)
	local node = decode_tree
	assert(node)

	local immediate
	local offset

	while true do
		if type(node) == "string" then break end

		local byte = assert(code[i])
		i = i + 1

		if node.n or node.nn then
			if immediate == nil then
				immediate = byte
			else
				immediate = immediate | (byte << 8)
			end
			node = node.n or node.nn
		elseif node.o then
			offset = byte
			if offset > 127 then offset = offset - 256 end
			node = node.o
		else
			node = assert(node[byte])
		end
	end

	local instr = node

	if immediate then
		instr = instr:gsub("nn", string.format("$%04x", immediate))
		instr = instr:gsub("n", string.format("$%02x", immediate))
	end

	if offset then
		instr = instr:gsub("o", offset)
	end

	return instr, immediate, offset, i
end

-- Relocates machine code to start at new address.
-- 'code' is an array of bytes,
-- 'list' is listing lines for that code (using same indices as code!)
-- For example, list[3] contains the listing line for the instruction at code[3].
local function relocate_mcode(code, list, old_start_addr, new_start_addr)
	local rel_code = {}
	local rel_list = {}

	local abs_jumps = {
		[0xc3] = "jp nn",
		[0xda] = "jp c,nn",
		[0xfa] = "jp m,nn",
		[0xd2] = "jp nc,nn",
		[0xc2] = "jp nz,nn",
		[0xf2] = "jp p,nn",
		[0xea] = "jp pe,nn",
		[0xe2] = "jp po,nn",
		[0xca] = "jp z,nn",
	}

	local rel_jumps = {
		[0x18] = "jr o",
		[0x38] = "jr c,o",
		[0x30] = "jr nc,o",
		[0x20] = "jr nz,o",
		[0x28] = "jr z,o",
	}

	local i = 1
	while i <= #code do
		local s = i	 -- start of instruction
		local instr, immediate, offset, e = z80_decode(code, i)

		for j = 1, e - s do
			rel_code[i] = code[i]
			rel_list[i] = list[i]
			i = i + 1
		end

		local opcode = code[s]	-- only valid for instructions without prefix bytes!

		-- relocate absolute jumps
		if abs_jumps[opcode] then
			local jump_to_addr = immediate
			local new_addr = jump_to_addr - old_start_addr + new_start_addr

			rel_code[s + 1] = new_addr & 0xff
			rel_code[s + 2] = new_addr >> 8

			rel_list[s] = abs_jumps[opcode]:gsub("nn", string.format("$%04x", new_addr))
		end

		-- relocate relative jumps (listing file only)
		if rel_jumps[opcode] then
			local jump_to_addr = new_start_addr + s + offset + 1
			rel_list[s] = rel_jumps[opcode]:gsub("o", string.format("$%04x", jump_to_addr))
		end

		-- skip over embedded strings
		if opcode == 0xcd and immediate == compilation_addresses["__print"] then
			local len = code[i] | (code[i + 1] << 8)

			for j = 1, len + 2 do
				rel_code[i] = code[i]
				rel_list[i] = list[i]
				i = i + 1
			end
		end

		-- skip over embedded Forth
		-- NOTE: This is pretty limited. We don't support jumping inside Forth code, for example.
		-- This should be fine because the mcode compiler only generates calls to Forth words.
		if opcode == 0xcd and immediate == 0x04b9 then
			-- copy bytes until Forth code end marker 0x1a0e is encountered
			-- every forth call address is 16-bit so we do two bytes per loop
			while true do
				local forth_end = (code[i] | (code[i + 1] << 8)) == 0x1a0e

				rel_code[i] = code[i]
				rel_list[i] = list[i]
				i = i + 1

				rel_code[i] = code[i]
				rel_list[i] = list[i]
				i = i + 1

				if forth_end then break end
			end
		end
	end

	return rel_code, rel_list
end

local function call_forth(name)
	-- Calling Forth word from machine code
	local addr = rom_words[string.upper(name)]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	stk_push_de()
	list_comment("call forth")
	_call(0x04b9) -- call forth
	list_line(name)
	emit_short(addr)
	list_line("end-forth")
	emit_short(0x1a0e) -- end-forth
	stk_pop_de()
end

local function call_code(name)
	-- Calling word created using CODE from machine code
	local addr = compilation_addresses[name]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	list_comment(name)
	_call(addr) -- words created using CODE don't have wrappers
	mark_used(name)
end

local function call_mcode(name)
	-- Calling machine code word from another machine code word
	local addr = compilation_addresses[name]
	if addr == nil then
		comp_error("could not find compilation address of word %s", name)
	end
	list_comment(name)
	_call(addr)
	mark_used(name)
end

-- Emit a return instruction, or change the previous call to tail call when possible.
local function ret()
	if opts.tail_call and call_pos == here() then
		-- check that the call opcode is really there
		assert(read_byte(call_pos - 3) == 0xcd)
		-- change it to jp
		write_byte(call_pos - 3, 0xc3)
		list_patch(call_pos - 3, "call", "jp")
		list_comment_append(call_pos - 3, " (tail-call)")

		-- ret cannot be eliminated if there's a jump to the address where the ret instruction should be
		if jump_targets[here()] then
			_ret()
		end
	else
		_ret()
	end
end

-- Emits invisible subroutine words to be used by mcode words.
local function emit_subroutines()
	local function is_word_used(name)
		return not eliminate_words[name]
	end

	-- rot
	if is_word_used("__rot") then
		-- >r swap r> swap
		create_word(0, "__rot", F_INVISIBLE | F_NO_INLINE)
		_push(DE)
		stk_pop_de()
		_call(here() + 5) -- call swap
		stk_push_de()
		_pop(DE)
		-- fall through to swap...
	end

	-- swap
	if is_word_used("__swap") or is_word_used("__rot") then
		create_word(0, "__swap", F_INVISIBLE | F_NO_INLINE)
		_ld_fetch(HL, SPARE)	-- load second element from top of stack to BC
		_dec(HL)
		_ld(B, HL_INDIRECT)
		_dec(HL)
		_ld(C, HL_INDIRECT)
		_ld(HL_INDIRECT, E)		-- push old top
		_inc(HL)
		_ld(HL_INDIRECT, D)
		_inc(HL)
		_ld_store(SPARE, HL)
		_ld(D, B)				-- second element to DE
		_ld(E, C)
		_ret()
	end

	-- 2dup
	if is_word_used("__2dup") then
		-- over over
		create_word(0, "__2dup", F_INVISIBLE | F_NO_INLINE)
		_call(here() + 3) -- call over
		-- fall through to over...
	end

	-- over
	if is_word_used("__over") or is_word_used("__2dup") then
		create_word(0, "__over", F_INVISIBLE | F_NO_INLINE)
		_ld_fetch(HL, SPARE) -- push old top
		_ld(B, H)
		_ld(C, L)
		_ld(HL_INDIRECT, E)
		_inc(HL)
		_ld(HL_INDIRECT, D)
		_inc(HL)
		_ld_store(SPARE, HL)
		_dec(BC)  -- second element to DE
		_ld(A, BC_INDIRECT)
		_ld(D, A)
		_dec(BC)
		_ld(A, BC_INDIRECT)
		_ld(E, A)
		_ret()
	end

	-- 2over
	if is_word_used("__2over") then
		-- 4 pick 4 pick
		create_word(0, "__2over", F_INVISIBLE | F_NO_INLINE)
		stk_push_de()
		for i = 1, 2 do
			_ld_const(DE, 4)
			stk_push_de()
			_call(0x094d)
		end
		stk_pop_de()
		_ret()
	end

	-- roll
	if is_word_used("__roll") then
		create_word(0, "__roll", F_INVISIBLE | F_NO_INLINE)
		stk_push_de()
		_call(0x094d)
		_ex_de_hl()
		_ld_fetch(HL, STKBOT)
		_ld(H, D)
		_ld(L, E)
		_inc(HL)
		_inc(HL)
		_ldir()
		_ld_store(SPARE, DE)
		stk_pop_de()
		_ret()
	end

	-- add
	if is_word_used("__add") then
		create_word(0, "__add", F_INVISIBLE | F_NO_INLINE)
		stk_pop_bc_inline()
		_ex_de_hl()
		_add(HL, BC)
		_ex_de_hl()
		_ret()
	end

	-- sub
	if is_word_used("__sub") then
		create_word(0, "__sub", F_INVISIBLE | F_NO_INLINE)
		_ld(B, D)
		_ld(C, E)
		stk_pop_de_inline()
		_ex_de_hl()
		_or(A) -- clear carry
		_sbc(HL, BC)
		_ex_de_hl()
		_ret()
	end

	-- signed 16-bit * 16-bit multiplication routine
	if is_word_used("__mult16") then
		create_word(0, "__mult16", F_INVISIBLE | F_NO_INLINE)
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
	end

	-- unsigned 8-bit * 8-bit multiplication routine
	-- source: http://map.grauw.nl/sources/external/z80bits.html#1.1
	if is_word_used("__mult8") then
		create_word(0, "__mult8", F_INVISIBLE | F_NO_INLINE)
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

	-- gt
	if is_word_used("__gt") then
		create_word(0, "__gt", F_INVISIBLE | F_NO_INLINE)
		_ld_fetch(HL, SPARE)	-- load second value from top to BC
		_dec(HL)
		_ld(B, HL_INDIRECT)
		_dec(HL)
		_ld(C, HL_INDIRECT)
		_ld_store(SPARE, HL)
		_ex_de_hl() -- HL = top value
		-- sign: HL = value1, BC = value2
		_ld(A, H)
		_xor(B)
		_jp_m(here() + 5) --> skip
		_sbc(HL, BC)
		-- skip:
		_rl(H)
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		_ret()
	end

	-- lt
	if is_word_used("__lt") then
		create_word(0, "__lt", F_INVISIBLE | F_NO_INLINE)
		_ld_fetch(HL, SPARE)	-- load second value from top to BC
		_dec(HL)
		_ld(B, HL_INDIRECT)
		_dec(HL)
		_ld(C, HL_INDIRECT)
		_ld_store(SPARE, HL)
		_ld(H, B)
		_ld(L, C)
		-- sign: HL = value1, DE = value2
		_ld(A, H)
		_xor(D)
		_jp_m(here() + 5) --> skip
		_sbc(HL, DE)
		-- skip:
		_rl(H)
		_ld_const(A, 0)
		_ld(D, A)
		_rla()
		_ld(E, A)
		_ret()
	end

	-- min
	if is_word_used("__min") then
		create_word(0, "__min", F_INVISIBLE | F_NO_INLINE)
		stk_pop_bc_inline()
		_ld(H, D)
		_ld(L, E)
		_or(A) -- clear carry
		_sbc(HL, BC)
		_rl(H)
		_ret_c()
		_ld(D, B)
		_ld(E, C)
		_ret()
	end

	-- max
	if is_word_used("__max") then
		create_word(0, "__max", F_INVISIBLE | F_NO_INLINE)
		stk_pop_bc_inline()
		_ld(H, D)
		_ld(L, E)
		_or(A) -- clear carry
		_sbc(HL, BC)
		_rl(H)
		_ret_nc()
		_ld(D, B)
		_ld(E, C)
		_ret()
	end

	-- at
	if is_word_used("__at") then
		create_word(0, "__at", F_INVISIBLE | F_NO_INLINE)
		_ld_fetch(HL, SPARE)
		_dec(HL)
		_dec(HL)
		_ld(A, HL_INDIRECT)
		_ld_store(SPARE, HL)
		_call(0x0b28)	-- at routine in ROM, in: A = y, E = x
		_ld_store(SCRPOS, HL)
		stk_pop_de()
		_ret()
	end

	-- print
	if is_word_used("__print") then
		create_word(0, "__print", F_INVISIBLE | F_NO_INLINE)
		_pop(HL)	-- HL = pointer to string data
		_push(DE) -- preserve DE
		_ex_de_hl()	-- DE = string data
		_call(0x0979) -- call print embedded string routine
		_ex_de_hl()	-- now HL points to end of string
		_pop(DE) -- restore DE
		_jp_indirect(HL)
	end

	-- spaces
	if is_word_used("__spaces") then
		create_word(0, "__spaces", F_INVISIBLE | F_NO_INLINE)
		-- loop:
		_dec(DE)
		_bit(7, D)
		_jr_nz(5) --> done
		_ld_const(A, 0x20)
		_rst(8)
		_jr(0xf6) --> loop
		-- done:
		stk_pop_de()
		_ret()
	end

	-- type
	if is_word_used("__type") then
		create_word(0, "__type", F_INVISIBLE | F_NO_INLINE)
		_ld(B, D)	-- move count from DE to BC
		_ld(C, E)
		stk_pop_de()
		_call(0x097f) -- call print string routine (BC = count, DE = addr)
		stk_pop_de()
		_ret()
	end
end

local function emit_literal(n, comment)
	if comment then
		list_comment(comment)
	else
		list_comment("lit %d", n)
	end

	stk_push_de()
	_ld_const(DE, n)

	literal_pos2 = literal_pos
	literal_pos = here()
end

-- Returns the literal that was just emitted, erasing the code that emitted it.
local function erase_literal()
	if literal_pos == here() then
		local value = read_short(literal_pos - 2)
		list_erase(here() - 4, here() - 1)
		erase(4)
		literal_pos = literal_pos2
		literal_pos2 = nil
		return value
	end
end

local function is_pow2(x)
	return x > 0 and (x & (x - 1)) == 0
end

local dict = {
	[';'] = function()
		-- patch gotos
		-- this must be done before ret() because a goto may target the address of the ret instruction
		for patch_loc, label in pairs(gotos) do
			local jump_to_addr = labels[label]
			if jump_to_addr == nil then comp_error("undefined label '%s'", label) end
			patch_jump(patch_loc, jump_to_addr)
		end

		ret()

		interpreter_state()
		check_control_flow_stack()

		-- inlining
		local name = last_word_name()
		if inline_words[name] then
			local code, list, comments, old_start_addr = erase_previous_word()

			-- when the inlined word is compiled, we emit its code
			mcode_dict[name] = function()
				list_comment("inlined %s", name)

				local code, list = relocate_mcode(code, list, old_start_addr, here())

				for i = 1, #code - 1 do	-- skip ret at the end
					if list[i] then list_line("%s", list[i]) end
					if comments[i] and i > 1 then list_comment("%s", comments[i]) end
					emit_byte(code[i])
				end
			end
		end

		labels = {}
		gotos = {}
		jump_targets = {}

		call_pos = nil
		literal_pos = nil
		literal_pos2 = nil
	end,
	dup = function()
		list_comment("dup")
		stk_push_de()
	end,
	['?dup'] = function()
		list_comment("?dup")
		_ld(A, D)
		_or(E)
		_jr_z(1) --> skip
		stk_push_de()
		-- skip:
	end,
	over = function()
		call_mcode("__over")
	end,
	drop = function()
		list_comment("drop")
		stk_pop_de()
	end,
	nip = function()
		-- swap drop
		list_comment("nip")
		stk_pop_bc()
	end,
	swap = function()
		call_mcode("__swap")
	end,
	['2dup'] = function()
		call_mcode("__2dup")
	end,
	['2drop'] = function()
		list_comment("2drop")
		stk_pop_de()
		stk_pop_de()
	end,
	['2over'] = function()
		call_mcode("__2over")
	end,
	pick = function()
		list_comment("pick")
		stk_push_de()
		_call(0x094d)
		stk_pop_de()
	end,
	roll = function()
		call_mcode("__roll")
	end,
	rot = function()
		call_mcode("__rot")
	end,
	['r>'] = function()
		list_comment("r>")
		stk_push_de()
		_pop(DE)
	end,
	['>r'] = function()
		list_comment(">r")
		_push(DE)
		stk_pop_de()
	end,
	['r@'] = function()
		list_comment("r@")
		stk_push_de()
		_pop(DE)
		_push(DE)
	end,
    ['+'] = function()
		local lit = erase_literal()
		if lit == 0 then
			-- nothing to do
		elseif lit and lit > 0 and lit <= 4 then
			-- lit*6 cycles, lit*1 bytes
			list_comment("%d + ", lit)
			for i = 1, lit do
				_inc(DE)
			end
		elseif lit and (lit & 0xff) == 0 then
			list_comment("$%04x + ", lit)
			_ld(A, D)
			_add_const((lit & 0xff00) >> 8)
			_ld(D, A)
		elseif lit then
			-- 28 cycles, 7 bytes
			list_comment("%d + ", lit)
			_ex_de_hl()
			_ld_const(DE, lit)
			_add(HL, DE)
			_ex_de_hl()
		else
			call_mcode("__add")
		end
	end,
	['-'] = function()
		local lit = erase_literal()
		if lit == 0 then
			-- nothing to do
		elseif lit and lit > 0 and lit <= 4 then
			-- lit*6 cycles, lit*1 bytes
			list_comment("%d - ", lit)
			for i = 1, lit do
				_dec(DE)
			end
		elseif lit and (lit & 0xff) == 0 then
			list_comment("$%04x - ", lit)
			_ld(A, D)
			_sub_const((lit & 0xff00) >> 8)
			_ld(D, A)
		elseif lit then
			list_comment("%d - ", lit)
			_ex_de_hl()
			_ld_const(DE, -lit)
			_add(HL, DE)
			_ex_de_hl()
		else
			call_mcode("__sub")
		end
	end,
	['*'] = function()
		local lit = erase_literal()
		if lit == 0 then
			list_comment("0 *")
			_ld_const(DE, 0)
		elseif lit == 1 then
			-- nothing to do
		elseif lit and is_pow2(lit) and lit <= 32767 then
			list_comment("%d *", lit)
			if lit < 256 then
				while lit > 1 do
					_sla(E)
					_rl(D)
					lit = lit // 2
				end
			else
				_ld(D, E)
				_ld_const(E, 0)
				lit = lit // 256
				while lit > 1 do
					_sla(D)
					lit = lit // 2
				end
			end
		elseif lit then
			emit_literal(lit)
			call_mcode("__mult16")
		else
			call_mcode("__mult16")
		end
	end,
	['c*'] = function()
		local lit = erase_literal()
		if lit and (lit == 0 or lit >= 256) then
			list_comment("%d c*", lit)
			_ld_const(DE, 0)
		elseif lit == 1 then
			-- nothing to do
		elseif lit and is_pow2(lit) then
			list_comment("%d c*", lit)
			while lit > 1 do
				_sla(E)
				lit = lit // 2
			end
		elseif lit then
			emit_literal(lit)
			call_mcode("__mult8")
		else
			call_mcode("__mult8")
		end
	end,
	['/'] = function()
		local lit = erase_literal()
		if lit == 1 then
			-- nothing to do
		elseif lit and is_pow2(lit) and lit <= 32767 then
			list_comment("%d /", lit)
			if lit < 256 then
				while lit > 1 do
					_sra(D)
					_rr(E)
					lit = lit // 2
				end
			else
				_ld(E, D)
				_ld_const(D, 0)
				_bit(7, E)
				_jr_z(1)
				_dec(D)
				lit = lit // 256
				while lit > 1 do
					_sra(E)
					lit = lit // 2
				end
			end
		elseif lit then
			emit_literal(lit)
			call_forth("/")
		else
			call_forth("/")
		end
	end,
	['1+'] = function()
		list_comment("1+")
		_inc(DE)
	end,
	['1-'] = function()
		list_comment("1-")
		_dec(DE)
	end,
	['2+'] = function()
		list_comment("2+")
		_inc(DE)
		_inc(DE)
	end,
	['2-'] = function()
		list_comment("2-")
		_dec(DE)
		_dec(DE)
	end,
	['2*'] = function()
		list_comment("2*")
		_sla(E)
		_rl(D)
	end,
	['2/'] = function()
		list_comment("2/")
		_sra(D)
		_rr(E)
	end,
	negate = function()
		list_comment("negate")
		_xor(A)
		_sub(E)
		_ld(E, A)
		_sbc(A, A)
		_sub(D)
		_ld(D, A)
	end,
	abs = function()
		list_comment("abs")
		_bit(7, D)
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
		call_mcode("__min")
	end,
	max = function()
		call_mcode("__max")
	end,
	xor = function()
		local lit = erase_literal()
		if lit then
			if lit ~= 0 then list_comment("%d xor", lit) end

			if (lit & 0xff) ~= 0 then
				_ld(A, E)
				_xor_const(lit & 0xff)
				_ld(E, A)
			end

			if (lit & 0xff00) ~= 0 then
				_ld(A, D)
				_xor_const((lit & 0xff00) >> 8)
				_ld(D, A)
			end
		else
			list_comment("xor")
			stk_pop_bc()
			_ld(A, E)
			_xor(C)
			_ld(E, A)
			_ld(A, D)
			_xor(B)
			_ld(D, A)
		end
	end,
	['and'] = function()
		local lit = erase_literal()
		if lit then
			local lo = lit & 0xff
			local hi = (lit & 0xff00) >> 8

			if lo ~= 0xff or hi ~= 0xff then list_comment("%d and", lit) end

			if lo == 0 then
				_ld_const(E, 0)
			elseif lo ~= 0xff then
				_ld(A, E)
				_and_const(lo)
				_ld(E, A)
			end

			if hi == 0 then
				_ld_const(D, 0)
			elseif hi ~= 0xff then
				_ld(A, D)
				_and_const(hi)
				_ld(D, A)
			end
		else
			list_comment("and")
			stk_pop_bc()
			_ld(A, E)
			_and(C)
			_ld(E, A)
			_ld(A, D)
			_and(B)
			_ld(D, A)
		end
	end,
	['or'] = function()
		local lit = erase_literal()
		if lit then
			local lo = lit & 0xff
			local hi = (lit & 0xff00) >> 8

			if lo ~= 0 or hi ~= 0 then list_comment("%d or", lit) end

			if lo == 0xff then
				_ld_const(E, 0xff)
			elseif lo ~= 0 then
				_ld(A, E)
				_or_const(lo)
				_ld(E, A)
			end

			if hi == 0xff then
				_ld_const(D, 0xff)
			elseif hi ~= 0 then
				_ld(A, D)
				_or_const(hi)
				_ld(D, A)
			end
		else
			list_comment("or")
			stk_pop_bc()
			_ld(A, E)
			_or(C)
			_ld(E, A)
			_ld(A, D)
			_or(B)
			_ld(D, A)
		end
	end,
	['not'] = function()
		list_comment("not")
		_ld(A, D)
		_or(E)
		_ld_const(DE, 1)
		_jr_z(1) --> skip
		_ld(E, D) -- clear e
		-- skip:
	end,
	['0='] = function()
		list_comment("0=")
		_ld(A, D)
		_or(E)
		_ld_const(DE, 1)
		_jr_z(1) --> skip
		_ld(E, D) -- clear e
		-- skip:
	end,
	['0<'] = function()
		list_comment("0<")
		_xor(A)
		_rl(D)
		_ld(D, A)
		_rla()
		_ld(E, A)
	end,
	['0>'] = function()
		list_comment("0>")
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
	end,
	['='] = function()
		local lit = erase_literal()
		if lit then
			list_comment("%d =", lit)
			_ex_de_hl()
			_ld_const(BC, -lit)
			_or(A) -- clear carry
			_adc(HL, BC)	-- ADD HL, BC can't be used here because it does not update Z flag!
			_ld_const(DE, 0)
			_jr_nz(1) --> skip
			_inc(E)
			-- skip:
		else
			list_comment("=")
			stk_pop_bc()
			_ex_de_hl()
			_or(A) -- clear carry
			_sbc(HL, BC)
			_ld_const(DE, 0)
			_jr_nz(1) --> skip
			_inc(E)
			-- skip:
		end
	end,
	['c='] = function()
		local lit = erase_literal()
		if lit then
			comp_assert(lit >= 0 and lit <= 255, "Literal outside range for C=")
			list_comment("%d c=", lit)
			_ld(A, E)
			_cp_const(lit)
			_ld_const(DE, 0)
			_jr_nz(1) --> skip
			_inc(E)
			-- skip:
		else
			list_comment("c=")
			_ld(A, E)
			stk_pop_de() -- preserves A
			_sub(E)
			_ld_const(DE, 0)
			_jr_nz(1) --> skip
			_inc(E)
			-- skip:
		end
	end,
	['>'] = function()
		call_mcode("__gt")
	end,
	['c>'] = function()
		local lit = erase_literal()
		if lit then lit = lit & 0xff end

		if lit and lit == 255 then
			list_comment("255 c>")
			_ld_const(DE, 0)
		elseif lit then
			list_comment("%d c>", lit)
			_ld(A, E)
			_ld_const(DE, 0)
			_cp_const(lit + 1)
			_jr_c(1)
			_inc(E)
		else
			list_comment("c>")
			_ld(A, E)
			stk_pop_de() -- preserves A
			_sub(E)
			_ld_const(DE, 0)
			_jr_nc(1) --> skip
			_inc(E)
			-- skip:
		end
	end,
	['<'] = function()
		call_mcode("__lt")
	end,
	['c<'] = function()
		local lit = erase_literal()
		if lit then lit = lit & 0xff end

		if lit and lit == 0 then
			list_comment("0 c<")
			_ld_const(DE, 0)
		elseif lit then
			list_comment("%d c<", lit)
			_ld(A, E)
			_ld_const(DE, 0)
			_cp_const(lit)
			_jr_nc(1)
			_inc(E)
		else
			list_comment("c<")
			_ld(A, E)
			stk_pop_de() -- preserves A
			_scf()
			_sbc(A, E)
			_ld_const(DE, 0)
			_jr_c(1) --> skip
			_inc(E)
			-- skip:
		end
	end,
	['!'] = function()
		-- ( n addr -- )
		local addr = erase_literal()
		if addr then
			list_comment("%04x !", addr)
			_ld_store(addr, DE)
			stk_pop_de()
		else
			list_comment("!")
			stk_pop_bc()
			_ex_de_hl()
			_ld(HL_INDIRECT, C)
			_inc(HL)
			_ld(HL_INDIRECT, B)
			stk_pop_de()
		end
	end,
	['@'] = function()
		-- ( addr -- n )
		local addr = erase_literal()
		if addr then
			list_comment("%04x @", addr)
			stk_push_de()
			_ld_fetch(DE, addr)
		else
			list_comment("@")
			_ex_de_hl()
			_ld(E, HL_INDIRECT)
			_inc(HL)
			_ld(D, HL_INDIRECT)
		end
	end,
	['c!'] = function()
		-- ( n addr -- )
		local addr = erase_literal()
		if addr then
			list_comment("%04x c!", addr)
			_ld(A, E)
			_ld_store(addr, A)
			stk_pop_de()
		else
			list_comment("c!")
			stk_pop_bc()
			_ld(A, C)
			_ld(DE_INDIRECT, A)
			stk_pop_de()
		end
	end,
	['c@'] = function()
		-- ( addr - n )
		local addr = erase_literal()
		if addr then
			list_comment("%04x c@", addr)
			stk_push_de()
			_ld_fetch(A, addr)
			_ld(E, A)
			_ld_const(D, 0)
		else
			list_comment("c@")
			_ld(A, DE_INDIRECT)
			_ld(E, A)
			_ld_const(D, 0)
		end
	end,
	inc = function()
		-- ( addr - )
		local addr = erase_literal()
		if addr then
			list_comment("%04x inc", addr)
			_ld_const(HL, addr)
			_inc(HL_INDIRECT)
		else
			list_comment("inc")
			_ex_de_hl()
			_inc(HL_INDIRECT)
			stk_pop_de()
		end
	end,
	dec = function()
		-- ( addr - )
		local addr = erase_literal()
		if addr then
			list_comment("%04x dec", addr)
			_ld_const(HL, addr)
			_dec(HL_INDIRECT)
		else
			list_comment("dec")
			_ex_de_hl()
			_dec(HL_INDIRECT)
			stk_pop_de()
		end
	end,
	ascii = function()
		(compile_dict.ascii or compile_dict.ASCII)()
	end,
	['[hex]'] = function()
		(compile_dict['[hex]'] or compile_dict['[HEX]'])()
	end,
	emit = function()
		list_comment("emit")
		_ld(A, E)
		_rst(8)
		stk_pop_de()
	end,
	cr = function()
		list_comment("cr")
		_ld_const(A, 0x0d)
		_rst(8)
	end,
	space = function()
		list_comment("space")
		_ld_const(A, 0x20)
		_rst(8)
	end,
	spaces = function()
		call_mcode("__spaces")
	end,
	at = function()
		call_mcode("__at")
	end,
	type = function()
		-- ( addr count -- )
		call_mcode("__type")
	end,
	base = function()
		list_comment("base")
		stk_push_de()
		_ld_const(DE, 0x3c3f)
	end,
	hex = function()
		list_comment("hex")
		_ld_store_offset_const(IX, 0x3f, 0x10)
	end,
	decimal = function()
		list_comment("decimal")
		_ld_store_offset_const(IX, 0x3f, 0x0a)
	end,
	out = function()
		-- ( n port -- )
		local port = erase_literal()
		if port then
			list_comment("$%04x out", port)
			_ld(A, E)
			_out_const(port & 0xff, A)
			stk_pop_de()
		else
			list_comment("out")	-- C = port
			_ld(C, E)
			stk_pop_de()	-- E = value to output (stk_pop_de does not trash C)
			_out(C, E)
			stk_pop_de()
		end
	end,
	['in'] = function()
		-- ( port -- n )
		local port = erase_literal()
		if port then
			list_comment("$%04x in", port)
			stk_push_de()
			--_ld_const(A, port >> 8) -- place hi byte to address bus when reading keyboard (untested)
			_in_const(A, port & 0xff)
			_ld(E, A)
			_ld_const(D, 0)
		else
			list_comment("in")	-- C = port
			_ld(C, E)
			_ld_const(D, 0)
			_in(E, C)
		end
	end,
	inkey = function()
		-- ( -- n )
		list_comment("inkey")
		stk_push_de()
		_call(0x0336) -- call keyscan routine
		_ld(E, A)
		_ld_const(D, 0)
	end,
	['if'] = function()
		list_comment("if")
		_ld(A, D)
		_or(E)
		stk_pop_de()
		local ppos = parse_pos()
		cf_push(ppos)
		cf_push(here())
		cf_push('if')
		-- emit conditional branch with placeholder jump to address
		-- use relative branch unless short jump is blacklisted (see ELSE)
		if opts.short_branches and not long_jumps[ppos] then
			_jr_z(0)
		else
			_jp_z(0)
		end
	end,
	['else'] = function()
		comp_assert(cf_pop() == 'if', "ELSE without matching IF")
		local where = cf_pop()
		local if_ppos = cf_pop()
		local ppos = parse_pos()
		cf_push(ppos)
		cf_push(here())
		cf_push('if')
		-- emit unconditional branch to jump to THEN with placeholder jump to address
		-- use relative branch unless short jump is blacklisted
		list_comment("else")
		if opts.short_branches and not long_jumps[ppos] then
			_jr(0)
		else
			_jp(0)
		end
		-- patch jump target at previous IF
		if not patch_jump(where, here()) then
			-- branch too long, blacklist it
			assert(opts.short_branches)
			record_long_jump(if_ppos)
		end
	end,
	['then'] = function()
		comp_assert(cf_pop() == 'if', "THEN without matching IF")
		local where = cf_pop()
		local ppos = cf_pop()
		-- patch jump target at previous IF or ELSE
		if not patch_jump(where, here()) then
			-- branch too long, blacklist it
			assert(opts.short_branches)
			record_long_jump(ppos)
		end
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
			list_comment("goto %s", label)
			jump(labels[label])
		else
			-- label not found -> this is a forward jump
			-- emit placeholder jump and resolve jump address in ;
			gotos[here()] = label
			list_comment("goto %s", label)
			_jp(0)
		end
	end,
	begin = function()
		cf_push(here())
		cf_push('begin')
	end,
	again = function()
		comp_assert(cf_pop() == 'begin', "AGAIN without matching BEGIN")
		local target = cf_pop()
		list_comment("again")
		jump(target)
	end,
	['until'] = function()
		comp_assert(cf_pop() == 'begin', "UNTIL without matching BEGIN")
		local target = cf_pop()
		list_comment("until")
		_ld(A, D)
		_or(E)
		_ex_af_af()	-- store Z flag
		stk_pop_de()
		_ex_af_af()	-- restore Z flag
		jump_z(target)
	end,
	['do'] = function()
		-- ( limit counter -- )

		-- record limit and counter if they are literals
		local limit = false
		local counter = false
		if literal_pos == here() and literal_pos2 == here() - 4 then
			limit = read_short(literal_pos2 - 2)
			counter = read_short(literal_pos - 2)
		end

		if limit and counter then
			assert(erase_literal() == counter)
			assert(erase_literal() == limit)
			list_comment("%d %d do", limit, counter)
			_ld_const(BC, limit)
			_push(BC) -- push limit to return stack
			_ld_const(BC, counter)
			_push(BC) -- push counter to return stack
		elseif counter then
			assert(erase_literal() == counter)
			list_comment("%d do", counter) -- push limit to return stack
			_push(DE)
			_ld_const(DE, counter)
			_push(DE) -- push counter to return stack
			stk_pop_de()
		else
			list_comment("do") -- pop limit
			stk_pop_bc(); 
			_push(BC) -- push limit to return stack
			_push(DE) -- push counter to return stack
			stk_pop_de()
		end

		cf_push(counter)
		cf_push(limit)
		cf_push(here())
		cf_push('do')
	end,
	loop = function()
		comp_assert(cf_pop() == 'do', "LOOP without matching DO")
		local target = cf_pop()
		local limit = cf_pop()
		local counter = cf_pop()

		if limit and counter and limit >= 0 and limit <= 255 and counter >= 0 and counter <= 255 then
			-- specialization for unsigned 8-bit loop with known limit
			list_comment("loop (8-bit)") -- pop counter
			_pop(BC)
			_inc(C)
			_push(BC) -- push counter
			_ld(A, C)
			_cp_const(limit)
			jump_c(target)
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		elseif limit then
			-- specialization for 16-bit loop with known limit
			list_comment("loop (16-bit)") -- pop counter
			_pop(BC)
			_inc(BC)
			_push(BC) -- push counter
			_scf() -- set carry
			_ld_const(HL, limit)
			_sbc(HL, BC) -- HL = limit - counter
			_jp_p(target)
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		else
			-- limit unknown
			list_comment("loop (generic)") -- pop counter
			_pop(BC)
			_pop(HL) -- pop limit
			_push(HL) -- push limit
			_inc(BC)
			_push(BC) -- push counter
			_scf() -- set carry
			_sbc(HL, BC) -- HL = limit - counter
			_jp_p(target)
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		end
	end,
	['+loop'] = function()
		comp_assert(cf_pop() == 'do', "+LOOP without matching DO")
		local target = cf_pop()
		local limit = cf_pop()
		local counter = cf_pop()

		local step = erase_literal()

		if step and step >= 0 and step < 32768 then
			-- specialization for counting up
			list_comment("%d +loop (count up)", step) -- pop counter
			_pop(HL)
			_ld_const(BC, step)
			_add(HL, BC) -- HL = counter + step
			_pop(BC) -- pop limit
			_push(BC) -- push limit
			_push(HL) -- push counter
			_or(A)
			_sbc(HL, BC) -- HL = counter - limit
			_jp_m(target)	-- loop back
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		elseif step and step >= 32768 then
			-- specialization for counting down
			step = step - 65536
			list_comment("%d +loop (count down)", step) -- pop counter
			_pop(HL)
			_ld_const(BC, step)
			_add(HL, BC) -- HL = counter + step
			_pop(BC) -- pop limit
			_push(BC) -- push limit
			_push(HL) -- push counter
			_scf()
			_sbc(HL, BC) -- HL = counter - limit
			_jp_p(target) -- there is no jr m,<addr> instruction on Z80!
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		else
			-- counting direction unknown!
			warn("+LOOP with non-literal step produces bad code!")
			-- lots of code but this should be very rare
			list_comment("+loop") -- pop counter
			_pop(HL)
			_add(HL, DE) -- increment loop counter
			_ld(B, D) -- B contains sign of step
			_ex_de_hl() -- DE = new counter value
			_pop(HL) -- pop limit
			_push(HL) -- push limit
			_push(DE) -- push counter
			-- counting up or down?
			_bit(7, B)
			_jr_nz(9) --> jump to 'down' if step is negative
			-- counting up
			_scf()
			_sbc(HL, DE) -- HL = limit - counter
			stk_pop_de() -- does not trash flags or BC
			_jp_p(target)
			_jr(7) --> continue
			-- counting down
			_or(A)	-- clear carry
			_sbc(HL, DE) -- HL = limit - counter
			stk_pop_de() -- does not trash flags or BC
			_jp_m(target) -- there is no jr m,<addr> instruction on Z80!
			-- continue:
			_pop(BC) -- end of loop -> pop limit & counter from stack
			_pop(BC)
		end
	end,
	['repeat'] = function()
		comp_error("mcode word REPEAT not yet implemented")
	end,
	['while'] = function()
		comp_error("mcode word WHILE not yet implemented")
	end,
	i = function()
		list_comment("i")
		stk_push_de()
		_pop(DE)
		_push(DE)
	end,
	['i\''] = function()
		list_comment("i'")
		stk_push_de()
		_pop(BC)
		_pop(DE)
		_push(DE)
		_push(BC)
	end,
	j = function()
		list_comment("j")
		stk_push_de()
		_ld_const(HL, 4)
		_add(HL, SP)
		_ld(E, HL_INDIRECT)
		_inc(HL)
		_ld(D, HL_INDIRECT)
	end,
	leave = function()
		list_comment("leave") -- pop counter
		_pop(HL)
		_pop(HL) -- pop limit
		_push(HL) -- push limit
		_push(HL) -- push limit as new counter
	end,
	exit = function()
		list_comment("exit")
		ret()
	end,
	['['] = function()
		compile_dict['[']()
	end,
	lit = function()
		(compile_dict.lit or compile_dict.LIT)()
	end,
	['."'] = function()
		local str = next_symbol_with_delimiter('"')
		call_mcode("__print")
		list_comment('"%s"', str)
		emit_short(#str)
		emit_string(str)
	end,
	di = function()
		list_comment("di")
		_di()
	end,
	ei = function()
		list_comment("ei")
		_ei()
	end,
	here = function()
		list_comment("here")
		stk_push_de()
		_ld_fetch(DE, STKBOT)
	end,
}

-- The following words do not have fast machine code implementation
local interpreted_words = {
	"ufloat", "int", "fnegate", "f/", "f*", "f+", "f-", "f.",
	"d+", "dnegate", "u/mod", "*/", "mod", "*/mod", "/mod", "u*", "d<", "u<",
	"#", "#s", "u.", ".", "#>", "<#", "sign", "hold",
	"cls", "slow", "fast", "invis", "vis", "abort", "quit",
	"line", "word", "number", "convert", "retype", "query",
	"plot", "beep", "execute", "call"
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
	emit_literal = emit_literal,
	call_forth = call_forth,
	call_code = call_code,
	call_mcode = call_mcode,
}