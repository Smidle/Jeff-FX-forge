extends SceneTree
## 性能报告（开发用）：每个内置预设整段渲染的耗时（原尺寸、整体缩放 2 倍），以及 3 倍 GIF 编码耗时。
##   godot --headless --path . --script res://tests/perf_report.gd
## 拖动参数时，整段渲染超过 main_panel 的 DRAG_FULL_BUDGET_MS 就只重算当前帧，所以这里主要看「原尺寸」一列。

const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const FxGif := preload("res://addons/fx_forge/export/fx_gif.gd")


func _initialize() -> void:
	print("%-16s %9s %4s %9s %9s %9s" % ["预设", "画布", "帧", "原尺寸", "放大2倍", "GIF×3"])
	var worst := ""
	var worst_ms := 0.0
	var total := 0.0
	for p: Resource in Builtin.all():
		var ms1 := _render_ms(p, 1.0)
		var ms2 := _render_ms(p, 2.0)
		var job := FxRenderer.make_job(p)
		FxRenderer.render_sync(job)
		var datas: Array = []
		for img: Image in job.images():
			var big: Image = img.duplicate()
			big.resize(job.w * 3, job.h * 3, Image.INTERPOLATE_NEAREST)
			datas.append(big.get_data())
		var t0 := Time.get_ticks_usec()
		FxGif.encode(datas, job.w * 3, job.h * 3, FxGif.delays_for(datas.size(), float(job.fps)), null, 3)
		var gif_ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("%-16s %4dx%-4d %4d %7.1fms %7.1fms %7.0fms" % [p.preset_id, job.w, job.h, job.frame_count, ms1, ms2, gif_ms])
		total += ms1
		if ms1 > worst_ms:
			worst_ms = ms1
			worst = p.preset_id
	print("合计 %.0f ms，最慢 %s %.1f ms（%d 个工作线程）" % [total, worst, worst_ms, OS.get_processor_count()])
	quit(0)


func _render_ms(p: Resource, scale: float) -> float:
	var c: Resource = p.clone()
	c.globals["size_scale"] = scale
	var best := INF
	for i in 3:
		var t0 := Time.get_ticks_usec()
		var job := FxRenderer.make_job(c)
		FxRenderer.render_sync(job)
		best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
	return best
