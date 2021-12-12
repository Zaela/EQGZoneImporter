
local lfs = require "lfs"
local eqg = require "luaeqg"
local obj = require "gui/obj"
require "gui/loader"

function assert(result, msg)
	if result then return result end
	io.stdout:write(msg .. "\n")
	io.flush()
end

function error_popup(msg)
	io.stdout:write(msg .. "\n")
	io.flush()
end

function log_write(...)
	io.stdout:write(... .. "\n")
	io.flush()
end

function obj_import(eqg_path, obj_path)
	local shortname = eqg_path:match("([%s%w_]+)%.eqg$")
	if not shortname then return end
	shortname = shortname:lower()

	local s, dir = pcall(eqg.LoadDirectory, eqg_path)
	if not s then
		error(dir)
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


	log_write("Attempting to save '" .. ter_name .. "' and '" .. zon_name .. "' to " .. eqg_path)

	local s, data = pcall(ter.Write, ter_data, ter_name, eqg.CalcCRC(ter_name))
	if s then
		dir[GetDirPos(ter_name)] = data
	else
		error("Error writing '" .. ter_name .. "': " .. data)
	end

	s, data = pcall(zon.Write, zon_data, zon_name, eqg.CalcCRC(zon_name))
	if s then
		dir[GetDirPos(zon_name)] = data
	else
		error("Error writing '" .. zon_name, "': " .. data)
	end

	s, data = pcall(eqg.WriteDirectory, eqg_path, dir)
	if not s then
		error("Error writing to active EQG directory: " .. data)
	end

	log_write("Saved successfully")
end

function main_cmd(arg1, arg2, arg3)
	io.stdout:write("Executing eqgzi")

	local args = ""
	if arg1 and string.len(arg1) then
		io.stdout:write(" " .. arg1)
		args = arg1
	end

	if arg2 and string.len(arg2) then
		io.stdout:write(" " .. arg2)
		args = args .. " " .. arg2
	end

	if arg3 and string.len(arg3) then
		io.stdout:write(" " .. arg3)
		args = args .. " " .. arg3
	end
	
	io.stdout:write("\n")

	local cmdType = ""
	local eqg_path = ""
	local obj_path = ""

	for cmd in string.gmatch(args, "%S+") do
		if cmd:lower() == "import" then
			cmdType = "import"
		end
		if string.find(cmd:lower(), ".eqg$") then
			log_write("EQG Path set to " .. cmd)
			eqg_path = cmd
		end	
		if string.find(cmd:lower(), ".obj$") then
			log_write("OBJ Path set to " .. cmd)
			obj_path = cmd
		end	
	end

	if cmdType == "import" then

		if eqg_path == "" then
			log_write("missing eqg path")
			log_write("usage: eqgzi import \".eqg\" \".obj\"")
			return
		end

		if obj_path == "" then
			log_write("missing obj path")
			log_write("usage: eqgzi import \".eqg\" \".obj\"")
			return
		end

		obj_import(eqg_path, obj_path)
	end

	log_write("usage: eqgzi [import \".eqg\" \".obj\"]")
end
