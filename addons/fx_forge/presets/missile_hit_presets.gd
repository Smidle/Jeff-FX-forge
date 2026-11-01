@tool
extends RefCounted
## 飞弹命中系：四款追踪飞弹打中目标时的效果（来源归「pixelfx 升级版」），照 pixelfx 的命中做法：
## 第一帧白闪、炸点一团叠加光；快进慢出，主体之后有冷却、烟和飞散的碎屑收尾。
## 命中发生在被打的角色身上，碎屑和火花在空中飞散后消失，不落到地上弹跳。
## 方向朝右（从左边打过来，碎屑多数顺着来势往右飞）；原点在命中点。
## 飞弹运行时（legacy/runtime/fx_missile_impact.gd）按飞弹的像素密度和「命中范围」缩放，
## 主色板、烟尘色板按飞弹配方的主色换色相；辅色板（白闪、火花）不换。
## 参数按「秒」和「像素 / 秒」写，在 _particles() 里换算成图层时长的比例。

const FPS := 24

## 色板（暗 → 亮）
const SWORD := ["0e2a2e", "1d5458", "3a8e8c", "7cd0c0", "c8f4e8", "ffffff"]
const FROST := ["16263e", "2c4a70", "5a88b4", "a2cfee", "e2f4ff"]
const VOID := ["0c0616", "1e1034", "382058", "5a3a86", "8a68b8"]


static func defs() -> Array:
	return [_fire(), _ice(), _shadow(), _sword()]


static func _ramp(hexes: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for h: String in hexes:
		out.append(Color(h))
	return out


static func _def(id: String, name: String, desc: String, total: float, w: int, h: int, ox: float, oy: float, palettes: Array, layers: Array) -> Dictionary:
	var g := {"canvas_w": w, "canvas_h": h, "frames": roundi(total * FPS), "fps": FPS, "origin_x": ox, "origin_y": oy,
		"alpha_levels": 4, "outline": "none", "theme": "custom"}
	for i in 3:
		var p: Variant = palettes[i]
		g[["palette_main", "palette_accent", "palette_smoke"][i]] = _ramp(p) if p is Array else p
	return {"id": id, "name": name, "category": "combat", "description": desc, "globals": g, "layers": layers}


## 一个粒子图层，从 t0 秒到 t1 秒。p 里按秒写：life / emit_time / trail（秒）、speed（像素/秒）、
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


## 其他模块的图层：只按秒换算起止时刻
static func _layer(module: String, name: String, slot: String, t0: float, t1: float, total: float, params: Dictionary, layer: Dictionary = {}) -> Dictionary:
	var l := {"module": module, "name": name, "palette_slot": slot, "follow_dir": false, "outline": false,
		"t_start": t0 / total, "t_end": minf(t1 / total, 1.0), "params": params}
	l.merge(layer, true)
	return l


# ---------------------------------------------------------------- 各款命中

static func _fire() -> Dictionary:
	var total := 1.0
	return _def("missile_hit_fire", "飞弹命中·火球爆燃",
		"火球打中目标：一帧白闪和冲击环，白热的火球胀开、边翻滚边冷却成暗红，火团顺着来势往前喷，火星飞散后熄灭；余烬往上飘，半透明的烟慢慢升起散开。碎屑不落地。原点在命中点，方向朝右。",
		total, 128, 112, 0.4, 0.56, ["fire", "spark", "smoke"], [
			_particles("烟", "smoke", 0.12, 1.0, total, {
				"count": 16, "shape": "smoke", "size": 9.0, "size_end": 2.2, "size_random": 0.4, "emit_shape": "circle", "emit_radius": 8.0,
				"spread": 120.0, "speed": 40.0, "speed_random": 0.5, "gravity": -60.0, "drag": 1.5, "sway": 3.0,
				"emit_mode": "stream", "emit_time": 0.35, "life": 0.62, "life_random": 0.25, "bright": 1.0, "cool": 0.45,
				"opacity": 0.7, "thin": 0.8, "soft_edge": 0.7},
				{"angle_offset": 270.0, "dissolve": "translucent"}),
			_layer("ring", "冲击环", "accent", 0.0, 0.13, total, {
				"radius": 30.0, "width": 2.0, "thin": 0.9, "start": 0.3, "easing": "out_expo"}),
			_layer("blob", "火球", "main", 0.0, 0.42, total, {
				"puffs": 4, "radius": 13.0, "spread": 6.0, "start": 0.3, "noise": 0.35, "expand_time": 0.25, "rise": 4.0,
				"heat": 1.0, "cool": 0.75, "core": 0.6, "burn": 0.85}),
			_particles("火团", "main", 0.0, 0.55, total, {
				"count": 22, "shape": "puff", "size": 11.0, "size_end": 0.5, "size_random": 0.5, "emit_shape": "circle", "emit_radius": 5.0,
				"spread": 250.0, "speed": 210.0, "speed_random": 0.6, "gravity": -120.0, "drag": 7.0, "emit_time": 0.03,
				"life": 0.45, "life_random": 0.45, "cool": 0.7, "glow": 0.25, "glow_size": 10.0},
				{"outline": true}),
			_particles("火星", "main", 0.0, 0.5, total, {
				"count": 30, "shape": "streak", "size": 2.0, "size_end": 0.7, "spread": 150.0, "speed": 420.0, "speed_random": 0.6,
				"gravity": 380.0, "drag": 3.5, "emit_time": 0.03, "life": 0.42, "life_random": 0.5, "cool": 0.7, "streak_len": 0.5,
				"glow": 0.5, "glow_size": 5.0}),
			_particles("余烬", "main", 0.05, 1.0, total, {
				"count": 16, "shape": "square", "size": 1.2, "size_end": 1.0, "spread": 160.0, "speed": 60.0, "speed_random": 0.6,
				"gravity": -40.0, "drag": 2.0, "sway": 3.0, "emit_mode": "stream", "emit_time": 0.35, "life": 0.55, "life_random": 0.4,
				"cool": 0.7, "flicker": 0.3, "glow": 0.35, "glow_size": 4.0},
				{"angle_offset": 270.0}),
			_layer("burst", "白闪", "accent", 0.0, 0.12, total, {
				"rays": 8, "length": 16.0, "width": 2.0, "length_random": 0.5, "inner": 0.3, "ray_time": 0.35, "detach": 0.8,
				"flash": "disc", "flash_size": 14.0, "flash_time": 0.45, "light": 0.8, "light_size": 34.0}),
			_layer("light", "火光", "main", 0.0, 0.5, total, {"radius": 40.0, "strength": 0.45, "tone": 0.55}),
		])


static func _ice() -> Dictionary:
	var total := 1.0
	return _def("missile_hit_ice", "飞弹命中·冰晶迸裂",
		"冰箭打中目标：一帧白闪和顺着来势的长短十字星芒，炸点裂出细纹、一圈冰环迸开，棱角分明的冰晶碎片翻滚着飞散，冰屑闪光；寒气团慢慢往下沉，雪花闪点在空中闪烁飘落。碎片不落地。原点在命中点，方向朝右。",
		total, 128, 112, 0.42, 0.52, ["ice", "steel", FROST], [
			_particles("寒雾", "smoke", 0.04, 1.0, total, {
				"count": 10, "shape": "smoke", "size": 7.0, "size_end": 2.0, "size_random": 0.4, "emit_shape": "circle", "emit_radius": 6.0,
				"spread": 360.0, "speed": 70.0, "speed_random": 0.5, "gravity": 25.0, "drag": 3.0, "emit_time": 0.1,
				"life": 0.7, "life_random": 0.25, "bright": 1.0, "cool": 0.2, "opacity": 0.45, "thin": 0.8, "soft_edge": 0.8},
				{"dissolve": "translucent"}),
			_layer("ring", "冰环", "main", 0.0, 0.18, total, {
				"radius": 26.0, "width": 2.0, "thin": 0.9, "start": 0.3, "segments": 10, "gap": 0.3, "spin": 0.1,
				"easing": "out_expo", "rim": 0.9}),
			_layer("burst", "裂纹", "main", 0.0, 0.25, total, {
				"rays": 7, "length": 22.0, "width": 1.5, "length_random": 0.5, "angle_random": 0.3, "inner": 0.1,
				"ray_time": 0.6, "detach": 0.0, "flash": "none"}),
			_particles("冰晶碎片", "main", 0.0, 0.75, total, {
				"count": 20, "shape": "shard", "size": 4.5, "size_end": 1.0, "size_random": 0.5, "spread": 220.0, "speed": 300.0,
				"speed_random": 0.55, "gravity": 300.0, "drag": 3.0, "emit_time": 0.02, "life": 0.6, "life_random": 0.4,
				"bright": 1.0, "cool": 0.25, "spin": 2.5, "glow": 0.3, "glow_size": 4.0},
				{"outline": true}),
			_layer("burst", "冰刺", "main", 0.0, 0.3, total, {
				"rays": 6, "length": 18.0, "width": 4.0, "length_random": 0.5, "angle_random": 0.3, "inner": 0.2,
				"ray_time": 0.5, "detach": 0.65, "flash": "none"},
				{"outline": true}),
			_particles("冰屑", "main", 0.0, 0.6, total, {
				"count": 24, "shape": "pixel", "size": 1.0, "size_end": 1.0, "spread": 300.0, "speed": 300.0, "speed_random": 0.6,
				"gravity": 250.0, "drag": 4.0, "emit_time": 0.02, "life": 0.4, "life_random": 0.5, "cool": 0.5, "glow": 0.3, "glow_size": 3.0}),
			_particles("雪花闪点", "accent", 0.1, 1.0, total, {
				"count": 14, "shape": "star", "size": 2.5, "size_end": 0.5, "emit_shape": "circle", "emit_radius": 16.0, "spread": 360.0,
				"speed": 15.0, "gravity": 20.0, "drag": 2.0, "sway": 2.0, "emit_mode": "stream", "emit_time": 0.5,
				"life": 0.45, "life_random": 0.4, "cool": 0.0, "flicker": 0.6, "glow": 0.3, "glow_size": 4.0}),
			_layer("burst", "白闪", "accent", 0.0, 0.14, total, {
				"rays": 4, "length": 20.0, "width": 2.5, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.5, "inner": 0.0,
				"ray_time": 0.5, "detach": 0.3, "flash": "diamond", "flash_size": 12.0, "flash_time": 0.5, "light": 0.8, "light_size": 30.0}),
			_layer("light", "寒光", "main", 0.0, 0.45, total, {"radius": 34.0, "strength": 0.4, "tone": 0.6}),
		])


static func _shadow() -> Dictionary:
	var total := 0.9
	return _def("missile_hit_shadow", "飞弹命中·暗影裂爆",
		"暗影箭打中目标：一帧紫白色的闪光，一颗边缘翻腾着紫焰的黑球胀开、往外喷出紫色火舌，又被噪声蚀出窟窿，发光的碎晶飞散，暗烟往上飘；最后四周的暗絮被吸回中心收拢消失。原点在命中点，方向朝右。",
		total, 120, 112, 0.42, 0.54, ["shadow", "arcane", VOID], [
			_particles("暗烟", "smoke", 0.1, 0.9, total, {
				"count": 14, "shape": "smoke", "size": 9.0, "size_end": 2.0, "size_random": 0.4, "emit_shape": "circle", "emit_radius": 6.0,
				"spread": 200.0, "speed": 50.0, "speed_random": 0.5, "gravity": -40.0, "drag": 2.0, "sway": 4.0,
				"emit_mode": "stream", "emit_time": 0.3, "life": 0.6, "life_random": 0.25, "bright": 1.0, "cool": 0.3,
				"opacity": 0.55, "thin": 0.8, "soft_edge": 0.7},
				{"angle_offset": 270.0, "dissolve": "translucent"}),
			_layer("burst", "白紫闪", "accent", 0.0, 0.15, total, {
				"rays": 6, "length": 18.0, "width": 2.0, "length_random": 0.4, "inner": 0.3, "ray_time": 0.4, "detach": 0.7,
				"flash": "disc", "flash_size": 13.0, "flash_time": 0.5, "light": 0.9, "light_size": 36.0}),
			_layer("blob", "黑球", "smoke", 0.02, 0.5, total, {
				"puffs": 3, "radius": 13.0, "spread": 3.0, "start": 0.5, "noise": 0.3, "expand_time": 0.15, "rise": 0.0,
				"boil": 1.5, "heat": 0.25, "cool": 0.3, "core": 0.0, "burn": 0.9}),
			_layer("ring", "紫焰边", "main", 0.02, 0.5, total, {
				"radius": 16.0, "width": 5.0, "thin": 0.5, "start": 0.55, "easing": "out_cubic", "wobble": 1.0, "rim": 1.0}),
			_particles("紫焰舌", "main", 0.02, 0.45, total, {
				"count": 14, "shape": "puff", "size": 6.0, "size_end": 0.5, "size_random": 0.4, "emit_shape": "ring", "emit_radius": 9.0,
				"spread": 360.0, "speed": 120.0, "speed_random": 0.5, "gravity": -80.0, "drag": 4.0, "emit_time": 0.06,
				"life": 0.35, "life_random": 0.4, "cool": 0.6, "glow": 0.3, "glow_size": 6.0}),
			_particles("碎晶", "main", 0.03, 0.7, total, {
				"count": 12, "shape": "shard", "size": 3.0, "size_end": 1.0, "size_random": 0.4, "spread": 260.0, "speed": 240.0,
				"speed_random": 0.5, "gravity": 150.0, "drag": 3.0, "emit_time": 0.02, "life": 0.5, "life_random": 0.4,
				"bright": 1.0, "cool": 0.4, "spin": 2.0, "glow": 0.3, "glow_size": 4.0},
				{"outline": true}),
			_particles("回吸暗絮", "main", 0.42, 0.9, total, {
				"count": 18, "shape": "pixel", "size": 1.5, "size_end": 1.0, "flow": "gather", "emit_shape": "circle", "emit_radius": 6.0,
				"spread": 360.0, "speed": 90.0, "speed_random": 0.4, "emit_time": 0.1, "life": 0.4, "life_random": 0.3,
				"bright": 1.0, "cool": 0.2, "glow": 0.3, "glow_size": 3.0}),
			_layer("light", "暗光", "main", 0.0, 0.5, total, {"radius": 36.0, "strength": 0.45, "tone": 0.7}),
		])


static func _sword() -> Dictionary:
	var total := 0.6
	return _def("missile_hit_sword", "飞弹命中·剑光星爆",
		"飞剑打中目标：顺着来势的一道长光和菱形白芯的十字星芒，一圈断开的光弧飞出，白黄色的火花和热屑朝前喷、少量往回溅，几点星光闪烁着熄灭。碎屑不落地。原点在命中点，方向朝右。",
		total, 120, 96, 0.4, 0.5, [SWORD, "spark", "smoke"], [
			_layer("ring", "断弧", "main", 0.02, 0.4, total, {
				"radius": 26.0, "width": 2.0, "thin": 0.8, "start": 0.35, "segments": 10, "gap": 0.45, "spin": 0.15, "easing": "out_cubic"}),
			_particles("火花", "accent", 0.0, 0.45, total, {
				"count": 24, "shape": "streak", "size": 2.0, "size_end": 0.7, "spread": 110.0, "speed": 380.0, "speed_random": 0.6,
				"gravity": 300.0, "drag": 3.0, "emit_time": 0.02, "life": 0.35, "life_random": 0.5, "cool": 0.6, "streak_len": 0.6,
				"glow": 0.45, "glow_size": 4.0}),
			_particles("回溅", "accent", 0.0, 0.35, total, {
				"count": 8, "shape": "streak", "size": 1.5, "size_end": 0.7, "spread": 70.0, "speed": 220.0, "speed_random": 0.5,
				"gravity": 200.0, "drag": 3.0, "emit_time": 0.02, "life": 0.25, "life_random": 0.4, "cool": 0.6, "streak_len": 0.5},
				{"angle_offset": 180.0}),
			_particles("热屑", "accent", 0.0, 0.5, total, {
				"count": 10, "shape": "square", "size": 1.5, "size_end": 1.0, "spread": 200.0, "speed": 200.0, "speed_random": 0.6,
				"gravity": 350.0, "drag": 2.5, "emit_time": 0.02, "life": 0.45, "life_random": 0.4, "cool": 0.6, "flicker": 0.3}),
			_layer("burst", "长光", "main", 0.0, 0.2, total, {
				"rays": 2, "length": 40.0, "width": 2.0, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.6, "inner": 0.0,
				"ray_time": 0.7, "detach": 0.5, "flash": "none"}),
			_layer("burst", "十字星芒", "main", 0.0, 0.3, total, {
				"rays": 4, "length": 22.0, "width": 3.0, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.6, "inner": 0.0,
				"ray_time": 0.6, "detach": 0.2, "flash": "diamond", "flash_size": 10.0, "flash_time": 0.5, "light": 0.8, "light_size": 30.0}),
			_particles("星光", "main", 0.08, 0.6, total, {
				"count": 8, "shape": "star", "size": 2.5, "size_end": 0.5, "emit_shape": "circle", "emit_radius": 14.0, "spread": 360.0,
				"speed": 10.0, "drag": 2.0, "emit_time": 0.15, "life": 0.35, "life_random": 0.4, "cool": 0.0, "flicker": 0.6,
				"glow": 0.35, "glow_size": 4.0}),
			_layer("light", "剑光", "main", 0.0, 0.4, total, {"radius": 30.0, "strength": 0.4, "tone": 0.6}),
		])
