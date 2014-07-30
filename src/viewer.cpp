
#include "viewer.h"

using namespace irr;

extern std::thread* gViewerThread;
extern std::atomic_flag gRunThread;

namespace Viewer
{
	void ThreadMain(uint32 w, uint32 h, scene::SAnimatedMesh* anim, std::vector<ImageFile*>* images)
	{
		CameraController control;

		IrrlichtDevice* device = createDevice(video::EDT_OPENGL,
			core::dimension2du(w, h), 16, false, false, true, &control);

		if (device == nullptr)
		{
			gRunThread.clear();
			return;
		}

		device->setWindowCaption(L"EQG Zone Viewer");
		scene::ISceneManager* mgr = device->getSceneManager();
		video::IVideoDriver* driver = device->getVideoDriver();

		uint32 i = 0;
		for (ImageFile* file : *images)
		{
			if (file)
			{
				video::ITexture* tex = driver->getTexture(file);
				if (tex)
					anim->getMeshBuffer(i)->getMaterial().setTexture(0, tex);
				file->drop();
			}
			++i;
		}

		delete images;

		mgr->addOctreeSceneNode(anim);
		anim->drop();

		scene::ICameraSceneNode* cam = mgr->addCameraSceneNode();
		cam->bindTargetAndRotation(true);
		control.SetPtrs(device, cam);

		mgr->setAmbientLight(video::SColorf(1, 1, 1));
		ITimer* timer = device->getTimer();
		timer->setTime(0);

		while (device->run())
		{
			if (gRunThread.test_and_set() == false)
				break;

			float delta = timer->getTime() / 1000.0f;
			timer->setTime(0);

			if (device->isWindowActive() && device->isWindowFocused())
			{
				control.ApplyMovement(delta);

				if (control.CheckMoved())
				{
					driver->beginScene(true, true, video::SColor(255, 128, 128, 128));
					mgr->drawAll();
					driver->endScene();
				}
			}

			std::this_thread::sleep_for(std::chrono::milliseconds(20));
		}

		device->drop();
		gRunThread.clear();
	}

	bool CameraController::OnEvent(const SEvent& ev)
	{
		switch (ev.EventType)
		{
		case EET_KEY_INPUT_EVENT:
		{
			return HandleKeyboardInput(ev.KeyInput);
		}
		case EET_MOUSE_INPUT_EVENT:
		{
			return HandleMouseInput(ev.MouseInput);
		}
		default:
			break;
		}

		return false;
	}

	void CameraController::ApplyMovement(float delta)
	{
		core::vector3df pos = mCamera->getPosition();

		// Update rotation
		core::vector3df target = (mCamera->getTarget() - mCamera->getAbsolutePosition());
		core::vector3df relativeRotation = target.getHorizontalAngle();

		relativeRotation.Y += mRelX;
		relativeRotation.X += mRelY;

		if (!mMouseDown && mTurnDirection != TURN_NONE)
		{
			relativeRotation.Y += delta * 100 * mTurnDirection;
			mHasMoved = true;
		}

		target.set(0,0, core::max_(1.f, pos.getLength()));

		core::matrix4 mat;
		mat.setRotationDegrees(core::vector3df(relativeRotation.X, relativeRotation.Y, 0));
		mat.transformVect(target);

		core::vector3df movedir = target;
		movedir.normalize();

		if (mMoveDirection != MOVE_NONE)
		{
			pos -= movedir * delta * mMovespeed * mMoveDirection;
			mHasMoved = true;
		}

		if (mMouseDown && mTurnDirection != TURN_NONE)
		{
			core::vector3df strafevect = target;
			strafevect = strafevect.crossProduct(mCamera->getUpVector());
			strafevect.normalize();

			pos -= strafevect * delta * mMovespeed * mTurnDirection;
			mHasMoved = true;
		}

		// write translation
		mCamera->setPosition(pos);

		// write right target
		target += pos;
		mCamera->setTarget(target);

		mRelX = 0;
		mRelY = 0;
	}

	bool CameraController::HandleKeyboardInput(const SEvent::SKeyInput& ev)
	{
		switch (ev.Key)
		{
		case KEY_UP:
			if (ev.PressedDown)
				mMoveDirection = MOVE_FORWARD;
			else if (mMoveDirection == MOVE_FORWARD)
				mMoveDirection = MOVE_NONE;
			break;
		case KEY_DOWN:
			if (ev.PressedDown)
				mMoveDirection = MOVE_BACKWARD;
			else if (mMoveDirection == MOVE_BACKWARD)
				mMoveDirection = MOVE_NONE;
			break;
		case KEY_LEFT:
			if (ev.PressedDown)
				mTurnDirection = TURN_LEFT;
			else if (mTurnDirection == TURN_LEFT)
				mTurnDirection = TURN_NONE;
			break;
		case KEY_RIGHT:
			if (ev.PressedDown)
				mTurnDirection = TURN_RIGHT;
			else if (mTurnDirection == TURN_RIGHT)
				mTurnDirection = TURN_NONE;
			break;
		case KEY_ESCAPE:
			mDevice->closeDevice();
			break;
		default:
			break;
		}

		return false;
	}

	bool CameraController::HandleMouseInput(const SEvent::SMouseInput& ev)
	{
		switch (ev.Event)
		{
		case EMIE_RMOUSE_PRESSED_DOWN:
			mMouseDown = true;
			break;
		case EMIE_RMOUSE_LEFT_UP:
			mMouseDown = false;
			break;
		case EMIE_MOUSE_MOVED:
			if (mMouseDown)
			{
				mRelX += ev.X - mMouseX;
				mRelY += ev.Y - mMouseY;
				mHasMoved = true;
			}
			mMouseX = ev.X;
			mMouseY = ev.Y;
			break;
		default:
			break;
		}

		return false;
	}

	ImageFile* CreateImageFile(lua_State* L, int tbl, int mat, bool& cur_dds)
	{
		lua_pushinteger(L, mat + 1);
		lua_gettable(L, tbl);

		if (!lua_istable(L, -1))
		{
			lua_pop(L, 1);
			return nullptr;
		}

		lua_getfield(L, -1, "ptr");
		byte* data = (byte*)lua_touserdata(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, -1, "inflated_len");
		uint32 len = lua_tointeger(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, -1, "png_name");
		const char* name = lua_tostring(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, -1, "isDDS");
		cur_dds = lua_toboolean(L, -1);
		lua_pop(L, 1);

		fipMemoryIO mem(data, len);
		fipImage img;
		img.loadFromMemory(mem);
		fipMemoryIO out;
		img.saveToMemory(FIF_PNG, out);

		out.seek(0, SEEK_END);
		unsigned long size = out.tell();
		out.seek(0, SEEK_SET);
		byte* ptr = new byte[size];
		out.read(ptr, 1, size);

		lua_pop(L, 1);
		return new ImageFile(name, ptr, size);
	}

	int LoadZone(lua_State* L)
	{
		//vertices, triangles, decompressed textures
		luaL_checktype(L, 1, LUA_TTABLE);
		luaL_checktype(L, 2, LUA_TTABLE);

		int vert_count = Util::GetInt(L, 1, "count");
		lua_getfield(L, 1, "data");
		byte* vert_data = (byte*)lua_touserdata(L, -1);
		lua_pop(L, 1);

		int tri_count = Util::GetInt(L, 2, "count");
		lua_getfield(L, 2, "data");
		byte* tri_data = (byte*)lua_touserdata(L, -1);
		lua_pop(L, 1);
		uint32 pos = 0;

		int cur_mat = -9999;
		bool cur_dds = false;

		std::unordered_map<int, ImageFile*> image_by_mat;
		std::vector<ImageFile*>* images = new std::vector<ImageFile*>;
		scene::SMeshBuffer* cur_buf = new scene::SMeshBuffer;
		scene::SMesh* mesh = new scene::SMesh;

		for (int i = 0; i < tri_count; ++i)
		{
			Triangle* tri = (Triangle*)&tri_data[pos];
			pos += Triangle::SIZE;

			if (tri->material != cur_mat || cur_buf->Indices.size() > 65530)
			{
				cur_mat = tri->material;
				if (cur_mat >= 0)
				{
					if (cur_buf->getVertexCount() > 0)
					{
						cur_buf->recalculateBoundingBox();
						mesh->addMeshBuffer(cur_buf);
						cur_buf->drop();
						cur_buf = new scene::SMeshBuffer;
					}

					ImageFile* add_image;
					if (image_by_mat.count(cur_mat))
					{
						add_image = image_by_mat[cur_mat];
						if (add_image)
							add_image->grab();
					}
					else
					{
						add_image = CreateImageFile(L, 3, cur_mat, cur_dds);
						image_by_mat[cur_mat] = add_image;
					}

					images->push_back(add_image);
				}
			}

			//make triangle! laziness: no vertices are reused to avoid headache of re-indexing
			auto& indices = cur_buf->Indices;
			uint16 idx = indices.size();
			indices.push_back(idx);
			indices.push_back(idx + 1);
			indices.push_back(idx + 2);

			auto& verts = cur_buf->Vertices;

			//get vertices based on actual index
			for (int j = 2; j >= 0; --j)
			{
				uint32 index = tri->index[j];
				Vertex* v = (Vertex*)&vert_data[index * Vertex::SIZE];

				video::S3DVertex vert;
				vert.Pos.X = v->x;
				vert.Pos.Z = v->y;
				vert.Pos.Y = v->z;
				vert.Normal.X = v->i;
				vert.Normal.Z = v->j;
				vert.Normal.Y = v->k;
				vert.TCoords.X = v->u;
				if (cur_dds)
					vert.TCoords.Y = (v->v > 0) ? -v->v : v->v;
				else
					vert.TCoords.Y = v->v;

				verts.push_back(vert);
			}
		}

		if (cur_buf->getVertexCount() > 0)
		{
			cur_buf->recalculateBoundingBox();
			mesh->addMeshBuffer(cur_buf);
		}
		cur_buf->drop();

		mesh->recalculateBoundingBox();

		scene::SAnimatedMesh* anim = new scene::SAnimatedMesh(mesh);
		mesh->drop();

		uint32 w = 0, h = 0;
		lua_getglobal(L, "settings");
		if (lua_istable(L, -1))
		{
			lua_getfield(L, -1, "viewer");
			if (lua_istable(L, -1))
			{
				lua_getfield(L, -1, "width");
				w = lua_tointeger(L, -1);
				lua_pop(L, 1);
				lua_getfield(L, -1, "height");
				h = lua_tointeger(L, -1);
			}
		}

		//if flag is currently false and thread ptr has a value, it is deleteable
		if (gRunThread.test_and_set() == false && gViewerThread)
			delete gViewerThread;

		gViewerThread = new std::thread(ThreadMain, (w >= 200) ? w : 600, (h >= 200) ? h : 400, anim, images);
		gViewerThread->detach();

		return 0;
	}

	int Close(lua_State* L)
	{
		gRunThread.clear();
		return 0;
	}

	static const luaL_Reg funcs[] = {
		{"LoadZone", LoadZone},
		{"Close", Close},
		{nullptr, nullptr}
	};

	void LoadFunctions(lua_State* L)
	{
		luaL_register(L, "viewer", funcs);
	}
}
