
#include <lua.hpp>
#include <cstdio>
#include <cstring>
#include "types.h"
#include "util.h"
#include "geo.h"

namespace MOD
{
	void LoadFunctions(lua_State* L);

	struct Header
	{
		char magic[4]; //EQGM
		uint32 version;
		uint32 strings_len;
		uint32 material_count;
		uint32 vertex_count;
		uint32 triangle_count;
		uint32 bone_count;
		static const uint32 SIZE = sizeof(uint32) * 7; //in case of 64bit alignment
	};

	struct Bone
	{
		uint32 name_index;
		float unknown[13];
		static const uint32 SIZE = sizeof(float) * 14;
	};

	struct BoneAssignment //not 100% that's what this is, but it would make sense
	{
		uint32 unknown[9];
		static const uint32 SIZE = sizeof(uint32) * 9;
	};
}
