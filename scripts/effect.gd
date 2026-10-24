@tool
extends Node2D
signal ended
var sprite: AnimatedSprite2D
var elapsed := 0.0
var ttl := 0.0
var permanent := false
var following: Node2D
var follow_offset := Vector2.ZERO
var moving := false
var from := Vector2.ZERO
var to := Vector2.ZERO
var travel_time := .7
var hit: Callable
var _arrived := false
var _ending := false
var _fade_start := 0.0
var _fade_length := .22
var ground := false
var blend_sprite: AnimatedSprite2D
var steady_start := 0
var steady_count := 0
var blend_frames := 8
var fps := 24.0

func configure(info: Dictionary, frames: SpriteFrames, seconds: float, persistent: bool) -> void:
	permanent = persistent
	z_index = -2 if ground else int(position.y)+100
	ttl = seconds
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -Vector2(info.pivot[0],info.pivot[1])
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * float(info.scale)
	add_child(sprite)
	sprite.play("default")
	if persistent and info.library == "classic":
		steady_start = mini(18,frames.get_frame_count("default")/3)
		steady_count = frames.get_frame_count("default")-steady_start
		fps = info.fps
		sprite.stop()
		blend_sprite = sprite.duplicate() as AnimatedSprite2D
		add_child(blend_sprite)
		blend_sprite.stop()

func stop_soft(seconds: float = .3) -> void:
	if _ending: return
	permanent = false
	_ending = true
	_fade_start = elapsed
	_fade_length = maxf(.05,seconds)

func _process(delta: float) -> void:
	if sprite == null: return
	elapsed += delta
	if blend_sprite != null:
		var span := maxi(1,steady_count-blend_frames)
		var phase := fposmod(elapsed*fps,span)
		sprite.frame = steady_start+int(phase)
		if phase < blend_frames:
			var u := phase/float(blend_frames)
			sprite.modulate.a = u
			blend_sprite.modulate.a = 1-u
			blend_sprite.frame = steady_start+span+int(phase)
		else:
			sprite.modulate.a = 1
			blend_sprite.modulate.a = 0
	if is_instance_valid(following): position = following.position + follow_offset
	elif following != null: stop_soft()
	if moving and not _arrived:
		var u := clampf(elapsed/travel_time,0,1)
		position = from.lerp(to,u) + Vector2(0,-sin(u*PI)*18)
		if u >= 1:
			_arrived = true
			moving = false
			if hit.is_valid(): hit.call(to)
			stop_soft(.23)
	if not permanent and not _ending and elapsed >= ttl: stop_soft(.22)
	if _ending:
		var f := clampf((elapsed-_fade_start)/_fade_length,0,1)
		modulate.a = 1-f
		if f >= 1:
			ended.emit()
			queue_free()
	z_index = -2 if ground else int(position.y)+100
