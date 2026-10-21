@tool
extends "fx_module.gd"
## 环：冲击波、能量环、光环、护盾泡。
## 可以多重环先后扩散、压扁成地面上的椭圆、切成旋转的分段虚线；开头可以带一下实心的冲击闪光。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")

const MODE_OPTIONS := [["expand", "向外扩散"], ["contract", "向内收缩"], ["pulse", "呼吸脉动"], ["static", "静止（护盾）"]]


func get_id() -> String:
	return "ring"


func get_display_name() -> String:
	return "环"


func get_display_name_en() -> String:
	return "Ring"


func get_description() -> String:
	return "冲击波、能量环、光环、护盾"


func get_param_defs() -> Array:
	return [
		P.num("radius", "最大半径", "Radius", 2.0, 240.0, 28.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("width", "环宽", "Width", 1.0, 60.0, 5.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("thin", "越扩越细", "Thinning", 0.0, 1.0, 0.75, {group = "shape", tip = "扩散到最大时环宽剩多少（1 = 细成一条线）"}),
		P.num("start", "起始大小", "Start Size", 0.0, 1.0, 0.15, {group = "shape", tip = "一开始的半径是最大半径的几成"}),
		P.num("squash", "地面透视", "Squash", 0.15, 1.0, 1.0, {group = "shape", tip = "上下压扁成椭圆，像贴在地面上的冲击波（俯视、等距视角常用 0.3~0.5）"}),
		P.integer("segments", "分段数", "Segments", 0, 24, 0, {group = "shape", tip = "0 = 完整的环；大于 0 时切成虚线段"}),
		P.num("gap", "分段间隙", "Gap", 0.05, 0.9, 0.35, {group = "shape", hide_if = ["segments", 0]}),
		P.integer("rings", "环数", "Rings", 1, 4, 1, {group = "shape", tip = "几个环先后扩散"}),
		P.num("ring_delay", "环间隔", "Ring Delay", 0.0, 0.5, 0.15, {group = "shape", hide_if = ["rings", 1]}),
		P.choice("mode", "模式", "Mode", MODE_OPTIONS, "expand", {group = "motion", tip = "呼吸脉动和静止适合循环特效（光环、护盾）"}),
		P.choice("easing", "速度曲线", "Easing", M.EASE_OPTIONS, "out_cubic", {group = "motion"}),
		P.num("spin", "旋转", "Spin", -4.0, 4.0, 0.0, {group = "motion", unit = "圈", step = 0.05, tip = "分段在一段动画里转几圈（循环特效用整数圈才能首尾衔接）"}),
		P.num("fill", "冲击闪光", "Impact Flash", 0.0, 1.0, 0.0, {group = "detail", tip = "开头环内部先亮一下实心的光再向中心收缩；数值越大持续越久"}),
		P.num("wobble", "边缘起伏", "Wobble", 0.0, 1.0, 0.0, {group = "detail"}),
		P.num("rim", "外缘亮度", "Rim Light", 0.0, 1.0, 0.6, {group = "detail", tip = "外缘比内缘亮多少"}),
	]


func prepare(_p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	return {"noise": M.periodic_noise(256, 3, rng)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var radius: float = p["radius"]
	var width: float = p["width"]
	var thin: float = p["thin"]
	var start: float = p["start"]
	var squash: float = p["squash"]
	var segments: int = p["segments"]
	var gap: float = p["gap"]
	var rings: int = p["rings"]
	var delay: float = p["ring_delay"] if rings > 1 else 0.0
	var mode: String = p["mode"]
	var ease_id: String = p["easing"]
	var spin_turns: float = p["spin"]
	var fill: float = p["fill"]
	var wobble: float = p["wobble"]
	var rim_pow := 1.0 - float(p["rim"]) * 0.7
	var noise: PackedFloat32Array = st["noise"]
	var nn := noise.size()
	var ox := ctx.ox
	var oy := ctx.oy
	var inv_sq := 1.0 / maxf(squash, 0.05)
	var span := maxf(1.0 - delay * float(rings - 1), 0.05)
	var need_angle := segments > 0 or wobble > 0.0
	var phase := ctx.angle + spin_turns * TAU * u
	var bv := buf.v
	var ba := buf.a
	buf.release()
	var drew := false
	var bx0 := buf.w
	var by0 := buf.h
	var bx1 := -1
	var by1 := -1
	var first_r := -1.0
	var first_w := 0.0
	for k in rings:
		var uk := (u - float(k) * delay) / span
		var r := radius
		var wd := width
		var alpha := 1.0
		match mode:
			"expand", "contract":
				if uk <= 0.0 or uk >= 1.0:
					continue
				var e := M.apply_ease(ease_id, uk)
				r = radius * (lerpf(start, 1.0, e) if mode == "expand" else lerpf(1.0, start, e))
				wd = width * lerpf(1.0, 1.0 - thin, e if mode == "expand" else 1.0 - e)
				alpha = 1.0 - smoothstep(0.55, 1.0, uk)
			"pulse":
				var s := 0.5 - 0.5 * cos(TAU * (u + float(k) / float(rings)))
				r = radius * lerpf(maxf(start, 0.6), 1.0, s)
				wd = width * lerpf(1.0, 1.0 - thin * 0.6, s)
			_:
				r = radius
		wd = maxf(wd, 1.0)
		if k == 0:
			first_r = r
			first_w = wd
		var half_w := wd * 0.5
		var amp := wobble * wd * 1.5
		var reach := r + half_w + amp + 1.0
		var xa := maxi(floori(ox - reach), 0)
		var xb := mini(ceili(ox + reach), buf.w - 1)
		var ya := maxi(floori(oy - reach * squash), 0)
		var yb := mini(ceili(oy + reach * squash), buf.h - 1)
		if xa > xb or ya > yb:
			continue
		var inner2 := maxf(r - half_w - amp - 1.0, 0.0)
		inner2 *= inner2
		var outer2 := reach * reach
		var vmul := 1.0 if k == 0 else 0.85
		for y in range(ya, yb + 1):
			var dy := (float(y) + 0.5 - oy) * inv_sq
			var row := y * buf.w
			for x in range(xa, xb + 1):
				var dx := float(x) + 0.5 - ox
				var d2 := dx * dx + dy * dy
				if d2 > outer2 or d2 < inner2:
					continue
				var d := sqrt(d2)
				var rr := r
				if need_angle:
					var th := atan2(dy, dx) - phase
					if wobble > 0.0:
						rr += (noise[int(fposmod(th, TAU) / TAU * nn) % nn] - 0.5) * amp
					if segments > 0 and fposmod(th / TAU * segments, 1.0) > 1.0 - gap:
						continue
				var q := (d - (rr - half_w)) / wd
				if q < 0.0 or q > 1.0:
					continue
				var val := (0.45 + 0.55 * pow(q, rim_pow)) * vmul
				var i := row + x
				if val > bv[i]:
					bv[i] = val
				if alpha > ba[i]:
					ba[i] = alpha
				drew = true
		bx0 = mini(bx0, xa)
		by0 = mini(by0, ya)
		bx1 = maxi(bx1, xb)
		by1 = maxi(by1, yb)
	buf.restore(bv, ba)
	if drew:
		buf.touch(bx0, by0, bx1, by1)
	# 冲击闪光：开头环内部是实心的光，随后向中心收缩消失（比点阵溶解干净）
	var fill_time := 0.12 + 0.18 * fill
	if fill > 0.0 and first_r > 0.0 and u < fill_time:
		var fu := u / fill_time
		var fr := maxf(first_r - first_w * 0.5, 0.0) * (1.0 - fu * fu)
		if fr >= 0.5:
			_fill_ellipse(buf, ox, oy, fr, squash, 1.0)
	return 1.0


func _fill_ellipse(buf: FxBuffer, ox: float, oy: float, r: float, squash: float, alpha: float) -> void:
	var xa := maxi(floori(ox - r), 0)
	var xb := mini(ceili(ox + r), buf.w - 1)
	var ya := maxi(floori(oy - r * squash), 0)
	var yb := mini(ceili(oy + r * squash), buf.h - 1)
	if xa > xb or ya > yb:
		return
	var inv_sq := 1.0 / maxf(squash, 0.05)
	var r2 := r * r
	var bv := buf.v
	var ba := buf.a
	buf.release()
	for y in range(ya, yb + 1):
		var dy := (float(y) + 0.5 - oy) * inv_sq
		var row := y * buf.w
		for x in range(xa, xb + 1):
			var dx := float(x) + 0.5 - ox
			var d2 := dx * dx + dy * dy
			if d2 > r2:
				continue
			var val := 0.75 + 0.25 * (1.0 - d2 / r2)
			var i := row + x
			if val > bv[i]:
				bv[i] = val
			if alpha > ba[i]:
				ba[i] = alpha
	buf.restore(bv, ba)
	buf.touch(xa, ya, xb, yb)
