
#include "mod.h"

namespace MOD
{
	int Write(lua_State* L)
	{
		//takes a mod data table, returns a .eqg directory entry table
		Util::PrepareWrite(L, ".mod");

		//write .mod data
		Header header;
		header.magic[0] = 'E';
		header.magic[1] = 'Q';
		header.magic[2] = 'G';
		header.magic[3] = 'M';
		header.version = 1;

		Util::Buffer name_buf;
		Util::Buffer data_buf;

		Util::WriteGeometry(L, data_buf, name_buf, header.material_count, header.vertex_count, header.triangle_count);

		lua_getfield(L, 1, "bones");
		header.bone_count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= header.bone_count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			lua_getfield(L, -1, "data");
			Bone* raw = (Bone*)lua_touserdata(L, -1);
			lua_pop(L, 1);

			uint32 len;
			const char* name = Util::GetString(L, -1, "name", len);
			raw->name_index = name_buf.GetLen();
			name_buf.Add(name, len);

			data_buf.Add(raw, Bone::SIZE);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "bone_assignments");
		uint32 count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			BoneAssignment* raw = (BoneAssignment*)lua_touserdata(L, -1);

			data_buf.Add(raw, BoneAssignment::SIZE);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		header.strings_len = name_buf.GetLen();

		Util::Buffer buf;
		buf.Add(&header, Header::SIZE);

		byte* b = name_buf.Take();
		buf.Add(b, name_buf.GetLen());
		delete[] b;

		b = data_buf.Take();
		buf.Add(b, data_buf.GetLen());
		delete[] b;

		return Util::FinishWrite(L, buf);
	}

	static const luaL_Reg funcs[] = {
		{"Write", Write},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "mod", funcs);
	}
}
