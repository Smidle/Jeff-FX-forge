@tool
extends RefCounted
## Classic recipes retain their original 3D runtime; only paths and class names are isolated.
const Preset := preload("../core/fx_preset.gd")
const IDS := ["smoke", "campfire", "rain", "fireflies", "portal", "procedural_flame", "wuxia_parry", "wuxia_dust", "wuxia_palm", "wuxia_pierce", "wuxia_dash", "wuxia_crush", "wuxia_needle", "wuxia_counter", "wuxia_acupoint", "wuxia_smokebomb", "wuxia_pixelstream", "wuxia_returnblade", "wuxia_groundwave", "xianxia_sword", "xianxia_talisman", "xianxia_lightning", "xianxia_charge", "xianxia_lotus", "xianxia_seal", "xianxia_feather", "xianxia_meridian", "xianxia_blink", "xianxia_bell", "xianxia_arc", "xianxia_swordarray", "xianxia_spiritbutterfly", "magic_icefall", "magic_flare", "magic_missile", "magic_heal", "magic_frostnova", "magic_water", "magic_earth", "magic_shadow", "magic_briar", "magic_siphon", "magic_icecage", "magic_voidvortex"]

static func all() -> Array:
	var result: Array = []
	for id: String in IDS:
		var p := find("classic_" + id)
		if p != null:
			result.append(p)
	return result

static func find(id: String) -> Preset:
	if not id.begins_with("classic_") or not IDS.has(id.trim_prefix("classic_")):
		return null
	var recipe: Resource = load("res://addons/fx_forge/legacy/presets/%s.tres" % id.trim_prefix("classic_"))
	if recipe == null:
		return null
	var p := Preset.new()
	p.preset_id = id
	p.display_name = recipe.title
	p.description = recipe.description
	p.category = "classic_" + recipe.category
	p.legacy_recipe = recipe
	return p

static func thumbnail(p: Preset) -> Image:
	if not p.preview_png.is_empty():
		var stored := Image.new()
		if stored.load_png_from_buffer(p.preview_png) == OK:
			return stored
	var path := "res://addons/fx_forge/legacy/assets/thumbnails/%s.png" % p.legacy_recipe.id
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return img
	return Image.create_empty(56, 56, false, Image.FORMAT_RGBA8)
