
local eqg = require "luaeqg"
local obj = require "gui/obj"

local path_text = iup.text{visiblecolumns = 32}
local source_text = iup.text{visiblecolumns = 32}

local path_button = iup.button{title = "Search", padding = "10x0"}
local source_button = iup.button{title = "Search", padding = "10x0"}
local import_button = iup.button{title = "Import", padding = "30x10"}

local function read(ter_data, zon_data, zone_name, path)
	path_text.value = path
end

local grid = iup.gridbox{
	iup.label{title = "Import to:"}, path_text, path_button,
	iup.label{title = "Source:"}, source_text, source_button,
	numdiv = 3, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

local function FileSearch(text, filter, field)
	local dlg = iup.filedlg{title = text, dialogtype = "FILE", extfilter = filter}
	iup.Popup(dlg)
	if dlg.status == "0" then
		field.value = dlg.value
	end
	iup.Destroy(dlg)
end

function path_button:action()
	FileSearch("Select EQG File", "EQG Files (*.eqg)|*.eqg|", path_text)
end

function source_button:action()
	FileSearch("Select OBJ File", "Wavefront OBJ (*.obj)|*.obj|", source_text)
end

function import_button:action()
	local eqg_path = path_text.value
	local obj_path = source_text.value
	if eqg_path:len() < 2 or obj_path:len() < 2 then return end

	local shortname = eqg_path:match("([%s%w_]+)%.eqg$")
	if not shortname then return end
	shortname = shortname:lower()

	eqg.CloseDirectory(open_dir)
	local s, dir = pcall(eqg.LoadDirectory, eqg_path)
	if not s then
		return error_popup(dir)
	end
	open_path = eqg_path
	open_dir = dir
	local pos, ter_name, zon_pos
	for i, ent in ipairs(dir) do
		local name = ent.name
		local ext = name:match("%.(%w+)$")
		if ext == "ter" then
			ter_name = name
			pos = i
		elseif ext == "zon" then
			zon_pos = i
		end
	end
	if not pos then
		ter_name = shortname .. ".ter"
		pos = #dir + 1
	end

	if pos < #dir then
		--delete .ter file's matching .lit file, if any
		local lit = ter_name:sub(1, -4) .. "lit"
		for i, ent in ipairs(dir) do
			if ent.name == lit then
				table.remove(dir, i)
				if pos > i then
					pos = pos - 1
				end
			end
		end
	end

	DirNames(dir)

	dir[pos] = {pos = pos, name = ter_name}
	local ter_data = obj.Import(obj_path, dir, (pos > #dir), shortname)
	local zon_data = {
		models = {ter_name},
		objects = {{name = ter_name:sub(1, -5), id = 0, x = 0, y = 0, z = 0, rotation_x = 0, rotation_y = 0, rotation_z = 0, scale = 1}},
		regions = {},
		lights = {},
	}

	local zon_name = shortname .. ".zon"

	DirNames(dir)

	active_ter_name = ter_name
	active_zon_name = zon_name

	LoadFromImport(ter_data, zon_data, shortname, eqg_path)
	if Save(true) then
		local msg = iup.messagedlg{title = "Success!", value = "Import to ".. shortname ..".eqg succeeded!"}
		iup.Popup(msg)
		iup.Destroy(msg)
	end
end

return {
	name = "Import",
	display = iup.vbox{grid, import_button; nmargin = "10x10", gap = 40, alignment = "ACENTER"},
	read = read,
}
