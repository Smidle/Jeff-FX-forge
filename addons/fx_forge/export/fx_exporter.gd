@tool
extends RefCounted
## 编辑器内导出：用 fx_export 生成数据，按固定顺序落盘（Godot 4.7 源码核查过的顺序）：
## 等编辑器空闲 → 写 PNG → 通知文件系统并立即导入 → 加载贴图 → SpriteFrames（已存在则原地更新）→ 场景 → JSON / 序列 / 预设副本。
## 任何一步失败都保留已写出的文件，并返回中文说明。

const FxExport := preload("fx_export.gd")
const FxGif := preload("fx_gif.gd")
const FxPreset := preload("../core/fx_preset.gd")


## 这次导出会写哪些文件（目录以 / 结尾）
static func target_files(s: Dictionary) -> PackedStringArray:
	var dir: String = s["out_dir"]
	var base: String = s["base_name"]
	var files := PackedStringArray([dir + base + ".png"])
	if s["json"]:
		files.append(dir + base + ".json")
	if s["sprite_frames"] or s["scene"]:
		files.append(dir + base + "_frames.tres")
	if s["scene"]:
		files.append(dir + base + ".tscn")
	if s["preset_copy"]:
		files.append(dir + base + ".fxforge.tres")
	if s["sequence"]:
		files.append(dir + base + "_seq/")
	if s["gif"]:
		files.append(dir + base + ".gif")
	return files


## 已经存在、会被覆盖的文件
static func existing_files(s: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for f: String in target_files(s):
		if f.ends_with("/"):
			if DirAccess.dir_exists_absolute(f):
				out.append(f)
		elif FileAccess.file_exists(f):
			out.append(f)
	return out


## 执行导出（协程，调用方要 await）。返回 {ok: bool, message: String, files: PackedStringArray, sheet_size: Vector2i}
## 目录对编辑器来说是新的时，update_file 不会登记新目录里的文件（4.7.1 实测），所以先等一次文件扫描。
static func run(preset: FxPreset, settings: Dictionary) -> Dictionary:
	var efs := EditorInterface.get_resource_filesystem()
	if efs.is_scanning() or efs.is_importing():
		return _fail("编辑器正在扫描或导入文件，请等几秒再导出。")
	var s := FxExport.normalize_settings(settings, preset)
	var dir: String = s["out_dir"]
	var base: String = s["base_name"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if not DirAccess.dir_exists_absolute(dir):
		return _fail("无法创建导出目录：" + dir)

	var rendered := FxExport.render_animations(preset, s)
	var sheet := FxExport.build_sheet(rendered, s)
	var files := PackedStringArray()

	# 1. 精灵图
	var png := dir + base + ".png"
	var err := (sheet["image"] as Image).save_png(png)
	if err != OK:
		return _fail("写入精灵图失败（%s）：%s" % [error_string(err), png])
	files.append(png)

	# 2. 让编辑器导入 PNG，再生成 SpriteFrames 和场景
	if s["sprite_frames"] or s["scene"]:
		if efs.get_filesystem_path(dir) == null:
			# 新目录：扫描会顺带导入里面的新图片
			efs.scan()
			var tree := Engine.get_main_loop() as SceneTree
			var waited := 0
			while (efs.is_scanning() or efs.is_importing() or not ResourceLoader.exists(png)) and waited < 1200:
				await tree.process_frame
				waited += 1
		else:
			efs.update_file(png)
			efs.reimport_files(PackedStringArray([png]))
		var tex := ResourceLoader.load(png, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
		if tex == null:
			return _fail("精灵图已写出，但编辑器没能导入它，可以稍后重新导出。", files)
		var sf_path := dir + base + "_frames.tres"
		var sf: SpriteFrames = null
		if ResourceLoader.exists(sf_path):
			sf = ResourceLoader.load(sf_path) as SpriteFrames
		var is_new := sf == null
		sf = FxExport.build_sprite_frames(tex, sheet, rendered, sf)
		if is_new:
			sf.take_over_path(sf_path)
		err = ResourceSaver.save(sf, sf_path)
		if err != OK:
			return _fail("保存 SpriteFrames 失败（%s）" % error_string(err), files)
		files.append(sf_path)
		if s["scene"]:
			var scene_path := dir + base + ".tscn"
			var ps := FxExport.build_scene(sf, sheet, rendered, s, FxExport.node_name(base))
			ps.take_over_path(scene_path)
			err = ResourceSaver.save(ps, scene_path)
			if err != OK:
				return _fail("保存场景失败（%s）" % error_string(err), files)
			files.append(scene_path)

	# 3. JSON
	if s["json"]:
		var json_path := dir + base + ".json"
		var f := FileAccess.open(json_path, FileAccess.WRITE)
		if f == null:
			return _fail("写入 JSON 失败：" + json_path, files)
		f.store_string(FxExport.build_json(sheet, rendered, s, base + ".png"))
		f.close()
		files.append(json_path)

	# 4. 单帧序列（Aseprite 可直接作为动画打开）
	if s["sequence"]:
		var seq_dir := dir + base + "_seq/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(seq_dir))
		var frames: Array = sheet["frames"]
		var idx := 0
		for a: Dictionary in rendered["anims"]:
			for i in (a["frames"] as Array).size():
				var name := "%s_%03d.png" % [base, i] if a["name"] == "default" else "%s_%s_%03d.png" % [base, a["name"], i]
				(frames[idx] as Image).save_png(seq_dir + name)
				idx += 1
		files.append(seq_dir)

	# 5. GIF 动图（编码放在工作线程里，大图也不卡编辑器）
	if s["gif"]:
		var gi := FxExport.gif_input(rendered, sheet, s)
		var box := {}
		var encode_gif := func() -> void:
			box["bytes"] = FxGif.encode(gi["frames"], gi["w"], gi["h"], gi["delays"], gi["background"], gi["scale"])
		var task := WorkerThreadPool.add_task(encode_gif, true, "FX Forge GIF")
		var tree := Engine.get_main_loop() as SceneTree
		while not WorkerThreadPool.is_task_completed(task):
			await tree.process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		var gif_path := dir + base + ".gif"
		var gf := FileAccess.open(gif_path, FileAccess.WRITE)
		if gf == null:
			return _fail("写入 GIF 失败：" + gif_path, files)
		gf.store_buffer(box.get("bytes", PackedByteArray()))
		gf.close()
		files.append(gif_path)

	# 6. 预设副本（以后双击它就能回到特效工坊继续改）
	if s["preset_copy"]:
		var copy: FxPreset = preset.clone()
		copy.export_settings = s.duplicate()
		var copy_path := dir + base + ".fxforge.tres"
		copy.take_over_path(copy_path)
		err = ResourceSaver.save(copy, copy_path)
		if err == OK:
			files.append(copy_path)

	efs.scan()
	var size := (sheet["image"] as Image).get_size()
	var anims: Array = rendered["anims"]
	var per := (anims[0]["frames"] as Array).size()
	return {
		"ok": true,
		"message": "导出完成：%d 个动画 × %d 帧，精灵图 %d×%d 像素。" % [anims.size(), per, size.x, size.y],
		"files": files,
		"sheet_size": size,
	}


static func _fail(message: String, files: PackedStringArray = PackedStringArray()) -> Dictionary:
	return {"ok": false, "message": message, "files": files, "sheet_size": Vector2i.ZERO}
