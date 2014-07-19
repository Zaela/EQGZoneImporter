
local toggle_names = {
	[1] = "Permeable",
}

local toggles = {}
toggles.__index = toggles

function toggles.new(valuechanged_cb)
	local toggle_grid = iup.gridbox{
		numdiv = 8, orientation = "HORIZONTAL", homogeneouslin = "YES",
		gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
	}

	local tog = {}

	for i = 1, 32 do
		local t = iup.toggle{value = "OFF", valuechanged_cb = valuechanged_cb}
		tog[i] = t
		iup.Append(toggle_grid, iup.label{title = toggle_names[i] or ("Bit".. i)})
		iup.Append(toggle_grid, t)
	end

	return setmetatable({grid = toggle_grid, raw = tog}, toggles)
end

function toggles:GetBinaryValue()
	local t = self.raw

	local n = 0
	for i = 32, 1, -1 do
		n = n * 2
		if t[i].value == "ON" then
			n = n + 1
		end
	end

	return n
end

function toggles:SetBinaryValue(n)
	local t = self.raw
	for i = 1, 32 do
		t[i].value = (n % 2 == 1) and "ON" or "OFF"
		n = math.floor(n / 2)
	end
end

function toggles:Clear()
	local t = self.raw
	for i = 1, 32 do
		t[i].value = "OFF"
	end
end

return toggles
