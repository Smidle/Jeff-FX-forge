@tool
extends "fx_module.gd"
## 射线爆发：打击火花、星形闪光。
## 中心先闪一下，尖刺状的射线向外射出，根部随后脱离中心，射线变细、溶解消失。
## 扩散角小于 360° 时朝「方向」喷出（格挡、定向打击）。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")
const FxParticles := preload("../core/fx_particles.gd")

const FLASH_OPTIONS := [["star", "四角星"], ["disc", "圆形"], ["diamond", "菱形"], ["none", "无"]]


func get_id() -> String:
	return "burst"


func get_display_name() -> String:
	return "射线爆发"


func get_display_name_en() -> String:
	return "Burst"


func get_description() -> String:
	return "打击火花、星形闪光"


func is_directional() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.integer("rays", "射线数", "Rays", 2, 32, 8, {group = "shape", tip = "向外射出的尖刺数量"}),
		P.num("length", "射线长度", "Ray Length", 2.0, 200.0, 22.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("width", "射线宽度", "Ray Width", 1.0, 40.0, 4.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "射线根部的粗细"}),
		P.num("spread", "扩散角", "Spread", 10.0, 360.0, 360.0, {group = "shape", unit = "°", step = 1.0, tip = "360 = 四面八方；小于 360 时朝「方向」喷出"}),
		P.num("length_random", "长短不一", "Length Random", 0.0, 1.0, 0.45, {group = "shape"}),
		P.num("angle_random", "角度随机", "Angle Random", 0.0, 1.0, 0.35, {group = "shape"}),
		P.num("alternate", "长短交替", "Alternate", 0.0, 1.0, 0.4, {group = "shape", tip = "相邻射线一长一短的程度"}),
		P.num("inner", "中心留空", "Inner Gap", 0.0, 1.0, 0.15, {group = "shape", tip = "射线从离中心多远的地方开始"}),
		P.choice("easing", "速度曲线", "Easing", M.EASE_OPTIONS, "out_expo", {group = "motion"}),
		P.num("ray_time", "射线时长", "Ray Time", 0.2, 1.0, 0.85, {group = "motion", tip = "射线从射出到消失占图层时长的比例"}),
		P.num("detach", "脱离中心", "Detach", 0.0, 1.0, 0.75, {group = "motion", tip = "射线根部离开中心的程度：越大越像飞散的火花"}),
		P.choice("flash", "中心闪光", "Flash", FLASH_OPTIONS, "star", {group = "detail"}),
		P.num("flash_size", "闪光大小", "Flash Size", 0.0, 80.0, 9.0, {group = "detail", unit = "px", scale = true, step = 0.5, hide_if = ["flash", "none"]}),
		P.num("flash_time", "闪光时长", "Flash Time", 0.05, 1.0, 0.35, {group = "detail", hide_if = ["flash", "none"]}),
	]


func prepare(p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = p["rays"]
	var spread := deg_to_rad(float(p["spread"]))
	var full := spread >= TAU - 0.01
	var angles := PackedFloat32Array()
	var lens := PackedFloat32Array()
	var step := (TAU if full else spread) / float(n)
	for i in n:
		var base := TAU * float(i) / float(n) if full else -spread * 0.5 + step * (float(i) + 0.5)
		angles.append(base + (rng.randf() - 0.5) * float(p["angle_random"]) * step)
		var l := 1.0 - float(p["length_random"]) * rng.randf()
		if i % 2 == 1:
			l *= 1.0 - float(p["alternate"]) * 0.55
		lens.append(l)
	return {"angles": angles, "lens": lens}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var angles: PackedFloat32Array = st["angles"]
	var lens: PackedFloat32Array = st["lens"]
	var length: float = p["length"]
	var width: float = p["width"]
	var inner: float = p["inner"]
	var detach: float = p["detach"]
	var ray_time: float = p["ray_time"]
	var ox := ctx.ox
	var oy := ctx.oy
	var t := u / ray_time
	if t < 1.0:
		var e := M.apply_ease(p["easing"], t)
		var cool := 1.0 - 0.35 * t
		for i in angles.size():
			var ang := ctx.angle + angles[i]
			var dx := cos(ang)
			var dy := sin(ang)
			var lf := lens[i]
			var l := length * lf
			var r0 := inner * l * 0.6
			var head := r0 + (l - r0) * e
			var tail := r0 + (head - r0) * detach * smoothstep(0.0, 1.0, t)
			var wr := maxf(width * sqrt(lf) * (1.0 - 0.75 * t) * 0.5, 0.5)
			if head - tail < 0.5:
				continue
			buf.capsule(ox + dx * tail, oy + dy * tail, ox + dx * head, oy + dy * head, wr, 0.45, cool, 0.78 * cool, 1.0)
	var flash: String = p["flash"]
	var flash_time: float = p["flash_time"]
	if flash != "none" and u < flash_time:
		var ft := u / flash_time
		var r: float = float(p["flash_size"]) * (1.0 - ft * ft)
		if r >= 0.5:
			match flash:
				"star":
					FxParticles.star(buf, ox, oy, r, ctx.angle + PI * 0.25, 1.0, 1.0)
				"disc":
					buf.disc(ox, oy, r, 1.0, 0.85, 1.0)
				"diamond":
					buf.diamond(ox, oy, r, 1.0, 0.85, 1.0)
	return 1.0 - 0.85 * smoothstep(0.6, 1.0, u)
