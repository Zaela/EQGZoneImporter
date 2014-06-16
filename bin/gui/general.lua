
local fields = {
	name = iup.text{visiblecolumns = 16, readonly = "YES"},
	mat_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	vert_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	tri_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	model_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	obj_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	region_count = iup.text{visiblecolumns = 16, readonly = "YES"},
	light_count = iup.text{visiblecolumns = 16, readonly = "YES"},
}

local grid = iup.gridbox{
	iup.label{title = "Shortname"}, fields.name,
	iup.label{title = "Materials"}, fields.mat_count,
	iup.label{title = "Vertices"}, fields.vert_count,
	iup.label{title = "Triangles"}, fields.tri_count,
	iup.label{title = "Model Definitions"}, fields.model_count,
	iup.label{title = "Placed Models"}, fields.obj_count,
	iup.label{title = "Regions"}, fields.region_count,
	iup.label{title = "Lights"}, fields.light_count,
	numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 4
}

local function load(ter_data, zon_data)
	if not ter_data or not zon_data then return end
	fields.mat_count.value = #ter_data.materials
	local vert = ter_data.vertices
	fields.vert_count.value = vert.binary and vert.count or #vert
	local tri = ter_data.triangles
	fields.tri_count.value = tri.binary and tri.count or #tri

	local mod_count = 0
	local dir = open_dir
	if dir then
		for i, ent in ipairs(dir) do
			local name = ent.name
			if name:find("%.mod$") or name:find("%.ter$") then
				mod_count = mod_count + 1
			end
		end
	end

	fields.model_count.value = mod_count
	fields.obj_count.value = #zon_data.objects
	fields.region_count.value = #zon_data.regions
	fields.light_count.value = #zon_data.lights
end

local function read(ter_data, zon_data, zone_name)
	fields.name.value = zone_name or ""
	load(ter_data, zon_data)
end

return {
	name = "Info",
	display = iup.vbox{grid; nmargin = "15x15"},
	read = read,
	load = load,
}
