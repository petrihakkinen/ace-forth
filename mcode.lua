-- Machine code compile dictionary

MCODE_END = 0xe9fd		-- jp (iy)

local dict = {
	drop = function()
		emit_byte(0xdf)	-- rst 24
	end
}

return dict