
require "gui/flag_editor"
local toggles = require "gui/toggles"

local list = iup.list{visiblecolumns = 8, visiblelines = 15, expand = "VERTICAL"}
local vertices, triangles, materials, ClearFields, active_pos

local v = {}
for i = 1, 3 do
	v[i] = {
		x = iup.text{visiblecolumns = 6, readonly = "YES"},
		y = iup.text{visiblecolumns = 6, readonly = "YES"},
		z = iup.text{visiblecolumns = 6, readonly = "YES"},
	}
end

local function l(text)
	return iup.label{title = text}
end

local grid = iup.gridbox{
	l"Vertex A ", l"X", v[1].x, l"Y", v[1].y, l"Z", v[1].z,
	l"Vertex B ", l"X", v[2].x, l"Y", v[2].y, l"Z", v[2].z,
	l"Vertex C ", l"X", v[3].x, l"Y", v[3].y, l"Z", v[3].z,
	numdiv = 7, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

local mat_field = iup.text{visiblecolumns = 16, readonly = "YES"}
local flag_field = iup.text{visiblecolumns = 16, mask = iup.MASK_UINT}

local grid2 = iup.gridbox{
	l"Material", mat_field,
	l"Flag", flag_field,
	numdiv = 2, orientation = "HORIZONTAL", homogeneouslin = "YES",
	gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 0
}

local tog

local function SaveFlag()
	local n = tonumber(flag_field.value) or 0
	if triangles and active_pos then
		if triangles.binary then
			util.SetTriangleFlag(triangles, active_pos - 1, n)
		else
			triangles[active_pos].flag = n
		end
	end
end

local function SetFlag()
	flag_field.value = tog:GetBinaryValue()
	SaveFlag()
end

tog = toggles.new(SetFlag)

function flag_field:valuechanged_cb()
	local n = tonumber(self.value) or 0
	tog:SetBinaryValue(n)
	SaveFlag()
end

l = nil

local function ReadBinaryVertex(pos, i)
	local x, y, z = util.GetVertex(vertices, pos)
	v[i].x.value = string.format("%.3f", x)
	v[i].y.value = string.format("%.3f", y)
	v[i].z.value = string.format("%.3f", z)
end

local function ReadVertex(vert, i)
	v[i].x.value = string.format("%.3f", vert.x)
	v[i].y.value = string.format("%.3f", vert.y)
	v[i].z.value = string.format("%.3f", vert.z)
end

function list:action(str, pos, state)
	if state == 1 and triangles and vertices and materials then
		active_pos = pos
		local v1, v2, v3, mat, flag
		if triangles.binary then
			v1, v2, v3, mat, flag = util.GetTriangle(triangles, pos - 1)
		else
			local tri = triangles[pos]
			v1 = tri[1]
			v2 = tri[2]
			v3 = tri[3]
			mat = tri.material
			flag = tri.flag
		end

		if mat >= 0 then
			mat = materials[mat + 1]
			mat_field.value = mat.name
		else
			mat_field.value = "<none>"
		end
		flag_field.value = flag
		tog:SetBinaryValue(flag)

		if vertices.binary then
			ReadBinaryVertex(v1, 1)
			ReadBinaryVertex(v2, 2)
			ReadBinaryVertex(v3, 3)
		else
			ReadVertex(vertices[v1 + 1], 1)
			ReadVertex(vertices[v2 + 1], 2)
			ReadVertex(vertices[v3 + 1], 3)
		end
	end
end

local loaded
local function read(ter_data)
	loaded = false
	active_pos = nil
	ClearFields()
	triangles = ter_data.triangles
	vertices = ter_data.vertices
	materials = ter_data.materials
end

local function load()
	if not loaded and triangles then
		loaded = true
		local count = triangles.binary and triangles.count or #triangles
		local progress = iup.progressdlg{count = 0, totalcount = count, description = "Loading Triangle data..."}
		progress:show()
		list.autoredraw = "NO"
		list[1] = nil
		for i = 1, count do
			list[i] = i
			progress.inc = 1
		end
		list.autoredraw = "YES"
		progress:hide()
		iup.Destroy(progress)
	end
end

function ClearFields()
	for i, f in ipairs(v) do
		f.x.value = ""
		f.y.value = ""
		f.z.value = ""
	end
	mat_field.value = ""
	flag_field.value = ""
	tog:Clear()
end

local flag_editor_button = iup.button{title = "Flag Editor", padding = "10x0",
	action = function()
		if triangles and materials then
			StartFlagEditor(triangles, materials)
		end
	end,
}

return {
	name = "Triangles",
	display = iup.hbox{list, iup.vbox{
		grid, grid2, iup.hbox{
			tog.grid, flag_editor_button; gap = 30, alignment = "ACENTER",
		}; gap = 20};
		nmargin = "10x10", gap = 10},
	read = read,
	load = load,
}
