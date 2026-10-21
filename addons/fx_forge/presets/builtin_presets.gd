@tool
extends RefCounted
## 内置预设（只读）。用代码定义，方便维护和比较差异；在编辑器里改了会提示另存为「我的预设」。
## 每个预设：{id, name, category, description, globals, layers: [{module, name, params, ……图层设置}]}

const FxPresetUtil := preload("../core/fx_preset_util.gd")


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
			"description": "势大力沉的重击：冲击环 + 大火花 + 往下掉的碎屑。",
			"globals": {"canvas_w": 88, "canvas_h": 104, "frames": 9, "fps": 20, "origin_x": 0.5, "origin_y": 0.42,
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
			"description": "红白配色的暴击：白色星芒 + 长短交替的红色射线 + 旋转的分段环。",
			"globals": {"canvas_w": 88, "canvas_h": 88, "frames": 9, "fps": 20, "theme": "blood",
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
	]
