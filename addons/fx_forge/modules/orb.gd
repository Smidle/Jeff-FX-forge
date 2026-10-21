@tool
extends "fx_module.gd"
## 能量弹：火球弹、魔法飞弹、能量球（适合循环）。
## 亮核 + 脉动光晕 + 往飞行反方向拖出的波动尾巴（尾巴上有往后流动的明暗条）+ 环绕的小光点。
## 原点 = 弹体中心，「方向」= 飞行方向。所有随时间变化的量都按整数圈循环，首尾无缝。

const P := preload("../core/fx_params.gd")
const FxNoise := preload("../core/fx_noise.gd")

const SHAPE_OPTIONS := [["round", "圆球"], ["diamond", "菱形"], ["flame", "火球（边缘翻滚）"]]


func get_id() -> String:
	return "orb"


func get_display_name() -> String:
	return "能量弹"


func get_display_name_en() -> String:
	return "Orb"


func get_description() -> String:
	return "火球弹、魔法飞弹、能量球"


func is_directional() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.choice("shape", "弹体形状", "Shape", SHAPE_OPTIONS, "round", {group = "shape"}),
		P.num("core", "核心半径", "Core", 0.5, 60.0, 3.5, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "最亮的芯有多大"}),
		P.num("halo", "光晕半径", "Halo", 1.0, 80.0, 7.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "弹体整体有多大"}),
		P.num("trail", "拖尾长度", "Trail", 0.0, 200.0, 20.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("trail_width", "拖尾粗细", "Trail Width", 0.1, 1.5, 0.8, {group = "shape", hide_if = ["trail", 0.0], tip = "相对光晕的粗细"}),
		P.num("wobble", "拖尾波动", "Wobble", 0.0, 1.0, 0.3, {group = "shape", hide_if = ["trail", 0.0]}),
		P.num("noise", "翻滚强度", "Turbulence", 0.0, 1.0, 0.5, {group = "shape", show_if = ["shape", "flame"]}),
		P.num("pulse", "脉动", "Pulse", 0.0, 1.0, 0.3, {group = "motion", tip = "光晕一胀一缩的幅度"}),
		P.integer("pulse_speed", "脉动次数", "Pulses", 1, 6, 2, {group = "motion", hide_if = ["pulse", 0.0], tip = "一个循环里胀缩几次"}),
		P.integer("flow", "尾巴流动", "Trail Flow", 0, 6, 2, {group = "motion", tip = "尾巴上的明暗条往后流动的速度（整数，循环无缝）"}),
		P.integer("orbiters", "环绕光点", "Orbiters", 0, 8, 0, {group = "detail"}),
		P.num("orbit_radius", "环绕半径", "Orbit Radius", 1.0, 80.0, 9.0, {group = "detail", unit = "px", scale = true, step = 0.5, hide_if = ["orbiters", 0]}),
		P.integer("orbit_turns", "环绕圈数", "Orbit Turns", -4, 4, 1, {group = "detail", hide_if = ["orbiters", 0], tip = "一个循环转几圈（整数才能首尾衔接）"}),
	]


func prepare(_p: Dictionary, ctx: FxContext, _rng: RandomNumberGenerator) -> Dictionary:
	return {"noise": FxNoise.table(ctx.seed, 16, 3)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var shape: String = p["shape"]
	var core: float = p["core"]
	var halo: float = p["halo"]
	var trail: float = p["trail"]
	var trail_w: float = p["trail_width"]
	var wobble: float = p["wobble"]
	var namp: float = float(p["noise"]) if shape == "flame" else 0.0
	var pulse: float = p["pulse"]
	var pulse_ph := sin(TAU * fposmod(float(p["pulse_speed"]) * u, 1.0))
	var flow_ph := fposmod(float(p["flow"]) * u, 1.0)
	var noise: PackedFloat32Array = st["noise"]
	var mask := FxNoise.MASK
	var shift := FxNoise.SHIFT
	var hr := halo * (1.0 + pulse * 0.2 * pulse_ph)
	var cr := minf(core * (1.0 + pulse * 0.12 * pulse_ph), hr * 0.95)
	var ang := TAU * u
	var nox := cos(ang) * 16.0 + 9.0
	var noy := sin(ang) * 16.0 + 5.0
	var ox := ctx.ox
	var oy := ctx.oy
	var ca := ctx.cos_a
	var sa := ctx.sin_a
	var reach := maxf(hr * (1.0 + namp * 0.8), hr) + trail + 2.0
	var xa := maxi(floori(ox - reach), 0)
	var xb := mini(ceili(ox + reach), buf.w - 1)
	var ya := maxi(floori(oy - reach), 0)
	var yb := mini(ceili(oy + reach), buf.h - 1)
	if xa <= xb and ya <= yb:
		var inv_trail := 1.0 / trail if trail > 0.0 else 0.0
		var w := buf.w
		var bv := buf.v
		var ba := buf.a
		buf.release()
		var drew := false
		for y in range(ya, yb + 1):
			var dy := float(y) + 0.5 - oy
			var row := y * w
			for x in range(xa, xb + 1):
				var dx := float(x) + 0.5 - ox
				var lx := dx * ca + dy * sa
				var ly := dy * ca - dx * sa
				var val := -1.0
				# 弹体
				var dist := sqrt(lx * lx + ly * ly)
				if shape == "diamond":
					dist = (absf(lx) * 0.8 + absf(ly)) * 1.05
				elif namp > 0.0:
					dist += (noise[((floori(dy * 1.3 + noy) & mask) << shift) | (floori(dx * 1.3 + nox) & mask)] - 0.5) * namp * hr * 0.9
				if dist < cr:
					val = 1.0
				elif dist < hr:
					val = 0.85 - 0.4 * (dist - cr) / maxf(hr - cr, 0.001)
				# 拖尾（弹体后方）
				if lx < 0.0 and inv_trail > 0.0:
					var k := -lx * inv_trail
					if k < 1.0:
						var hw := hr * trail_w * pow(1.0 - k, 0.8)
						var wob := wobble * hr * 0.6 * sin(TAU * (k * 1.5 - flow_ph)) * k
						var off := absf(ly - wob)
						if off < hw:
							var tv := (0.75 - 0.45 * k) * (1.0 - 0.35 * off / hw)
							tv *= 0.82 + 0.18 * sin(TAU * (k * 3.0 - flow_ph))
							if tv > val:
								val = tv
				if val <= 0.0:
					continue
				var i := row + x
				if val > bv[i]:
					bv[i] = val
				if 1.0 > ba[i]:
					ba[i] = 1.0
				drew = true
		buf.restore(bv, ba)
		if drew:
			buf.touch(xa, ya, xb, yb)
	# 环绕光点（略微压扁的轨道，有立体感）
	var n: int = p["orbiters"]
	if n > 0:
		var r: float = p["orbit_radius"]
		var base := TAU * fposmod(float(p["orbit_turns"]) * u, 1.0)
		for i in n:
			var a := base + TAU * float(i) / float(n)
			var px := cos(a) * r
			var py := sin(a) * r * 0.55
			buf.diamond(ox + px * ca - py * sa, oy + px * sa + py * ca, maxf(halo * 0.22, 1.0), 0.95, 0.8, 1.0)
	return 1.0
