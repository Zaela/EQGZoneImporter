
local bit = require "bit"
local toggles = require "gui/toggles"

local triangles
local util = util
local bitwise_or = bit.bor

local mat_list = iup.list{visiblecolumns = 16, dropdown = "YES", visible_items = 20}
local min_field = iup.text{visiblecolumns = 6, mask = iup.MASK_UINT, active = "NO"}
local max_field = iup.text{visiblecolumns = 6, mask = iup.MASK_UINT, active = "NO"}

local by_mat_toggle = iup.toggle{value = "ON",
	valuechanged_cb = function(self)
		mat_list.active = (self.value == "ON") and "YES" or "NO"
	end}

local by_range_toggle = iup.toggle{value = "OFF",
	valuechanged_cb = function(self)
		local active = (self.value == "ON") and "YES" or "NO"
		min_field.active = active
		max_field.active = active
	end}

local mode_list = iup.list{visiblecolumns = 12, dropdown = "YES",
	"Overwrite Flags", "Set Selected Bits", value = 1}

local tog = toggles.new()

local button = iup.button{title = "Go", padding = "10x0",
	action = function()
		local mat_id = tonumber(mat_list.value) or 0
		mat_id = mat_id - 1
		local by_mat = (by_mat_toggle.value == "ON") and (mat_id >= 0)
		local by_range, min, max
		if by_range_toggle.value == "ON" then
			min = tonumber(min_field.value)
			max = tonumber(max_field.value)
			by_range = (min and max)
		end
		local comp_func
		if by_mat and by_range then
			comp_func = function(i, m)
				return (i >= min and i <= max and m == mat_id)
			end
		elseif by_mat then
			comp_func = function(i, m)
				return (m == mat_id)
			end
		elseif by_range then
			comp_func = function(i)
				return (i >= min and i <= max)
			end
		else return end

		local val = tog:GetBinaryValue()
		local count = 0
		local progress = iup.progressdlg{
			count = 0,
			totalcount = triangles.binary and triangles.count or #triangles,
			description = "Setting Triangle flags..."}
		if mode_list.value == "1" then
			--overwrite
			if triangles.binary then
				for i = 1, triangles.count do
					local pos = i - 1
					local a, b, c, mat = util.GetTriangle(triangles, pos)
					if comp_func(i, mat) then
						util.SetTriangleFlag(triangles, pos, val)
						count = count + 1
					end
					progress.inc = 1
				end
			else
				for i, tri in ipairs(triangles) do
					if comp_func(i, tri.material) then
						tri.flag = val
						count = count + 1
					end
					progress.inc = 1
				end
			end
		else
			--set bits
			if triangles.binary then
				for i = 1, triangles.count do
					local pos = i - 1
					local a, b, c, mat, flag = util.GetTriangle(triangles, pos)
					if comp_func(i, mat) then
						util.SetTriangleFlag(triangles, pos, bitwise_or(flag, val))
						count = count + 1
					end
					progress.inc = 1
				end
			else
				for i, tri in ipairs(triangles) do
					if comp_func(i, tri.material) then
						tri.flag = bitwise_or(tri.flag, val)
						count = count + 1
					end
					progress.inc = 1
				end
			end
		end

		local msg = iup.messagedlg{title = "Complete", value = count .." Triangle flags edited."}
		iup.Popup(msg)
		iup.Destroy(msg)
	end,
}

local editor = iup.dialog{title = "Triangle Flag Mass Editor",
	iup.hbox{
		iup.vbox{
			iup.gridbox{
				by_mat_toggle, iup.label{title = "By Material"}, mat_list,
				by_range_toggle, iup.label{title = "By Range  "}, iup.hbox{
						iup.label{title = "Min"}, min_field, iup.label{title = "Max"}, max_field;
						gap = 10, alignment = "ACENTER",
					},
				iup.label{title = "Mode"}, mode_list;
				numdiv = 3, orientation = "HORIZONTAL", homogeneouslin = "YES",
				gapcol = 10, gaplin = 8, alignmentlin = "ACENTER", sizelin = 1
			},
			iup.vbox{
				tog.grid, button;
				alignment = "ACENTER", gap = 20,
			},
			gap = 10,
		},
		nmargin = "15x15",
	},
	k_any = function(self,key) if key == iup.K_ESC then self:hide() end end,
}

function StartFlagEditor(tris, mats)
	mat_list[1] = nil
	for i, mat in ipairs(mats) do
		mat_list[i] = mat.name
	end
	triangles = tris

	iup.Popup(editor)
end
