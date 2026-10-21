@tool
extends Node
## 编辑器内导出自检（开发用）：
##   godot --headless --editor --path <工程副本> -- --fxforge-selftest
## 等文件扫描结束 → 用内置「基础刀光」做一次 4 方向导出 → 逐项校验 → 打印结果并退出（失败退出码 1）。
## 请在工程副本里运行：它会在 res://fx_exports/_selftest/ 写文件。

const FxExporter := preload("../export/fx_exporter.gd")
const FxExport := preload("../export/fx_export.gd")
const FxPreset := preload("../core/fx_preset.gd")
const Builtin := preload("../presets/builtin_presets.gd")

const OUT := "res://fx_exports/_selftest/"
const BASE := "selftest_slash"

var _errors: PackedStringArray = []


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--fxforge-export-samples"):
		_export_samples.call_deferred()
	else:
		_run.call_deferred()


## 生成示例导出（开发用，写进当前工程的 res://fx_exports/）：
##   godot --headless --editor --path . -- --fxforge-export-samples
func _export_samples() -> void:
	var efs := EditorInterface.get_resource_filesystem()
	while efs.is_scanning() or efs.is_importing():
		await get_tree().process_frame
	var failed := 0
	for p: FxPreset in Builtin.all():
		var res: Dictionary = await FxExporter.run(p, FxExport.default_settings(p))
		print("  [%s] %s：%s" % ["ok" if res["ok"] else "失败", p.preset_id, res["message"]])
		if not res["ok"]:
			failed += 1
		while efs.is_scanning() or efs.is_importing():
			await get_tree().process_frame
	print("FXFORGE_SAMPLES: " + ("DONE" if failed == 0 else "FAIL"))
	get_tree().quit(0 if failed == 0 else 1)


func _check(cond: bool, msg: String) -> void:
	print("  [%s] %s" % ["ok" if cond else "失败", msg])
	if not cond:
		_errors.append(msg)


func _run() -> void:
	var efs := EditorInterface.get_resource_filesystem()
	var frames := 0
	while (efs.is_scanning() or efs.is_importing()) and frames < 6000:
		await get_tree().process_frame
		frames += 1
	print("FXFORGE_SELFTEST: 开始（等待扫描 %d 帧）" % frames)
	var preset: FxPreset = Builtin.find("slash_basic")
	var s := FxExport.default_settings(preset)
	s.merge({"out_dir": OUT, "base_name": BASE, "directions": "4", "sequence": true, "padding": 1}, true)
	var res: Dictionary = await FxExporter.run(preset, s)
	_check(res["ok"], "首次导出到新目录：" + str(res["message"]))
	if res["ok"]:
		_verify()
		# 再导出一次：目录已知、文件已存在，走覆盖流程，SpriteFrames 原地更新
		while efs.is_scanning() or efs.is_importing():
			await get_tree().process_frame
		var res2: Dictionary = await FxExporter.run(preset, s)
		_check(res2["ok"], "重复导出（覆盖）：" + str(res2["message"]))
		if res2["ok"]:
			_verify()
	print("FXFORGE_SELFTEST: " + ("PASS" if _errors.is_empty() else "FAIL"))
	for e in _errors:
		print("  - ", e)
	get_tree().quit(0 if _errors.is_empty() else 1)


func _verify() -> void:
	var tex := ResourceLoader.load(OUT + BASE + ".png", "Texture2D") as Texture2D
	_check(tex != null, "精灵图能作为贴图加载")
	if tex != null:
		# 4 个方向各一行，每行 9 帧 64px，帧间距 1px
		_check(tex.get_size() == Vector2(9 * 64 + 8, 4 * 64 + 3), "精灵图尺寸 %s" % tex.get_size())

	var json_text := FileAccess.get_file_as_string(OUT + BASE + ".json")
	var data: Variant = JSON.parse_string(json_text)
	_check(data is Dictionary, "JSON 能解析")
	if data is Dictionary:
		_check((data["frames"] as Array).size() == 36, "JSON 共 36 帧")
		var tags: Array = data["meta"]["frameTags"]
		_check(tags.map(func(t: Dictionary) -> String: return t["name"]) == ["right", "down", "left", "up"], "JSON 动画标签为 4 个方向")
		_check(int(data["meta"]["pivot"]["x"]) == 32, "JSON 记录了锚点")

	var sf := ResourceLoader.load(OUT + BASE + "_frames.tres") as SpriteFrames
	_check(sf != null, "SpriteFrames 能加载")
	if sf != null:
		for anim: String in ["right", "down", "left", "up"]:
			_check(sf.has_animation(anim) and sf.get_frame_count(anim) == 9, "动画 %s 有 9 帧" % anim)
		_check(not sf.has_animation(&"default"), "没有多余的 default 动画")
		_check(is_equal_approx(sf.get_animation_speed(&"right"), 20.0), "帧率 20")
		_check(not sf.get_animation_loop(&"right"), "一次性特效不循环")
		var at := sf.get_frame_texture(&"down", 0) as AtlasTexture
		_check(at != null and at.atlas != null and at.atlas.resource_path == OUT + BASE + ".png", "帧贴图引用精灵图")
		_check(at != null and at.region == Rect2(0, 65, 64, 64), "第 2 行第 1 帧的区域正确")

	var ps := ResourceLoader.load(OUT + BASE + ".tscn") as PackedScene
	_check(ps != null, "即用场景能加载")
	if ps != null:
		var node := ps.instantiate()
		var spr := node as AnimatedSprite2D
		_check(spr != null, "场景根节点是 AnimatedSprite2D")
		if spr != null:
			_check(spr.sprite_frames != null and spr.sprite_frames.resource_path == OUT + BASE + "_frames.tres", "场景引用导出的 SpriteFrames")
			_check(spr.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "最近邻过滤（像素不糊）")
			_check(spr.offset == Vector2(-32, -32) and not spr.centered, "锚点对齐到特效原点")
			_check(spr.autoplay == "right", "自动播放第一个动画")
			_check(spr.get("free_on_finish") == true, "内嵌脚本：播完自动删除")
		node.free()

	var seq := DirAccess.get_files_at(OUT + BASE + "_seq/")
	var pngs := Array(seq).filter(func(f: String) -> bool: return f.ends_with(".png"))
	_check(pngs.size() == 36, "单帧序列 36 张（实际 %d）" % pngs.size())
	var copy := ResourceLoader.load(OUT + BASE + ".fxforge.tres")
	_check(copy is FxPreset, "预设副本能加载")
