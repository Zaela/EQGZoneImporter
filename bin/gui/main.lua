
local lfs = require "lfs"
local eqg = require "luaeqg"
local obj = require "gui/obj"

function assert(result, msg)
	if result then return result end
	local err = iup.messagedlg{buttons = "OK", dialogtype = "ERROR", title = "Error", value = msg}
	iup.Popup(err)
	iup.Close()
end

function error_popup(msg)
	local err = iup.messagedlg{buttons = "OK", dialogtype = "ERROR", title = "Error", value = msg}
	iup.Popup(err)
	iup.Destroy(err)
end

local log_file = assert(io.open("log.txt", "w+"))
log_file:setvbuf("no")
function log_write(...)
	log_file:write("[", os.date(), "] ", ...)
	log_file:write("\r\n")
end

log_write "Loading UI"

local displays = {
	require "gui/general",
	require "gui/material",
	require "gui/triangle",
	require "gui/model",
	require "gui/region",
	require "gui/light",
	require "gui/import",
	require "gui/obj_data",
}
require "gui/loader"
require "gui/s3d"

local title = "EQG Zone Importer v1.2"
local window
local tabs = iup.tabs{padding = "5x5"}

for i = 1, #displays do
	local d = displays[i]
	tabs["tabtitle".. (i - 1)] = d.name
	iup.Append(tabs, d.display)
end

function tabs:tabchangepos_cb(pos)
	local d = displays[pos + 1]
	if d.load then
		d.load(active_ter, active_zon)
	end
end

local function OpenZoneFile()
	local dlg = iup.filedlg{title = "Select Zone EQG", dialogtype = "FILE",
		extfilter = "EQG Files (*.eqg)|*.eqg|All Files|*.*|", directory = lfs.currentdir()}
	iup.Popup(dlg)
	if dlg.status == "0" then
		local path = dlg.value
		if path then
			open_path = path
			local name = path:match("([%w_]+)%.%w+$")
			local ter_data, zon_data = LoadZone(path)
			if ter_data and zon_data and name then
				active_ter = ter_data
				active_zon = zon_data
				zone_name = name
				for i, d in ipairs(displays) do
					d.read(ter_data, zon_data, name, path)
				end
				window.title = title .." - ".. name
				tabs:tabchangepos_cb(tabs.valuepos)
			end
			log_write "Writing gui/settings.lua"
			local f = assert(io.open("gui/settings.lua", "w+"))
			f:write("\nsettings = {\n\tfolder = \"", (path:gsub("\\", "\\\\")), "\",\n")
			f:write("\tviewer = {\n\t\twidth = ", v and v.width or 600, ",\n\t\theight = ", v and v.height or 400, ",\n")
			f:write("\t}\n}\n")
			f:close()
		end
	end
end

function LoadFromImport(ter_data, zon_data, name, path)
	log_write("Loading '", name, "' from '", path, "' after import")
	active_ter = ter_data
	active_zon = zon_data
	for i, d in ipairs(displays) do
		d.read(ter_data, zon_data, name, path)
	end
	zone_name = name
	window.title = title .." - ".. name
	tabs:tabchangepos_cb(tabs.valuepos)
	log_write "Writing gui/settings.lua"
	local f = assert(io.open("gui/settings.lua", "w+"))
	f:write("\nsettings = {\n\tfolder = \"", (path:gsub("\\", "\\\\")), "\",\n")
	f:write("\tviewer = {\n\t\twidth = ", v and v.width or 600, ",\n\t\theight = ", v and v.height or 400, ",\n")
	f:write("\t}\n}\n")
	f:close()
end

local function dump_table_recurse(f, tbl, depth)
	for k, v in pairs(tbl) do
		local t = type(v)
		local d = string.rep("\t", depth)
		if t == "table" then
			f:write(d, k, " = {\r\n")
			dump_table_recurse(f, v, depth + 1)
			f:write(d, "},\r\n")
		else
			f:write(d, k, " = ", tostring(v), ",\r\n")
		end
	end
end

function Save(silent)
	local tname = active_ter_name
	local zname = active_zon_name
	local dir = open_dir
	local path = open_path
	if not active_ter or not active_zon or not tname or not zname or not dir or not path then return false end
	tname = tname:lower()
	zname = zname:lower()

	log_write("Attempting to save '", tname, "' and '", zname, "' to active directory")

	local s, data = pcall(ter.Write, active_ter, tname, eqg.CalcCRC(tname))
	if s then
		dir[GetDirPos(tname)] = data
	else
		log_write("Error writing '", tname, "': ", data)
		error_popup(data)
		return false
	end

	s, data = pcall(zon.Write, active_zon, zname, eqg.CalcCRC(zname))
	if s then
		dir[GetDirPos(zname)] = data
	else
		log_write("Error writing '", zname, "': ", data)
		error_popup(data)
		return false
	end

	s, data = pcall(eqg.WriteDirectory, path, dir)
	if not s then
		log_write("Error writing to active EQG directory: ", data)
		error_popup(data)
		return false
	end

	if not silent then
		local msg = iup.messagedlg{title = "Saved", value = "Saved successfully."}
		iup.Popup(msg)
		iup.Destroy(msg)
	end
	log_write "Saved successfully"
	return true
end

local function NewEQGArchive()
	local dlg = iup.filedlg{title = "Select location and name for new EQG archive.", dialogtype = "SAVE",
		extfilter = "EQG Files (*.eqg)|*.eqg|All Files|*.*|"}
	iup.Popup(dlg)
	if dlg.status ~= "-1" then
		local path = dlg.value
		if path and path ~= "" then
			--ensure file extension is .eqg
			if not path:match("%.eqg$") then
				path = path:match("([^%.]+)%.?%w*")
				path = path .. ".eqg"
			end
			log_write("Creating new EQG file at '", path, "'")
			local s, err = pcall(eqg.WriteDirectory, path, {})
			if not s then
				iup.Destroy(dlg)
				log_write("Error creating new EQG file: ", err)
				return error_popup(err)
			end
			log_write "Successfully created new EQG file"
			local msg = iup.messagedlg{title = "Created EQG", value = "Successfully created '".. path .."'"}
			iup.Popup(msg)
			iup.Destroy(msg)
		end
	end
	iup.Destroy(dlg)
end

local function StartViewer()
	local ter_data = active_ter
	local zon_data = active_zon
	local dir = open_dir
	if not ter_data or not zon_data or not dir then return end

	ter.Arrayize(ter_data.vertices, ter_data.triangles)

	local textures = {}
	--find and decompress all diffuse textures in the materials
	for i, mat in ipairs(ter_data.materials) do
		for j, prop in ipairs(mat) do
			if prop.name == "e_TextureDiffuse0" then
				local name = prop.value:lower()
				for k, ent in ipairs(dir) do
					if ent.name == name then
						local s, err = pcall(eqg.OpenEntry, ent)
						if s then
							ent.png_name = name:match("[^%.]+") .. ".png"
							ent.isDDS = (name:sub(-3) == "dds")
							textures[i] = ent
						end
						break
					end
				end
				break
			end
		end
	end

	log_write("Launching zone viewer, textures found: ", #textures)

	viewer.LoadZone(ter_data.vertices, ter_data.triangles, textures)
end

local menu = iup.menu{
	iup.submenu{
		title = "&File";
		iup.menu{
			iup.item{title = "Open Zone EQG", action = OpenZoneFile},
			iup.item{title = "&Save", action = function() Save() end},
			iup.separator{},
			iup.item{title = "New EQG Archive", action = NewEQGArchive},
			iup.separator{},
			iup.item{title = "&Quit", action = function() return iup.CLOSE end},
		},
	},
	iup.submenu{
		title = "Utility";
		iup.menu{
			iup.item{title = "Convert S3D Zone", action = s3d.ConvertZone},
			iup.item{title = "Export Zone", action = obj.Export},
		},
	},
	iup.submenu{
		title = "Viewer";
		iup.menu{
			iup.item{title = "Start Viewer", action = StartViewer},
			iup.separator{},
			iup.item{title = "Close Viewer", action = viewer.Close},
		},
	},
}

window = assert(iup.dialog{iup.hbox{tabs; nmargin = "10x10"}; title = title, menu = menu})

function window:k_any(key)
	if key == iup.K_ESC then
		return iup.CLOSE
	end
end

local function LoadSettings()
	local set = loadfile("gui/settings.lua")
	if set then
		set()
		if settings and settings.folder then
			open_path = settings.folder
			local name = open_path:match("([%w_]+)%.%w+$")
			local ter_data, zon_data = LoadZone(open_path)
			if ter_data and zon_data and name then
				active_ter = ter_data
				active_zon = zon_data
				zone_name = name
				for i, d in ipairs(displays) do
					d.read(ter_data, zon_data, name, open_path)
				end
				window.title = title .." - ".. name
				tabs:tabchangepos_cb(tabs.valuepos)
			end
		end
	end
end

window:show()

LoadSettings()
LoadSettings = nil

iup.MainLoop()

eqg.CloseDirectory(open_dir)

iup.Close()

log_write "Shutting down cleanly"
log_file:close()
