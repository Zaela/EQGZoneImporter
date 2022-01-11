
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
end

function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end


function dump(o)
	if type(o) == 'table' then
	   local s = '{ '
	   for k,v in pairs(o) do
		  if type(k) ~= 'number' then k = '"'..k..'"' end
		  s = s .. '['..k..'] = ' .. dump(v) .. ','
	   end
	   return s .. '} '
	else
	   return tostring(o)
	end
 end

function obj_import(eqg_path, obj_path)
	local shortname = eqg_path:match("([%s%w_]+)%.eqg$")
	if not shortname then return end
	shortname = shortname:lower()

	local s, dir = pcall(eqg.LoadDirectory, eqg_path)
	if not s then
		error("open eq path " .. eqg_path .. " failed: " .. dir)
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

	local lights = {}
	--table.insert(lights, {name = "test", x = 1, y = 2, z = 3, r = 1, g = 2, b = 3, radius = 3})

	local f = io.open(shortname .. "_light.txt", "rb")
	if f then		
		f:close()
		local lineNumber = 0
		for line in io.lines(shortname .. "_light.txt") do
			lineNumber = lineNumber + 1
			lines = Split(line, " ")			
			if not #lines == 8 then
				error("expected 8 entries, got " .. #lines)
			end
			table.insert(lights, {name = lines[1],
			x = lines[2], y = lines[3], z = lines[4],
			r = lines[5], g = lines[6], b = lines[7],
			radius = lines[8]})
		end
		log_write("Added " .. #lights .. " lights based on " .. shortname .. "_light.txt")
	end

	
	local regions = {}
	local f = io.open(shortname .. "_region.txt", "rb")
	if f then		
		f:close()
		local lineNumber = 0
		for line in io.lines(shortname .. "_region.txt") do
			lineNumber = lineNumber + 1
			lines = Split(line, " ")
			if not #lines == 10 then
				error("expected 10 entries, got " .. #lines)
			end
			-- log_write(#lines)
			
			table.insert(regions, {name = lines[1],
			center_x = lines[2], center_y = lines[3], center_z = lines[4],
			extent_x = lines[5], extent_y = lines[6], extent_z = lines[7],
			unknownA = lines[8], unknownB = lines[9], unknownC = lines[10],
		})
		end
		log_write("Added " .. #regions .. " regions based on " .. shortname .. "_region.txt")
	end

	local models = {ter_name}
	local objects = {{name = ter_name:sub(1, -5), id = 0, x = 0, y = 0, z = 0, rotation_x = 0, rotation_y = 0, rotation_z = 0, scale = 1}}

	local f = io.open(shortname .. "_mod.txt", "rb")
	if f then
		f:close()
		local lineNumber = 0
		for line in io.lines(shortname .. "_mod.txt") do
			lineNumber = lineNumber + 1
			lines = Split(line, " ")
			if not #lines == 9 then
				error("expected 9 entries, got " .. #lines)
			end
			
			local modelIndex = -1
			for i = 1, #models do
				if models[i] ==  lines[1] then
					modelIndex = i
				end
			end
			if modelIndex == -1 then
				modelIndex = #models
				local modelName = string.gsub(lines[1], ".obj", ".mod")
				table.insert(models, modelName)
				log_write("Inserted " .. lines[1] .. " as index " .. modelIndex)				
			end

			log_write("Found " .. lines[1] .. " as index " .. modelIndex)

			table.insert(objects, {name = lines[2],
				id = modelIndex,
				x = lines[3], y = lines[4], z = lines[5],
				rotation_x = lines[6], rotation_y = lines[7], rotation_z = lines[8],
				scale = lines[9],
			})
		end
		log_write("Added " .. #models .. " models, " .. #objects .. " objects based on " .. shortname .. "_mod.txt")
	end
	
	dir[pos] = {pos = pos, name = ter_name}
	local ter_data = obj.Import(obj_path, dir, (pos > #dir), shortname)
	local zon_data = {
		models = models,
		objects = objects,
		regions = regions,
		lights = lights,
	}

	local zon_name = shortname .. ".zon"


	log_write("Attempting to save '" .. ter_name .. "' to " .. eqg_path)

	local s, data = pcall(ter.Write, ter_data, ter_name, eqg.CalcCRC(ter_name))
	if s then
		dir[GetDirPos(ter_name)] = data
	else
		error("Error writing '" .. ter_name .. "': " .. data)
	end

	
	for i = 2, #models do
		local modelName = string.gsub(models[i], ".mod", "")
		log_write("Attempting to save '" .. modelName .. "' as '" .. modelName .. ".mod")
		
		local data = obj.Import(modelName .. ".obj", dir, (pos > #dir), shortname)
		data.bones = {}
		data.bone_assignments = {}
		local s, err = pcall(mod.Write, data, modelName .. ".mod", eqg.CalcCRC(modelName))
		if not s then
			error("mod write returned no result")
		end
		-- TODO: fix dir appending
		-- by_name[modelName .. ".mod"] = pos + 1
		-- dir[GetDirPos(modelName .. ".mod")] = data
	end

	
	
	log_write("Attempting to save '" .. zon_name .. "' to " .. eqg_path)

	s, data = pcall(zon.Write, zon_data, zon_name, eqg.CalcCRC(zon_name))
	if s then
		dir[GetDirPos(zon_name)] = data
	else
		error("Error writing '" .. zon_name, "': " .. data)
	end

	DirNames(dir)	

	s, data = pcall(eqg.WriteDirectory, eqg_path, dir)
	if not s then
		error("Error writing to " .. eqg_path .. ": " .. data)
	end

	log_write("Saved successfully to " .. eqg_path)
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
		return
	end

	log_write("usage: eqgzi [import \".eqg\" \".obj\"]")
end
