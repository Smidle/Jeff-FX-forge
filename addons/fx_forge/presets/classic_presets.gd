@tool
extends RefCounted
## Classic recipes retain their original 3D runtime; only paths and class names are isolated.
const Preset := preload("../core/fx_preset.gd")
const Catalog := preload("library_catalog.gd")
const IDS := ["smoke", "campfire", "rain", "fireflies", "portal", "procedural_flame", "wuxia_parry", "wuxia_dust", "wuxia_palm", "wuxia_pierce", "wuxia_dash", "wuxia_crush", "wuxia_needle", "wuxia_counter", "wuxia_acupoint", "wuxia_smokebomb", "wuxia_pixelstream", "wuxia_returnblade", "wuxia_groundwave", "xianxia_sword", "xianxia_talisman", "xianxia_lightning", "xianxia_charge", "xianxia_lotus", "xianxia_seal", "xianxia_feather", "xianxia_meridian", "xianxia_blink", "xianxia_bell", "xianxia_arc", "xianxia_swordarray", "xianxia_spiritbutterfly", "magic_icefall", "magic_flare", "magic_missile", "magic_heal", "magic_frostnova", "magic_water", "magic_earth", "magic_shadow", "magic_briar", "magic_siphon", "magic_icecage", "magic_voidvortex"]

static func all() -> Array:
	var result: Array = []
	for entry: Dictionary in catalog():
		var p := find(str(entry.id))
		if p != null:
			result.append(p)
	return result

## Classic-format recipe ids, including the missile collection (rendered by the same runtime).
static func has_id(id: String) -> bool:
	return IDS.has(id) or Catalog.MISSILE_IDS.has(id)

## Metadata for library/gallery views. No effects or textures are loaded here.
## Missiles come first so they sit next to the other Claude-made entries in the browser.
static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in Catalog.MISSILE_IDS + IDS:
		result.append(Catalog.classic_metadata(id))
	result.append_array(Catalog.entries())
	return result

static func find(id: String) -> Preset:
	var metadata: Dictionary
	if id.begins_with("classic_ext_"):
		metadata = Catalog.metadata_for(id)
		if metadata.get("status") != "ready" or not FileAccess.file_exists(str(metadata.get("recipe", ""))):
			return null
	elif id.begins_with("classic_") and has_id(id.trim_prefix("classic_")):
		metadata = Catalog.classic_metadata(id.trim_prefix("classic_"))
	else:
		return null
	var recipe: Resource = load(str(metadata.recipe))
	if recipe == null:
		return null
	var p := Preset.new()
	p.preset_id = id
	p.display_name = recipe.title
	p.description = recipe.description
	p.category = "classic_" + recipe.category
	p.legacy_recipe = recipe
	p.library_metadata = metadata.duplicate(true)
	return p

static func thumbnail(p: Preset) -> Image:
	if not p.preview_png.is_empty():
		var stored := Image.new()
		if stored.load_png_from_buffer(p.preview_png) == OK:
			return stored
	var path := str(p.library_metadata.get("thumbnail", ""))
	if path.is_empty() and p.legacy_recipe != null:
		path = "res://addons/fx_forge/legacy/assets/thumbnails/%s.png" % p.legacy_recipe.id
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return img
	return Image.create_empty(56, 56, false, Image.FORMAT_RGBA8)
