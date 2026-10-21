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
			"layers": [{"module": "arc", "name": "火焰刀光", "params": {
				"radius": 27.0, "thickness": 12.0, "span": 210.0, "taper": 0.6, "crescent": 0.6,
				"trail": 0.65, "sweep": 0.5, "easing": "out_cubic", "rim": 0.75, "edge_noise": 0.45, "ghosts": 1}}],
		},
		{
			"id": "slash_ice", "name": "寒冰斩", "category": "combat",
			"description": "细而锋利的冰蓝刀光，用点阵抖动和选择性描边表现冷硬质感。",
			"globals": {"canvas_w": 64, "canvas_h": 64, "frames": 9, "fps": 20, "theme": "ice",
				"palette_main": "ice", "palette_accent": "water", "palette_smoke": "smoke",
				"dither": "bayer4", "dither_strength": 0.6, "outline": "selective"},
			"layers": [{"module": "arc", "name": "冰刃", "params": {
				"radius": 26.0, "thickness": 9.0, "span": 190.0, "taper": 0.85, "crescent": 0.4,
				"trail": 0.55, "sweep": 0.5, "easing": "out_cubic", "rim": 0.8, "edge_noise": 0.25}}],
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
	]
