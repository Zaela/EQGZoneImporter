
#ifndef GEO_H
#define GEO_H

#include "types.h"

struct Material
{
	uint32 index;
	uint32 name_index;
	uint32 shader_index;
	uint32 property_count;
	static const uint32 SIZE = sizeof(uint32) * 4;
};

struct Property
{
	uint32 name_index;
	uint32 type;
	union
	{
		uint32 i;
		float f;
	} value;
	static const uint32 SIZE = sizeof(uint32) * 3;
};

struct Vertex
{
	float x, y, z;
	float i, j, k;
	float u, v;
	static const uint32 SIZE = sizeof(float) * 8;
};

struct VertexV3
{
	float x, y, z;
	float i, j, k;
	uint32 color;
	float unknown[2];
	float u, v;
	static const uint32 SIZE = sizeof(float) * 11;
};

struct Triangle
{
	uint32 index[3];
	int material;
	uint32 flag;
	static const uint32 SIZE = sizeof(uint32) * 5;
};

#endif
