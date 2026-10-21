@tool
extends "fx_module.gd"
## 光柱：传送光柱、激光、圣光。
## 从原点沿「方向」射出（做竖直光柱时把方向设为 270° 朝上），宽度先展开、最后收起；
## 边缘波纹和内部亮条沿着光柱流动（流动速度为整数，循环首尾无缝）；底部可以有一圈贴地光斑。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")
const FxNoise := preload("../core/fx_noise.gd")


func get_id() -> String:
	return "beam"


func get_display_name() -> String:
	return "光柱"


func get_display_name_en() -> String:
	return "Beam"


func get_description() -> String:
	return "传送光柱、激光、圣光"


func is_directional() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.num("length", "长度", "Length", 4.0, 400.0, 64.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("width", "宽度", "Width", 1.0, 120.0, 12.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("core", "内核宽度", "Core", 0.0, 1.0, 0.35, {group = "shape", tip = "中间最亮的部分占多宽"}),
		P.num("taper", "末端收窄", "Taper", 0.0, 1.0, 0.2, {group = "shape"}),
		P.num("ripple", "边缘波纹", "Ripple", 0.0, 1.0, 0.3, {group = "shape"}),
		P.num("base_glow", "底部光斑", "Base Glow", 0.0, 1.0, 0.6, {group = "shape", tip = "原点处一圈贴地的椭圆光斑"}),
		P.num("open_time", "展开用时", "Open Time", 0.0, 0.6, 0.15, {group = "motion", tip = "从一条细线展开到全宽的时间（循环特效设 0）"}),
		P.num("close_time", "收起用时", "Close Time", 0.0, 0.6, 0.25, {group = "motion", tip = "最后收成一条线消失的时间（循环特效设 0）"}),
		P.choice("easing", "展开曲线", "Easing", M.EASE_OPTIONS, "out_cubic", {group = "motion"}),
		P.integer("flow", "流动速度", "Flow", 0, 8, 3, {group = "motion", tip = "波纹和亮条沿光柱流动的速度（整数，循环无缝）"}),
		P.num("pulse", "脉动", "Pulse", 0.0, 1.0, 0.2, {group = "motion"}),
		P.num("streaks", "亮条", "Streaks", 0.0, 1.0, 0.5, {group = "detail", tip = "光柱内部沿长度方向流动的明暗条"}),
	]


func prepare(_p: Dictionary, ctx: FxContext, _rng: RandomNumberGenerator) -> Dictionary:
	return {"noise": FxNoise.table(ctx.seed, 16, 2)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var length: float = p["length"]
	var width: float = p["width"]
	var core: float = p["core"]
	var taper: float = p["taper"]
	var ripple: float = p["ripple"]
	var base_glow: float = p["base_glow"]
	var open_t: float = p["open_time"]
	var close_t: float = p["close_time"]
	var ease_id: String = p["easing"]
	var flow_ph := fposmod(float(p["flow"]) * u, 1.0)
	var pulse: float = p["pulse"]
	var streaks: float = p["streaks"]
	var noise: PackedFloat32Array = st["noise"]
	var mask := FxNoise.MASK
	var shift := FxNoise.SHIFT

	var env := 1.0
	if open_t > 0.0:
		env *= M.apply_ease(ease_id, u / open_t)
	if close_t > 0.0:
		env *= 1.0 - M.apply_ease("in_quad", (u - (1.0 - close_t)) / close_t)
	if env <= 0.0:
		return 1.0
	var hw0 := width * 0.5 * env * (1.0 + pulse * 0.12 * sin(TAU * fposmod(3.0 * u, 1.0)))
	if hw0 < 0.4:
		return 1.0
	var ox := ctx.ox
	var oy := ctx.oy
	var ca := ctx.cos_a
	var sa := ctx.sin_a
	var lam := maxf(width * 1.5, 4.0)

	# 包围盒：光柱的四个角
	var m := hw0 * (1.0 + ripple * 0.25) + 2.0
	var ex := ox + ca * length
	var ey := oy + sa * length
	var xa := maxi(floori(minf(ox, ex) - m), 0)
	var xb := mini(ceili(maxf(ox, ex) + m), buf.w - 1)
	var ya := maxi(floori(minf(oy, ey) - m), 0)
	var yb := mini(ceili(maxf(oy, ey) + m), buf.h - 1)
	if xa <= xb and ya <= yb:
		var w := buf.w
		var bv := buf.v
		var ba := buf.a
		buf.release()
		var drew := false
		var inv_len := 1.0 / length
		var scroll := flow_ph * float(FxNoise.SIZE)
		for y in range(ya, yb + 1):
			var dy := float(y) + 0.5 - oy
			var row := y * w
			for x in range(xa, xb + 1):
				var dx := float(x) + 0.5 - ox
				var lx := dx * ca + dy * sa
				if lx < -hw0 or lx > length:
					continue
				var ly := dy * ca - dx * sa
				var k := clampf(lx * inv_len, 0.0, 1.0)
				var hw := hw0 * (1.0 - taper * k) * (1.0 + ripple * 0.2 * sin(TAU * (lx / lam - flow_ph)))
				var a := 0.0
				if lx < 0.0:
					# 起点圆头
					a = sqrt(lx * lx + ly * ly) / hw0
				else:
					a = absf(ly) / maxf(hw, 0.3)
				if a > 1.0:
					continue
				var val := 1.0 if a < core else 0.9 - 0.5 * (a - core) / maxf(1.0 - core, 0.001)
				if streaks > 0.0:
					var n := noise[((floori(lx * 0.35 - scroll) & mask) << shift) | (floori(ly * 2.0 + 64.0) & mask)]
					val *= 1.0 - streaks * 0.35 + streaks * 0.5 * n
				# 末端渐暗
				val *= 1.0 - 0.35 * smoothstep(0.85, 1.0, k)
				var i := row + x
				if val > bv[i]:
					bv[i] = val
				if 1.0 > ba[i]:
					ba[i] = 1.0
				drew = true
		buf.restore(bv, ba)
		if drew:
			buf.touch(xa, ya, xb, yb)
	if base_glow > 0.0:
		var rx := hw0 * (1.0 + base_glow)
		buf.ellipse(ox, oy, rx, rx * 0.35, 0.95, 0.5, 1.0)
	return 1.0
