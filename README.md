EQEmu Zone Importer

# TODO
- Fix normals being defined inside a custom property, to properly inject the material into the eqg
- Figure out regions and why extents don't properly align
- 

# Usage
- Textures must be in same directory as .obj file for import, due to how referencing is built inside EQG
- eqgzi.exe is a command line tool, e.g. eqgzi.exe import c:\src\demoncia\client\rof\_tutorialb.eqg\tutorialb.obj  c:\src\demoncia\client\rof\tutorialb.eqg
- 

# Adding Regions
- In blender, create a new empty cube. 
- Cube's name needs to have a prefix, e.g. AWT_: water, ALV_: lava, APK_: pvp, ATP_: zoneline, ASL_: ice, APV_: generic
- Adding custom properties is how you set unknown values, prop = unk1, prop1 = unk2, prop2 = unk3
- Material custom properties:
    - flag: GoD uses 262144
    - shader: By default this is set to Opaque_MaxCB1.fx, but can be overwritten


# Material Properties

e_TextureDiffuse0 = 2,
	e_TextureNormal0 = 2,
	e_TextureCoverage0 = 2,
	e_TextureEnvironment0 = 2,
	e_TextureGlow0 = 2,
	e_fShininess0 = 0,
	e_fBumpiness0 = 0,
	e_fEnvMapStrength0 = 0,
	e_fFresnelBias = 0,
	e_fFresnelPower = 0,
	e_fWaterColor1 = 3,
	e_fWaterColor2 = 3,
	e_fReflectionAmount = 0,
	e_fReflectionColor = 3,

key: Name Type Value
lavaglow from broodlands:
    e_fShininess0 0 1
waterfalls from broodlands:
    e_fSlide1X 0 -0.12
    e_fSlide1Y 0 -0.32
    e_fSlide2X 0 0
    e_fSlide2Y 0 -0.5
watertable from broodlands:
    e_TextureDiffuse0 2 rc_cavewater_c.dds
    e_TextureNormal0 2 rc_cavewater_n.dds
    e_TextureEnvironment0 2 ra_watertest_e_01.dds
    e_fFresnelBias 0 0.06
    e_fFresnelPower 0 6.35
    e_fWaterColor1 3 255 61 93 100
    e_fWaterColor2 3 255 96 151 166
    e_fReflectionAmount 0 0.01
    e_fReflectionColor 3 255 255 255 255
    e_fSlide1X 0 0.04
    e_fSlide1Y 0 0.04
    e_fSlide2X 0 0.03
    e_fSlide2Y 0 0.03
lavastoneC from broodlands:
    e_fGloss0 0 0.5
    e_fShininess0 0 12
    e_TextureDiffuse0 2 Di_ls_lava_rock_rough_c.dds
    e_TextureSecond0 2 erosion_lava_ov_tile.dds


# Light properties
LIT_vents07 from chamberse:
    radius 50, rgb 0 to 1

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