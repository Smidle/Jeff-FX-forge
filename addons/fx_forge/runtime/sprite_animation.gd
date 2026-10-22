@tool
extends Resource
## Compact embedded PNG data; scenes do not depend on temporary export paths.
@export var png: PackedByteArray
@export var rects: Array[Rect2i] = []
@export var origin: Vector2
@export var fps: float = 12
@export var looping := false
@export var durations: PackedFloat32Array
var _frames: SpriteFrames

func frames() -> SpriteFrames:
	if _frames != null:
		return _frames
	var img := Image.new()
	if img.load_png_from_buffer(png) != OK:
		return null
	var atlas := ImageTexture.create_from_image(img)
	_frames = SpriteFrames.new()
	_frames.set_animation_speed(&"default", fps)
	_frames.set_animation_loop_mode(&"default", SpriteFrames.LOOP_LINEAR if looping else SpriteFrames.LOOP_NONE)
	for i in rects.size():
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = rects[i]
		texture.filter_clip = true
		_frames.add_frame(&"default", texture, durations[i] if i < durations.size() else 1)
	return _frames

static func from_job(job: RefCounted) -> Resource:
	var data := new()
	data.origin = job.origin
	data.fps = job.fps
	data.looping = job.loop
	data.durations = job.durations.duplicate()
	var cols := ceili(sqrt(float(job.frame_count)))
	var rows := ceili(float(job.frame_count) / cols)
	var sheet := Image.create_empty(cols * job.w, rows * job.h, false, Image.FORMAT_RGBA8)
	var images: Array = job.images()
	for i in images.size():
		var rect := Rect2i((i % cols) * job.w, (i / cols) * job.h, job.w, job.h)
		sheet.blit_rect(images[i], Rect2i(0, 0, job.w, job.h), rect.position)
		data.rects.append(rect)
	data.png = sheet.save_png_to_buffer()
	return data
