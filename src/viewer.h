
#include <cstdio>
#include <cstring>
#include <thread>
#include <atomic>
#include <chrono>
#include <unordered_map>
#include <lua.hpp>
#include <irrlicht.h>
#include <FreeImagePlus.h>
#include "types.h"
#include "util.h"
#include <cmath>

using namespace irr;

namespace Viewer
{
	void LoadFunctions(lua_State* L);

	class CameraController : public IEventReceiver
	{
	public:
		CameraController() : mMovespeed(150.0f), mMoveDirection(MOVE_NONE), mTurnDirection(TURN_NONE),
			mHasMoved(true), mMouseDown(false), mRelX(0), mRelY(0)
		{
	
		}

		bool CheckMoved()
		{
			if (mHasMoved)
			{
				mHasMoved = false;
				return true;
			}
			return false;
		}

		void ApplyMovement(float delta);

		void SetPtrs(IrrlichtDevice* device, scene::ICameraSceneNode* camera)
		{
			mDevice = device;
			mCamera = camera;
		}

		virtual bool OnEvent(const SEvent& ev) override;
		bool HandleKeyboardInput(const SEvent::SKeyInput& ev);
		bool HandleMouseInput(const SEvent::SMouseInput& ev);

	private:
		float mMovespeed;
		int8 mMoveDirection;
		int8 mTurnDirection;
		IrrlichtDevice* mDevice;
		scene::ICameraSceneNode* mCamera;
		bool mHasMoved;
		bool mMouseDown;
		float mMouseX;
		float mMouseY;
		float mRelX;
		float mRelY;

		enum Movement
		{
			MOVE_FORWARD = -1,
			MOVE_NONE,
			MOVE_BACKWARD
		};

		enum Turn
		{
			TURN_LEFT = -1,
			TURN_NONE,
			TURN_RIGHT
		};
	};

	class ImageFile : public io::IReadFile
	{
	public:
		ImageFile(const char* name, byte* data, uint32 len) :
			mName(name), mData(data), mLength(len), mPos(0)
		{

		}

		~ImageFile()
		{
			if (mData)
				delete[] mData;
		}

		virtual const io::path& getFileName() const
		{
			return mName;
		}

		virtual long getPos() const
		{
			return mPos;
		}

		virtual long getSize() const
		{
			return mLength;
		}

		virtual int32 read(void* buffer, uint32 sizeToRead)
		{
			long read = mPos + sizeToRead;
			if (read >= mLength)
				sizeToRead = mLength - mPos;
			memcpy(buffer, &mData[mPos], sizeToRead);
			mPos = read;
			return sizeToRead;
		}

		virtual bool seek(long finalPos, bool relativeMovement = false)
		{
			if (relativeMovement)
				finalPos += mPos;
			if (finalPos >= mLength)
				return false;
			mPos = finalPos;
			return true;
		}

	private:
		irr::io::path mName;
		byte* mData;
		long mLength;
		long mPos;
	};
}
