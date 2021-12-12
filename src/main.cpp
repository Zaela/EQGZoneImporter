
#include <lua.hpp>
#include <cstdio>
#include <irrlicht.h>
#include <thread>
#include <atomic>
#include <vector>

#include <iup.h>
#include <iuplua.h>
#include <iupcontrols.h>
#include <iupluacontrols.h>

extern "C" { FILE __iob_func[3] = { *stdin,*stdout,*stderr }; }

#include "ter.h"
#include "zon.h"
#include "mod.h"
#include "wld.h"
#include "viewer.h"
#include "util.h"
#include "types.h"

#ifdef _WIN32
#include <windows.h>
#endif

//globals
std::thread* gViewerThread;
std::atomic_flag gRunThread;

void ShowError(const char* fmt, const char* str)
{
#if defined _WIN32 && !_CONSOLE
		char msg[1024];
		snprintf(msg, 1024, fmt, str);
		MessageBox(NULL, msg, NULL, MB_OK | MB_ICONERROR | MB_TASKMODAL);
#else
		printf(fmt, str);
#endif
}

#if defined _WIN32 && !_CONSOLE
int CALLBACK WinMain(_In_ HINSTANCE hInstance, _In_ HINSTANCE hPrevInstance,
	_In_ LPSTR lpCmdLine, _In_ int nCmdShow)
{	
	int argc = 0; 
	char** argv = NULL;
	argc = __argc;
	argv = __argv;

#else
int main(int argc, char *argv[])
{
#endif
	gViewerThread = nullptr;
	gRunThread.clear();

	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	IupOpen(nullptr, nullptr);
	IupControlsOpen();
	iuplua_open(L);
	iupcontrolslua_open(L);

	TER::LoadFunctions(L);
	ZON::LoadFunctions(L);
	MOD::LoadFunctions(L);
	WLD::LoadFunctions(L);
	Viewer::LoadFunctions(L);
	Util::LoadFunctions(L);

#if defined _CONSOLE
	if (argc > 1 && strlen(argv[1]) > 0) {
		if (luaL_loadfile(L, "gui/main_cmd.lua") != 0) {
			ShowError("Could not load GUI script:\n%s\n", lua_tostring(L, -1));
			lua_close(L);
			return 1;
		}
		
		if (lua_pcall(L, 0, 0, 0) != 0) {
			ShowError("main_cmd.lua error:\n%s\n", lua_tostring(L, -1));
			lua_close(L);
			return 1;
		}

		lua_getglobal(L, "main_cmd");
		for (int i = 1; i < argc; i++) {
			lua_pushstring(L, argv[i]);
		}
		if (lua_pcall(L, argc - 1, 0, 0) != 0) {
			ShowError("main_cmd error:\n%s\n", lua_tostring(L, -1));
			lua_close(L);
			return 1;
		}

		return 0;
	}
	ShowError("usage: eqgzi import \".eqg\" \".obj\"", "");
	return 1;
#endif
	if (luaL_loadfile(L, "gui/main.lua") != 0)
	{
		ShowError("Could not load GUI script:\n%s\n", lua_tostring(L, -1));
	}
	else if (lua_pcall(L, 0, 0, 0) != 0)
	{
		ShowError("Runtime error:\n%s\n", lua_tostring(L, -1));
	}

	lua_close(L);
	return 0;
}
