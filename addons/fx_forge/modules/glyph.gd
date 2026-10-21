@tool
extends "fx_module.gd"
## 法阵：魔法阵、召唤阵、护盾符文。
## 同心圆环 + 星形多边形（{顶点数 / 跳点}，例如六芒星 {6/2}）+ 刻度 + 顶点符文，内外圈可以反向旋转；
## 可以压扁成地面上的椭圆，也可以按「外环 → 内环 → 星形 → 刻度」的顺序逐笔画出来。
## 线条用胶囊线画，粗细是真实像素宽度，压扁后也不会断线。

const P := preload("../core/fx_params.gd")


func get_id() -> String:
	return "glyph"


func get_display_name() -> String:
	return "法阵"


func get_display_name_en() -> String:
	return "Glyph"


func get_description() -> String:
	return "魔法阵、召唤阵、护盾符文"


func get_param_defs() -> Array:
	return [
		P.num("radius", "外环半径", "Radius", 4.0, 240.0, 30.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.integer("rings", "环数", "Rings", 0, 4, 2, {group = "shape"}),
		P.num("ring_gap", "环间距", "Ring Gap", 1.0, 60.0, 5.0, {group = "shape", unit = "px", scale = true, step = 0.5, hide_if = ["rings", 0]}),
		P.integer("star_points", "星形顶点", "Star Points", 0, 12, 6, {group = "shape", tip = "0 = 不画星形"}),
		P.integer("star_step", "星形跳点", "Star Step", 1, 5, 2, {group = "shape", hide_if = ["star_points", 0], tip = "连到隔几个的顶点：6 顶点跳 2 = 六芒星，跳 1 = 六边形"}),
		P.num("star_scale", "星形大小", "Star Size", 0.2, 1.0, 0.92, {group = "shape", hide_if = ["star_points", 0], tip = "相对最内圈的大小"}),
		P.integer("ticks", "刻度数", "Ticks", 0, 64, 16, {group = "shape"}),
		P.num("tick_len", "刻度长度", "Tick Length", 1.0, 30.0, 3.0, {group = "shape", unit = "px", scale = true, step = 0.5, hide_if = ["ticks", 0]}),
		P.num("line", "线宽", "Line Width", 0.5, 6.0, 1.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("squash", "地面透视", "Squash", 0.15, 1.0, 1.0, {group = "shape", tip = "压扁成贴在地上的椭圆（俯视、等距视角常用 0.35~0.5）"}),
		P.num("spin", "旋转圈数", "Spin", -4.0, 4.0, 0.5, {group = "motion", step = 0.05, tip = "一段动画里转几圈；循环特效要用整数圈"}),
		P.boolean("counter", "内圈反转", "Counter Spin", true, {group = "motion", tip = "星形和外环反方向转"}),
		P.num("draw_time", "逐笔画出", "Draw Time", 0.0, 0.9, 0.0, {group = "motion", tip = "0 = 一开始就完整；大于 0 时用这么长的时间把法阵一笔一笔画出来"}),
		P.num("fade_out", "结尾淡出", "Fade Out", 0.0, 0.6, 0.0, {group = "motion", tip = "最后多长时间里溶解消失（循环特效保持 0）"}),
		P.num("pulse", "呼吸亮度", "Pulse", 0.0, 1.0, 0.2, {group = "detail"}),
		P.num("runes", "顶点符文", "Runes", 0.0, 1.0, 0.5, {group = "detail", hide_if = ["star_points", 0], tip = "星形顶点上的菱形符文大小"}),
	]


func render(buf: FxBuffer, p: Dictionary, _st: Dictionary, u: float, ctx: FxContext) -> float:
	var radius: float = p["radius"]
	var rings: int = p["rings"]
	var gap: float = p["ring_gap"]
	var n_star: int = p["star_points"]
	var step: int = p["star_step"]
	var star_scale: float = p["star_scale"]
	var ticks: int = p["ticks"]
	var tick_len: float = p["tick_len"]
	var lr := maxf(float(p["line"]) * 0.5, 0.5)
	var squash: float = p["squash"]
	var draw_time: float = p["draw_time"]
	var fade_out: float = p["fade_out"]
	var pulse := 1.0 - float(p["pulse"]) * 0.25 * (0.5 + 0.5 * sin(TAU * fposmod(2.0 * u, 1.0)))
	var rot := TAU * fposmod(float(p["spin"]) * u, 1.0) + ctx.angle
	var rot_in := -rot if p["counter"] else rot
	var prog := clampf(u / draw_time, 0.0, 1.0) if draw_time > 0.0 else 1.0
	var ox := ctx.ox
	var oy := ctx.oy

	# 圆环
	for k in rings:
		var e := _phase(prog, 0.0 + 0.12 * k, 0.45 + 0.12 * k)
		if e <= 0.0:
			continue
		var r := radius - gap * k
		if r <= 0.5:
			continue
		var segs := clampi(int(r * 1.6), 16, 160)
		var count := maxi(int(ceil(segs * e)), 1)
		var pts := PackedVector2Array()
		var a0 := rot if k % 2 == 0 else rot_in
		for i in count + 1:
			var a := a0 + TAU * minf(float(i) / segs, e)
			pts.append(_to_screen(cos(a) * r, sin(a) * r, ox, oy, squash))
		# 外环最亮，内环暗一档，层次更清楚
		buf.polyline(pts, lr, (0.95 if k == 0 else 0.68) * pulse, 1.0, false)

	# 星形多边形
	var inner_r := radius - gap * maxi(rings - 1, 0)
	var star_r := inner_r * star_scale if rings > 0 else radius * star_scale
	if n_star >= 2:
		var e2 := _phase(prog, 0.35, 0.85)
		if e2 > 0.0:
			var verts := PackedVector2Array()
			for i in n_star:
				var a := rot_in + TAU * float(i) / n_star - PI * 0.5
				verts.append(Vector2(cos(a) * star_r, sin(a) * star_r))
			var edges := n_star
			var drawn := e2 * edges
			for i in edges:
				if float(i) >= drawn:
					break
				var a := verts[i]
				var b := verts[(i + step) % n_star]
				var part := minf(drawn - float(i), 1.0)
				var bb := a + (b - a) * part
				var sa := _to_screen(a.x, a.y, ox, oy, squash)
				var sb := _to_screen(bb.x, bb.y, ox, oy, squash)
				buf.capsule(sa.x, sa.y, sb.x, sb.y, lr, lr, 0.8 * pulse, 0.8 * pulse, 1.0)
			# 顶点符文（星形画完后才出现）
			var rune: float = p["runes"]
			if rune > 0.0 and e2 >= 1.0:
				for v in verts:
					var s := _to_screen(v.x, v.y, ox, oy, squash)
					buf.diamond(s.x, s.y, maxf(rune * 4.0 + lr, 1.0), pulse, 0.75 * pulse, 1.0)

	# 刻度（在最外环内侧）
	if ticks > 0:
		var e3 := _phase(prog, 0.6, 1.0)
		var shown := int(ceil(ticks * e3))
		for i in shown:
			var a := rot + TAU * float(i) / ticks
			var c := cos(a)
			var s2 := sin(a)
			var p0 := _to_screen(c * radius, s2 * radius, ox, oy, squash)
			var p1 := _to_screen(c * (radius - tick_len), s2 * (radius - tick_len), ox, oy, squash)
			buf.capsule(p0.x, p0.y, p1.x, p1.y, lr, lr, 0.6 * pulse, 0.6 * pulse, 1.0)

	if fade_out > 0.0:
		return 1.0 - smoothstep(1.0 - fade_out, 1.0, u)
	return 1.0


## 某一笔在整体进度 prog 下画到了几成
static func _phase(prog: float, start: float, end: float) -> float:
	return clampf((prog - start) / maxf(end - start, 0.001), 0.0, 1.0)


## 法阵平面坐标 → 屏幕：上下压扁（贴地）
static func _to_screen(x: float, y: float, ox: float, oy: float, squash: float) -> Vector2:
	return Vector2(ox + x, oy + y * squash)
