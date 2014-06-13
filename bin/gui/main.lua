
local lfs = require "lfs"
local eqg = require "luaeqg"

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

local displays = {
	require "gui/general",
	require "gui/material",
	require "gui/triangle",
	require "gui/model",
	require "gui/region",
	require "gui/light",
	require "gui/import",
}
require "gui/loader"

local title = "EQG Zone Importer v0.1"
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
				for i, d in ipairs(displays) do
					d.read(ter_data, zon_data, name, path)
				end
				window.title = title .." - ".. name
				tabs:tabchangepos_cb(tabs.valuepos)
			end
			local f = assert(io.open("gui/settings.lua", "w+"))
			f:write("\nreturn \"".. (path:gsub("\\", "\\\\")) .."\"\n")
			f:close()
		end
	end
end

function LoadFromImport(ter_data, zon_data, name, path)
	active_ter = ter_data
	active_zon = zon_data
	for i, d in ipairs(displays) do
		d.read(ter_data, zon_data, name, path)
	end
	window.title = title .." - ".. name
	tabs:tabchangepos_cb(tabs.valuepos)
	local f = assert(io.open("gui/settings.lua", "w+"))
	f:write("\nreturn \"".. (path:gsub("\\", "\\\\")) .."\"\n")
	f:close()
end

function Save(silent)
	local tname = active_ter_name
	local zname = active_zon_name
	local dir = open_dir
	local path = open_path
	if not active_ter or not active_zon or not tname or not zname or not dir or not path then return false end
	tname = tname:lower()
	zname = zname:lower()

	local s, data = pcall(ter.Write, active_ter, tname, eqg.CalcCRC(tname))
	if s then
		dir[GetDirPos(tname)] = data
	else
		error_popup(data)
		return false
	end

	s, data = pcall(zon.Write, active_zon, zname, eqg.CalcCRC(zname))
	if s then
		dir[GetDirPos(zname)] = data
	else
		error_popup(data)
		return false
	end

	s, data = pcall(eqg.WriteDirectory, path, dir)
	if not s then
		error_popup(data)
		return false
	end

	if not silent then
		local msg = iup.messagedlg{title = "Saved", value = "Saved successfully."}
		iup.Popup(msg)
		iup.Destroy(msg)
	end
	return true
end

local function DoSave()
	Save()
end

local menu = iup.menu{
	iup.submenu{
		title = "&File";
		iup.menu{
			iup.item{title = "Open Zone EQG", action = OpenZoneFile},
			iup.item{title = "&Save", action = DoSave},
			iup.separator{},
			iup.item{title = "&Quit", action = function() return iup.CLOSE end},
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
	local settings = loadfile("gui/settings.lua")
	if settings then
		local path = settings()
		if path then
			open_path = path
			local name = path:match("([%w_]+)%.%w+$")
			local ter_data, zon_data = LoadZone(path)
			if ter_data and zon_data and name then
				active_ter = ter_data
				active_zon = zon_data
				for i, d in ipairs(displays) do
					d.read(ter_data, zon_data, name, path)
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
