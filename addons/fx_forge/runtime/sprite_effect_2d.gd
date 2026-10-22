@tool
extends AnimatedSprite2D
const AnimationData := preload("sprite_animation.gd")
@export var effect_animation: AnimationData
@export var free_on_finish := true
var preview_enabled := false

func _ready() -> void:
	if effect_animation == null:
		return
	sprite_frames = effect_animation.frames()
	if sprite_frames == null or sprite_frames.get_frame_count(&"default") == 0:
		return
	centered = false
	offset = -effect_animation.origin
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not Engine.is_editor_hint() or preview_enabled:
		if not preview_enabled and free_on_finish and not effect_animation.looping:
			animation_finished.connect(queue_free)
		play()
	else:
		frame = mini(3, sprite_frames.get_frame_count(&"default") - 1)

func _validate_property(property: Dictionary) -> void:
	# Reconstructed from compact PNG data, never serialized a second time.
	if property.name in ["sprite_frames", "frame", "frame_progress", "autoplay", "animation"]:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_STORAGE
