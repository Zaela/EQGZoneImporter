
local lfs = require "lfs"
local eqg = require "luaeqg"

local obj = {}

local tonumber = tonumber
local insert = table.insert
local pcall = pcall

local function ReadMTL(path)
	log_write("Attempting to read MTL file from '" .. path .. "'")
	local f = assert(io.open(path, "r"))
	local out = {}
	local cur

	for line in f:lines() do
		local cmd, args = line:match("%s*(%S+)%s([^\n]+)")
		if cmd and args then
			cmd = cmd:lower()
			if cmd == "newmtl" then
				cur = {}
				out[args] = cur
				log_write("Found material '" .. args .. "'")
			elseif cmd == "map_kd" then
				local name = args:match("[%w_]+%.%w+")
				cur.diffuse_map = name
				log_write("Found diffuse map name '" .. name .. "'")
			elseif cmd == "map_bump" then
				local name = args:match("[%w_]+%.%w+")
				cur.e_TextureNormal0 = name
				log_write("Found normal map name '" .. name .. "'")
			end
		end
	end

	f:close()
	log_write "Finished reading MTL file"

	return out
end

local function WriteO(f, obj)
	f:write("\n", obj.name, " = {from = ", obj.from, ", to = ", obj.to)
	for i, v in ipairs(obj) do
		f:write(", ", v)
	end
	f:write("}")
end

function Split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function obj.Import(path, dir, appending, shortname)
	log_write("Starting IMPORT from OBJ format from path " .. path)
	local f = assert(io.open(path, "r"))
	local fstr = f:read("*a")
	f:seek("set")
	local line_count = 0
	for n in fstr:gmatch("\n") do
		line_count = line_count + 1
	end

	log_write("Found OBJ file with " .. line_count .. " lines at '" .. path .. "'")

	local materials = {}
	local vertices = {}
	local triangles = {}
	local vert_src = {}
	local uv_src = {}
	local norm_src = {}
	local vert_mem = {}
	local in_object, mat_src
	local mat_index = {}
	local cur_index

	local cur_obj
	local data_file = assert(io.open(util.ExeDir() .. "/data/".. shortname ..".lua", "w+"))

	local face = function(str)
		local a = vert_mem[str]
		if a then
			return a
		end
		local v, t, n = str:match("(%d+)/(%d*)/(%d+)")
		local vert = vert_src[tonumber(v)]
		local norm = norm_src[tonumber(n)]
		local out = {x = vert.x, y = vert.y, z = vert.z, i = norm.i, j = norm.j, k = norm.k}
		t = tonumber(t)
		if t then
			local tex = uv_src[t]
			out.u = tex.u
			out.v = tex.v
		end
		a = #vertices
		insert(vertices, out)
		vert_mem[str] = a
		return a
	end

	local progress = iup.progressdlg{count = 0, totalcount = line_count, description = "Importing model..."}
	if not util.IsConsole() then		
		progress:show()
	end

	local material_flags = {}
	local shortname = path:match("([%s%w_]+)%.obj$")
	local fm = io.open(shortname .. "_material.txt", "rb")
	if fm then
		fm:close()
		local lineNumber = 0
		for line in io.lines(shortname .. "_material.txt") do
			lineNumber = lineNumber + 1
			lines = Split(line, " ")
			if not lines[1]  == "m" and not lines[1] == "e" then
				error("failed to parse " .. shortname .. "_material.txt:" .. lineNumber .. " unknown definition " .. lines[1])
			end
			if lines[1] == "m" then
				if not #lines == 4 then
					error("failed to parse " .. shortname .. "_material.txt:" .. lineNumber .. " due to number of entries should be 4, got " .. #lines)
				end
				material_flags[lines[2]] = { flag = tonumber(lines[3]), shader = lines[4] }
			end
			if lines[1] == "e" then
				if not #lines == 5 and not #lines == 4 then
					error("failed to parse " .. shortname .. "_material.txt:" .. lineNumber .. " due to number of entries should be 4 or 5, got " .. #lines)
				end
				if #lines == 5 then
					material_flags[lines[2]][lines[3]] = lines[4] .. " " .. lines[5]
				end
				if #lines == 4 then
					material_flags[lines[2]][lines[3]] = lines[4]
				end
			end
		end
		log_write("Added " .. #material_flags .. " flags based on " .. shortname .. "_material.txt")
	end

	local last_material = { flag = 65536, shader = "Opaque_MaxCB1.fx"}
	for line in f:lines() do
		local cmd, args = line:match("%s*(%S+)%s([^\n]+)")
		if cmd and args then
			cmd = cmd:lower()
			if mat_src then
				if cmd == "v" then
					local x, y, z = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+) (%-?%d+%.%d+)")
					if x and y and z then
						insert(vert_src, {x = tonumber(x), y = tonumber(y), z = tonumber(z)})
					end
				elseif cmd == "vt" then
					local u, v = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+)")
					if u and v then
						insert(uv_src, {u = tonumber(u), v = tonumber(v)})
					end
				elseif cmd == "vn" then
					local i, j, k = args:match("(%-?%d+%.%d+) (%-?%d+%.%d+) (%-?%d+%.%d+)")
					if i and j and k then
						insert(norm_src, {i = tonumber(i), j = tonumber(j), k = tonumber(k)})
					end
				elseif cmd == "usemtl" then
					cur_index = mat_index[args]
					
					last_material = material_flags[args]
					if not last_material then
						last_material = { flag = 65536, shader = "Opaque_MaxCB1.fx"}
					end

					if not cur_index then
						cur_index = #materials
						mat_index[args] = cur_index
						local mat = mat_src[args]
						if mat then
							local tbl = {name = args, shader = last_material.shader}
							if mat.diffuse_map then
								local v = mat.diffuse_map:lower()
								tbl[1] = {name = "e_TextureDiffuse0", type = 2, value = v}
							end
							for key, value in pairs(last_material) do
								if string.sub(key, 1, 2) == "e_" then
									entries = Split(value, " ")
									if not #entries == 2 then
										error("expected two values for " .. key .. ", got " .. #entries)
									end
									log_write("adding to ".. args .. " ".. key .. " with value " .. entries[2])
									insert(tbl, {name = key, type = entries[1], value = entries[2]})
								end
							end
							insert(materials, tbl)
						end
					end

					if cur_obj then
						insert(cur_obj, cur_index)
					end
					log_write("Material " .. args .. ": flag=" .. last_material.flag .. ", shader=" .. last_material.shader)
				elseif cmd == "f" then
					local v1, v2, v3 = args:match("(%d+/%d*/%d+) (%d+/%d*/%d+) (%d+/%d*/%d+)")
					if v1 and v2 and v3 then
						local a, b, c = face(v1), face(v2), face(v3)
						insert(triangles, {
							[1] = a,
							[2] = b,
							[3] = c,
							material = cur_index,
							flag = last_material.flag,
						})
					end
				elseif cmd == "o" then
					local t = #triangles
					if cur_obj then
						cur_obj.to = t
						WriteO(data_file, cur_obj)
					end
					cur_obj = {name = args, from = t + 1}
				end
			elseif cmd == "mtllib" then
				mat_src = ReadMTL(path:gsub("[^\\/]+%.%w+$", args))
			end
		end
		if not util.IsConsole() then 
			progress.inc = 1
		end
	end


	for name, flags in pairs(material_flags) do
		for key, value in pairs(flags) do
			if string.sub(key, 1, 2) == "e_" then
				entries = Split(value, " ")
				if not #entries == 2 then
					error("expected two values for " .. key .. ", got " .. #entries)
				end
				
				log_write("flags ".. name .. " key "..key..": " .. entries[2])
				if not mat_src[name] then
					mat_src[name] = {}
				end
				mat_src[name][key] = entries[2]
			end
		end
	end

	f:close()
	log_write "Finished reading OBJ vertices, normals, texture coordinates and faces"

	if cur_obj then
		cur_obj.to = #triangles
		WriteO(data_file, cur_obj)
	end
	data_file:write("\n")
	data_file:close()

	if mat_src then		
		local folder = path:match("^.+[\\/]")
		if not folder then 
			folder = "./"
		end
		log_write("Searching for texture files to import from directory '" .. folder .. "' (path: " .. path .. ")")
		local append_pos = appending and (#dir + 2) or (#dir + 1)
		local load_img = function(name)
			local mat_path = folder .. name
			-- log_write("Attempting to find file '" .. name .. "' at '" .. mat_path .. "'")
			name = name:lower()
			local pos
			for i, ent in ipairs(dir) do
				if ent.name == name then
					pos = i
					break
				end
			end
			if not pos then
				pos = append_pos
				append_pos = append_pos + 1
			end
			local s, err = pcall(eqg.ImportFlippedImage, mat_path, name, dir, pos)
			if not s then
				if not util.IsConsole() then error(err) end
				if util.IsConsole() then log_write("Find file '" .. name .. "' failed with error: " .. err) end
				return
			end
		end

		for mat_name, mat in pairs(mat_src) do
			--log_write("Searching for images to import for material '" .. mat_name .. "'")
			local name = mat.diffuse_map
			if name then
				log_write("Material " .. mat_name .. " had diffuse map '" .. name .. "' listed")
				load_img(name)
			end
			name = mat.e_TextureNormal0
			if name then
				log_write("Material " .. mat_name .. " had normal map '" .. name .. "' listed")
				load_img(name)
			end
			name = mat.e_TextureEnvironment0
			if name then
				log_write("Material " .. mat_name .. " had environment map '" .. name .. "' listed")
				load_img(name)
			end
			name = mat.e_TextureSecond0
			if name then
				log_write("Material " .. mat_name .. " had second diffuse map '" .. name .. "' listed")
				load_img(name)
			end
		end
	end

	if not util.IsConsole()	then 
		progress:hide()
		iup.Destroy(progress)
	end

	log_write "Import from OBJ complete"

	return {
		materials = materials,
		vertices = vertices,
		triangles = triangles,
	}
end

local format = string.format
local util = util

function obj.Export()
	local ter_data = active_ter
	local zonename = zone_name
	local dir = open_dir
	if not ter_data or not zonename or not dir then return end

	local dlg = iup.filedlg{title = "Select destination folder", dialogtype = "DIR"}
	iup.Popup(dlg)
	if dlg.status ~= "-1" then
		local folder = dlg.value .. "/"

		local materials = ter_data.materials
		local triangles = ter_data.triangles
		local vertices = ter_data.vertices
		local exported = {}

		local ExportImage = function(name)
			if not exported[name] then
				exported[name] = true
				for i, ent in ipairs(dir) do
					if ent.name == name then
						local s, err = pcall(eqg.OpenEntry, ent)
						if s then
							pcall(eqg.ExportFile, folder .. name, ent)
						end
						break
					end
				end
			end
		end

		local f = assert(io.open(folder .. zonename .. ".mtl", "w+"))
		f:write("# Exported by EQG Zone Importer v1.5\n\n")
		for i, mat in ipairs(materials) do
			f:write("newmtl ", mat.name, "\n")
			f:write("Ka 1.000000 1.000000 1.000000\nKd 1.000000 1.000000 1.000000\nd 1.000000\nillum 2\n")
			for _, prop in ipairs(mat) do
				local name, value = prop.name, prop.value
				if name == "e_TextureDiffuse0" then
					f:write("map_Kd ", value, "\n")
					ExportImage(value)
				elseif name == "e_TextureNormal0" then
					f:write("map_Bump ", value, "\n")
					ExportImage(value)
				end
			end
			f:write("\n")
		end
		f:close()

		f = assert(io.open(folder .. zonename .. ".obj", "w+"))
		f:write("# Exported by EQG Zone Importer v1.5\n")
		f:write("mtllib ", zonename, ".mtl\no ", zonename, "\n")

		if vertices.binary then
			local x, y, z, u, v, i, j, k
			local c = vertices.count - 1
			for i = 0, c do
				x, y, z = util.GetVertex(vertices, i)
				f:write("v ", format("%.6f %.6f %.6f\n", x, y, z))
			end
			for i = 0, c do
				x, y, z, u, v = util.GetVertex(vertices, i)
				f:write("vt ", format("%.6f %.6f\n", u, v))
			end
			for i = 0, c do
				x, y, z, u, v, i, j, k = util.GetVertex(vertices, i)
				f:write("vn ", format("%.6f %.6f %.6f\n", i, j, k))
			end
		else
			for i, vert in ipairs(vertices) do
				f:write("v ", format("%.6f %.6f %.6f\n", vert.x, vert.y, vert.z))
			end
			for i, vert in ipairs(vertices) do
				f:write("vt ", format("%.6f %.6f\n", vert.u, vert.v))
			end
			for i, vert in ipairs(vertices) do
				f:write("vn ", format("%.6f %.6f %.6f\n", vert.i, vert.j, vert.k))
			end
		end

		local group = 0
		local mat_id = -1
		if triangles.binary then
			for i = 0, triangles.count - 1 do
				local v1, v2, v3, mat = util.GetTriangle(triangles, i)
				if mat ~= mat_id then
					mat_id = mat
					if mat_id ~= -1 then
						f:write("usemtl ", materials[mat_id + 1].name, "\ns off\ng piece", group, "\n")
						group = group + 1
					end
				end
				--obj is 1-indexed
				v1 = v1 + 1
				v2 = v2 + 1
				v3 = v3 + 1
				f:write("f ", v1, "/", v1, "/", v1, " ", v2, "/", v2, "/", v2, " ", v3, "/", v3, "/", v3, "\n")
			end
		else
			for i, tri in ipairs(triangles) do
				if tri.material ~= mat_id then
					mat_id = tri.material
					if mat_id ~= -1 then
						f:write("usemtl ", materials[mat_id + 1].name, "\ns off\ng piece", group, "\n")
						group = group + 1
					end
				end
				local v1, v2, v3 = tri[1], tri[2], tri[3]
				--obj is 1-indexed
				v1 = v1 + 1
				v2 = v2 + 1
				v3 = v3 + 1
				f:write("f ", v1, "/", v1, "/", v1, " ", v2, "/", v2, "/", v2, " ", v3, "/", v3, "/", v3, "\n")
			end
		end
		f:close()

		local msg = iup.messagedlg{title = "Export Complete", value = "Successfully exported ".. zonename .." to .obj format."}
		iup.Popup(msg)
		iup.Destroy(msg)
	end
	iup.Destroy(dlg)
end

return obj
