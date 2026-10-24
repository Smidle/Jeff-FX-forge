extends Node2D
## All effect ownership is local to one level. No timers or nodes survive unloading.
const Effect = preload("res://scripts/effect.gd")
var catalog: Dictionary = {}
var resources: Dictionary = {}
var courtyard_variants: Dictionary = {}
var gameplay_counts: Dictionary = {}
var debug_counts: Dictionary = {}
var accepting := true
const INITIAL = ["campfire", "torch", "classic_smoke", "classic_fireflies", "magic_circle", "water_splash", "pickup_sparkle", "teleport_beam", "electric_arc", "slash_basic", "slash_spin", "thrust", "classic_xianxia_sword", "classic_xianxia_lightning", "classic_magic_heal", "classic_xianxia_bell", "run_dust", "landing_dust", "dash_trail", "hit_basic", "hit_heavy", "block_sparks", "heal", "shield", "charge", "hit_crit", "buff_aura", "explosion_small", "explosion_poison", "classic_magic_icefall", "classic_magic_earth", "classic_magic_icecage", "classic_magic_voidvortex"]

func _ready() -> void:
	for entry in JSON.parse_string(FileAccess.get_file_as_string("res://data/effects.json")):
		catalog[entry.id] = entry
	for id in INITIAL:
		resources[id] = _frames(id)
	# Warm the courtyard dash frames before the first keyboard activation.
	for id in ["classic_wuxia_dash", "classic_wuxia_dust"]:
		resources[id] = _frames(id)
	if FileAccess.file_exists("res://data/courtyard/fx_variants/manifest.json"):
		courtyard_variants = JSON.parse_string(FileAccess.get_file_as_string("res://data/courtyard/fx_variants/manifest.json"))
		for id in courtyard_variants:
			resources["courtyard/" + id] = _frames(id, courtyard_variants[id])

func _frames(id: String, override_info: Dictionary = {}) -> SpriteFrames:
	var info: Dictionary = catalog[id] if override_info.is_empty() else override_info
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", info.fps)
	frames.set_animation_loop_mode("default", SpriteFrames.LOOP_LINEAR if info.loop else SpriteFrames.LOOP_NONE)
	var texture: Texture2D = load(info.get("texture_path", "res://assets/effects/" + id + ".png"))
	for i in range(info.rects.size()):
		var box: Array = info.rects[i]
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(box[0], box[1], box[2], box[3])
		frames.add_frame("default", atlas, info.durations[i])
	return frames

func play(id: String, at: Vector2, options: Dictionary = {}) -> Node2D:
	if not accepting or not catalog.has(id): return null
	if not resources.has(id): resources[id] = _frames(id)
	var is_variant: bool = options.get("variant", "") == "courtyard" and courtyard_variants.has(id)
	var resource_key := "courtyard/" + id if is_variant else id
	var info: Dictionary = (courtyard_variants[id] if is_variant else catalog[id]).duplicate(true)
	info.scale = options.get("scale", info.scale)
	var fx = Effect.new()
	fx.position = at
	fx.ground = options.get("ground", false)
	add_child(fx)
	fx.set_meta("source_id", id)
	fx.set_meta("variant", "courtyard" if is_variant else "original")
	fx.configure(info, resources[resource_key], options.get("duration", info.duration), options.get("loop", false))
	fx.sprite.speed_scale = options.get("speed", 1.0)
	# A one-shot protection recipe has an intact interval followed by destruction.
	# Loop only the authored intact interval while its gameplay status is active.
	if fx.blend_sprite != null and options.has("stable_frames"):
		var stable: Vector2i = options.stable_frames
		fx.steady_start = clampi(stable.x, 0, resources[id].get_frame_count("default") - 2)
		fx.steady_count = clampi(stable.y - fx.steady_start, 2, resources[id].get_frame_count("default") - fx.steady_start)
		fx.blend_frames = mini(2, fx.steady_count - 1)
	fx.following = options.get("follow", null)
	fx.follow_offset = options.get("offset", Vector2.ZERO)
	fx.rotation = options.get("rotation", 0.0)
	fx.modulate = options.get("color", Color.WHITE)
	# Existing baked frames are animation appearance, never a damage/hit callback.
	var counter: Dictionary = debug_counts if options.get("debug", false) else gameplay_counts
	counter[id] = int(counter.get(id, 0)) + 1
	return fx

func shutdown() -> void:
	accepting = false
	for child in get_children(): child.queue_free()
