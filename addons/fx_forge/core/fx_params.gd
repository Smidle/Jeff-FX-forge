@tool
extends RefCounted
## 参数说明表（schema）工具。每个参数是一个 Dictionary：
##   id / kind / label（中文）/ label_en / default / group / tip / advanced
##   数值类另有 min / max / step / unit / scale（true = 跟随整体缩放）
##   枚举类另有 options = [[id, 中文名], ...]，值存字符串 id
## 界面、默认值、校验、预设迁移都从这张表派生。

enum Kind { NUM, INT, BOOL, ENUM, COLOR, ANGLE, PALETTE, SLOT }

const SLOT_OPTIONS := [["main", "主色板"], ["accent", "辅色板"], ["smoke", "烟尘色板"]]


static func num(id: String, label: String, label_en: String, min_v: float, max_v: float, default_v: float, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.NUM, label, label_en, default_v, {"min": min_v, "max": max_v, "step": 0.01}, opts)


static func integer(id: String, label: String, label_en: String, min_v: int, max_v: int, default_v: int, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.INT, label, label_en, default_v, {"min": min_v, "max": max_v, "step": 1}, opts)


static func boolean(id: String, label: String, label_en: String, default_v: bool, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.BOOL, label, label_en, default_v, {}, opts)


static func choice(id: String, label: String, label_en: String, options: Array, default_id: String, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.ENUM, label, label_en, default_id, {"options": options}, opts)


static func color(id: String, label: String, label_en: String, default_v: Color, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.COLOR, label, label_en, default_v, {}, opts)


## 角度（度），0 = 朝右，顺时针为正
static func angle(id: String, label: String, label_en: String, default_v: float, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.ANGLE, label, label_en, default_v, {"min": 0.0, "max": 360.0, "step": 1.0, "unit": "°"}, opts)


## 色板：值是内置色板 id（String）或自定义颜色（PackedColorArray，从暗到亮）
static func palette(id: String, label: String, label_en: String, default_id: String, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.PALETTE, label, label_en, default_id, {}, opts)


## 色板槽：图层使用哪个全局色板
static func slot(id: String, label: String, label_en: String, default_id: String, opts: Dictionary = {}) -> Dictionary:
	return _make(id, Kind.SLOT, label, label_en, default_id, {"options": SLOT_OPTIONS}, opts)


static func _make(id: String, kind: int, label: String, label_en: String, default_v: Variant, base: Dictionary, opts: Dictionary) -> Dictionary:
	var d := {
		"id": id, "kind": kind, "label": label, "label_en": label_en, "default": default_v,
		"group": "", "tip": "", "advanced": false, "unit": "", "scale": false,
	}
	d.merge(base, true)
	d.merge(opts, true)
	return d


static func find(defs: Array, id: String) -> Dictionary:
	for d: Dictionary in defs:
		if d["id"] == id:
			return d
	return {}


static func defaults(defs: Array) -> Dictionary:
	var out := {}
	for d: Dictionary in defs:
		out[d["id"]] = _copy(d["default"])
	return out


## 把任意来源的值校正成合法值；不合法就回到默认值
static func normalize_value(d: Dictionary, v: Variant) -> Variant:
	var t := typeof(v)
	var is_number := t == TYPE_FLOAT or t == TYPE_INT
	match int(d["kind"]):
		Kind.NUM:
			return clampf(float(v), float(d["min"]), float(d["max"])) if is_number else d["default"]
		Kind.ANGLE:
			return fposmod(float(v), 360.0) if is_number else d["default"]
		Kind.INT:
			return clampi(roundi(float(v)), int(d["min"]), int(d["max"])) if is_number else d["default"]
		Kind.BOOL:
			if t == TYPE_BOOL:
				return v
			return v != 0 if is_number else d["default"]
		Kind.ENUM, Kind.SLOT:
			if t == TYPE_STRING or t == TYPE_STRING_NAME:
				var s := str(v)
				for o: Array in d["options"]:
					if o[0] == s:
						return s
			return d["default"]
		Kind.COLOR:
			if t == TYPE_COLOR:
				return v
			if t == TYPE_STRING and Color.html_is_valid(v):
				return Color.html(v)
			return d["default"]
		Kind.PALETTE:
			if t == TYPE_PACKED_COLOR_ARRAY and (v as PackedColorArray).size() >= 2:
				return (v as PackedColorArray).duplicate()
			if t == TYPE_STRING or t == TYPE_STRING_NAME:
				return str(v)
			return d["default"]
	return v


## 按说明表补齐缺省、校正非法值，返回新字典（多余的键会被丢弃）
static func normalize(defs: Array, values: Dictionary) -> Dictionary:
	var out := {}
	for d: Dictionary in defs:
		var id: String = d["id"]
		out[id] = normalize_value(d, values[id]) if values.has(id) else _copy(d["default"])
	return out


## 返回按整体缩放换算后的参数副本（只换算 scale = true 的参数）
static func apply_scale(defs: Array, values: Dictionary, s: float) -> Dictionary:
	var out := values.duplicate()
	if is_equal_approx(s, 1.0):
		return out
	for d: Dictionary in defs:
		if not d.get("scale", false):
			continue
		var id: String = d["id"]
		if int(d["kind"]) == Kind.INT:
			out[id] = maxi(1, roundi(float(out[id]) * s))
		else:
			out[id] = float(out[id]) * s
	return out


static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	if v is PackedColorArray:
		return (v as PackedColorArray).duplicate()
	return v
