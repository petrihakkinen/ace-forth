#!tools/lua

-- dumps contents of a tap file

local args = {...}
local filename = args[1]

if filename == nil then
	print("Usage: dump_tap.lua <filename>")
	return
end

local file = assert(io.open(filename, "rb"))

function printf(...)
	print(string.format(...))
end

function fread_byte()
	return string.byte(file:read(1))
end

function fread_short()
	local lo = fread_byte()
	local hi = fread_byte()
	return lo | (hi << 8)
end

function compute_checksum(data)
	local sum = 0
	for i = 1, #data do
		sum = sum ~ data:byte(i)
	end
	return sum
end

function read_header()
	local header = {}
	header.header_length = fread_short()
	header.file_type = fread_byte()
	header.filename = file:read(10)
	header.file_length = fread_short()
	header.start_address = fread_short()
	header.link = fread_short()
	header.current = fread_short()
	header.context = fread_short()
	header.voc_link = fread_short()
	header.dict_data_end = fread_short()
	header.header_checksum = fread_byte()

	printf("Header:")
	printf("    Header length  %d", header.header_length)
	printf("    File type      %d", header.file_type)
	printf("    Filename       %s", header.filename)
	printf("    File length    %d", header.file_length)
	printf("    Start address  %04x", header.start_address)
	printf("    Link           %04x", header.link)
	printf("    Current        %04x", header.current)
	printf("    Context        %04x", header.context)
	printf("    Voc link       %04x", header.voc_link)
	printf("    Data end       %04x", header.dict_data_end)
	printf("    Checksum       %02x", header.header_checksum)
	print()

	return header
end

function dump_word(header, data, link)
	local function read_byte(addr)
		return data:byte(addr - header.start_address + 1)
	end

	local function read_short(addr)
		local lo = read_byte(addr)
		local hi = read_byte(addr + 1)
		return lo | (hi << 8)
	end

	local function read_name(addr, count)
		local str = ""
		for i = addr, addr + count - 1 do
			str = str .. string.char(read_byte(i) & 127)
		end
		return str
	end

	-- link points to the name length field
	local word_length = read_short(link - 4)
	local prev_word_link = read_short(link - 2)
	local name_length = read_byte(link)
	local name = read_name(link - 4 - name_length, name_length)
	local code_field = read_short(link + 1)

	local what = "???"
	if code_field == 0x0ec3 then what = "do colon" end
	if code_field == 0x0ff0 then what = "do param" end
	if code_field == 0x0ff5 then what = "do constant" end

	printf("Word           %s", name)
	printf("Word length    %d", word_length)
	printf("Code field     %04x (%s)", code_field, what)
	printf("Prev link      %04x", prev_word_link)
	print()

	if prev_word_link >= 0x3c51 then
		dump_word(header, data, prev_word_link)
	end
end

local header = read_header()

local data_size = fread_short()
printf("Data size      %d", data_size)

local data = file:read(data_size - 1)

local checksum = fread_byte()
printf("Data checksum  %02x  (computed checksum %02x)\n", checksum, compute_checksum(data))

dump_word(header, data, header.link)

file:close()
