
local lfs = require "lfs"
local eqg = require "luaeqg"

local obj = {}

local tonumber = tonumber
local insert = table.insert
local pcall = pcall

local function ReadMTL(path)
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
			elseif cmd == "map_kd" then
				cur.diffuse_map = args:match("[%w_]+%.%w+")
			elseif cmd == "map_bump" then
				cur.normal_map = args:match("[%w_]+%.%w+")
			end
		end
	end

	f:close()

	return out
end

function obj.Import(path, dir, appending)
	local f = assert(io.open(path, "r"))
	local fstr = f:read("*a")
	f:seek("set")
	local line_count = 0
	for n in fstr:gmatch("\n") do
		line_count = line_count + 1
	end

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
	progress:show()

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
					if not cur_index then
						cur_index = #materials
						mat_index[args] = cur_index
						local mat = mat_src[args]
						if mat then
							local tbl = {name = args, shader = "Opaque_MaxCB1.fx"}
							if mat.diffuse_map then
								local v = mat.diffuse_map:lower()
								tbl[1] = {name = "e_TextureDiffuse0", type = 2, value = v}
							end
							if mat.normal_map then
								local v = mat.normal_map:lower()
								insert(tbl, {name = "e_TextureNormal0", type = 2, value = v})
							end
							insert(materials, tbl)
						end
					end
				elseif cmd == "f" then
					local v1, v2, v3 = args:match("(%d+/%d*/%d+) (%d+/%d*/%d+) (%d+/%d*/%d+)")
					if v1 and v2 and v3 then
						local a, b, c = face(v1), face(v2), face(v3)
						insert(triangles, {
							[1] = a,
							[2] = b,
							[3] = c,
							material = cur_index,
							flag = 65536,
						})
					end
				end
			elseif cmd == "mtllib" then
				mat_src = ReadMTL(path:gsub("[^\\/]+%.%w+$", args))
			end
		end
		progress.inc = 1
	end

	f:close()

	if mat_src then
		local folder = path:match("^.+[\\/]")
		local append_pos = appending and (#dir + 2) or (#dir + 1)
		local load_img = function(name)
			local mat_path = folder .. name
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
				error_popup(err)
			end
		end

		for _, mat in pairs(mat_src) do
			local name = mat.diffuse_map
			if name then
				load_img(name)
			end
			name = mat.normal_map
			if name then
				load_img(name)
			end
		end
	end

	progress:hide()
	iup.Destroy(progress)

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
		f:write("# Exported by EQG Zone Importer v1.1\n\n")
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
		f:write("# Exported by EQG Zone Importer v1.1\n")
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
