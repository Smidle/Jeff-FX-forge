extends "res://tests/test_base.gd"
## 渲染层测试：内置预设、确定性、方向、缩放、耗时

const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const FxPresetUtil := preload("res://addons/fx_forge/core/fx_preset_util.gd")
const FxRegistry := preload("res://addons/fx_forge/core/fx_registry.gd")

## 默认尺寸下单个预设整段渲染的耗时上限（毫秒）
const BUDGET_MS := 2000.0


func _bytes(images: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for img: Image in images:
		out.append_array(img.get_data())
	return out


## 所有帧叠在一起后，不透明像素的重心（相对画布中心）
func _centroid(images: Array) -> Vector2:
	var first: Image = images[0]
	var sum := Vector2.ZERO
	var n := 0
	for y in first.get_height():
		for x in first.get_width():
			for img: Image in images:
				if img.get_pixel(x, y).a > 0.5:
					sum += Vector2(x, y) + Vector2(0.5, 0.5)
					n += 1
					break
	if n == 0:
		return Vector2.ZERO
	return sum / n - Vector2(first.get_width(), first.get_height()) * 0.5


func test_builtin_presets_render() -> bool:
	var presets := Builtin.all()
	check(presets.size() >= 6, "至少 6 个内置预设")
	var ids := {}
	for p: Resource in presets:
		check(not ids.has(p.preset_id), "预设 id 不重复：" + p.preset_id)
		ids[p.preset_id] = true
		check(not p.layers.is_empty(), p.preset_id + " 至少一个图层")
		for l: Dictionary in p.layers:
			check(FxRegistry.has_module(l["module"]), "%s 的模块 %s 已注册" % [p.preset_id, l["module"]])
		var t0 := Time.get_ticks_usec()
		var job := FxRenderer.make_job(p)
		FxRenderer.render_sync(job)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		check(ms < BUDGET_MS, "%s 渲染耗时 %.0f ms（上限 %.0f）" % [p.preset_id, ms, BUDGET_MS])
		var non_empty := 0
		var touched := false
		for r: Dictionary in job.results:
			var img: Image = r["image"]
			check_eq(img.get_size(), Vector2i(job.w, job.h), p.preset_id + " 帧尺寸")
			if int(r["opaque"]) > 0:
				non_empty += 1
			touched = touched or bool(r["edge"])
		check(non_empty >= job.frame_count - 1, "%s 几乎每帧都有内容（%d/%d）" % [p.preset_id, non_empty, job.frame_count])
		check(not touched, p.preset_id + " 没有超出画布")
	return true


func test_render_is_deterministic_and_thread_safe() -> bool:
	var p: Resource = Builtin.find("slash_fire")
	var a := _bytes(FxRenderer.render_images(p))
	var b := _bytes(FxRenderer.render_images(p))
	var c := _bytes(FxRenderer.render_images(p, {"threaded": false}))
	check(a == b, "同参数两次渲染逐字节一致")
	check(a == c, "多线程与单线程结果一致")
	return true


func test_seed_changes_output() -> bool:
	var p: Resource = Builtin.find("slash_fire")
	var a := _bytes(FxRenderer.render_images(p))
	var q: Resource = p.clone()
	q.globals["seed"] = 7
	var b := _bytes(FxRenderer.render_images(q))
	check(a != b, "换种子后结果不同")
	return true


func test_direction_rotates_effect() -> bool:
	var p: Resource = Builtin.find("slash_basic")
	var right := _centroid(FxRenderer.render_images(p, {"direction": 0.0}))
	var left := _centroid(FxRenderer.render_images(p, {"direction": 180.0}))
	var down := _centroid(FxRenderer.render_images(p, {"direction": 90.0}))
	check(right.x > 4.0 and absf(right.y) < 2.5, "方向 0°：整段刀光在右侧（%s）" % right)
	check(left.x < -4.0 and absf(left.y) < 2.5, "方向 180°：整段刀光在左侧（%s）" % left)
	check(down.y > 4.0 and absf(down.x) < 2.5, "方向 90°：整段刀光在下方（%s）" % down)
	return true


func test_size_scale_scales_canvas() -> bool:
	var p: Resource = Builtin.find("slash_basic").clone()
	p.globals["size_scale"] = 2.0
	var job := FxRenderer.make_job(p)
	check_eq(job.w, 128, "整体缩放 2 倍后画布宽 128")
	FxRenderer.render_sync(job)
	var touched := false
	for r: Dictionary in job.results:
		touched = touched or bool(r["edge"])
	check(not touched, "放大后依然不超出画布")
	return true


func test_frame_time_mapping() -> bool:
	var p: Resource = Builtin.find("slash_basic").clone()
	var job := FxRenderer.make_job(p)
	check_near(job.frame_time(0), 0.5 / job.frame_count, 0.0001, "一次性特效首帧取帧中点")
	p.globals["loop"] = true
	var loop_job := FxRenderer.make_job(p)
	check_near(loop_job.frame_time(0), 0.0, 0.0001, "循环特效首帧从 0 开始")
	return true


func test_unknown_module_layer_is_skipped() -> bool:
	var p: Resource = FxPresetUtil.new_blank()
	p.layers.append({"module": "不存在的模块", "params": {}})
	var norm := FxPresetUtil.normalized(p)
	check_eq((norm["layers"] as Array).size(), 1, "未知模块的图层被跳过")
	var imgs := FxRenderer.render_images(p)
	check_eq(imgs.size(), 12, "依然能正常渲染")
	return true
