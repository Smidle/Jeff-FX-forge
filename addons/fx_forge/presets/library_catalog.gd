@tool
extends RefCounted
## Lightweight descriptors only. Reading the catalog never loads effect Resources.
## Candidates remain discoverable to authoring tools, but never enter the user library.

const MANIFEST := "res://addons/fx_forge/presets/expansion_catalog.json"
const LABELS := {
	"usage": {"combat": "战斗动作", "impact": "命中反馈", "area": "范围与场域", "status": "状态与恢复", "environment": "环境天气", "interaction": "机关交互", "telegraph": "预警与指示", "presentation": "演出与系统"},
	"subtype": {"slash": "斩击", "thrust": "刺击", "projectile": "远程发射", "beam": "射线", "melee": "拳掌", "movement": "位移", "light_hit": "轻击", "heavy_hit": "重击", "critical": "暴击", "block": "格挡", "shield_break": "破盾", "material_hit": "材质命中", "explosion": "爆炸", "shockwave": "冲击波", "ground_spike": "地面突刺", "persistent_area": "持续区域", "restraint": "束缚", "attraction": "吸引", "healing": "治疗", "buff": "增益", "debuff": "减益", "shield": "护盾", "charge": "蓄力", "cleanse": "净化", "fire_smoke": "火焰与烟雾", "water": "水体", "weather": "风雨雪", "flora_fauna": "植被与生物", "dust": "尘埃", "pickup": "拾取", "switch": "开关", "seal": "封印", "teleport": "传送", "summon": "召唤", "breakable": "破坏", "target": "目标标记", "cone": "扇形预警", "line": "直线预警", "radius": "范围预警", "path": "路径指示", "landing": "落点", "arrival": "登场", "vanish": "消失", "level_up": "升级", "completion": "完成反馈", "attachment": "附着装饰", "fireworks": "烟花"},
	"style": {"fine_pixel": "细腻像素", "retro_pixel": "复古像素", "painted_smooth": "手绘平滑", "toon": "卡通", "ink": "水墨", "natural_realistic": "自然写实"},
	"theme": {"wuxia": "武侠", "xianxia": "仙侠", "fantasy": "奇幻魔法", "scifi": "科幻科技", "nature": "自然环境", "dark": "暗黑", "universal": "通用"},
	"elements": {"physical": "物理", "fire": "火", "ice": "冰", "water": "水", "lightning": "雷", "wind": "风", "earth": "土", "wood": "木", "poison": "毒", "light": "光", "shadow": "暗", "arcane": "奥术"},
	"method": {"drawn": "手绘素材", "procedural": "程序生成", "mixed": "混合制作"},
	"playback": {"one_shot": "单次", "loop": "持续"},
	"anchor": {"ground": "地面", "camera": "面向镜头", "direction": "沿方向"},
	"space": {"world": "世界位置", "follow": "跟随对象"},
	"battle": {"combat": "战斗用途", "non_combat": "非战斗用途"},
	"maker": {"claude": "Claude 制作", "codex": "Codex 制作", "pixelfx": "pixelfx 升级版"},
	"school": {"fist": "拳系", "blade": "刀剑系", "physical": "物理系", "spirit": "灵气系", "fire": "火系", "ice": "冰系", "water": "水系", "lightning": "雷系", "wind": "风系", "earth": "土系", "wood": "木系", "poison": "毒系", "light": "光系", "shadow": "暗系", "arcane": "奥术系", "missile": "追踪飞弹系", "fireworks": "烟花系"},
}
## battle and school are browser groupings derived from usage/subtype/elements.
## They are never written into metadata, so saved presets and recipes stay unchanged.
const DERIVED_FACETS := ["battle", "school", "maker"]
## 追踪飞弹配方：沿用三维运行时（legacy），来源算作 Claude 制作。
const MISSILE_IDS := ["missile_spirit_sword", "missile_fireball", "missile_ice_arrow", "missile_shadow_arrow"]
## 按 pixelfx 方法升级的试验版：和原版并列，来源单独算作「pixelfx 升级版」，不混在 Claude 制作里
const PIXELFX_IDS := ["slash_basic_v2", "explosion_small_v2", "explosion_big_v2", "ice_burst_v2", "smoke_bomb_v2"]
const BATTLE_USAGES := ["combat", "impact", "area", "status", "telegraph"]
const USAGE_SUBTYPES := {
	"combat": ["slash", "thrust", "projectile", "beam", "melee", "movement"],
	"impact": ["light_hit", "heavy_hit", "critical", "block", "shield_break", "material_hit"],
	"area": ["explosion", "shockwave", "ground_spike", "persistent_area", "restraint", "attraction"],
	"status": ["healing", "buff", "debuff", "shield", "charge", "cleanse"],
	"environment": ["fire_smoke", "water", "weather", "flora_fauna", "dust"],
	"interaction": ["pickup", "switch", "seal", "teleport", "summon", "breakable"],
	"telegraph": ["target", "cone", "line", "radius", "path", "landing"],
	"presentation": ["arrival", "vanish", "level_up", "completion", "attachment", "fireworks"],
}

## Legacy IDs are preserved; these descriptors do not change rendering or recipes.
const CLASSIC_GROUPS := {
	"environment/fire_smoke": ["smoke", "campfire", "procedural_flame"],
	"environment/weather": ["rain"], "environment/flora_fauna": ["fireflies"],
	"interaction/teleport": ["portal", "xianxia_blink"],
	"impact/block": ["wuxia_parry", "wuxia_counter"],
	"combat/movement": ["wuxia_dust", "wuxia_dash"],
	"combat/melee": ["wuxia_palm"], "combat/thrust": ["wuxia_pierce"],
	"impact/heavy_hit": ["wuxia_crush"],
	"combat/projectile": ["wuxia_needle", "wuxia_pixelstream", "xianxia_sword", "magic_missile", "magic_shadow", "missile_spirit_sword", "missile_fireball", "missile_ice_arrow", "missile_shadow_arrow"],
	"combat/slash": ["wuxia_returnblade"], "status/debuff": ["wuxia_acupoint"],
	"area/persistent_area": ["wuxia_smokebomb", "xianxia_swordarray"],
	"area/attraction": ["magic_voidvortex"],
	"area/shockwave": ["wuxia_groundwave", "magic_frostnova", "magic_water"],
	"area/explosion": ["xianxia_talisman", "magic_flare"],
	"impact/light_hit": ["xianxia_lightning", "xianxia_arc", "magic_icefall"],
	"status/charge": ["xianxia_charge"],
	"status/healing": ["xianxia_lotus", "xianxia_spiritbutterfly", "magic_heal", "magic_siphon"],
	"area/restraint": ["xianxia_seal", "magic_briar", "magic_icecage"],
	"status/buff": ["xianxia_feather", "xianxia_meridian"], "status/shield": ["xianxia_bell"],
	"area/ground_spike": ["magic_earth"],
}
const PIXEL_GROUPS := {
	"combat/slash": ["slash_basic", "slash_basic_v2", "slash_fire", "slash_ice", "slash_shadow", "slash_spin", "slash_ink"],
	"combat/thrust": ["thrust"],
	"impact/heavy_hit": ["hit_heavy"], "impact/critical": ["hit_crit"], "impact/block": ["block_sparks"],
	"area/shockwave": ["ground_shockwave", "energy_ring"],
	"area/explosion": ["explosion_small", "explosion_small_v2", "explosion_big", "explosion_big_v2", "explosion_poison", "ice_burst", "ice_burst_v2"],
	"environment/fire_smoke": ["campfire", "torch", "blue_flame", "smoke_bomb", "smoke_bomb_v2"],
	"impact/light_hit": ["hit_basic", "lightning_strike", "electric_arc", "missile_hit_fire", "missile_hit_ice", "missile_hit_shadow", "missile_hit_sword"],
	"combat/projectile": ["fireball_shot", "magic_missile"],
	"status/healing": ["heal"], "status/buff": ["buff_aura"], "status/shield": ["shield"], "status/charge": ["charge"],
	"interaction/summon": ["magic_circle", "summon_circle"],
	"environment/dust": ["landing_dust", "run_dust"], "environment/water": ["water_splash"],
	"interaction/pickup": ["pickup_sparkle"], "interaction/teleport": ["teleport_beam"],
	"presentation/vanish": ["dissolve_away"], "combat/movement": ["dash_trail"],
}
const GROUND_IDS := ["portal", "rain", "wuxia_dust", "wuxia_dash", "wuxia_groundwave", "xianxia_lotus", "xianxia_seal", "xianxia_blink", "xianxia_swordarray", "magic_frostnova", "magic_water", "magic_earth", "magic_briar", "magic_icecage", "magic_voidvortex"]
const DIRECTION_IDS := ["wuxia_palm", "wuxia_pierce", "wuxia_needle", "wuxia_pixelstream", "wuxia_returnblade", "xianxia_sword", "magic_missile", "magic_shadow", "missile_spirit_sword", "missile_fireball", "missile_ice_arrow", "missile_shadow_arrow"]
static var _manifest_entries: Array[Dictionary] = []
static var _manifest_stamp: int = -1
static var _classic_metadata: Dictionary = {}


## 按 pixelfx 做法制作的像素特效：PIXELFX_IDS 里的升级版 + 全部烟花（id 以 firework_ 开头）+ 飞弹命中系（missile_hit_ 开头）
static func is_pixelfx(id: String) -> bool:
	return id in PIXELFX_IDS or id.begins_with("firework_") or id.begins_with("missile_hit_")


static func name_for(facet: String, value: String) -> String:
	return str((LABELS.get(facet, {}) as Dictionary).get(value, value))

static func facet_value(metadata: Dictionary, facet: String) -> Variant:
	if facet == "battle":
		return "combat" if str(metadata.get("usage", "")) in BATTLE_USAGES else "non_combat"
	if facet == "school":
		return school_for(metadata)
	if facet == "maker":
		return maker_of(metadata)
	return metadata.get(facet, "")

## 制作来源与渲染方式无关：飞弹走三维运行时，但属于 Claude 制作。
static func maker_of(metadata: Dictionary) -> String:
	if metadata.has("maker"):
		return str(metadata.maker)
	return "codex" if bool(metadata.get("is_classic", false)) else "claude"

## 追踪飞弹单独成「追踪飞弹系」（元素仍可在「更多筛选 → 元素」里查）。
## Melee strikes are always 拳系. Otherwise the first non-physical element names the school;
## purely physical effects split into blades, strikes, explosions/smoke, and spirit energy.
static func school_for(metadata: Dictionary) -> String:
	if bool(metadata.get("is_missile", false)):
		return "missile"
	# 烟花单独成「烟花系」；id 里的 firework 也不能被元素规则当成「火」
	if str(metadata.get("subtype", "")) == "fireworks":
		return "fireworks"
	var id := str(metadata.get("id", ""))
	var name := str(metadata.get("display_name", ""))
	var subtype := str(metadata.get("subtype", ""))
	if subtype == "melee" or id.contains("palm") or id.contains("acupoint"):
		return "fist"
	for element: Variant in metadata.get("elements", []):
		if str(element) != "physical":
			return str(element) if (LABELS.school as Dictionary).has(str(element)) else "arcane"
	if subtype in ["light_hit", "heavy_hit", "critical"]:
		return "fist"
	if subtype in ["slash", "thrust", "block"] or id.contains("sword") or name.contains("剑"):
		return "blade"
	if metadata.get("theme") != "xianxia" and (subtype in ["explosion", "fire_smoke"] or name.contains("烟")):
		return "physical"
	return "spirit"

static func options(facet: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in LABELS.get(facet, {}):
		result.append({"id": id, "label": name_for(facet, id)})
	return result

static func invalidate() -> void:
	_manifest_stamp = -1
	_classic_metadata.clear()

static func entries(include_candidates: bool = false) -> Array[Dictionary]:
	_load_manifest()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _manifest_entries:
		if include_candidates or (entry.get("status") == "ready" and FileAccess.file_exists(str(entry.get("recipe", "")))):
			result.append(entry.duplicate(true))
	return result

static func metadata_for(id: String) -> Dictionary:
	_load_manifest()
	for entry: Dictionary in _manifest_entries:
		if entry.get("id") == id:
			return entry.duplicate(true)
	return {}

static func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST):
		_manifest_entries.clear()
		return
	var stamp := int(FileAccess.get_modified_time(MANIFEST))
	if stamp == _manifest_stamp:
		return
	_manifest_stamp = stamp
	_manifest_entries.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary or int(parsed.get("schema_version", 0)) != 1:
		push_warning("Jeff FX: invalid library catalog; original presets remain available.")
		return
	var seen: Dictionary = {}
	for raw: Variant in parsed.get("entries", []):
		if not raw is Dictionary:
			continue
		var id := str(raw.get("id", ""))
		var recipe := str(raw.get("recipe", ""))
		if not id.begins_with("classic_ext_") or seen.has(id) or not recipe.begins_with("res://addons/fx_forge/library/recipes/ext_") or not recipe.ends_with(".tres") or recipe.contains(".."):
			continue
		seen[id] = true
		var entry: Dictionary = raw.duplicate(true)
		# Older candidate descriptors used hybrid; normalize only the in-memory copy.
		if entry.get("method") == "hybrid":
			entry["method"] = "mixed"
		entry["is_classic"] = true
		entry["maker"] = "codex"
		entry["category"] = "classic_" + str(entry.get("theme", "magic")) if entry.get("theme") in ["wuxia", "xianxia"] else "classic_environment" if entry.get("usage") == "environment" else "classic_magic"
		_manifest_entries.append(entry)

static func classic_metadata(id: String) -> Dictionary:
	if _classic_metadata.has(id):
		return (_classic_metadata[id] as Dictionary).duplicate(true)
	var recipe := "res://addons/fx_forge/legacy/presets/%s.tres" % id
	var text := FileAccess.get_file_as_string(recipe)
	var root := text.get_slice("[resource]", 1)
	var category := _string_field(root, "category", "environment")
	var groups := _group_for(id, CLASSIC_GROUPS, "environment/fire_smoke")
	var tags := _tags(root)
	var result := {"id": "classic_" + id, "recipe": recipe, "thumbnail": "res://addons/fx_forge/legacy/assets/thumbnails/%s.png" % id,
		"display_name": _string_field(root, "title", id), "description": _string_field(root, "description", ""), "category": "classic_" + category,
		"usage": groups[0], "subtype": groups[1], "style": "fine_pixel", "theme": "dark" if id in ["magic_shadow", "magic_voidvortex", "magic_siphon", "missile_shadow_arrow"] else category if category in ["wuxia", "xianxia"] else "nature" if category == "environment" else "fantasy",
		"elements": _elements(id, tags), "method": "procedural" if tags.has("程序化") else "mixed" if id in ["rain", "fireflies"] else "drawn",
		"playback": "loop" if root.contains("looping = true") else "one_shot", "anchor": "ground" if GROUND_IDS.has(id) else "direction" if DIRECTION_IDS.has(id) else "camera",
		"space": "follow" if groups[0] == "status" else "world", "status": "ready", "is_classic": true, "tags": tags,
		"maker": "claude" if MISSILE_IDS.has(id) else "codex", "is_missile": MISSILE_IDS.has(id)}
	_classic_metadata[id] = result
	return result.duplicate(true)

static func pixel_metadata(definition: Dictionary) -> Dictionary:
	var id := str(definition.get("id", ""))
	var groups := PackedStringArray(["presentation", "fireworks"]) if id.begins_with("firework_") else _group_for(id, PIXEL_GROUPS, "presentation/attachment")
	var g: Dictionary = definition.get("globals", {})
	return {"id": id, "display_name": definition.get("name", id), "description": definition.get("description", ""), "category": definition.get("category", "custom"),
		"usage": groups[0], "subtype": groups[1], "style": "ink" if id == "slash_ink" else "fine_pixel", "theme": "dark" if id == "slash_shadow" else "universal", "elements": ["fire", "light"] if groups[1] == "fireworks" else _elements(id, []), "method": "procedural",
		"playback": "loop" if bool(g.get("loop", false)) else "one_shot", "anchor": "ground" if groups[1] in ["dust", "water", "summon"] else "camera", "space": "follow" if groups[0] == "status" else "world", "status": "ready", "is_classic": false, "maker": "pixelfx" if is_pixelfx(id) else "claude", "thumbnail": "", "recipe": ""}

static func _group_for(id: String, groups: Dictionary, fallback: String) -> PackedStringArray:
	for key: String in groups:
		if id in groups[key]:
			return key.split("/")
	return fallback.split("/")

static func _string_field(text: String, key: String, fallback: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with(key + " = "):
			var value: Variant = JSON.parse_string(line.trim_prefix(key + " = "))
			return str(value) if value is String else fallback
	return fallback

static func _tags(text: String) -> Array:
	for line: String in text.split("\n"):
		if line.begins_with("tags = PackedStringArray("):
			var parsed: Variant = JSON.parse_string("[" + line.trim_prefix("tags = PackedStringArray(").trim_suffix(")") + "]")
			return parsed if parsed is Array else []
	return []

static func _elements(id: String, tags: Array) -> Array:
	# Rewrite words that would substring-match the wrong rule: "fireflies" is not fire,
	# and "arcane" must not hit lightning's "arc".
	var words := (id + " " + " ".join(tags)).replace("fireflies", "glow").replace("arcane", "奥术")
	var rules := {"fire": ["fire", "flame", "flare", "torch", "火"], "ice": ["ice", "frost", "冰"], "water": ["water", "rain", "水", "雨"], "lightning": ["lightning", "arc", "electric", "雷"], "wind": ["wind", "dash", "风"], "earth": ["earth", "dust", "ground", "土"], "wood": ["briar", "木"], "poison": ["poison", "毒"], "shadow": ["shadow", "void", "暗"], "light": ["heal", "lotus", "light", "glow", "净化", "治疗"], "arcane": ["奥术"]}
	var result: Array = []
	for element: String in rules:
		for word: String in rules[element]:
			if words.contains(word):
				result.append(element)
				break
	if result.is_empty():
		result.append("arcane" if id.contains("magic") else "physical")
	if result.has("lightning") and result.has("light") and not words.contains("治疗"):
		result.erase("light")
	return result
