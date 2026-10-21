@tool
extends RefCounted
## 解析式粒子：每个粒子的位置 / 大小 / 亮度都是时间的闭式函数，任意一帧都能单独求值（便于多线程逐帧渲染）。
## 单位：像素；时间用图层本地时间 u（0~1 = 图层整段时长）。速度 = 一整段时长里（无阻力时）走过的像素数。
## 发射方向围绕图层朝向；重力始终朝屏幕下方，不随方向旋转。

const FxBuffer := preload("fx_buffer.gd")

const SHAPE_OPTIONS := [
	["pixel", "像素点"], ["square", "方块"], ["disc", "圆点"], ["plus", "十字"],
	["diamond", "菱形"], ["star", "四角星"], ["streak", "拖影线"], ["shard", "碎片"], ["puff", "烟团"],
]
const EMIT_SHAPE_OPTIONS := [["point", "一个点"], ["circle", "圆形区域"], ["ring", "圆环上"], ["line", "一条横线"], ["box", "矩形区域"]]
const EMIT_MODE_OPTIONS := [["burst", "一次爆发"], ["stream", "持续发射"]]
const FLOW_OPTIONS := [["out", "向外飞散"], ["gather", "向中心汇聚"]]

enum Shape { PIXEL, SQUARE, DISC, PLUS, DIAMOND, STAR, STREAK, SHARD, PUFF }
const _SHAPE_IDS := ["pixel", "square", "disc", "plus", "diamond", "star", "streak", "shard", "puff"]


static func shape_index(id: String) -> int:
	return maxi(_SHAPE_IDS.find(id), 0)


## 生成粒子表（主线程调用）。cfg 键：
##   count, emit_shape, emit_radius, emit_height（矩形区域的高）, angle（弧度，发射中心方向）, spread（度）,
##   speed, speed_random, life, life_random, emit_mode, emit_time, size, size_random, spin（圈 / 整段）,
##   mirror（true = 一半粒子左右镜像：从原点往两侧对称地飞，例如落地扬起的尘土）
## 返回字典，每项是 PackedFloat32Array：x y（出生点相对原点）, vx vy（初速度）, t0（出生时间）,
##   life, size, bright（0.75~1 的随机亮度）, rot（初始朝向）, spin, phase（闪烁相位）
static func spawn(cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var count: int = cfg["count"]
	var emit_shape: String = cfg["emit_shape"]
	var radius: float = cfg["emit_radius"]
	var center: float = cfg["angle"]
	var spread := deg_to_rad(float(cfg["spread"]))
	var full := spread >= TAU - 0.01
	var speed: float = cfg["speed"]
	var speed_rnd: float = cfg["speed_random"]
	var life: float = cfg["life"]
	var life_rnd: float = cfg["life_random"]
	var stream: bool = cfg["emit_mode"] == "stream"
	var emit_time: float = cfg["emit_time"]
	var size: float = cfg["size"]
	var size_rnd: float = cfg["size_random"]
	var spin: float = cfg["spin"]
	var mirror: bool = cfg.get("mirror", false)
	var t := {}
	for key: String in ["x", "y", "vx", "vy", "t0", "life", "size", "bright", "rot", "spin", "phase"]:
		var arr := PackedFloat32Array()
		arr.resize(count)
		t[key] = arr
	var xs: PackedFloat32Array = t["x"]
	var ys: PackedFloat32Array = t["y"]
	var vxs: PackedFloat32Array = t["vx"]
	var vys: PackedFloat32Array = t["vy"]
	var t0s: PackedFloat32Array = t["t0"]
	var lifes: PackedFloat32Array = t["life"]
	var sizes: PackedFloat32Array = t["size"]
	var brights: PackedFloat32Array = t["bright"]
	var rots: PackedFloat32Array = t["rot"]
	var spins: PackedFloat32Array = t["spin"]
	var phases: PackedFloat32Array = t["phase"]
	# 持续发射时出生时间按序号排；发射角度如果也按序号排，粒子会像扫射一样绕圈出现，所以角度用打乱后的序号
	var order := PackedInt32Array()
	order.resize(count)
	for i in count:
		order[i] = i
	if stream:
		for i in range(count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := order[i]
			order[i] = order[j]
			order[j] = tmp
	for i in count:
		# 发射方向：扇形内均匀分布 + 抖动
		var k := (float(i) + rng.randf()) / float(count)
		var ka := (float(order[i]) + rng.randf()) / float(count) if stream else k
		var ang := center + (ka - 0.5) * spread if not full else center + ka * TAU
		var px := 0.0
		var py := 0.0
		match emit_shape:
			"circle":
				var rr := radius * sqrt(rng.randf())
				px = cos(ang) * rr
				py = sin(ang) * rr
			"ring":
				px = cos(ang) * radius
				py = sin(ang) * radius
			"line":
				var lx := (rng.randf() * 2.0 - 1.0) * radius
				# 横线沿发射中心方向的垂直方向铺开
				px = -sin(center) * lx
				py = cos(center) * lx
				ang = center + (rng.randf() - 0.5) * spread
			"box":
				# 矩形区域始终和屏幕对齐：宽 = 2 × 发射范围，高 = emit_height
				px = (rng.randf() * 2.0 - 1.0) * radius
				py = (rng.randf() - 0.5) * float(cfg.get("emit_height", radius * 2.0))
				ang = center + (rng.randf() - 0.5) * spread
		var sp := speed * (1.0 - speed_rnd * rng.randf())
		# 左右对称：奇数号粒子沿竖直线翻到另一边
		var mx := -1.0 if mirror and i % 2 == 1 else 1.0
		xs[i] = px * mx
		ys[i] = py
		vxs[i] = cos(ang) * sp * mx
		vys[i] = sin(ang) * sp
		t0s[i] = rng.randf() * emit_time if not stream else k * maxf(emit_time, 0.001)
		lifes[i] = maxf(life * (1.0 - life_rnd * rng.randf()), 0.02)
		sizes[i] = size * (1.0 - size_rnd * rng.randf() * 0.7)
		brights[i] = 1.0 - 0.25 * rng.randf()
		rots[i] = rng.randf() * TAU
		spins[i] = spin * TAU * (0.5 + rng.randf()) * (1.0 if rng.randf() < 0.5 else -1.0)
		phases[i] = rng.randf()
	return t


## 把 u 时刻的粒子画进画布。cfg 键：
##   shape（Shape 枚举值）, size_end, gravity, drag, cool, bright, flicker, streak_len, loop, ox, oy,
##   gather（true = 向中心汇聚：从「向外飞散时会到达的位置」出发，越来越快地被吸到原点）,
##   sway（左右摆动的幅度，像素）, floor_y（粒子落到原点下方这么多像素就消失；不设 = 不限制）
## 返回这一帧画了多少个粒子
static func draw(buf: FxBuffer, t: Dictionary, cfg: Dictionary, u: float) -> int:
	var xs: PackedFloat32Array = t["x"]
	var ys: PackedFloat32Array = t["y"]
	var vxs: PackedFloat32Array = t["vx"]
	var vys: PackedFloat32Array = t["vy"]
	var t0s: PackedFloat32Array = t["t0"]
	var lifes: PackedFloat32Array = t["life"]
	var sizes: PackedFloat32Array = t["size"]
	var brights: PackedFloat32Array = t["bright"]
	var rots: PackedFloat32Array = t["rot"]
	var spins: PackedFloat32Array = t["spin"]
	var phases: PackedFloat32Array = t["phase"]
	var shape: int = cfg["shape"]
	var size_end: float = cfg["size_end"]
	var g: float = cfg["gravity"]
	var k: float = cfg["drag"]
	var cool: float = cfg["cool"]
	var bright: float = cfg["bright"]
	var flicker: float = cfg["flicker"]
	var streak_len: float = cfg["streak_len"]
	var loop: bool = cfg["loop"]
	var ox: float = cfg["ox"]
	var oy: float = cfg["oy"]
	var gather: bool = cfg.get("gather", false)
	var sway: float = cfg.get("sway", 0.0)
	var use_floor: bool = cfg.has("floor_y")
	var floor_y: float = oy + float(cfg.get("floor_y", 0.0))
	var drawn := 0
	for i in xs.size():
		var ta := u - t0s[i]
		if loop:
			ta = fposmod(ta, 1.0)
		var life := lifes[i]
		if ta < 0.0 or ta > life:
			continue
		var tau := ta / life
		# 闪烁：按相位随机熄灭一部分时间
		if flicker > 0.0 and fposmod(phases[i] + tau * 3.7, 1.0) < flicker * 0.45:
			continue
		var x := 0.0
		var y := 0.0
		var vx_now := 0.0
		var vy_now := 0.0
		var alpha := 1.0 - smoothstep(0.6, 1.0, tau)
		if gather:
			# 汇聚：起点 = 出生点 + 0.35 × 初速度，越来越快地被吸到原点；开头淡入、到中心前淡出
			var sx := xs[i] + vxs[i] * 0.35
			var sy := ys[i] + vys[i] * 0.35
			var e2 := tau * tau
			x = ox + sx * (1.0 - e2)
			y = oy + sy * (1.0 - e2)
			# 真实速度（位置对时间求导），越靠近中心越快，拖影也越长
			vx_now = -sx * 2.0 * tau / life
			vy_now = -sy * 2.0 * tau / life
			alpha = smoothstep(0.0, 0.25, tau) * (1.0 - smoothstep(0.85, 1.0, tau))
		else:
			# 带线性阻力和重力的闭式运动
			var e := exp(-k * ta) if k > 0.0001 else 1.0
			var f := (1.0 - e) / k if k > 0.0001 else ta
			x = ox + xs[i] + vxs[i] * f
			y = oy + ys[i] + vys[i] * f
			vy_now = vys[i] * e
			if k > 0.0001:
				y += g / k * (ta - f)
				vy_now += g / k * (1.0 - e)
			else:
				y += 0.5 * g * ta * ta
				vy_now += g * ta
			vx_now = vxs[i] * e
			if sway > 0.0:
				# 左右摆动（飘落的灰、上升的光点）：每个粒子相位不同，出生时从 0 开始摆
				x += sway * (sin(TAU * (phases[i] + tau * 1.25)) - sin(TAU * phases[i]))
			if use_floor and y > floor_y:
				continue
		var sz := maxf(sizes[i] * lerpf(1.0, size_end, tau), 0.5)
		var val := clampf(bright * brights[i] * (1.0 - cool * tau), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		_draw_one(buf, shape, x, y, sz, val, alpha, rots[i] + spins[i] * ta, vx_now, vy_now, streak_len)
		drawn += 1
	return drawn


static func _draw_one(buf: FxBuffer, shape: int, x: float, y: float, sz: float, val: float, alpha: float, rot: float, vx: float, vy: float, streak_len: float) -> void:
	match shape:
		Shape.PIXEL:
			if sz < 1.6:
				buf.plot(floori(x), floori(y), val, alpha)
			else:
				var s := roundi(sz)
				buf.rect(floori(x - s * 0.5 + 0.5), floori(y - s * 0.5 + 0.5), s, s, val, alpha)
		Shape.SQUARE:
			var s2 := maxi(1, roundi(sz))
			buf.rect(floori(x - s2 * 0.5 + 0.5), floori(y - s2 * 0.5 + 0.5), s2, s2, val, alpha)
		Shape.DISC:
			buf.disc(x, y, maxf(sz * 0.5, 0.6), val, val * 0.85, alpha)
		Shape.PLUS:
			var arm := maxi(1, roundi(sz * 0.5))
			var cx := floori(x)
			var cy := floori(y)
			# 大十字（7 像素以上）用 3 像素粗的臂，像医疗十字
			var ht := 1 if sz >= 6.5 else 0
			buf.rect(cx - arm, cy - ht, arm * 2 + 1, ht * 2 + 1, val * 0.85, alpha)
			buf.rect(cx - ht, cy - arm, ht * 2 + 1, arm * 2 + 1, val * 0.85, alpha)
			buf.rect(cx - ht, cy - ht, ht * 2 + 1, ht * 2 + 1, val, alpha)
		Shape.DIAMOND:
			buf.diamond(x, y, maxf(sz * 0.6, 0.7), val, val * 0.8, alpha)
		Shape.STAR:
			star(buf, x, y, sz, rot, val, alpha)
		Shape.STREAK:
			var sp := sqrt(vx * vx + vy * vy)
			var length := maxf(sp * streak_len * 0.12, 1.0)
			var nx := vx / sp if sp > 0.001 else 1.0
			var ny := vy / sp if sp > 0.001 else 0.0
			buf.capsule(x, y, x - nx * length, y - ny * length, maxf(sz * 0.35, 0.5), 0.35, val, val * 0.55, alpha)
		Shape.SHARD:
			var r := maxf(sz, 1.0)
			var pts := PackedVector2Array([
				Vector2(x + cos(rot) * r, y + sin(rot) * r),
				Vector2(x + cos(rot + 2.4) * r * 0.55, y + sin(rot + 2.4) * r * 0.55),
				Vector2(x + cos(rot - 2.4) * r * 0.55, y + sin(rot - 2.4) * r * 0.55),
			])
			buf.polygon(pts, val, alpha)
		Shape.PUFF:
			buf.puff(x, y, maxf(sz * 0.5, 0.6), val, alpha)


## 四角星：四条尖臂 + 菱形核心（射线爆发的闪光也用它）
static func star(buf: FxBuffer, x: float, y: float, size: float, rot: float, val: float, alpha: float) -> void:
	var arm := maxf(size, 1.0)
	var base := maxf(arm * 0.2, 0.75)
	for q in 4:
		var a := rot + q * PI * 0.5
		buf.capsule(x, y, x + cos(a) * arm, y + sin(a) * arm, base, 0.4, val, val * 0.9, alpha)
	buf.diamond(x, y, maxf(arm * 0.32, 0.8), val, val, alpha)
