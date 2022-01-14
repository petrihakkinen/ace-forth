#!tools/lua

-- Ace Forth cross compiler
-- Copyright (c) 2021 Petri Häkkinen
-- See LICENSE file for details
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

local mcode = require "mcode"

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
local POSTPONE		= 0x0001 -- Internal word, hacky way to postpone compilation of words, not actual ROM code!

local start_address = 0x3c51
local v_current = 0x3C4C
local v_context = 0x3C4C
local v_voclink = 0x3C4F

-- parse args
local args = {...}

local input_files = {}
local output_file

opts = { main_word = "main", tap_filename = "dict" }

function fatal_error(msg)
	io.stderr:write(msg, "\n")
	os.exit(-1)
end

do
	local i = 1
	while i <= #args do
		local arg = args[i]
		if string.match(arg, "^%-") then
			if arg == "--minimal-word-names" then
				opts.minimal_word_names = true
			elseif arg == "--inline" then
				opts.inline_words = true
			elseif arg == "--eliminate-unused-words" then
				opts.eliminate_unused_words = true
			elseif arg == "--small-literals" then
				opts.small_literals = true
			elseif arg == "--optimize" then
				opts.inline_words = true
				opts.minimal_word_names = true
				opts.eliminate_unused_words = true
				opts.small_literals = true
			elseif arg == "--verbose" then
				opts.verbose = true
			elseif arg == "--ignore-case" then
				opts.ignore_case = true
			elseif arg == "--no-warn" then
				opts.no_warn = true
			elseif arg == "--mcode" then
				opts.mcode = true
			elseif arg == "--main" then
				i = i + 1
				opts.main_word = args[i]
				if opts.main_word == nil then fatal_error("Word name must follow --main") end
			elseif arg == "--filename" then
				i = i + 1
				opts.tap_filename = args[i]
				if opts.tap_filename == nil then fatal_error("TAP filename must follow --filename") end
				if #opts.tap_filename > 10 then fatal_error("TAP filename too long (max 10 chars)") end
			elseif arg == "-o" then
				i = i + 1
				output_file = args[i]
				if output_file == nil then fatal_error("Output filename must follow -o") end
			elseif arg == "-l" then
				i = i + 1
				opts.listing_file = args[i]
				if opts.listing_file == nil then fatal_error("Listing filename must follow -l") end
			else
				fatal_error("Invalid option: " .. arg)
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
	print("  -o <filename>             Sets output filename")
	print("  -l <filename>             Write listing to file")
	print("  --mcode                   Compile to machine code")
	print("  --ignore-case             Treat all word names as case insensitive")
	print("  --minimal-word-names      Rename all words as '@', except main word")
	print("  --inline                  Inline words that are only used once")
	print("  --eliminate-unused-words  Eliminate unused words when possible")
	print("  --small-literals          Optimize byte-sized literals")
	print("  --optimize                Enable all safe optimizations")
	print("  --no-warn                 Disable all warnings")
	print("  --verbose                 Print information while compiling")
	print("  --main <name>             Sets name of main executable word (default 'main')")
	print("  --filename <name>         Sets the filename for tap header (default 'dict')")
	os.exit(-1)
end

local eliminate_words = {}
local inline_words = {}
local pass = 1

::restart::

if opts.verbose then print("Pass " .. pass) end

local input								-- source code as string
local input_file						-- current input filename
local cur_pos							-- current position in input
local cur_line							-- current line in input
local compile_mode = false				-- interpret or compile mode?
local prev_compile_mode					-- previous value of compile_mode (before [ was invoked)
local stack = {}						-- the compiler stack
local mem = { [0] = 10 }				-- compiler memory
local output_pos = start_address		-- current output position in the dictionary
local next_immediate_word = 1			-- next free address for compiled immediate words
local labels = {}						-- label -> address for current word
local gotos = {}						-- address to be patched -> label for current word
local last_word							-- name of last user defined word
local word_counts = {}					-- how many times each word is used in generated code?
local word_flags = {}					-- bitfield of F_* flags
local list_headers = {}					-- listing headers (addr -> string)
local list_lines = {}					-- listing lines (addr -> string)
local list_comments = {}				-- listing comments (addr -> string)
local dont_allow_redefining = false		-- if set, do not allow redefining word behaviors (hack for library words)
local warnings = {}						-- array of strings

-- address of prev word's name length field in RAM
-- initial value: address of FORTH in RAM
local prev_word_link = 0x3C49

rom_words = {
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

-- word flags
F_NO_INLINE	= 0x01 			-- words that should never we inlined (explicitly marked as 'noinline' or cannot be inlined)
F_NO_ELIMINATE = 0x02		-- words that should not be eliminated even when they are not used
F_HAS_SIDE_EXITS = 0x04		-- words that have side-exits and cannot there be inlined
F_INVISIBLE = 0x08			-- word cannot be seen from user written code
F_MACRO = 0x10				-- word is a macro (to be executed immediately at compile time)

-- starting addresses of user defined words
local word_start_addresses = {}

-- compilation addresses of user defined words
compilation_addresses = {}

-- inverse mapping of compilation addresses back to word names (for executing compiled code)
local compilation_addr_to_name = {}

-- Return stack for executing compile time code
local return_stack = {}

local function r_push(x)
	return_stack[#return_stack + 1] = x
end

local function r_pop()
	local x = return_stack[#return_stack]
	comp_assert(x, "return stack underflow")
	return_stack[#return_stack] = nil
	return x
end

function r_peek(idx)
	local v = return_stack[#return_stack + idx + 1]
	comp_assert(v, "return stack underflow")
	return v
end

-- Separate stack for control flow constructs
local control_flow_stack = {}

function cf_push(x)
	control_flow_stack[#control_flow_stack + 1] = x
end

function cf_pop(x)
	local x = control_flow_stack[#control_flow_stack]
	comp_assert(x ~= nil, "control flow stack underflow")
	control_flow_stack[#control_flow_stack] = nil
	return x
end

-- Checks that the control flow stack is empty at the end of word definition,
-- and if not, raises an appropriate error.
function check_control_flow_stack()
	local v = control_flow_stack[#control_flow_stack]

	if v == "if" then
		comp_error("IF without matching THEN")
	elseif v == "begin" then
		comp_error("BEGIN without matching UNTIL or AGAIN")
	elseif v == "do" then
		comp_error("DO without matching LOOP")
	elseif v then
		comp_error("unbalanced control flow constructs")
	end
end

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

function warn(...)
	if not opts.no_warn then
		warnings[#warnings + 1] = string.format("%s:%d: Warning! %s", input_file, cur_line, string.format(...))
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

-- Returns the next whitespace delimited symbol from input. Returns nil at end of input.
function next_symbol()
	-- skip leading whitespaces
	while true do
		local char = peek_char()
		if char == ' ' or char == '\n' or char == '\t' then
			next_char()
		else
			break
		end
	end

	-- end of file reached?
	if peek_char() == nil then return nil end

	-- scan for next whitespace character
	local start = cur_pos
	while true do
		local char = next_char()
		if char == ' ' or char == '\n' or char == '\t' or char == nil then
			return input:sub(start, cur_pos - 2)
		end
	end
end

-- Returns the next symbol up until next occurrence of given delimiter.
-- Returns nil at the end of input.
function next_symbol_with_delimiter(delimiter)
	local start = cur_pos
	while true do
		local char = next_char()
		if char == delimiter then
			return input:sub(start, cur_pos - 2)
		elseif char == nil then
			return nil
		end
	end
end

function next_word(allow_eof)
	local word = next_symbol()
	if word == nil and not allow_eof then comp_error("unexpected end of file") end
	if opts.ignore_case and word then word = string.upper(word) end
	return word
end

function next_number()
	local sym = next_symbol()
	if sym == nil then comp_error("unexpected end of file") end
	local n = parse_number(sym)
	if n == nil then comp_error("expected number, got '%s'", sym) end
	return n
end

-- Reads symbols until end marker has been reached, processing comments.
-- That is, end markers inside comments are ignored.
function skip_until(end_marker)
	while true do
		local sym = next_word()
		if sym == end_marker then
			break
		elseif sym == "\\" then
			next_symbol_with_delimiter('\n')
		elseif sym == "(" then
			next_symbol_with_delimiter(')')
		end
	end
end

-- Checks whether two word names are the same, taking case sensitivity option into account.
function match_word(name1, name2)
	if opts.ignore_case then
		return string.upper(name1) == string.upper(name2)
	else
		return name1 == name2
	end
end

function read_byte(address)
	comp_assert(address < 65536, "address out of range")
	return mem[address] or 0
end

function read_short(address, x)
	comp_assert(address < 65536 - 1, "address out of range")
	return (mem[address] or 0) | ((mem[address + 1] or 0) << 8)
end

function write_byte(address, x)
	comp_assert(address < 65536 - 1, "address out of range")
	if x < 0 then x = x + 256 end
	mem[address] = x & 0xff
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
	if compile_mode == "mcode" then
		if n >= -32768 and n < 65536 then
			if n < 0 then n = 65536 + n end
			mcode.emit_literal(n)
		else
			comp_error("literal out of range")
		end
	else
		list_line("lit %d", n)

		if n >= 0 and n < 256 and opts.small_literals then
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
end

-- Erases last N emitted bytes from output dictionary.
function erase(n)
	for i = here() - n, here() - 1 do
		mem[i] = 0
	end
	output_pos = output_pos - n
end

-- Returns the address of the next free byte in dictionary in Ace's RAM.
function here()
	return output_pos
end

-- Enters interpreter state. Usually called by ;
function interpreter_state()
	compile_mode = false
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

	if n == 0 then return "0" end

	local neg = n < 0
	if neg then	n = math.abs(n) end

	while n > 0 do
		local d = n % base
	    result = digits:sub(d + 1, d + 1) .. result
	    n = n // base
	end

	if neg then result = "-" ..result end

	return result
end

-- Parses number from a string using current numeric base.
function parse_number(str)
	local base = mem[0]
	comp_assert(base >= 2 and base <= 36, "invalid numeric base")
	return tonumber(str, base)
end

-- Fills the word length field of previous word in dictionary.
function update_word_length()
	if prev_word_link >= start_address then
		-- prev_word_link points to the name length field of the last defined word
		-- word length field is always 4 bytes before this
		local word_length_addr = prev_word_link - 4
		local length = here() - prev_word_link + 4
		write_short(word_length_addr, length)
	end
end

-- Inserts a header for a new word to output dictionary. The new word has a header but with empty parameter field.
-- Its word length is also zero. The word length field is updated to correct value when the next word is added.
-- This means that the last word will have zero in the word length field. This is how the ROM code works too
-- (and its documented in Jupiter Ace Forth Programming, page 121).
function create_word(code_field, name, flags)
	flags = flags or 0

	word_start_addresses[name] = here()
	word_flags[name] = flags
	word_counts[name] = word_counts[name] or 0

	list_header(name)

	if not opts.mcode then
		update_word_length()

		list_comment("word header")
		
		-- write name to dictionary, with terminator bit set for the last character
		local name = name
		if opts.minimal_word_names and name ~= opts.main_word then name = "@" end
		name = string.upper(name)
		emit_string(name:sub(1, #name - 1) .. string.char(name:byte(#name) | 128))

		emit_short(0) -- placeholder word length
		emit_short(prev_word_link)

		prev_word_link = here()
		emit_byte(#name)
	end

	-- compilation addresses work differently with interpreted Forth and machine code:
	-- interpreter: compilation address points to code field of the word
	-- machine code: compilation address points directly to the start of machine code
	local compilation_addr = here()

	if not opts.mcode then
		emit_short(code_field)	-- code field
	end

	-- remember compilation addresses for FIND
	compilation_addresses[name] = compilation_addr

	-- add word to compile dictionary so that other words can refer to it when compiling
	if (flags & F_INVISIBLE) == 0 then
		compile_dict[name] = function()
			word_counts[name] = word_counts[name] + 1
			list_line(name)
			emit_short(compilation_addr)
		end
	end

	return name
end

-- Erases previously compiled word from dictionary.
-- Returns the contents of the parameter field of the erased word.
function erase_previous_word()
	local name = last_word

	local start_addr = word_start_addresses[name]
	assert(start_addr, "could not determine starting address of previous word")

	local compilation_addr = compilation_addresses[name]
	assert(compilation_addr, "could not determine compilation address of previous word")

	-- fix prev word link
	if not opts.mcode then
		prev_word_link = read_short(compilation_addr - 3)
	end

	local code_start = compilation_addr
	if not opts.mcode then code_start = code_start + 2 end

	-- store old code (skip code field)
	local code = {}
	for i = code_start, here() - 1 do
		code[#code + 1] = mem[i]
	end

	for i = start_addr, here() - 1 do
		mem[i] = 0
	end

	word_start_addresses[name] = nil
	compilation_addresses[name] = nil

	output_pos = start_addr

	return code
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
			local limit, counter = pop2()
			r_push(limit)
			r_push(counter)
		elseif instr == LOOP or instr == PLUS_LOOP then
			local offset = fetch_signed() - 1
			local counter = r_pop()
			local limit = r_pop()
			local step = instr == LOOP and 1 or pop()
			counter = counter + step
			if (step >= 0 and counter < limit) or (step < 0 and counter > limit) then
				r_push(limit)
				r_push(counter)
				pc = pc + offset
			end
		elseif instr == PRINT then
			local len = fetch_short()
			for i = 1, len do
				io.write(string.char(fetch_byte()))
			end 
		elseif instr == POSTPONE then
			local len = fetch_short()
			local name = ""
			for i = 1, len do
				name = name .. string.char(fetch_byte())
			end

			local func
			if compile_mode == "mcode" then
				func = mcode_dict[name]
			else
				func = compile_dict[name]
			end

			if func == nil then
				comp_error("POSTPONE failed -- could not find compile behavior for word '%s'", name)
			end
			func()
		else
			comp_error("unknown compilation address $%04x encountered when executing compiled code", instr)
		end
	end
end

function execute_string(src, filename)
	-- initialize parser state
	input = src
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
			local func
			if compile_mode == "mcode" then
				func = mcode_dict[sym]
			else
				func = compile_dict[sym]
			end
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

-- Listings

function list_header(...)
	if opts.listing_file then
		list_headers[here()] = string.format(...)
	end
end

function list_line(...)
	if opts.listing_file then
		list_lines[here()] = string.format(...)
	end
end

function list_comment(...)
	if opts.listing_file then
		list_comments[here()] = string.format(...)
	end
end

-- Patches hex literal (jump address) in already emitted listing line.
function list_patch(addr, new_value)
	if opts.listing_file then
		local line = list_lines[addr]
		assert(line, "invalid listing line")
		line = line:gsub("%$%x+", new_value)
		list_lines[addr] = line
	end
end

-- Erases the last n lines, including the current line, from the listing.
function list_erase_lines(n)
	if opts.listing_file then
		local addr = here()
		while n > 0 and addr >= start_address do
			if list_lines[addr] then
				list_lines[addr] = nil
				list_comments[addr] = nil
				n = n - 1
			end
			addr = addr - 1
		end
	end
end

function write_listing(filename)
	local file = io.open(filename, "wb")
	local addr = start_address
	local len = 0

	local function align(x)
		local spaces = x - len
		if spaces > 0 then
			file:write(string.rep(" ", spaces))
			len = len + spaces
		end
	end

	while addr < here() do
		if list_headers[addr] then
			if addr > start_address then file:write("\n") end
			file:write(list_headers[addr], ":\n")
		end

		-- find end address of line
		local e = here()
		for i = addr + 1, here() do
			if list_lines[i] or list_comments[i] then
				e = i
				break
			end
		end
		assert(e > addr)

		file:write(string.format("%04x", addr))
		len = 4

		-- emit bytes
		for i = addr, e - 1 do
			file:write(string.format(" %02x", read_byte(i)))
			len = len + 3
		end

		if list_lines[addr] then
			align(20)
			file:write(" ", list_lines[addr])
			len = len + #list_lines[addr] + 1
		end

		if list_comments[addr] then
			align(40)
			file:write(" ; ", list_comments[addr])
		end

		file:write("\n")
		addr = e
	end

	file:close()
end

interpret_dict = {
	create = function()
		-- this word cannot be dead-code eliminated, because we don't know where it ends
		-- (this is not strictly true since every word has a length field!)
		local name = create_word(DO_PARAM, next_word(), F_NO_ELIMINATE)

		-- make it possible to refer to the word from machine code
		local addr = here()
		mcode_dict[name] = function()
			mcode.emit_literal(addr, name)
			word_counts[name] = word_counts[name] + 1
		end
	end,
	['create{'] = function()	-- create{ is like create but it can be eliminated since } marks the end of the word
		local name = next_word()
		if not eliminate_words[name] then
			create_word(DO_PARAM, name)

			-- make it possible to refer to the word from machine code
			local addr = here()
			mcode_dict[name] = function()
				mcode.emit_literal(addr, name)
				word_counts[name] = word_counts[name] + 1
			end
		else
			skip_until('}')
		end
	end,
	['}'] = function()
		-- } is a nop unless we're skipping create{ block
	end,
	[':'] = function() 
		local name = next_word()
		if not eliminate_words[name] then
			local flags = 0
			if compile_dict[name] and dont_allow_redefining then flags = F_INVISIBLE end

			-- we don't currently support inlining machine code
			if opts.mcode then flags = flags | F_NO_INLINE end

			last_word = create_word(DO_COLON, name, flags)

			compile_mode = true

			if opts.mcode then
				-- load top of stack to DE if this is the machine code entry point from Forth
				if name == opts.main_word then
					list_line("rst 24")
					list_comment("adjust stack for machine code")
					emit_byte(0xc7 + 24)
				end

				compile_mode = "mcode"

				if mcode_dict[name] == nil or not dont_allow_redefining then
					mcode_dict[name] = function()
						mcode.call_mcode(name)
						word_counts[name] = word_counts[name] + 1
					end
				end
			end
		else
			skip_until(';')
		end
	end,
	[':m'] = function() 
		-- compile macro
		last_word = create_word(0, next_word(), F_MACRO | F_NO_INLINE | F_NO_ELIMINATE)
		compile_mode = true

		local addr = next_immediate_word
		interpret_dict[last_word] = function() execute(addr) end
		compile_dict[last_word] = function() execute(addr) end
		mcode_dict[last_word] = function() execute(addr) end
	end,
	noinline = function()
		-- forbid inlining previous word
		comp_assert(last_word, "invalid use of NOINLINE")
		word_flags[last_word] = word_flags[last_word] | F_NO_INLINE
	end,
	code = function()
		local name = create_word(0, next_word(), F_NO_ELIMINATE)

		-- patch codefield
		if not opts.mcode then
			write_short(here() - 2, here())
		end

		-- make it possible to call CODE words from machine code
		if mcode_dict[name] == nil or not dont_allow_redefining then
			mcode_dict[name] = function()
				mcode.call_code(name)
				word_counts[name] = word_counts[name] + 1
			end
		end
	end,
	byte = function()	-- byte-sized variable
		local name = create_word(DO_PARAM, next_word(), F_NO_ELIMINATE)
		local value = pop()
		comp_assert(value >= 0 and value < 256, "byte variable out of range")
		local addr = here()
		emit_byte(value)

		-- make it possible to refer to variable from machine code
		mcode_dict[name] = function()
			mcode.emit_literal(addr, name)
		end
	end,
	bytes = function()	-- emit bytes, terminated by ; symbol
		push('bytes')
	end,
	[';bytes'] = function()
		-- find start of bytes block
		local start
		for i = #stack, 1, -1 do
			if stack[i] == 'bytes' then
				start = i
				break
			end
		end
		comp_assert(start, "invalid use of ;BYTES")
		for i = start + 1, #stack do
			emit_byte(stack[i])
			stack[i] = nil
		end 
		stack[start] = nil
		compile_bytes = false
	end,
	variable = function()
		local name = create_word(DO_PARAM, next_word(), F_NO_ELIMINATE)
		local addr = here()
		emit_short(pop())	-- write variable value to dictionary

		-- make it possible to refer to variable from machine code
		mcode_dict[name] = function()
			mcode.emit_literal(addr, name)
		end
	end,
	const = function()
		local name = next_word()
		local value = pop()

		-- add compile time word which emits the constant as literal
		compile_dict[name] = function()
			emit_literal(value)
			list_comment(name)
		end

		-- add mcode behavior for the word which emits the constant as machine code literal
		mcode_dict[name] = function()
			emit_literal(value)
			list_comment(name)
		end

		-- add word to interpreter dictionary so that the constant can be used at compile time
		interpret_dict[name] = function()
			push(value)
		end
	end,
	allot = function()
		local count = pop()
		for i = 1, count do
			emit_byte(0)
		end
	end,
	find = function()
		local name = next_word()
		local addr = compilation_addresses[name]
		if addr == nil then comp_error("undefined word %s", name) end
		push(addr)
	end,
	[','] = function()
		emit_short(pop() & 0xffff)
	end,
	['c,'] = function()
		emit_byte(pop() & 0xff)
	end,
	['"'] = function()
		local str = next_symbol_with_delimiter('"')
		for i = 1, #str do
			emit_byte(str:byte(i))
		end
	end,
	['('] = function()
		-- skip block comment
		comp_assert(next_symbol_with_delimiter(')'), "unfinished comment")
	end,
	['\\'] = function()
		-- skip line comment
		next_symbol_with_delimiter('\n')
	end,
	[']'] = function()
		comp_assert(previous_compile_mode ~= nil, "] without matching [")
		compile_mode = previous_compile_mode
		previous_compile_mode = nil
	end,
	['."'] = function()
		local str = next_symbol_with_delimiter("\"")
		io.write(str)
	end,
	dup = function() push(peek(-1)) end,
	over = function() push(peek(-2)) end,
	drop = function() pop() end,
	nip = function() local a = pop(); pop(); push(a) end,
	['2dup'] = function() push(peek(-2)); push(peek(-2)) end,
	['2drop'] = function() pop2() end,
	['2over'] = function() push(peek(-4)); push(peek(-4)) end,
	rot = function() push(peek(-3)); remove(-4) end,
	swap = function() local a, b = pop2(); push(b); push(a) end,
	pick = function() push(peek(-pop())) end,
	roll = function() local i = pop(); push(peek(-i)); remove(-i - 1) end,
	['>r'] = function() r_push(pop()) end,
	['r>'] = function() push(r_pop()) end,
	['r@'] = function() push(r_peek(-1)) end,
	['+'] = function() local a, b = pop2(); push(a + b) end,
	['-'] = function() local a, b = pop2(); push(a - b) end,
	['*'] = function() local a, b = pop2(); push(a * b) end,
	['/'] = function() local a, b = pop2(); push(a // b) end,
	['*/'] = function() local c = pop(); local a, b = pop2(); push(a * b // c) end,
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
	['2*'] = function() push(pop() * 2) end,
	['2/'] = function() push(pop() // 2) end,
	['.'] = function() io.write(format_number(pop()), " ") end,
	negate = function() push(-pop()) end,
	xor = function() local a, b = pop2(); push(a ~ b) end,
	['and'] = function() local a, b = pop2(); push(a & b) end,
	['or'] = function() local a, b = pop2(); push(a | b) end,
	['not'] = function() push_bool(pop() == 0) end,
	abs = function() push(math.abs(pop())) end,
	min = function() local a, b = pop2(); push(math.min(a, b)) end,
	max = function() local a, b = pop2(); push(math.max(a, b)) end,
	cr = function() io.write("\n") end,
	emit = function() io.write(string.char(pop())) end,
	space = function() io.write(" ") end,
	spaces = function() io.write(string.rep(" ", pop())) end,
	here = function() push(here()) end,
	ascii = function()
		local char = next_symbol()
		if #char ~= 1 then comp_error("invalid symbol following ASCII") end
		push(char:byte(1))
	end,
	['c!'] = function()
		local n, addr = pop2()
		if n < 0 then n = n + 256 end
		comp_assert(addr >= 0 and addr < 65536, "invalid address")
		comp_assert(n >= 0 and n < 256, "value out of range")
		mem[addr] = n
	end,
	['c@'] = function()
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
	base = function() push(0) end,
	hex = function() mem[0] = 16 end,
	decimal = function() mem[0] = 10 end,
	['[if]'] = function()
		if pop() == 0 then
			-- skip until next [ELSE] or [THEN]
			local depth = 0
			while true do
				local sym = next_word()
				if match_word(sym, '[if]') then
					depth = depth + 1
				elseif match_word(sym, '[else]') and depth == 0 then
					break
				elseif match_word(sym, '[then]') then
					if depth == 0 then break end
					depth = depth - 1
				end
			end
		end
	end,
	['[else]'] = function()
		-- skip until matching [THEN]
		local depth = 0
		while true do
			local sym = next_word()
			if match_word(sym, '[if]') then
				depth = depth + 1
			elseif match_word(sym, '[then]') then
				if depth == 0 then break end
				depth = depth - 1
			end
		end
	end,
	['[then]'] = function() end,
	['[defined]'] = function()
		push(compile_dict[next_word()] and 255 or 0)
	end,
	i = function()
		push(r_peek(-1))
	end,
	['.s'] = function()
		for i = 1, #stack do
			io.write(format_number(stack[i]), " ")
		end
	end,
}

compile_dict = {
	[':'] = function()
		comp_error("invalid :")
	end,
	[';'] = function()
		list_line("forth-end")
		emit_short(FORTH_END)
		compile_mode = false

		check_control_flow_stack()

		-- patch gotos
		for patch_loc, label in pairs(gotos) do
			local target_addr = labels[label]
			if target_addr == nil then comp_error("undefined label '%s'", label) end
			write_short(patch_loc, target_addr - patch_loc - 1)
		end
		labels = {}
		gotos = {}

		-- inlining
		if inline_words[last_word] then
			local name = last_word
			local code = erase_previous_word()

			-- when the inlined word is compiled, we emit its code
			compile_dict[name] = function()
				-- skip ret at the end
				for i = 1, #code - 2 do
					emit_byte(code[i])
				end
			end
		end

		-- finish macro
		if (word_flags[last_word] & F_MACRO) ~= 0 then
			local code = erase_previous_word()

			-- store code in compiler memory
			for _, byte in ipairs(code) do
				mem[next_immediate_word] = byte
				next_immediate_word = next_immediate_word + 1
			end
		end
	end,
	['['] = function()
		-- temporarily fall back to the interpreter
		previous_compile_mode = compile_mode
		compile_mode = false
	end,
	['."'] = function()
		local str = next_symbol_with_delimiter('"')
		list_line(' ." %s"', str)
		emit_short(PRINT)
		emit_short(#str)
		emit_string(str)
	end,
	['if'] = function()
		-- emit conditional branch
		list_line("?branch ???") -- TODO: patch jump
		emit_short(CBRANCH)
		cf_push(here())
		cf_push('if')
		emit_short(0)	-- placeholder branch offset
	end,
	['else'] = function()
		comp_assert(cf_pop() == 'if', "ELSE without matching IF")
		local where = cf_pop()
		-- emit jump to THEN
		list_line("branch ?")	-- TODO: patch jump
		emit_short(BRANCH)
		cf_push(here())
		cf_push('if')
		emit_short(0)	-- placeholder branch offset
		-- patch branch offset for ?branch at IF
		write_short(where, here() - where - 1)
	end,
	['then']= function()
		-- patch branch offset for ?branch at IF
		comp_assert(cf_pop() == 'if', "THEN without matching IF")
		local where = cf_pop()
		write_short(where, here() - where - 1)
	end,
	begin = function()
		cf_push(here())
		cf_push('begin')
	end,
	['until'] = function()
		comp_assert(cf_pop() == 'begin', "UNTIL without matching BEGIN")
		local target = cf_pop()
		list_line("?branch %04x", target)
		emit_short(CBRANCH)
		emit_short(target - here() - 1)
	end,
	again = function()
		comp_assert(cf_pop() == 'begin', "AGAIN without matching BEGIN")
		local target = cf_pop()
		list_line("branch %04x", target)
		emit_short(BRANCH)
		emit_short(target - here() - 1)
	end,
	['do'] = function()
		list_line("do")
		emit_short(DO)
		cf_push(here())
		cf_push('do')
	end,
	loop = function()
		comp_assert(cf_pop() == 'do', "LOOP without matching DO")
		local target = cf_pop()
		list_line("loop %04x", target)
		emit_short(LOOP)
		emit_short(target - here() - 1)		
	end,
	['+loop'] = function()
		comp_assert(cf_pop() == 'do', "+LOOP without matching DO")
		local target = cf_pop()
		list_line("+loop %04x", target)
		emit_short(PLUS_LOOP)
		emit_short(target - here() - 1)		
	end,
	['while'] = function() comp_error("WHILE not implemented") end,
	['repeat'] = function() comp_error("REPEAT not implemented") end,
	['goto'] = function()
		local label = next_symbol()
		list_line("branch %s", label)	-- TODO: patch jump
		emit_short(BRANCH)
		local addr = here()
		emit_short(0)	-- place holder branch offset
		gotos[addr] = label
	end,
	label = function()
		local label = next_symbol()
		labels[label] = here()
	end,
	exit = function()
		list_line("exit")
		emit_short(rom_words.EXIT)
		word_flags[last_word] = word_flags[last_word] | F_HAS_SIDE_EXITS
	end,
	ascii = function()
		local char = next_symbol()
		if #char ~= 1 then comp_error("invalid symbol following ASCII") end
		emit_literal(char:byte(1))
	end,
	lit = function() emit_literal(pop()) end,
	postpone = function()
		local name = next_word()
		if compile_dict[name] == nil then comp_error("undefined word %s", name) end
		list_line("postpone")
		emit_short(POSTPONE)
		list_comment("%s", name)
		emit_short(#name)
		emit_string(name)
	end,
	['r@'] = function()
		-- R@ is alias for I
		list_line("r@")
		emit_short(rom_words.I)
	end,
	['not'] = function()
		-- NOT is alias for 0=
		list_line("not")
		emit_short(rom_words['0='])
	end,
}

mcode_dict = mcode.get_dict()

-- the following words have identical interpreter, compile and mcode behaviors
for _, name in ipairs{ "(", "\\", "[if]", "[else]", "[then]", "[defined]" } do
	local func = assert(interpret_dict[name])
	compile_dict[name] = func
	mcode_dict[name] = func
end

-- insert built-in ROM words into compilation dict
for name, addr in pairs(rom_words) do
	name = string.lower(name)
	compile_dict[name] = compile_dict[name] or function()
		list_line(name)
		emit_short(addr)
	end

	compilation_addr_to_name[addr] = name
end

-- emit header for the main word enclosing the whole machine code program
if opts.mcode then
	-- write name to dictionary, with terminator bit set for the last character
	local name = string.upper(opts.main_word)
	list_header("main word header")
	emit_string(name:sub(1, #name - 1) .. string.char(name:byte(#name) | 128))
	emit_short(0) -- placeholder word length
	emit_short(prev_word_link)
	prev_word_link = here()
	emit_byte(#name)
	emit_short(0)	-- placeholder code field
end

if opts.mcode then
	mcode.emit_subroutines()
end

local library_words = [[
1 const TRUE
0 const FALSE
32 const BL
9985 const PAD

: 2dup over over ;
: 2drop drop drop ;
: 2over 4 pick 4 pick ;
: nip swap drop ;
: 2* dup + ;
: 2/ 2 / ;
: hex 16 base c! ;
: .s 15419 @ here 12 + over over - if do i @ . 2 +loop else drop drop then ;

: c* 255 and swap 255 and * ;
: c= - 255 and 0= ;

code di 243 c, 253 c, 233 c, 
code ei 251 c, 253 c, 233 c,
]]

-- Compile library words which are not natively available on Jupiter Ace's ROM.
-- These are added at the beginning of every program, but they may be dead code eliminated.
-- Note that behaviors for some of these words may already exist and it's important
-- that we don't overwrite for example the optimized machine code implementations.
-- We prevent that by setting this ugly flag here...
dont_allow_redefining = true
execute_string(library_words, "<library>")
dont_allow_redefining = false

-- convert all words to uppercase if we're in case insensitive mode
if opts.ignore_case then
	local function to_upper_case(dict)
		local t = {}
		for name, func in pairs(dict) do
			t[string.upper(name)] = func
		end
		return t
	end

	interpret_dict = to_upper_case(interpret_dict)
	compile_dict = to_upper_case(compile_dict)
	mcode_dict = to_upper_case(mcode_dict)
end

-- compile all files
for _, filename in ipairs(input_files) do
	-- load input file
	local file, err = io.open(filename, "r")
	if file == nil then fatal_error(err) end
	local src = file:read("a")
	file:close()

	-- execute it!
	execute_string(src, filename)
end

-- patch code field for main word
if opts.mcode then
	local addr = compilation_addresses[opts.main_word]
	assert(addr, "could not find compilation address of main word")
	write_short(prev_word_link + 1, addr)
end

update_word_length()

local more_work = false

-- eliminate unused words
if opts.eliminate_unused_words then
	-- mark unused words for next pass
	for name in pairs(compilation_addresses) do
		if word_counts[name] == 0 and name ~= opts.main_word and (word_flags[name] & F_NO_ELIMINATE) == 0 then
			if opts.verbose then print("Eliminating unused word: " .. name) end
			eliminate_words[name] = true
			more_work = true
		end
	end
end

-- inline words that are used only once and have no side exits
if opts.inline_words then
	for name, compilation_addr in pairs(compilation_addresses) do
		if word_counts[name] == 1 and (word_flags[name] & F_NO_INLINE) == 0 then
			-- check that it's a colon definition
			if read_short(compilation_addr) == DO_COLON then
				-- check for side exits
				if (word_flags[name] & F_HAS_SIDE_EXITS) == 0 then
					if opts.verbose then print("Inlining word: " .. name) end
					inline_words[name] = true
					more_work = true
				else
					warn("Word '%s' has side exits and cannot be inlined", name)
				end
			end
		end
	end
end

-- run another pass if we could optimize something
if more_work then
	pass = pass + 1
	assert(pass < 10, "exceeded maximum number of compilation passes (compiler got stuck?)")
	goto restart
end

-- print warnings
for _, msg in ipairs(warnings) do
	print(msg)
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
	local filename = opts.tap_filename .. string.rep(" ", 10 - #opts.tap_filename)
	local header = "\26\0\0" ..
		filename ..
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

-- write listing file
if opts.listing_file then
	write_listing(opts.listing_file)
end