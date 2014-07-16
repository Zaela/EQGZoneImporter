
#include "ter.h"

namespace TER
{
	int Read(lua_State* L)
	{
		byte* ptr = Util::CheckHeader(L, "EQGT", ".ter");

		Header* header = (Header*)ptr;
		uint32 pos = Header::SIZE;

		if (header->version != 2)
			return luaL_argerror(L, 1, "unsupported .ter version");

		lua_createtable(L, 0, 3); //to return

		const char* string_block = (const char*)&ptr[pos];
		pos += header->strings_len;

		//materials and their properties
		lua_createtable(L, header->material_count, 0);

		for (uint32 i = 1; i <= header->material_count; ++i)
		{
			Material* mat = (Material*)&ptr[pos];
			pos += Material::SIZE;

			lua_pushinteger(L, i);
			lua_createtable(L, mat->property_count, 2); //one table per material

			lua_pushstring(L, &string_block[mat->name_index]);
			lua_setfield(L, -2, "name");
			lua_pushstring(L, &string_block[mat->shader_index]);
			lua_setfield(L, -2, "shader");

			for (uint32 j = 1; j <= mat->property_count; ++j)
			{
				Property* prop = (Property*)&ptr[pos];
				pos += Property::SIZE;

				lua_pushinteger(L, j);
				lua_createtable(L, 0, 3);

				lua_pushstring(L, &string_block[prop->name_index]);
				lua_setfield(L, -2, "name");
				lua_pushinteger(L, prop->type);
				lua_setfield(L, -2, "type");
				if (prop->type == 0)
					lua_pushnumber(L, Util::FloatToDouble(prop->value.f));
				else if (prop->type == 3) //looks like rgb color values
					lua_pushnumber(L, prop->value.i);
				else
					lua_pushstring(L, &string_block[prop->value.i]);
				lua_setfield(L, -2, "value");

				lua_settable(L, -3);
			}

			lua_settable(L, -3);
		}

		lua_setfield(L, -2, "materials");

		//vertices
		lua_createtable(L, 0, 4);
		lua_pushboolean(L, true);
		lua_setfield(L, -2, "binary");
		lua_pushinteger(L, header->vertex_count);
		lua_setfield(L, -2, "count");
		lua_pushinteger(L, header->version);
		lua_setfield(L, -2, "version");
		uint32 len = (header->version < 3) ? Vertex::SIZE : VertexV3::SIZE;
		len *= header->vertex_count;
		void* block = lua_newuserdata(L, len);
		memcpy(block, &ptr[pos], len);
		pos += len;
		lua_setfield(L, -2, "data");

		lua_setfield(L, -2, "vertices");

		//triangles
		lua_createtable(L, 0, 3);
		lua_pushboolean(L, true);
		lua_setfield(L, -2, "binary");
		lua_pushinteger(L, header->triangle_count);
		lua_setfield(L, -2, "count");
		len = Triangle::SIZE * header->triangle_count;
		block = lua_newuserdata(L, len);
		memcpy(block, &ptr[pos], len);
		pos += len;
		lua_setfield(L, -2, "data");

		lua_setfield(L, -2, "triangles");

		return 1;
	}

	int Write(lua_State* L)
	{
		//takes a ter data table, returns a .eqg directory entry table
		Util::PrepareWrite(L, ".ter");

		//write .ter data
		Header header;
		header.magic[0] = 'E';
		header.magic[1] = 'Q';
		header.magic[2] = 'G';
		header.magic[3] = 'T';
		header.version = 2;

		Util::Buffer name_buf;
		Util::Buffer data_buf;

		Util::WriteGeometry(L, data_buf, name_buf, header.material_count, header.vertex_count, header.triangle_count);

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

	int Arrayize(lua_State* L)
	{
		//vertex table, triangle table
		luaL_checktype(L, 1, LUA_TTABLE);
		luaL_checktype(L, 2, LUA_TTABLE);

		//vertices
		lua_getfield(L, 1, "binary");
		if (lua_toboolean(L, -1) == false)
		{
			int count = lua_objlen(L, 1);
			lua_pushboolean(L, true);
			lua_setfield(L, 1, "binary");
			lua_pushinteger(L, count);
			lua_setfield(L, 1, "count");
			lua_pushinteger(L, 2);
			lua_setfield(L, 1, "version");
			uint32 len = count * Vertex::SIZE;
			byte* block = (byte*)lua_newuserdata(L, len);
			uint32 pos = 0;

			for (int i = 1; i <= count; ++i)
			{
				lua_pushinteger(L, i);
				lua_gettable(L, 1);

				Vertex* v = (Vertex*)&block[pos];
				pos += Vertex::SIZE;

				v->x = Util::GetFloat(L, -1, "x");
				v->y = Util::GetFloat(L, -1, "y");
				v->z = Util::GetFloat(L, -1, "z");
				v->i = Util::GetFloat(L, -1, "i");
				v->j = Util::GetFloat(L, -1, "j");
				v->k = Util::GetFloat(L, -1, "k");
				v->u = Util::GetFloat(L, -1, "u");
				v->v = Util::GetFloat(L, -1, "v");

				lua_pop(L, 1);
			}
	
			lua_setfield(L, 1, "data");
		}

		//triangles
		lua_getfield(L, 2, "binary");
		if (lua_toboolean(L, -1) == false)
		{
			int count = lua_objlen(L, 2);
			lua_pushboolean(L, true);
			lua_setfield(L, 2, "binary");
			lua_pushinteger(L, count);
			lua_setfield(L, 2, "count");
			lua_pushinteger(L, 2);
			lua_setfield(L, 2, "version");
			uint32 len = count * Triangle::SIZE;
			byte* block = (byte*)lua_newuserdata(L, len);
			uint32 pos = 0;

			for (int i = 1; i <= count; ++i)
			{
				lua_pushinteger(L, i);
				lua_gettable(L, 2);

				Triangle* tri = (Triangle*)&block[pos];
				pos += Triangle::SIZE;

				lua_pushinteger(L, 1);
				lua_gettable(L, -2);
				tri->index[0] = lua_tointeger(L, -1);
				lua_pop(L, 1);
				lua_pushinteger(L, 2);
				lua_gettable(L, -2);
				tri->index[1] = lua_tointeger(L, -1);
				lua_pop(L, 1);
				lua_pushinteger(L, 3);
				lua_gettable(L, -2);
				tri->index[2] = lua_tointeger(L, -1);
				lua_pop(L, 1);
				
				lua_getfield(L, -1, "material");
				tri->material = lua_tointeger(L, -1);
				lua_pop(L, 1);
				tri->flag = Util::GetInt(L, -1, "flag");

				lua_pop(L, 1);
			}
	
			lua_setfield(L, 2, "data");
		}

		return 0;
	}

	static const luaL_Reg funcs[] = {
		{"Read", Read},
		{"Write", Write},
		{"Arrayize", Arrayize},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "ter", funcs);
	}
}
