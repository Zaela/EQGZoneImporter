
local mat_list = iup.list{visiblecolumns = 12, visiblelines = 15, expand = "VERTICAL"}
local prop_list = iup.list{visiblecolumns = 12, visiblelines = 15, expand = "VERTICAL"}
local data, material, property

local ClearFields, fields, shader

local function PackColors(str)
	local n = 0
	for v in str:gmatch("%d+") do
		local val = tonumber(v)
		if val > 255 then val = 255 end
		n = n * 256
		n = n + val
	end
	return n
end

local function Edited()
	if property then
		property.name = fields.prop_name.value
		if property.type == 3 then
			property.value = PackColors(fields.prop_value.value)
		else
			property.value = fields.prop_value.value
		end
	end
	if material then
		material.shader = shader.value
	end
end

shader = iup.list{visiblecolumns = 14, --[[valuechanged_cb = Edited,]] dropdown = "YES", editbox = "YES", visible_items = 15,
	"OpaqueMPLBasic.fx", "OpaqueMPLBump.fx", "OpaqueCBSGE1.fx", "OpaqueCBGG1.fx", "OpaqueCBSG1.fx", "OpaqueCBS1.fx",
	"OpaqueCB1.fx", "OpaqueCE1.fx", "AlphaMPLBasic.fx", "AlphaMPLBlendNoBump.fx", "AlphaMPLBlend.fx", "AlphaMPLFull2UV.fx",
	"AlphaMPLFull.fx", "AlphaMPLBump2UV.fx", "AlphaMPLBump.fx", "AlphaMPLSB2UV.fx", "AlphaMPLSB.fx", "AlphaMPLGB2UV.fx",
	"AlphaMPLGB.fx", "AlphaMPLRB2UV.fx", "AlphaMPLRB.fx", "AlphaC1DTP.fx", "AlphaCBSG1_2UV.fx", "AlphaCBST2_2UV.fx",
	"AlphaCB1_2UV.fx", "AlphaC1_2UV.fx", "AlphaCBGGE1.fx", "AlphaCBSGE1.fx", "AlphaCBSE1.fx", "AlphaCBE1.fx",
	"AlphaCBGG1.fx", "AlphaCBSG1.fx", "AlphaVSB.fx", "AlphaCBS1.fx", "AlphaCBS_2UV.fx", "AlphaCB1.fx", "AlphaCE1.fx",
	"AlphaCG1.fx", "ChromaMPLBasic.fx", "ChromaCBSGE1.fx", "ChromaCBGG1.fx", "ChromaCBSG1.fx", "ChromaVSB.fx",
	"ChromaCBS1.fx", "ChromaCB1.fx", "ChromaCE1.fx", "ChromaCG1.fx", "AddAlphaCBSGE1.fx", "AddAlphaCBGG1.fx",
	"AddAlphaCBSG1.fx", "AddAlphaCBS1.fx", "AddAlphaCB1.fx", "AddAlphaCE1.fx", "AddAlphaCG1.fx", "WaterFall.fx",
	"Water.fx", "Terrain.fx", "Lava.fx", "Lava2.fx",
	valuechanged_cb = function()
		--for some dumb reason this does't get the updated values like it does for everything else
		iup.SetIdle(function()
			Edited()
			iup.SetIdle(nil)
		end)
	end,
}

function mat_list:action(str, pos, state)
	if state == 1 and data then
		material = data[pos]
		prop_list[1] = nil
		prop_list.autoredraw = "NO"
		for i, prop in ipairs(material) do
			prop_list[i] = prop.name
		end
		prop_list.autoredraw = "YES"
		ClearFields()
		shader.value = material.shader
	end
end

local function ExtractColors(col)
	col = tonumber(col)
	local str = {}
	if col then
		for i = 4, 1, -1 do
			local v = col % 256
			str[i] = v
			col = math.floor(col / 256)
		end
	end
	return table.concat(str, " ")
end

function prop_list:action(str, pos, state)
	if state == 1 and material then
		property = material[pos]
		fields.prop_name.value = property.name
		fields.prop_type.value = property.type
		fields.prop_value.value = property.value
		local t = property.type
		if t == 0 then
			fields.prop_value.mask = iup.MASK_FLOAT
		elseif t == 3 then
			fields.prop_value.value = ExtractColors(property.value)
			fields.prop_value.mask = "/d+/s/d+/s/d+/s/d+"
		else
			fields.prop_value.mask = nil
		end
	end
end

fields = {
	prop_name = iup.text{visiblecolumns = 16, valuechanged_cb = Edited},
	prop_type = iup.text{visiblecolumns = 16, readonly = "YES"},
	prop_value = iup.text{visiblecolumns = 16, valuechanged_cb = Edited},
}

local grid = iup.gridbox{
	iup.label{title = "Name"}, fields.prop_name,
	iup.label{title = "Type"}, fields.prop_type,
	iup.label{title = "Value"}, fields.prop_value,
	numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 2
}

function ClearFields()
	for _, field in pairs(fields) do
		field.value = ""
	end
	shader.value = ""
end

local function read(ter_data)
	ClearFields()
	data = ter_data.materials
	mat_list.autoredraw = "NO"
	mat_list[1] = nil
	for i, mat in ipairs(ter_data.materials) do
		mat_list[i] = mat.name
	end
	mat_list.autoredraw = "YES"
end

local prop_options = {
	e_TextureDiffuse0 = 2,
	e_TextureNormal0 = 2,
	e_TextureCoverage0 = 2,
	e_TextureEnvironment0 = 2,
	e_TextureGlow0 = 2,
	e_fShininess0 = 0,
	e_fBumpiness0 = 0,
	e_fEnvMapStrength0 = 0,
	e_fFresnelBias = 0,
	e_fFresnelPower = 0,
	e_fWaterColor1 = 3,
	e_fWaterColor2 = 3,
	e_fReflectionAmount = 0,
	e_fReflectionColor = 3,
}

local function AddProperty()
	if not material then return end
	local list = iup.list{dropdown = "YES", visiblecolumns = 16}
	local opt = {}
	for o in pairs(prop_options) do
		opt[o] = true
	end
	for _, p in ipairs(material) do
		opt[p.name] = nil
	end

	local n = 1
	for o in pairs(opt) do
		list[n] = o
		n = n + 1
	end

	local dlg
	local enter = function(self, key) if key == iup.K_CR then dlg:hide() end end
	list.k_any = enter
	local but = iup.button{title = "Add", action = function() dlg:hide() end}
	local cancel = iup.button{title = "Cancel", action = function() list.value = -1 dlg:hide() end}
	dlg = iup.dialog{iup.vbox{
		iup.label{title = "Select a property to add:"},
		list, iup.hbox{but, cancel; gap = 10, alignment = "ACENTER"},
		gap = 12, nmargin = "50x25", alignment = "ACENTER"}, k_any = enter}
	iup.Popup(dlg)

	if list.value ~= -1 then
		local str = list[list.value]
		local t = prop_options[str]
		table.insert(material, {name = str, type = t, value = (t ~= 2) and 0 or ""})
		prop_list[prop_list.count + 1] = str
	end

	iup.Destroy(dlg)
end

local function DeleteProperty()
	if not material or not property then return end
	for i, p in ipairs(material) do
		if p == property then
			table.remove(material, i)
			prop_list.autoredraw = "NO"
			prop_list[1] = nil
			for i, prop in ipairs(material) do
				prop_list[i] = prop.name
			end
			prop_list.autoredraw = "YES"
			ClearFields()
			property = nil
			return
		end
	end
end

function prop_list:button_cb(button, pressed, x, y)
	if data and button == iup.BUTTON3 and pressed == 0 then
		local mx, my = iup.GetGlobal("CURSORPOS"):match("(%d+)x(%d+)")
		local menu = iup.menu{
			iup.item{title = "Add Property", action = AddProperty},
			iup.item{title = "Remove Property", action = DeleteProperty, active = property and "YES" or "NO"},
		}
		iup.Popup(menu, mx, my)
		iup.Destroy(menu)
	end
end

return {
	name = "Materials",
	display = iup.hbox{iup.frame{title = "Materials", mat_list}, iup.frame{title = "Properties", prop_list},
		iup.vbox{iup.frame{title = "Property Values", iup.vbox{grid, nmargin = "10x10"}},
		iup.frame{title = "Material Shader", iup.vbox{shader, nmargin = "10x10"}}, gap = 10}; nmargin = "10x10", gap = 10},
	read = read,
}
