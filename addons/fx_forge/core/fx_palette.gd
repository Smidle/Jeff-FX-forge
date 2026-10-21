@tool
extends RefCounted
## 内置色板（从暗到亮）与配色主题，以及抖动阈值表。
## 色板都是自行设计的色相偏移色阶：暗部偏冷、亮部偏暖。

## id → [中文名, 英文名, 颜色（暗→亮）]
const PALETTES := {
	"steel": ["钢铁", "Steel", ["1a1c2c", "333c57", "566c86", "94b0c2", "d4e3ee", "ffffff"]],
	"spark": ["火花", "Spark", ["5a2412", "a4481a", "e08a24", "ffcf4a", "fff3b0", "ffffff"]],
	"fire": ["火焰", "Fire", ["2c0d1c", "6a1424", "aa281e", "dc5418", "f6962a", "ffd55a", "fff5c8"]],
	"ice": ["冰霜", "Ice", ["101c3e", "1e467e", "327ebe", "66bce8", "b0e8ff", "ffffff"]],
	"thunder": ["雷电", "Thunder", ["1a0e44", "382896", "5060de", "7eaeff", "c6eaff", "ffffff"]],
	"poison": ["毒素", "Poison", ["1c112e", "3a1d4c", "3e6a1e", "6cac22", "b2e23e", "eefa9c"]],
	"holy": ["神圣", "Holy", ["48260e", "985814", "da9e2a", "ffd65c", "fff2b6", "ffffff"]],
	"shadow": ["暗影", "Shadow", ["0a0612", "220f38", "461f68", "7a35a6", "b66cde", "eccaff"]],
	"blood": ["鲜血", "Blood", ["1c0408", "4a0a14", "8a1422", "c82832", "f0605a"]],
	"nature": ["自然", "Nature", ["0e2214", "1c4c24", "388630", "70c03c", "c0ea78", "f2ffd0"]],
	"water": ["水流", "Water", ["0a1634", "133a76", "1e6cb6", "3caade", "90dcf4", "ffffff"]],
	"arcane": ["奥术", "Arcane", ["150a38", "321888", "5a38d4", "9278ff", "d0c2ff", "ffffff"]],
	"energy": ["能量", "Energy", ["032026", "084e5c", "0e909e", "32d2cc", "9cfeee", "ffffff"]],
	"heal": ["治愈", "Heal", ["0c281a", "185c38", "2c9e5e", "5cda88", "b2ffc6", "ffffff"]],
	"smoke": ["烟雾", "Smoke", ["1a1a24", "363644", "5c5c6a", "8c8c98", "c2c2ca"]],
	"dust": ["尘土", "Dust", ["2a190e", "543420", "845e3a", "b68e5c", "e0c598"]],
	"ink": ["水墨", "Ink", ["0a0a0e", "1a1a22", "2e2e38", "4a4a56", "727280"]],
	"rose": ["樱花", "Rose", ["380b24", "781c48", "c03872", "ee689e", "ffb2ce", "fff0f6"]],
}

## id → [中文名, 英文名, 主色板, 辅色板, 烟尘色板]
const THEMES := {
	"steel": ["钢铁", "Steel", "steel", "spark", "smoke"],
	"fire": ["火焰", "Fire", "fire", "spark", "smoke"],
	"ice": ["冰霜", "Ice", "ice", "water", "smoke"],
	"thunder": ["雷电", "Thunder", "thunder", "energy", "smoke"],
	"poison": ["毒素", "Poison", "poison", "nature", "smoke"],
	"holy": ["神圣", "Holy", "holy", "spark", "dust"],
	"shadow": ["暗影", "Shadow", "shadow", "arcane", "smoke"],
	"blood": ["鲜血", "Blood", "blood", "fire", "smoke"],
	"nature": ["自然", "Nature", "nature", "heal", "dust"],
	"water": ["水流", "Water", "water", "ice", "smoke"],
	"arcane": ["奥术", "Arcane", "arcane", "rose", "smoke"],
	"energy": ["能量", "Energy", "energy", "thunder", "smoke"],
	"heal": ["治愈", "Heal", "heal", "holy", "dust"],
	"ink": ["水墨", "Ink", "ink", "steel", "smoke"],
	"rose": ["樱花", "Rose", "rose", "holy", "smoke"],
}

## 4×4 Bayer 阈值（0~1）：按 ((y & 3) << 2) | (x & 3) 取值
static var BAYER4: PackedFloat32Array = _bayer4()
## 2×2 Bayer 平铺成 4×4，取值方式同上
static var BAYER2: PackedFloat32Array = _bayer2()
## 全 0.5：不抖动
static var FLAT: PackedFloat32Array = _flat()


static func _bayer4() -> PackedFloat32Array:
	var m := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	var out := PackedFloat32Array()
	for v: int in m:
		out.append((float(v) + 0.5) / 16.0)
	return out


static func _bayer2() -> PackedFloat32Array:
	var m := [0, 2, 3, 1]
	var out := PackedFloat32Array()
	for y in 4:
		for x in 4:
			out.append((float(m[(y & 1) * 2 + (x & 1)]) + 0.5) / 4.0)
	return out


static func _flat() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(16)
	out.fill(0.5)
	return out


static func dither_table(id: String) -> PackedFloat32Array:
	match id:
		"bayer2":
			return BAYER2
		"bayer4":
			return BAYER4
	return FLAT


## 色板值（内置 id 或自定义颜色数组）→ 颜色数组
static func colors_of(value: Variant) -> PackedColorArray:
	if value is PackedColorArray and (value as PackedColorArray).size() >= 2:
		return value
	var id := str(value)
	if not PALETTES.has(id):
		id = "steel"
	var out := PackedColorArray()
	for hex: String in PALETTES[id][2]:
		out.append(Color.html(hex))
	return out


static func palette_name(value: Variant) -> String:
	if value is PackedColorArray:
		return "自定义"
	var id := str(value)
	return PALETTES[id][0] if PALETTES.has(id) else id


static func palette_options() -> Array:
	var out: Array = []
	for id: String in PALETTES:
		out.append([id, PALETTES[id][0]])
	return out


static func theme_options() -> Array:
	var out: Array = []
	for id: String in THEMES:
		out.append([id, THEMES[id][0]])
	out.append(["custom", "自定义"])
	return out


## 主题 → {main, accent, smoke} 三个色板 id；未知主题返回空字典
static func theme_slots(theme_id: String) -> Dictionary:
	if not THEMES.has(theme_id):
		return {}
	var t: Array = THEMES[theme_id]
	return {"main": t[2], "accent": t[3], "smoke": t[4]}


## 由一个颜色生成色相偏移色阶：暗部偏蓝紫、亮部偏黄
static func ramp_from_color(base: Color, steps: int = 6) -> PackedColorArray:
	steps = clampi(steps, 2, 8)
	var out := PackedColorArray()
	for i in steps:
		var k := float(i) / float(steps - 1)
		var target := 0.72 if k < 0.5 else 0.14
		var hh := _lerp_hue(base.h, target, absf(k - 0.5) * 0.35)
		var ss := clampf(base.s * (1.0 - 0.55 * pow(k, 3.0)) + 0.1 * (1.0 - k), 0.0, 1.0)
		var vv := lerpf(0.16, 1.0, pow(k, 0.8))
		out.append(Color.from_hsv(hh, ss, vv))
	return out


static func _lerp_hue(a: float, b: float, t: float) -> float:
	var d := fposmod(b - a + 0.5, 1.0) - 0.5
	return fposmod(a + d * t, 1.0)
