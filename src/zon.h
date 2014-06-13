
#include <lua.hpp>
#include <cstdio>
#include <cstring>
#include "types.h"
#include "util.h"

namespace ZON
{
	void LoadFunctions(lua_State* L);

	struct Header
	{
		char magic[4]; //EQGZ
		uint32 version;
		uint32 strings_len;
		uint32 model_count;
		uint32 object_count;
		uint32 region_count;
		uint32 light_count;
		static const uint32 SIZE = sizeof(uint32) * 7;
	};

	struct Model
	{
		uint32 name_index;
		static const uint32 SIZE = sizeof(uint32);
	};

	struct Object //"placeable"
	{
		int id;
		uint32 name_index;
		float x, y, z;
		float rotation_x, rotation_y, rotation_z;
		float scale;
		static const uint32 SIZE = sizeof(uint32) * 9;
	};

	struct Region
	{
		uint32 name_index;
		float center_x, center_y, center_z;
		float unknownA;
		uint32 unknownB, unknownC;
		float extent_x, extent_y, extent_z;
		static const uint32 SIZE = sizeof(uint32) * 10;
	};

	struct Light
	{
		uint32 name_index;
		float x, y, z;
		float r, b, g;
		float radius;
		static const uint32 SIZE = sizeof(float) * 8;
	};
}
