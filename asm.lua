-- Z80A vocabulary

asm_vocabulary = {
	LD_A = function()
		emit_byte(62)
		emit_byte(next_number())
	end,
	RST = function()
		local vec = next_number()
		assert(vec >= 0 and vec <= 0x38 and (vec & 7) == 0, "invalid vector for RST")
		emit_byte(0xc7 + vec)
	end,
	["JP_(IY)"] = function()
		emit_byte(253)
		emit_byte(233)
	end,
}

return asm_vocabulary