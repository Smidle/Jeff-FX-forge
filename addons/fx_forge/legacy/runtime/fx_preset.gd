@tool
class_name JeffForge3DPreset
extends Resource
## Effect recipe. Edit a duplicate to make a variation of a built-in preset.

@export var id: String = "custom"
@export var title: String = "New effect"
@export var title_en: String = "New effect"
@export_enum("environment", "wuxia", "xianxia", "magic") var category: String = "environment"
@export_multiline var description: String = ""
@export var tags: PackedStringArray = []
@export var looping: bool = false
@export var duration: float = 1.5
@export var preview_time: float = 0.35
@export var primary_color: Color = Color("ffd48a")
@export var secondary_color: Color = Color("ff7548")
@export var effect_scale: float = 1.0
@export var playback_speed: float = 1.0
@export var density: float = 1.0
@export var brightness: float = 1.0
@export var seed: int = 42
@export var layers: Array[JeffForge3DLayer] = []

func copy() -> JeffForge3DPreset:
	var result := duplicate(false) as JeffForge3DPreset
	# Copy each layer once, including externally stored Resources. Replace the
	# container instead of clearing a potentially shared typed array.
	result.layers = []
	for layer in layers:
		var cloned := layer.duplicate(true) as JeffForge3DLayer
		if layer.missile != null:
			cloned.missile = layer.missile.copy()
		result.layers.append(cloned)
	return result

func total_duration() -> float:
	var result: float = duration
	for layer in layers:
		if layer.enabled:
			var source: JeffForge3DLayer = layers[layer.motion_source] if layer.kind == JeffForge3DLayer.Kind.FIELD and layer.motion_source >= 0 and layer.motion_source < layers.size() else layer
			var ending: float = source.delay + source.tail_time()
			if layer.continuous:
				ending = maxf(ending, duration + layer.lifetime)
			result = maxf(result, ending)
	return result

func particle_capacity(reduced: bool = false) -> int:
	var total: int = 0
	for layer in layers:
		if layer.enabled and layer.kind in [JeffForge3DLayer.Kind.PARTICLES, JeffForge3DLayer.Kind.FIELD] and not (reduced and layer.decorative):
			var source: JeffForge3DLayer = layers[layer.motion_source] if layer.kind == JeffForge3DLayer.Kind.FIELD and layer.motion_source >= 0 and layer.motion_source < layers.size() else layer
			var multiplier: int = clampi(layer.satellite_count, 1, 4) if layer.kind == JeffForge3DLayer.Kind.FIELD and layer.field_motion == JeffForge3DLayer.FieldMotion.FIREFLY_MOTES else 1
			total += maxi(1, int(source.count * clampf(density, 0.05, 3.0) * (0.45 if reduced else 1.0))) * multiplier
	return total

func has_missile() -> bool:
	for layer in layers:
		if layer.kind == JeffForge3DLayer.Kind.MISSILE: return true
	return false

func is_foot_effect() -> bool:
	# Tags survive saved variations and keep preview/runtime attachment consistent.
	return tags.has("轻功")
