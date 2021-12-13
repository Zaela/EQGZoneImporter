EQEmu Zone Importer

# Usage
- Textures must be in same directory as .obj file for import, due to how referencing is built inside EQG
- eqgzi.exe is a command line tool, e.g. eqgzi.exe import c:\src\demoncia\client\rof\_tutorialb.eqg\tutorialb.obj  c:\src\demoncia\client\rof\tutorialb.eqg
- 

# Adding Regions
- In blender, create a new empty cube. 
- Cube's name needs to have a prefix, e.g. AWT_: water, ALV_: lava, APK_: pvp, ATP_: zoneline, ASL_: ice, APV_: generic
- Adding custom properties is how you set unknown values, prop = unk1, prop1 = unk2, prop2 = unk3

# Setup for new dependencies
- Download CMake
- Configure, set to 
- in command prompt:
- git clone https://github.com/Microsoft/vcpkg.git
- vcpkg install lua:x86-windows
- vcpkg install irrlicht:x86-windows


lua requirements for cmake:
    find_package(Lua REQUIRED)
    target_include_directories(main PRIVATE ${LUA_INCLUDE_DIR})
    target_link_libraries(main PRIVATE ${LUA_LIBRARIES})
irrlicht requirements for cmake:
    find_package(irrlicht CONFIG REQUIRED)
    target_link_libraries(main PRIVATE Irrlicht)