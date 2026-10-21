@tool
extends "fx_module.gd"
## 闪电：落雷、电弧、放射状闪电。
## 用中点位移生成锯齿折线和分支；整段动画里闪几次，每次换一个随机形状。
##   落雷：从「方向」那头远处劈到原点（原点 = 落点），第一下有劈下来的过程
##   电弧：从原点连到「方向」那头，持续跳动（适合循环）
##   放射：从原点向四周放出几道闪电（数量 = 分支数 + 1）

const P := preload("../core/fx_params.gd")

const MODE_OPTIONS := [["strike", "落雷（劈到原点）"], ["arc", "电弧（原点连到远端）"], ["radial", "放射（向四周）"]]


func get_id() -> String:
	return "bolt"


func get_display_name() -> String:
	return "闪电"


func get_display_name_en() -> String:
	return "Bolt"


func get_description() -> String:
	return "落雷、电弧、放射闪电"


func is_directional() -> bool:
	return true


func get_layer_defaults() -> Dictionary:
	return {"outline": false}


func get_param_defs() -> Array:
	return [
		P.choice("mode", "模式", "Mode", MODE_OPTIONS, "strike", {group = "shape"}),
		P.num("length", "长度", "Length", 4.0, 400.0, 60.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.integer("segments", "折段数", "Segments", 2, 40, 10, {group = "shape", tip = "主干折几次"}),
		P.num("jag", "锯齿幅度", "Jaggedness", 0.0, 1.0, 0.35, {group = "shape"}),
		P.integer("branches", "分支数", "Branches", 0, 8, 2, {group = "shape"}),
		P.num("branch_len", "分支长度", "Branch Length", 0.05, 1.0, 0.4, {group = "shape", hide_if = ["branches", 0]}),
		P.num("width", "粗细", "Width", 0.5, 12.0, 1.2, {group = "shape", unit = "px", scale = true, step = 0.1, tip = "亮芯的半宽"}),
		P.num("glow", "光晕宽度", "Glow", 0.0, 16.0, 2.5, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "亮芯外面较暗的一圈"}),
		P.integer("flashes", "闪烁次数", "Flashes", 1, 8, 3, {group = "motion", tip = "整段动画里闪几下，每下换一个形状"}),
		P.num("on_ratio", "点亮比例", "On Ratio", 0.2, 1.0, 0.7, {group = "motion", tip = "每一下里亮着的时间比例（1 = 一直亮着只换形状）"}),
		P.num("grow", "劈下用时", "Strike Time", 0.0, 0.5, 0.12, {group = "motion", show_if = ["mode", "strike"], tip = "第一下从远处劈到落点的时间"}),
		P.num("end_glow", "端点光球", "End Glow", 0.0, 1.0, 0.6, {group = "detail"}),
		P.num("fork_dim", "分支亮度", "Branch Brightness", 0.0, 1.0, 0.7, {group = "detail"}),
	]


func prepare(p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var mode: String = p["mode"]
	var length: float = p["length"]
	var segments: int = p["segments"]
	var jag: float = p["jag"]
	var branches: int = p["branches"]
	var branch_len: float = p["branch_len"]
	var flashes: Array = []
	for f in int(p["flashes"]):
		var mains: Array = []
		var forks: Array = []
		if mode == "radial":
			var count := branches + 1
			var base := rng.randf() * TAU
			for i in count:
				var a := base + TAU * float(i) / float(count) + (rng.randf() - 0.5) * 0.6
				mains.append(_polyline(rng, Vector2.ZERO, Vector2(cos(a), sin(a)) * length * (0.75 + 0.25 * rng.randf()), segments, jag))
		else:
			# 局部坐标：x 轴沿「方向」。落雷从远端到原点，电弧从原点到远端
			var far := Vector2(length, 0.0)
			var main := _polyline(rng, far, Vector2.ZERO, segments, jag) if mode == "strike" else _polyline(rng, Vector2.ZERO, far, segments, jag)
			mains.append(main)
			for b in branches:
				var idx := int(main.size() * (0.2 + 0.6 * rng.randf()))
				var from := main[clampi(idx, 0, main.size() - 1)]
				var dir := (main[clampi(idx + 1, 0, main.size() - 1)] - main[clampi(idx - 1, 0, main.size() - 1)]).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2(-1.0, 0.0) if mode == "strike" else Vector2(1.0, 0.0)
				var turn := deg_to_rad(25.0 + 35.0 * rng.randf()) * (1.0 if rng.randf() < 0.5 else -1.0)
				var to := from + dir.rotated(turn) * length * branch_len * (0.5 + 0.5 * rng.randf())
				forks.append(_polyline(rng, from, to, maxi(int(segments * 0.5), 2), jag))
		flashes.append({"mains": mains, "forks": forks, "bright": 0.85 + 0.15 * rng.randf()})
	return {"flashes": flashes}


## 中点位移折线：每轮在每段中点加一个垂直偏移，偏移量逐轮减小
static func _polyline(rng: RandomNumberGenerator, from: Vector2, to: Vector2, segments: int, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array([from, to])
	var disp := from.distance_to(to) * jag * 0.5
	var levels := ceili(log(float(maxi(segments, 2))) / log(2.0))
	for lv in levels:
		var next := PackedVector2Array()
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var perp := (b - a).orthogonal().normalized()
			next.append(a)
			next.append((a + b) * 0.5 + perp * (rng.randf() * 2.0 - 1.0) * disp)
		next.append(pts[pts.size() - 1])
		pts = next
		disp *= 0.55
	return pts


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var flashes: Array = st["flashes"]
	var n := flashes.size()
	var mode: String = p["mode"]
	var fi := mini(int(u * n), n - 1)
	var ph := u * n - float(fi)
	if ph > float(p["on_ratio"]) + 0.0001:
		return 1.0
	var fl: Dictionary = flashes[fi]
	var core_r := maxf(float(p["width"]), 0.5)
	var glow_r := core_r + float(p["glow"])
	var bright: float = fl["bright"]
	# 落雷的第一下：从远端往落点长出来
	var reveal := 1.0
	var grow: float = p["grow"]
	if mode == "strike" and fi == 0 and grow > 0.0:
		reveal = clampf(u / grow, 0.0, 1.0)
	var ca := ctx.cos_a
	var sa := ctx.sin_a
	var ox := ctx.ox
	var oy := ctx.oy
	for main: PackedVector2Array in fl["mains"]:
		_draw_polyline(buf, main, reveal, core_r, glow_r, bright, ox, oy, ca, sa)
	var fork_v := bright * float(p["fork_dim"])
	if reveal >= 1.0:
		for fork: PackedVector2Array in fl["forks"]:
			_draw_polyline(buf, fork, 1.0, core_r * 0.7, glow_r * 0.75, fork_v, ox, oy, ca, sa)
	var end_glow: float = p["end_glow"]
	if end_glow > 0.0 and reveal >= 1.0:
		var r := glow_r * 2.2 * end_glow
		buf.disc(ox, oy, r, bright, bright * 0.6, 1.0)
		if mode == "arc":
			var m0: PackedVector2Array = fl["mains"][0]
			var far := m0[m0.size() - 1]
			buf.disc(ox + far.x * ca - far.y * sa, oy + far.x * sa + far.y * ca, r, bright, bright * 0.6, 1.0)
	return 1.0 - 0.85 * smoothstep(0.8, 1.0, u) if mode == "strike" else 1.0


func _draw_polyline(buf: FxBuffer, pts: PackedVector2Array, reveal: float, core_r: float, glow_r: float, val: float, ox: float, oy: float, ca: float, sa: float) -> void:
	var last := int(ceil((pts.size() - 1) * reveal))
	for i in last:
		var a := pts[i]
		var b := pts[i + 1]
		var ax := ox + a.x * ca - a.y * sa
		var ay := oy + a.x * sa + a.y * ca
		var bx := ox + b.x * ca - b.y * sa
		var by := oy + b.x * sa + b.y * ca
		if glow_r > core_r:
			buf.capsule(ax, ay, bx, by, glow_r, glow_r, val * 0.5, val * 0.5, 1.0)
		buf.capsule(ax, ay, bx, by, core_r, core_r, val, val, 1.0)
