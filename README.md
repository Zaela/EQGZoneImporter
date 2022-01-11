EQEmu Zone Importer

# TODO
- Fix normals being defined inside a custom property, to properly inject the material into the eqg
- Figure out regions and why extents don't properly align
- Add environment emitters (zonename_environmentemitters.txt)
- Add character references (zonename_chr.txt)
- Add sound emitters (zonename.emt)


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
- Recommeneded to use Visual Studio 2017+ with C++ v143

lua requirements for cmake:
    find_package(Lua REQUIRED)
    target_include_directories(main PRIVATE ${LUA_INCLUDE_DIR})
    target_link_libraries(main PRIVATE ${LUA_LIBRARIES})
irrlicht requirements for cmake:
    find_package(irrlicht CONFIG REQUIRED)
    target_link_libraries(main PRIVATE Irrlicht)

# file extensions:
ext|desc
--|--
ani|Animation
anl|Animation list
dat|Random data file
def|Text-based definition file of some kind (new eqg format?)
eco|Text-based definition file for region of new eqg?
edd|Emitter definition
eff|Seems to be some kind of list definition file?
emt|Defines where specific background music plays in a zone
env|Only one use, seems to contain bone data
eqg|S3D archive for new formats
fx|D3D effect
fxo|Binary D3D effect
gr2|Unknown; attached to mds/mod/ani
lay|Contains texture references, in EQG
lit|Lighting info
lod|Level of detail info
mds|Character model
mlf|Character something something
mod|Model
ms|Two examples, both selection.ms.  Some kind of text file for selecting materials?
mtl|Defined materials for obj files|off-the-shelf
obg|Text-based definition file of some kind
obj|Standard wavefront obj
pak|Another s3d archive format, for art
pfs|Another s3d archive format, for sound
prj|Text-base definition file of some kind|seems to be for zones (new eqg)
prt|Defines attachment points for models maybe?
pts|Defines skeleton for models maybe?
rfd|Radial flora defs
ter|Defines terrain
tog|Text-based definition file of some kind|object placement?
uvw|Unknown, tied to model in some way
wld|Old-school zone
zon|EQG zone definition



dranikhollows_environmentemitters.txt 
Name^EmitterDefIdx^X^Y^Z^Lifespan
cavetorch00^7^-232.960953^3869.141846^137.998978^9999999

entry 00 is OBJ_walltorchsm20

