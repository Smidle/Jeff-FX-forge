@tool
extends RefCounted
## 解析式粒子：每个粒子的位置 / 大小 / 亮度都是时间的闭式函数，任意一帧都能单独求值（便于多线程逐帧渲染）。
## 单位：像素；时间用图层本地时间 u（0~1 = 图层整段时长）。速度 = 一整段时长里（无阻力时）走过的像素数。
## 发射方向围绕图层朝向；重力始终朝屏幕下方，不随方向旋转。

const FxBuffer := preload("fx_buffer.gd")
const FxPixelFont := preload("fx_pixel_font.gd")

const SHAPE_OPTIONS := [
	["pixel", "像素点"], ["square", "方块"], ["disc", "圆点"], ["plus", "十字"],
	["diamond", "菱形"], ["star", "四角星"], ["streak", "拖影线"], ["shard", "碎片"], ["puff", "烟团"],
	["smoke", "烟雾（三团）"],
]
const EMIT_SHAPE_OPTIONS := [["point", "一个点"], ["circle", "圆形区域"], ["ring", "圆环上"], ["line", "一条横线"], ["box", "矩形区域"],
	["heart", "心形图案"], ["star", "五角星图案"], ["smile", "笑脸图案"], ["text", "文字"]]
const EMIT_MODE_OPTIONS := [["burst", "一次爆发"], ["stream", "持续发射"]]
const FLOW_OPTIONS := [["out", "向外飞散"], ["gather", "向中心汇聚"]]

enum Shape { PIXEL, SQUARE, DISC, PLUS, DIAMOND, STAR, STREAK, SHARD, PUFF, SMOKE }
const _SHAPE_IDS := ["pixel", "square", "disc", "plus", "diamond", "star", "streak", "shard", "puff", "smoke"]
## 每个粒子最多几段运动（第一段 + 最多 3 次反弹 / 停下）
const _SEGS := 4
## 停在地面上以后水平滑动的阻力
const _REST_DRAG := 7.0


static func shape_index(id: String) -> int:
	return maxi(_SHAPE_IDS.find(id), 0)


## 生成粒子表（主线程调用）。cfg 键：
##   count, emit_shape, emit_radius, emit_height（矩形区域的高）, angle（弧度，发射中心方向）, spread（度）,
##   speed, speed_random, life, life_random, emit_mode, emit_time, size, size_random, spin（圈 / 整段）,
##   mirror（true = 一半粒子左右镜像：从原点往两侧对称地飞，例如落地扬起的尘土）,
##   squash（出生点和初速度的纵向分量乘这个倍数：圆环发射变成贴在地面上的扁椭圆）,
##   sphere（true = 速度按球面投影：侧面看，朝镜头和背向镜头飞的粒子显得慢，炸开是一个实心的球，不是一个圈）,
##   emit_rise（发射点在发射时长内从原点升起这么多像素，先快后慢：礼花弹升空时一路洒下火星）
## 发射区域选心形 / 五角星 / 笑脸图案时，粒子从原点出发，速度按图案分布，炸开后保持这个形状（阻力、重力对所有粒子一样）
## 选文字时（cfg 的 text 是要排的字），粒子一开始就排成文字、半宽是 emit_radius，再按 speed 向外放大：
## 半径 0 是从原点炸开成字，速度 0 是直接在那里出现（停留在空中的字）
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
	var squash: float = cfg.get("squash", 1.0)
	var sphere: bool = cfg.get("sphere", false)
	var emit_rise: float = cfg.get("emit_rise", 0.0)
	var pattern := emit_shape == "heart" or emit_shape == "star" or emit_shape == "smile"
	var letters := FxPixelFont.points(str(cfg.get("text", ""))) if emit_shape == "text" else PackedVector2Array()
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
		if sphere:
			var z := rng.randf() * 2.0 - 1.0
			sp *= sqrt(1.0 - z * z)
		if squash < 1.0:
			py *= squash
		# 左右对称：奇数号粒子沿竖直线翻到另一边
		var mx := -1.0 if mirror and i % 2 == 1 else 1.0
		xs[i] = px * mx
		ys[i] = py
		vxs[i] = cos(ang) * sp * mx
		vys[i] = sin(ang) * sp * (squash if squash < 1.0 else 1.0)
		if pattern:
			var dir := _pattern_point(emit_shape, ka)
			vxs[i] = dir.x * sp
			vys[i] = dir.y * sp * (squash if squash < 1.0 else 1.0)
		elif not letters.is_empty():
			# 文字：粒子按序号分到文字的各个点上（数量和点数相同时一点一颗）
			var dot := letters[mini(int(ka * letters.size()), letters.size() - 1)]
			xs[i] = dot.x * radius
			ys[i] = dot.y * radius
			vxs[i] = dot.x * sp
			vys[i] = dot.y * sp
		t0s[i] = rng.randf() * emit_time if not stream else k * maxf(emit_time, 0.001)
		if emit_rise > 0.0:
			ys[i] -= emit_rise * _rise(t0s[i] / maxf(emit_time, 0.001))
		lifes[i] = maxf(life * (1.0 - life_rnd * rng.randf()), 0.02)
		sizes[i] = size * (1.0 - size_rnd * rng.randf() * 0.7)
		brights[i] = 1.0 - 0.25 * rng.randf()
		rots[i] = rng.randf() * TAU
		spins[i] = spin * TAU * (0.5 + rng.randf()) * (1.0 if rng.randf() < 0.5 else -1.0)
		phases[i] = rng.randf()
	return t


## 图案发射的方向和速度倍数：u（0~1）沿图案走一圈，返回图案上的点（大小约 1，y 向下）
static func _pattern_point(id: String, u: float) -> Vector2:
	var th := u * TAU
	if id == "heart":
		var s := sin(th)
		return Vector2(s * s * s, -(13.0 * cos(th) - 5.0 * cos(2.0 * th) - 2.0 * cos(3.0 * th) - cos(4.0 * th)) / 16.0 + 0.2)
	if id == "smile":
		# 笑脸：58% 的点画脸的外圈，两只眼睛各 8%，剩下 26% 画嘴（下半圆弧）
		var f0 := fposmod(u, 1.0)
		if f0 < 0.58:
			return Vector2.from_angle(f0 / 0.58 * TAU)
		if f0 < 0.74:
			var e := (f0 - 0.58) / 0.08
			var side := -1.0 if e < 1.0 else 1.0
			return Vector2(side * 0.36, -0.3) + Vector2.from_angle(fposmod(e, 1.0) * TAU) * 0.09
		var m := (f0 - 0.74) / 0.26
		return Vector2.from_angle(PI * (0.18 + 0.64 * m)) * 0.58 + Vector2(0.0, -0.05)
	# 五角星：沿 10 个顶点（外 1、内 0.42 交替）连成的折线均匀取点
	var f := fposmod(u, 1.0) * 10.0
	var j := int(f)
	var a := Vector2.from_angle(-PI * 0.5 + float(j) * PI / 5.0) * (1.0 if j % 2 == 0 else 0.42)
	var b := Vector2.from_angle(-PI * 0.5 + float(j + 1) * PI / 5.0) * (1.0 if (j + 1) % 2 == 0 else 0.42)
	return a.lerp(b, f - float(j))


## 发射点上升的进度（0~1 → 0~1，先快后慢）
static func _rise(k: float) -> float:
	var r := 1.0 - clampf(k, 0.0, 1.0)
	return 1.0 - r * r * r


## 带线性阻力 k 和重力 g 的闭式运动：从 (x, y, vx, vy) 出发经过 dt 后的位置和速度
static func _move(x: float, y: float, vx: float, vy: float, g: float, k: float, dt: float) -> Vector4:
	if k > 0.0001:
		var e := exp(-k * dt)
		var f := (1.0 - e) / k
		return Vector4(x + vx * f, y + vy * f + g / k * (dt - f), vx * e, vy * e + g / k * (1.0 - e))
	return Vector4(x + vx * dt, y + vy * dt + 0.5 * g * dt * dt, vx, vy + g * dt)


## 落地反弹（主线程，prepare 里调用一次）：按闭式运动找出粒子碰到地面线的时刻，从碰撞点反弹后再算一段闭式运动，
## 最多弹 3 次；反弹高度不到 1 像素就停在地面上，只剩很快停下的水平滑动。
## 每帧渲染时只需找到所在的那一段，所以任意一帧仍能单独求值。
## 写进 t：seg_n（段数）, seg_t / seg_x / seg_y / seg_vx / seg_vy / seg_rest（每粒子 _SEGS 段；时间相对出生，位置相对原点）
static func bounce_paths(t: Dictionary, g: float, k: float, floor_y: float, bounce: float) -> void:
	var xs: PackedFloat32Array = t["x"]
	var ys: PackedFloat32Array = t["y"]
	var vxs: PackedFloat32Array = t["vx"]
	var vys: PackedFloat32Array = t["vy"]
	var lifes: PackedFloat32Array = t["life"]
	var count := xs.size()
	var seg_n := PackedInt32Array()
	seg_n.resize(count)
	var cols := {}
	for key: String in ["seg_t", "seg_x", "seg_y", "seg_vx", "seg_vy", "seg_rest"]:
		var arr := PackedFloat32Array()
		arr.resize(count * _SEGS)
		arr.fill(0.0)
		cols[key] = arr
	var st: PackedFloat32Array = cols["seg_t"]
	var sx: PackedFloat32Array = cols["seg_x"]
	var sy: PackedFloat32Array = cols["seg_y"]
	var svx: PackedFloat32Array = cols["seg_vx"]
	var svy: PackedFloat32Array = cols["seg_vy"]
	var srest: PackedFloat32Array = cols["seg_rest"]
	# 反弹后至少要能弹起 1 像素，否则算停下
	var min_vy := sqrt(2.0 * maxf(g, 0.0))
	for i in count:
		var b := i * _SEGS
		st[b] = 0.0
		sx[b] = xs[i]
		sy[b] = ys[i]
		svx[b] = vxs[i]
		svy[b] = vys[i]
		var n := 1
		var t0 := 0.0
		var life := lifes[i]
		# 出生在地面线以下、或者重力向上的粒子不反弹
		while g > 0.0 and ys[i] < floor_y and n < _SEGS and t0 < life:
			var s := b + n - 1
			var step := maxf(life / 96.0, 0.0005)
			var ta := 0.0
			var hit := -1.0
			while t0 + ta < life:
				var tb := ta + step
				if _move(sx[s], sy[s], svx[s], svy[s], g, k, tb).y >= floor_y:
					# 二分找到碰撞时刻
					var lo := ta
					var hi := tb
					for _r in 14:
						var mid := (lo + hi) * 0.5
						if _move(sx[s], sy[s], svx[s], svy[s], g, k, mid).y >= floor_y:
							hi = mid
						else:
							lo = mid
					hit = hi
					break
				ta = tb
			if hit < 0.0:
				break
			var at := _move(sx[s], sy[s], svx[s], svy[s], g, k, hit)
			t0 += hit
			var vy_new := -at.w * bounce
			var q := b + n
			st[q] = t0
			sx[q] = at.x
			sy[q] = floor_y
			svx[q] = at.z * 0.7
			if -vy_new < min_vy or n == _SEGS - 1:
				svy[q] = 0.0
				srest[q] = 1.0
				n += 1
				break
			svy[q] = vy_new
			n += 1
		seg_n[i] = n
	t["seg_n"] = seg_n
	t.merge(cols)


## 把 u 时刻的粒子画进画布。cfg 键：
##   shape（Shape 枚举值）, size_end, gravity, drag, cool, bright, flicker, streak_len, loop, ox, oy,
##   gather（true = 向中心汇聚：从「向外飞散时会到达的位置」出发，越来越快地被吸到原点）,
##   sway（左右摆动的幅度，像素）, floor_y（粒子落到原点下方这么多像素就消失；不设 = 不限制；
##   粒子表里有 bounce_paths() 算好的反弹路径时改为反弹、停在地面上）,
##   opacity（起始可见度）, thin（随寿命变稀的程度）, soft（烟团边缘更透明的程度）,
##   glow / glow_size / glow_tone（每个粒子的叠加光：强度、半径、光色位置）,
##   flicker_from（寿命走到这里才开始闪烁）, fade_from（寿命走到这里开始变淡，1 = 一直不淡，到寿命直接消失）, trail（尾迹：画出过去这么长时间走过的路径，越往后越暗越淡）,
##   split / split_at / split_speed / split_life（寿命走到 split_at 时一颗分成 split 颗，以 split_speed 向四周散开，
##   子粒子活到剩余寿命的 split_life），emit_head / emit_rise / emit_time（发射点上升时在发射点画一个亮头）
##   尾迹和分裂不用于汇聚和落地反弹的粒子
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
	var paths := t.has("seg_n") and not gather
	var seg_n: PackedInt32Array = t.get("seg_n", PackedInt32Array())
	var seg_t: PackedFloat32Array = t.get("seg_t", PackedFloat32Array())
	var seg_x: PackedFloat32Array = t.get("seg_x", PackedFloat32Array())
	var seg_y: PackedFloat32Array = t.get("seg_y", PackedFloat32Array())
	var seg_vx: PackedFloat32Array = t.get("seg_vx", PackedFloat32Array())
	var seg_vy: PackedFloat32Array = t.get("seg_vy", PackedFloat32Array())
	var seg_rest: PackedFloat32Array = t.get("seg_rest", PackedFloat32Array())
	var opacity: float = cfg.get("opacity", 1.0)
	var thin: float = cfg.get("thin", 0.0)
	var shade_alpha := opacity < 1.0 or thin > 0.0
	var soft: float = cfg.get("soft", 0.0)
	var glow: float = cfg.get("glow", 0.0)
	var glow_size: float = cfg.get("glow_size", 6.0)
	var glow_tone: float = cfg.get("glow_tone", 0.6)
	var flicker_from: float = cfg.get("flicker_from", 0.0)
	var flicker_rate: float = cfg.get("flicker_rate", 3.7)
	var fade_from: float = cfg.get("fade_from", 0.6)
	var trail: float = cfg.get("trail", 0.0)
	var split: int = cfg.get("split", 0)
	var split_at: float = cfg.get("split_at", 0.5)
	var split_speed: float = cfg.get("split_speed", 30.0)
	var split_life: float = cfg.get("split_life", 1.0)
	var free_flight := not gather and not paths
	var drawn := 0
	var emit_rise: float = cfg.get("emit_rise", 0.0)
	if cfg.get("emit_head", false) and emit_rise > 0.0:
		# 发射点上升中：一个白热的亮点拖着一小段尾巴，带一团光
		var kk := u / maxf(float(cfg.get("emit_time", 1.0)), 0.001)
		if kk >= 0.0 and kk <= 1.0:
			var hy := oy - emit_rise * _rise(kk)
			buf.capsule(ox, hy, ox, hy + 3.0 + 6.0 * (1.0 - kk), 0.7, 0.4, 1.0, 0.7, 1.0)
			buf.plot(floori(ox), floori(hy), 1.0, 1.0)
			if glow > 0.0:
				buf.glow(ox, hy, glow_size + 2.0, glow, glow_tone)
	for i in xs.size():
		var ta := u - t0s[i]
		if loop:
			ta = fposmod(ta, 1.0)
		var life := lifes[i]
		if ta < 0.0 or ta > life:
			continue
		var tau := ta / life
		# 闪烁：按相位随机熄灭一部分时间
		if flicker > 0.0 and tau >= flicker_from and fposmod(phases[i] + tau * flicker_rate, 1.0) < flicker * 0.45:
			continue
		if split > 0 and free_flight and tau >= split_at:
			# 分裂：在 split_at 那一刻的位置一分为几，子粒子带着三成母粒子的速度向四周散开
			var ts := split_at * life
			var pm := _move(xs[i], ys[i], vxs[i], vys[i], g, k, ts)
			var c_end := ts + (life - ts) * split_life
			if ta > c_end:
				continue
			var ctau := (ta - ts) / maxf(c_end - ts, 0.0001)
			var c_alpha := (1.0 - smoothstep(0.6, 1.0, ctau)) * (opacity if shade_alpha else 1.0)
			var c_val := clampf(bright * brights[i] * (1.0 - cool * tau), 0.0, 1.0)
			var c_sz := maxf(sizes[i] * lerpf(1.0, size_end, tau) * 0.75, 0.5)
			for j in split:
				var a := rots[i] + TAU * float(j) / float(split)
				var cvx := pm.z * 0.3 + cos(a) * split_speed
				var cvy := pm.w * 0.3 + sin(a) * split_speed
				var cm := _move(pm.x, pm.y, cvx, cvy, g, k, ta - ts)
				if trail > 0.0:
					_trail(buf, pm.x, pm.y, cvx, cvy, g, k, ox, oy, ta - ts, trail, c_val, c_alpha)
				_draw_one(buf, shape, ox + cm.x, oy + cm.y, c_sz, c_val, c_alpha, a, cm.z, cm.w, streak_len, soft)
				if glow > 0.0:
					buf.glow(ox + cm.x, oy + cm.y, glow_size * 0.8, glow * c_val * c_alpha, glow_tone)
			drawn += 1
			continue
		var x := 0.0
		var y := 0.0
		var vx_now := 0.0
		var vy_now := 0.0
		var alpha := 1.0 - smoothstep(fade_from, 1.0, tau) if fade_from < 1.0 else 1.0
		var rot_t := ta
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
		elif paths:
			# 反弹路径：找到这一刻所在的那一段，从那一段的起点按闭式运动算
			var b := i * _SEGS
			var s := b
			for q in range(b + 1, b + seg_n[i]):
				if seg_t[q] <= ta:
					s = q
			var dt := ta - seg_t[s]
			if seg_rest[s] > 0.5:
				var e2 := exp(-_REST_DRAG * dt)
				x = ox + seg_x[s] + seg_vx[s] * (1.0 - e2) / _REST_DRAG
				y = oy + seg_y[s]
				vx_now = seg_vx[s] * e2
				# 停下以后不再翻滚：角度定在停下那一刻
				rot_t = seg_t[s]
			else:
				var m := _move(seg_x[s], seg_y[s], seg_vx[s], seg_vy[s], g, k, dt)
				x = ox + m.x
				y = oy + m.y
				vx_now = m.z
				vy_now = m.w
			if sway > 0.0:
				x += _sway_at(sway, phases[i], tau)
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
				x += _sway_at(sway, phases[i], tau)
			if use_floor and y > floor_y:
				continue
		var sz := maxf(sizes[i] * lerpf(1.0, size_end, tau), 0.5)
		var val := clampf(bright * brights[i] * (1.0 - cool * tau), 0.0, 1.0)
		if shade_alpha:
			alpha *= opacity * maxf(1.0 - thin * tau, 0.0)
		if alpha <= 0.0:
			continue
		if trail > 0.0 and free_flight:
			_trail(buf, xs[i], ys[i], vxs[i], vys[i], g, k, ox, oy, ta, trail, val, alpha, sway, phases[i], life)
		_draw_one(buf, shape, x, y, sz, val, alpha, rots[i] + spins[i] * rot_t, vx_now, vy_now, streak_len, soft)
		if glow > 0.0:
			buf.glow(x, y, glow_size, glow * val * alpha, glow_tone)
		drawn += 1
	return drawn


## 尾迹：从现在往回 trail 时长（不早于出生）走过的路径，分 6 段画成 1 像素的线，越往后越暗、越淡
## （按图层的消散方式点阵溶解）。sway > 0 时尾迹也跟着左右摆动（phase、life 与粒子本身相同）。
static func _trail(buf: FxBuffer, x0: float, y0: float, vx: float, vy: float, g: float, k: float, ox: float, oy: float, dt_now: float, trail: float, val: float, alpha: float, sway: float = 0.0, phase: float = 0.0, life: float = 1.0) -> void:
	var span := minf(trail, dt_now)
	if span <= 0.0:
		return
	var n := 6
	var prev := _move(x0, y0, vx, vy, g, k, dt_now)
	if sway > 0.0:
		prev.x += _sway_at(sway, phase, dt_now / life)
	for s in range(1, n + 1):
		var u0 := float(s - 1) / float(n)
		var u1 := float(s) / float(n)
		var cur := _move(x0, y0, vx, vy, g, k, dt_now - span * u1)
		if sway > 0.0:
			cur.x += _sway_at(sway, phase, (dt_now - span * u1) / life)
		buf.capsule(ox + prev.x, oy + prev.y, ox + cur.x, oy + cur.y, 0.5, 0.5, val * (1.0 - 0.55 * u0), val * (1.0 - 0.55 * u1), alpha * pow(1.0 - u0, 0.8))
		prev = cur


## 左右摆动的水平偏移：寿命走到 tau 时（出生时为 0）
static func _sway_at(sway: float, phase: float, tau: float) -> float:
	return sway * (sin(TAU * (phase + tau * 1.25)) - sin(TAU * phase))


static func _draw_one(buf: FxBuffer, shape: int, x: float, y: float, sz: float, val: float, alpha: float, rot: float, vx: float, vy: float, streak_len: float, soft: float = 0.0) -> void:
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
			buf.puff(x, y, maxf(sz * 0.5, 0.6), val, alpha, soft)
		Shape.SMOKE:
			# 三团叠成的一朵烟：上面一团最大最亮，左下、右下两团略小略暗
			var r := maxf(sz * 0.5, 0.6)
			buf.puff(x - r * 0.55, y + r * 0.3, r * 0.72, val * 0.85, alpha, soft)
			buf.puff(x + r * 0.5, y + r * 0.35, r * 0.66, val * 0.8, alpha, soft)
			buf.puff(x, y - r * 0.15, r, val, alpha, soft)


## 四角星：四条尖臂 + 菱形核心（射线爆发的闪光也用它）
static func star(buf: FxBuffer, x: float, y: float, size: float, rot: float, val: float, alpha: float) -> void:
	var arm := maxf(size, 1.0)
	var base := maxf(arm * 0.2, 0.75)
	for q in 4:
		var a := rot + q * PI * 0.5
		buf.capsule(x, y, x + cos(a) * arm, y + sin(a) * arm, base, 0.4, val, val * 0.9, alpha)
	buf.diamond(x, y, maxf(arm * 0.32, 0.8), val, val, alpha)
