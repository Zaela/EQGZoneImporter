
#ifndef UTIL_H
#define UTIL_H

#include "types.h"
#include "geo.h"
#include <cstdio>
#include <cstring>
#include <unordered_map>
#include <lua.hpp>

namespace Util
{
	void LoadFunctions(lua_State* L);
	class Buffer;

	byte* CheckHeader(lua_State* L, const char* magic, const char* err_name);
	void PrepareWrite(lua_State* L, const char* err_name);
	int FinishWrite(lua_State* L, Buffer& buf);

	double FloatToDouble(float val);
	uint32 GetInt(lua_State* L, int index, const char* name);
	uint32 GetInt(lua_State* L, int index, int pos);
	float GetFloat(lua_State* L, int index, const char* name);
	const char* GetString(lua_State* L, int index, const char* name, uint32& len);
	const char* GetString(lua_State* L, int index, const char* name);

	void WriteGeometry(lua_State* L, Buffer& data_buf, Buffer& name_buf,
		uint32& mat_count, uint32& vert_count, uint32& tri_count);

	class Buffer
	{
	public:
		Buffer();
		void Add(const void* in_data, uint32 len);
		byte* Take();
		uint32 GetLen() { return mLen; }
	private:
		uint32 mLen;
		uint32 mCap;
		byte* mData;
	};

	typedef std::unordered_map<const char*, uint32> FoundNamesMap;

	uint32 AddName(lua_State* L, const char* id, Buffer& name_buf, FoundNamesMap& found_names);
}

#endif//UTIL_H
