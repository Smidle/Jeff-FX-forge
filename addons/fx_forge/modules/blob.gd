@tool
extends "fx_module.gd"
## 能量团：爆炸火球、烟团、毒雾。
## 若干团块从小胀大、彼此融合，边缘被噪声搅得参差翻滚；热度随时间下降（白热 → 暗红），
## 后半段被噪声「烧穿」成碎块消失。噪声采样位置绕圆周移动，「翻滚速度」用整数时可以无缝循环。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")
const FxNoise := preload("../core/fx_noise.gd")


func get_id() -> String:
	return "blob"


func get_display_name() -> String:
	return "能量团"


func get_display_name_en() -> String:
	return "Blob"


func get_description() -> String:
	return "爆炸火球、烟团、毒雾"


func get_param_defs() -> Array:
	return [
		P.integer("puffs", "团数", "Puffs", 1, 12, 5, {group = "shape", tip = "由几个团块融合而成"}),
		P.num("radius", "半径", "Radius", 2.0, 200.0, 16.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "主团块胀到最大时的半径"}),
		P.num("spread", "散开范围", "Spread", 0.0, 200.0, 9.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "其他团块离原点多远"}),
		P.num("start", "起始大小", "Start Size", 0.0, 1.0, 0.25, {group = "shape"}),
		P.num("squash", "压扁", "Squash", 0.3, 1.0, 1.0, {group = "shape", tip = "上下压扁（贴地的烟、毒雾）"}),
		P.num("noise", "翻滚强度", "Turbulence", 0.0, 1.0, 0.5, {group = "shape", tip = "边缘被噪声搅动的程度"}),
		P.num("noise_scale", "噪声颗粒", "Noise Scale", 0.3, 4.0, 1.2, {group = "shape", step = 0.05, tip = "越大颗粒越细碎"}),
		P.choice("easing", "膨胀曲线", "Easing", M.EASE_OPTIONS, "out_expo", {group = "motion"}),
		P.num("expand_time", "膨胀用时", "Expand Time", 0.05, 1.0, 0.35, {group = "motion", tip = "团块胀到最大所用的时间比例"}),
		P.num("rise", "上升距离", "Rise", -100.0, 200.0, 6.0, {group = "motion", unit = "px", scale = true, step = 0.5, tip = "整段动画里往上飘多远（烟雾大一些；负数往下沉）"}),
		P.num("boil", "翻滚速度", "Boil", 0.0, 4.0, 1.0, {group = "motion", unit = "圈", step = 0.25, tip = "噪声翻滚的快慢；循环特效要用整数圈才能首尾衔接"}),
		P.num("stagger", "先后出现", "Stagger", 0.0, 0.6, 0.15, {group = "motion", tip = "各团块出现的时间错开多少"}),
		P.num("heat", "初始热度", "Heat", 0.0, 1.0, 1.0, {group = "detail", tip = "一开始有多亮（1 = 白热）"}),
		P.num("cool", "冷却", "Cooling", 0.0, 1.0, 0.75, {group = "detail", tip = "随时间变暗的程度：火球从白热变成暗红"}),
		P.num("core", "核心亮度", "Core", 0.0, 1.0, 0.6, {group = "detail", tip = "团块中心比边缘亮多少"}),
		P.num("burn", "烧穿消散", "Burn Out", 0.0, 1.0, 0.7, {group = "detail", tip = "后半段被噪声烧出窟窿、碎成小块消失"}),
	]


func prepare(p: Dictionary, ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = p["puffs"]
	var spread: float = p["spread"]
	var squash: float = p["squash"]
	var stagger: float = p["stagger"]
	var cx := PackedFloat32Array()
	var cy := PackedFloat32Array()
	var rr := PackedFloat32Array()
	var delay := PackedFloat32Array()
	var rise := PackedFloat32Array()
	for k in n:
		if k == 0:
			cx.append(0.0)
			cy.append(0.0)
			rr.append(1.0)
			delay.append(0.0)
			rise.append(1.0)
			continue
		var a := rng.randf() * TAU
		var d := spread * sqrt(rng.randf())
		cx.append(cos(a) * d)
		cy.append(sin(a) * d * squash)
		rr.append(0.6 + 0.45 * rng.randf())
		delay.append(stagger * rng.randf())
		rise.append(0.7 + 0.6 * rng.randf())
	return {"cx": cx, "cy": cy, "rr": rr, "delay": delay, "rise": rise, "noise": FxNoise.table(ctx.seed, 16, 3)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var radius: float = p["radius"]
	var start: float = p["start"]
	var squash: float = p["squash"]
	var namp := float(p["noise"]) * 0.9
	var ns: float = p["noise_scale"]
	var ease_id: String = p["easing"]
	var expand_time: float = p["expand_time"]
	var rise: float = p["rise"]
	var boil: float = p["boil"]
	var heat: float = p["heat"]
	var cool: float = p["cool"]
	var core: float = p["core"]
	var burn: float = p["burn"]
	var cx: PackedFloat32Array = st["cx"]
	var cy: PackedFloat32Array = st["cy"]
	var rr: PackedFloat32Array = st["rr"]
	var delay: PackedFloat32Array = st["delay"]
	var rise_k: PackedFloat32Array = st["rise"]
	var noise: PackedFloat32Array = st["noise"]
	var mask := FxNoise.MASK
	var shift := FxNoise.SHIFT

	var heat_now := heat * (1.0 - cool * smoothstep(0.05, 0.95, u))
	# 烧穿：后半段用另一处噪声在整团上打窟窿（不只是从边缘收缩），越到最后窟窿越多
	var erode := burn * smoothstep(0.4, 1.0, u) * 0.8
	var ang := TAU * u * boil
	var nox := cos(ang) * 22.0 + 7.0
	var noy := sin(ang) * 22.0 + 3.0
	var hox := cos(ang + 2.0) * 18.0 + 61.0
	var hoy := sin(ang + 2.0) * 18.0 + 37.0
	var hs := ns * 1.7
	var rise_e := M.apply_ease("out_quad", u)

	# 各团块此刻的位置和半径
	var pcx := PackedFloat32Array()
	var pcy := PackedFloat32Array()
	var pinv := PackedFloat32Array()
	var xa := buf.w
	var ya := buf.h
	var xb := -1
	var yb := -1
	var margin := 1.0 + namp
	for k in cx.size():
		var span := maxf(1.0 - delay[k], 0.05)
		var uk := (u - delay[k]) / span
		if uk <= 0.0:
			continue
		var e := M.apply_ease(ease_id, uk / expand_time)
		var grow := lerpf(start, 1.0, e) * (1.0 + 0.15 * maxf(uk - expand_time, 0.0) / maxf(1.0 - expand_time, 0.05))
		var r := radius * rr[k] * grow
		if r < 0.5:
			continue
		var px := ctx.ox + cx[k]
		var py := ctx.oy + cy[k] - rise * rise_k[k] * rise_e
		pcx.append(px)
		pcy.append(py)
		pinv.append(1.0 / r)
		xa = mini(xa, floori(px - r * margin) - 1)
		xb = maxi(xb, ceili(px + r * margin) + 1)
		ya = mini(ya, floori(py - r * squash * margin) - 1)
		yb = maxi(yb, ceili(py + r * squash * margin) + 1)
	if pcx.is_empty():
		return 1.0
	xa = maxi(xa, 0)
	ya = maxi(ya, 0)
	xb = mini(xb, buf.w - 1)
	yb = mini(yb, buf.h - 1)
	if xa > xb or ya > yb:
		return 1.0

	var inv_sq := 1.0 / squash
	var count := pcx.size()
	var core_k := 0.55 + core * 0.6
	var w := buf.w
	var bv := buf.v
	var ba := buf.a
	buf.release()
	var drew := false
	for y in range(ya, yb + 1):
		var fy := float(y) + 0.5
		var row := y * w
		var ny := (floori(fy * ns + noy) & mask) << shift
		var hy := (floori(fy * hs + hoy) & mask) << shift
		for x in range(xa, xb + 1):
			var fx := float(x) + 0.5
			var f := -1.0
			for k in count:
				var dx := fx - pcx[k]
				var dy := (fy - pcy[k]) * inv_sq
				var fk := 1.0 - sqrt(dx * dx + dy * dy) * pinv[k]
				if fk > f:
					f = fk
			if f < -namp:
				continue
			var nv := noise[ny | (floori(fx * ns + nox) & mask)] - 0.5
			if f + nv * namp * 2.0 <= 0.02:
				continue
			if erode > 0.0 and noise[hy | (floori(fx * hs + hox) & mask)] < erode:
				continue
			# 内部明暗：几何中心亮、边缘暗，再叠加噪声起伏，色阶一块一块地分布
			var b := f * core_k + nv * 0.9 + 0.15
			if b > 1.0:
				b = 1.0
			elif b < 0.0:
				b = 0.0
			var val := heat_now * (0.28 + 0.72 * b)
			var i := row + x
			if val > bv[i]:
				bv[i] = val
			if 1.0 > ba[i]:
				ba[i] = 1.0
			drew = true
	buf.restore(bv, ba)
	if drew:
		buf.touch(xa, ya, xb, yb)
	return 1.0
