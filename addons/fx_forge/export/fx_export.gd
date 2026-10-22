@tool
extends RefCounted
## 导出的纯计算部分（不依赖编辑器，可无头测试）：
## 规划动画（方向批量 / 随机变体）→ 渲染 → 裁边 / 放大 → 拼精灵图 → JSON / SpriteFrames / 即用场景

const FxRenderer := preload("../core/fx_renderer.gd")
const FxPreset := preload("../core/fx_preset.gd")
const FxGif := preload("fx_gif.gd")

const VERSION := "1.2.0-local"
const APP_NAME := "Jeff FX"

## 方向角 → 动画名
const DIRECTION_NAMES := {
	0: "right", 45: "down_right", 90: "down", 135: "down_left",
	180: "left", 225: "up_left", 270: "up", 315: "up_right",
}
const LAYOUT_OPTIONS := [["auto", "自动"], ["row", "每个动画一行"], ["grid", "固定列数"]]
const DIRECTION_OPTIONS := [["none", "不批量"], ["mirror", "左右（原样 + 水平镜像）"], ["4", "4 方向"], ["8", "8 方向"]]
const BLEND_OPTIONS := [["normal", "正常"], ["add", "发光叠加"]]
const GIF_BG_OPTIONS := [["transparent", "透明"], ["dark", "深色底"], ["light", "浅色底"]]
const GIF_BG_COLORS := {"dark": Color("1d1d27"), "light": Color("e8e2d0")}
## 一次性特效的 GIF 播完后停多久再重播（1/100 秒）
const GIF_END_PAUSE := 40

## 即用场景内嵌的运行时脚本：不是 @tool，所以在编辑器里预览动画不会删掉节点
const ONE_SHOT_SOURCE := """extends AnimatedSprite2D
## FX Forge 导出的特效：自动播放；一次性特效播完自动删除自己。

## 一次性（不循环）的特效播完后自动删除
@export var free_on_finish := true
## 生成时随机左右镜像（用 scale.x 翻转，锚点保持不动）
@export var random_flip_h := false


func _ready() -> void:
	if random_flip_h and randf() < 0.5:
		scale.x = -scale.x
	if free_on_finish and sprite_frames != null and not sprite_frames.get_animation_loop(animation):
		animation_finished.connect(queue_free)
	play()
"""


static func default_settings(preset: FxPreset) -> Dictionary:
	return {
		"base_name": ascii_name(preset.preset_id if preset != null else "", "effect"),
		"out_dir": "res://fx_exports/",
		"layout": "auto",
		"columns": 8,
		"padding": 0,
		"margin": 0,
		"trim": false,
		"scale": 1,
		"directions": "none",
		"variants": 1,
		"json": true,
		"sprite_frames": true,
		"scene": true,
		"sequence": false,
		"preset_copy": true,
		"blend": "normal",
		"gif": false,
		"gif_scale": 3,
		"gif_bg": "transparent",
		"capture_size": 256,
		"capture_fps": 24,
		"capture_seconds": (minf(10, maxf(.1, preset.legacy_recipe.duration if preset.legacy_recipe.looping else preset.legacy_recipe.total_duration()) / maxf(.1, preset.legacy_recipe.playback_speed)) if preset != null and preset.legacy_recipe != null else 2.0),
	}


## 补齐缺省、校正非法值
static func normalize_settings(s: Dictionary, preset: FxPreset) -> Dictionary:
	var d := default_settings(preset)
	for k: String in d:
		if not s.has(k):
			continue
		var v: Variant = s[k]
		match typeof(d[k]):
			TYPE_FLOAT:
				if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
					d[k] = float(v)
			TYPE_INT:
				if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
					d[k] = int(v)
			TYPE_BOOL:
				if typeof(v) == TYPE_BOOL:
					d[k] = v
			TYPE_STRING:
				if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
					d[k] = str(v)
	d["capture_size"] = clampi(d["capture_size"], 64, 512)
	d["capture_fps"] = clampi(d["capture_fps"], 6, 30)
	d["capture_seconds"] = clampf(d["capture_seconds"], .1, 10.0) if is_finite(d["capture_seconds"]) else 2.0
	d["columns"] = clampi(d["columns"], 1, 64)
	d["padding"] = clampi(d["padding"], 0, 16)
	d["margin"] = clampi(d["margin"], 0, 16)
	d["scale"] = clampi(d["scale"], 1, 4)
	d["variants"] = clampi(d["variants"], 1, 8)
	d["gif_scale"] = clampi(d["gif_scale"], 1, 8)
	if not ["transparent", "dark", "light"].has(d["gif_bg"]):
		d["gif_bg"] = "transparent"
	d["base_name"] = ascii_name(d["base_name"], "effect")
	var dir: String = str(d["out_dir"]).strip_edges()
	if not dir.begins_with("res://"):
		dir = "res://fx_exports/"
	if not dir.ends_with("/"):
		dir += "/"
	d["out_dir"] = dir
	if not ["auto", "row", "grid"].has(d["layout"]):
		d["layout"] = "auto"
	if not ["none", "mirror", "4", "8"].has(d["directions"]):
		d["directions"] = "none"
	if not ["normal", "add"].has(d["blend"]):
		d["blend"] = "normal"
	return d


## 要导出的动画列表：[{name, direction（null = 用预设自己的方向）, seed_offset, mirror}]
static func plan_animations(s: Dictionary) -> Array:
	var dirs: Array = []
	match s["directions"]:
		"mirror":
			dirs = [{"name": "right", "dir": null, "mirror": false}, {"name": "left", "dir": null, "mirror": true}]
		"4":
			for a: int in [0, 90, 180, 270]:
				dirs.append({"name": DIRECTION_NAMES[a], "dir": float(a), "mirror": false})
		"8":
			for a: int in [0, 45, 90, 135, 180, 225, 270, 315]:
				dirs.append({"name": DIRECTION_NAMES[a], "dir": float(a), "mirror": false})
		_:
			dirs = [{"name": "default", "dir": null, "mirror": false}]
	var out: Array = []
	for v in int(s["variants"]):
		for d: Dictionary in dirs:
			var name: String = d["name"] if v == 0 else "%s_v%d" % [d["name"], v + 1]
			out.append({"name": name, "direction": d["dir"], "seed_offset": v, "mirror": d["mirror"]})
	return out


## 渲染所有动画：{anims: [{name, frames: Array[Image]}], fps, loop, origin: Vector2, canvas: Vector2i,
##   durations: PackedFloat32Array（每帧时长倍数，打击停顿）}
static func render_animations(preset: FxPreset, s: Dictionary) -> Dictionary:
	var anims: Array = []
	var info := {"fps": 12, "loop": false, "origin": Vector2.ZERO, "canvas": Vector2i.ONE, "durations": PackedFloat32Array()}
	for a: Dictionary in plan_animations(s):
		var opts := {"seed_offset": a["seed_offset"]}
		if a["direction"] != null:
			opts["direction"] = a["direction"]
		var job := FxRenderer.make_job(preset, opts)
		FxRenderer.render_sync(job)
		var frames := job.images()
		if a["mirror"]:
			var mirrored: Array = []
			for img: Image in frames:
				var c: Image = img.duplicate()
				c.flip_x()
				mirrored.append(c)
			frames = mirrored
		anims.append({"name": a["name"], "frames": frames, "origin": Vector2(job.w - job.origin.x, job.origin.y) if a["mirror"] else job.origin})
		info = {"fps": job.fps, "loop": job.loop, "origin": job.origin, "canvas": Vector2i(job.w, job.h), "durations": job.durations}
	info["anims"] = anims
	return align_animation_origins(info)


## SpriteFrames uses one scene offset for all animations. Pad each direction
## to a shared anchor instead of letting a mirrored off-centre pivot jump.
static func align_animation_origins(rendered: Dictionary) -> Dictionary:
	var canvas: Vector2i = rendered.canvas
	var original: Vector2 = rendered.origin
	var same := true
	var left := original.x
	var right := canvas.x - original.x
	for a: Dictionary in rendered.anims:
		var pivot: Vector2 = a.get("origin", original)
		same = same and pivot.is_equal_approx(original)
		left = maxf(left, pivot.x)
		right = maxf(right, canvas.x - pivot.x)
	if same: return rendered
	var common := Vector2(ceilf(left), original.y)
	var width := ceili(left) + ceili(right)
	for a: Dictionary in rendered.anims:
		var pivot: Vector2 = a.get("origin", original)
		var offset := Vector2i(roundi(common.x - pivot.x), 0)
		var aligned: Array = []
		for frame: Image in a.frames:
			var img := Image.create_empty(width, canvas.y, false, Image.FORMAT_RGBA8)
			img.blit_rect(frame, Rect2i(Vector2i.ZERO, canvas), offset)
			aligned.append(img)
		a.frames = aligned
		a.origin = common
	rendered.origin = common
	rendered.canvas = Vector2i(width, canvas.y)
	return rendered


## 排布：每个动画从新的一行开始。返回 {size: Vector2i, rects: Array[Rect2i]}
static func layout(counts: Array, fw: int, fh: int, mode: String, columns: int, padding: int, margin: int) -> Dictionary:
	var total := 0
	var longest := 1
	for c: int in counts:
		total += c
		longest = maxi(longest, c)
	var cols := longest
	if mode == "grid":
		cols = clampi(columns, 1, longest)
	elif mode == "auto" and counts.size() == 1 and total > 16:
		cols = ceili(sqrt(float(total)))
	var rects: Array = []
	var row := 0
	for c: int in counts:
		for i in c:
			@warning_ignore("integer_division")
			var r := row + i / cols
			var x := margin + (i % cols) * (fw + padding)
			var y := margin + r * (fh + padding)
			rects.append(Rect2i(x, y, fw, fh))
		row += ceili(float(c) / float(cols))
	var size := Vector2i(margin * 2 + cols * fw + (cols - 1) * padding, margin * 2 + row * fh + (row - 1) * padding)
	return {"size": size, "rects": rects}


## 裁边、放大、拼图。返回：
##   image（精灵图）、frames（处理后的单帧）、rects（每帧在图中的位置）、frame_size、
##   pivot（锚点，单帧内的整数像素坐标）、crop（裁剪框，原画布坐标）、source_size（放大后的原画布尺寸）、tags
static func build_sheet(rendered: Dictionary, s: Dictionary) -> Dictionary:
	var anims: Array = rendered["anims"]
	var canvas: Vector2i = rendered["canvas"]
	var origin: Vector2 = rendered["origin"]
	var crop := Rect2i(Vector2i.ZERO, canvas)
	if s["trim"]:
		var u := Rect2i()
		for a: Dictionary in anims:
			for img: Image in a["frames"]:
				var r := img.get_used_rect()
				if r.size.x > 0:
					u = r if u.size.x == 0 else u.merge(r)
		if u.size.x > 0:
			crop = u
	var sc: int = s["scale"]
	var fw := crop.size.x * sc
	var fh := crop.size.y * sc
	var frames: Array = []
	var counts: Array = []
	var tags: Array = []
	for a: Dictionary in anims:
		var list: Array = a["frames"]
		tags.append({"name": a["name"], "from": frames.size(), "to": frames.size() + list.size() - 1, "direction": "forward"})
		counts.append(list.size())
		for img: Image in list:
			var f: Image = img.get_region(crop) if crop.size != canvas else img.duplicate()
			if sc > 1:
				f.resize(fw, fh, Image.INTERPOLATE_NEAREST)
			frames.append(f)
	var lay := layout(counts, fw, fh, s["layout"], s["columns"], s["padding"], s["margin"])
	var size: Vector2i = lay["size"]
	var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var rects: Array = lay["rects"]
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, fw, fh), (rects[i] as Rect2i).position)
	var pivot := ((origin - Vector2(crop.position)) * sc).floor()
	return {
		"image": sheet, "frames": frames, "rects": rects, "frame_size": Vector2i(fw, fh),
		"pivot": pivot, "crop": crop, "source_size": canvas * sc, "tags": tags,
	}


## Aseprite 数组格式的 JSON（多数引擎和工具都能读），meta 里额外记录锚点、帧率、是否循环
static func build_json(sheet: Dictionary, rendered: Dictionary, s: Dictionary, image_file: String) -> String:
	var rects: Array = sheet["rects"]
	var crop: Rect2i = sheet["crop"]
	var sc: int = s["scale"]
	var fs: Vector2i = sheet["frame_size"]
	var src: Vector2i = sheet["source_size"]
	var frame_ms := 1000.0 / float(rendered["fps"])
	var mults: PackedFloat32Array = rendered.get("durations", PackedFloat32Array())
	var frames: Array = []
	var idx := 0
	for a: Dictionary in rendered["anims"]:
		for i in (a["frames"] as Array).size():
			var duration := roundi(frame_ms * (mults[i] if i < mults.size() else 1.0))
			var r: Rect2i = rects[idx]
			frames.append({
				"filename": "%s %s %d.png" % [s["base_name"], a["name"], i],
				"frame": {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y},
				"rotated": false,
				"trimmed": s["trim"],
				"spriteSourceSize": {"x": crop.position.x * sc, "y": crop.position.y * sc, "w": fs.x, "h": fs.y},
				"sourceSize": {"w": src.x, "h": src.y},
				"duration": duration,
			})
			idx += 1
	var img: Image = sheet["image"]
	var pivot: Vector2 = sheet["pivot"]
	var meta := {
		"app": APP_NAME, "version": VERSION, "image": image_file, "format": "RGBA8888",
		"size": {"w": img.get_width(), "h": img.get_height()}, "scale": str(sc),
		"frameTags": sheet["tags"], "layers": [], "slices": [],
		"pivot": {"x": int(pivot.x), "y": int(pivot.y)}, "fps": rendered["fps"], "loop": rendered["loop"],
	}
	return JSON.stringify({"frames": frames, "meta": meta}, "\t")


## 生成（或原地更新）SpriteFrames：每个动画一组 AtlasTexture，指向精灵图里的区域
static func build_sprite_frames(tex: Texture2D, sheet: Dictionary, rendered: Dictionary, sf: SpriteFrames = null) -> SpriteFrames:
	if sf == null:
		sf = SpriteFrames.new()
	else:
		sf.clear_all()
	var rects: Array = sheet["rects"]
	var loop: bool = rendered["loop"]
	var mults: PackedFloat32Array = rendered.get("durations", PackedFloat32Array())
	var idx := 0
	var first := ""
	for a: Dictionary in rendered["anims"]:
		var name := StringName(a["name"])
		if not sf.has_animation(name):
			sf.add_animation(name)
		sf.set_animation_speed(name, float(rendered["fps"]))
		if sf.has_method(&"set_animation_loop_mode"):
			var mode := ClassDB.class_get_integer_constant(&"SpriteFrames", &"LOOP_LINEAR" if loop else &"LOOP_NONE")
			sf.call(&"set_animation_loop_mode", name, mode)
		else:
			sf.set_animation_loop(name, loop)
		for i in (a["frames"] as Array).size():
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(rects[idx])
			at.filter_clip = true
			# 帧时长倍数（打击停顿的那一帧更长）
			sf.add_frame(name, at, mults[i] if i < mults.size() else 1.0)
			idx += 1
		if first.is_empty():
			first = a["name"]
	if first != "default" and sf.has_animation(&"default") and sf.get_frame_count(&"default") == 0:
		sf.remove_animation(&"default")
	return sf


## 即用场景：AnimatedSprite2D（最近邻、锚点对齐、自动播放）+ 内嵌运行时脚本
static func build_scene(sf: SpriteFrames, sheet: Dictionary, rendered: Dictionary, s: Dictionary, node_name: String) -> PackedScene:
	var root := AnimatedSprite2D.new()
	root.name = node_name
	root.sprite_frames = sf
	var first: String = (rendered["anims"][0] as Dictionary)["name"]
	root.animation = StringName(first)
	root.autoplay = first
	root.centered = false
	root.offset = -(sheet["pivot"] as Vector2)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if s["blend"] == "add":
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		root.material = mat
	var script := GDScript.new()
	script.source_code = ONE_SHOT_SOURCE
	script.reload()
	root.set_script(script)
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


## GIF 的输入（只取第一个动画，预览分享用）：{frames: Array[PackedByteArray], w, h, delays, background, scale}
## 和精灵图一样裁边；按 gif_scale 放大；一次性特效末尾加一帧空白停顿，循环播放时能看清开头。
## Image 的读取都在这里（主线程）完成，编码可以交给工作线程。
static func gif_input(rendered: Dictionary, sheet: Dictionary, s: Dictionary) -> Dictionary:
	var crop: Rect2i = sheet["crop"]
	var canvas: Vector2i = rendered["canvas"]
	var sc: int = s["gif_scale"]
	var w := crop.size.x * sc
	var h := crop.size.y * sc
	var list: Array = (rendered["anims"][0] as Dictionary)["frames"]
	var datas: Array = []
	for img: Image in list:
		var f: Image = img.get_region(crop) if crop.size != canvas else img.duplicate()
		if sc > 1:
			f.resize(w, h, Image.INTERPOLATE_NEAREST)
		datas.append(f.get_data())
	var delays := FxGif.delays_for(list.size(), float(rendered["fps"]), rendered.get("durations", PackedFloat32Array()))
	var bg: Variant = GIF_BG_COLORS.get(s["gif_bg"], null)
	if not rendered["loop"]:
		var blank := PackedByteArray()
		blank.resize(w * h * 4)
		blank.fill(0)
		datas.append(blank)
		delays.append(GIF_END_PAUSE)
	return {"frames": datas, "w": w, "h": h, "delays": delays, "background": bg, "scale": sc}


## 只保留英文字母、数字、下划线和连字符（文件名用）
static func ascii_name(text: String, fallback: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return out if not out.is_empty() else fallback


## slash_fire → SlashFire（场景根节点名）
static func node_name(base: String) -> String:
	var out := ""
	for part in base.replace("-", "_").split("_", false):
		out += part.capitalize().replace(" ", "")
	return out if not out.is_empty() else "Effect"
