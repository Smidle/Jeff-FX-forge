@tool
extends "fx_module.gd"
## 火焰：篝火、火把、蓝焰（适合循环）。
## 火焰横向分成几条火舌（中间高、两侧低，各自的高度随时间起伏），
## 再减去向上滚动的噪声把边缘和顶部撕碎。
## 循环：噪声两份相差一个周期的滚动按时间交叉混合（再做方差补偿），火舌高度按整数圈起伏，
## u = 0 与 u = 1 完全相同，所以最后一帧能无缝接回第一帧。
## 原点 = 火焰底部中心；火焰总是向上（用「倾斜」模拟风吹）。

const P := preload("../core/fx_params.gd")
const FxNoise := preload("../core/fx_noise.gd")

const BASE_OPTIONS := [["flat", "平底（篝火、火墙）"], ["point", "尖底（火苗、火把）"], ["round", "圆团（火球、鬼火）"]]
const _MAX_TONGUES := 8


func get_id() -> String:
	return "flame"


func get_display_name() -> String:
	return "火焰"


func get_display_name_en() -> String:
	return "Flame"


func get_description() -> String:
	return "篝火、火把、蓝焰（适合循环）"


func get_param_defs() -> Array:
	return [
		P.num("width", "宽度", "Width", 2.0, 200.0, 18.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("height", "高度", "Height", 4.0, 300.0, 30.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.choice("base", "底部形状", "Base", BASE_OPTIONS, "flat", {group = "shape"}),
		P.integer("tongues", "火舌数", "Tongues", 1, _MAX_TONGUES, 3, {group = "shape", tip = "横向分成几条火舌"}),
		P.num("tongue_depth", "火舌落差", "Tongue Depth", 0.0, 0.8, 0.4, {group = "shape", tip = "火舌之间凹下去多深"}),
		P.num("taper", "收尖", "Taper", 0.0, 1.0, 0.45, {group = "shape", tip = "往上收窄得多快"}),
		P.num("lean", "倾斜", "Lean", -1.0, 1.0, 0.0, {group = "shape", tip = "被风吹歪：负数往左，正数往右"}),
		P.num("speed", "上升速度", "Speed", 0.2, 5.0, 1.5, {group = "motion", step = 0.1, tip = "一个循环里火舌往上窜过几倍火焰高度"}),
		P.num("sway", "摇曳", "Sway", 0.0, 1.0, 0.3, {group = "motion"}),
		P.num("turbulence", "湍流", "Turbulence", 0.0, 1.0, 0.55, {group = "motion", tip = "边缘和顶部被撕扯得多碎"}),
		P.num("noise_scale", "噪声颗粒", "Noise Scale", 0.3, 4.0, 1.4, {group = "motion", step = 0.05, tip = "越大火焰越细碎"}),
		P.num("core", "内焰亮度", "Core", 0.0, 1.0, 0.6, {group = "detail"}),
		P.num("flicker", "闪烁", "Flicker", 0.0, 1.0, 0.3, {group = "detail", tip = "整体忽明忽暗"}),
	]


func prepare(_p: Dictionary, ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var phases := PackedFloat32Array()
	for k in _MAX_TONGUES + 1:
		phases.append(rng.randf())
	return {
		"n1": FxNoise.table(ctx.seed, 16, 3),
		"n2": FxNoise.table(ctx.seed + 7919, 8, 2),
		"phases": phases,
		"flick_phase": rng.randf(),
	}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var hw0 := float(p["width"]) * 0.5
	var height: float = p["height"]
	var base: String = p["base"]
	var tongues: int = p["tongues"]
	var depth: float = p["tongue_depth"]
	var taper: float = p["taper"]
	var lean: float = p["lean"]
	var speed: float = p["speed"]
	var sway: float = p["sway"]
	var turb: float = p["turbulence"]
	var ns: float = p["noise_scale"]
	var core: float = p["core"]
	var flicker: float = p["flicker"]
	var n1: PackedFloat32Array = st["n1"]
	var n2: PackedFloat32Array = st["n2"]
	var phases: PackedFloat32Array = st["phases"]
	var mask := FxNoise.MASK
	var shift := FxNoise.SHIFT

	# 每条火舌此刻的高度起伏（整数圈，循环无缝）
	var amps := PackedFloat32Array()
	for k in tongues:
		amps.append(0.6 + 0.4 * sin(TAU * (u * float(1 + k % 2) + phases[k])))
	var flick := 1.0 - flicker * 0.3 * (0.5 + 0.5 * sin(TAU * (3.0 * u + float(st["flick_phase"]))))

	# 噪声：纵向拉长成竖条；交叉淡化循环
	var nsy := ns * 0.6
	var scroll := speed * height * nsy
	var sa := u * scroll
	var sb := (u - 1.0) * scroll
	var wa := 1.0 - u
	var wb := u
	var norm := 1.0 / sqrt(wa * wa + wb * wb)

	var ox := ctx.ox
	var oy := ctx.oy
	var reach_x := hw0 * (1.3 + sway * 0.5) + absf(lean) * height * 0.5 + 2.0
	var xa := maxi(floori(ox - reach_x), 0)
	var xb := mini(ceili(ox + reach_x), buf.w - 1)
	var ya := maxi(floori(oy - height * 1.1), 0)
	var yb := mini(ceili(oy + 2.0), buf.h - 1)
	if xa > xb or ya > yb:
		return 1.0
	var inv_hw0 := 1.0 / hw0
	var w := buf.w
	var bv := buf.v
	var ba := buf.a
	buf.release()
	var drew := false
	for y in range(ya, yb + 1):
		var ly := oy - (float(y) + 0.5)
		var v := ly / height
		if v < -0.08 or v > 1.1:
			continue
		var center := ox + sway * hw0 * 0.5 * clampf(v, 0.0, 1.0) * sin(TAU * (u + v * 0.7)) + lean * ly * 0.5
		var row := y * w
		var ny1a := (floori(-ly * nsy + sa) & mask) << shift
		var ny1b := (floori(-ly * nsy + sb) & mask) << shift
		var ny2a := (floori(-ly * nsy * 2.0 + sa * 2.0) & mask) << shift
		var ny2b := (floori(-ly * nsy * 2.0 + sb * 2.0) & mask) << shift
		for x in range(xa, xb + 1):
			var lx := float(x) + 0.5 - center
			var xn := lx * inv_hw0
			if xn < -1.3 or xn > 1.3:
				continue
			# 火舌：横向第 k 条，中间高、两侧低
			var tp := clampf((xn + 1.0) * 0.5, 0.0, 0.9999) * float(tongues)
			var k := int(tp)
			var fr := tp - float(k)
			var peak := 1.0 - (2.0 * fr - 1.0) * (2.0 * fr - 1.0)
			var ve := v / (1.0 - depth + depth * peak * amps[k])
			if ve > 1.05:
				continue
			var vc := clampf(ve, 0.0, 1.0)
			var prof := 0.0
			match base:
				"point":
					prof = pow(maxf(sin(PI * pow(vc, 0.55)), 0.0), 0.5 + taper * 0.6)
				"round":
					if vc < 0.3:
						var q := (0.3 - vc) / 0.3
						prof = sqrt(maxf(1.0 - q * q, 0.0))
					else:
						prof = pow(maxf(1.0 - (vc - 0.3) / 0.7, 0.0), 0.4 + taper)
				_:
					prof = pow(maxf(1.0 - vc, 0.0), 0.35 + taper)
			if ve < 0.0:
				prof *= 1.0 + ve / 0.08
			if prof <= 0.01:
				continue
			var s := 1.0 - absf(xn) / prof
			if s < -0.3:
				continue
			var ix1 := floori(lx * ns + 40.0) & mask
			var ix2 := floori(lx * ns * 2.0 + 17.0) & mask
			var m1 := wa * n1[ny1a | ix1] + wb * n1[ny1b | ix1]
			var m2 := wa * n2[ny2a | ix2] + wb * n2[ny2b | ix2]
			var nc := (0.65 * m1 + 0.35 * m2 - 0.5) * norm * 2.4 + 0.5
			if nc < 0.0:
				nc = 0.0
			elif nc > 1.0:
				nc = 1.0
			var val := s * (1.0 - 0.5 * vc) + 0.25 - nc * turb * (0.3 + 1.1 * vc)
			if val <= 0.12:
				continue
			var b := (val - 0.12) * (1.0 + core) * 1.15
			if b > 1.0:
				b = 1.0
			var out := (0.25 + 0.75 * b) * flick
			var i := row + x
			if out > bv[i]:
				bv[i] = out
			if 1.0 > ba[i]:
				ba[i] = 1.0
			drew = true
	buf.restore(bv, ba)
	if drew:
		buf.touch(xa, ya, xb, yb)
	return 1.0
