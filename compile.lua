#!tools/lua

-- Ace Forth cross compiler
--
-- Each user defined word has the following structure:
-- Name				array of bytes, the last character has high bit set which marks the end of string
-- Word length		short, the length of the word in bytes excluding the name
-- Link				pointer to name length field of previous defined word
-- Name length		byte, length of name in bytes
-- Code field		machine code address, called when the word is executed (for example, DO_COLON or DO_PARAM)
-- Parameter field	optional area for storing word specific data (compiled forth code for DO_COLON words)
--
-- The first user defined word is placed at 3C51 in RAM.
-- The function create_word() below adds a new word header to the output dictionary.

local asm_vocabulary = require "asm"

local DO_COLON		= 0x0EC3 -- DoColon routine in ROM, the value of code field for user defined words
local DO_PARAM		= 0x0FF0 -- Routine which pushes the parameter field to stack, code field value for variables
local DO_CONSTANT	= 0x0FF5 -- Routine which pushes short from parameter field to stack, code field value for constants
local FORTH_END		= 0x04B6 -- Internal word, returns from current word
local PUSH_BYTE		= 0x104B -- Internal word, pushes the following literal byte to stack
local PUSH_WORD 	= 0x1011 -- Internal word, pushes the following literal word to stack
local PUSH_ZERO 	= 0x0688 -- Internal word, push zero stack
local CBRANCH		= 0x1283 -- Internal word, conditional branch '?branch', the following word is the branch offset
local BRANCH		= 0x1276 -- Internal word, unconditional branch 'branch', the following word is the branch offset
local PRINT			= 0x1396 -- Internal word, prints a string, string length word + data follows
local DO 			= 0x1323 -- Internal word, runtime part of DO (pushes 2 values from data stack to return stack)
local LOOP			= 0x1332 -- Internal word, runtime part of LOOP, the following word is the branch offset
local PLUS_LOOP		= 0x133C -- Internal word, runtime part of +LOOP, the following word is the branch offset

local start_address = 0x3c51
local v_current = 0x3C4C
local v_context = 0x3C4C
local v_voclink = 0x3C4F

-- parse args
local args = {...}

local input_files = {}
local output_file
local opts = { main_word = "MAIN" }

do
	local i = 1
	while i <= #args do
		local arg = args[i]
		if string.match(arg, "^%-") then
			if arg == "--no-headers" then
				opts.no_headers = true
			elseif string.match(arg, "^%-%-main=") then
				opts.main_word = string.upper(string.match(arg, "^%-%-main=(.*)"))
			elseif arg == "-o" then
				output_file = args[i + 1]
				i = i + 1
				if output_file == nil then
					print("No output file!")
					os.exit(-1)
				end
			else
				print("Invalid option: " .. arg)
				os.exit(-1)
			end
		else
			input_files[#input_files + 1] = arg
		end
		i = i + 1
	end
end

if #input_files == 0 then
	print("Usage: compile.lua [options] <inputfile1> <inputfile2> ...")
	print("\nOptions:")
	print("  -o <filename>   Sets output filename")
	print("  --no-headers    Eliminate word headers, except for main word")
	print("  --main=<name>   Sets name of main executable word (default 'MAIN')")
	os.exit(-1)
end

local input								-- source code as string
local input_file						-- current input filename
local cur_pos							-- current position in input
local cur_line							-- current line in input
local compile_mode = false				-- interpret or compile mode?
local inside_colon_definition = false	-- are we between : and ; ?
local compile_bytes = false				-- are we between BYTES and ; ?
local stack = {}						-- the compiler stack
local mem = { [0] = 10 }				-- compiler memory
local output_pos = start_address		-- current output position in the dictionary
local next_immediate_word = 1			-- next free address for compiled immediate words
local labels = {}						-- label -> address for current word
local gotos = {}						-- address to be patched -> label for current word
local last_word							-- name of last user defined word

-- address of prev word's name length field in RAM
-- initial value: address of FORTH in RAM
local prev_word_link = 0x3C49

local rom_words = {
	FORTH = 0x3c4a, UFLOAT = 0x1d59, INT = 0x1d22, FNEGATE = 0x1d0f, ["F/"] = 0x1c7b, ["F*"] = 0x1c4b,
	["F+"] = 0x1bb1, ["F-"] = 0x1ba4, LOAD = 0x198a, BVERIFY = 0x1979, VERIFY = 0x1967, BLOAD = 0x1954,
	BSAVE = 0x1944, SAVE = 0x1934, LIST = 0x1670, EDIT = 0x165e, FORGET = 0x1638, REDEFINE = 0x13fd,
	EXIT = 0x13f0, [".\""] = 0x1388, ["("] = 0x1361, ["["] = 0x13d5, ["+LOOP"] = 0x12d0, LOOP = 0x12bd,
	DO = 0x12ab, UNTIL = 0x1263, REPEAT = 0x124c, BEGIN = 0x121a, THEN = 0x1207, ELSE = 0x11ec,
	WHILE = 0x11d5, IF = 0x11c0, ["]"] = 0x13e1, LEAVE = 0x1316, J = 0x1302, ["I'"] = 0x12f7, I = 0x12e9,
	DEFINITIONS = 0x11ab, VOCABULARY = 0x117d, IMMEDIATE = 0x1160, ["RUNS>"] = 0x1125, ["DOES>"] = 0x10b4,
	COMPILER = 0x10f5, CALL = 0x10a7, DEFINER = 0x1074, ASCII = 0x1028, LITERAL = 0x1006, CONSTANT = 0x0fe2,
	VARIABLE = 0x0fcf, ALLOT = 0x0f76, ["C,"] = 0x0f5f, [","] = 0x0f4e, CREATE = 0x0ed0, [":"] = 0x0eaf,
	DECIMAL = 0x0ea3, MIN = 0x0e87, MAX = 0x0e75, XOR = 0x0e60, AND = 0x0e4b, OR = 0x0e36, ["2-"] = 0x0e29,
	["1-"] = 0x0e1f, ["2+"] = 0x0e13, ["1+"] = 0x0e09, ["D+"] = 0x0dee, ["-"] = 0x0de1, ["+"] = 0x0dd2,
	DNEGATE = 0x0dba, NEGATE = 0x0da9, ["U/MOD"] = 0x0d8c, ["*/"] = 0x0d7a, ["*"] = 0x0d6d, MOD = 0x0d61,
	["/"] = 0x0d51, ["*/MOD"] = 0x0d31, ["/MOD"] = 0x0d00, ["U*"] = 0x0ca8, ["D<"] = 0x0c83, ["U<"] = 0x0c72,
	["<"] = 0x0c65, [">"] = 0x0c56, ["="] = 0x0c4a, ["0>"] = 0x0c3a, ["0<"] = 0x0c2e, ["0="] = 0x0c1a,
	ABS = 0x0c0d, OUT = 0x0bfd, IN = 0x0beb, INKEY = 0x0bdb, BEEP = 0x0b98, PLOT = 0x0b4a, AT = 0x0b19,
	["F."] = 0x0aaf, EMIT = 0x0aa3, CR = 0x0a95, SPACES = 0x0a83, SPACE = 0x0a73, HOLD = 0x0a5c, CLS = 0x0a1d,
	["#"] = 0x09f7, ["#S"] = 0x09e1, ["U."] = 0x09d0, ["."] = 0x09b3, SIGN = 0x0a4a, ["#>"] = 0x099c,
	["<#"] = 0x098d, TYPE = 0x096e, ROLL = 0x0933, PICK = 0x0925, OVER = 0x0912, ROT = 0x08ff, ["?DUP"] = 0x08ee,
	["R>"] = 0x08df, [">R"] = 0x08d2, ["!"] = 0x08c1, ["@"] = 0x08b3, ["C!"] = 0x08a5, ["C@"] = 0x0896,
	SWAP = 0x0885, DROP = 0x0879, DUP = 0x086b, SLOW = 0x0846, FAST = 0x0837, INVIS = 0x0828, VIS = 0x0818,
	CONVERT = 0x078a, NUMBER = 0x06a9, EXECUTE = 0x069a, FIND = 0x063d, VLIST = 0x062d, WORD = 0x05ab,
	RETYPE = 0x0578, QUERY = 0x058c, LINE = 0x0506, [";"] = 0x04a1, PAD = 0x0499, BASE = 0x048a,
	CURRENT = 0x0480, CONTEXT = 0x0473, HERE = 0x0460, ABORT = 0x00ab, QUIT = 0x0099
}

-- compilation addresses of user defined words
local compilation_addresses = {}

-- inverse mapping of compilation addresses back to word names (for executing compiled code)
local compilation_addr_to_name = {}

function printf(...)
	print(string.format(...))
end

function comp_error(...)
	printf("%s:%d: %s", input_file, cur_line, string.format(...))
	os.exit(-1)
end

function comp_assert(expr, message)
	if not expr then
		comp_error("%s", message)
	end
end

function push(v)
	stack[#stack + 1] = v
end

function push_bool(v)
	stack[#stack + 1] = v and 1 or 0
end

function pop()
	local v = stack[#stack]
	comp_assert(v, "compiler stack underflow")
	stack[#stack] = nil
	return v
end

function pop2()
	local a = pop()
	local b = pop()
	return b, a
end

function peek(idx)
	local v = stack[#stack + idx + 1]
	comp_assert(v, "compiler stack underflow")
	return v
end

function remove(idx)
	comp_assert(stack[#stack + idx + 1], "compiler stack underflow")
	table.remove(stack, #stack + idx + 1)
end

function peek_char()
	local char = input:sub(cur_pos, cur_pos)
	if #char == 0 then char = nil end
	return char
end

-- Returns next character from input. Returns nil at end of input.
function next_char()
	local char = peek_char()
	if char == '\n' then cur_line = cur_line + 1 end
	cur_pos = cur_pos + 1
	return char
end

-- Returns the next symbol from input. Returns nil at end of input.
function next_symbol(delimiters)
	delimiters = delimiters or " \n\t"

	-- this is shit
	comp_assert(#delimiters <= 3)
	local delimiter1 = delimiters:sub(1, 1)
	local delimiter2 = delimiters:sub(2, 2)
	local delimiter3 = delimiters:sub(3, 3)

	-- skip leading delimiters
	while true do
		local char = peek_char()
		if char == delimiter1 or char == delimiter2 or char == delimiter3 then
			next_char()
		else
			break
		end
	end

	-- end of file reached?
	if peek_char() == nil then return nil end

	-- scan for next delimiter character
	local start = cur_pos
	while true do
		local char = next_char()
		if char == delimiter1 or char == delimiter2 or char == delimiter3 or char == nil then
			return input:sub(start, cur_pos - 2)
		end
	end
end

function next_word(allow_eof)
	local word = next_symbol()
	if word == nil and not allow_eof then errof("unexpected end of file") end
	if word then word = string.upper(word) end
	return word
end

function next_number()
	local sym = next_symbol()
	if sym == nil then comp_error("unexpected end of file") end
	local n = parse_number(sym)
	if n == nil then comp_error("expected number, got '%s'", sym) end
	return n
end

function read_short(address, x)
	comp_assert(address < 65536 - 1, "address out of range")
	return (mem[address] or 0) | ((mem[address + 1] or 0) << 8)
end

function write_short(address, x)
	comp_assert(address < 65536 - 1, "address out of range")
	if x < 0 then x = x + 65536 end
	mem[address] = x & 0xff
	mem[address + 1] = x >> 8
end

function emit_byte(x)
	comp_assert(output_pos < 65536, "out of space")
	mem[output_pos] = x
	output_pos = output_pos + 1
end

function emit_short(x)
	if x < 0 then x = x + 65536 end
	emit_byte(x & 0xff)
	emit_byte(x >> 8)
end

function emit_string(str)
	for i = 1, #str do
		emit_byte(str:byte(i))
	end
end

function emit_literal(n)
	if n == 0 then
		emit_short(PUSH_ZERO)
	elseif n >= 0 and n < 256 then
		emit_short(PUSH_BYTE)
		emit_byte(n)
	elseif n >= -32768 and n < 65536 then
		if n < 0 then n = 65536 + n end
		emit_short(PUSH_WORD)
		emit_short(n)
	else
		comp_error("literal out of range")
	end
end

-- Returns the address of the next free byte in dictionary in Ace's RAM.
function here()
	return output_pos
end

-- Returns the current numeric base used by the compiler.
function base()
	return mem[0]
end

-- Returns string representation of a number in current numeric base.
function format_number(n)
	local base = mem[0]
	comp_assert(base >= 2 and base <= 36, "invalid numeric base")

	local digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	local result = ""

	while n > 0 do
		local d = n % base
	    result = digits:sub(d + 1, d + 1) .. result
	    n = n // base
	end

	return result
end

-- Parses number from a string using current numeric base.
function parse_number(str)
	local base = mem[0]
	comp_assert(base >= 2 and base <= 36, "invalid numeric base")
	return tonumber(str, base)
end

-- Inserts a header for a new word to output dictionary. The new word has a header but with empty parameter field.
-- Its word length is also zero. The word length field is updated to correct value when the next word is added.
-- This means that the last word will have zero in the word length field. This is how the ROM code works too
-- (and its documented in Jupiter Ace Forth Programming, page 121).
function create_word(code_field)
	local name = next_word()

	local skip_header = false
	if opts.no_headers and name ~= opts.main_word then skip_header = true end

	if skip_header then
		emit_byte(0)
	else
		-- write name to dictionary, with terminator bit set for the last character
		emit_string(name:sub(1, #name - 1) .. string.char(name:byte(#name) | 128))

		-- fill the word length field of the previous word
		if prev_word_link >= start_address then
			-- prev_word_link points to the name length field of the last defined word
			-- word length field is always 4 bytes before this
			local word_length_addr = prev_word_link - 4
			local length = here() - word_length_addr
			write_short(word_length_addr, length)
		end

		emit_short(0) -- placeholder word length
		emit_short(prev_word_link)

		prev_word_link = here()
		emit_byte(#name)
	end

	local compilation_addr = here()
	emit_short(code_field)	-- code field

	-- remember compilation addresses for FIND
	compilation_addresses[name] = compilation_addr

	-- add word to compile dictionary so that other words can refer to it when compiling
	compile_dict[name] = function()
		emit_short(compilation_addr)
	end

	return name
end

-- Execute user defined word at compile time.
function execute(pc)
	local function fetch_byte()
		local x = mem[pc]
		pc = pc + 1
		return x
	end

	local function fetch_short()
		local x = read_short(pc)
		pc = pc + 2
		return x
	end

	local function fetch_signed()
		local x = fetch_short()
		if x > 32767 then x = x - 65536 end
		return x
	end

	while true do
		local instr = fetch_short()
		local name = compilation_addr_to_name[instr]
		if name then
			local func = interpret_dict[name]
			if func == nil then
				comp_error("could not determine address of %s when executing compiled code", name)
			end
			func()
		elseif instr == FORTH_END then
			break
		elseif instr == PUSH_BYTE then
			push(fetch_byte())
		elseif instr == PUSH_WORD then
			push(fetch_short())
		elseif instr == PUSH_ZERO then
			push(0)
		elseif instr == CBRANCH then
			local offset = fetch_signed() - 1
			if pop() == 0 then
				pc = pc + offset
			end
		elseif instr == BRANCH then
			pc = pc + fetch_signed() - 1
		elseif instr == DO then
			comp_error("DO not implemented for execute")
		elseif instr == LOOP then
			comp_error("LOOP not implemented for execute")
		elseif instr == PLUS_LOOP then
			comp_error("+LOOP not implemented for execute")
		elseif instr == PRINT then
			local len = fetch_short()
			for i = 1, len do
				io.write(string.char(fetch_byte()))
			end 
		else
			comp_error("unknown compilation address $%04x encountered when executing compiled code", instr)
		end
	end
end

interpret_dict = {
	CREATE = function()
		create_word(DO_PARAM)
	end,
	[':'] = function()
		last_word = create_word(DO_COLON)
		compile_mode = true
		inside_colon_definition = true
	end,
	IMMEDIATE = function()
		local name = last_word
		comp_assert(name, "invalid use of IMMEDIATE")
		local compilation_addr = compilation_addresses[name]
		comp_assert(compilation_addr, "could not determine compilation address of previous word")

		local addr = next_immediate_word

		interpret_dict[name] = function()
			execute(addr)
		end

		compile_dict[name] = function()
			execute(addr)
		end

		-- copy compiled code to compiler memory (skip code field)
		for i = compilation_addr + 2, here() - 1 do
			mem[next_immediate_word] = mem[i]
			next_immediate_word = next_immediate_word + 1
		end

		-- erase compiled code from output dictionary
		for i = compilation_addr, here() - 1 do
			mem[i] = 0
		end
		output_pos = compilation_addr
		compilation_addresses[name] = nil
	end,
	CODE = function()
		create_word(0)
		write_short(here() - 2, here())	-- patch codefield
	end,
	BYTE = function()	-- byte-sized variable
		create_word(DO_PARAM)
		local value = pop()
		comp_assert(value >= 0 and value < 256, "byte variable out of range")
		emit_byte(value)
	end,
	BYTES = function()	-- emit bytes, terminated by ; symbol
		push('bytes')
		compile_bytes = true
	end,
	[';'] = function()
		comp_assert(compile_bytes, "invalid use of ;")
		-- find start of bytes block
		local start
		for i = #stack, 1, -1 do
			if stack[i] == 'bytes' then
				start = i
				break
			end
		end
		for i = start + 1, #stack do
			emit_byte(stack[i])
			stack[i] = nil
		end 
		stack[start] = nil
		compile_bytes = false
	end,
	VARIABLE = function()
		create_word(DO_PARAM)
		emit_short(pop())	-- write variable value to dictionary
	end,
	CONST = function()
		local name = next_word()
		local value = pop()

		-- add compile time word which emits the constant as literal
		compile_dict[name] = function()
			emit_literal(value)
		end

		-- add word to interpreter dictionary so that the constant can be used at compile time
		interpret_dict[name] = function()
			push(value)
		end
	end,
	ALLOT = function()
		local count = pop()
		for i = 1, count do
			emit_byte(0)
		end
	end,
	FIND = function()
		local name = next_word()
		local addr = compilation_addresses[name]
		if addr == nil then comp_error("undefined word %s", name) end
		push(addr)
	end,
	[','] = function()
		emit_short(pop() & 0xffff)
	end,
	['C,'] = function()
		emit_byte(pop() & 0xff)
	end,
	['"'] = function()
		local str = next_symbol('"')
		for i = 1, #str do
			emit_byte(str:byte(i))
		end
	end,
	['('] = function()
		-- skip block comment
		next_symbol(")")
	end,
	['\\'] = function()
		-- skip line comment
		while true do
			local ch = next_char()
			if ch == nil or ch == '\n' then break end
		end
	end,
	[']'] = function()
		comp_assert(inside_colon_definition, "] without matching [")
		compile_mode = true
	end,
	['."'] = function()
		local str = next_symbol("\"")
		io.write(str)
	end,
	DUP = function() push(peek(-1)) end,
	OVER = function() push(peek(-2)) end,
	DROP = function() pop() end,
	ROT = function() push(peek(-3)); remove(-4) end,
	SWAP = function() local a, b = pop2(); push(b); push(a) end,
	PICK = function() push(peek(-pop())) end,
	ROLL = function() local i = pop(); push(peek(-i)); remove(-i - 1) end,
	['+'] = function() local a, b = pop2(); push(a + b) end,
	['-'] = function() local a, b = pop2(); push(a - b) end,
	['*'] = function() local a, b = pop2(); push(a * b) end,
	['/'] = function() local a, b = pop2(); push(a / b) end,
	['<'] = function() local a, b = pop2(); push_bool(a < b) end,
	['>'] = function() local a, b = pop2(); push_bool(a > b) end,
	['='] = function() local a, b = pop2(); push_bool(a == b) end,
	['0<'] = function() push_bool(pop() < 0) end,
	['0>'] = function() push_bool(pop() > 0) end,
	['0='] = function() push_bool(pop() == 0) end,
	['1+'] = function() push(pop() + 1) end,
	['1-'] = function() push(pop() - 1) end,
	['2+'] = function() push(pop() + 2) end,
	['2-'] = function() push(pop() - 2) end,
	['.'] = function() io.write(format_number(pop()), " ") end,
	NEGATE = function() push(-pop()) end,
	AND = function() local a, b = pop2(); push(a & b) end,
	OR = function() local a, b = pop2(); push(a | b) end,
	XOR = function() local a, b = pop2(); push(a ~ b) end,
	NOT = function() push_bool(pop() == 0) end,
	ABS = function() push(math.abs(pop())) end,
	MIN = function() local a, b = pop2(); push(math.min(a, b)) end,
	MAX = function() local a, b = pop2(); push(math.max(a, b)) end,
	CR = function() io.write("\n") end,
	EMIT = function() io.write(string.char(pop())) end,
	SPACE = function() io.write(" ") end,
	SPACES = function() io.write(string.rep(" ", pop())) end,
	HERE = function() push(here()) end,
	ASCII = function()
		local char = next_symbol()
		if #char ~= 1 then comp_error("invalid symbol following ASCII") end
		push(char:byte(1))
	end,
	['C!'] = function()
		local n, addr = pop2()
		if n < 0 then n = n + 256 end
		comp_assert(addr >= 0 and addr < 65536, "invalid address")
		comp_assert(n >= 0 and n < 256, "value out of range")
		mem[addr] = n
	end,
	['C@'] = function()
		local addr = pop()
		comp_assert(addr >= 0 and addr < 65536, "invalid address")
		push(mem[addr] or 0)
	end,
	['!'] = function()
		local n, addr = pop2()
		if n < 0 then n = n + 256 end
		comp_assert(addr >= 0 and addr < 65536, "invalid address")
		comp_assert(n >= 0 and n < 65536, "value out of range")
		write_short(addr, n)
	end,
	['@'] = function()
		local addr = pop()
		comp_assert(addr >= 0 and addr < 65536, "invalid address")
		push(read_short(addr) or 0)
	end,
	BASE = function() push(0) end,
	HEX = function() mem[0] = 16 end,
	DECIMAL = function() mem[0] = 10 end,
	LIT = function() emit_literal(pop()) end,
	['[IF]'] = function()
		if pop() == 0 then
			-- skip until next [ELSE] or [THEN]
			local depth = 0
			while true do
				local sym = next_word()
				if sym == '[IF]' then
					depth = depth + 1
				elseif sym == '[ELSE]' and depth == 0 then
					break
				elseif sym == '[THEN]' then
					if depth == 0 then break end
					depth = depth - 1
				end
			end
		end
	end,
	['[ELSE]'] = function()
		-- skip until matching [THEN]
		local depth = 0
		while true do
			local sym = next_word()
			if sym == '[IF]' then
				depth = depth + 1
			elseif sym == '[THEN]' then
				if depth == 0 then break end
				depth = depth - 1
			end
		end
	end,
	['[THEN]'] = function() end,
	['[DEFINED]'] = function()
		push(compile_dict[next_word()] and 255 or 0)
	end,
}

compile_dict = {
	[':'] = function()
		comp_error("invalid :")
	end,
	[';'] = function()
		emit_short(FORTH_END)
		compile_mode = false
		inside_colon_definition = false

		-- patch gotos
		for patch_loc, label in pairs(gotos) do
			local target_addr = labels[label]
			if target_addr == nil then comp_error("undefined label '%s'", label) end
			write_short(patch_loc, target_addr - patch_loc - 1)
		end
		labels = {}
		gotos = {}
	end,
	['['] = function()
		-- temporarily fall back to the interpreter
		compile_mode = false
	end,
	['."'] = function()
		local str = next_symbol("\"")
		emit_short(PRINT)
		emit_short(#str)
		emit_string(str)
	end,
	IF = function()
		-- emit conditional branch
		emit_short(CBRANCH)
		push(here())
		push('if')
		emit_short(0)	-- placeholder branch offset
	end,
	ELSE = function()
		comp_assert(pop() == 'if', "ELSE without matching IF")
		local where = pop()
		-- emit jump to THEN
		emit_short(BRANCH)
		push(here())
		push('if')
		emit_short(0)	-- placeholder branch offset
		-- patch branch offset for ?branch at IF
		write_short(where, here() - where - 1)
	end,
	THEN = function()
		-- patch branch offset for ?branch at IF
		comp_assert(pop() == 'if', "THEN without matching IF")
		local where = pop()
		write_short(where, here() - where - 1)
	end,
	BEGIN = function()
		push(here())
		push('begin')
	end,
	UNTIL = function()
		comp_assert(pop() == 'begin', "UNTIL without matching BEGIN")
		local target = pop()
		emit_short(CBRANCH)
		emit_short(target - here() - 1)
	end,
	AGAIN = function()
		comp_assert(pop() == 'begin', "AGAIN without matching BEGIN")
		local target = pop()
		emit_short(BRANCH)
		emit_short(target - here() - 1)
	end,
	DO = function()
		emit_short(DO)
		push(here())
		push('do')
	end,
	LOOP = function()
		comp_assert(pop() == 'do', "LOOP without matching DO")
		local target = pop()
		emit_short(LOOP)
		emit_short(target - here() - 1)		
	end,
	["+LOOP"] = function()
		comp_assert(pop() == 'do', "+LOOP without matching DO")
		local target = pop()
		emit_short(PLUS_LOOP)
		emit_short(target - here() - 1)		
	end,
	WHILE = function() comp_error("WHILE not implemented") end,
	REPEAT = function() comp_error("REPEAT not implemented") end,
	GOTO = function()
		local label = next_symbol()
		emit_short(BRANCH)
		local addr = here()
		emit_short(0)	-- place holder branch offset
		gotos[addr] = label
	end,
	LABEL = function()
		local label = next_symbol()
		labels[label] = here()
	end,
	ASCII = function()
		local char = next_symbol()
		if #char ~= 1 then comp_error("invalid symbol following ASCII") end
		emit_literal(char:byte(1))
	end,
}

local immediate_words = { "(", "\\", "[IF]", "[ELSE]", "[THEN]", "[DEFINED]" }

for _, name in ipairs(immediate_words) do
	compile_dict[name] = assert(interpret_dict[name])
end

-- insert built-in ROM words into compilation dict
for name, addr in pairs(rom_words) do
	compile_dict[name] = compile_dict[name] or function()
		emit_short(addr)
	end

	compilation_addr_to_name[addr] = name
end

-- load asm vocabulary
-- TODO: CODE word should switch to asm vocabulary?
for name, func in pairs(asm_vocabulary) do
	interpret_dict[name] = func
end

-- compile all files
for _, filename in ipairs(input_files) do
	-- load input file
	local file, err = io.open(filename, "r")
	if file == nil then print(err); os.exit(-1) end
	input = file:read("a")
	file:close()

	input_file = filename
	cur_pos = 1
	cur_line = 1

	-- execute input
	while true do
		local sym = next_word(true)
		if sym == nil then break end
		--printf("symbol [%s]", sym)

		if compile_mode then
			-- compile mode
			local func = compile_dict[sym]
			if func == nil then
				-- is it a number?
				local n = parse_number(sym)
				if n == nil then comp_error("undefined word '%s'", sym) end
				emit_literal(n)
			else
				func()
			end
		else
			-- interpret mode
			local func = interpret_dict[sym]
			if func == nil then
				-- is it a number?
				local n = parse_number(sym)
				if n == nil then comp_error("undefined word '%s'", sym) end
				push(n)
			else
				func()
			end
		end
	end
end

-- write output
if output_file then
	local file = io.open(output_file, "wb")

	local function shortstr(x)
		return string.char(x & 0xff) .. string.char(x >> 8)
	end

	local function checksum(str)
		local chk = 0
		for i = 1, #str do
			chk = chk ~ str:byte(i)	-- xor
		end
		return chk & 0xff
	end

	-- header
	local dict_data_size = here() - start_address
	local dict_data_end = here()
	local header = "\25\0\0dict      " ..
		shortstr(dict_data_size) ..
		shortstr(start_address) ..
		shortstr(prev_word_link) ..
		shortstr(v_current) ..
		shortstr(v_context) ..
		shortstr(v_voclink) ..
		shortstr(dict_data_end)
	assert(#header == 27)
	file:write(header)
	file:write(string.char(checksum(header:sub(3))))

	-- data
	file:write(shortstr(dict_data_size + 1))
	local chk = 0
	for addr = start_address, dict_data_end - 1 do
		local byte = mem[addr]
		file:write(string.char(byte))
		chk = chk ~ byte
	end
	file:write(string.char(chk & 0xff))
	file:close()
end
