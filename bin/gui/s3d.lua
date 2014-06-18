
local eqg = require "luaeqg"

s3d = {}

function s3d.ConvertZone()
	local dlg = iup.filedlg{title = "Select Zone S3D File",
		extfilter = "S3D Files (*.s3d)|*.s3d|All Files|*.*|"}
	iup.Popup(dlg)
	if dlg.status == "0" then
		local path = dlg.value
		if path and path ~= "" then
			local s, dir = pcall(eqg.LoadDirectory, path)
			if not s then
				return error_popup(dir)
			end
			local name = path:match("(%w+)_?%w*%.s3d")
			if not name then return end
			local progress = iup.progressdlg{description = "Converting S3D...", state = "UNDEFINED"}
			progress:show()
			name = name .. ".wld"
			local wld_file
			local by_name = {}
			for i, ent in ipairs(dir) do
				local n = ent.name
				if name == n then
					wld_file = ent
				end
				by_name[n] = ent
			end
			if not wld then
				progress:hide()
				iup.Destroy(progress)
				return error_popup("Could not find a matching zone .wld file in '".. path .."'. Are you sure this is a valid zone .s3d?")
			end
			local verts, tris
			s, verts = pcall(eqg.OpenEntry, wld_file)
			if s then
				s, verts, tris = pcall(wld.Read, wld_file)
				if s then
					--now we need to: make materials, build ter and zon, make new EQG and copy textures to it
					--materials
					local mat_ids = {}
					local materials = {}
					for i, tri in ipairs(tris) do
						local tex = tri.texture:lower()
						local id = mat_ids[tex]
						if not id then
							id = #materials
							mat_ids[tex] = id
							materials[id + 1] = {name = "Material".. id, shader = "Opaque_MaxCB1.fx",
								{name = "e_TextureDiffuse0", type = 2, value = tex}}
						end
						--s3d has winding order backwards
						tri[1], tri[3] = tri[3], tri[1]
						tri.material = id
						tri.flag = 65536
					end
					--ter and zon
					name = name:sub(1, -5)
					local ter_data = {
						materials = materials,
						vertices = verts,
						triangles = tris,
					}
					local zon_data = {
						models = {name .. ".ter"},
						objects = {{name = name, id = 0, x = 0, y = 0, z = 0,
							rotation_x = 0, rotation_y = 0, rotation_z = 0, scale = 1}},
						regions = {},
						lights = {},
					}
					--new EQG dir
					local new_dir = {}
					for i, mat in ipairs(materials) do
						local ent = by_name[mat[1].value]
						if ent then
							table.insert(new_dir, ent)
						end
					end
					path = path:sub(1, -4) .. "eqg"
					local err
					s, err = pcall(eqg.WriteDirectory, path, new_dir)
					if not s then
						progress:hide()
						iup.Destroy(progress)
						iup.Destroy(dlg)
						return error_popup(err)
					end
					eqg.CloseDirectory(dir)
					eqg.CloseDirectory(open_dir)
					s, new_dir = pcall(eqg.LoadDirectory, path)
					if not s then
						progress:hide()
						iup.Destroy(progress)
						iup.Destroy(dlg)
						return error_popup(new_dir)
					end
					--save it all
					open_dir = new_dir
					open_path = path
					active_ter_name = name .. ".ter"
					active_zon_name = name .. ".zon"
					DirNames(new_dir)
					LoadFromImport(ter_data, zon_data, name, path)
					progress:hide()
					iup.Destroy(progress)
					if Save(true) then
						local msg = iup.messagedlg{title = "Success!", value = "Successfully converted ".. name .."!"}
						iup.Popup(msg)
						iup.Destroy(msg)
					end
					iup.Destroy(dlg)
					return
				end
			end
			error_popup(verts)
		end
	end
	iup.Destroy(dlg)
end

return s3d
