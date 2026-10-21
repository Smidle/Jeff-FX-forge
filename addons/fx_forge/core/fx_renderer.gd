@tool
extends RefCounted
## 渲染入口：把预设变成 FxJob；提供同步渲染（测试 / 导出）和异步渲染（编辑器预览）。

const FxJob := preload("fx_job.gd")
const FxParams := preload("fx_params.gd")
const FxPalette := preload("fx_palette.gd")
const FxContext := preload("fx_context.gd")
const FxRegistry := preload("fx_registry.gd")
const FxPreset := preload("fx_preset.gd")
const FxPresetUtil := preload("fx_preset_util.gd")
const FxModule := preload("../modules/fx_module.gd")
const FxMath := preload("fx_math.gd")

const _DISSOLVE_IDS := ["dither", "shrink", "darken", "fade"]
const _OUTLINE_IDS := ["none", "outer", "inner", "selective"]

## 画布边长上限（防止误操作卡死编辑器）
const MAX_CANVAS := 1024


## opts：
##   frames: PackedInt32Array —— 只渲染这些帧（默认全部）
##   direction: float —— 覆盖全局方向（多方向批量导出用）
##   seed_offset: int —— 种子偏移（导出多个变体用）
static func make_job(preset: FxPreset, opts: Dictionary = {}) -> FxJob:
	var norm := FxPresetUtil.normalized(preset)
	var g: Dictionary = norm["globals"]
	var sc: float = g["size_scale"]
	var job := FxJob.new()
	job.w = clampi(roundi(float(g["canvas_w"]) * sc), 1, MAX_CANVAS)
	job.h = clampi(roundi(float(g["canvas_h"]) * sc), 1, MAX_CANVAS)
	job.frame_count = g["frames"]
	job.fps = g["fps"]
	job.loop = g["loop"]
	var ids: PackedInt32Array = opts.get("frames", PackedInt32Array())
	if ids.is_empty():
		ids = PackedInt32Array(range(job.frame_count))
	job.frame_ids = ids
	job.results.resize(ids.size())
	job.origin = Vector2(float(g["origin_x"]) * job.w, float(g["origin_y"]) * job.h)

	var direction: float = float(opts.get("direction", g["direction"]))
	var seed: int = int(g["seed"]) + int(opts.get("seed_offset", 0))
	var palettes := {
		"main": FxPalette.colors_of(g["palette_main"]),
		"accent": FxPalette.colors_of(g["palette_accent"]),
		"smoke": FxPalette.colors_of(g["palette_smoke"]),
	}
	var index := 0
	for l: Dictionary in norm["layers"]:
		index += 1
		if not l["enabled"]:
			continue
		var m: FxModule = FxRegistry.get_module(l["module"])
		var params := FxParams.apply_scale(m.get_param_defs(), l["params"], sc)
		var follow: bool = l["follow_dir"]
		var ctx := FxContext.new()
		ctx.w = job.w
		ctx.h = job.h
		ctx.angle = deg_to_rad((direction if follow else 0.0) + float(l["angle_offset"]))
		ctx.cos_a = cos(ctx.angle)
		ctx.sin_a = sin(ctx.angle)
		var off := Vector2(float(l["offset_x"]), float(l["offset_y"])) * sc
		if follow:
			off = off.rotated(deg_to_rad(direction))
		ctx.ox = job.origin.x + off.x
		ctx.oy = job.origin.y + off.y
		ctx.scale = sc
		ctx.frames = job.frame_count
		ctx.loop = job.loop
		ctx.seed = FxMath.mix_seed(seed, index)
		ctx.bayer = FxPalette.BAYER4
		var rng := RandomNumberGenerator.new()
		rng.seed = ctx.seed
		var state := m.prepare(params, ctx, rng)
		var cols: PackedColorArray = palettes[l["palette_slot"]]
		var r := PackedFloat32Array()
		var gg := PackedFloat32Array()
		var b := PackedFloat32Array()
		for c in cols:
			r.append(c.r)
			gg.append(c.g)
			b.append(c.b)
		job.layers.append({
			"module": m, "params": params, "state": state, "ctx": ctx,
			"t0": float(l["t_start"]), "t1": float(l["t_end"]),
			"r": r, "g": gg, "b": b, "outline": l["outline"],
		})

	var main_cols: PackedColorArray = palettes["main"]
	var outline_rgb: Color = main_cols[0] if g["outline_color_mode"] == "darkest" else g["outline_color"]
	job.post = {
		"bayer": FxPalette.BAYER4,
		"dither_tab": FxPalette.dither_table(g["dither"]),
		"dither_strength": float(g["dither_strength"]) if g["dither"] != "none" else 0.0,
		"dissolve": _DISSOLVE_IDS.find(g["dissolve"]),
		"alpha_levels": g["alpha_levels"],
		"cleanup": g["cleanup"],
		"min_cluster": g["min_cluster"],
		"outline": _OUTLINE_IDS.find(g["outline"]),
		"outline_width": g["outline_width"],
		"outline_square": g["outline_corner"] == "square",
		"outline_rgb": outline_rgb,
		"soft": g["soft"],
		"glow_rgb": main_cols[maxi(main_cols.size() - 2, 0)],
		"flip_h": g["flip_h"],
		"flip_v": g["flip_v"],
	}
	return job


## 同步渲染（会阻塞调用线程，测试与导出用）
static func render_sync(job: FxJob, threaded: bool = true) -> void:
	var n := job.frame_ids.size()
	if threaded and n > 1:
		var gid := WorkerThreadPool.add_group_task(job.render_frame, n, -1, true, "FX Forge 渲染")
		WorkerThreadPool.wait_for_group_task_completion(gid)
	else:
		for i in n:
			job.render_frame(i)


## 异步渲染：返回分组任务 id。调用方必须保持 job 的引用，
## 用 is_group_task_completed() 轮询，完成后恰好调用一次 wait_for_group_task_completion()。
static func start_async(job: FxJob) -> int:
	return WorkerThreadPool.add_group_task(job.render_frame, job.frame_ids.size(), -1, true, "FX Forge 预览")


## 便捷函数：渲染整个预设，返回 Image 数组
static func render_images(preset: FxPreset, opts: Dictionary = {}) -> Array:
	var job := make_job(preset, opts)
	render_sync(job, bool(opts.get("threaded", true)))
	return job.images()
