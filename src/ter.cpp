
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

	static const luaL_Reg funcs[] = {
		{"Read", Read},
		{"Write", Write},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "ter", funcs);
	}
}
