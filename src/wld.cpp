
#include "wld.h"

namespace WLD
{
	void DecodeString(byte* str, size_t len)
	{
		static byte hashval[] = {0x95, 0x3A, 0xC5, 0x2A, 0x95, 0x7A, 0x95, 0x6A};
		for (size_t i = 0; i < len; ++i)
		{
			str[i] ^= hashval[i & 7];
		}
	}

	int Read(lua_State* L)
	{
		char magic[] = {0x02, 0x3D, 0x50, 0x54};
		byte* ptr = Util::CheckHeader(L, magic, ".wld");

		Header* header = (Header*)ptr;
		uint32 pos = Header::SIZE;

		header->version &= 0xFFFFFFFE;
		if (header->version != Header::VERSION1 && header->version != Header::VERSION2)
			return luaL_argerror(L, 1, "data is not a valid .wld version");
		int ver = (header->version == Header::VERSION1) ? 1 : 2;

		byte* raw_strings = &ptr[pos];
		DecodeString(raw_strings, header->strings_len);
		const char* string_block = (char*)raw_strings;
		pos += header->strings_len;

		std::vector<FragHeader*> frag_list;
		std::unordered_map<std::string, FragHeader*> frag_hash;
		std::unordered_set<Frag03*> decoded_names;

		lua_newtable(L); //vertices, -2
		lua_newtable(L); //triangles, -1

		for (uint32 i = 0; i < header->frag_count; ++i)
		{
			FragHeader* fh = (FragHeader*)&ptr[pos];
			frag_list.push_back(fh);
			pos += FragHeader::SIZE;

			switch (fh->type)
			{
			case 0x36: //mesh fragment
			{
				MeshFrag* mf = (MeshFrag*)&ptr[pos];
				if (mf->vert_count != mf->normal_count)
					return luaL_error(L, "mesh fragment %d had vertex mismatch: %d, %d",
						i, mf->vert_count, mf->normal_count);

				uint32 count = mf->vert_count;
				uint32 p = pos + MeshFrag::SIZE;
				uint32 tbl_pos = lua_objlen(L, -2);
				uint32 base_vertex = tbl_pos;

				float scale = 1.0f / (1 << mf->scale);
				float uv_scale = 1.0f / 256.0f;
				float normal_scale = 1.0f / 127.0f;
				RawVertex* vert = (RawVertex*)&ptr[p];
				p += RawVertex::SIZE * count;

				if (mf->uv_count == 0)
				{
					RawNormal* norm = (RawNormal*)&ptr[p];
					p += RawNormal::SIZE * count;

					for (uint32 j = 1; j <= count; ++j)
					{
						lua_pushinteger(L, ++tbl_pos);
						lua_createtable(L, 0, 8);

						lua_pushnumber(L, Util::FloatToDouble(mf->x + (float)vert->x * scale));
						lua_setfield(L, -2, "x");
						lua_pushnumber(L, Util::FloatToDouble(mf->y + (float)vert->y * scale));
						lua_setfield(L, -2, "y");
						lua_pushnumber(L, Util::FloatToDouble(mf->z + (float)vert->z * scale));
						lua_setfield(L, -2, "z");
						vert = (RawVertex*)((byte*)vert + RawVertex::SIZE);

						lua_pushnumber(L, 0);
						lua_setfield(L, -2, "u");
						lua_pushnumber(L, 0);
						lua_setfield(L, -2, "v");

						lua_pushnumber(L, Util::FloatToDouble((float)norm->i * normal_scale));
						lua_setfield(L, -2, "i");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->j * normal_scale));
						lua_setfield(L, -2, "j");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->k * normal_scale));
						lua_setfield(L, -2, "k");
						norm = (RawNormal*)((byte*)norm + RawNormal::SIZE);

						lua_settable(L, -4);
					}
				}
				else if (ver == 1)
				{
					RawUV16* uv = (RawUV16*)&ptr[p];
					p += RawUV16::SIZE * count;
					RawNormal* norm = (RawNormal*)&ptr[p];
					p += RawNormal::SIZE * count;

					for (uint32 j = 1; j <= count; ++j)
					{
						lua_pushinteger(L, ++tbl_pos);
						lua_createtable(L, 0, 8);

						lua_pushnumber(L, Util::FloatToDouble(mf->x + (float)vert->x * scale));
						lua_setfield(L, -2, "x");
						lua_pushnumber(L, Util::FloatToDouble(mf->y + (float)vert->y * scale));
						lua_setfield(L, -2, "y");
						lua_pushnumber(L, Util::FloatToDouble(mf->z + (float)vert->z * scale));
						lua_setfield(L, -2, "z");
						vert = (RawVertex*)((byte*)vert + RawVertex::SIZE);

						lua_pushnumber(L, Util::FloatToDouble((float)uv->u * uv_scale));
						lua_setfield(L, -2, "u");
						lua_pushnumber(L, Util::FloatToDouble((float)uv->v * uv_scale));
						lua_setfield(L, -2, "v");
						uv = (RawUV16*)((byte*)uv + RawUV16::SIZE);

						lua_pushnumber(L, Util::FloatToDouble((float)norm->i * normal_scale));
						lua_setfield(L, -2, "i");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->j * normal_scale));
						lua_setfield(L, -2, "j");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->k * normal_scale));
						lua_setfield(L, -2, "k");
						norm = (RawNormal*)((byte*)norm + RawNormal::SIZE);

						lua_settable(L, -4);
					}
				}
				else
				{
					RawUV32* uv = (RawUV32*)&ptr[p];
					p += RawUV32::SIZE * count;
					RawNormal* norm = (RawNormal*)&ptr[p];
					p += RawNormal::SIZE * count;

					for (uint32 j = 1; j <= count; ++j)
					{
						lua_pushinteger(L, ++tbl_pos);
						lua_createtable(L, 0, 8);

						lua_pushnumber(L, Util::FloatToDouble(mf->x + (float)vert->x * scale));
						lua_setfield(L, -2, "x");
						lua_pushnumber(L, Util::FloatToDouble(mf->y + (float)vert->y * scale));
						lua_setfield(L, -2, "y");
						lua_pushnumber(L, Util::FloatToDouble(mf->z + (float)vert->z * scale));
						lua_setfield(L, -2, "z");
						vert = (RawVertex*)((byte*)vert + RawVertex::SIZE);

						lua_pushnumber(L, Util::FloatToDouble((float)uv->u));
						lua_setfield(L, -2, "u");
						lua_pushnumber(L, Util::FloatToDouble((float)uv->v));
						lua_setfield(L, -2, "v");
						uv = (RawUV32*)((byte*)uv + RawUV32::SIZE);

						lua_pushnumber(L, Util::FloatToDouble((float)norm->i * normal_scale));
						lua_setfield(L, -2, "i");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->j * normal_scale));
						lua_setfield(L, -2, "j");
						lua_pushnumber(L, Util::FloatToDouble((float)norm->k * normal_scale));
						lua_setfield(L, -2, "k");
						norm = (RawNormal*)((byte*)norm + RawNormal::SIZE);

						lua_settable(L, -4);
					}
				}

				//skip vertex colors
				p += sizeof(uint32) * mf->color_count;

				count = mf->poly_count;
				tbl_pos = lua_objlen(L, -1);
				uint32 base_triangle = tbl_pos;

				for (uint32 j = 1; j <= count; ++j)
				{
					RawTriangle* tri = (RawTriangle*)&ptr[p];
					p += RawTriangle::SIZE;

					lua_pushinteger(L, ++tbl_pos);
					lua_createtable(L, 3, 1);

					for (uint32 a = 0; a < 3; ++a)
					{
						lua_pushinteger(L, a + 1);
						lua_pushinteger(L, base_vertex + tri->index[a]);
						lua_settable(L, -3);
					}

					lua_settable(L, -3);
				}

				//skip vertex pieces
				p += sizeof(uint16) * 2 * mf->vert_piece_count;

				//find texture names
				std::vector<const char*> texture_list;
				//0x31 -> 0x30 -> 0x05 -> 0x04 -> 0x03
				Frag31* f31 = (Frag31*)frag_list[mf->texture_list_ref - 1];
				int* ref_list = (int*)((byte*)f31 + Frag31::SIZE);
				count = f31->ref_count;
				for (uint32 j = 0; j < count; ++j)
				{
					Frag03* f03;
					Frag30* f30 = (Frag30*)frag_list[(*ref_list++) - 1];

					if (f30->ref > 0)
					{
						Frag05* f05 = (Frag05*)frag_list[f30->ref - 1];
						Frag04* f04 = (Frag04*)frag_list[f05->ref - 1];
						f03 = (Frag03*)frag_list[f04->ref - 1];
					}
					else
					{
						int index = (f30->ref == 0) ? 1 : -f30->ref;
						const char* name = &string_block[index];
						f03 = (Frag03*)frag_hash[name];
					}

					if (f03->len > 0)
					{
						if (decoded_names.count(f03) == 0)
						{
							DecodeString(f03->string, f03->len);
							decoded_names.insert(f03);
						}
						texture_list.push_back((char*)f03->string);
					}
				}

				count = mf->poly_texture_count;
				for (uint32 j = 0; j < count; ++j)
				{
					RawTextureEntry* te = (RawTextureEntry*)&ptr[p];
					p += RawTextureEntry::SIZE;

					for (uint16 z = 0; z < te->count; ++z)
					{
						lua_pushinteger(L, ++base_triangle);
						lua_gettable(L, -2);

						lua_pushstring(L, texture_list[te->index]);
						lua_setfield(L, -2, "texture");

						lua_pop(L, 1);
					}
				}
				break;
			}
			case 0x03:
			{
				int nameref = *(int*)&ptr[pos];
				if (nameref < 0)
				{
					std::string name = &string_block[-nameref];
					frag_hash[name] = fh;
				}
				break;
			}
			default:
				break;
			}

			pos += fh->len;
		}

		return 2;
	}

	static const luaL_Reg funcs[] = {
		{"Read", Read},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "wld", funcs);
	}
}
