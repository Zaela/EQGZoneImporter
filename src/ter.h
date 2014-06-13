
#include <lua.hpp>
#include <cstdio>
#include <cstring>
#include "types.h"
#include "util.h"
#include "geo.h"

namespace TER
{
	void LoadFunctions(lua_State* L);

	struct Header
	{
		char magic[4]; //EQGT
		uint32 version;
		uint32 strings_len;
		uint32 material_count;
		uint32 vertex_count;
		uint32 triangle_count;
		static const uint32 SIZE = sizeof(uint32) * 6;
	};
}
