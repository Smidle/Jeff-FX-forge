@tool
extends RefCounted
## 内置预设（只读）。用代码定义，方便维护和比较差异；在编辑器里改了会提示另存为「我的预设」。
## 每个预设：{id, name, category, description, globals, layers: [{module, name, params, ……图层设置}]}

const FxPresetUtil := preload("../core/fx_preset_util.gd")
const Fireworks := preload("firework_presets.gd")
const MissileHits := preload("missile_hit_presets.gd")


## 返回全新的预设实例数组（每次调用都是新对象，可以随便改）
static func all() -> Array:
	var out: Array = []
	for d: Dictionary in _defs():
		out.append(FxPresetUtil.from_dict(d))
	return out


static func find(preset_id: String) -> Resource:
	for d: Dictionary in _defs():
		if d["id"] == preset_id:
			return FxPresetUtil.from_dict(d)
	return null


static func _defs() -> Array:
	return _base_defs() + Fireworks.defs() + MissileHits.defs()


static func _base_defs() -> Array:
	return [
		{
			"id": "slash_basic", "name": "基础刀光", "category": "combat",
			"description": "白钢色的标准挥砍，适合大多数近战普攻。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 9, "fps": 20, "theme": "steel",
				"palette_main": "steel", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [{"module": "arc", "name": "刀光", "params": {
				"radius": 26.0, "thickness": 10.0, "span": 200.0, "taper": 0.7, "crescent": 0.5,
				"trail": 0.6, "sweep": 0.5, "easing": "out_cubic", "rim": 0.7, "edge_noise": 0.12}}],
		},
		{
			"id": "slash_basic_v2", "name": "基础刀光·升级版", "category": "combat",
			"description": "按 pixelfx 的做法升级的试验版：刀锋两帧扫完、命中停顿，刀光从白热亮边冷却变暗并留下点状轨迹；刀锋带光，刀尖闪一下，迸出火星和碎屑。",
			"globals": {"canvas_w": 96, "canvas_h": 80, "frames": 16, "fps": 30, "origin_x": 0.42, "origin_y": 0.5,
				"hold_frame": 3, "hold_mult": 2.0, "outline": "none",
				"theme": "steel", "palette_main": "steel", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "arc", "name": "回声刀光", "t_start": 0.039, "t_end": 0.656, "params": {
					"radius": 24.0, "thickness": 4.0, "span": 190.0, "taper": 0.8, "crescent": 0.6, "squash": 0.85,
					"trail": 0.5, "sweep": 0.25, "easing": "out_expo", "rim": 0.5, "edge_noise": 0.05, "cool": 0.9}},
				{"module": "arc", "name": "主刀光", "t_end": 0.787, "params": {
					"radius": 31.0, "thickness": 11.0, "span": 205.0, "taper": 0.7, "crescent": 0.6, "squash": 0.85,
					"trail": 0.6, "sweep": 0.2, "easing": "out_expo", "rim": 0.9, "edge_noise": 0.08,
					"cool": 0.8, "glow": 0.6}},
				{"module": "particles", "name": "削屑", "palette_slot": "main", "t_start": 0.105, "t_end": 1.0, "params": {
					"count": 14, "shape": "square", "size": 1.0, "size_end": 1.0, "emit_shape": "ring", "emit_radius": 29.0,
					"spread": 180.0, "speed": 40.0, "speed_random": 0.6, "gravity": -10.0, "drag": 3.0, "emit_time": 0.15,
					"life": 0.6, "life_random": 0.4, "cool": 0.5, "flicker": 0.2}},
				{"module": "particles", "name": "火星", "offset_x": 5.0, "offset_y": 22.0, "angle_offset": 175.0,
						"t_start": 0.079, "t_end": 0.656, "params": {
					"count": 10, "shape": "streak", "size": 1.5, "size_end": 0.8, "spread": 60.0, "speed": 110.0,
					"speed_random": 0.6, "gravity": 90.0, "drag": 3.0, "emit_time": 0.05, "life": 0.9, "life_random": 0.45,
					"cool": 0.6, "streak_len": 0.8, "glow": 0.35, "glow_size": 4.0}},
				{"module": "burst", "name": "刀尖闪光", "palette_slot": "main", "outline": false, "offset_x": 5.0, "offset_y": 22.0,
						"t_start": 0.066, "t_end": 0.459, "params": {
					"rays": 4, "length": 9.0, "width": 1.5, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.5,
					"inner": 0.0, "flash": "star", "flash_size": 6.0, "flash_time": 0.5, "ray_time": 0.6, "detach": 0.0,
					"light": 0.6, "light_size": 20.0}},
			],
		},
		{
			"id": "slash_fire", "name": "火焰斩", "category": "combat",
			"description": "带火焰色和毛糙边缘的重斩，附一道残影。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 10, "fps": 20, "theme": "fire",
				"palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "arc", "name": "火焰刀光", "params": {
					"radius": 27.0, "thickness": 12.0, "span": 210.0, "taper": 0.6, "crescent": 0.6,
					"trail": 0.65, "sweep": 0.5, "easing": "out_cubic", "rim": 0.75, "edge_noise": 0.45, "ghosts": 1}},
				{"module": "particles", "name": "火星", "t_start": 0.08, "params": {
					"count": 18, "shape": "square", "size": 2.0, "size_end": 0.5, "size_random": 0.5,
					"emit_shape": "ring", "emit_radius": 22.0, "spread": 200.0, "speed": 32.0, "speed_random": 0.7,
					"gravity": -30.0, "drag": 2.0, "emit_mode": "stream", "emit_time": 0.45,
					"life": 0.55, "life_random": 0.4, "cool": 0.5, "flicker": 0.2}},
			],
		},
		{
			"id": "slash_ice", "name": "寒冰斩", "category": "combat",
			"description": "细而锋利的冰蓝刀光，用点阵抖动和选择性描边表现冷硬质感。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 9, "fps": 20, "theme": "ice",
				"palette_main": "ice", "palette_accent": "water", "palette_smoke": "smoke",
				"dither": "bayer4", "dither_strength": 0.6, "outline": "selective"},
			"layers": [
				{"module": "arc", "name": "冰刃", "params": {
					"radius": 26.0, "thickness": 9.0, "span": 190.0, "taper": 0.85, "crescent": 0.4,
					"trail": 0.55, "sweep": 0.5, "easing": "out_cubic", "rim": 0.8, "edge_noise": 0.25}},
				{"module": "particles", "name": "冰屑", "t_start": 0.1, "params": {
					"count": 14, "shape": "diamond", "size": 2.5, "size_end": 0.6,
					"emit_shape": "ring", "emit_radius": 20.0, "spread": 140.0, "speed": 26.0, "speed_random": 0.6,
					"gravity": 25.0, "drag": 2.0, "emit_mode": "stream", "emit_time": 0.4, "life": 0.55, "cool": 0.3}},
			],
		},
		{
			"id": "slash_shadow", "name": "暗影斩", "category": "combat",
			"description": "紫黑色的宽刀光，柔光外晕 + 两道抖动残影，不描边。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 11, "fps": 20, "theme": "shadow",
				"palette_main": "shadow", "palette_accent": "arcane", "palette_smoke": "smoke",
				"soft": 0.55, "outline": "none"},
			"layers": [{"module": "arc", "name": "暗影刀光", "params": {
				"radius": 27.0, "thickness": 13.0, "span": 220.0, "taper": 0.6, "crescent": 0.7,
				"trail": 0.7, "sweep": 0.55, "easing": "out_cubic", "rim": 0.5, "edge_noise": 0.55, "ghosts": 2}}],
		},
		{
			"id": "slash_spin", "name": "回旋斩", "category": "combat",
			"description": "绕身一整圈的回旋斩击。",
			"globals": {"canvas_w": 80, "canvas_h": 80, "frames": 12, "fps": 20, "theme": "steel",
				"palette_main": "steel", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [{"module": "arc", "name": "回旋刀光", "params": {
				"radius": 34.0, "thickness": 8.0, "span": 360.0, "taper": 0.5, "crescent": 0.3,
				"trail": 0.75, "sweep": 0.7, "easing": "out_quad", "rim": 0.6, "edge_noise": 0.1, "ghosts": 1}}],
		},
		{
			"id": "slash_ink", "name": "墨刃", "category": "combat",
			"description": "水墨笔触般的刀光，边缘飞白，适合武侠题材（浅色背景上效果最好）。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 9, "fps": 20, "theme": "ink",
				"palette_main": "ink", "palette_accent": "steel", "palette_smoke": "smoke", "outline": "none"},
			"layers": [{"module": "arc", "name": "墨痕", "params": {
				"radius": 27.0, "thickness": 14.0, "span": 170.0, "taper": 0.9, "crescent": 0.8, "squash": 0.85,
				"trail": 0.6, "sweep": 0.45, "easing": "out_expo", "rim": 0.2, "edge_noise": 0.8, "ghosts": 1}}],
		},
		{
			"id": "thrust", "name": "突刺", "category": "combat",
			"description": "长枪、细剑的直线突刺：一道锋芒向前冲出，枪尖炸开小火花。原点在左侧，方向朝右。",
			"globals": {"canvas_w": 80, "canvas_h": 40, "frames": 8, "fps": 20, "origin_x": 0.2, "origin_y": 0.5,
				"theme": "steel", "palette_main": "steel", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "streak", "name": "锋芒", "params": {
					"count": 3, "length": 40.0, "width": 5.0, "spread": 12.0, "length_random": 0.4, "main_boost": 0.7,
					"taper": 0.8, "travel": 22.0, "stagger": 0.25, "easing": "out_expo", "head": 0.6}},
				{"module": "burst", "name": "枪尖火花", "palette_slot": "accent", "offset_x": 40.0, "t_start": 0.15, "t_end": 0.8, "params": {
					"rays": 5, "length": 9.0, "width": 2.5, "spread": 140.0, "flash": "star", "flash_size": 7.0,
					"flash_time": 0.35, "ray_time": 0.7, "detach": 0.6}},
			],
		},
		{
			"id": "hit_basic", "name": "普通打击", "category": "combat",
			"description": "白黄色的打击火花：中心星形闪光 + 一圈飞散的尖刺，适合普通命中。",
			"globals": {"canvas_w": 48, "canvas_h": 48, "frames": 7, "fps": 20, "theme": "custom",
				"palette_main": "spark", "palette_accent": "steel", "palette_smoke": "smoke"},
			"layers": [{"module": "burst", "name": "打击火花", "params": {
				"rays": 7, "length": 17.0, "width": 4.0, "length_random": 0.5, "angle_random": 0.4, "alternate": 0.5,
				"inner": 0.2, "flash": "star", "flash_size": 10.0, "flash_time": 0.3, "ray_time": 0.8, "detach": 0.7}}],
		},
		{
			"id": "hit_heavy", "name": "重击", "category": "combat",
			"description": "势大力沉的重击：冲击环 + 大火花 + 往下掉的碎屑。第 1 帧（命中闪光）打击停顿 3 倍时长。",
			"globals": {"canvas_w": 88, "canvas_h": 104, "frames": 9, "fps": 20, "origin_x": 0.5, "origin_y": 0.42,
				"hold_frame": 1, "hold_mult": 3.0,
				"theme": "custom", "palette_main": "spark", "palette_accent": "steel", "palette_smoke": "dust"},
			"layers": [
				{"module": "ring", "name": "冲击环", "palette_slot": "accent", "t_end": 0.95, "params": {
					"radius": 34.0, "width": 7.0, "thin": 0.85, "start": 0.2, "easing": "out_expo", "fill": 1.0}},
				{"module": "burst", "name": "重击火花", "params": {
					"rays": 10, "length": 30.0, "width": 6.0, "length_random": 0.4, "alternate": 0.5, "inner": 0.25,
					"flash": "star", "flash_size": 15.0, "flash_time": 0.3, "ray_time": 0.85, "detach": 0.7}},
				{"module": "particles", "name": "碎屑", "palette_slot": "smoke", "outline": true, "t_start": 0.05,
						"follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 14, "shape": "square", "size": 2.0, "size_end": 0.8, "spread": 240.0, "speed": 100.0,
					"speed_random": 0.6, "gravity": 110.0, "drag": 1.6, "life": 0.8, "cool": 0.3}},
			],
		},
		{
			"id": "hit_crit", "name": "暴击", "category": "combat",
			"description": "红白配色的暴击：白色星芒 + 长短交替的红色射线 + 旋转的分段环。第 1 帧打击停顿 3 倍时长。",
			"globals": {"canvas_w": 88, "canvas_h": 88, "frames": 9, "fps": 20, "theme": "blood", "hold_frame": 1, "hold_mult": 3.0,
				"palette_main": "blood", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "ring", "name": "暴击环", "params": {
					"radius": 36.0, "width": 4.0, "thin": 0.5, "start": 0.3, "segments": 12, "gap": 0.4, "spin": 0.25,
					"easing": "out_cubic"}},
				{"module": "burst", "name": "暴击射线", "params": {
					"rays": 12, "length": 34.0, "width": 5.0, "length_random": 0.3, "alternate": 0.75, "inner": 0.2,
					"flash": "none", "ray_time": 0.9, "detach": 0.65}},
				{"module": "burst", "name": "白色星芒", "palette_slot": "accent", "angle_offset": 45.0, "t_end": 0.6, "params": {
					"rays": 4, "length": 14.0, "width": 4.0, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.0,
					"inner": 0.0, "flash": "star", "flash_size": 18.0, "flash_time": 0.6, "ray_time": 0.6, "detach": 0.3}},
			],
		},
		{
			"id": "block_sparks", "name": "格挡火花", "category": "combat",
			"description": "兵器相交的格挡：一点菱形闪光，火星朝「方向」成扇形飞溅并下坠。",
			"globals": {"canvas_w": 80, "canvas_h": 72, "frames": 10, "fps": 20, "origin_x": 0.28, "origin_y": 0.38,
				"theme": "custom", "palette_main": "spark", "palette_accent": "steel", "palette_smoke": "smoke"},
			"layers": [
				{"module": "particles", "name": "火星", "palette_slot": "main", "params": {
					"count": 24, "shape": "streak", "size": 2.0, "size_end": 0.7, "spread": 90.0, "speed": 120.0,
					"speed_random": 0.6, "gravity": 90.0, "drag": 1.4, "emit_time": 0.1, "life": 0.85, "life_random": 0.3,
					"cool": 0.55, "streak_len": 0.9}},
				{"module": "burst", "name": "格挡闪光", "t_end": 0.5, "params": {
					"rays": 4, "length": 9.0, "width": 3.0, "length_random": 0.2, "angle_random": 0.2, "alternate": 0.0,
					"flash": "diamond", "flash_size": 8.0, "flash_time": 0.6, "ray_time": 0.7, "detach": 0.4}},
			],
		},
		{
			"id": "ground_shockwave", "name": "地面冲击波", "category": "combat",
			"description": "砸地、落地的冲击：贴着地面扩散的两道椭圆波 + 扬起的尘土。原点在地面上。",
			"globals": {"canvas_w": 120, "canvas_h": 56, "frames": 10, "fps": 20, "origin_x": 0.5, "origin_y": 0.62,
				"theme": "custom", "palette_main": "dust", "palette_accent": "steel", "palette_smoke": "smoke"},
			"layers": [
				{"module": "ring", "name": "地面冲击环", "follow_dir": false, "params": {
					"radius": 52.0, "width": 7.0, "thin": 0.8, "squash": 0.32, "start": 0.08, "rings": 2, "ring_delay": 0.18,
					"easing": "out_cubic", "rim": 0.7}},
				{"module": "particles", "name": "扬尘", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 24, "shape": "disc", "size": 4.0, "size_end": 1.4, "size_random": 0.5, "emit_shape": "line",
					"emit_radius": 18.0, "spread": 170.0, "speed": 90.0, "speed_random": 0.6, "gravity": 70.0, "drag": 3.0,
					"life": 0.8, "life_random": 0.3, "cool": 0.3}},
			],
		},
		{
			"id": "energy_ring", "name": "能量冲击环", "category": "combat",
			"description": "青色能量爆开：带冲击闪光的柔光主环 + 旋转的分段内环 + 星形能量粒子。",
			"globals": {"canvas_w": 96, "canvas_h": 96, "frames": 12, "fps": 20, "theme": "energy",
				"palette_main": "energy", "palette_accent": "thunder", "palette_smoke": "smoke", "soft": 0.6, "outline": "none",
				"dissolve": "fade", "alpha_levels": 3},
			"layers": [
				{"module": "ring", "name": "能量环", "params": {
					"radius": 32.0, "width": 7.0, "thin": 0.7, "start": 0.05, "easing": "out_expo", "fill": 0.9, "rim": 0.85}},
				{"module": "ring", "name": "内环", "palette_slot": "accent", "t_start": 0.1, "params": {
					"radius": 22.0, "width": 3.0, "thin": 0.4, "start": 0.1, "segments": 8, "gap": 0.45, "spin": 0.5,
					"easing": "out_cubic"}},
				{"module": "particles", "name": "能量粒子", "params": {
					"count": 16, "shape": "star", "size": 2.5, "size_end": 0.3, "emit_shape": "ring", "emit_radius": 6.0,
					"speed": 110.0, "speed_random": 0.4, "drag": 2.2, "life": 0.7, "cool": 0.2, "spin": 0.5}},
			],
		},
		# ---------------------------------------------------------------- 爆炸与元素
		{
			"id": "explosion_small", "name": "小型爆炸", "category": "element",
			"description": "手雷、火焰弹的小爆炸：白热火球迅速膨胀、变红、烧穿成碎块，随后冒出一团烟。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 10, "fps": 15, "origin_x": 0.5, "origin_y": 0.56,
				"theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "烟", "palette_slot": "smoke", "t_start": 0.35, "dissolve": "shrink", "params": {
					"puffs": 3, "radius": 11.0, "spread": 7.0, "start": 0.5, "noise": 0.6, "rise": 14.0, "heat": 0.75,
					"cool": 0.45, "core": 0.3, "burn": 0.9, "expand_time": 0.5}},
				{"module": "blob", "name": "火球", "params": {
					"puffs": 4, "radius": 14.0, "spread": 7.0, "start": 0.2, "noise": 0.55, "expand_time": 0.3, "rise": 4.0,
					"heat": 1.0, "cool": 0.85, "core": 0.6, "burn": 0.75}},
			],
		},
		{
			"id": "explosion_small_v2", "name": "小型爆炸·升级版", "category": "element",
			"description": "按 pixelfx 的做法升级的试验版：白闪和冲击环之后，火团边升边冷却，火星落地弹跳，碎石翻滚着落定；半透明的烟柱和贴地尘浪慢慢散去，地上留下焦痕。原点在地面。",
			"globals": {"canvas_w": 128, "canvas_h": 112, "frames": 40, "fps": 20, "origin_x": 0.5, "origin_y": 0.84,
				"alpha_levels": 4, "theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "焦痕", "palette_slot": "smoke", "outline": false, "t_start": 0.04, "t_end": 0.8, "params": {
					"puffs": 3, "radius": 13.0, "spread": 6.0, "start": 0.3, "squash": 0.22, "noise": 0.5, "rise": 0.0,
					"boil": 0.0, "heat": 0.3, "cool": 0.3, "core": 0.2, "burn": 0.6, "expand_time": 0.08, "stagger": 0.0}},
				{"module": "particles", "name": "地面尘浪", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 352.0,
						"offset_y": -3.0, "dissolve": "translucent", "t_start": 0.02, "params": {
					"count": 12, "shape": "smoke", "size": 7.0, "size_end": 2.0, "size_random": 0.4, "mirror": true,
					"spread": 16.0, "speed": 210.0, "speed_random": 0.5, "gravity": -12.0, "drag": 5.0, "emit_time": 0.05,
					"life": 0.55, "life_random": 0.3, "bright": 1.0, "cool": 0.3, "opacity": 0.55, "thin": 0.7, "soft_edge": 0.8}},
				{"module": "particles", "name": "烟柱", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -12.0, "dissolve": "translucent", "t_start": 0.06, "params": {
					"count": 22, "shape": "smoke", "size": 9.0, "size_end": 2.2, "size_random": 0.4, "emit_shape": "circle",
					"emit_radius": 7.0, "spread": 50.0, "speed": 70.0, "speed_random": 0.5, "gravity": -200.0, "drag": 1.2,
					"sway": 3.0, "emit_mode": "stream", "emit_time": 0.35, "life": 0.7, "life_random": 0.25,
					"bright": 1.0, "cool": 0.45, "opacity": 0.75, "thin": 0.8, "soft_edge": 0.7}},
				{"module": "ring", "name": "地面冲击环", "palette_slot": "main", "outline": false, "follow_dir": false,
						"t_end": 0.16, "params": {
					"radius": 56.0, "width": 2.0, "thin": 0.8, "start": 0.15, "squash": 0.25, "easing": "out_expo"}},
				{"module": "ring", "name": "空中冲击环", "palette_slot": "accent", "outline": false, "follow_dir": false,
						"offset_y": -12.0, "t_end": 0.1, "params": {
					"radius": 30.0, "width": 2.0, "thin": 0.9, "start": 0.3, "easing": "out_expo"}},
				{"module": "blob", "name": "火球", "offset_y": -12.0, "t_end": 0.2, "params": {
					"puffs": 4, "radius": 12.0, "spread": 6.0, "start": 0.3, "noise": 0.3, "expand_time": 0.2, "rise": 6.0,
					"heat": 1.0, "cool": 0.7, "core": 0.6, "burn": 0.85}},
				{"module": "particles", "name": "火团", "palette_slot": "main", "outline": true, "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -12.0, "t_end": 0.6, "params": {
					"count": 26, "shape": "puff", "size": 12.0, "size_end": 0.5, "size_random": 0.5, "emit_shape": "circle",
					"emit_radius": 6.0, "spread": 360.0, "speed": 120.0, "speed_random": 0.6, "gravity": -90.0, "drag": 5.0,
					"emit_time": 0.04, "life": 0.5, "life_random": 0.45, "cool": 0.7, "glow": 0.25, "glow_size": 10.0}},
				{"module": "particles", "name": "碎石", "palette_slot": "smoke", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "offset_y": -3.0, "t_end": 0.75, "params": {
					"count": 12, "shape": "shard", "size": 3.5, "size_end": 0.9, "size_random": 0.5, "spread": 120.0,
					"speed": 260.0, "speed_random": 0.5, "gravity": 1500.0, "drag": 0.6, "use_floor": true, "floor_y": 3.0,
					"bounce": 0.3, "emit_time": 0.03, "life": 0.85, "life_random": 0.2, "bright": 0.95, "cool": 0.2, "spin": 3.0}},
				{"module": "particles", "name": "火星", "follow_dir": false, "angle_offset": 270.0, "offset_y": -12.0,
						"t_end": 0.5, "params": {
					"count": 36, "shape": "streak", "size": 2.0, "size_end": 0.7, "spread": 360.0, "speed": 260.0,
					"speed_random": 0.6, "gravity": 700.0, "drag": 3.0, "use_floor": true, "floor_y": 12.0, "bounce": 0.35,
					"emit_time": 0.03, "life": 0.6, "life_random": 0.5, "cool": 0.7, "streak_len": 0.5,
					"glow": 0.5, "glow_size": 5.0}},
				{"module": "particles", "name": "余烬", "follow_dir": false, "angle_offset": 270.0, "offset_y": -12.0,
						"t_start": 0.05, "params": {
					"count": 18, "shape": "square", "size": 1.2, "size_end": 1.0, "spread": 160.0, "speed": 70.0,
					"speed_random": 0.6, "gravity": -50.0, "drag": 2.0, "sway": 3.0, "emit_mode": "stream", "emit_time": 0.3,
					"life": 0.6, "life_random": 0.4, "cool": 0.7, "flicker": 0.3, "glow": 0.35, "glow_size": 4.0}},
				{"module": "burst", "name": "白闪", "palette_slot": "accent", "outline": false, "follow_dir": false,
						"offset_y": -12.0, "t_end": 0.12, "params": {
					"rays": 8, "length": 18.0, "width": 2.0, "length_random": 0.5, "inner": 0.3, "ray_time": 0.35,
					"detach": 0.8, "flash": "disc", "flash_size": 14.0, "flash_time": 0.45, "light": 0.8, "light_size": 36.0}},
				{"module": "light", "name": "火光", "offset_y": -12.0, "t_end": 0.45, "params": {
					"radius": 44.0, "strength": 0.45, "tone": 0.55}},
				{"module": "light", "name": "地面光斑", "t_start": 0.02, "t_end": 0.7, "params": {
					"radius": 40.0, "squash": 0.3, "strength": 0.4, "tone": 0.55, "flicker": 0.3}},
			],
		},
		{
			"id": "explosion_big", "name": "大型爆炸", "category": "element",
			"description": "火药桶、大招的大爆炸：冲击波 + 翻滚的火球 + 飞溅的碎片 + 延迟升起的浓烟。",
			"globals": {"canvas_w": 120, "canvas_h": 120, "frames": 14, "fps": 15, "origin_x": 0.5, "origin_y": 0.5,
				"theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "浓烟", "palette_slot": "smoke", "t_start": 0.3, "dissolve": "shrink", "params": {
					"puffs": 6, "radius": 20.0, "spread": 16.0, "start": 0.5, "noise": 0.6, "rise": 24.0, "heat": 0.75,
					"cool": 0.45, "core": 0.3, "burn": 0.9, "expand_time": 0.5, "stagger": 0.25}},
				{"module": "ring", "name": "冲击波", "palette_slot": "accent", "t_end": 0.55, "params": {
					"radius": 48.0, "width": 5.0, "thin": 0.9, "start": 0.15, "easing": "out_expo"}},
				{"module": "blob", "name": "火球", "params": {
					"puffs": 7, "radius": 24.0, "spread": 15.0, "start": 0.15, "noise": 0.55, "expand_time": 0.3,
					"rise": 8.0, "heat": 1.0, "cool": 0.85, "core": 0.6, "burn": 0.75, "stagger": 0.12}},
				{"module": "particles", "name": "碎片", "palette_slot": "smoke", "outline": true, "t_start": 0.05,
						"follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 16, "shape": "shard", "size": 3.0, "size_end": 0.8, "spread": 260.0, "speed": 150.0,
					"speed_random": 0.6, "gravity": 120.0, "drag": 1.6, "life": 0.75, "cool": 0.2, "spin": 1.5}},
			],
		},
		{
			"id": "explosion_big_v2", "name": "大型爆炸·升级版", "category": "element",
			"description": "按 pixelfx 的做法升级的试验版，三拍：白色穹顶般的闪光和地面冲击环；翻滚的火团一路往上爬，顶成一朵蘑菇云；重石块翻滚落地，地上留下零星残火和焦痕，烟柱慢慢散去。原点在地面。",
			"globals": {"canvas_w": 160, "canvas_h": 168, "frames": 60, "fps": 20, "origin_x": 0.5, "origin_y": 0.86,
				"alpha_levels": 4, "theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "焦痕", "palette_slot": "smoke", "outline": false, "t_start": 0.03, "t_end": 0.75, "params": {
					"puffs": 4, "radius": 19.0, "spread": 10.0, "start": 0.3, "squash": 0.2, "noise": 0.5, "rise": 0.0,
					"boil": 0.0, "heat": 0.3, "cool": 0.3, "core": 0.2, "burn": 0.6, "expand_time": 0.06, "stagger": 0.0}},
				{"module": "particles", "name": "地面尘浪", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 352.0,
						"offset_y": -4.0, "dissolve": "translucent", "t_start": 0.02, "params": {
					"count": 16, "shape": "smoke", "size": 11.0, "size_end": 2.2, "size_random": 0.4, "mirror": true,
					"spread": 14.0, "speed": 320.0, "speed_random": 0.5, "gravity": -12.0, "drag": 5.0, "emit_time": 0.05,
					"life": 0.5, "life_random": 0.3, "bright": 1.0, "cool": 0.3, "opacity": 0.6, "thin": 0.7, "soft_edge": 0.8}},
				{"module": "particles", "name": "烟柱", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -8.0, "dissolve": "translucent", "t_start": 0.06, "params": {
					"count": 34, "shape": "smoke", "size": 12.0, "size_end": 2.0, "size_random": 0.4, "emit_shape": "circle",
					"emit_radius": 6.0, "spread": 14.0, "speed": 300.0, "speed_random": 0.7, "gravity": -60.0, "drag": 3.0,
					"sway": 3.0, "emit_mode": "stream", "emit_time": 0.45, "life": 0.6, "life_random": 0.3,
					"bright": 1.0, "cool": 0.45, "opacity": 0.75, "thin": 0.7, "soft_edge": 0.7}},
				{"module": "particles", "name": "蘑菇云顶", "palette_slot": "smoke", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -86.0, "dissolve": "translucent", "t_start": 0.2, "params": {
					"count": 20, "shape": "smoke", "size": 15.0, "size_end": 1.9, "size_random": 0.4, "squash": 0.55,
					"emit_shape": "circle", "emit_radius": 12.0, "spread": 360.0, "speed": 45.0, "speed_random": 0.5,
					"gravity": -25.0, "drag": 2.0, "sway": 2.0, "emit_mode": "stream", "emit_time": 0.3, "life": 0.75,
					"life_random": 0.2, "bright": 1.0, "cool": 0.4, "opacity": 0.85, "thin": 0.7, "soft_edge": 0.6}},
				{"module": "ring", "name": "地面冲击环", "palette_slot": "main", "outline": false, "follow_dir": false,
						"t_end": 0.2, "params": {
					"radius": 78.0, "width": 3.0, "thin": 0.8, "start": 0.1, "squash": 0.24, "rings": 2, "ring_delay": 0.3,
					"easing": "out_expo"}},
				{"module": "ring", "name": "穹顶冲击", "palette_slot": "accent", "outline": false, "follow_dir": false,
						"offset_y": -26.0, "t_end": 0.08, "params": {
					"radius": 46.0, "width": 2.0, "thin": 0.9, "start": 0.3, "easing": "out_expo"}},
				{"module": "blob", "name": "火球", "offset_y": -18.0, "t_end": 0.13, "params": {
					"puffs": 5, "radius": 20.0, "spread": 9.0, "start": 0.3, "noise": 0.3, "expand_time": 0.2, "rise": 12.0,
					"heat": 1.0, "cool": 0.45, "core": 0.6, "burn": 0.95}},
				{"module": "particles", "name": "火团", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "offset_y": -18.0, "dissolve": "shrink", "t_end": 0.35, "params": {
					"count": 30, "shape": "puff", "size": 15.0, "size_end": 0.5, "size_random": 0.5, "emit_shape": "circle",
					"emit_radius": 8.0, "spread": 360.0, "speed": 160.0, "speed_random": 0.6, "gravity": -120.0, "drag": 5.0,
					"emit_time": 0.04, "life": 0.5, "life_random": 0.45, "cool": 0.7, "glow": 0.25, "glow_size": 12.0}},
				{"module": "particles", "name": "升腾火柱", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "offset_y": -10.0, "dissolve": "shrink", "t_start": 0.03, "t_end": 0.55, "params": {
					"count": 28, "shape": "puff", "size": 14.0, "size_end": 0.6, "size_random": 0.4, "emit_shape": "circle",
					"emit_radius": 6.0, "spread": 22.0, "speed": 270.0, "speed_random": 0.35, "gravity": -60.0, "drag": 3.0,
					"emit_mode": "stream", "emit_time": 0.3, "life": 0.5, "life_random": 0.3, "cool": 0.75,
					"glow": 0.25, "glow_size": 12.0}},
				{"module": "particles", "name": "重石块", "palette_slot": "smoke", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "offset_y": -4.0, "t_end": 0.6, "params": {
					"count": 14, "shape": "shard", "size": 5.0, "size_end": 0.9, "size_random": 0.5, "spread": 120.0,
					"speed": 380.0, "speed_random": 0.5, "gravity": 1500.0, "drag": 0.6, "use_floor": true, "floor_y": 4.0,
					"bounce": 0.3, "emit_time": 0.03, "life": 0.85, "life_random": 0.2, "bright": 0.95, "cool": 0.2, "spin": 3.0}},
				{"module": "particles", "name": "火星", "follow_dir": false, "angle_offset": 270.0, "offset_y": -18.0,
						"t_end": 0.4, "params": {
					"count": 50, "shape": "streak", "size": 2.0, "size_end": 0.7, "spread": 360.0, "speed": 330.0,
					"speed_random": 0.6, "gravity": 700.0, "drag": 2.6, "use_floor": true, "floor_y": 18.0, "bounce": 0.35,
					"emit_time": 0.03, "life": 0.6, "life_random": 0.5, "cool": 0.7, "streak_len": 0.5,
					"glow": 0.5, "glow_size": 5.0}},
				{"module": "particles", "name": "残火", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -1.0, "t_start": 0.18, "t_end": 0.9, "params": {
					"count": 46, "shape": "puff", "size": 4.0, "size_end": 0.5, "size_random": 0.5, "emit_shape": "line",
					"emit_radius": 52.0, "spread": 20.0, "speed": 25.0, "speed_random": 0.5, "gravity": -40.0, "drag": 1.0,
					"emit_mode": "stream", "emit_time": 0.85, "life": 0.12, "life_random": 0.4, "cool": 0.8, "flicker": 0.2,
					"glow": 0.3, "glow_size": 5.0}},
				{"module": "particles", "name": "余烬", "follow_dir": false, "angle_offset": 270.0, "offset_y": -30.0,
						"t_start": 0.05, "params": {
					"count": 30, "shape": "square", "size": 1.2, "size_end": 1.0, "spread": 160.0, "speed": 90.0,
					"speed_random": 0.6, "gravity": -60.0, "drag": 2.0, "sway": 4.0, "emit_mode": "stream", "emit_time": 0.5,
					"life": 0.45, "life_random": 0.4, "cool": 0.7, "flicker": 0.3, "glow": 0.35, "glow_size": 4.0}},
				{"module": "burst", "name": "白闪", "palette_slot": "accent", "outline": false, "follow_dir": false,
						"offset_y": -14.0, "t_end": 0.07, "params": {
					"rays": 10, "length": 26.0, "width": 2.5, "length_random": 0.5, "inner": 0.3, "ray_time": 0.4,
					"detach": 0.8, "flash": "disc", "flash_size": 24.0, "flash_time": 0.5, "light": 1.0, "light_size": 60.0}},
				{"module": "light", "name": "火光", "offset_y": -40.0, "t_end": 0.45, "params": {
					"radius": 64.0, "strength": 0.5, "tone": 0.55, "flicker": 0.2}},
				{"module": "light", "name": "地面光斑", "t_start": 0.02, "t_end": 0.85, "params": {
					"radius": 64.0, "squash": 0.3, "strength": 0.45, "tone": 0.55, "flicker": 0.35}},
			],
		},
		{
			"id": "explosion_poison", "name": "毒气爆炸", "category": "element",
			"description": "毒瓶、毒雾陷阱：紫绿色的毒爆，炸开后留下一大片贴地翻滚的毒雾和冒泡。",
			"globals": {"canvas_w": 88, "canvas_h": 72, "frames": 12, "fps": 12, "origin_x": 0.5, "origin_y": 0.62,
				"theme": "poison", "palette_main": "poison", "palette_accent": "nature", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "毒雾", "palette_slot": "main", "t_start": 0.2, "dissolve": "shrink", "params": {
					"puffs": 7, "radius": 14.0, "spread": 22.0, "start": 0.4, "squash": 0.6, "noise": 0.6, "rise": 4.0,
					"boil": 2.0, "heat": 0.75, "cool": 0.35, "core": 0.3, "burn": 0.85, "expand_time": 0.45, "stagger": 0.25}},
				{"module": "blob", "name": "毒爆", "params": {
					"puffs": 5, "radius": 16.0, "spread": 8.0, "start": 0.2, "noise": 0.55, "expand_time": 0.3, "rise": 3.0,
					"heat": 1.0, "cool": 0.6, "core": 0.5, "burn": 0.8}},
				{"module": "particles", "name": "毒泡", "palette_slot": "accent", "outline": true, "t_start": 0.2, "params": {
					"count": 10, "shape": "disc", "size": 3.0, "size_end": 0.6, "emit_shape": "circle", "emit_radius": 18.0,
					"spread": 360.0, "speed": 10.0, "gravity": -60.0, "drag": 1.0, "emit_mode": "stream", "emit_time": 0.5,
					"life": 0.45, "cool": 0.2}},
			],
		},
		{
			"id": "campfire", "name": "篝火", "category": "element",
			"description": "循环播放的篝火：平底火焰 + 往上飘的火星。原点在火堆底部。",
			"globals": {"canvas_w": 48, "canvas_h": 64, "frames": 12, "fps": 12, "loop": true, "origin_x": 0.5, "origin_y": 0.92,
				"theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "flame", "name": "火焰", "params": {
					"width": 26.0, "height": 40.0, "base": "flat", "tongues": 3, "tongue_depth": 0.45, "taper": 0.3,
					"speed": 1.5, "sway": 0.25,
					"turbulence": 0.55, "noise_scale": 1.4, "core": 0.6, "flicker": 0.3}},
				{"module": "particles", "name": "火星", "follow_dir": false, "angle_offset": 270.0, "offset_y": -6.0, "params": {
					"count": 10, "shape": "square", "size": 1.5, "size_end": 0.6, "emit_shape": "line", "emit_radius": 7.0,
					"spread": 40.0, "speed": 70.0, "speed_random": 0.5, "gravity": -20.0, "drag": 1.0,
					"emit_mode": "stream", "emit_time": 1.0, "life": 0.6, "life_random": 0.3, "cool": 0.5, "flicker": 0.3}},
			],
		},
		{
			"id": "torch", "name": "火把", "category": "element",
			"description": "循环播放的小火苗：尖底、摇曳得厉害，适合火把、蜡烛、灯台。原点在火苗底部。",
			"globals": {"canvas_w": 32, "canvas_h": 48, "frames": 10, "fps": 12, "loop": true, "origin_x": 0.5, "origin_y": 0.92,
				"theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [{"module": "flame", "name": "火苗", "params": {
				"width": 12.0, "height": 28.0, "base": "point", "taper": 0.5, "speed": 1.6, "sway": 0.45,
				"turbulence": 0.45, "noise_scale": 1.6, "core": 0.7, "flicker": 0.4}}],
		},
		{
			"id": "blue_flame", "name": "蓝焰", "category": "element",
			"description": "循环播放的冷色火焰（冥火、法术火），带柔光。原点在火焰底部。",
			"globals": {"canvas_w": 48, "canvas_h": 64, "frames": 12, "fps": 12, "loop": true, "origin_x": 0.5, "origin_y": 0.9,
				"theme": "ice", "palette_main": "ice", "palette_accent": "water", "palette_smoke": "smoke",
				"soft": 0.4, "outline": "none"},
			"layers": [{"module": "flame", "name": "蓝色火焰", "params": {
				"width": 20.0, "height": 38.0, "base": "round", "taper": 0.6, "speed": 1.2, "sway": 0.35,
				"turbulence": 0.6, "noise_scale": 1.3, "core": 0.5, "flicker": 0.25}}],
		},
		{
			"id": "lightning_strike", "name": "落雷", "category": "element",
			"description": "从天而降的闪电：先劈下来，再闪两下；落点有电火花和贴地的冲击环。原点在落点。",
			"globals": {"canvas_w": 80, "canvas_h": 112, "frames": 10, "fps": 15, "origin_x": 0.5, "origin_y": 0.88,
				"theme": "thunder", "palette_main": "thunder", "palette_accent": "energy", "palette_smoke": "smoke",
				"soft": 0.45, "outline": "none"},
			"layers": [
				{"module": "ring", "name": "落点冲击", "palette_slot": "accent", "follow_dir": false, "t_start": 0.08, "t_end": 0.7, "params": {
					"radius": 24.0, "width": 4.0, "thin": 0.8, "squash": 0.35, "start": 0.1, "fill": 0.5, "easing": "out_expo"}},
				{"module": "bolt", "name": "雷电", "follow_dir": false, "angle_offset": 270.0, "params": {
					"mode": "strike", "length": 92.0, "segments": 12, "jag": 0.3, "branches": 3, "branch_len": 0.3,
					"width": 1.2, "glow": 2.5, "flashes": 3, "on_ratio": 0.75, "grow": 0.12, "end_glow": 0.7}},
				{"module": "burst", "name": "电火花", "palette_slot": "accent", "follow_dir": false, "t_start": 0.08, "t_end": 0.6, "params": {
					"rays": 8, "length": 12.0, "width": 2.0, "flash": "star", "flash_size": 8.0, "flash_time": 0.4, "detach": 0.6}},
			],
		},
		{
			"id": "electric_arc", "name": "电弧", "category": "element",
			"description": "循环跳动的电弧：两点之间不停变形的电流，适合电网、充能、连锁闪电。原点在左端，方向朝右。",
			"globals": {"canvas_w": 96, "canvas_h": 48, "frames": 8, "fps": 15, "loop": true, "origin_x": 0.1, "origin_y": 0.5,
				"theme": "thunder", "palette_main": "thunder", "palette_accent": "energy", "palette_smoke": "smoke",
				"soft": 0.4, "outline": "none"},
			"layers": [{"module": "bolt", "name": "电弧", "params": {
				"mode": "arc", "length": 76.0, "segments": 14, "jag": 0.25, "branches": 1, "branch_len": 0.22,
				"width": 1.0, "glow": 2.0, "flashes": 8, "on_ratio": 1.0, "end_glow": 0.5}}],
		},
		{
			"id": "ice_burst", "name": "冰晶爆裂", "category": "element",
			"description": "冰系命中或冰块碎裂：菱形冰光 + 旋转飞散的冰晶碎片 + 一圈霜环。",
			"globals": {"canvas_w": 88, "canvas_h": 88, "frames": 10, "fps": 15, "theme": "ice",
				"palette_main": "ice", "palette_accent": "water", "palette_smoke": "smoke"},
			"layers": [
				{"module": "ring", "name": "霜环", "palette_slot": "accent", "params": {
					"radius": 32.0, "width": 3.0, "thin": 0.4, "start": 0.3, "segments": 10, "gap": 0.3, "spin": 0.15,
					"easing": "out_cubic"}},
				{"module": "burst", "name": "冰光", "params": {
					"rays": 6, "length": 24.0, "width": 5.0, "length_random": 0.3, "angle_random": 0.15, "alternate": 0.4,
					"flash": "diamond", "flash_size": 10.0, "flash_time": 0.35, "ray_time": 0.9, "detach": 0.5}},
				{"module": "particles", "name": "冰晶", "palette_slot": "main", "outline": true, "params": {
					"count": 12, "shape": "shard", "size": 5.0, "size_end": 0.6, "speed": 110.0, "speed_random": 0.5,
					"gravity": 50.0, "drag": 1.8, "life": 0.9, "cool": 0.25, "spin": 1.5}},
			],
		},
		{
			"id": "ice_burst_v2", "name": "冰晶爆裂·升级版", "category": "element",
			"description": "按 pixelfx 的做法升级的试验版：白闪和八道冰芒之后，冰晶碎片翻滚着落地弹跳、停住，冰碴四溅；地面荡开碎裂的霜环，半透明的寒气贴地滚开，雪屑飘落，碎冰上闪着光点。",
			"globals": {"canvas_w": 120, "canvas_h": 100, "frames": 32, "fps": 20, "origin_x": 0.5, "origin_y": 0.48,
				"alpha_levels": 4, "outline": "selective",
				"theme": "ice", "palette_main": "ice", "palette_accent": "water", "palette_smoke": "smoke"},
			"layers": [
				{"module": "light", "name": "地面冷光", "offset_y": 21.0, "t_end": 0.8, "params": {
					"radius": 40.0, "squash": 0.3, "strength": 0.4, "tone": 0.6}},
				{"module": "ring", "name": "霜环", "palette_slot": "accent", "outline": false, "follow_dir": false, "offset_y": 21.0,
						"t_start": 0.02, "t_end": 0.3, "params": {
					"radius": 42.0, "width": 2.0, "thin": 0.6, "start": 0.1, "squash": 0.28, "segments": 18, "gap": 0.45,
					"wobble": 0.4, "easing": "out_expo", "rim": 0.3}},
				{"module": "particles", "name": "贴地寒气", "palette_slot": "main", "follow_dir": false, "angle_offset": 352.0,
						"offset_y": 18.0, "dissolve": "translucent", "t_start": 0.04, "params": {
					"count": 14, "shape": "puff", "size": 7.0, "size_end": 2.0, "size_random": 0.4, "mirror": true,
					"spread": 20.0, "speed": 170.0, "speed_random": 0.5, "gravity": -15.0, "drag": 5.0, "emit_time": 0.06,
					"life": 0.6, "life_random": 0.3, "bright": 1.0, "cool": 0.0, "opacity": 0.4, "thin": 0.6, "soft_edge": 0.9,
					"glow": 0.2, "glow_size": 7.0, "glow_tone": 0.85}},
				{"module": "particles", "name": "悬浮寒气", "palette_slot": "main", "follow_dir": false, "dissolve": "translucent",
						"t_start": 0.06, "params": {
					"count": 4, "shape": "puff", "size": 9.0, "size_end": 1.8, "size_random": 0.4, "emit_shape": "circle",
					"emit_radius": 10.0, "spread": 360.0, "speed": 45.0, "gravity": -20.0, "drag": 3.0, "emit_time": 0.08,
					"life": 0.5, "life_random": 0.3, "bright": 1.0, "cool": 0.0, "opacity": 0.35, "thin": 0.6, "soft_edge": 0.9,
					"glow": 0.2, "glow_size": 8.0, "glow_tone": 0.85}},
				{"module": "particles", "name": "冰晶碎片", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "t_end": 0.75, "params": {
					"count": 22, "shape": "shard", "size": 3.5, "size_end": 0.7, "size_random": 0.6, "spread": 300.0,
					"speed": 180.0, "speed_random": 0.6, "gravity": 1300.0, "drag": 0.8, "use_floor": true, "floor_y": 21.0,
					"bounce": 0.35, "emit_time": 0.02, "life": 0.75, "life_random": 0.3, "cool": 0.35, "spin": 4.0}},
				{"module": "particles", "name": "冰碴", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"t_end": 0.7, "params": {
					"count": 16, "shape": "square", "size": 1.5, "size_end": 1.0, "spread": 360.0, "speed": 220.0,
					"speed_random": 0.6, "gravity": 1300.0, "drag": 0.8, "use_floor": true, "floor_y": 21.0, "bounce": 0.4,
					"emit_time": 0.02, "life": 0.6, "life_random": 0.4, "cool": 0.3}},
				{"module": "particles", "name": "雪屑", "palette_slot": "main", "follow_dir": false, "t_start": 0.05, "params": {
					"count": 14, "shape": "pixel", "size": 1.0, "size_end": 1.0, "spread": 360.0, "speed": 70.0,
					"speed_random": 0.6, "gravity": 60.0, "drag": 3.0, "sway": 4.0, "emit_time": 0.05, "life": 0.8,
					"life_random": 0.3, "cool": 0.1, "flicker": 0.15}},
				{"module": "particles", "name": "闪点", "palette_slot": "main", "follow_dir": false, "offset_y": 15.0,
						"t_start": 0.3, "params": {
					"count": 7, "shape": "star", "size": 3.0, "size_end": 0.5, "emit_shape": "box", "emit_radius": 30.0,
					"emit_height": 10.0, "spread": 360.0, "speed": 5.0, "emit_mode": "stream", "emit_time": 0.5,
					"life": 0.25, "cool": 0.0, "glow": 0.4, "glow_size": 6.0}},
				{"module": "burst", "name": "白闪冰芒", "palette_slot": "main", "outline": false, "follow_dir": false,
						"t_end": 0.25, "params": {
					"rays": 8, "length": 30.0, "width": 1.5, "length_random": 0.3, "angle_random": 0.1, "alternate": 0.6,
					"inner": 0.15, "ray_time": 0.55, "detach": 0.6, "flash": "diamond", "flash_size": 12.0,
					"flash_time": 0.35, "light": 0.8, "light_size": 46.0}},
				{"module": "light", "name": "冷光", "t_end": 0.5, "params": {
					"radius": 44.0, "strength": 0.4, "tone": 0.65}},
			],
		},
		# ---------------------------------------------------------------- 魔法与状态
		{
			"id": "fireball_shot", "name": "火球弹", "category": "magic",
			"description": "循环飞行的火球：翻滚的火团 + 波动的尾焰 + 往后掉的余烬。原点在弹体中心，方向 = 飞行方向。",
			"globals": {"canvas_w": 56, "canvas_h": 32, "frames": 8, "fps": 12, "loop": true, "origin_x": 0.7, "origin_y": 0.5,
				"theme": "fire", "palette_main": "fire", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "orb", "name": "火球", "params": {
					"shape": "flame", "core": 3.0, "halo": 7.0, "trail": 20.0, "trail_width": 0.8, "wobble": 0.35,
					"noise": 0.7, "pulse": 0.25, "pulse_speed": 2, "flow": 2}},
				{"module": "particles", "name": "余烬", "palette_slot": "accent", "angle_offset": 180.0, "offset_x": -9.0, "params": {
					"count": 12, "shape": "square", "size": 2.0, "size_end": 0.5, "spread": 70.0, "speed": 60.0,
					"speed_random": 0.5, "gravity": -25.0, "drag": 1.0, "emit_mode": "stream", "emit_time": 1.0,
					"life": 0.5, "cool": 0.5, "flicker": 0.25}},
			],
		},
		{
			"id": "magic_missile", "name": "魔法飞弹", "category": "magic",
			"description": "循环飞行的奥术飞弹：细长的波动尾迹 + 环绕的三个光点，带柔光。",
			"globals": {"canvas_w": 56, "canvas_h": 32, "frames": 8, "fps": 12, "loop": true, "origin_x": 0.7, "origin_y": 0.5,
				"theme": "arcane", "palette_main": "arcane", "palette_accent": "rose", "palette_smoke": "smoke",
				"soft": 0.5, "outline": "none"},
			"layers": [{"module": "orb", "name": "飞弹", "params": {
				"shape": "round", "core": 2.5, "halo": 5.5, "trail": 22.0, "trail_width": 0.55, "wobble": 0.5,
				"pulse": 0.35, "pulse_speed": 2, "flow": 3, "orbiters": 3, "orbit_radius": 8.0, "orbit_turns": 1}}],
		},
		{
			"id": "heal", "name": "治疗", "category": "magic",
			"description": "回血、治疗术：脚下扩散的光环 + 往上飘的绿色十字 + 闪烁的光点。原点在角色脚下。",
			"globals": {"canvas_w": 64, "canvas_h": 80, "frames": 14, "fps": 14, "origin_x": 0.5, "origin_y": 0.85,
				"theme": "heal", "palette_main": "heal", "palette_accent": "holy", "palette_smoke": "dust"},
			"layers": [
				{"module": "ring", "name": "治疗光环", "follow_dir": false, "t_end": 0.75, "outline": false, "params": {
					"radius": 22.0, "width": 3.0, "thin": 0.4, "start": 0.2, "squash": 0.35, "easing": "out_cubic"}},
				{"module": "particles", "name": "上升光丝", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 10, "shape": "streak", "size": 1.5, "size_end": 1.0, "emit_shape": "line", "emit_radius": 16.0,
					"spread": 4.0, "speed": 110.0, "speed_random": 0.4, "drag": 0.6, "emit_mode": "stream", "emit_time": 0.55,
					"life": 0.45, "cool": 0.3, "streak_len": 0.6}},
				{"module": "particles", "name": "治疗十字", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "params": {
					"count": 7, "shape": "plus", "size": 7.0, "size_end": 3.0, "size_random": 0.4, "emit_shape": "line",
					"emit_radius": 15.0, "spread": 20.0, "speed": 75.0, "speed_random": 0.4, "drag": 1.2,
					"emit_mode": "stream", "emit_time": 0.55, "life": 0.5, "cool": 0.25}},
				{"module": "particles", "name": "光点", "palette_slot": "accent", "follow_dir": false, "offset_y": -18.0, "outline": false, "params": {
					"count": 8, "shape": "star", "size": 2.5, "size_end": 0.5, "emit_shape": "circle", "emit_radius": 16.0,
					"speed": 15.0, "gravity": -30.0, "drag": 1.0, "emit_mode": "stream", "emit_time": 0.7,
					"life": 0.35, "cool": 0.1, "flicker": 0.3}},
			],
		},
		{
			"id": "buff_aura", "name": "增益光环", "category": "magic",
			"description": "循环的增益状态：脚下呼吸的金色光环 + 往上飘的光丝和星光。原点在角色脚下。",
			"globals": {"canvas_w": 64, "canvas_h": 80, "frames": 12, "fps": 12, "loop": true, "origin_x": 0.5, "origin_y": 0.85,
				"theme": "holy", "palette_main": "holy", "palette_accent": "spark", "palette_smoke": "dust",
				"soft": 0.2, "outline": "none"},
			"layers": [
				{"module": "ring", "name": "脚下光环", "follow_dir": false, "params": {
					"radius": 22.0, "width": 3.0, "thin": 0.5, "start": 0.85, "squash": 0.35, "mode": "pulse"}},
				{"module": "particles", "name": "上升光丝", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 16, "shape": "streak", "size": 2.0, "size_end": 1.0, "emit_shape": "line", "emit_radius": 19.0,
					"spread": 4.0, "speed": 100.0, "speed_random": 0.4, "drag": 0.5, "emit_mode": "stream", "emit_time": 1.0,
					"life": 0.55, "cool": 0.25, "flicker": 0.15, "streak_len": 0.8}},
				{"module": "particles", "name": "星光", "palette_slot": "main", "follow_dir": false, "offset_y": -24.0, "params": {
					"count": 8, "shape": "star", "size": 3.0, "size_end": 0.5, "emit_shape": "circle", "emit_radius": 18.0,
					"speed": 10.0, "gravity": -20.0, "drag": 1.0, "emit_mode": "stream", "emit_time": 1.0,
					"life": 0.35, "cool": 0.0, "flicker": 0.3}},
			],
		},
		{
			"id": "shield", "name": "护盾", "category": "magic",
			"description": "循环的护盾泡：发光的球形外壳 + 旋转的六边形纹 + 绕行的流光。",
			"globals": {"canvas_w": 72, "canvas_h": 72, "frames": 12, "fps": 12, "loop": true,
				"theme": "energy", "palette_main": "energy", "palette_accent": "thunder", "palette_smoke": "smoke",
				"soft": 0.5, "outline": "none", "dissolve": "fade"},
			"layers": [
				{"module": "ring", "name": "护盾泡", "params": {
					"radius": 28.0, "width": 3.0, "mode": "static", "rim": 0.9}},
				{"module": "glyph", "name": "六边形纹", "palette_slot": "accent", "params": {
					"radius": 25.0, "rings": 0, "star_points": 6, "star_step": 1, "star_scale": 0.9, "ticks": 0,
					"line": 1.0, "spin": 1.0, "counter": false, "pulse": 0.4, "runes": 0.3}},
				{"module": "ring", "name": "流光", "params": {
					"radius": 24.0, "width": 2.0, "mode": "static", "segments": 3, "gap": 0.75, "spin": 1.0}},
			],
		},
		{
			"id": "charge", "name": "蓄力", "category": "magic",
			"description": "循环的蓄力：四周的光点被吸向中心，能量核一下下脉动，外圈的环不断收拢。",
			"globals": {"canvas_w": 72, "canvas_h": 72, "frames": 12, "fps": 12, "loop": true,
				"theme": "energy", "palette_main": "energy", "palette_accent": "thunder", "palette_smoke": "smoke",
				"soft": 0.35, "outline": "none"},
			"layers": [
				{"module": "ring", "name": "收拢环", "palette_slot": "accent", "params": {
					"radius": 30.0, "width": 2.0, "thin": 0.0, "start": 0.15, "mode": "contract", "easing": "in_quad"}},
				{"module": "particles", "name": "汇聚光点", "palette_slot": "accent", "params": {
					"count": 24, "shape": "streak", "size": 2.0, "size_end": 1.2, "emit_shape": "ring", "emit_radius": 8.0,
					"flow": "gather", "speed": 70.0, "speed_random": 0.3, "emit_mode": "stream", "emit_time": 1.0,
					"life": 0.45, "cool": 0.0, "streak_len": 1.0}},
				{"module": "orb", "name": "能量核", "params": {
					"shape": "round", "core": 3.0, "halo": 6.0, "trail": 0.0, "pulse": 0.6, "pulse_speed": 3}},
			],
		},
		{
			"id": "magic_circle", "name": "魔法阵", "category": "magic",
			"description": "循环旋转的地面魔法阵：双环 + 六芒星 + 刻度，内外圈反向转动，周围升起光点。",
			"globals": {"canvas_w": 96, "canvas_h": 56, "frames": 24, "fps": 12, "loop": true, "origin_x": 0.5, "origin_y": 0.55,
				"theme": "arcane", "palette_main": "arcane", "palette_accent": "rose", "palette_smoke": "smoke",
				"soft": 0.15, "outline": "none"},
			"layers": [
				{"module": "glyph", "name": "法阵", "follow_dir": false, "params": {
					"radius": 42.0, "rings": 2, "ring_gap": 6.0, "star_points": 6, "star_step": 2, "star_scale": 0.92,
					"ticks": 24, "tick_len": 3.0, "line": 1.0, "squash": 0.45, "spin": 1.0, "counter": true,
					"pulse": 0.3, "runes": 0.5}},
				{"module": "particles", "name": "符文光点", "follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 10, "shape": "star", "size": 2.0, "size_end": 0.5, "emit_shape": "line", "emit_radius": 34.0,
					"spread": 20.0, "speed": 25.0, "gravity": -20.0, "drag": 1.0, "emit_mode": "stream", "emit_time": 1.0,
					"life": 0.5, "cool": 0.1, "flicker": 0.3}},
			],
		},
		{
			"id": "summon_circle", "name": "召唤阵展开", "category": "magic",
			"description": "一次性的召唤：五芒星法阵一笔笔画出来，随后升起光柱和光丝，最后一起消散。原点在地面中心。",
			"globals": {"canvas_w": 96, "canvas_h": 120, "frames": 18, "fps": 15, "origin_x": 0.5, "origin_y": 0.82,
				"theme": "arcane", "palette_main": "arcane", "palette_accent": "holy", "palette_smoke": "smoke",
				"soft": 0.2, "outline": "none"},
			"layers": [
				{"module": "glyph", "name": "召唤阵", "follow_dir": false, "params": {
					"radius": 42.0, "rings": 2, "ring_gap": 6.0, "star_points": 5, "star_step": 2, "star_scale": 0.95,
					"ticks": 20, "tick_len": 3.0, "line": 1.0, "squash": 0.4, "spin": 0.25, "counter": true,
					"draw_time": 0.45, "fade_out": 0.2, "pulse": 0.3, "runes": 0.5}},
				{"module": "beam", "name": "召唤光柱", "palette_slot": "accent", "follow_dir": false, "angle_offset": 270.0,
						"t_start": 0.4, "params": {
					"length": 92.0, "width": 20.0, "core": 0.3, "taper": 0.15, "ripple": 0.3, "base_glow": 0.5,
					"open_time": 0.25, "close_time": 0.35, "flow": 3, "streaks": 0.6}},
				{"module": "particles", "name": "上升光丝", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"t_start": 0.45, "params": {
					"count": 18, "shape": "streak", "size": 2.0, "emit_shape": "line", "emit_radius": 30.0, "spread": 10.0,
					"speed": 130.0, "speed_random": 0.4, "drag": 0.8, "emit_mode": "stream", "emit_time": 0.6,
					"life": 0.5, "cool": 0.2, "streak_len": 0.8}},
			],
		},
		# ---------------------------------------------------------------- 环境与通用
		{
			"id": "landing_dust", "name": "落地尘土", "category": "env",
			"description": "跳跃落地：脚下往左右两边滚开的尘团 + 溅起又落下的小石子 + 贴地的一圈冲击线。原点在脚下。",
			"globals": {"canvas_w": 80, "canvas_h": 40, "frames": 10, "fps": 15, "origin_x": 0.5, "origin_y": 0.8,
				"theme": "dust", "palette_main": "sand", "palette_accent": "dust", "palette_smoke": "smoke"},
			"layers": [
				{"module": "ring", "name": "冲击线", "follow_dir": false, "outline": false, "t_end": 0.45, "params": {
					"radius": 30.0, "width": 2.0, "thin": 0.5, "start": 0.3, "squash": 0.2, "easing": "out_cubic"}},
				{"module": "particles", "name": "尘团", "palette_slot": "main", "follow_dir": false, "angle_offset": 348.0,
						"dissolve": "shrink", "params": {
					"count": 14, "shape": "puff", "size": 7.0, "size_end": 1.6, "size_random": 0.5, "mirror": true,
					"spread": 24.0, "speed": 115.0, "speed_random": 0.6, "gravity": -20.0, "drag": 3.5,
					"emit_time": 0.05, "life": 1.0, "life_random": 0.1, "cool": 0.2}},
				{"module": "particles", "name": "小石子", "follow_dir": false, "angle_offset": 305.0, "params": {
					"count": 6, "shape": "square", "size": 2.0, "size_end": 1.0, "mirror": true, "spread": 40.0,
					"speed": 75.0, "gravity": 240.0, "drag": 0.8, "life": 0.6, "cool": 0.2, "use_floor": true, "floor_y": 1.0}},
			],
		},
		{
			"id": "run_dust", "name": "跑步扬尘", "category": "env",
			"description": "跑步、急停时脚后跟扬起的一小股尘土。方向 = 跑步方向（朝左跑用「水平翻转」）。原点在脚下。",
			"globals": {"canvas_w": 44, "canvas_h": 28, "frames": 8, "fps": 15, "origin_x": 0.7, "origin_y": 0.85,
				"theme": "dust", "palette_main": "sand", "palette_accent": "dust", "palette_smoke": "smoke"},
			"layers": [
				{"module": "particles", "name": "扬尘", "palette_slot": "main", "angle_offset": 200.0, "dissolve": "shrink", "params": {
					"count": 6, "shape": "puff", "size": 5.0, "size_end": 1.4, "size_random": 0.5, "spread": 40.0,
					"speed": 45.0, "speed_random": 0.5, "gravity": -15.0, "drag": 3.0, "emit_time": 0.1,
					"life": 0.9, "life_random": 0.15, "cool": 0.2}},
				{"module": "particles", "name": "沙粒", "palette_slot": "main", "angle_offset": 215.0, "params": {
					"count": 4, "shape": "pixel", "size": 1.0, "size_end": 1.0, "spread": 30.0, "speed": 60.0,
					"gravity": 160.0, "drag": 1.0, "life": 0.55, "cool": 0.3, "use_floor": true, "floor_y": 1.0}},
			],
		},
		{
			"id": "smoke_bomb", "name": "烟雾弹", "category": "env",
			"description": "烟雾弹、遁术、出场：一下爆闪，随后翻滚的浓烟和向四周滚开的烟团慢慢散去。原点在地面。",
			"globals": {"canvas_w": 96, "canvas_h": 96, "frames": 16, "fps": 12, "origin_x": 0.5, "origin_y": 0.62,
				"theme": "smoke", "palette_main": "smoke", "palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "blob", "name": "浓烟", "dissolve": "shrink", "params": {
					"puffs": 8, "radius": 19.0, "spread": 15.0, "start": 0.35, "squash": 0.85, "noise": 0.55,
					"noise_scale": 1.0, "rise": 14.0, "heat": 0.85, "cool": 0.3, "core": 0.35, "burn": 0.85,
					"expand_time": 0.35, "stagger": 0.2}},
				{"module": "particles", "name": "四散烟团", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "dissolve": "shrink", "params": {
					"count": 12, "shape": "puff", "size": 10.0, "size_end": 1.5, "size_random": 0.4, "spread": 220.0,
					"speed": 115.0, "speed_random": 0.35, "gravity": -12.0, "drag": 3.0, "emit_time": 0.05,
					"life": 0.85, "life_random": 0.25, "cool": 0.35}},
				{"module": "burst", "name": "爆闪", "palette_slot": "accent", "follow_dir": false, "outline": false, "t_end": 0.3, "params": {
					"rays": 8, "length": 16.0, "width": 3.0, "ray_time": 0.8, "flash": "star", "flash_size": 12.0,
					"flash_time": 0.6}},
			],
		},
		{
			"id": "smoke_bomb_v2", "name": "烟雾弹·升级版", "category": "env",
			"description": "按 pixelfx 的做法升级的试验版：啪地一闪，浓烟贴着地面向两侧喷涌，翻滚着鼓成一团把人整个遮住，再慢慢变稀、散成缕缕轻烟。烟是真正的半透明，带紫灰色调。原点在地面。",
			"globals": {"canvas_w": 128, "canvas_h": 112, "frames": 56, "fps": 20, "origin_x": 0.5, "origin_y": 0.82,
				"alpha_levels": 4, "outline": "none", "theme": "custom",
				"palette_main": PackedColorArray([Color("1c1828"), Color("2f2a42"), Color("4a4463"), Color("6c6688"), Color("958fb0"), Color("c6c1da")]),
				"palette_accent": "spark", "palette_smoke": "smoke"},
			"layers": [
				{"module": "particles", "name": "贴地喷涌", "palette_slot": "main", "follow_dir": false, "angle_offset": 352.0,
						"offset_y": -4.0, "dissolve": "translucent", "params": {
					"count": 18, "shape": "smoke", "size": 11.0, "size_end": 2.3, "size_random": 0.4, "mirror": true,
					"spread": 24.0, "speed": 230.0, "speed_random": 0.5, "gravity": -10.0, "drag": 4.0, "emit_time": 0.12,
					"life": 0.7, "life_random": 0.3, "bright": 1.0, "cool": 0.35, "opacity": 1.0, "thin": 0.5, "soft_edge": 0.4}},
				{"module": "particles", "name": "翻滚浓烟", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -16.0, "dissolve": "translucent", "t_start": 0.02, "params": {
					"count": 22, "shape": "smoke", "size": 16.0, "size_end": 2.1, "size_random": 0.4, "squash": 0.75,
					"emit_shape": "circle", "emit_radius": 10.0, "spread": 360.0, "speed": 95.0, "speed_random": 0.5,
					"gravity": -35.0, "drag": 3.0, "sway": 2.0, "emit_time": 0.15, "life": 0.8, "life_random": 0.2,
					"bright": 1.0, "cool": 0.35, "opacity": 1.0, "thin": 0.5, "soft_edge": 0.3}},
				{"module": "particles", "name": "缕缕轻烟", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -28.0, "dissolve": "translucent", "t_start": 0.3, "params": {
					"count": 20, "shape": "puff", "size": 10.0, "size_end": 2.0, "size_random": 0.5, "emit_shape": "box",
					"emit_radius": 26.0, "emit_height": 20.0, "spread": 40.0, "speed": 40.0, "speed_random": 0.5,
					"gravity": -40.0, "drag": 1.5, "sway": 4.0, "emit_mode": "stream", "emit_time": 0.45, "life": 0.5,
					"life_random": 0.3, "bright": 1.0, "cool": 0.2, "opacity": 0.7, "thin": 0.9, "soft_edge": 0.8}},
				{"module": "particles", "name": "引信火星", "palette_slot": "accent", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -3.0, "t_end": 0.25, "params": {
					"count": 14, "shape": "streak", "size": 1.5, "size_end": 0.7, "spread": 160.0, "speed": 260.0,
					"speed_random": 0.6, "gravity": 1200.0, "drag": 2.0, "use_floor": true, "floor_y": 3.0, "bounce": 0.35,
					"emit_time": 0.03, "life": 0.5, "life_random": 0.4, "cool": 0.7, "streak_len": 0.6, "glow": 0.4, "glow_size": 4.0}},
				{"module": "burst", "name": "爆闪", "palette_slot": "accent", "outline": false, "follow_dir": false,
						"offset_y": -6.0, "t_end": 0.08, "params": {
					"rays": 8, "length": 16.0, "width": 2.0, "length_random": 0.4, "inner": 0.2, "ray_time": 0.5, "detach": 0.7,
					"flash": "star", "flash_size": 12.0, "flash_time": 0.5, "light": 0.8, "light_size": 36.0}},
			],
		},
		{
			"id": "water_splash", "name": "落水水花", "category": "env",
			"description": "掉进水里、石头入水：向上溅起的水柱和水滴落回水面消失，水面荡开两圈涟漪。原点在水面。",
			"globals": {"canvas_w": 72, "canvas_h": 64, "frames": 12, "fps": 15, "origin_x": 0.5, "origin_y": 0.8,
				"theme": "water", "palette_main": "water", "palette_accent": "ice", "palette_smoke": "smoke"},
			"layers": [
				{"module": "ring", "name": "涟漪", "follow_dir": false, "outline": false, "params": {
					"radius": 30.0, "width": 2.0, "thin": 0.5, "start": 0.15, "squash": 0.25, "rings": 2,
					"ring_delay": 0.25, "easing": "out_cubic"}},
				{"module": "particles", "name": "水柱", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "params": {
					"count": 4, "shape": "streak", "size": 5.0, "size_end": 2.0, "spread": 12.0, "speed": 170.0,
					"speed_random": 0.3, "gravity": 400.0, "drag": 0.3, "emit_time": 0.08, "life": 1.0, "life_random": 0.0,
					"cool": 0.0, "streak_len": 0.5, "use_floor": true, "floor_y": 0.0}},
				{"module": "particles", "name": "水滴", "palette_slot": "main", "outline": true, "follow_dir": false,
						"angle_offset": 270.0, "params": {
					"count": 12, "shape": "disc", "size": 3.5, "size_end": 1.5, "spread": 50.0, "speed": 135.0,
					"speed_random": 0.5, "gravity": 380.0, "drag": 0.8, "emit_time": 0.1, "life": 1.0, "life_random": 0.1,
					"cool": 0.1, "use_floor": true, "floor_y": 0.0}},
				{"module": "particles", "name": "飞沫", "follow_dir": false, "angle_offset": 270.0, "params": {
					"count": 10, "shape": "square", "size": 1.5, "size_end": 1.0, "spread": 90.0, "speed": 100.0,
					"gravity": 300.0, "drag": 0.8, "emit_time": 0.1, "life": 0.8, "cool": 0.1, "use_floor": true, "floor_y": 2.0}},
			],
		},
		{
			"id": "pickup_sparkle", "name": "拾取闪光", "category": "env",
			"description": "捡到金币、道具、升级时的一闪：八角星芒 + 旁边跟着再闪一下的小星 + 往上飘的闪粉。",
			"globals": {"canvas_w": 48, "canvas_h": 48, "frames": 8, "fps": 15,
				"theme": "holy", "palette_main": "holy", "palette_accent": "spark", "palette_smoke": "dust",
				"outline": "none"},
			"layers": [
				{"module": "burst", "name": "星芒", "follow_dir": false, "t_end": 0.75, "params": {
					"rays": 8, "length": 18.0, "width": 2.0, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.6,
					"inner": 0.05, "ray_time": 0.7, "detach": 0.0, "flash": "star", "flash_size": 8.0, "flash_time": 0.5}},
				{"module": "burst", "name": "余闪", "palette_slot": "accent", "follow_dir": false, "t_start": 0.45,
						"offset_x": 7.0, "offset_y": -6.0, "params": {
					"rays": 4, "length": 7.0, "width": 1.5, "length_random": 0.0, "angle_random": 0.0, "alternate": 0.0,
					"inner": 0.05, "ray_time": 0.9, "detach": 0.0, "flash": "star", "flash_size": 4.0, "flash_time": 0.8}},
				{"module": "particles", "name": "闪粉", "palette_slot": "main", "follow_dir": false, "params": {
					"count": 8, "shape": "star", "size": 3.0, "size_end": 0.4, "speed": 45.0, "gravity": -30.0, "drag": 1.5,
					"emit_time": 0.1, "life": 0.9, "life_random": 0.05, "cool": 0.1, "flicker": 0.25}},
			],
		},
		{
			"id": "teleport_beam", "name": "传送光柱", "category": "env",
			"description": "传送、复活、出生点：地面光圈先收拢，随后一道光柱冲天而起，光点往上飞，最后光柱收成一条线消失。原点在脚下。",
			"globals": {"canvas_w": 64, "canvas_h": 112, "frames": 16, "fps": 15, "origin_x": 0.5, "origin_y": 0.86,
				"theme": "energy", "palette_main": "energy", "palette_accent": "thunder", "palette_smoke": "smoke",
				"outline": "none", "soft": 0.3},
			"layers": [
				{"module": "ring", "name": "地面光圈", "follow_dir": false, "t_end": 0.45, "params": {
					"radius": 24.0, "width": 3.0, "thin": 0.3, "start": 0.3, "squash": 0.3, "mode": "contract", "easing": "in_quad"}},
				{"module": "beam", "name": "光柱", "follow_dir": false, "angle_offset": 270.0, "t_start": 0.15, "params": {
					"length": 84.0, "width": 18.0, "core": 0.35, "taper": 0.3, "ripple": 0.25, "base_glow": 0.4,
					"open_time": 0.15, "close_time": 0.4, "easing": "out_expo", "flow": 4, "pulse": 0.2, "streaks": 0.5}},
				{"module": "particles", "name": "上升光点", "follow_dir": false, "angle_offset": 270.0, "t_start": 0.15, "params": {
					"count": 16, "shape": "streak", "size": 1.5, "size_end": 1.0, "emit_shape": "line", "emit_radius": 14.0,
					"spread": 6.0, "speed": 160.0, "speed_random": 0.5, "drag": 0.3, "emit_mode": "stream", "emit_time": 0.6,
					"life": 0.45, "cool": 0.3, "flicker": 0.2, "streak_len": 0.6}},
			],
		},
		{
			"id": "dissolve_away", "name": "消散", "category": "env",
			"description": "角色死亡、灵体消失：整个身体范围里不断冒出微粒，一边摇摆一边往上飘散。叠在角色身上用，原点在脚下。",
			"globals": {"canvas_w": 48, "canvas_h": 72, "frames": 16, "fps": 12, "origin_x": 0.5, "origin_y": 0.85,
				"theme": "arcane", "palette_main": "arcane", "palette_accent": "rose", "palette_smoke": "smoke",
				"outline": "none"},
			"layers": [
				{"module": "particles", "name": "飘散微粒", "palette_slot": "main", "follow_dir": false, "angle_offset": 270.0,
						"offset_y": -17.0, "params": {
					"count": 60, "shape": "square", "size": 2.5, "size_end": 0.5, "size_random": 0.5, "emit_shape": "box",
					"emit_radius": 10.0, "emit_height": 34.0, "spread": 30.0, "speed": 45.0, "speed_random": 0.6,
					"gravity": -40.0, "drag": 1.0, "sway": 2.5, "emit_mode": "stream", "emit_time": 0.7, "life": 0.45,
					"life_random": 0.4, "cool": 0.5, "flicker": 0.15}},
				{"module": "particles", "name": "亮点", "follow_dir": false, "angle_offset": 270.0, "offset_y": -17.0, "params": {
					"count": 14, "shape": "pixel", "size": 1.0, "size_end": 1.0, "emit_shape": "box", "emit_radius": 10.0,
					"emit_height": 34.0, "spread": 20.0, "speed": 60.0, "gravity": -30.0, "drag": 1.0, "sway": 1.5,
					"emit_mode": "stream", "emit_time": 0.7, "life": 0.35, "cool": 0.2, "flicker": 0.4}},
			],
		},
		{
			"id": "dash_trail", "name": "冲刺残影", "category": "env",
			"description": "冲刺、闪避：身后拉出几道渐隐的速度残影，起步的地方扬起尘土。方向 = 冲刺方向，原点在角色身上。",
			"globals": {"canvas_w": 96, "canvas_h": 40, "frames": 8, "fps": 15, "origin_x": 0.8, "origin_y": 0.55,
				"theme": "steel", "palette_main": "steel", "palette_accent": "spark", "palette_smoke": "sand"},
			"layers": [
				{"module": "particles", "name": "起步尘土", "palette_slot": "smoke", "angle_offset": 200.0, "dissolve": "shrink",
						"offset_x": -52.0, "offset_y": 10.0, "params": {
					"count": 6, "shape": "puff", "size": 6.0, "size_end": 1.4, "size_random": 0.5, "spread": 40.0,
					"speed": 35.0, "speed_random": 0.5, "gravity": -15.0, "drag": 3.0, "emit_time": 0.05,
					"life": 0.9, "life_random": 0.2, "cool": 0.3}},
				{"module": "streak", "name": "残影", "offset_x": -30.0, "params": {
					"count": 5, "length": 60.0, "width": 7.0, "spread": 26.0, "length_random": 0.5, "main_boost": 0.5,
					"taper": 0.6, "travel": 10.0, "stagger": 0.25, "head": 0.0}},
				{"module": "particles", "name": "速度线", "palette_slot": "main", "angle_offset": 180.0, "offset_x": -8.0, "params": {
					"count": 8, "shape": "streak", "size": 1.0, "size_end": 1.0, "emit_shape": "line", "emit_radius": 14.0,
					"spread": 0.0, "speed": 120.0, "drag": 0.5, "emit_mode": "stream", "emit_time": 0.5, "life": 0.5,
					"cool": 0.3, "streak_len": 1.2}},
			],
		},
	]
