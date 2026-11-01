@tool
extends RefCounted
## 参考角色：工坊 3D 场景里对照特效大小的小人。不用贴图文件，由一副三维骨架画成像素图。
## 做法参考 pixelfx（https://github.com/patch-gg/pixelfx ，MIT 许可）的 src/core/rig.js：
## - 骨头长度固定、一节挂一节（骨盆 → 腰 → 胸 → 肩、头），姿势只给手脚该在哪里，肘和膝由两段 IK 算出来；
## - 身体由椭球和圆管拼成，全部经过同一个深度缓冲画到像素上，前后遮挡自然正确；
## - 按受光分成四级平涂色调，远侧的手脚暗一级；部件前后叠压的地方和外轮廓按材质描深色线，相接的地方压一条暗缝。
## 比例和风格参考 DNF（地下城与勇士）的剑士：约 6 头身、长腿宽肩，侧身 3/4 朝右，
## 膝盖微屈、右手持太刀、刀尖朝前下方的战斗待机，长外套的下摆垂在身后；呼吸时膝盖一起一伏，刀尖、下摆和头发跟着轻摆。
## 坐标：x 向右（面朝方向），y 向上，z 朝向镜头，单位是像素，脚底在原点。右半身朝向镜头，所以右手是近侧的手。

## 画布大小和脚底所在的像素（列, 行）
const W := 44
const H := 54
const FOOT := Vector2i(14, 52)
## 脚底在画布上的位置（像素，左上为原点、y 向下）：外轮廓那一行的下沿贴地
const ORIGIN := Vector2(14.5, 53.0)
## 待机动画：帧数、每秒几帧
const FRAMES := 6
const FPS := 7.0

## 身体尺寸（像素）：约 50 像素高，头约 8 像素，腿占一半
const PELVIS := 26.4
const HIP_DOWN := 1.4
const HIP_OUT := 2.9
const THIGH := 12.4
const SHIN := 11.8
const ANKLE := 2.4
const SPINE1 := 3.2
const SPINE2 := 5.2
const SH_UP := 2.4
const SH_OUT := 5.8
const NECK_UP := 4.6
const HEAD_UP := 4.2
const UPPER := 9.4
const FORE := 8.8
## 身体最低画到这一行（世界 y），下面一行留给外轮廓
const GROUND := 1

## 光从左上前方来
const LIGHT := Vector3(-0.38, 0.72, 0.58)

## 部件：编号不同的部件之间才描缝；远侧的手脚暗一级
enum { NONE, PELVIS_P, WAIST_P, CHEST_P, NECK_P, HEAD_P, HAIR_P, COLLAR_P, BELT_P, COAT_P,
	UPPER_N, FORE_N, HAND_N, THIGH_N, SHIN_N, FOOT_N,
	UPPER_F, FORE_F, HAND_F, THIGH_F, SHIN_F, FOOT_F, SWORD_P }
## 材质
enum { SKIN, HAIR, COAT, TRIM, SHIRT, PANTS, BOOTS, GLOVE, STEEL, GRIP, BELT }
## 每种材质：亮、基本、暗、最暗、描边
const PALETTE := [
	["fbe0c4", "eab48e", "c0805f", "8a4f3d", "3a1c1a"],
	["f7f8fc", "cfd4e2", "959cb4", "626881", "232637"],
	["e8604f", "bd3f40", "862a35", "561b2b", "220a18"],
	["fff0a0", "e8b84e", "b07a2c", "74491c", "2a1608"],
	["6a6e88", "4b4e66", "34364b", "232435", "0e0e18"],
	["565b78", "3d4058", "2a2c40", "1c1d2c", "0b0b14"],
	["b07a4e", "845637", "5c3925", "3a231a", "170c09"],
	["646076", "45405a", "2f2b3d", "1e1b28", "0a080e"],
	["ffffff", "dbe3f2", "a0acc6", "66718c", "1b1f30"],
	["a8433f", "7a2c2e", "521d21", "331216", "140608"],
	["7a5440", "5a3d2e", "402b21", "2a1c16", "100a07"],
]
const EYE := "2b1d2e"
## 椭球的上色方式：0 整个一种材质；1 外套前襟敞开（中间露出衬衣、两边金色镶边）；2 头发（脸的部分不画）
enum { PLAIN, OPEN_FRONT, HAIR_CAP }

static var _frames: Array[Image] = []

var _z := PackedFloat32Array()
var _light := PackedFloat32Array()
var _part := PackedInt32Array()
var _mat := PackedInt32Array()
var _tone := PackedInt32Array()
var _touched := PackedInt32Array()
var _colors: Array = []


## 待机动画的每一帧（第一次调用时生成，之后用缓存）
static func frames() -> Array[Image]:
	if _frames.is_empty():
		for i in FRAMES:
			_frames.append(new()._render(_pose(TAU * i / FRAMES)))
	return _frames


## 战斗待机在呼吸相位 phase（0~TAU）时的姿势：手脚的位置（像素）和身体的朝向
static func _pose(phase: float) -> Dictionary:
	var bob := 0.5 - 0.5 * cos(phase)
	return {
		"crouch": 1.0 + 1.0 * bob,
		"lean": 0.12,
		"turn": deg_to_rad(32.0),
		"hand_n": Vector3(5.6, 21.0 - 0.8 * bob, 5.0),
		"hand_f": Vector3(-2.6 + 0.3 * sin(phase), 22.0 - 0.7 * bob, -4.8),
		"foot_n": Vector3(4.4, ANKLE, 2.7),
		"foot_f": Vector3(-4.2, ANKLE, -2.4),
		"sword": deg_to_rad(-48.0 + 2.0 * sin(phase)),
		"sway": sin(phase - 1.0),
		"hair": sin(phase - 0.6),
	}


func _init() -> void:
	_z.resize(W * H)
	_light.resize(W * H)
	_part.resize(W * H)
	_mat.resize(W * H)
	_tone.resize(W * H)
	for row: Array in PALETTE:
		var tones: Array[Color] = []
		for code: String in row:
			tones.append(Color(code))
		_colors.append(tones)


# ---------- 解姿势：从手脚该在哪里，算出每个关节 ----------

## 两段 IK：从 a 伸向 target，两节长 l1、l2，关节往 pole 那边弯。返回 [关节, 末端]
static func _ik(a: Vector3, target: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var to := target - a
	var d := to.length()
	var reach := l1 + l2 - 0.02
	if d > reach:
		to *= reach / d
		d = reach
	var u := to / d
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - along * along))
	var v := pole - u * pole.dot(u)
	v = v.normalized() if v.length() > 1e-4 else u.cross(Vector3.BACK).normalized()
	return [a + u * along + v * h, a + to]


func _render(q: Dictionary) -> Image:
	var tilt: float = q.lean
	var turn: float = q.turn
	var hip_turn := turn * 0.45
	var rp := Basis(Vector3.BACK, -tilt * 0.25) * Basis(Vector3.UP, -hip_turn)
	var rc := Basis(Vector3.BACK, -tilt) * Basis(Vector3.UP, -turn)
	var rh := Basis(Vector3.BACK, -tilt * 0.35) * Basis(Vector3.UP, -turn * 0.85)
	var foot_n: Vector3 = q.foot_n
	var foot_f: Vector3 = q.foot_f
	# 先定脚：两条腿够不着脚的位置时，骨盆往下沉
	var pelvis := Vector3(tilt * 2.0, PELVIS - float(q.crouch), 0)
	var max_leg := (THIGH + SHIN) * 0.995
	for s: float in [1.0, -1.0]:
		var hip := pelvis + rp * Vector3(0, -HIP_DOWN, s * HIP_OUT)
		var ankle := foot_n if s > 0 else foot_f
		var flat := Vector2(hip.x - ankle.x, hip.z - ankle.z).length_squared()
		if flat < max_leg * max_leg:
			var top := ankle.y + sqrt(max_leg * max_leg - flat)
			if hip.y > top:
				pelvis.y -= hip.y - top
	var hip_n := pelvis + rp * Vector3(0, -HIP_DOWN, HIP_OUT)
	var hip_f := pelvis + rp * Vector3(0, -HIP_DOWN, -HIP_OUT)
	var waist := pelvis + Vector3(sin(tilt * 0.45), cos(tilt * 0.45), 0) * SPINE1
	var chest := waist + Vector3(sin(tilt), cos(tilt), 0) * SPINE2
	var neck := chest + rc * Vector3(0, NECK_UP, 0)
	var head := neck + rh * Vector3(0.3, HEAD_UP, 0)
	var sh_n := chest + rc * Vector3(0, SH_UP, SH_OUT)
	var sh_f := chest + rc * Vector3(0, SH_UP, -SH_OUT)
	# 肘往下、往后弯；膝往前、稍微往外
	var arm_n := _ik(sh_n, q.hand_n, UPPER, FORE, Vector3(-0.6, -1.0, 0.5))
	var arm_f := _ik(sh_f, q.hand_f, UPPER, FORE, Vector3(-0.6, -1.0, -0.5))
	var leg_n := _ik(hip_n, foot_n, THIGH, SHIN, rp * Vector3(1, 0, 0.3))
	var leg_f := _ik(hip_f, foot_f, THIGH, SHIN, rp * Vector3(1, 0, -0.3))

	# ---- 身体
	_ellipsoid(pelvis + Vector3(0, -0.3, 0), rp, Vector3(3.7, 3.1, 4.7), PELVIS_P, COAT)
	_sweep(pelvis, chest, 3.4, 3.8, WAIST_P, COAT)
	_ellipsoid(chest + rc * Vector3(0.2, 0.8, 0), rc, Vector3(4.0, 5.2, 6.0), CHEST_P, COAT, OPEN_FRONT)
	_sweep(neck, neck + rh * Vector3(0, 1.8, 0), 1.5, 1.4, NECK_P, SKIN)
	# 立领：后面高、前面敞开
	for k in range(-6, 7):
		var a := k * deg_to_rad(20.0) + PI
		var ring := Vector3(cos(a) * 2.7, 0, sin(a) * 3.0)
		_sweep(chest + rc * (ring + Vector3(0, 3.4, 0)), chest + rc * (ring * 1.05 + Vector3(-0.3, 5.0, 0)), 0.9, 0.8, COLLAR_P, COAT)
	_ellipsoid(head, rh, Vector3(3.4, 3.9, 3.2), HEAD_P, SKIN)
	_ellipsoid(head + rh * Vector3(0.9, -0.6, 0), rh, Vector3(2.8, 3.1, 2.7), HEAD_P, SKIN)
	_hair(head, rh, float(q.hair))
	# 腰带和金色带扣
	var belt := pelvis + Vector3(0, 1.9, 0)
	for k in 24:
		var a := TAU * k / 24.0
		_sphere(belt + rp * Vector3(cos(a) * 3.9, 0, sin(a) * 4.8), 1.0, BELT_P, BELT if k != 0 else TRIM)
	_coat_tail(pelvis, rp, float(q.crouch), float(q.sway))

	# ---- 手脚（远侧先画、近侧后画都无所谓：深度缓冲决定前后）
	_arm(sh_n, arm_n, UPPER_N, FORE_N, HAND_N)
	_arm(sh_f, arm_f, UPPER_F, FORE_F, HAND_F)
	_leg(hip_n, leg_n, rp, THIGH_N, SHIN_N, FOOT_N)
	_leg(hip_f, leg_f, rp, THIGH_F, SHIN_F, FOOT_F)
	_sword(arm_n[1], float(q.sword))
	return _finish(head, rh)


func _arm(shoulder: Vector3, arm: Array, upper: int, fore: int, hand: int) -> void:
	var elbow: Vector3 = arm[0]
	var wrist: Vector3 = arm[1]
	_sphere(shoulder, 2.7, upper, COAT)
	_sweep(shoulder, elbow, 2.3, 1.9, upper, COAT)
	_sphere(elbow, 1.8, fore, COAT)
	_sweep(elbow, wrist, 1.9, 1.6, fore, COAT, 0.15)
	# 袖口的金边、手套
	_sphere(elbow.lerp(wrist, 0.82), 1.8, fore, TRIM)
	_sphere(wrist, 1.9, hand, GLOVE)


func _leg(hip: Vector3, leg: Array, rp: Basis, thigh: int, shin: int, foot: int) -> void:
	var knee: Vector3 = leg[0]
	var ankle: Vector3 = leg[1]
	_sweep(hip, knee, 3.0, 2.3, thigh, PANTS)
	_sphere(knee, 2.0, shin, PANTS)
	# 小腿上段是裤子，下段是靴子（靴口略粗）
	var top := knee.lerp(ankle, 0.38)
	_sweep(knee, top, 2.0, 1.9, shin, PANTS)
	_sweep(top, ankle, 2.3, 1.75, shin, BOOTS)
	var dir := rp * Vector3(1, 0, 0)
	dir = Vector3(dir.x, 0, dir.z * 0.6).normalized()
	_sweep(ankle + dir * -1.2 + Vector3(0, -0.6, 0), ankle + dir * 4.4 + Vector3(0, -1.2, 0), 1.9, 1.35, foot, BOOTS)


## 头发：后脑和头顶的一顶「帽子」，往后上方翘的几簇发尖，额前垂下的刘海
func _hair(head: Vector3, rh: Basis, sway: float) -> void:
	_ellipsoid(head + rh * Vector3(-0.5, 0.8, 0), rh, Vector3(4.0, 4.0, 3.8), HAIR_P, HAIR, HAIR_CAP)
	var spikes := [
		[Vector3(-2.6, 2.6, 0.0), Vector3(-1.0, 0.75, 0.0), 5.4],
		[Vector3(-1.6, 3.4, 1.6), Vector3(-0.8, 1.0, 0.45), 4.6],
		[Vector3(-1.6, 3.4, -1.6), Vector3(-0.8, 1.0, -0.45), 4.4],
		[Vector3(-3.2, 0.6, 1.4), Vector3(-1.0, -0.3, 0.5), 3.8],
		[Vector3(-3.0, -0.8, -0.6), Vector3(-1.0, -0.35, -0.2), 4.0],
		[Vector3(0.4, 3.9, 0.2), Vector3(-0.2, 1.0, 0.1), 3.0],
	]
	for s: Array in spikes:
		var root: Vector3 = head + rh * (s[0] as Vector3)
		var dir: Vector3 = rh * (s[1] as Vector3).normalized()
		var tip: Vector3 = root + dir * float(s[2]) + Vector3(-0.35 * sway, 0, 0)
		_sweep(root, tip, 1.7, 0.35, HAIR_P, HAIR)
	# 刘海：从额头上方垂到眉毛
	for z: float in [1.3, -0.2, -1.5]:
		var root := head + rh * Vector3(2.0, 3.0, z)
		_sweep(root, root + rh * Vector3(1.4, -2.9, 0.15 * z), 1.3, 0.35, HAIR_P, HAIR)


## 外套下摆：从腰一圈垂到膝盖下面，只有身后半圈（前面敞开，露出两条腿），往后飘开
func _coat_tail(pelvis: Vector3, rp: Basis, crouch: float, sway: float) -> void:
	var deg := 115.0
	while deg <= 245.01:
		var a := deg_to_rad(deg)
		var back := clampf(-cos(a), 0.0, 1.0)
		var top := pelvis + rp * Vector3(cos(a) * 3.9, 1.0, sin(a) * 4.8)
		var hem := Vector3(pelvis.x, 7.2 + crouch * 0.5 - back * 0.8, 0) + rp * Vector3(cos(a) * 6.0, 0, sin(a) * 6.3)
		hem.x -= back * (2.2 + 0.7 * sway)
		# 布料的褶皱：法线随角度轻轻起伏，平涂后就是一道道竖褶
		var fold := a + 0.35 * sin(a * 7.0)
		# 下摆在身后、背光，比上身暗一点
		var n := (rp * Vector3(cos(fold) * 0.8, -0.1, sin(fold) * 0.6)).normalized()
		var steps := ceili(top.distance_to(hem) / 0.4)
		for k in steps + 1:
			var u := float(k) / steps
			_sphere(top.lerp(hem, u), 1.25, COAT_P, TRIM if u > 0.93 else COAT, n)
		deg += 8.0


## 太刀：刀柄在右手里，刀尖朝前下方，刀身略弯
func _sword(hand: Vector3, angle: float) -> void:
	var axis := Vector3(cos(angle), sin(angle), 0.12).normalized()
	var side := Vector3(-sin(angle), cos(angle), 0)
	var i := -3.6
	while i <= 25.0:
		if i < -3.2:
			_blade_row(hand, axis, side, i, 0.9, TRIM, -1)
		elif i < 2.2:
			_blade_row(hand, axis, side, i, 0.75, GRIP, -2)
		elif i < 3.0:
			_blade_row(hand, axis, side, i, 1.9, TRIM, -1)
		else:
			var r := i - 3.0
			var half := 1.0 if r < 19.0 else maxf(0.0, (22.0 - r) / 3.0)
			_blade_row(hand + side * (0.0016 * r * r), axis, side, i, half, STEEL, -3)
		i += 0.4


## 刀的一排像素。shade：-1 按受光平涂，-2 刀柄的缠绳花纹，-3 刀身（刀背亮、刃口暗）
func _blade_row(hand: Vector3, axis: Vector3, side: Vector3, i: float, half: float, mat: int, shade: int) -> void:
	var k := -half
	while k <= half + 0.01:
		var p := hand + axis * i + side * k
		var tone := 1
		if shade == -2:
			tone = 1 if (roundi(i * 2.5) + roundi(k * 2.5)) % 2 == 0 else 2
		elif shade == -3:
			tone = 0 if k > half * 0.35 else (2 if k < -half * 0.35 else 1)
		_plot(roundi(p.x), roundi(p.y), p.z + 0.05, 0.0, SWORD_P, mat, tone)
		k += 0.4


# ---------- 画到像素上：所有部件经过同一个深度缓冲 ----------

func _plot(wx: int, wy: int, z: float, light: float, part: int, mat: int, tone: int = -1) -> void:
	if wy < GROUND:
		return
	var ix := FOOT.x + wx
	var iy := FOOT.y - wy
	if ix < 0 or iy < 0 or ix >= W or iy >= H:
		return
	var i := iy * W + ix
	if _part[i] != NONE and z <= _z[i]:
		return
	if _part[i] == NONE:
		_touched.append(i)
	_z[i] = z
	_light[i] = light
	_part[i] = part
	_mat[i] = mat
	_tone[i] = tone


## 实心球：n 不为零时用它代替球面法线算受光（布料这类要平整的面）
func _sphere(c: Vector3, r: float, part: int, mat: int, n: Vector3 = Vector3.ZERO) -> void:
	var r2 := r * r
	var lit := n.dot(LIGHT.normalized())
	for wy in range(floori(c.y - r), ceili(c.y + r) + 1):
		var dy := wy - c.y
		for wx in range(floori(c.x - r), ceili(c.x + r) + 1):
			var dx := wx - c.x
			var d2 := dx * dx + dy * dy
			if d2 > r2:
				continue
			var dz := sqrt(r2 - d2)
			var light := lit if n != Vector3.ZERO else Vector3(dx / r, dy / r, dz / r).dot(LIGHT.normalized())
			_plot(wx, wy, c.z + dz, light, part, mat)


## 圆管：从 a 到 b，半径从 ra 渐变到 rb，中间可以鼓起一点（bulge）
func _sweep(a: Vector3, b: Vector3, ra: float, rb: float, part: int, mat: int, bulge: float = 0.0) -> void:
	var n := maxi(2, ceili(a.distance_to(b) / 0.4))
	for k in n + 1:
		var u := float(k) / n
		_sphere(a.lerp(b, u), lerpf(ra, rb, u) + bulge * sin(u * PI), part, mat)


## 椭球：中心 c，三个半轴沿 basis 的三个轴、长度 r；从镜头方向（+z）看过去取前表面
func _ellipsoid(c: Vector3, basis: Basis, r: Vector3, part: int, mat: int, style: int = PLAIN) -> void:
	var a := basis * Basis.from_scale(Vector3(1.0 / (r.x * r.x), 1.0 / (r.y * r.y), 1.0 / (r.z * r.z))) * basis.transposed()
	var back := basis.transposed()
	var big := maxf(r.x, maxf(r.y, r.z))
	var light_dir := LIGHT.normalized()
	for wy in range(floori(c.y - big), ceili(c.y + big) + 1):
		var dy := wy - c.y
		for wx in range(floori(c.x - big), ceili(c.x + big) + 1):
			var dx := wx - c.x
			var qa := a.z.z
			var qb := 2.0 * (a.z.x * dx + a.z.y * dy)
			var qc := a.x.x * dx * dx + 2.0 * a.y.x * dx * dy + a.y.y * dy * dy - 1.0
			var disc := qb * qb - 4.0 * qa * qc
			if disc < 0.0:
				continue
			var dz := (-qb + sqrt(disc)) / (2.0 * qa)
			var n := (a * Vector3(dx, dy, dz)).normalized()
			var m := mat
			if style != PLAIN:
				var local := back * n
				if style == OPEN_FRONT:
					m = SHIRT if local.x > 0.82 else (TRIM if local.x > 0.68 else mat)
				elif style == HAIR_CAP and local.x > 0.05 and local.y < 0.55:
					continue
			_plot(wx, wy, c.z + dz, n.dot(light_dir), part, m)


# ---------- 平涂、暗缝、描边 ----------

static func _is_far(part: int) -> bool:
	return part >= UPPER_F and part <= FOOT_F


func _finish(head: Vector3, rh: Basis) -> Image:
	var tones := PackedInt32Array()
	tones.resize(W * H)
	for i: int in _touched:
		var t := _tone[i]
		if t < 0:
			var v := _light[i]
			t = 0 if v > 0.72 else (1 if v > 0.32 else (2 if v > -0.05 else 3))
			if _is_far(_part[i]):
				t = mini(3, t + 1)
		tones[i] = t
	# 孤立的一个像素（同一部件里四周没有同色调的）改成邻居最多的色调，平涂面更干净
	for i: int in _touched:
		if _tone[i] >= 0:
			continue
		var votes := [0, 0, 0, 0]
		var same := false
		for d: int in [-1, 1, -W, W]:
			var j := i + d
			if j < 0 or j >= W * H or _part[j] != _part[i]:
				continue
			votes[tones[j]] += 1
			if tones[j] == tones[i]:
				same = true
		if not same and votes.max() > 0:
			tones[i] = votes.find(votes.max())
	var image := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var color: Array[Color] = []
	color.resize(W * H)
	for i: int in _touched:
		color[i] = _colors[_mat[i]][tones[i]]
	# 两个部件相接：前后差得多（一个叠在另一个前面）描深色线，否则压一条暗缝
	var marks := {}
	for i: int in _touched:
		for d: int in [1, W]:
			var j := i + d
			if j >= W * H or (d == 1 and j % W == 0) or _part[j] == NONE or _part[j] == _part[i]:
				continue
			var near := i if _z[i] >= _z[j] else j
			var far := j if near == i else i
			var dz := absf(_z[i] - _z[j])
			if _part[i] == SWORD_P or _part[j] == SWORD_P:
				if dz < 1.0:
					continue
				marks[far] = _colors[_mat[near]][4]
			elif dz > 2.2:
				marks[far] = _colors[_mat[near]][4]
			elif not marks.has(far):
				marks[far] = _colors[_mat[far]][3]
	for i: int in marks:
		color[i] = marks[i]
	for i: int in _touched:
		image.set_pixel(i % W, i / W, color[i])
	# 眼睛：近侧的眼睛两个像素高，远侧的眼睛看得到才画
	for e: Array in [[Vector3(2.75, -0.4, 1.25), 2], [Vector3(2.9, -0.4, -1.0), 1]]:
		var p: Vector3 = head + rh * (e[0] as Vector3)
		var ix := FOOT.x + roundi(p.x)
		var iy := FOOT.y - roundi(p.y)
		var i := iy * W + ix
		if ix < 0 or ix >= W or iy < 1 or iy >= H or _part[i] != HEAD_P or absf(_z[i] - p.z) > 1.6:
			continue
		for k: int in e[1]:
			if _part[i - k * W] == HEAD_P:
				image.set_pixel(ix, iy - k, Color(EYE))
	# 外轮廓：贴着身体的空像素按旁边部件的材质描深色
	for i: int in _touched:
		for d: int in [-1, 1, -W, W]:
			var j := i + d
			if j < 0 or j >= W * H or _part[j] != NONE or (d == 1 and j % W == 0) or (d == -1 and i % W == 0):
				continue
			var x := j % W
			var y := j / W
			if image.get_pixel(x, y).a == 0.0:
				image.set_pixel(x, y, _colors[_mat[i]][4])
	return image
