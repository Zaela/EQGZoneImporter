
local bit = require "bit"
local toggles = require "gui/toggles"

local triangles, materials
local util = util
local bitwise_or = bit.bor
local data, cur_obj, cur_mat_pos

local obj_list = iup.list{visiblecolumns = 10, visiblelines = 15, expand = "VERTICAL"}
local mat_list = iup.list{visiblecolumns = 10, visiblelines = 15, expand = "VERTICAL"}
local mode_list = iup.list{visiblecolumns = 12, dropdown = "YES",
	"Overwrite Flags", "Set Selected Bits", value = 1}
local tog = toggles.new()
local button = iup.button{title = "Apply", padding = "10x0"}

function obj_list:action(str, pos, state)
	if state == 1 and data and materials and triangles then
		local d = data[str]
		if not d then return end

		mat_list.autoredraw = "NO"
		mat_list[1] = nil
		mat_list[1] = "<All>"
		local i = 2
		for _, mat_id in ipairs(d) do
			local mat = materials[mat_id + 1]
			if mat then
				mat_list[i] = mat.name
				i = i + 1
			end
		end
		mat_list.autoredraw = "YES"

		cur_obj = d
		cur_mat_pos = nil
	end
end

function mat_list:action(str, pos, state)
	if state == 1 and cur_obj then
		cur_mat_pos = pos
		local flag
		if pos == 1 then
			if triangles.binary then
				local a, b, c, d, f = util.GetTriangle(triangles, cur_obj.from - 1)
				flag = f
			else
				local tri = triangles[cur_obj.from]
				if tri then
					flag = tri.flag
				end
			end
		else
			local mat_id = cur_obj[pos - 1]
			if triangles.binary then
				for i = cur_obj.from - 1, cur_obj.to - 1 do
					local a, b, c, mat, f = util.GetTriangle(triangles, i)
					if mat == mat_id then
						flag = f
						break
					end
				end
			else
				for i = cur_obj.from, cur_obj.to do
					local tri = triangles[i]
					if tri.material == mat_id then
						flag = tri.flag
						break
					end
				end
			end
		end

		if flag then
			tog:SetBinaryValue(flag)
		else
			tog:Clear()
		end
	end
end

function button:action()
	if not cur_obj or not cur_mat_pos then return end

	local mat_comp, check_mat, apply_func
	if cur_mat_pos == 1 then
		mat_comp = function() return true end
	else
		check_mat = cur_obj[cur_mat_pos - 1]
		if not check_mat then return end
		mat_comp = function(mat) return (mat == check_mat) end
	end

	if mode_list.value == "1" then
		--overwrite
		apply_func = function(flag, val) return val end
	else
		--set bits
		apply_func = function(flag, val) return bitwise_or(flag, val) end
	end

	local val = tog:GetBinaryValue()
	local count = 0

	if triangles.binary then
		for i = cur_obj.from - 1, cur_obj.to - 1 do
			local a, b, c, mat, flag = util.GetTriangle(triangles, i)
			if mat_comp(mat) then
				util.SetTriangleFlag(triangles, i, apply_func(flag, val))
				count = count + 1
			end
		end
	else
		for i = cur_obj.from, cur_obj.to do
			local tri = triangles[i]
			if mat_comp(tri.mat) then
				tri.flag = apply_func(tri.flag, val)
				count = count + 1
			end
		end
	end

	local msg = iup.messagedlg{title = "Complete", value = count .." Triangle flags edited."}
	iup.Popup(msg)
	iup.Destroy(msg)
end

local function Clear()
	cur_mat_pos = nil
	cur_obj = nil
	mat_list[1] = nil
	tog:Clear()
end

local function read(ter_data, zon_data, zone_name)
	Clear()

	triangles = ter_data.triangles
	materials = ter_data.materials

	local src = loadfile("data/".. zone_name ..".lua")
	if src then
		data = {}
		setfenv(src, data)
		src()

		obj_list.autoredraw = "NO"
		obj_list[1] = nil
		local i = 1
		for name in pairs(data) do
			obj_list[i] = name
			i = i + 1
		end
		obj_list.autoredraw = "YES"
	end
end

return {
	name = "OBJ Data",
	display = iup.hbox{obj_list, mat_list,
		iup.vbox{
			iup.hbox{iup.label{title = "Mode"}, mode_list, gap = 20, alignment = "ACENTER"},
		tog.grid, button; gap = 30, nmargin = "10x0", alignment = "ACENTER"};
	nmargin = "10x10", gap = 10, alignment = "ACENTER"},
	read = read,
}
