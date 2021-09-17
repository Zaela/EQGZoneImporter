EQEmu Zone Importer

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