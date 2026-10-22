@tool
extends TextureRect
## A small UI sprite player; hidden workshop tabs do not advance the animation.

const ANIMATION: StringName = &"explosion"
var _frames: SpriteFrames
var _frame: int = 0
var _elapsed: float = 0.0
var _cycle_duration: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://addons/fx_forge/legacy/assets/branding/explosion/logo_explosion_sheet.png")) != OK:
		return
	var atlas := ImageTexture.create_from_image(img)
	_frames = SpriteFrames.new()
	_frames.add_animation(ANIMATION)
	_frames.set_animation_speed(ANIMATION, 10.0)
	_frames.set_animation_loop_mode(ANIMATION, SpriteFrames.LOOP_LINEAR)
	var durations: Array = [0.9, 0.7, 0.4, 0.4, 0.6, 0.6, 0.7, 0.8, 0.9, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.8, 0.7, 0.7]
	for i in durations.size():
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2((i % 4) * 64, (i / 4) * 64, 64, 64)
		frame.filter_clip = true
		_frames.add_frame(ANIMATION, frame, durations[i])
	if _frames != null:
		for index in _frames.get_frame_count(ANIMATION):
			_cycle_duration += _frame_duration(index)
		texture = _frames.get_frame_texture(ANIMATION, 0)
	visibility_changed.connect(_sync_playback)
	_sync_playback()

func _frame_duration(index: int) -> float:
	return _frames.get_frame_duration(ANIMATION, index) / _frames.get_animation_speed(ANIMATION)

func _sync_playback() -> void:
	set_process(is_visible_in_tree() and _cycle_duration > 0.0)

func _process(delta: float) -> void:
	# Bound work when the editor returns after a long suspension.
	_elapsed += fmod(delta, _cycle_duration)
	var changed: bool = false
	while _elapsed >= _frame_duration(_frame):
		_elapsed -= _frame_duration(_frame)
		_frame = (_frame + 1) % _frames.get_frame_count(ANIMATION)
		changed = true
	if changed:
		texture = _frames.get_frame_texture(ANIMATION, _frame)
