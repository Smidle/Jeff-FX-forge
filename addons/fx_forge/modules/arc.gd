@tool
extends "fx_module.gd"
## 弧光：斩击、回旋斩、月牙形刀光。
## 刀锋（head）沿弧线扫过，刀尾（tail）延迟跟上，两者之间就是可见的刀光；
## 厚度沿弧线呈月牙形分布（两端尖、靠近刀锋处最粗），外缘最亮。
## 「方向」= 挥砍弧线的中点朝向。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")

## 厚度轮廓查找表的精度
const _LUT_N := 256


func get_id() -> String:
	return "arc"


func get_display_name() -> String:
	return "弧光"


func get_display_name_en() -> String:
	return "Arc"


func get_description() -> String:
	return "斩击、回旋斩、月牙形刀光"


func is_directional() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.num("radius", "半径", "Radius", 4.0, 240.0, 24.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "刀光外缘到中心的距离"}),
		P.num("thickness", "宽度", "Width", 1.0, 120.0, 9.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "刀光最粗处的宽度"}),
		P.num("span", "弧度", "Arc Span", 20.0, 360.0, 200.0, {group = "shape", unit = "°", step = 1.0, tip = "挥砍扫过的角度，360 就是回旋斩"}),
		P.num("taper", "尖锐度", "Taper", 0.0, 1.0, 0.7, {group = "shape", tip = "两端收尖的程度"}),
		P.num("crescent", "月牙感", "Crescent", 0.0, 1.0, 0.5, {group = "shape", tip = "越大越像月牙：最粗的地方更靠近刀锋前端"}),
		P.num("squash", "透视压扁", "Squash", 0.2, 1.0, 1.0, {group = "shape", tip = "把弧线上下压扁，模拟斜着看到的挥砍"}),
		P.num("trail", "拖尾长度", "Trail", 0.05, 1.0, 0.55, {group = "motion", tip = "同一时刻能看到多长的一段刀光"}),
		P.num("sweep", "挥砍用时", "Sweep Time", 0.2, 0.95, 0.55, {group = "motion", tip = "刀锋扫完全程占整段动画的比例，剩下的时间用来收尾"}),
		P.choice("easing", "速度曲线", "Easing", M.EASE_OPTIONS, "out_cubic", {group = "motion", tip = "刀锋的快慢节奏：缓出 = 起手快、收刀慢"}),
		P.boolean("clockwise", "顺时针", "Clockwise", true, {group = "motion"}),
		P.num("rim", "亮边", "Rim Light", 0.0, 1.0, 0.6, {group = "detail", tip = "外缘比内侧亮多少"}),
		P.num("edge_noise", "边缘毛糙", "Edge Roughness", 0.0, 1.0, 0.15, {group = "detail", tip = "内缘的参差感"}),
		P.integer("ghosts", "残影数", "Afterimages", 0, 3, 0, {group = "detail", tip = "刀光后面留下几道淡残影"}),
	]


func prepare(p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	# 沿弧线的厚度轮廓：k = 0 刀尾 → k = 1 刀锋
	var bias := 1.0 + float(p["crescent"])
	var end_pow := 0.35 + float(p["taper"]) * 1.6
	var prof := PackedFloat32Array()
	prof.resize(_LUT_N + 1)
	for i in _LUT_N + 1:
		var k := float(i) / float(_LUT_N)
		prof[i] = pow(maxf(sin(PI * pow(k, bias)), 0.0), end_pow)
	return {"noise": M.periodic_noise(360, 3, rng), "profile": prof}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var radius: float = p["radius"]
	var thick: float = p["thickness"]
	var span := deg_to_rad(float(p["span"]))
	var squash: float = p["squash"]
	var trail: float = p["trail"]
	var sweep: float = p["sweep"]
	var ease_id: String = p["easing"]
	var cw: bool = p["clockwise"]
	var rim_pow := 1.0 - float(p["rim"]) * 0.75
	var rough: float = p["edge_noise"]
	var ghosts: int = p["ghosts"]
	var noise: PackedFloat32Array = st["noise"]
	var prof: PackedFloat32Array = st["profile"]
	var nn := noise.size()

	var w := buf.w
	var cx := ctx.ox
	var cy := ctx.oy
	var ca := ctx.cos_a
	var sa := ctx.sin_a
	var reach := radius + 1.5
	var xa := maxi(floori(cx - reach), 0)
	var xb := mini(ceili(cx + reach), w - 1)
	var ya := maxi(floori(cy - reach), 0)
	var yb := mini(ceili(cy + reach), buf.h - 1)
	if xa > xb or ya > yb:
		return 1.0

	# 节奏：刀锋在 sweep 时刻扫完（按速度曲线，快起慢收）；
	# 刀尾在 tail_start 才出发、先慢后快，最多退到弧线的 80%（剩下的交给变细和溶解）；
	# 刀锋扫完后刀光从内侧逐渐变细，后半段整体抖动溶解——每一帧都有内容，收尾干净。
	var tail_start := sweep * (0.25 + 0.75 * trail)
	var tail_len := maxf(1.0 - tail_start, 0.05)
	var half := span * 0.5
	var inv_sq := 1.0 / maxf(squash, 0.05)
	var r_out2 := radius * radius
	var nscale := float(nn) / TAU

	var bv := buf.v
	var ba := buf.a
	buf.release()
	var drew := false
	for g in range(ghosts + 1):
		var ug := u - float(g) * 0.07
		if ug <= 0.0:
			continue
		var head := span * M.apply_ease(ease_id, ug / sweep)
		var tk := clampf((ug - tail_start) / tail_len, 0.0, 1.0)
		var tail := span * 0.8 * tk * tk
		var vis := head - tail
		if vis <= 0.002:
			continue
		var thin := 1.0 - 0.6 * smoothstep(sweep * 0.9, 1.0, ug)
		var tg := thick * thin * (1.0 if g == 0 else 0.8)
		var vmul := 1.0 if g == 0 else 0.75
		var amul := 1.0 if g == 0 else 0.55 - 0.12 * float(g)
		var r_in := maxf(radius - tg * (1.0 + rough * 0.6) - 1.0, 0.0)
		var r_in2 := r_in * r_in
		var inv_vis := 1.0 / vis
		for y in range(ya, yb + 1):
			var dy := float(y) + 0.5 - cy
			var row := y * w
			for x in range(xa, xb + 1):
				var dx := float(x) + 0.5 - cx
				# 转到局部坐标：刀光中线朝 +x
				var lx := dx * ca + dy * sa
				var ly := (dy * ca - dx * sa) * inv_sq
				var r2 := lx * lx + ly * ly
				if r2 > r_out2 or r2 < r_in2:
					continue
				var th := atan2(ly, lx)
				var s := (th + half) if cw else (half - th)
				if s < 0.0:
					s += TAU
				elif s >= TAU:
					s -= TAU
				if s < tail or s > head:
					continue
				var k := (s - tail) * inv_vis
				var pw: float = prof[int(k * _LUT_N)]
				if pw <= 0.0:
					continue
				var wl := tg * pw * (1.0 + rough * (noise[int(s * nscale) % nn] - 0.5) * 1.2)
				var r := sqrt(r2)
				var rin := radius - wl
				if r < rin:
					continue
				var q := (r - rin) / maxf(wl, 0.001)
				var val := (0.3 + 0.7 * pow(q, rim_pow)) * (0.55 + 0.45 * k) * vmul
				var i := row + x
				if val > bv[i]:
					bv[i] = val
				if amul > ba[i]:
					ba[i] = amul
				drew = true
	buf.restore(bv, ba)
	if drew:
		buf.touch(xa, ya, xb, yb)
	return 1.0 - 0.85 * smoothstep(0.55, 1.0, u)
