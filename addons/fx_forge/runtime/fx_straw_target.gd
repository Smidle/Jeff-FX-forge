@tool
extends Node3D
## 稻草人靶子：飞弹、技能的测试目标，一张面向镜头的像素贴图（脚底在节点位置），被打中时有反应：
## - 像装在弹簧上一样被推得往后仰、来回摆几下停住（上半身按行错开，越往上偏得越多）；
## - 闪白：先两帧纯白剪影、再一帧半白；
## - 按命中的元素染色再慢慢褪掉：火烧黑、冰结霜（还会发抖）、暗影发紫；
## - 身上飞出几根稻草，在空中飘一会儿就消失（命中的碎屑不落到地上）。
## 做法参考 pixelfx（https://github.com/patch-gg/pixelfx ，MIT）src/core/act.js 的弹簧稻草靶（它又参考了 Hollow Crown，MIT）；
## 造型是这里重画的：木桩和横杆、麻袋上衣胸口有红色靶环、系绳腰带、麻袋头缝着 X 眼睛和笑嘴、戴一顶草帽。
## 所有反应都按「离命中过了多久」直接算出来，所以工坊预览来回拖动时间轴，画面每次都一样。
## 游戏里：调用 hit()，节点自己计时（auto_clock）。预览里：set_state(时刻, 命中列表) 由外面给时间。

## 每个像素在世界里多大（米）：和工坊里的参考角色、像素特效一样，约 2 米高
@export var pixel_size := 0.038:
	set(v):
		pixel_size = v
		if _sprite != null:
			_sprite.pixel_size = v
## 自己计时（游戏里）；预览里由 set_state() 给时间
@export var auto_clock := true

## 贴图（不含飞出去的稻草）：宽、高，脚底在最下面一行的中间
const W := 40
const H := 56
## 画布四周留出稻草飞出去、身体摆动的空间
const MARGIN := 18
const CW := W + MARGIN * 2
const CH := H + MARGIN
## 弹簧：角加速度 = -K·角度 - D·角速度（和 pixelfx 的稻草靶相同）
const K := 60.0
const D := 3.4
## 闪白：纯白的时长、之后半白的时长（秒）
const FLASH := 0.07
const FLASH_TAIL := 0.05
## 元素染色：颜色、最大比例、褪色用时（秒）
const SKINS := {
	"fire": [Color("1a0c0e"), 0.7, 1.6],
	"ice": [Color("a8e8ff"), 0.65, 1.4],
	"shadow": [Color("3a1a70"), 0.5, 1.2],
}
## 冰冻发抖的时长（秒）
const SHIVER := 0.45
const STRAW_COLORS := ["f0d98a", "d2aa55", "d2aa55", "9a7a36", "9a7a36"]

static var _base := PackedColorArray()

## 命中列表：[{t, element, push, dir}]，t 是命中时刻（秒），dir 是来势在屏幕上的左右（+1 朝右）
var hits: Array = []
var clock := 0.0
var _sprite: Sprite3D
var _image: Image
var _texture: ImageTexture
var _frame := -1


func _ready() -> void:
	if _base.is_empty():
		_base = _paint()
	_image = Image.create(CW, CH, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite3D.new()
	_sprite.texture = _texture
	_sprite.centered = false
	# 脚底（最下面一行的中间）对准节点
	_sprite.offset = Vector2(-CW * 0.5, 0)
	_sprite.pixel_size = pixel_size
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	_redraw(true)


func _process(delta: float) -> void:
	if auto_clock:
		clock += delta
		_redraw(false)


## 被打中（游戏里用）：element 是 fire / ice / shadow 或空；direction 是来势（世界方向），用来决定往哪边仰
func hit(element: String = "", push: float = 1.2, direction: Vector3 = Vector3.RIGHT) -> void:
	hits.append({"t": clock, "element": element, "push": push, "dir": _screen_side(direction)})
	_redraw(true)


## 预览用：直接给时刻和命中列表（列表里的 dir 可以是世界方向 Vector3，也可以是 ±1）
func set_state(at_time: float, list: Array) -> void:
	clock = at_time
	hits = []
	for h: Dictionary in list:
		var d: Variant = h.get("dir", 1.0)
		hits.append({"t": float(h.t), "element": str(h.get("element", "")), "push": float(h.get("push", 1.2)),
			"dir": _screen_side(d) if d is Vector3 else float(d)})
	_redraw(true)


## 来势在屏幕上朝右还是朝左（看当前镜头）
func _screen_side(direction: Vector3) -> float:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var right := camera.global_transform.basis.x if camera != null else Vector3.RIGHT
	return -1.0 if direction.dot(right) < 0.0 else 1.0


# ---------- 反应：按离每次命中过了多久算 ----------

func _redraw(force: bool) -> void:
	if _image == null:
		return
	var frame := int(clock * 30.0)
	if not force and frame == _frame:
		return
	_frame = frame
	var lean := 0.0
	var flash := 0.0
	var skin := Color.TRANSPARENT
	var skin_amount := 0.0
	var shiver := 0
	var wd := sqrt(K - D * D * 0.25)
	for h: Dictionary in hits:
		var age: float = clock - float(h.t)
		if age < 0.0:
			continue
		# 受到冲量后的阻尼振动：往来势的方向仰，再来回摆几下停住
		lean += float(h.push) / wd * exp(-D * 0.5 * age) * sin(wd * age) * float(h.dir)
		if age < FLASH:
			flash = 1.0
		elif age < FLASH + FLASH_TAIL:
			flash = maxf(flash, 0.5)
		var s: Array = SKINS.get(h.element, [])
		if not s.is_empty():
			var k: float = float(s[1]) * (1.0 - smoothstep(0.1, float(s[2]), age))
			if k > skin_amount:
				skin = s[0]
				skin_amount = k
		if h.element == "ice" and age < SHIVER:
			shiver = 1 if int(age * 30.0) % 2 == 0 else -1
	lean = clampf(lean, -0.4, 0.42)
	_image.fill(Color.TRANSPARENT)
	var tan_lean := tan(lean)
	for r in H:
		var shift := roundi((H - 1 - r) * tan_lean * 0.8) + shiver
		for x in W:
			var c := _base[r * W + x]
			if c.a == 0.0:
				continue
			if skin_amount > 0.0:
				c = c.lerp(skin, skin_amount)
			if flash > 0.0:
				c = c.lerp(Color.WHITE, flash)
			var px := MARGIN + x + shift
			if px >= 0 and px < CW:
				_image.set_pixel(px, MARGIN + r, c)
	_draw_straw()
	_texture.update(_image)


## 每次命中飞出几根稻草：多数顺着来势往后上方飞，在空中慢慢飘、闪烁着消失
func _draw_straw() -> void:
	for n in hits.size():
		var h: Dictionary = hits[n]
		# 闪白过后才飞出来（闪白的剪影里不要有黄点）
		var age: float = clock - float(h.t) - FLASH
		if age < 0.0 or age > 1.3:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = 9173 + n * 101
		for k in 9:
			var back := rng.randf() < 0.3
			var vx := (rng.randf_range(-50.0, -5.0) if back else rng.randf_range(10.0, 110.0)) * float(h.dir)
			var vy := rng.randf_range(-110.0, -20.0)
			var life := rng.randf_range(0.7, 1.3)
			var big := rng.randf() < 0.5
			var x0 := W * 0.5 + rng.randf_range(-4.0, 4.0)
			var y0 := 27.0 + rng.randf_range(-4.0, 4.0)
			if age > life:
				continue
			# 线性阻力 + 很小的重力：稻草轻，飞出去很快就慢下来往下飘
			var drag := 3.0
			var f := (1.0 - exp(-drag * age)) / drag
			var x := x0 + vx * f + sin(age * 9.0 + k) * 1.5
			var y := y0 + vy * f + 60.0 / drag * (age - f)
			var tone := Color(STRAW_COLORS[mini(4, int(age / life * 5.0))])
			if age > life * 0.7 and int(age * 30.0 + k) % 2 == 0:
				continue
			for i in (2 if big else 1):
				var px := MARGIN + roundi(x) + i
				var py := MARGIN + roundi(y)
				if px >= 0 and px < CW and py >= 0 and py < CH:
					_image.set_pixel(px, py, tone)


# ---------- 造型 ----------

## 画出稻草人（W × H，左上为原点），返回每个像素的颜色
static func _paint() -> PackedColorArray:
	var c := {
		"wood": Color("724c2e"), "woodL": Color("a0703a"), "woodD": Color("4e331f"),
		"straw": Color("d2aa55"), "strawL": Color("f0d98a"), "strawD": Color("9a7a36"),
		"burlap": Color("b38b57"), "burlapL": Color("c9a26c"), "burlapD": Color("86643a"), "burlapDD": Color("6a4c2c"),
		"red": Color("9a2f3c"), "redL": Color("c4434f"), "patch": Color("6f7f52"), "patchD": Color("53603c"),
		"band": Color("8a2f2a"), "ink": Color("1e1420"),
	}
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# 木桩：脚下一直到肩
	_rect(img, 18, 20, 4, 36, c.wood)
	_rect(img, 18, 20, 1, 36, c.woodL)
	_rect(img, 21, 20, 1, 36, c.woodD)
	for y in [30, 39, 47]:
		_put(img, 19, y, c.woodD)
		_put(img, 20, y + 1, c.woodD)
	# 横杆（手臂），两头露出稻草
	_rect(img, 3, 22, 34, 3, c.wood)
	_rect(img, 3, 22, 34, 1, c.woodL)
	_rect(img, 3, 24, 34, 1, c.woodD)
	for side: int in [-1, 1]:
		var bx := 2 if side < 0 else 37
		for d: Array in [[0, -2, "strawL"], [0, -1, "straw"], [0, 0, "straw"], [0, 1, "straw"], [0, 2, "strawD"], [0, 3, "straw"],
				[side, -1, "strawL"], [side, 1, "straw"], [side, 3, "strawD"], [side * 2, 0, "straw"], [side * 2, 2, "strawL"], [side * 2, -2, "strawD"]]:
			_put(img, bx + d[0], 23 + d[1], c[d[2]])
	# 麻袋上衣：左上受光，右边和下摆暗；织纹
	_rect(img, 9, 19, 22, 23, c.burlap)
	_rect(img, 9, 19, 22, 1, c.burlapL)
	_rect(img, 9, 19, 1, 22, c.burlapL)
	_rect(img, 27, 20, 4, 22, c.burlapD)
	_rect(img, 9, 39, 22, 3, c.burlapD)
	for y in range(21, 38, 3):
		for x in range(11 + (y % 2), 27, 4):
			_put(img, x, y, c.burlapD)
	# 袖子：横杆外面包一段麻袋
	for side: int in [-1, 1]:
		var sx := 4 if side < 0 else 31
		_rect(img, sx, 21, 5, 5, c.burlap)
		_rect(img, sx, 21, 5, 1, c.burlapL)
		_rect(img, sx, 25, 5, 1, c.burlapD)
		_put(img, sx + (4 if side < 0 else 0), 23, c.burlapDD)
	# 右下的补丁（缝线是深色点）
	_rect(img, 23, 30, 6, 6, c.patch)
	_rect(img, 23, 35, 6, 1, c.patchD)
	for i in range(23, 29, 2):
		_put(img, i, 29, c.ink)
		_put(img, i + 1, 36, c.ink)
	# 胸口的红色靶环
	for y in range(20, 36):
		for x in range(10, 28):
			var d := Vector2(x - 17.5, y - 27.5).length()
			if (d > 4.2 and d < 5.6) or d < 1.9:
				_put(img, x, y, c.redL if x + y < 45 else c.red)
	# 系绳腰带和绳结，下摆露出稻草
	for x in range(9, 31):
		_put(img, x, 37, c.strawL if x % 2 == 1 else c.straw)
		_put(img, x, 38, c.strawD if x % 2 == 1 else c.burlapD)
	_rect(img, 14, 37, 2, 3, c.straw)
	_put(img, 13, 40, c.strawD)
	_put(img, 16, 41, c.strawD)
	for d: Array in [[10, 42, "straw"], [11, 43, "strawL"], [13, 42, "straw"], [14, 44, "strawD"], [16, 42, "strawL"], [24, 42, "straw"],
			[25, 43, "strawL"], [27, 42, "straw"], [28, 44, "strawD"], [29, 42, "strawL"], [12, 45, "strawD"], [26, 45, "straw"]]:
		_put(img, d[0], d[1], c[d[2]])
	# 麻袋头：圆一点的方块，左上受光
	_rect(img, 12, 7, 16, 12, c.burlap)
	_rect(img, 13, 6, 14, 1, c.burlap)
	_rect(img, 12, 7, 1, 11, c.burlapL)
	_rect(img, 13, 6, 13, 1, c.burlapL)
	_rect(img, 25, 7, 3, 12, c.burlapD)
	_rect(img, 13, 18, 14, 1, c.burlapD)
	# 缝的 X 眼睛和笑嘴
	for ex: int in [16, 23]:
		for d in range(-1, 2):
			_put(img, ex + d, 11 + d, c.ink)
			_put(img, ex - d, 11 + d, c.ink)
	for x in range(15, 25):
		_put(img, x, 15 + (1 if x > 16 and x < 23 else 0), c.ink if x % 2 == 0 else c.burlapDD)
	for x: int in [16, 19, 22]:
		_put(img, x, 14 + (1 if x == 19 else 0), c.ink)
	# 脖子上的绳子
	for x in range(13, 27):
		_put(img, x, 19, c.strawL if x % 2 == 0 else c.straw)
	_put(img, 25, 20, c.straw)
	_put(img, 26, 21, c.strawD)
	# 帽檐下露出来的稻草头发
	for d: Array in [[10, 8, "straw"], [11, 9, "strawL"], [10, 10, "strawD"], [29, 8, "straw"], [28, 9, "strawL"], [29, 10, "strawD"]]:
		_put(img, d[0], d[1], c[d[2]])
	# 草帽：宽帽檐、帽顶、红色帽带
	_rect(img, 5, 6, 30, 2, c.straw)
	_rect(img, 6, 6, 28, 1, c.strawL)
	_rect(img, 7, 8, 26, 1, c.strawD)
	_rect(img, 13, 1, 14, 5, c.straw)
	_rect(img, 14, 0, 12, 1, c.straw)
	_rect(img, 13, 1, 2, 4, c.strawL)
	_rect(img, 24, 1, 3, 4, c.strawD)
	_rect(img, 13, 4, 14, 2, c.band)
	for x in range(6, 34, 3):
		_put(img, x, 7, c.strawD)
	for x in range(15, 25, 3):
		_put(img, x, 2, c.strawD)
	# 外轮廓：贴着身体的空像素描深色
	var out := PackedColorArray()
	out.resize(W * H)
	for y in H:
		for x in W:
			var col := img.get_pixel(x, y)
			if col.a == 0.0:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx := x + d.x
					var ny := y + d.y
					if nx >= 0 and ny >= 0 and nx < W and ny < H and img.get_pixel(nx, ny).a > 0.0:
						col = c.ink
						break
			out[y * W + x] = col
	return out


static func _put(img: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, col)


static func _rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for j in h:
		for i in w:
			_put(img, x + i, y + j, col)
