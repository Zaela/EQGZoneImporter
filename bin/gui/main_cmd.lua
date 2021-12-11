
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

log_write("eqgzi " .. ...)

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