
#include "util.h"

namespace Util
{
	byte* CheckHeader(lua_State* L, const char* magic, const char* err_name)
	{
		if (!lua_istable(L, 1))
		{
			char msg[256];
			snprintf(msg, 256, "expected unprocessed %s data table", err_name);
			luaL_argerror(L, 1, msg);
		}

		lua_getfield(L, 1, "ptr");
		if (!lua_isuserdata(L, -1))
		{
			char msg[256];
			snprintf(msg, 256, "no 'ptr' in unprocessed %s data table", err_name);
			luaL_argerror(L, 1, msg);
		}
		byte* ptr = (byte*)lua_touserdata(L, -1);
		lua_pop(L, 1);

		const char* m = (const char*)ptr;

		if (m[0] != magic[0] || m[1] != magic[1] || m[2] != magic[2] || m[3] != magic[3])
		{
			char msg[256];
			snprintf(msg, 256, "data is not a valid %s file", err_name);
			luaL_argerror(L, 1, msg);
		}

		return ptr;
	}

	void PrepareWrite(lua_State* L, const char* err_name)
	{
		if (!lua_istable(L, 1))
		{
			char msg[256];
			snprintf(msg, 256, "expected processed %s data table", err_name);
			luaL_argerror(L, 1, msg);
		}
		const char* name = luaL_checkstring(L, 2);
		uint32 crc = luaL_checkinteger(L, 3);

		//ptr, inflated_len, decompressed, name, name crc
		lua_createtable(L, 0, 5); //to return

		lua_pushboolean(L, 1);
		lua_setfield(L, -2, "decompressed");
		lua_pushstring(L, name);
		lua_setfield(L, -2, "name");
		lua_pushinteger(L, crc);
		lua_setfield(L, -2, "crc");
	}

	int FinishWrite(lua_State* L, Buffer& buf)
	{
		byte* ptr = buf.Take();
		lua_pushlightuserdata(L, ptr);
		lua_setfield(L, -2, "ptr");
		lua_pushinteger(L, buf.GetLen());
		lua_setfield(L, -2, "inflated_len");
		return 1;
	}

	double FloatToDouble(float val)
	{
		//this avoids extended precision mucking up nice round floats for display purposes (e.g. 0.7 -> 0.6999999997862...)
		//even though it really shouldn't...
		char str[256];
		snprintf(str, 256, "%g", val);
		return strtod(str, nullptr);
	}

	uint32 GetInt(lua_State* L, int index, const char* name)
	{
		uint32 val = 0;
		lua_getfield(L, index, name);
		val |= lua_tointeger(L, -1);
		lua_pop(L, 1);
		return val;
	}

	uint32 GetInt(lua_State* L, int index, int pos)
	{
		uint32 val = 0;
		lua_pushinteger(L, pos);
		lua_gettable(L, index);
		val |= lua_tointeger(L, -1);
		lua_pop(L, 1);
		return val;
	}

	float GetFloat(lua_State* L, int index, const char* name)
	{
		lua_getfield(L, index, name);
		float val = static_cast<float>(lua_tonumber(L, -1));
		lua_pop(L, 1);
		return val;
	}

	const char* GetString(lua_State* L, int index, const char* name, uint32& len)
	{
		lua_getfield(L, index, name);
		const char* str = lua_tostring(L, -1);
		len = lua_objlen(L, -1) + 1;
		lua_pop(L, 1);
		return str;
	}

	const char* GetString(lua_State* L, int index, const char* name)
	{
		lua_getfield(L, index, name);
		const char* str = lua_tostring(L, -1);
		lua_pop(L, 1);
		return str;
	}

	uint32 AddName(lua_State* L, const char* id, Buffer& name_buf, FoundNamesMap& found_names)
	{
		uint32 len;
		const char* name = GetString(L, -1, id, len);
		if (found_names.count(name))
		{
			return found_names[name];
		}
		uint32 pos = name_buf.GetLen();
		found_names[name] = pos;
		name_buf.Add(name, len);
		return pos;
	}

	void WriteGeometry(lua_State* L, Buffer& data_buf, Buffer& name_buf, uint32& mat_count, uint32& vert_count, uint32& tri_count)
	{
		FoundNamesMap found_names;

		lua_getfield(L, 1, "materials");
		uint32 count = lua_objlen(L, -1);
		mat_count = count;
		for (uint32 i = 1; i <= count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			Material mat;
			mat.index = i - 1;
			
			mat.name_index = AddName(L, "name", name_buf, found_names);
			mat.shader_index = AddName(L, "shader", name_buf, found_names);

			mat.property_count = lua_objlen(L, -1);
			data_buf.Add(&mat, Material::SIZE);

			for (uint32 j = 1; j <= mat.property_count; ++j)
			{
				lua_pushinteger(L, j);
				lua_gettable(L, -2);

				Property prop;
				prop.name_index = AddName(L, "name", name_buf, found_names);
				prop.type = GetInt(L, -1, "type");
				if (prop.type == 0)
				{
					prop.value.f = GetFloat(L, -1, "value");
				}
				else if (prop.type == 3)
				{
					lua_getfield(L, -1, "value");
					double val = lua_tonumber(L, -1);
					lua_pop(L, 1);
					prop.value.i = static_cast<uint32>(val);
				}
				else
				{
					prop.value.i = AddName(L, "value", name_buf, found_names);
				}

				data_buf.Add(&prop, Property::SIZE);
				lua_pop(L, 1);
			}

			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "vertices");
		lua_getfield(L, -1, "binary");
		int binary = lua_toboolean(L, -1);
		lua_pop(L, 1);

		if (binary)
		{
			lua_getfield(L, -1, "count");
			int count = lua_tointeger(L, -1);
			lua_getfield(L, -2, "data");
			void* data = lua_touserdata(L, -1);
			uint32 len = lua_objlen(L, -1);
			lua_pop(L, 2);

			data_buf.Add(data, len);
			vert_count = count;
		}
		else
		{
			count = lua_objlen(L, -1);
			vert_count = count;
			for (uint32 i = 1; i <= count; ++i)
			{
				lua_pushinteger(L, i);
				lua_gettable(L, -2);

				Vertex vert;
				vert.x = GetFloat(L, -1, "x");
				vert.y = GetFloat(L, -1, "y");
				vert.z = GetFloat(L, -1, "z");
				vert.i = GetFloat(L, -1, "i");
				vert.j = GetFloat(L, -1, "j");
				vert.k = GetFloat(L, -1, "k");
				vert.u = GetFloat(L, -1, "u");
				vert.v = GetFloat(L, -1, "v");

				data_buf.Add(&vert, Vertex::SIZE);
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "triangles");
		lua_getfield(L, -1, "binary");
		binary = lua_toboolean(L, -1);
		lua_pop(L, 1);

		if (binary)
		{
			lua_getfield(L, -1, "count");
			int count = lua_tointeger(L, -1);
			lua_getfield(L, -2, "data");
			void* data = lua_touserdata(L, -1);
			uint32 len = lua_objlen(L, -1);
			lua_pop(L, 2);

			data_buf.Add(data, len);
			tri_count = count;
		}
		else
		{
			count = lua_objlen(L, -1);
			tri_count = count;
			for (uint32 i = 1; i <= count; ++i)
			{
				lua_pushinteger(L, i);
				lua_gettable(L, -2);

				Triangle tri;
				for (int j = 0; j < 3; ++j)
				{
					lua_pushinteger(L, j + 1);
					lua_gettable(L, -2);
					tri.index[j] = lua_tointeger(L, -1);
					lua_pop(L, 1);
				}
				lua_getfield(L, -1, "material");
				tri.material = lua_tointeger(L, -1);
				lua_pop(L, 1);
				tri.flag = GetInt(L, -1, "flag");

				data_buf.Add(&tri, Triangle::SIZE);
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1);
	}


	Buffer::Buffer() : mLen(0), mCap(8192)
	{
		mData = new byte[8192];
	}

	void Buffer::Add(const void* in_data, uint32 len)
	{
		const byte* data = (byte*)in_data;
		uint32 newlen = mLen + len;
		if (newlen >= mCap)
		{
			while (newlen >= mCap)
				mCap <<= 1;
			byte* add = new byte[mCap];
			memcpy(add, mData, mLen);
			delete[] mData;
			mData = add;
		}
		memcpy(&mData[mLen], data, len);
		mLen = newlen;
	}

	byte* Buffer::Take()
	{
		byte* ret = mData;
		mData = nullptr;
		return ret;
	}

	int VertexLookup(lua_State* L)
	{
		//1 = vertex table, 2 = key
		int key = luaL_checkinteger(L, 2);

		lua_getfield(L, 1, "count");
		int count = lua_tointeger(L, -1);
		if (key >= count)
			return luaL_argerror(L, 2, "out of range vertex lookup");

		lua_getfield(L, 1, "version");
		int version = lua_tointeger(L, -1);
		lua_getfield(L, 1, "data");
		byte* data = (byte*)lua_touserdata(L, -1);

		float x, y, z, u, v, i, j, k;
		if (version < 3)
		{
			Vertex* vert = (Vertex*)&data[key * Vertex::SIZE];
			x = vert->x;
			y = vert->y;
			z = vert->z;
			u = vert->u;
			v = vert->v;
			i = vert->i;
			j = vert->j;
			k = vert->k;
		}
		else
		{
			VertexV3* vert = (VertexV3*)&data[key * VertexV3::SIZE];
			x = vert->x;
			y = vert->y;
			z = vert->z;
			u = vert->u;
			v = vert->v;
			i = vert->i;
			j = vert->j;
			k = vert->k;
		}

		lua_pushnumber(L, x);
		lua_pushnumber(L, y);
		lua_pushnumber(L, z);
		lua_pushnumber(L, u);
		lua_pushnumber(L, v);
		lua_pushnumber(L, i);
		lua_pushnumber(L, j);
		lua_pushnumber(L, k);
		return 8;
	}

	int TriangleLookup(lua_State* L)
	{
		//1 = triangle table, 2 = key
		int key = luaL_checkinteger(L, 2);

		lua_getfield(L, 1, "count");
		int count = lua_tointeger(L, -1);
		if (key >= count)
			return luaL_argerror(L, 2, "out of range triangle lookup");

		lua_getfield(L, 1, "data");
		byte* data = (byte*)lua_touserdata(L, -1);

		Triangle* tri = (Triangle*)&data[key * Triangle::SIZE];

		lua_pushinteger(L, tri->index[0]);
		lua_pushinteger(L, tri->index[1]);
		lua_pushinteger(L, tri->index[2]);
		lua_pushinteger(L, tri->material);
		double flag = tri->flag;
		lua_pushnumber(L, flag);
		return 5;
	}

	int SetTriangleFlag(lua_State* L)
	{
		//1 = triangle table, 2 = key, 3 = flag
		int key = luaL_checkinteger(L, 2);
		double flag = luaL_checknumber(L, 3);

		lua_getfield(L, 1, "count");
		int count = lua_tointeger(L, -1);
		if (key >= count)
			return luaL_argerror(L, 2, "out of range triangle setflag");

		lua_getfield(L, 1, "data");
		byte* data = (byte*)lua_touserdata(L, -1);

		Triangle* tri = (Triangle*)&data[key * Triangle::SIZE];

		tri->flag = static_cast<uint32>(flag);
		return 0;
	}

	static const luaL_Reg funcs[] = {
		{"GetVertex", VertexLookup},
		{"GetTriangle", TriangleLookup},
		{"SetTriangleFlag", SetTriangleFlag},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "util", funcs);
	}
}
