CMAKE_MINIMUM_REQUIRED(VERSION 3.7)

SET(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/" ${CMAKE_MODULE_PATH})

IF(POLICY CMP0074)
	CMAKE_POLICY(SET CMP0074 NEW)
ENDIF()

PROJECT(EQZoneImporter)

IF(NOT CMAKE_BUILD_TYPE)
	SET(CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING "Choose the type of build." FORCE)
ENDIF(NOT CMAKE_BUILD_TYPE)

SET(CMAKE_CXX_STANDARD 14)
SET(CMAKE_CXX_STANDARD_REQUIRED ON)
SET(CMAKE_CXX_EXTENSIONS OFF)

IF(MSVC)
	ADD_DEFINITIONS(-D_CRT_SECURE_NO_WARNINGS)
	ADD_DEFINITIONS(-DNOMINMAX)
	ADD_DEFINITIONS(-DCRASH_LOGGING)
	
	SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")
ELSE(MSVC)
	ADD_DEFINITIONS(-DHAS_UNION_SEMUN)
ENDIF(MSVC)


#MSVC can fetch dependencies automatically.
IF(MSVC)
	INCLUDE("${CMAKE_SOURCE_DIR}/cmake/DependencyHelperMSVC.cmake")
ENDIF()

FILE(GLOB SRCS src/*.cpp)
FILE(GLOB HDRS include/*.h)

add_executable(main ${SRCS} ${HDRS})

find_package(Lua REQUIRED)
target_include_directories(main PRIVATE 
	${LUA_INCLUDE_DIR}
	${PROJECT_SOURCE_DIR}/dependencies/freeimage-3.18.0/include
	${PROJECT_SOURCE_DIR}/dependencies/irrlicht-1.8.4/include
	${PROJECT_SOURCE_DIR}/dependencies/irrlicht-1.8.4/include/irrlicht
)

add_library(iup SHARED IMPORTED)
set_target_properties(iup PROPERTIES
    IMPORTED_LOCATION "${PROJECT_SOURCE_DIR}/dependencies/iup-3.3.0/lib/iuplua51.dll"
    IMPORTED_IMPLIB "${PROJECT_SOURCE_DIR}/dependencies/iup-3.3.0/lib/iuplua51.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${PROJECT_SOURCE_DIR}/dependencies/iup-3.3.0/include"
)

target_link_libraries(main 
	iup
	${LUA_LIBRARIES}
	${PROJECT_SOURCE_DIR}/dependencies/irrlicht-1.8.4/lib/Irrlicht.lib
	${PROJECT_SOURCE_DIR}/dependencies/freeimage-3.18.0/lib/FreeImage.lib
)
