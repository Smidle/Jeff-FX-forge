extends SceneTree
## 预设画廊：把每个内置预设渲染成放大的帧条，方便目视检查美术效果。
##   godot --headless --path . --script res://tests/render_gallery.gd [-- 预设id过滤]
## 输出：tests/output/gallery/<id>.png、_all.png（总览）、_directions.png（基础刀光 8 个方向）

const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")

const OUT := "res://tests/output/gallery/"
const ZOOM := 3
const GAP := 6
const BG_A := Color("1d1d27")
const BG_B := Color("24243a")
const BG_LIGHT := Color("e8e2d0")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ignore := ProjectSettings.globalize_path("res://tests/output/.gdignore")
	if not FileAccess.file_exists(ignore):
		FileAccess.open(ignore, FileAccess.WRITE)
	var filter := ""
	if not OS.get_cmdline_user_args().is_empty():
		filter = OS.get_cmdline_user_args()[0]
	var rows: Array = []
	print("%-14s %-8s %9s %5s %9s" % ["id", "名称", "尺寸", "帧", "耗时"])
	for p: Resource in Builtin.all():
		if not filter.is_empty() and not p.preset_id.contains(filter):
			continue
		var t0 := Time.get_ticks_usec()
		var job := FxRenderer.make_job(p)
		FxRenderer.render_sync(job)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		var light: bool = p.globals.get("palette_main", "") == "ink"
		var strip := _strip(job.images(), light)
		strip.save_png(OUT + p.preset_id + ".png")
		rows.append(strip)
		var warn := ""
		for r: Dictionary in job.results:
			if r["edge"]:
				warn = "  ⚠ 超出画布"
		print("%-14s %-8s %4dx%-4d %5d %7.1fms%s" % [p.preset_id, p.display_name, job.w, job.h, job.frame_count, ms, warn])
	if not rows.is_empty():
		_stack(rows).save_png(OUT + "_all.png")
	if filter.is_empty() or "slash_basic".contains(filter):
		var p: Resource = Builtin.find("slash_basic")
		var mid := PackedInt32Array([4])
		var dirs: Array = []
		for k in 8:
			dirs.append(FxRenderer.render_images(p, {"frames": mid, "direction": 45.0 * k})[0])
		_strip(dirs, false).save_png(OUT + "_directions.png")
	print("画廊已输出到 ", ProjectSettings.globalize_path(OUT))
	quit(0)


## 帧条：每帧放大 ZOOM 倍，铺棋盘格背景（看得出透明区域），帧间留空
func _strip(frames: Array, light: bool) -> Image:
	var fw: int = (frames[0] as Image).get_width() * ZOOM
	var fh: int = (frames[0] as Image).get_height() * ZOOM
	var out := Image.create_empty(GAP + frames.size() * (fw + GAP), fh + GAP * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color("101018"))
	for i in frames.size():
		var x0 := GAP + i * (fw + GAP)
		var bg := Image.create_empty(fw, fh, false, Image.FORMAT_RGBA8)
		for cy in range(0, fh, 8):
			for cx in range(0, fw, 8):
				var col := BG_LIGHT if light else (BG_A if ((cx / 8 + cy / 8) % 2 == 0) else BG_B)
				bg.fill_rect(Rect2i(cx, cy, 8, 8), col)
		out.blit_rect(bg, Rect2i(0, 0, fw, fh), Vector2i(x0, GAP))
		var big: Image = (frames[i] as Image).duplicate()
		big.resize(fw, fh, Image.INTERPOLATE_NEAREST)
		out.blend_rect(big, Rect2i(0, 0, fw, fh), Vector2i(x0, GAP))
	return out


func _stack(rows: Array) -> Image:
	var w := 0
	var h := 0
	for r: Image in rows:
		w = maxi(w, r.get_width())
		h += r.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color("101018"))
	var y := 0
	for r: Image in rows:
		out.blit_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), Vector2i(0, y))
		y += r.get_height()
	return out
