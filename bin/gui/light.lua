
local list = iup.list{visiblecolumns = 12, visiblelines = 15, expand = "VERTICAL"}
local data, light, fields, active_pos
local tonumber = tonumber

function list:action(str, pos, state)
	if state == 1 and data then
		active_pos = pos
		light = data[pos]
		for k, field in pairs(fields) do
			field.value = light[k]
		end
	end
end

local function Edited()
	if light then
		for k, field in pairs(fields) do
			light[k] = (k == "name") and field.value or tonumber(field.value)
		end
		if active_pos then
			list[active_pos] = fields.name.value or ""
		end
	end
end

fields = {
	name = iup.text{visiblecolumns = 16, valuechanged_cb = Edited},
	x = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	y = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	z = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	r = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	g = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	b = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	radius = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
}

local grid = iup.gridbox{
	iup.label{title = "Name"}, fields.name,
	iup.label{title = "X"}, fields.x,
	iup.label{title = "Y"}, fields.y,
	iup.label{title = "Z"}, fields.z,
	iup.label{title = "Red"}, fields.r,
	iup.label{title = "Green"}, fields.g,
	iup.label{title = "Blue"}, fields.b,
	iup.label{title = "Radius"}, fields.radius,
	numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 7
}

local function ClearFields()
	for _, field in pairs(fields) do
		field.value = ""
	end
end

local function read(ter_data, zon_data)
	active_pos = nil
	data = zon_data.lights
	list.autoredraw = "NO"
	list[1] = nil
	for i, lit in ipairs(zon_data.lights) do
		list[i] = lit.name
	end
	list.autoredraw = "YES"
	ClearFields()
end

local function AddLight()
	if data then
		table.insert(data, {
			name = "Unnamed",
			x = 0, y = 0, z = 0,
			r = 1, g = 1, b = 1,
			radius = 10
		})
		list[tonumber(list.count) + 1] = "Unnamed"
	end
end

local function CopyLight()
	if data and light then
		local new = {}
		for k, v in pairs(light) do
			new[k] = v
		end
		table.insert(data, new)
		list[tonumber(list.count) + 1] = new.name or "Unnamed"
	end
end

local function DeleteLight()
	if data and active_pos then
		table.remove(data, active_pos)
		list.autoredraw = "NO"
		list[1] = nil
		for i, lit in ipairs(data) do
			list[i] = lit.name
		end
		list.autoredraw = "YES"
		ClearFields()
		active_pos = nil
		light = nil
	end
end

function list:button_cb(button, pressed, x, y)
	if data and button == iup.BUTTON3 and pressed == 0 then
		local mx, my = iup.GetGlobal("CURSORPOS"):match("(%d+)x(%d+)")
		local menu = iup.menu{
			iup.item{title = "Add Light", action = AddLight},
			iup.item{title = "Copy Light", action = CopyLight, active = light and "YES" or "NO"},
			iup.separator{},
			iup.item{title = "Remove Light", action = DeleteLight, active = active_pos and "YES" or "NO"},
		}
		iup.Popup(menu, mx, my)
		iup.Destroy(menu)
	end
end

return {
	name = "Lights",
	display = iup.hbox{list, grid; nmargin = "10x10", gap = 10},
	read = read,
}
