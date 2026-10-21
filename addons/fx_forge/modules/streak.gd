@tool
extends "fx_module.gd"
## 冲刺线：突刺、冲刺、速度线。
## 若干条两头尖、中间偏前最粗的线沿「方向」向前冲，先伸长再收缩消失；第一条是主线（更粗更长）。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")


func get_id() -> String:
	return "streak"


func get_display_name() -> String:
	return "冲刺线"


func get_display_name_en() -> String:
	return "Streak"


func get_description() -> String:
	return "突刺、冲刺、速度线"


func is_directional() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.integer("count", "条数", "Count", 1, 16, 3, {group = "shape"}),
		P.num("length", "长度", "Length", 2.0, 300.0, 30.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("width", "宽度", "Width", 1.0, 40.0, 3.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("spread", "散布宽度", "Spread", 0.0, 120.0, 10.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "几条线在两侧铺开的范围"}),
		P.num("length_random", "长短不一", "Length Random", 0.0, 1.0, 0.4, {group = "shape"}),
		P.num("main_boost", "主线加粗", "Main Boost", 0.0, 1.0, 0.6, {group = "shape", tip = "第一条线比其他线粗多少、长多少"}),
		P.num("taper", "尖锐度", "Taper", 0.0, 1.0, 0.75, {group = "shape"}),
		P.num("travel", "前冲距离", "Travel", 0.0, 200.0, 16.0, {group = "motion", unit = "px", scale = true, step = 0.5}),
		P.num("stagger", "先后错开", "Stagger", 0.0, 0.8, 0.3, {group = "motion", tip = "各条线出现的时间错开多少"}),
		P.choice("easing", "速度曲线", "Easing", M.EASE_OPTIONS, "out_cubic", {group = "motion"}),
		P.num("head", "锋芒", "Glint", 0.0, 1.0, 0.5, {group = "detail", tip = "主线头部的菱形亮点"}),
	]


func prepare(p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = p["count"]
	var lateral := PackedFloat32Array()
	var lens := PackedFloat32Array()
	var delays := PackedFloat32Array()
	var stagger: float = p["stagger"]
	for i in n:
		if i == 0:
			lateral.append(0.0)
			lens.append(1.0)
			delays.append(0.0)
		else:
			# 其他线在两侧交替铺开
			var side := 1.0 if i % 2 == 1 else -1.0
			lateral.append(side * (0.35 + 0.65 * rng.randf()) * float(p["spread"]) * 0.5)
			lens.append((1.0 - float(p["length_random"]) * rng.randf()) * (1.0 - float(p["main_boost"]) * 0.4))
			delays.append(stagger * rng.randf())
	return {"lateral": lateral, "lens": lens, "delays": delays}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var lateral: PackedFloat32Array = st["lateral"]
	var lens: PackedFloat32Array = st["lens"]
	var delays: PackedFloat32Array = st["delays"]
	var length: float = p["length"]
	var width: float = p["width"]
	var taper: float = p["taper"]
	var travel: float = p["travel"]
	var boost: float = p["main_boost"]
	var head_glint: float = p["head"]
	var stagger: float = p["stagger"]
	var ca := ctx.cos_a
	var sa := ctx.sin_a
	var ox := ctx.ox
	var oy := ctx.oy
	for i in lateral.size():
		var uk := (u - delays[i]) / maxf(1.0 - stagger, 0.2)
		if uk <= 0.0 or uk >= 1.0:
			continue
		var grow := pow(sin(PI * uk), 0.6)
		var l := length * lens[i] * grow
		var center := travel * (M.apply_ease(p["easing"], uk) - 0.5)
		var head := center + l * 0.5
		var tail := center - l * 0.5
		var mid := tail + (head - tail) * 0.7
		var main := i == 0
		var wr := maxf(width * (1.0 + boost * 0.6 if main else 0.6) * (0.55 + 0.45 * grow) * 0.5, 0.5)
		var ly := lateral[i]
		var tx := ox + tail * ca - ly * sa
		var ty := oy + tail * sa + ly * ca
		var mx := ox + mid * ca - ly * sa
		var my := oy + mid * sa + ly * ca
		var hx := ox + head * ca - ly * sa
		var hy := oy + head * sa + ly * ca
		var v_main := 1.0 if main else 0.8
		buf.capsule(tx, ty, mx, my, 0.4, wr, 0.45 * v_main, 0.9 * v_main, 1.0)
		buf.capsule(mx, my, hx, hy, wr, lerpf(wr, 0.45, taper), 0.9 * v_main, v_main, 1.0)
		if main and head_glint > 0.0:
			buf.diamond(hx, hy, wr * 1.8 * head_glint * grow, 1.0, 0.9, 1.0)
	return 1.0 - 0.85 * smoothstep(0.7, 1.0, u)
