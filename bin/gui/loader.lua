
local lfs = require "lfs"
local eqg = require "luaeqg"

local by_name

function DirNames(dir)
	by_name = {}
	for i, ent in ipairs(dir) do
		ent.pos = i
		by_name[ent.name] = ent
	end
end

function GetDirPos(name)
	local dir = open_dir
	local pos = by_name[name]
	if pos then
		return pos.pos
	end
	return #dir + 1
end

function LoadZone(eqg_path)
	log_write("Loading zone EQG from '", eqg_path, "'")
	local s, data = pcall(eqg.LoadDirectory, eqg_path)
	if not s then
		log_write "Could not open zone EQG"
		return error_popup(data)
	end
	open_dir = data
	by_name = {}
	local ter_file, zon_file, ter_data, zon_data
	for i, ent in ipairs(data) do
		local name = ent.name
		local ext = name:match("%.(%w+)$")
		ent.pos = i
		by_name[name] = ent
		if ext then
			if ext == "ter" then
				ter_file = ent
			elseif ext == "zon" then
				zon_file = ent
			end
		end
	end

	local path, name, ext = eqg_path:match("^([:%s%w_\\/]+[\\/])([%s%w_]+)(%.%w+)$")
	if not ter_file then
		return error_popup("Could not find .ter file in '".. name .. ext .."'. Are you sure this is a zone EQG file?")
	end
	s, data = pcall(eqg.OpenEntry, ter_file)
	if s then
		s, data = pcall(ter.Read, ter_file)
		if s then
			ter_data = data
		end
	end
	if not ter_data then
		return error_popup(data)
	end

	if zon_file then
		s, data = pcall(eqg.OpenEntry, zon_file)
		if not s then
			return error_popup(data)
		end
	else
		name = name:lower()
		for str in lfs.dir(path) do
			str = str:lower()
			if str:find("%.zon$") then
				local n = str:match("^[^%.]+")
				if n == name then
					s, data = pcall(zon.EQGize, path .. str)
					if s then
						zon_file = data
						break
					else
						return error_popup(data)
					end
				end
			end
		end
	end

	if not zon_file then
		return error_popup("Could not find .zon file in '".. name .. ext .. "' or in the directory containing it.")
	end
	s, data = pcall(zon.Read, zon_file)
	if s then
		zon_data = data
	else
		return error_popup(data)
	end

	active_ter_name = ter_file.name
	active_zon_name = zon_file.name

	return ter_data, zon_data
end
