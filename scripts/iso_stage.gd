@tool
extends Node3D
## 等距测试场的布景：用《八方旅人》场景素材搭成的「林间遗迹 · 山贼营地」。
## 运行等距测试场、或在编辑器里打开 iso_stage.tscn 时自动搭建；生成的节点不保存进场景文件。
## 素材是第三方版权素材，只在本机使用，来源和导入设置见 res://assets/octopath/README.md。
##
## 摆放都写在下面的表里（世界坐标，米）：改位置、加减物件只需要改表。

const ROOT := "res://assets/octopath/"
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const GROUND_SHADER := preload("res://assets/iso_stage/ground.gdshader")
const GRASS_TEX := preload("res://assets/iso_stage/ground_grass.png")
const DIRT_TEX := preload("res://assets/iso_stage/ground_dirt.png")
## 广场石板用八方旅人 2 遗迹的地砖贴图
const STONE_TEX := "res://assets/octopath/ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrTX_Ruins_A_Grd_A_cl.tga"

## 角色能走到的范围
const WALK_MIN := Vector2(-11.0, -9.2)
const WALK_MAX := Vector2(11.5, 9.8)
const BODY_RADIUS := 0.35
const ARENA := Vector2(0.25, 0.25)

## 模型：名字 → [FBX（相对 ROOT）, 子网格名（空 = 整个文件）, 选项]
## 选项：card = 竖直的插片（只在正对镜头附近转动）；backdrop = 远景（不受光、不投影）；no_shadow = 不投影
const MODELS := {
	# 遗迹（八方旅人 2）
	"pillar": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Pillar_A", ""],
	"pillar_base": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Pillar_B_Start_B", ""],
	"pillar_c": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_C", ""],
	"pillar_d": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_D", ""],
	"pillar_e": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_E", ""],
	"stub_a": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_A", ""],
	"stub_b": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_B", ""],
	"drum": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Pillar_A.FBX", "EnvMdrMD_Ruins_A_Debris_Pillar_F_Loop_B", ""],
	"fresco_wall": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Wall_Arch_A.FBX", "EnvMdrMD_Ruins_A_Wall_Fresco_A_Broken", ""],
	"wall_end_l": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Wall_A.FBX", "EnvMdrMD_Ruins_A_Debris_Wall_G_Left", ""],
	"wall_end_r": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Wall_A.FBX", "EnvMdrMD_Ruins_A_Debris_Wall_G_Right", ""],
	"wall_chunk_b": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Wall_A.FBX", "EnvMdrMD_Ruins_A_Debris_Wall_B", ""],
	"wall_chunk_d": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Wall_A.FBX", "EnvMdrMD_Ruins_A_Debris_Wall_D", ""],
	"wall_chunk_e": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_Wall_A.FBX", "EnvMdrMD_Ruins_A_Debris_Wall_E", ""],
	"rubble": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_A.FBX", "EnvMdrMD_Ruins_A_Debris_A_Large", ""],
	"rubble_b": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_A.FBX", "EnvMdrMD_Ruins_A_Debris_B", ""],
	"rubble_c": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_A.FBX", "EnvMdrMD_Ruins_A_Debris_C", ""],
	"rubble_d": ["ot2/EnvMdrMD_Ruins_A_Altar_A/EnvMdrMD_Ruins_A_Debris_A.FBX", "EnvMdrMD_Ruins_A_Debris_D", ""],
	"tower_ruin": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Battlefield_B_Tower_A.FBX", "EnvObjMD_Battlefield_B_Tower_A", ""],
	# 山贼营地
	"tent_big": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Battlefield_Tent_A.FBX", "", ""],
	"tent_small": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Tent_A", ""],
	"tent_small_b": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Tent_B", ""],
	"bonfire": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Bonfire", ""],
	"pot": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Pot", ""],
	"bedroll": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Bed_A", ""],
	"bedroll_b": ["ot2/EnvObjMD_Campset_A_Bed_A/EnvObjMD_Campset_A_Bed_A.FBX", "EnvObjMD_Campset_A_Bed_B", ""],
	"log_seat": ["ot2/EnvObjMD_Timber_A_XL/EnvObjMD_Timber_A_XL.FBX", "EnvObjMD_Timber_A_S", ""],
	"log_pile": ["ot2/EnvObjMD_Timber_A_XL/EnvObjMD_Timber_A_XL.FBX", "EnvObjMD_Timber_A_XL", ""],
	"spear_rack": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_fence_A_Broken.FBX", "EnvObjMD_Batlefield_A_WeaponStand_Spear", ""],
	"sword_rack": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_fence_A_Broken.FBX", "EnvObjMD_Batlefield_A_WeaponStand_Sword_A", ""],
	"barricade": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_fence_A_Broken.FBX", "EnvObjMD_Batlefield_A_fence_A", ""],
	"barricade_broken": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_fence_A_Broken.FBX", "EnvObjMD_Batlefield_A_fence_B_Broken", ""],
	"cart_broken": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_fence_A_Broken.FBX", "EnvObjMD_Batlefield_A_Wagon_B_Broken", ""],
	"straw_dummy": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_NoFlag.FBX", "EnvObjMD_Batlefield_A_Torso_A", ""],
	"spear": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_NoFlag.FBX", "EnvObjMD_Batlefield_A_Spear_B", ""],
	"shield": ["ot2/EnvObjMD_Batlefield_A_fence_A_Broken/EnvObjMD_Batlefield_A_NoFlag.FBX", "EnvObjMD_Batlefield_A_Shield_B_Broken_A", ""],
	"barrel": ["ot2/EnvObjMD_Barrel_A/EnvObjMD_Barrel_A.FBX", "EnvObjMD_Barrel_A", ""],
	"barrel_open": ["ot2/EnvObjMD_Barrel_A/EnvObjMD_Barrel_A.FBX", "EnvObjMD_Barrel_A_Open", ""],
	"crate": ["ot2/EnvObjMD_Box_A/EnvObjMD_Box_A.FBX", "EnvObjMD_Box_A", ""],
	"crate_c": ["ot2/EnvObjMD_Box_A/EnvObjMD_Box_A.FBX", "EnvObjMD_Box_C", ""],
	"sack": ["ot2/EnvObjMD_Bag_A_Close/EnvObjMD_Bag_A_Close.FBX", "", ""],
	"sack_pile": ["ot2/EnvObjMD_Bag_A_Close/EnvObjMD_Bag_A_Put.FBX", "", ""],
	"skull": ["ot2/EnvObjMD_Bone_A_Femur/EnvObjMD_Bone_A_Femur.FBX", "EnvObjMD_Bone_A_Skull", ""],
	"cow_skull": ["ot2/EnvObjMD_Bone_A_Femur/EnvObjMD_Bone_B_Cowbone_A.FBX", "", ""],
	"flag": ["ot1/ObjMD_Battlefield_Flag_D_Red_Wind/ObjMD_Battlefield_Flag_D_Red_Wind.FBX", "", ""],
	"brazier": ["ot2/EnvObjMD_Torch_C/EnvObjMD_Torch_C.FBX", "", ""],
	"torch_stand": ["ot2/EnvObjMD_Torch_D/EnvObjMD_Torch_D.FBX", "EnvObjMD_Torch_D", ""],
	"watchtower": ["ot2/EnvObjMD_WatchTower_A/EnvObjMD_WatchTower_A.FBX", "", ""],
	"wagon": ["ot1/ObjMD_Wagon_A/ObjMD_Wagon_A.FBX", "", ""],
	"stump_axe": ["ot1/ObjMD_Woodstump_A/ObjMD_Woodstump_A.FBX", "ObjMD_Woodstump_A", ""],
	"woodpile": ["ot1/ObjMD_Woodput_A/ObjMD_Woodput_A.FBX", "ObjMD_Woodput_A", ""],
	"well": ["ot1/ObjMD_Well_A/ObjMD_Well_A.FBX", "ObjMD_Well_A", ""],
	"barrel_ot1": ["ot1/ObjMD_Barrel_A/ObjMD_Barrel_A.FBX", "", ""],
	"fence": ["ot2/EnvMdrMD_Wilderness_A_Fence_A_End_A/EnvMdrMD_Wilderness_A_Fence_B_End_A.FBX", "EnvMdrMD_Wilderness_A_Fence_B_Loop_A", ""],
	"fence_broken": ["ot2/EnvMdrMD_Wilderness_A_Fence_A_End_A/EnvMdrMD_Wilderness_A_Fence_B_End_A.FBX", "EnvMdrMD_Wilderness_A_Fence_B_Loop_A_Broken_B", ""],
	"fence_post": ["ot2/EnvMdrMD_Wilderness_A_Fence_A_End_A/EnvMdrMD_Wilderness_A_Fence_B_End_A.FBX", "EnvMdrMD_Wilderness_A_Fence_B_Post_A", ""],
	# 树木、灌木、石头
	"tree_round": ["ot1/ObjMD_Tree_Plain_A/ObjMD_Tree_Plain_A.FBX", "", ""],
	"tree_cone": ["ot1/ObjMD_Tree_A_04/ObjMD_Tree_A_04.FBX", "", ""],
	"tree_pine": ["ot1/ObjMD_Tree_Forest_A/ObjMD_Tree_Forest_A.FBX", "", ""],
	"tree_pine_s": ["ot1/ObjMD_Tree_H/ObjMD_Tree_H.FBX", "", ""],
	"tree_slim": ["ot1/ObjMD_Tree_Sea_A/ObjMD_Tree_Sea_A.FBX", "", ""],
	"tree_leafy": ["ot2/EnvFldMD_Tree_E_MA_LOD0/EnvFldMD_Tree_E_MA_LOD0.FBX", "", ""],
	"tree_leafy_b": ["ot2/EnvFldMD_Tree_E_MA_LOD0/EnvFldMD_Tree_E_MB_LOD0.FBX", "", ""],
	"tree_old": ["ot2/EnvFldMD_Tree_L_A/EnvFldMD_Tree_L_C.FBX", "", ""],
	"tree_dead": ["ot1/ObjMD_Tree_G/ObjMD_Tree_G.FBX", "", ""],
	"bush": ["ot1/ObjMD_Tree_Plain_Low_B/ObjMD_Tree_Plain_Low_B.FBX", "", ""],
	"bush_big": ["ot1/ObjMD_Tree_Plain_Low_C/ObjMD_Tree_Plain_Low_C.FBX", "", ""],
	"bush_low": ["ot1/ObjMD_Tree_Low_A/ObjMD_Tree_Low_A.FBX", "", ""],
	"bush_leafy": ["ot2/EnvFldMD_Tree_E_MA_LOD0/EnvFldMD_Tree_E_SA.FBX", "", ""],
	"shrub_m": ["ot2/EnvFldMD_Grass_M_A/EnvFldMD_Grass_M_A.FBX", "", ""],
	"shrub_l": ["ot2/EnvFldMD_Grass_M_A/EnvFldMD_Grass_M_B.FBX", "", ""],
	"fern": ["ot2/EnvFldMD_Grass_E_Fern_LA/EnvFldMD_Grass_E_Fern_LA.FBX", "", ""],
	"fallen_log": ["ot2/EnvFldMD_FallenTree_A_Spline_A/EnvFldMD_FallenTree_A_Spline_A.FBX", "", ""],
	"rock_big": ["ot1/ObjMD_Rock_A_04/ObjMD_Rock_A_04.FBX", "ObjMD_Rock_B_011", ""],
	"stone": ["ot2/EnvFldMD_FoliageStone_A_MA/EnvFldMD_FoliageStone_A_MA.FBX", "", ""],
	"stone_flat": ["ot2/EnvFldMD_FoliageStone_A_MA/EnvFldMD_FoliageStone_A_MB.FBX", "", ""],
	# 散布用的花草碎石
	"grass": ["ot2/EnvFldMD_FoliageGrass_A_MA/EnvFldMD_FoliageGrass_A_MA.FBX", "", "no_shadow"],
	"grass_short": ["ot2/EnvFldMD_FoliageGrass_A_MA/EnvFldMD_FoliageGrass_A_MA_Short.FBX", "", "no_shadow"],
	"grass_tall": ["ot1/ObjMD_Grass_A_long/ObjMD_Grass_A_long.FBX", "", "no_shadow"],
	"grass_tuft": ["ot1/ObjMD_Grass_J/ObjMD_Grass_J.FBX", "", "no_shadow"],
	"weed": ["ot1/ObjMD_Grass_B_weedA/ObjMD_Grass_B_weedA.FBX", "", "no_shadow"],
	"weed_b": ["ot1/ObjMD_Grass_B_weedB/ObjMD_Grass_B_weedB.FBX", "", "no_shadow"],
	"forest_grass": ["ot2/EnvFldMD_Grass_B_Forest_MA/EnvFldMD_Grass_B_Forest_MA.FBX", "", "no_shadow"],
	"leafy_grass": ["ot2/EnvFldMD_Grass_J_L/EnvFldMD_Grass_J_M.FBX", "", "no_shadow"],
	"flowers_a": ["ot1/ObjMD_Cemetery_Flower_A/ObjMD_Cemetery_Flower_A.FBX", "", "card,no_shadow"],
	"flowers_d": ["ot1/ObjMD_Cemetery_Flower_D/ObjMD_Cemetery_Flower_D.FBX", "", "card,no_shadow"],
	"flowers_e": ["ot1/ObjMD_Cemetery_Flower_E/ObjMD_Cemetery_Flower_E.FBX", "", "card,no_shadow"],
	"lavender": ["ot1/ObjMD_Flower_A_blue/ObjMD_Flower_A_blue.FBX", "ObjMD_Flower_A_lavender_Many", "card,no_shadow"],
	"pink_flowers": ["ot1/ObjMD_Flower_A_blue/ObjMD_Flower_A_blue.FBX", "ObjMD_Flower_A_pink_many", "card,no_shadow"],
	"blue_patch": ["ot1/ObjMD_Grass_BlueFlower_A/ObjMD_Grass_BlueFlower_A.FBX", "", "no_shadow"],
	"moss_patch": ["ot1/ObjMD_Grass_Hkoke/ObjMD_Grass_Hkoke.FBX", "", "no_shadow"],
	"pebble_a": ["ot1/ObjMD_Rock_A_04/ObjMD_Rock_A_04.FBX", "ObjMD_Rock_A_08", "no_shadow"],
	"pebble_b": ["ot1/ObjMD_Rock_A_04/ObjMD_Rock_A_04.FBX", "ObjMD_Rock_B_014", "no_shadow"],
	"pebble_c": ["ot1/ObjMD_Stone_D_Cave_02/ObjMD_Stone_D_Cave_02.FBX", "ObjMD_Stone_D_Cave_06", "no_shadow"],
	"twigs": ["ot2/EnvFldMD_FoliageScrap_LA/EnvFldMD_FoliageScrap_MA.FBX", "", "no_shadow"],
	# 远景
	"far_forest": ["ot1/BgMD_Dis_Forest_A/BgMD_Dis_Forest_A.FBX", "", "backdrop"],
	"far_mountain": ["ot1/BgMD_Dis_Mount_A/BgMD_Dis_Mount_A.FBX", "", "backdrop"],
	"mid_mountain": ["ot1/BgMD_Mid_Mount_D_tall/BgMD_Mid_Mount_D_tall.FBX", "", "backdrop"],
	"mid_mountain_low": ["ot1/BgMD_Mid_Mount_D_low/BgMD_Mid_Mount_D_low.FBX", "", "backdrop"],
}

## 原文件里贴错贴图的子网格：子网格名 → {表面序号: 同目录下应该用的贴图}
const SURFACE_TEXTURES := {
	"EnvFldMD_Tree_E_MA_LOD0": {1: "EnvFldTX_Tree_E_LOD0_Leaf"},
	"EnvFldMD_Tree_E_MB_LOD0": {1: "EnvFldTX_Tree_E_LOD0_Leaf"},
}

## 摆放：[模型, 位置（y 是上下偏移）, 朝向（度）, 缩放, 阻挡]
## 阻挡：0 不挡路；大于 0 是圆形半径（米）；小于 0 按占地矩形的比例
const LAYOUT := [
	# 场地中央是石板广场（地面着色器画的），四周是断柱
	["pillar", Vector3(-5.3, 0, -3.7), 0.0, 1.0, 0.6],
	["pillar_e", Vector3(5.7, 0, -3.9), 30.0, 1.0, 0.6],
	["pillar_c", Vector3(-6.4, 0, 1.3), 10.0, 1.0, 0.6],
	["pillar_d", Vector3(6.5, 0, 1.2), -20.0, 1.0, 0.6],
	["stub_a", Vector3(-4.7, 0, 4.9), 0.0, 1.0, 0.55],
	["stub_b", Vector3(5.1, 0, 4.7), 45.0, 1.0, 0.55],
	["pillar_base", Vector3(1.9, 0, -6.9), 15.0, 0.8, 1.0],
	["drum", Vector3(-2.2, 0, -7.0), 0.0, 1.0, 0.8],
	["rubble", Vector3(3.6, 0, -8.0), 20.0, 1.0, 0.0],
	["rubble_b", Vector3(-7.4, 0, -1.6), 60.0, 1.0, 0.0],
	["rubble_c", Vector3(7.6, 0, 3.4), -30.0, 1.0, 0.0],
	["rubble_d", Vector3(-1.8, 0, 7.6), 15.0, 1.0, 0.0],
	# 后方的断墙（带壁画），中间有缺口能看到树林
	["fresco_wall", Vector3(-0.5, 0, -11.6), 90.0, 1.0, -0.9],
	["wall_end_l", Vector3(-11.2, 0, -11.2), 90.0, 1.0, -0.9],
	["wall_end_r", Vector3(10.2, 0, -11.4), 90.0, 1.0, -0.9],
	["wall_chunk_d", Vector3(-8.6, 0, -9.6), 75.0, 0.9, -0.85],
	["wall_chunk_e", Vector3(8.0, 0, -9.4), 100.0, 1.0, -0.85],
	["wall_chunk_b", Vector3(13.2, 0, -10.6), 90.0, 0.9, -0.85],
	["tower_ruin", Vector3(15.8, 0, -13.5), -20.0, 1.0, 0.0],
	# 左侧：山贼营地
	["tent_big", Vector3(-14.0, 0, -5.4), 25.0, 1.0, -0.75],
	["tent_small", Vector3(-10.0, 0, -9.0), 35.0, 1.0, -0.8],
	["tent_small_b", Vector3(-16.2, 0, 0.6), 80.0, 1.0, -0.8],
	["bonfire", Vector3(-9.2, 0, -3.3), 0.0, 1.0, 0.9],
	["pot", Vector3(-10.6, 0, -2.1), 40.0, 1.0, 0.4],
	["bedroll", Vector3(-11.6, 0, -0.6), 70.0, 1.0, 0.0],
	["bedroll_b", Vector3(-7.4, 0, -5.6), -25.0, 1.0, 0.0],
	["log_seat", Vector3(-7.4, 0, -2.4), 80.0, 1.0, 0.45],
	["log_seat", Vector3(-9.6, 0, -5.3), 10.0, 1.0, 0.45],
	["spear_rack", Vector3(-12.9, 0, -1.4), 90.0, 1.0, -0.8],
	["sword_rack", Vector3(-12.2, 0, 1.7), 60.0, 1.0, -0.8],
	["straw_dummy", Vector3(-8.0, 0, 3.7), -20.0, 1.0, 0.4],
	["barrel", Vector3(-14.6, 0, -1.9), 0.0, 1.0, 0.5],
	["barrel_open", Vector3(-13.9, 0, -2.8), 40.0, 1.0, 0.5],
	["crate", Vector3(-15.3, 0, -0.5), 15.0, 1.0, 0.6],
	["crate_c", Vector3(-14.3, 0, 0.5), -10.0, 1.0, 0.5],
	["sack", Vector3(-12.2, 0, -3.6), 0.0, 1.0, 0.0],
	["sack_pile", Vector3(-11.0, 0, -7.4), 30.0, 1.0, 0.0],
	["flag", Vector3(-11.4, 0, -10.6), 15.0, 1.0, 0.0],
	["barricade", Vector3(-16.6, 0, 3.4), 60.0, 1.0, 0.0],
	["barricade_broken", Vector3(-13.6, 0, 4.6), 20.0, 1.0, -0.8],
	["cart_broken", Vector3(-17.8, 0, -9.8), 30.0, 1.0, 0.0],
	["spear", Vector3(-12.6, 0, -8.6), 10.0, 1.0, 0.0],
	["shield", Vector3(-12.1, 0, -8.2), 70.0, 1.0, 0.0],
	["skull", Vector3(-6.2, 0, -6.6), 30.0, 1.0, 0.0],
	["cow_skull", Vector3(-15.0, 0, 4.0), 20.0, 1.0, 0.0],
	# 圆台北侧两只火盆
	["brazier", Vector3(-3.4, 0, -5.4), 0.0, 1.0, 0.55],
	["brazier", Vector3(4.0, 0, -5.6), 0.0, 1.0, 0.55],
	["torch_stand", Vector3(8.7, 0, -4.6), 0.0, 1.0, 0.3],
	["torch_stand", Vector3(-6.9, 0, 6.3), 0.0, 1.0, 0.3],
	# 右侧：瞭望塔、马车、劈柴
	["watchtower", Vector3(12.4, 0, -6.0), -15.0, 1.0, -0.8],
	["wagon", Vector3(12.4, 0, 2.4), -70.0, 1.0, -0.8],
	["stump_axe", Vector3(9.0, 0, -0.9), 30.0, 1.0, 0.55],
	["woodpile", Vector3(14.8, 0, -1.4), -90.0, 1.0, -0.85],
	["log_pile", Vector3(10.0, 0, -2.6), 20.0, 1.0, -0.8],
	["barrel_ot1", Vector3(9.7, 0, -6.8), 0.0, 1.0, 0.5],
	["well", Vector3(12.2, 0, 6.4), -30.0, 1.0, -0.8],
	["fence_post", Vector3(9.5, 0, 9.3), 0.0, 1.0, 0.0],
	["fence", Vector3(10.1, 0, 9.3), 90.0, 1.0, 0.0],
	["fence", Vector3(11.2, 0, 9.3), 90.0, 1.0, 0.0],
	["fence_broken", Vector3(12.3, 0, 9.3), 90.0, 1.0, 0.0],
	["fence", Vector3(13.4, 0, 9.3), 90.0, 1.0, 0.0],
	["fence_post", Vector3(14.0, 0, 9.3), 0.0, 1.0, 0.0],
	# 前景：倒木、石头、灌木（保持低矮，不挡角色）
	["fallen_log", Vector3(-11.8, 0, 9.4), 70.0, 0.75, -0.6],
	["rock_big", Vector3(6.9, 0, 8.6), 20.0, 1.0, 0.8],
	["stone", Vector3(-1.2, 0, 11.6), 60.0, 1.5, 0.6],
	["stone_flat", Vector3(4.6, 0, 11.0), -20.0, 1.4, 0.0],
	["stone", Vector3(9.6, 0, 9.4), 0.0, 1.2, 0.0],
	["stone_flat", Vector3(-6.0, 0, 9.8), 40.0, 1.3, 0.0],
	["bush_big", Vector3(13.0, 0, 8.0), 0.0, 1.0, 0.9],
	["bush", Vector3(-13.6, 0, 8.6), 0.0, 1.0, 0.7],
	["bush_low", Vector3(15.6, 0, 3.6), 0.0, 1.0, 0.0],
	["bush_leafy", Vector3(-12.0, 0, 11.5), 30.0, 1.0, 0.0],
	["shrub_m", Vector3(7.8, 0, 12.6), 0.0, 1.0, 0.0],
	["shrub_m", Vector3(-16.6, 0, 6.6), 90.0, 1.0, 0.0],
	["fern", Vector3(2.0, 0, 13.6), 0.0, 1.0, 0.0],
	["fern", Vector3(-7.4, 0, 12.8), 120.0, 1.0, 0.0],
	# 树林：后排高，两侧中等，前排只放矮的
	["tree_old", Vector3(-3.4, 0, -16.8), 20.0, 1.0, 0.0],
	["tree_pine", Vector3(-14.6, 0, -17.2), 0.0, 1.0, 0.0],
	["tree_pine", Vector3(6.4, 0, -22.4), 0.0, 1.1, 0.0],
	["tree_pine", Vector3(19.2, 0, -16.6), 0.0, 0.95, 0.0],
	["tree_pine_s", Vector3(-20.4, 0, -12.0), 0.0, 1.0, 0.0],
	["tree_pine_s", Vector3(21.6, 0, -9.0), 0.0, 1.0, 0.0],
	["tree_leafy", Vector3(3.8, 0, -15.0), 30.0, 1.0, 0.0],
	["tree_leafy", Vector3(-9.6, 0, -15.4), 140.0, 1.0, 0.0],
	["tree_leafy_b", Vector3(12.8, 0, -16.0), 200.0, 1.0, 0.0],
	["tree_leafy_b", Vector3(-19.4, 0, -6.0), 60.0, 1.0, 0.0],
	["tree_round", Vector3(-0.6, 0, -21.0), 0.0, 1.0, 0.0],
	["tree_round", Vector3(10.6, 0, -20.4), 0.0, 1.1, 0.0],
	["tree_round", Vector3(-12.2, 0, -22.0), 0.0, 1.0, 0.0],
	["tree_round", Vector3(-19.2, 0, 1.4), 0.0, 1.0, 1.0],
	["tree_round", Vector3(18.4, 0, 2.6), 0.0, 1.05, 1.0],
	["tree_cone", Vector3(-6.4, 0, -19.6), 0.0, 1.0, 0.0],
	["tree_cone", Vector3(15.4, 0, -21.4), 0.0, 1.0, 0.0],
	["tree_cone", Vector3(17.8, 0, -4.4), 0.0, 1.0, 0.8],
	["tree_slim", Vector3(-17.2, 0, 8.4), 0.0, 1.0, 0.6],
	["tree_slim", Vector3(19.6, 0, 9.0), 0.0, 1.0, 0.6],
	["tree_leafy", Vector3(16.6, 0, 13.8), 0.0, 0.9, 0.0],
	["tree_leafy_b", Vector3(-16.4, 0, 15.0), 90.0, 0.9, 0.0],
	["tree_dead", Vector3(7.4, 0, -13.6), 0.0, 1.0, 0.0],
	["bush_big", Vector3(-6.0, 0, -13.6), 0.0, 1.0, 0.0],
	["bush", Vector3(1.2, 0, -14.0), 0.0, 1.0, 0.0],
	["bush_low", Vector3(9.4, 0, -14.2), 0.0, 1.0, 0.0],
	["shrub_l", Vector3(-17.6, 0, -2.4), 30.0, 1.0, 0.0],
	["shrub_l", Vector3(17.0, 0, -10.0), 0.0, 1.0, 0.0],
	["shrub_m", Vector3(-4.6, 0, -13.2), 0.0, 1.0, 0.0],
	["fern", Vector3(14.4, 0, -12.6), 0.0, 1.0, 0.0],
]

## 外圈的树林：沿圆环自动摆放
const TREE_RING := {"radius": [26.0, 40.0], "count": 46, "models": ["tree_pine", "tree_round", "tree_cone", "tree_leafy", "tree_leafy_b", "tree_pine_s"]}

## 远景：[模型, 方位（度，0 = 北 / -Z，90 = 西 / -X）, 距离, 缩放]
const BACKDROP := [
	["far_forest", -40.0, 72.0, 1.0], ["far_forest", -5.0, 74.0, 1.0], ["far_forest", 30.0, 72.0, 1.0],
	["far_forest", 65.0, 74.0, 1.0], ["far_forest", 100.0, 72.0, 1.0],
	["mid_mountain", 12.0, 118.0, 1.4], ["mid_mountain_low", 52.0, 112.0, 1.4], ["mid_mountain", 88.0, 120.0, 1.2],
	["far_mountain", -20.0, 150.0, 1.6], ["far_mountain", 40.0, 150.0, 1.6], ["far_mountain", 100.0, 150.0, 1.6],
]

## 散布：[模型, 数量, 区域（x, z, 宽, 深）, 缩放范围]
const SCATTER := [
	["grass", 420, Rect2(-26, -26, 52, 46), Vector2(0.9, 1.5)],
	["grass_short", 360, Rect2(-26, -26, 52, 46), Vector2(0.9, 1.4)],
	["grass_tall", 90, Rect2(-24, -24, 48, 42), Vector2(0.8, 1.2)],
	["grass_tuft", 40, Rect2(-24, -24, 48, 42), Vector2(0.7, 1.0)],
	["weed", 50, Rect2(-22, -22, 44, 38), Vector2(0.8, 1.2)],
	["weed_b", 40, Rect2(-22, -22, 44, 38), Vector2(0.8, 1.1)],
	["forest_grass", 70, Rect2(-26, -26, 52, 46), Vector2(0.8, 1.2)],
	["leafy_grass", 26, Rect2(-24, -24, 48, 42), Vector2(0.6, 0.9)],
	["flowers_a", 34, Rect2(-20, -16, 40, 32), Vector2(0.8, 1.1)],
	["flowers_d", 26, Rect2(-20, -16, 40, 32), Vector2(0.8, 1.1)],
	["flowers_e", 26, Rect2(-20, -16, 40, 32), Vector2(0.8, 1.1)],
	["lavender", 14, Rect2(-18, -14, 36, 30), Vector2(0.7, 0.9)],
	["pink_flowers", 14, Rect2(-18, -14, 36, 30), Vector2(0.7, 0.9)],
	["blue_patch", 10, Rect2(-20, -18, 40, 34), Vector2(0.8, 1.1)],
	["moss_patch", 14, Rect2(-20, -18, 40, 34), Vector2(0.8, 1.2)],
	["pebble_a", 40, Rect2(-16, -12, 32, 26), Vector2(0.6, 1.0)],
	["pebble_b", 40, Rect2(-16, -12, 32, 26), Vector2(0.7, 1.2)],
	["pebble_c", 30, Rect2(-16, -12, 32, 26), Vector2(0.6, 1.0)],
	["twigs", 24, Rect2(-20, -18, 40, 34), Vector2(0.8, 1.2)],
]

## 泥土小路（地面着色器和散布共用）：[起点, 终点, 半宽]
const PATHS := [
	[Vector2(-5.4, 0.6), Vector2(-9.4, -2.9), 1.2],
	[Vector2(-9.4, -2.9), Vector2(-23.0, -4.6), 0.9],
	[Vector2(5.6, 0.0), Vector2(10.4, -1.8), 1.1],
	[Vector2(10.4, -1.8), Vector2(13.4, -5.8), 0.9],
	[Vector2(0.8, 5.6), Vector2(1.9, 12.0), 1.2],
	[Vector2(1.9, 12.0), Vector2(4.6, 24.0), 1.0],
	[Vector2(0.0, -5.6), Vector2(-0.6, -10.4), 0.9],
	[Vector2(-0.6, -10.4), Vector2(-1.4, -24.0), 0.8],
]
## 石板地面：[中心, 半径]（铺在泥土上面，边缘同样是像素抖动）
const STONES := [
	[ARENA, 5.0],
	[Vector2(-1.6, -8.4), 2.2],
	[Vector2(3.4, -7.6), 1.6],
]
## 泥土空地：[中心, 半径, 强度]
const PATCHES := [
	[ARENA, 6.0, 1.0],
	[Vector2(-10.6, -3.0), 3.8, 1.0],
	[Vector2(12.2, -5.6), 2.8, 0.9],
	[Vector2(-14.4, -0.8), 2.4, 0.8],
]

## 光照预设：太阳方向是光线前进的方向
const LIGHTING := [
	{"name": "傍晚", "sun_dir": Vector3(0.62, -0.42, -0.66), "sun": Color(1.0, 0.78, 0.55), "sun_energy": 1.45,
		"ambient": Color(0.52, 0.52, 0.7), "ambient_energy": 0.8, "sky_top": Color(0.32, 0.39, 0.6), "sky_horizon": Color(0.98, 0.7, 0.48),
		"fog": Color(0.95, 0.74, 0.56), "fog_density": 0.6, "torch": 1.3, "sprite": Color(1.0, 0.93, 0.84), "motes": Color(1.0, 0.82, 0.45, 0.85),
		"exposure": 1.0, "glow": 0.65},
	{"name": "白天", "sun_dir": Vector3(0.45, -0.78, -0.43), "sun": Color(1.0, 0.96, 0.88), "sun_energy": 1.0,
		"ambient": Color(0.6, 0.66, 0.8), "ambient_energy": 0.62, "sky_top": Color(0.38, 0.58, 0.86), "sky_horizon": Color(0.78, 0.86, 0.94),
		"fog": Color(0.78, 0.85, 0.94), "fog_density": 0.5, "torch": 0.0, "sprite": Color(1, 1, 1), "motes": Color(1.0, 1.0, 0.9, 0.5),
		"exposure": 0.92, "glow": 0.45},
	{"name": "夜晚", "sun_dir": Vector3(0.35, -0.62, -0.7), "sun": Color(0.62, 0.72, 1.0), "sun_energy": 0.42,
		"ambient": Color(0.26, 0.3, 0.5), "ambient_energy": 0.75, "sky_top": Color(0.04, 0.06, 0.14), "sky_horizon": Color(0.12, 0.16, 0.3),
		"fog": Color(0.1, 0.13, 0.24), "fog_density": 0.7, "torch": 2.4, "sprite": Color(0.62, 0.68, 0.9), "motes": Color(0.78, 1.0, 0.42, 1.0),
		"exposure": 1.0, "glow": 0.9},
]

## 火盆、篝火、火把上的火：模型名 → [火焰特效（插件自带的像素特效）, 火焰底部高度, 每像素多少米, 光源高度]
const FIRES := {
	"bonfire": ["campfire", 0.15, 0.03, 0.7],
	"brazier": ["campfire", 0.95, 0.022, 1.5],
	"torch_stand": ["torch", 1.62, 0.026, 2.0],
}

var environment: Environment
## 角色贴图的色调，随光照变化（角色不受场景灯光影响，用色调配合）
var sprite_tint := Color(1, 1, 1)
var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _motes: CPUParticles3D
var _fires: Array[OmniLight3D] = []
var _torch_energy := 1.0
var _blockers: Array[Dictionary] = []
## 本机有没有八方旅人素材（第三方版权素材，不随仓库发布）。没有时只搭地面、树和光，不逐个报找不到模型
var has_art := false
var _models: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}
var _cutouts: Dictionary = {}
var _flames: Dictionary = {}
var _time := 0.0


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		child.free()
	_blockers.clear()
	_fires.clear()
	has_art = ResourceLoader.exists(STONE_TEX)
	if not has_art:
		print("iso_stage: 没有本机素材 %s（第三方版权素材，不随仓库发布），场景里只有地面和特效" % ROOT)
	_build_environment()
	_build_ground()
	for entry: Array in LAYOUT:
		_place_entry(entry)
	_build_tree_ring()
	_build_backdrop()
	_build_scatter()
	_build_motes()
	set_lighting(0)


# ---------- 光照与环境 ----------

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	_sky = ProceduralSkyMaterial.new()
	_sky.sun_angle_max = 0.0
	_sky.ground_bottom_color = Color(0.12, 0.14, 0.12)
	var sky := Sky.new()
	sky.sky_material = _sky
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 42.0
	environment.fog_depth_end = 150.0
	environment.fog_depth_curve = 1.4
	environment.fog_sky_affect = 0.6
	# 兼容渲染器画面不超过 1.0，阈值放低火光和特效才会有光晕
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.72
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 1.1
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.shadow_blur = 1.5
	_sun.shadow_bias = 0.05
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)


## 切换光照预设（0 傍晚、1 白天、2 夜晚）
func set_lighting(index: int) -> void:
	var p: Dictionary = LIGHTING[clampi(index, 0, LIGHTING.size() - 1)]
	var dir: Vector3 = (p.sun_dir as Vector3).normalized()
	_sun.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	_sun.light_color = p.sun
	_sun.light_energy = p.sun_energy
	environment.ambient_light_color = p.ambient
	environment.ambient_light_energy = p.ambient_energy
	environment.fog_light_color = p.fog
	environment.fog_density = p.fog_density
	environment.tonemap_exposure = p.exposure
	environment.glow_intensity = p.glow
	_sky.sky_top_color = p.sky_top
	_sky.sky_horizon_color = p.sky_horizon
	_sky.ground_horizon_color = (p.sky_horizon as Color).darkened(0.25)
	_torch_energy = p.torch
	for light in _fires:
		light.visible = _torch_energy > 0.0
	sprite_tint = p.sprite
	if _motes != null:
		(_motes.mesh.surface_get_material(0) as StandardMaterial3D).albedo_color = p.motes


## 环境飘浮的光点（傍晚的尘埃、夜里的萤火）
func set_ambience(on: bool) -> void:
	if _motes != null:
		_motes.visible = on


func _process(delta: float) -> void:
	_time += delta
	for i in _fires.size():
		var t := _time * 9.0 + i * 3.7
		_fires[i].light_energy = _torch_energy * (0.85 + 0.1 * sin(t) + 0.06 * sin(t * 2.3 + 1.1))


# ---------- 地面 ----------

func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("grass_tex", GRASS_TEX)
	material.set_shader_parameter("dirt_tex", DIRT_TEX)
	var segments: Array[Vector4] = []
	var widths: Array[float] = []
	for path: Array in PATHS:
		var a: Vector2 = path[0]
		var b: Vector2 = path[1]
		segments.append(Vector4(a.x, a.y, b.x, b.y))
		widths.append(path[2])
	var patches: Array[Vector4] = []
	for patch: Array in PATCHES:
		var c: Vector2 = patch[0]
		patches.append(Vector4(c.x, c.y, patch[1], patch[2]))
	material.set_shader_parameter("paths", segments)
	material.set_shader_parameter("path_width", widths)
	material.set_shader_parameter("path_count", segments.size())
	material.set_shader_parameter("patches", patches)
	material.set_shader_parameter("patch_count", patches.size())
	var stones: Array[Vector4] = []
	for stone: Array in STONES:
		var c: Vector2 = stone[0]
		stones.append(Vector4(c.x, c.y, stone[1], 1.0))
	if has_art:
		material.set_shader_parameter("stone_tex", load(STONE_TEX))
	material.set_shader_parameter("stones", stones)
	material.set_shader_parameter("stone_count", stones.size())
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## 与地面着色器一致：这一点是否在小路或空地上（散布花草时避开）
func _on_dirt(p: Vector2, margin: float) -> bool:
	for path: Array in PATHS:
		if Geometry2D.get_closest_point_to_segment(p, path[0], path[1]).distance_to(p) < float(path[2]) + margin:
			return true
	for patch: Array in PATCHES:
		if p.distance_to(patch[0]) < float(patch[1]) + margin:
			return true
	return false


# ---------- 模型 ----------

## 把一个模型（或 FBX 里的一个子网格）取出来：网格 + 变换，底面中心对齐原点
func _model(key: String) -> Dictionary:
	if _models.has(key):
		return _models[key]
	var spec: Array = MODELS[key]
	var parts: Array[Dictionary] = []
	var path := ROOT + str(spec[0])
	var scene := load(path) as PackedScene if ResourceLoader.exists(path) else null
	if scene != null:
		var root := scene.instantiate()
		_collect(root, Transform3D.IDENTITY, str(spec[1]), parts)
		root.free()
	for part in parts:
		part.dir = (ROOT + str(spec[0])).get_base_dir()
	var box := AABB()
	for i in parts.size():
		var b: AABB = parts[i].xform * (parts[i].mesh as Mesh).get_aabb()
		box = b if i == 0 else box.merge(b)
	var shift := -Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for part in parts:
		part.xform = Transform3D(Basis.IDENTITY, shift) * part.xform
	var options := str(spec[2])
	var result := {"parts": parts, "size": box.size, "card": options.contains("card"), "backdrop": options.contains("backdrop"), "shadow": not options.contains("no_shadow") and not options.contains("backdrop")}
	if parts.is_empty() and has_art:
		push_warning("iso_stage: 找不到模型 %s（%s）" % [key, spec[0]])
	_models[key] = result
	return result


func _collect(node: Node, parent: Transform3D, only: String, out: Array[Dictionary]) -> void:
	var xform := parent * (node as Node3D).transform if node is Node3D else parent
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (only.is_empty() or node.name == only):
		out.append({"mesh": (node as MeshInstance3D).mesh, "xform": xform, "name": str(node.name)})
	for child in node.get_children():
		_collect(child, xform, only, out)


## 换上处理过材质的网格副本（导入的原网格不改）
func _fixed_mesh(part: Dictionary, backdrop: bool) -> Mesh:
	var mesh: Mesh = part.mesh
	var key := [mesh, backdrop]
	if _meshes.has(key):
		return _meshes[key]
	var fixes: Dictionary = SURFACE_TEXTURES.get(part.name, {})
	var copy := mesh.duplicate() as Mesh
	for i in copy.get_surface_count():
		var override := str(part.dir) + "/" + str(fixes[i]) if fixes.has(i) else ""
		copy.surface_set_material(i, _material(mesh.surface_get_material(i), backdrop, override))
	_meshes[key] = copy
	return copy


## 八方旅人的贴图是像素画：最近邻采样、不剔除背面（插片两面都要看到）、高光压低。
## override 不为空时换成同目录下的另一套贴图（<名字>_cl.tga / _no.tga）。
## 贴图的 alpha 有的是镂空，有的是高光遮罩，按透明像素的比例判断。
func _material(source: Material, backdrop: bool, override := "") -> Material:
	var key := [source, backdrop, override]
	if _materials.has(key):
		return _materials[key]
	if not source is StandardMaterial3D:
		return source
	var m := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	if not override.is_empty():
		m.albedo_texture = load(override + "_cl.tga") if ResourceLoader.exists(override + "_cl.tga") else m.albedo_texture
		m.normal_texture = load(override + "_no.tga") if ResourceLoader.exists(override + "_no.tga") else null
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 顶点色存的是风吹动画的权重，不是颜色（当颜色用会把树染红、帐篷染成洋红）
	m.vertex_color_use_as_albedo = false
	m.emission_enabled = false
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.15
	var threshold := _cutout(m.albedo_texture)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if threshold > 0.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.alpha_scissor_threshold = maxf(threshold, 0.01)
	if backdrop:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.normal_enabled = false
	_materials[key] = m
	return m


## 镂空贴图：透明像素超过一成；阈值取不透明部分最大 alpha 的一半（有的贴图整体 alpha 偏低）
func _cutout(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var key := texture.resource_path
	if _cutouts.has(key):
		return _cutouts[key]
	var result := 0.0
	var image := texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		image.clear_mipmaps()
		if image.get_width() > 64:
			image.resize(64, maxi(1, 64 * image.get_height() / image.get_width()), Image.INTERPOLATE_NEAREST)
		var clear := 0
		var top := 0.0
		for y in image.get_height():
			for x in image.get_width():
				var a := image.get_pixel(x, y).a
				if a < 0.02:
					clear += 1
				top = maxf(top, a)
		if clear > image.get_width() * image.get_height() / 10:
			result = clampf(top * 0.5, 0.05, 0.5)
	_cutouts[key] = result
	return result


func _place_entry(entry: Array) -> void:
	var key: String = entry[0]
	var pos: Vector3 = entry[1]
	var node := place(key, pos, entry[2], entry[3])
	if node == null:
		return
	var block: float = entry[4]
	if block > 0.0:
		_blockers.append({"center": Vector2(pos.x, pos.z), "radius": block})
	elif block < 0.0:
		var size: Vector3 = _model(key).size * float(entry[3])
		_blockers.append({"center": Vector2(pos.x, pos.z), "half": Vector2(size.x, size.z) * 0.5 * -block, "yaw": deg_to_rad(entry[2])})
	if FIRES.has(key):
		_add_fire(FIRES[key], pos)


func _add_fire(spec: Array, pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.3)
	light.omni_range = 8.5
	light.omni_attenuation = 1.4
	light.position = pos + Vector3(0, spec[3], 0)
	add_child(light)
	_fires.append(light)
	var flame := _flame(spec[0])
	if flame.is_empty():
		return
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = flame.frames
	sprite.centered = false
	# 帧图左上为原点、y 向下；Sprite3D 的偏移以左下为原点、y 向上
	sprite.offset = Vector2(-flame.origin.x, -(flame.size.y - flame.origin.y))
	sprite.pixel_size = spec[2]
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = pos + Vector3(0, spec[1], 0)
	add_child(sprite)
	sprite.play("default")
	sprite.frame = randi() % maxi(1, flame.frames.get_frame_count("default"))


## 把插件自带的像素火焰渲染成帧（每种只渲染一次）
func _flame(id: String) -> Dictionary:
	if _flames.has(id):
		return _flames[id]
	var result := {}
	var preset: Resource = Builtin.find(id)
	if preset != null:
		var job := FxRenderer.make_job(preset, {})
		FxRenderer.render_sync(job)
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", job.fps)
		frames.set_animation_loop("default", true)
		var images: Array = job.images()
		for i in images.size():
			if images[i] != null:
				frames.add_frame("default", ImageTexture.create_from_image(images[i]), job.durations[i] if i < job.durations.size() else 1.0)
		result = {"frames": frames, "origin": job.origin, "size": Vector2(job.w, job.h)}
	_flames[id] = result
	return result


## 摆一个模型；返回节点（找不到模型时返回 null）
func place(key: String, pos: Vector3, yaw_degrees: float, scale_factor: float) -> Node3D:
	var model := _model(key)
	if model.parts.is_empty():
		return null
	var holder := Node3D.new()
	holder.name = key
	holder.position = pos
	holder.rotation.y = deg_to_rad(yaw_degrees)
	holder.scale = Vector3.ONE * scale_factor
	for part: Dictionary in model.parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _fixed_mesh(part, model.backdrop)
		mi.transform = part.xform
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	add_child(holder)
	return holder


func _build_tree_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var models: Array = TREE_RING.models
	var radius: Array = TREE_RING.radius
	for i in int(TREE_RING.count):
		var angle := TAU * (i + rng.randf_range(-0.3, 0.3)) / float(TREE_RING.count)
		var r := rng.randf_range(radius[0], radius[1])
		# 镜头在南边（+z）：南侧不种树，免得挡住镜头
		if sin(angle) > 0.2:
			continue
		var pos := Vector3(ARENA.x + cos(angle) * r, 0, ARENA.y + sin(angle) * r)
		place(models[rng.randi() % models.size()], pos, rng.randf_range(0, 360), rng.randf_range(0.9, 1.25))


func _build_backdrop() -> void:
	for entry: Array in BACKDROP:
		var theta := deg_to_rad(entry[1])
		var pos := Vector3(-sin(theta), 0, -cos(theta)) * float(entry[2])
		# 远景插片原本沿 z 展开、朝 x 方向：转到垂直于视线
		place(entry[0], pos, rad_to_deg(theta) + 90.0, entry[3])


# ---------- 散布 ----------

func _build_scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	for entry: Array in SCATTER:
		var model := _model(entry[0])
		if model.parts.is_empty():
			continue
		var area: Rect2 = entry[2]
		var scale_range: Vector2 = entry[3]
		var transforms: Array[Transform3D] = []
		var attempts := 0
		while transforms.size() < int(entry[1]) and attempts < int(entry[1]) * 6:
			attempts += 1
			var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
			if _on_dirt(p, 0.4) or _blocked_by_prop(p, 0.4):
				continue
			var yaw := deg_to_rad(90.0 + rng.randf_range(-28, 28)) if model.card else rng.randf_range(0, TAU)
			var s := rng.randf_range(scale_range.x, scale_range.y)
			transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, 0, p.y)))
		for part: Dictionary in model.parts:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.mesh = _fixed_mesh(part, false)
			multimesh.instance_count = transforms.size()
			for i in transforms.size():
				multimesh.set_instance_transform(i, transforms[i] * part.xform)
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Scatter_" + str(entry[0])
			mmi.multimesh = multimesh
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if model.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)


func _build_motes() -> void:
	_motes = CPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 70
	_motes.lifetime = 9.0
	_motes.preprocess = 9.0
	_motes.position = Vector3(ARENA.x, 1.6, ARENA.y)
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(14, 1.5, 11)
	_motes.direction = Vector3.UP
	_motes.spread = 180.0
	_motes.gravity = Vector3(0, 0.03, 0)
	_motes.initial_velocity_min = 0.05
	_motes.initial_velocity_max = 0.25
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1))
	fade.add_point(0.75, Color(1, 1, 1, 1))
	_motes.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	quad.material = material
	_motes.mesh = quad
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_motes)


# ---------- 碰撞 ----------

## 角色是否会撞到边界或物件
func blocked(pos: Vector3) -> bool:
	if pos.x < WALK_MIN.x or pos.x > WALK_MAX.x or pos.z < WALK_MIN.y or pos.z > WALK_MAX.y:
		return true
	return _blocked_by_prop(Vector2(pos.x, pos.z), BODY_RADIUS)


func _blocked_by_prop(p: Vector2, margin: float) -> bool:
	for b: Dictionary in _blockers:
		var local: Vector2 = p - b.center
		if b.has("radius"):
			if local.length() < float(b.radius) + margin:
				return true
		else:
			local = local.rotated(float(b.yaw))
			var half: Vector2 = b.half
			if absf(local.x) < half.x + margin and absf(local.y) < half.y + margin:
				return true
	return false
