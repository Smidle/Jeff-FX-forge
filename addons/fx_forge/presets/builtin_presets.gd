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
	]
