extends "res://tests/test_base.gd"
## 导出纯计算部分的测试：动画规划、排布、裁边、JSON、SpriteFrames、即用场景（编辑器导入流程由 selftest 覆盖）

const FxExport := preload("res://addons/fx_forge/export/fx_export.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")


func _settings(overrides: Dictionary = {}) -> Dictionary:
	var p: Resource = Builtin.find("slash_basic")
	var s := FxExport.default_settings(p)
	s.merge(overrides, true)
	return FxExport.normalize_settings(s, p)


func test_normalize_settings() -> bool:
	var p: Resource = Builtin.find("slash_basic")
	var s := FxExport.normalize_settings({"base_name": "火焰 Slash!", "out_dir": "C:/x", "scale": 9, "variants": 0, "layout": "??"}, p)
	check_eq(s["base_name"], "slash", "文件名只保留英文字母数字")
	check_eq(s["out_dir"], "res://fx_exports/", "非法目录回到默认")
	check_eq(s["scale"], 4, "放大倍数夹到 4")
	check_eq(s["variants"], 1, "变体数至少 1")
	check_eq(s["layout"], "auto", "非法排列回到自动")
	check_eq(FxExport.ascii_name("墨刃", "effect"), "effect", "纯中文名回退到默认文件名")
	check_eq(FxExport.node_name("slash_fire"), "SlashFire", "场景根节点名")
	return true


func test_plan_animations() -> bool:
	var names := FxExport.plan_animations(_settings({"directions": "8"})).map(func(a: Dictionary) -> String: return a["name"])
	check_eq(names, ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"], "8 方向动画名")
	var v := FxExport.plan_animations(_settings({"directions": "mirror", "variants": 2}))
	check_eq(v.map(func(a: Dictionary) -> String: return a["name"]), ["right", "left", "right_v2", "left_v2"], "镜像 + 变体")
	check(v[1]["mirror"] and v[3]["seed_offset"] == 1, "镜像与种子偏移")
	return true


func test_layout() -> bool:
	var row := FxExport.layout([9], 64, 64, "auto", 8, 0, 0)
	check_eq(row["size"], Vector2i(576, 64), "9 帧自动排成一行")
	var grid := FxExport.layout([9], 64, 64, "grid", 4, 2, 3)
	check_eq(grid["size"], Vector2i(3 * 2 + 4 * 64 + 3 * 2, 3 * 2 + 3 * 64 + 2 * 2), "4 列网格 + 间距 + 边距")
	check_eq(grid["rects"][5], Rect2i(3 + 66, 3 + 66, 64, 64), "第 6 帧在第 2 行第 2 列")
	var multi := FxExport.layout([3, 3], 16, 16, "auto", 8, 0, 0)
	check_eq(multi["size"], Vector2i(48, 32), "两个动画各占一行")
	check_eq(multi["rects"][3], Rect2i(0, 16, 16, 16), "第二个动画从新的一行开始")
	var big := FxExport.layout([25], 8, 8, "auto", 8, 0, 0)
	check_eq(big["size"], Vector2i(40, 40), "帧很多时自动排成接近正方形")
	return true


func test_sheet_json_and_trim() -> bool:
	var p: Resource = Builtin.find("slash_basic")
	var s := _settings({"trim": true, "scale": 2, "padding": 1})
	var rendered := FxExport.render_animations(p, s)
	var sheet := FxExport.build_sheet(rendered, s)
	var fs: Vector2i = sheet["frame_size"]
	var crop: Rect2i = sheet["crop"]
	check(crop.size.x < 64 and crop.size.y < 64, "裁边后比画布小（%s）" % crop)
	check_eq(fs, crop.size * 2, "放大 2 倍")
	var pivot: Vector2 = sheet["pivot"]
	check_eq(pivot, ((Vector2(32, 32) - Vector2(crop.position)) * 2).floor(), "锚点随裁边换算")
	var img: Image = sheet["image"]
	for r: Rect2i in sheet["rects"]:
		check(Rect2i(Vector2i.ZERO, img.get_size()).encloses(r), "帧矩形在图内")
	var data: Variant = JSON.parse_string(FxExport.build_json(sheet, rendered, s, "slash_basic.png"))
	check(data is Dictionary, "JSON 可解析")
	if data is Dictionary:
		check_eq((data["frames"] as Array).size(), 9, "JSON 帧数")
		check_eq(int(data["meta"]["size"]["w"]), img.get_width(), "JSON 记录图片宽度")
		check_eq(data["meta"]["frameTags"][0]["name"], "default", "动画标签")
		check_eq(int(data["frames"][0]["duration"]), 50, "20 帧/秒 → 每帧 50 毫秒")
	return true


func test_sprite_frames_and_scene() -> bool:
	var p: Resource = Builtin.find("slash_basic")
	var s := _settings({"directions": "4", "blend": "add"})
	var rendered := FxExport.render_animations(p, s)
	var sheet := FxExport.build_sheet(rendered, s)
	var tex := ImageTexture.create_from_image(sheet["image"])
	var sf := FxExport.build_sprite_frames(tex, sheet, rendered)
	check_eq(Array(sf.get_animation_names()), ["down", "left", "right", "up"], "4 个方向动画（按名称排序），没有多余的 default")
	check_eq(sf.get_frame_count(&"left"), 9, "每个动画 9 帧")
	check(not sf.get_animation_loop(&"up"), "一次性特效不循环")
	check_eq((sf.get_frame_texture(&"down", 2) as AtlasTexture).region, Rect2(128, 64, 64, 64), "帧区域对应精灵图")
	# 原地更新：同一个 SpriteFrames 对象重建
	var again := FxExport.build_sprite_frames(tex, sheet, rendered, sf)
	check(again == sf and sf.get_frame_count(&"right") == 9, "重复导出时原地重建")

	var ps := FxExport.build_scene(sf, sheet, rendered, s, "SlashBasic")
	var path := OUTPUT_DIR + "export_scene.tscn"
	check_eq(ResourceSaver.save(ps, path), OK, "场景能保存")
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(back != null, "场景能读回")
	if back == null:
		return true
	var node := back.instantiate() as AnimatedSprite2D
	check(node != null, "根节点是 AnimatedSprite2D")
	if node != null:
		check_eq(node.name, &"SlashBasic", "根节点名")
		check_eq(node.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "最近邻过滤")
		check_eq(node.offset, Vector2(-32, -32), "锚点对齐")
		check_eq(node.autoplay, "right", "自动播放第一个动画")
		check(node.material is CanvasItemMaterial and (node.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "发光叠加材质")
		check_eq(node.get("free_on_finish"), true, "内嵌脚本的属性")
		node.free()
	return true


func test_loop_effect_sprite_frames_loop() -> bool:
	var p: Resource = Builtin.find("slash_spin").clone()
	p.globals["loop"] = true
	var s := _settings()
	var rendered := FxExport.render_animations(p, s)
	var sheet := FxExport.build_sheet(rendered, s)
	var sf := FxExport.build_sprite_frames(ImageTexture.create_from_image(sheet["image"]), sheet, rendered)
	check(sf.get_animation_loop(&"default"), "循环特效的动画设为循环")
	return true
