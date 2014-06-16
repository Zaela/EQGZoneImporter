
#include <lua.hpp>
#include <cstdio>
#include <cstring>
#include <vector>
#include <unordered_map>
#include <unordered_set>
#include <string>
#include "types.h"
#include "util.h"

namespace WLD
{
	void LoadFunctions(lua_State* L);

	struct Header
	{
		char magic[4];
		uint32 version;
		uint32 frag_count;
		uint32 unknownA[2];
		uint32 strings_len;
		uint32 unknownB;
		static const uint32 SIZE = sizeof(uint32) * 7;
		static const uint32 VERSION1 = 0x00015500;
		static const uint32 VERSION2 = 0x1000C800;
	};

	struct FragHeader
	{
		uint32 len;
		uint32 type;
		static const uint32 SIZE = sizeof(uint32) * 2;
	};

	struct MeshFrag
	{
		int nameref;
		uint32 flag;
		int texture_list_ref;
		int anim_vert_ref;
		uint32 unknownA[2];
		float x, y, z;
		float rotation[3];
		float unusedA[7];
		uint16 vert_count;
		uint16 uv_count;
		uint16 normal_count;
		uint16 color_count;
		uint16 poly_count;
		uint16 vert_piece_count;
		uint16 poly_texture_count;
		uint16 vert_texture_count;
		uint16 size9;
		uint16 scale;
		static const uint32 SIZE = sizeof(uint16) * 10 + sizeof(uint32) * 19;
	};

	struct RawVertex
	{
		int16 x, y, z;
		static const uint32 SIZE = sizeof(int16) * 3;
	};

	struct RawUV16
	{
		int16 u, v;
		static const uint32 SIZE = sizeof(int16) * 2;
	};

	struct RawUV32
	{
		int32 u, v;
		static const uint32 SIZE = sizeof(int32) * 2;
	};

	struct RawNormal
	{
		int8 i, j, k;
		static const uint32 SIZE = sizeof(int8) * 3;
	};

	struct RawTriangle
	{
		uint16 flag;
		uint16 index[3];
		static const uint32 SIZE = sizeof(uint16) * 4;
	};

	struct RawTextureEntry
	{
		uint16 count;
		uint16 index;
		static const uint32 SIZE = sizeof(uint16) * 2;
	};

	struct Frag31
	{
		FragHeader header;
		int nameref;
		uint32 flag;
		uint32 ref_count;
		static const uint32 SIZE = FragHeader::SIZE + sizeof(uint32) * 3;
	};

	struct Frag30
	{
		FragHeader header;
		int nameref;
		uint32 flag;
		uint32 visibility_flag;
		uint32 unknown[3];
		int ref;
	};

	struct Frag05
	{
		FragHeader header;
		int nameref;
		int ref;
		uint32 flag;
	};

	struct Frag04
	{
		FragHeader header;
		int nameref;
		uint32 flag;
		int count;
		//uint32 unknown[2];
		int ref; //ignoring additional refs (animated textures)
		//static const uint32 SIZE = FragHeader::SIZE + sizeof(uint32) * 5;
	};

	struct Frag03
	{
		FragHeader header;
		int nameref;
		int count;
		uint16 len;
		byte string[2];
	};
}
