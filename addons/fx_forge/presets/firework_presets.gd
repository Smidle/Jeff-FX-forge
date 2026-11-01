@tool
extends RefCounted
## 烟花系预设（非战斗 · 演出与系统 · 烟花，来源归「pixelfx 升级版」），照 pixelfx 的烟花做法。
## 每一款按「绽放方式」区分、命名；颜色只是色板，换「配色主题」或色板即可（所以牡丹、菊花、变色牡丹合成了「球形绽放」）。
## 共同的做法：
## 礼花弹拖着金色火星和一缕淡烟升空、越升越慢，在高处炸开：白闪和八道光芒，夜空被照亮一下；
## 星点按球面炸开（侧面看，朝镜头和背向镜头飞的星点显得慢，所以是一个实心的球），每颗拖着 1 像素的尾迹，
## 先烧成金色再变成本色——色板从暗到亮排成「本色……金……白」，星点冷却时依次走过；
## 边飞边受阻力减速、受重力下坠，最后闪烁、噼啪碎成小点熄灭；炸点留一团淡烟，闪粉悬在空中闪烁、慢慢落下。
## 原点在发射点（地面）。参数按「秒」和「像素 / 秒」写，在 _particles() 里换算成图层时长的比例。

const FxPixelFont := preload("../core/fx_pixel_font.gd")

const FPS := 20
## 炸点离地高度（像素）
const RISE := 150.0
## 礼花弹升空用时（秒）
const CLIMB := 0.58

## 色板（暗 → 亮）：本色在下，金色和白在上
const MAGENTA := ["3d0a33", "701560", "b0228f", "f53cd1", "ff86e6", "ffcf6a", "fff3c4", "ffffff"]
const GOLD := ["4a1e08", "86400c", "c47012", "f0a424", "ffd45a", "ffeea0", "fffbe0", "ffffff"]
const CYAN := ["06202e", "0b4a63", "137f9a", "2ac2d6", "7ff0f0", "ffe08a", "fffbe0", "ffffff"]
const GREEN := ["0d2412", "17501f", "24872f", "3fc94a", "9af07a", "ffe08a", "fffbe0", "ffffff"]
const VIOLET := ["150a38", "321888", "5a38d4", "9278ff", "d0c2ff", "ffe08a", "fffbe0", "ffffff"]
const RED := ["2c0610", "6a0f1c", "b0182a", "f0303c", "ff8a7a", "ffd27a", "fff3d0", "ffffff"]
const SILVER := ["1a1c2c", "3a4560", "6f86a6", "b4c8de", "e6eef8", "ffffff"]
const YELLOW := ["3a2604", "7a5408", "c08a10", "f5c21c", "ffe45a", "fff3a0", "fffbe0", "ffffff"]
## 文字烟花排的字
const TEXT := "Jeff Studio"
## 炸开后的淡烟：偏紫的夜空灰
const HAZE := ["14121e", "262234", "3e3850", "5c566e", "8a849c"]


static func defs() -> Array:
	return [_sphere(), _willow(), _palm(), _ring(), _saturn(), _crossette(), _multibreak(), _crackle(), _strobe(),
		_heart(), _star(), _smile(), _text(), _fountain(), _fan(), _waterfall()]


static func _ramp(hexes: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for h: String in hexes:
		out.append(Color(h))
	return out


static func _globals(total: float, main: Array, accent: Array, w: int = 176, h: int = 240, fps: int = FPS) -> Dictionary:
	return {"canvas_w": w, "canvas_h": h, "frames": roundi(total * fps), "fps": fps, "origin_x": 0.5, "origin_y": 1.0 - 12.0 / h,
		"outline": "none", "alpha_levels": 4, "theme": "custom",
		"palette_main": _ramp(main), "palette_accent": _ramp(accent), "palette_smoke": _ramp(HAZE)}


static func _def(id: String, name: String, desc: String, total: float, main: Array, accent: Array, layers: Array, w: int = 176, h: int = 240, fps: int = FPS) -> Dictionary:
	return {"id": id, "name": name, "category": "env", "description": desc, "globals": _globals(total, main, accent, w, h, fps), "layers": layers}


## 一个粒子图层，从 t0 秒到 t1 秒。p 里按秒写：life / emit_time / trail（秒）、speed / split_speed（像素/秒）、
## drag（每秒）、gravity（像素/秒²），这里换算成图层时长的比例
static func _particles(name: String, slot: String, t0: float, t1: float, total: float, p: Dictionary, layer: Dictionary = {}) -> Dictionary:
	var span := t1 - t0
	var q := p.duplicate()
	for key: String in ["life", "emit_time", "trail"]:
		if q.has(key):
			q[key] = float(q[key]) / span
	for key: String in ["speed", "split_speed", "drag"]:
		if q.has(key):
			q[key] = float(q[key]) * span
	if q.has("gravity"):
		q["gravity"] = float(q["gravity"]) * span * span
	var l := {"module": "particles", "name": name, "palette_slot": slot, "follow_dir": false, "outline": false,
		"t_start": t0 / total, "t_end": minf(t1 / total, 1.0), "params": q}
	l.merge(layer, true)
	return l


## 礼花弹升空：从 (x, 0) 升到 (x, -height)，升空用时 climb 秒，t0 秒发射
static func _rocket(total: float, t0: float = 0.0, x: float = 0.0, height: float = RISE, climb: float = CLIMB) -> Array:
	return [
		_particles("升空淡烟", "smoke", t0, t0 + climb + 1.4, total, {
			"count": 12, "shape": "puff", "size": 4.0, "size_end": 2.2, "size_random": 0.4, "spread": 40.0, "speed": 6.0,
			"speed_random": 0.5, "gravity": -6.0, "drag": 1.0, "emit_mode": "stream", "emit_time": climb, "emit_rise": height,
			"life": 1.2, "life_random": 0.3, "bright": 0.9, "cool": 0.2, "opacity": 0.4, "thin": 0.8, "soft_edge": 0.8},
			{"angle_offset": 90.0, "offset_x": x, "dissolve": "translucent"}),
		_particles("升空火星", "accent", t0, t0 + climb + 0.5, total, {
			"count": 30, "shape": "pixel", "size": 1.0, "size_end": 1.0, "spread": 80.0, "speed": 45.0, "speed_random": 0.6,
			"gravity": 160.0, "drag": 2.0, "emit_mode": "stream", "emit_time": climb, "emit_rise": height, "emit_head": true,
			"life": 0.35, "life_random": 0.5, "cool": 0.8, "glow": 0.45, "glow_size": 4.0},
			{"angle_offset": 90.0, "offset_x": x}),
	]


## 炸开：白闪和八道光芒，加照亮夜空的光
static func _flash(total: float, t: float, x: float = 0.0, y: float = -RISE, size: float = 28.0, slot: String = "main") -> Array:
	return [
		{"module": "burst", "name": "炸开光芒", "palette_slot": slot, "outline": false, "follow_dir": false, "offset_x": x, "offset_y": y,
			"t_start": t / total, "t_end": (t + 0.3) / total, "params": {
			"rays": 8, "length": size, "width": 1.5, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.6, "inner": 0.0,
			"easing": "out_expo", "ray_time": 0.9, "detach": 0.55, "flash": "star", "flash_size": 5.0, "flash_time": 0.3,
			"light": 0.6, "light_size": 36.0}},
		{"module": "light", "name": "夜空照亮", "palette_slot": slot, "offset_x": x, "offset_y": y,
			"t_start": t / total, "t_end": minf((t + 1.5) / total, 1.0), "params": {"radius": 80.0, "strength": 0.45, "tone": 0.6}},
	]


## 炸点留下的一团淡烟
static func _smoke(total: float, t: float, x: float = 0.0, y: float = -RISE) -> Dictionary:
	return _particles("炸点淡烟", "smoke", t, total, total, {
		"count": 7, "shape": "smoke", "size": 13.0, "size_end": 1.8, "size_random": 0.4, "emit_shape": "circle", "emit_radius": 7.0,
		"spread": 360.0, "speed": 22.0, "speed_random": 0.6, "gravity": -5.0, "drag": 1.2, "emit_time": 0.1,
		"life": minf(2.4, total - t), "life_random": 0.2, "bright": 0.9, "cool": 0.2, "opacity": 0.3, "thin": 0.8, "soft_edge": 0.8},
		{"offset_x": x, "offset_y": y, "dissolve": "translucent"})


## 闪粉：炸开后悬在星点之间，一闪一闪地慢慢落下
static func _glitter(total: float, t: float, radius: float, slot: String = "accent", x: float = 0.0, y: float = -RISE, count: int = 26) -> Dictionary:
	return _particles("闪粉", slot, t + 0.2, total, total, {
		"count": count, "shape": "star", "size": 2.0, "size_end": 0.5, "emit_shape": "circle", "emit_radius": radius,
		"spread": 360.0, "speed": 6.0, "gravity": 22.0, "drag": 2.0, "emit_mode": "stream", "emit_time": minf(1.4, total - t - 0.6),
		"life": 0.45, "life_random": 0.4, "cool": 0.0, "flicker": 0.5, "glow": 0.3, "glow_size": 4.0},
		{"offset_x": x, "offset_y": y})


## 一层星点：默认是球面炸开、拖尾、先金后本色、末尾闪烁并噼啪碎成两点
static func _shell(name: String, slot: String, total: float, t: float, p: Dictionary, x: float = 0.0, y: float = -RISE) -> Dictionary:
	var q := {"count": 60, "shape": "pixel", "size": 1.5, "size_end": 1.0, "size_random": 0.3, "sphere": true, "spread": 360.0,
		"speed": 170.0, "speed_random": 0.08, "drag": 2.6, "gravity": 90.0, "emit_time": 0.02, "life": 1.6, "life_random": 0.25,
		"cool": 0.85, "trail": 0.3, "flicker": 0.6, "flicker_from": 0.72, "glow": 0.45, "glow_size": 5.0, "glow_tone": 0.7,
		"split": 2, "split_at": 0.93, "split_speed": 18.0, "split_life": 0.6}
	q.merge(p, true)
	if q["split"] == 0:
		for key: String in ["split_at", "split_speed", "split_life"]:
			q.erase(key)
	return _particles(name, slot, t, total, total, q, {"offset_x": x, "offset_y": y})


# ---------------------------------------------------------------- 各款烟花

static func _sphere() -> Dictionary:
	var total := 3.3
	var t := CLIMB
	return _def("firework_sphere", "烟花·球形绽放", "星点从炸点按球面均匀炸开，是一个实心的球（侧面看，朝镜头和背向镜头飞的星点显得慢），拖着尾迹先金后本色、下坠闪烁，噼啪碎成小点熄灭；中心一圈金色小星。尾迹调成 0 是点状的「牡丹」，调长是拖尾的「菊花」；把色板从暗到亮排成想要的变色顺序就是「变色牡丹」。原点在发射点（地面）。",
		total, MAGENTA, GOLD,
		[_smoke(total, t), _glitter(total, t, 50.0)] + _rocket(total) + [
			_shell("球形星点", "main", total, t, {"count": 64, "speed": 180.0, "life": 1.8, "trail": 0.35}),
			_shell("金色内芯", "accent", total, t, {"count": 24, "speed": 85.0, "life": 1.1, "trail": 0.15, "cool": 0.7, "split": 0}),
		] + _flash(total, t))


static func _willow() -> Dictionary:
	var total := 4.4
	var t := CLIMB
	return _def("firework_willow", "烟花·垂柳绽放", "星点炸开后很快慢下来，拖着又长又亮的金色尾迹缓缓垂落，像柳条一样挂满夜空，最后闪着金粉熄灭。原点在发射点（地面）。",
		total, GOLD, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("柳条", "main", total, t, {"count": 56, "speed": 150.0, "drag": 1.9, "gravity": 70.0, "life": 3.2, "life_random": 0.15,
				"trail": 1.2, "cool": 0.6, "glow": 0.35, "split": 0, "flicker": 0.3, "flicker_from": 0.85}),
			_glitter(total, t + 0.6, 55.0, "accent", 0.0, -RISE + 25.0, 36),
		] + _flash(total, t, 0.0, -RISE, 22.0, "accent"))


static func _palm() -> Dictionary:
	var total := 3.4
	var t := CLIMB
	return _def("firework_palm", "烟花·棕榈绽放", "只炸出九道粗大的彗星，拖着重尾向外弯垂，像棕榈的枝叶，枝头碎成闪粉；中心一簇金色小星。原点在发射点（地面）。",
		total, RED, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("棕榈枝", "main", total, t, {"count": 9, "shape": "disc", "size": 3.5, "size_end": 1.6, "size_random": 0.2, "sphere": false,
				"speed": 175.0, "speed_random": 0.12, "gravity": 120.0, "life": 1.9, "life_random": 0.1, "trail": 0.75, "cool": 0.7,
				"glow": 0.6, "glow_size": 7.0, "split": 3, "split_at": 0.8, "split_speed": 22.0, "split_life": 0.7, "flicker": 0.3}),
			_shell("金色内芯", "accent", total, t, {"count": 18, "speed": 70.0, "life": 1.0, "trail": 0.12, "cool": 0.7, "split": 0}),
		] + _flash(total, t))


static func _ring() -> Dictionary:
	var total := 3.2
	var t := CLIMB
	return _def("firework_ring", "烟花·圆环绽放", "星点整齐地排成一圈向外扩张，略带俯视的倾斜光环，中间一小团银白星芒。原点在发射点（地面）。",
		total, CYAN, SILVER,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("光环", "main", total, t, {"count": 48, "sphere": false, "emit_shape": "ring", "emit_radius": 2.0, "squash": 0.42,
				"speed": 175.0, "speed_random": 0.0, "gravity": 60.0, "life": 1.7, "life_random": 0.1, "trail": 0.25, "split": 0}),
			_shell("银芯", "accent", total, t, {"count": 20, "speed": 55.0, "life": 1.0, "trail": 0.1, "cool": 0.6, "split": 0}),
		] + _flash(total, t))


static func _saturn() -> Dictionary:
	var total := 3.4
	var t := CLIMB
	return _def("firework_saturn", "烟花·土星绽放", "中间炸成一个紫色的小球，外面同时飞出一圈压扁的金色光环，像一颗土星；光环比球飞得远，最后都闪烁着落下。原点在发射点（地面）。",
		total, VIOLET, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("星球", "main", total, t, {"count": 56, "speed": 110.0, "life": 1.6, "trail": 0.18, "split": 0, "flicker": 0.4, "flicker_from": 0.8}),
			_shell("光环", "accent", total, t, {"count": 44, "sphere": false, "emit_shape": "ring", "emit_radius": 2.0, "squash": 0.26,
				"speed": 210.0, "speed_random": 0.0, "gravity": 50.0, "life": 1.8, "life_random": 0.08, "trail": 0.22, "cool": 0.6, "split": 0}),
		] + _flash(total, t))


static func _crossette() -> Dictionary:
	var total := 3.4
	var t := CLIMB
	return _def("firework_crossette", "烟花·十字分裂绽放", "炸开的十几颗大星飞到一半，每颗又裂成四颗呈十字散开，满天交错的绿色光迹。原点在发射点（地面）。",
		total, GREEN, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("十字星", "main", total, t, {"count": 14, "size": 2.0, "speed": 140.0, "life": 1.9, "life_random": 0.1, "trail": 0.25,
				"cool": 0.75, "split": 4, "split_at": 0.32, "split_speed": 75.0, "split_life": 1.0, "flicker": 0.4, "flicker_from": 0.8}),
		] + _flash(total, t))


static func _multibreak() -> Dictionary:
	var total := 3.6
	var t := CLIMB
	return _def("firework_multibreak", "烟花·千轮绽放", "炸开时只撒出十来颗小子弹，飞出一小段后几乎同时各自炸成一朵八瓣的小花：满天十几朵小圆花一齐开放，再一齐闪烁着凋谢。原点在发射点（地面）。",
		total, CYAN, MAGENTA,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("小花", "main", total, t, {"count": 13, "size": 1.0, "speed": 150.0, "speed_random": 0.25, "drag": 2.8, "gravity": 40.0,
				"life": 2.2, "life_random": 0.05, "bright": 0.75, "cool": 0.6, "trail": 0.0, "glow": 0.5, "glow_size": 7.0,
				"split": 8, "split_at": 0.3, "split_speed": 34.0, "split_life": 1.0, "flicker": 0.5, "flicker_from": 0.75}),
		] + _flash(total, t, 0.0, -RISE, 16.0))


static func _crackle() -> Dictionary:
	var total := 3.2
	var t := CLIMB
	return _def("firework_crackle", "烟花·碎裂绽放", "银白的星点炸开后很快碎成一片噼啪作响的小闪点，此起彼伏地闪灭，满天碎银。原点在发射点（地面）。",
		total, SILVER, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("碎银", "main", total, t, {"count": 46, "speed": 150.0, "life": 1.7, "trail": 0.18, "cool": 0.5,
				"split": 3, "split_at": 0.45, "split_speed": 24.0, "split_life": 0.45, "flicker": 0.7, "flicker_from": 0.3}),
			_glitter(total, t + 0.3, 60.0, "main", 0.0, -RISE, 40),
		] + _flash(total, t, 0.0, -RISE, 24.0))


static func _strobe() -> Dictionary:
	var total := 3.8
	var t := CLIMB
	return _def("firework_strobe", "烟花·频闪绽放", "星点炸开后很快停在空中，不拖尾，每颗以不同的节奏飞快地明灭，像一片闪个不停的白色星海，慢慢往下沉。原点在发射点（地面）。",
		total, SILVER, SILVER,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("频闪星", "main", total, t, {"count": 70, "size": 2.0, "size_end": 1.0, "speed": 165.0, "speed_random": 0.25, "drag": 3.6,
				"gravity": 22.0, "life": 2.8, "life_random": 0.2, "cool": 0.15, "trail": 0.0, "glow": 0.35, "glow_size": 4.0,
				"split": 0, "flicker": 0.95, "flicker_from": 0.1, "flicker_rate": 18.0}),
		] + _flash(total, t, 0.0, -RISE, 24.0))


static func _heart() -> Dictionary:
	var total := 3.2
	var t := CLIMB
	return _def("firework_heart", "烟花·心形绽放", "星点排成一颗红心向外扩张，保持形状慢慢下坠、闪烁熄灭，外面散着几点粉色闪粉。原点在发射点（地面）。",
		total, RED, MAGENTA,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("红心", "main", total, t, {"count": 60, "sphere": false, "emit_shape": "heart", "speed": 95.0, "speed_random": 0.0,
				"gravity": 35.0, "life": 1.8, "life_random": 0.05, "trail": 0.2, "split": 0, "flicker": 0.4, "flicker_from": 0.82}),
			_glitter(total, t + 0.3, 50.0, "accent", 0.0, -RISE, 18),
		] + _flash(total, t, 0.0, -RISE, 20.0))


static func _star() -> Dictionary:
	var total := 3.2
	var t := CLIMB
	return _def("firework_star", "烟花·星形绽放", "星点沿五角星的轮廓排开向外扩张，金色的五角星保持形状慢慢下坠，金粉缓缓落下。原点在发射点（地面）。",
		total, GOLD, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("金星", "main", total, t, {"count": 70, "sphere": false, "emit_shape": "star", "speed": 105.0, "speed_random": 0.0,
				"gravity": 35.0, "life": 1.8, "life_random": 0.05, "trail": 0.2, "cool": 0.6, "split": 0, "flicker": 0.4, "flicker_from": 0.82}),
			_glitter(total, t + 0.3, 45.0, "accent", 0.0, -RISE, 20),
		] + _flash(total, t, 0.0, -RISE, 22.0, "accent"))


static func _smile() -> Dictionary:
	var total := 3.2
	var t := CLIMB
	return _def("firework_smile", "烟花·笑脸绽放", "星点排成一张黄色的笑脸：圆脸、两只眼睛和一道弯弯的嘴，向外扩张后保持形状下坠、闪烁熄灭。原点在发射点（地面）。",
		total, YELLOW, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_shell("笑脸", "main", total, t, {"count": 78, "sphere": false, "emit_shape": "smile", "speed": 100.0, "speed_random": 0.0,
				"gravity": 35.0, "life": 1.8, "life_random": 0.05, "trail": 0.15, "cool": 0.6, "split": 0, "flicker": 0.4, "flicker_from": 0.82}),
		] + _flash(total, t, 0.0, -RISE, 20.0, "accent"))


## 文字：炸开后星点排成一行字，在空中停约 9 秒，由白金慢慢变成本色，闪烁着缓缓下沉，最后噼啪碎成小点熄灭。
## 一个图层的参数按图层时长换算，阻力有上限，不能既在 1 秒内炸开成字、又活 9 秒，所以分两层接力：
## 「字形展开」从炸点按字形飞出、迅速减速，到这一层结束正好停在字的位置；「字形停留」在同一位置接着出现。
## 帧数上限 128，要停 10 秒左右，这一款按每秒 12 帧做
static func _text() -> Dictionary:
	var fps := 12
	var total := 128.0 / fps
	var t := CLIMB
	var bloom := 0.9
	var stay := total - t - bloom
	# 字的半宽（像素）；展开层的阻力（整层时长内）和这时走完全程的比例
	var half := 150.0
	var k := 6.0
	var reach := 1.0 - exp(-k)
	var count := mini(FxPixelFont.points(TEXT).size(), 300)
	return _def("firework_text", "烟花·文字绽放", "星点从炸点按字形炸开，排成一行「Jeff Studio」停在空中约 9 秒：由白金慢慢变成粉色，一闪一闪地缓缓下沉，周围飘着金色闪粉，最后噼啪碎成小点熄灭。要排别的字，改两层星点的「文字」（英文字母、数字和常用符号）。原点在发射点（地面）。",
		total, MAGENTA, GOLD,
		[_smoke(total, t)] + _rocket(total) + [
			_particles("字形展开", "main", t, t + bloom, total, {
				"count": count, "shape": "square", "size": 3.0, "size_end": 1.0, "size_random": 0.0, "emit_shape": "text", "text": TEXT,
				"emit_radius": 0.0, "speed": half * k / reach / bloom, "speed_random": 0.0, "drag": k / bloom, "gravity": 0.0,
				"emit_time": 0.01, "life": bloom, "life_random": 0.0, "cool": 0.0, "trail": 0.12, "fade_from": 1.0,
				"glow": 0.45, "glow_size": 5.0, "glow_tone": 0.7},
				{"offset_y": -RISE}),
			_particles("字形停留", "main", t + bloom, total, total, {
				"count": count, "shape": "square", "size": 3.0, "size_end": 1.0, "size_random": 0.0, "emit_shape": "text", "text": TEXT,
				"emit_radius": half, "speed": 0.0, "speed_random": 0.0, "drag": 1.0, "gravity": 2.0,
				"emit_time": 0.01, "life": stay - 0.2, "life_random": 0.06, "cool": 0.35, "fade_from": 0.9,
				"flicker": 0.3, "flicker_from": 0.0, "flicker_rate": 20.0, "glow": 0.4, "glow_size": 4.0, "glow_tone": 0.7,
				"split": 2, "split_at": 0.95, "split_speed": 14.0, "split_life": 0.6},
				{"offset_y": -RISE}),
			_particles("闪粉", "accent", t + bloom, total - 0.6, total, {
				"count": 46, "shape": "star", "size": 2.0, "size_end": 0.5, "emit_shape": "box", "emit_radius": half + 8.0, "emit_height": 44.0,
				"spread": 360.0, "speed": 4.0, "gravity": 14.0, "drag": 2.0, "emit_mode": "stream", "emit_time": stay - 1.4,
				"life": 0.6, "life_random": 0.4, "cool": 0.0, "flicker": 0.5, "glow": 0.3, "glow_size": 4.0},
				{"offset_y": -RISE}),
		] + _flash(total, t, 0.0, -RISE, 26.0), 352, 240, fps)


static func _fountain() -> Dictionary:
	var total := 1.2
	var d := _def("firework_fountain", "烟花·地面喷泉", "不升空，从地上的喷口循环往上喷：金色火花不停地喷起一人多高，带着短短的尾迹落回地面，底部一团白热的光。原点在喷口（地面）。",
		total, GOLD, GOLD, [
			_particles("喷泉火花", "main", 0.0, total, total, {
				"count": 60, "shape": "pixel", "size": 1.5, "size_end": 1.0, "spread": 34.0, "speed": 210.0, "speed_random": 0.35,
				"gravity": 320.0, "drag": 0.8, "emit_mode": "stream", "emit_time": total, "life": 0.95, "life_random": 0.35,
				"cool": 0.8, "trail": 0.08, "glow": 0.4, "glow_size": 4.0, "flicker": 0.3, "flicker_from": 0.7}, {"angle_offset": 270.0}),
			_particles("火星", "accent", 0.0, total, total, {
				"count": 24, "shape": "pixel", "size": 1.0, "size_end": 1.0, "spread": 90.0, "speed": 120.0, "speed_random": 0.6,
				"gravity": 260.0, "drag": 1.5, "emit_mode": "stream", "emit_time": total, "life": 0.6, "life_random": 0.4,
				"cool": 0.9, "flicker": 0.5}, {"angle_offset": 270.0}),
			{"module": "light", "name": "喷口白光", "palette_slot": "main", "follow_dir": false, "params": {
				"radius": 30.0, "strength": 0.55, "tone": 0.85, "attack": 0.5, "flicker": 0.4}},
		], 96, 128)
	d["globals"]["loop"] = true
	return d


static func _fan() -> Dictionary:
	var total := 2.6
	var w := 208
	var h := 200
	var layers: Array = []
	# 三轮齐射：[发射时刻, 色板]，每轮七颗彗星呈扇形冲上天，到顶后碎成三点
	var volleys := [[0.0, "main"], [0.4, "accent"], [0.8, "main"]]
	for v: Array in volleys:
		var t0: float = v[0]
		layers.append(_particles("齐射彗星", v[1], t0, total, total, {
			"count": 7, "shape": "disc", "size": 2.5, "size_end": 1.0, "size_random": 0.2, "spread": 76.0, "speed": 300.0,
			"speed_random": 0.12, "gravity": 140.0, "drag": 0.9, "emit_time": 0.03, "life": 1.15, "life_random": 0.1,
			"cool": 0.7, "trail": 0.3, "glow": 0.5, "glow_size": 5.0, "split": 3, "split_at": 0.82, "split_speed": 20.0,
			"split_life": 0.6, "flicker": 0.4, "flicker_from": 0.8}, {"angle_offset": 270.0}))
		layers.append({"module": "burst", "name": "筒口火光", "palette_slot": "accent", "outline": false, "follow_dir": false,
			"t_start": t0 / total, "t_end": (t0 + 0.25) / total, "params": {
			"rays": 5, "length": 14.0, "width": 1.5, "length_random": 0.3, "angle_random": 0.3, "alternate": 0.5, "inner": 0.0,
			"easing": "out_expo", "ray_time": 0.8, "detach": 0.5, "flash": "star", "flash_size": 4.0, "flash_time": 0.35,
			"light": 0.6, "light_size": 22.0}})
	layers.append(_particles("筒口烟", "smoke", 0.0, total, total, {
		"count": 10, "shape": "puff", "size": 6.0, "size_end": 2.4, "size_random": 0.4, "spread": 50.0, "speed": 30.0,
		"speed_random": 0.5, "gravity": -12.0, "drag": 1.2, "emit_mode": "stream", "emit_time": 1.0, "life": 1.5, "life_random": 0.3,
		"bright": 0.9, "cool": 0.2, "opacity": 0.35, "thin": 0.8, "soft_edge": 0.8}, {"angle_offset": 270.0, "dissolve": "translucent"}))
	return _def("firework_fan", "烟花·扇形齐射", "不升空的礼花筒：从地面一口气射出七颗彗星，排成扇形冲上夜空，到顶后碎成小点熄灭；先后三轮，筒口冒火光和淡烟。原点在筒口（地面）。",
		total, RED, GOLD, layers, w, h)


static func _waterfall() -> Dictionary:
	var total := 1.5
	var w := 224
	var h := 160
	var top := -128.0
	var d := _def("firework_waterfall", "烟花·瀑布垂落", "架在高处的一排喷口同时向下喷火，金色火花拖着长尾像瀑布一样不停地垂落到地面，循环播放（仕挂烟花「尼亚加拉瀑布」）。原点在地面中央，喷口在原点上方 128 像素。",
		total, GOLD, GOLD, [
			_particles("瀑布火花", "main", 0.0, total, total, {
				"count": 150, "shape": "pixel", "size": 1.0, "size_end": 1.0, "emit_shape": "line", "emit_radius": 92.0,
				"spread": 24.0, "speed": 18.0, "speed_random": 0.6, "gravity": 230.0, "drag": 0.4, "emit_mode": "stream",
				"emit_time": total, "life": 1.4, "life_random": 0.3, "cool": 0.75, "trail": 0.35, "glow": 0.2, "glow_size": 3.0,
				"flicker": 0.3, "flicker_from": 0.7, "use_floor": true, "floor_y": -top}, {"angle_offset": 90.0, "offset_y": top}),
			_particles("喷口火星", "accent", 0.0, total, total, {
				"count": 40, "shape": "pixel", "size": 1.0, "size_end": 1.0, "emit_shape": "line", "emit_radius": 92.0,
				"spread": 160.0, "speed": 30.0, "speed_random": 0.6, "gravity": 120.0, "drag": 2.0, "emit_mode": "stream",
				"emit_time": total, "life": 0.4, "life_random": 0.4, "cool": 0.6, "flicker": 0.6}, {"angle_offset": 90.0, "offset_y": top}),
			{"module": "light", "name": "喷口光带", "palette_slot": "main", "follow_dir": false, "offset_y": top, "params": {
				"radius": 100.0, "squash": 0.22, "strength": 0.4, "tone": 0.75, "flicker": 0.3}},
		], w, h)
	d["globals"]["loop"] = true
	return d
