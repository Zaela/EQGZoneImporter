
#include "zon.h"

namespace ZON
{
	int Read(lua_State* L)
	{
		byte* ptr = Util::CheckHeader(L, "EQGZ", ".zon");

		Header* header = (Header*)ptr;
		uint32 pos = Header::SIZE;

		if (header->version != 1)
			return luaL_argerror(L, 1, "unsupported .zon version");

		lua_createtable(L, 0, 4); //to return

		const char* string_block = (const char*)&ptr[pos];
		pos += header->strings_len;

		//model identifiers
		lua_createtable(L, header->model_count, 0);

		for (uint32 i = 1; i <= header->model_count; ++i)
		{
			Model* mod = (Model*)&ptr[pos];
			pos += Model::SIZE;

			lua_pushinteger(L, i);
			lua_pushstring(L, &string_block[mod->name_index]);
			lua_settable(L, -3);
		}

		lua_setfield(L, -2, "models");

		//objects/placeables
		lua_createtable(L, header->object_count, 0);

		for (uint32 i = 1; i <= header->object_count; ++i)
		{
			Object* obj = (Object*)&ptr[pos];
			pos += Object::SIZE;

			lua_pushinteger(L, i);
			lua_createtable(L, 0, 9);

			lua_pushinteger(L, obj->id);
			lua_setfield(L, -2, "id");
			lua_pushstring(L, &string_block[obj->name_index]);
			lua_setfield(L, -2, "name");

			lua_pushnumber(L, Util::FloatToDouble(obj->x));
			lua_setfield(L, -2, "x");
			lua_pushnumber(L, Util::FloatToDouble(obj->y));
			lua_setfield(L, -2, "y");
			lua_pushnumber(L, Util::FloatToDouble(obj->z));
			lua_setfield(L, -2, "z");
			lua_pushnumber(L, Util::FloatToDouble(obj->rotation_x));
			lua_setfield(L, -2, "rotation_x");
			lua_pushnumber(L, Util::FloatToDouble(obj->rotation_y));
			lua_setfield(L, -2, "rotation_y");
			lua_pushnumber(L, Util::FloatToDouble(obj->rotation_z));
			lua_setfield(L, -2, "rotation_z");
			lua_pushnumber(L, Util::FloatToDouble(obj->scale));
			lua_setfield(L, -2, "scale");

			lua_settable(L, -3);
		}

		lua_setfield(L, -2, "objects");

		//regions
		lua_createtable(L, header->region_count, 0);

		for (uint32 i = 1; i <= header->region_count; ++i)
		{
			Region* reg = (Region*)&ptr[pos];
			pos += Region::SIZE;

			lua_pushinteger(L, i);
			lua_createtable(L, 0, 10);

			lua_pushstring(L, &string_block[reg->name_index]);
			lua_setfield(L, -2, "name");

			lua_pushnumber(L, Util::FloatToDouble(reg->center_x));
			lua_setfield(L, -2, "center_x");
			lua_pushnumber(L, Util::FloatToDouble(reg->center_y));
			lua_setfield(L, -2, "center_y");
			lua_pushnumber(L, Util::FloatToDouble(reg->center_z));
			lua_setfield(L, -2, "center_z");

			lua_pushnumber(L, Util::FloatToDouble(reg->unknownA));
			lua_setfield(L, -2, "unknownA");
			lua_pushnumber(L, reg->unknownB);
			lua_setfield(L, -2, "unknownB");
			lua_pushinteger(L, reg->unknownC);
			lua_setfield(L, -2, "unknownC");

			lua_pushnumber(L, Util::FloatToDouble(reg->extent_x));
			lua_setfield(L, -2, "extent_x");
			lua_pushnumber(L, Util::FloatToDouble(reg->extent_y));
			lua_setfield(L, -2, "extent_y");
			lua_pushnumber(L, Util::FloatToDouble(reg->extent_z));
			lua_setfield(L, -2, "extent_z");

			lua_settable(L, -3);
		}

		lua_setfield(L, -2, "regions");

		//lights
		lua_createtable(L, header->light_count, 0);

		for (uint32 i = 1; i <= header->light_count; ++i)
		{
			Light* light = (Light*)&ptr[pos];
			pos += Light::SIZE;

			lua_pushinteger(L, i);
			lua_createtable(L, 0, 8);

			lua_pushstring(L, &string_block[light->name_index]);
			lua_setfield(L, -2, "name");

			lua_pushnumber(L, Util::FloatToDouble(light->x));
			lua_setfield(L, -2, "x");
			lua_pushnumber(L, Util::FloatToDouble(light->y));
			lua_setfield(L, -2, "y");
			lua_pushnumber(L, Util::FloatToDouble(light->z));
			lua_setfield(L, -2, "z");
			lua_pushnumber(L, Util::FloatToDouble(light->r));
			lua_setfield(L, -2, "r");
			lua_pushnumber(L, Util::FloatToDouble(light->g));
			lua_setfield(L, -2, "g");
			lua_pushnumber(L, Util::FloatToDouble(light->b));
			lua_setfield(L, -2, "b");
			lua_pushnumber(L, Util::FloatToDouble(light->radius));
			lua_setfield(L, -2, "radius");

			lua_settable(L, -3);
		}

		lua_setfield(L, -2, "lights");

		return 1;
	}

	int Write(lua_State* L)
	{
		//takes a zon data table, returns a .eqg directory entry table
		Util::PrepareWrite(L, ".zon");

		//write .zon data
		Header header;
		header.magic[0] = 'E';
		header.magic[1] = 'Q';
		header.magic[2] = 'G';
		header.magic[3] = 'Z';
		header.version = 1;

		Util::Buffer name_buf;
		Util::Buffer data_buf;
		const char* name;
		uint32 len;

		lua_getfield(L, 1, "models");
		header.model_count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= header.model_count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			Model mod;

			name = lua_tostring(L, -1);
			len = lua_objlen(L, -1) + 1;
			lua_pop(L, 1);
			mod.name_index = name_buf.GetLen();
			name_buf.Add(name, len);

			data_buf.Add(&mod, Model::SIZE);
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "objects");
		header.object_count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= header.object_count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			Object obj;

			name = Util::GetString(L, -1, "name", len);
			obj.name_index = name_buf.GetLen();
			name_buf.Add(name, len);

			lua_getfield(L, -1, "id");
			obj.id = lua_tointeger(L, -1);
			lua_pop(L, 1);

			obj.x = Util::GetFloat(L, -1, "x");
			obj.y = Util::GetFloat(L, -1, "y");
			obj.z = Util::GetFloat(L, -1, "z");
			obj.rotation_x = Util::GetFloat(L, -1, "rotation_x");
			obj.rotation_y = Util::GetFloat(L, -1, "rotation_y");
			obj.rotation_z = Util::GetFloat(L, -1, "rotation_z");
			obj.scale = Util::GetFloat(L, -1, "scale");

			data_buf.Add(&obj, Object::SIZE);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "regions");
		header.region_count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= header.region_count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			Region reg;

			name = Util::GetString(L, -1, "name", len);
			reg.name_index = name_buf.GetLen();
			name_buf.Add(name, len);

			reg.center_x = Util::GetFloat(L, -1, "center_x");
			reg.center_y = Util::GetFloat(L, -1, "center_y");
			reg.center_z = Util::GetFloat(L, -1, "center_z");

			reg.unknownA = Util::GetFloat(L, -1, "unknownA");
			lua_getfield(L, -1, "unknownB");
			double val = lua_tonumber(L, -1);
			lua_pop(L, 1);
			reg.unknownB = static_cast<uint32>(val);
			reg.unknownC = Util::GetInt(L, -1, "unknownC");

			reg.extent_x = Util::GetFloat(L, -1, "extent_x");
			reg.extent_y = Util::GetFloat(L, -1, "extent_y");
			reg.extent_z = Util::GetFloat(L, -1, "extent_z");

			data_buf.Add(&reg, Region::SIZE);
			lua_pop(L, 1);
		}
		lua_pop(L, 1);

		lua_getfield(L, 1, "lights");
		header.light_count = lua_objlen(L, -1);
		for (uint32 i = 1; i <= header.light_count; ++i)
		{
			lua_pushinteger(L, i);
			lua_gettable(L, -2);

			Light light;

			name = Util::GetString(L, -1, "name", len);
			light.name_index = name_buf.GetLen();
			name_buf.Add(name, len);

			light.x = Util::GetFloat(L, -1, "x");
			light.y = Util::GetFloat(L, -1, "y");
			light.z = Util::GetFloat(L, -1, "z");
			light.r = Util::GetFloat(L, -1, "r");
			light.g = Util::GetFloat(L, -1, "g");
			light.b = Util::GetFloat(L, -1, "b");
			light.radius = Util::GetFloat(L, -1, "radius");

			data_buf.Add(&light, Light::SIZE);
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

	int EQGize(lua_State* L)
	{
		const char* path = luaL_checkstring(L, 1);

		FILE* fp = fopen(path, "rb");
		if (fp == nullptr)
			return luaL_argerror(L, 1, "could not open specified path for reading");

		fseek(fp, 0, SEEK_END);
		uint32 len = ftell(fp);
		fseek(fp, 0, SEEK_SET);
		byte* data = new byte[len];
		fread(data, sizeof(byte), len, fp);
		fclose(fp);

		lua_createtable(L, 0, 1);
		lua_pushlightuserdata(L, data);
		lua_setfield(L, -2, "ptr");

		return 1;
	}

	static const luaL_Reg funcs[] = {
		{"Read", Read},
		{"Write", Write},
		{"EQGize", EQGize},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "zon", funcs);
	}
}
