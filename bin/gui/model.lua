
local eqg = require "luaeqg"
local obj = require "gui/obj"

local model_list = iup.list{visiblecolumns = 12, visiblelines = 15, expand = "VERTICAL"}
local obj_list = iup.list{visiblecolumns = 12, visiblelines = 15, expand = "VERTICAL"}
local name_data, obj_data, object, def_list, fields, active_pos, model_pos
local tonumber = tonumber

function obj_list:action(str, pos, state)
	if state == 1 and obj_data then
		active_pos = pos
		object = obj_data[pos]
		for k, field in pairs(fields) do
			field.value = object[k]
		end
		def_list.value = object.id + 1
	end
end

function model_list:action(str, pos, state)
	if state == 1 and name_data then
		model_pos = pos
	end
end

local function Edited()
	if object then
		for k, field in pairs(fields) do
			object[k] = (k == "name") and field.value or tonumber(field.value) or 0
		end
		if active_pos then
			obj_list[active_pos] = object.name or ""
		end
	end
end

def_list = iup.list{visiblecolumns = 14, dropdown = "YES", visible_items = 20}

function def_list:action(str, pos, state)
	if state == 1 and object then
		object.id = pos - 1
	end
end

fields = {
	name = iup.text{visiblecolumns = 16, valuechanged_cb = Edited},
	x = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	y = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	z = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	rotation_x = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	rotation_y = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	rotation_z = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
	scale = iup.text{visiblecolumns = 16, mask = iup.MASK_FLOAT, valuechanged_cb = Edited},
}

local grid = iup.gridbox{
	iup.label{title = "Model Def"}, def_list,
	iup.label{title = "Name"}, fields.name,
	iup.label{title = "X"}, fields.x,
	iup.label{title = "Y"}, fields.y,
	iup.label{title = "Z"}, fields.z,
	iup.label{title = "Rotate X"}, fields.rotation_x,
	iup.label{title = "Rotate Y"}, fields.rotation_y,
	iup.label{title = "Rotate Z"}, fields.rotation_z,
	iup.label{title = "Scale"}, fields.scale,
	numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

local function ClearFields()
	for _, field in pairs(fields) do
		field.value = ""
	end
end

--[[
	Model definitions are expected to be in a certain order; model placements
	reference them by array index. However, we also want to include model
	defintions that are in the EQG but have no placements (newly imported, etc)
	so we need to mix the two lists.
]]

local function read(ter_data, zon_data)
	active_pos = nil
	model_pos = nil
	local dir = open_dir
	local names = {}
	local found = {}
	for i, name in ipairs(zon_data.models) do
		name = name:lower()
		names[i] = name
		found[name] = true
	end

	for i, ent in ipairs(dir) do
		local name = ent.name
		if name:find("%.mod$") and not found[name] then
			table.insert(names, name)
		end
	end
	name_data = names
	zon_data.models = names

	model_list.autoredraw = "NO"
	model_list[1] = nil
	def_list[1] = nil
	for i, name in ipairs(names) do
		model_list[i] = name
		def_list[i] = name
	end
	model_list.autoredraw = "YES"

	obj_data = zon_data.objects
	obj_list.autoredraw = "NO"
	obj_list[1] = nil
	for i, obj in ipairs(zon_data.objects) do
		obj_list[i] = obj.name
	end
	obj_list.autoredraw = "YES"
	ClearFields()
end

local function AddPlacement()
	if obj_data and tonumber(def_list.count) > 0 then
		table.insert(obj_data, {
			name = "Unnamed",
			x = 0, y = 0, z = 0,
			rotation_x = 0, rotation_y = 0, rotation_z = 0,
			scale = 1, id = 0
		})
		obj_list[tonumber(obj_list.count) + 1] = "Unnamed"
	end
end

local function DeletePlacement()
	if obj_data and active_pos then
		table.remove(obj_data, active_pos)
		obj_list.autoredraw = "NO"
		obj_list[1] = nil
		for i, obj in ipairs(obj_data) do
			obj_list[i] = obj.name
		end
		obj_list.autoredraw = "YES"
		ClearFields()
		active_pos = nil
		object = nil
	end
end

function obj_list:button_cb(button, pressed, x, y)
	if obj_data and button == iup.BUTTON3 and pressed == 0 then
		local mx, my = iup.GetGlobal("CURSORPOS"):match("(%d+)x(%d+)")
		local menu = iup.menu{
			iup.item{title = "Add Placement", action = AddPlacement, active = obj_data and (tonumber(def_list.count) > 0) and "YES" or "NO"},
			iup.item{title = "Remove Placement", action = DeletePlacement, active = active_pos and "YES" or "NO"},
		}
		iup.Popup(menu, mx, my)
		iup.Destroy(menu)
	end
end

local function ImportModel()
	local dlg = iup.filedlg{title = "Select OBJ file to import", dialogtype = "FILE",
		extfilter = "Wavefront OBJ (*.obj)|*.obj|"}
	iup.Popup(dlg)
	if dlg.status == "0" then
		local path = dlg.value
		local dir = open_dir
		if path and dir then
			local name = path:match("([^\\/]+)%.obj$")
			name = name:lower()
			local modname = name .. ".mod"
			--check if the name is already in use
			local pos, overwrite
			for i, ent in ipairs(dir) do
				if modname == ent.name then
					local warn = iup.messagedlg{title = "Overwrite?",
						value = "A model named '".. name .."' already exists in this archive. Overwrite it?",
						buttons = "YESNO", dialogtype = "WARNING"}
					iup.Popup(warn)
					local yes = (warn.buttonresponse == "1")
					iup.Destroy(warn)
					if not yes then iup.Destroy(dlg) return end
					pos = i
					overwrite = true
					break
				end
			end
			if not pos then
				pos = #dir + 1
			end
			local data = obj.Import(path, dir, (pos > #dir))
			data.bones = {}
			data.bone_assignments = {}
			local s, err = pcall(mod.Write, data, modname, eqg.CalcCRC(modname))
			if s then
				dir[pos] = err
				s, err = pcall(eqg.WriteDirectory, open_path, dir)
				if s then
					local msg = iup.messagedlg{title = "Import Status", value = "Import of '".. name .."' complete."}
					iup.Popup(msg)
					iup.Destroy(msg)
					iup.Destroy(dlg)
					if not overwrite then
						model_list[tonumber(model_list.count) + 1] = modname
						def_list[tonumber(def_list.count) + 1] = modname
						table.insert(name_data, modname)
					end
					return
				end
			end
			error_popup(err)
		end
	end
	iup.Destroy(dlg)
end

local function DeleteModel()
	local dir = open_dir
	if not name_data or not model_pos or not active_zon or not dir then return end
	local name = name_data[model_pos]
	table.remove(name_data, model_pos)

	for i, ent in ipairs(dir) do
		if ent.name == name then
			table.remove(dir, i)
			break
		end
	end

	model_list.autoredraw = "NO"
	def_list.autoredraw = "NO"
	model_list[1] = nil
	def_list[1] = nil
	for i, name in ipairs(name_data) do
		model_list[i] = name
		def_list[i] = name
	end
	model_list.autoredraw = "YES"
	def_list.autoredraw = "YES"

	--need to remove any placements associated with this model
	local id = model_pos - 1
	local out = {}
	for i, obj in ipairs(active_zon.objects) do
		local o = obj.id
		if o > id then
			obj.id = o - 1
		end
		if o ~= id then
			table.insert(out, obj)
		end
	end

	obj_list.autoredraw = "NO"
	obj_list[1] = nil
	for i, obj in ipairs(out) do
		obj_list[i] = obj.name
	end
	obj_list.autoredraw = "YES"

	active_zon.objects = out
	obj_data = out

	ClearFields()
	active_pos = nil
	model_pos = nil
	object = nil
end

function model_list:button_cb(button, pressed, x, y)
	if open_dir and button == iup.BUTTON3 and pressed == 0 then
		local mx, my = iup.GetGlobal("CURSORPOS"):match("(%d+)x(%d+)")
		local menu = iup.menu{
			iup.item{title = "Import Model", action = ImportModel},
			iup.item{title = "Remove Model", action = DeleteModel, active = model_pos and "YES" or "NO"},
		}
		iup.Popup(menu, mx, my)
		iup.Destroy(menu)
	end
end

return {
	name = "Models",
	display = iup.hbox{iup.frame{title = "Definitions", model_list}, iup.frame{title = "Placements", obj_list},
		iup.frame{title = "Placement Data", iup.vbox{grid; nmargin = "10x10"}}; nmargin = "10x10", gap = 10},
	read = read,
}
