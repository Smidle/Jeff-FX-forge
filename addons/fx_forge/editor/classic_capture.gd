@tool
extends RefCounted
## Offscreen RGBA capture, isolated from the user's scene and workshop playback.
## A bounded main-thread coroutine: no rendering objects enter WorkerThreadPool.
const Instance := preload("../legacy/runtime/fx_instance.gd")
const FxExport := preload("../export/fx_export.gd")
var viewport: SubViewport
var camera: Camera3D
var world: Node3D
var effect: Instance

func setup(parent: Node, resolution: int, source_camera: Camera3D = null) -> void:
	viewport = SubViewport.new()
	viewport.name = "JeffFXSpriteCapture"
	viewport.size = Vector2i(resolution, resolution)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	parent.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6
	world.add_child(camera)
	camera.position = Vector3(3, 5, 8)
	camera.look_at(Vector3(0, .8, 0))
	if is_instance_valid(source_camera):
		camera.transform = source_camera.global_transform
		camera.projection = source_camera.projection
		camera.size = source_camera.size
		camera.fov = source_camera.fov
	camera.current = true

func set_recipe(recipe: Resource) -> void:
	if is_instance_valid(effect):
		effect.free()
	effect = Instance.new()
	effect.preset = recipe.copy()
	effect.autoplay = false
	effect.preview_enabled = true
	# Deterministic CPU sampling also works in Compatibility. No asynchronous
	# GPU upload dependency can leave a capture waiting on an invisible window.
	effect.backend = Instance.Backend.CPU
	world.add_child(effect)
	effect.seek(0)

func sample(time: float) -> Image:
	effect.seek(time)
	await viewport.get_tree().process_frame
	RenderingServer.force_draw(false)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	straight_alpha(image)
	return image

static func straight_alpha(image: Image) -> void:
	# Transparent viewports return premultiplied RGB. PNG / SpriteFrames use
	# straight alpha; without this pass soft pixels darken a second time.
	var bytes := image.get_data()
	for i in range(0, bytes.size(), 4):
		var alpha: int = bytes[i + 3]
		if alpha == 0:
			bytes[i] = 0
			bytes[i + 1] = 0
			bytes[i + 2] = 0
		elif alpha < 255:
			bytes[i] = mini(255, (int(bytes[i]) * 255 + alpha / 2) / alpha)
			bytes[i + 1] = mini(255, (int(bytes[i + 1]) * 255 + alpha / 2) / alpha)
			bytes[i + 2] = mini(255, (int(bytes[i + 2]) * 255 + alpha / 2) / alpha)
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, bytes)

func close() -> void:
	if is_instance_valid(viewport):
		viewport.free()
	viewport = null
	effect = null

static func render(preset: Resource, settings: Dictionary, source_camera: Camera3D = null) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"error": "经典效果需要带渲染器的 Godot 编辑器才能导出。"}
	var seconds: float = settings.capture_seconds
	var fps: int = settings.capture_fps
	var resolution: int = settings.capture_size
	var frames: int = maxi(2, ceili(seconds * fps))
	var plan := FxExport.plan_animations(settings)
	# Bound peak image memory including sheet construction and scaled copies.
	if frames * plan.size() * resolution * resolution * settings.scale * settings.scale > 33554432:
		return {"error": "导出画面过大，请减少尺寸、时长、方向或变体数量（最多约 3200 万像素）。"}
	var watches_camera := is_instance_valid(source_camera)
	var tree := Engine.get_main_loop() as SceneTree
	var capture := new()
	capture.setup(tree.root, resolution, source_camera)
	var initial: Transform3D = capture.camera.transform
	var pivot: Vector2 = capture.camera.unproject_position(Vector3.ZERO)
	var aligned_width := resolution
	if settings.directions == "mirror":
		aligned_width = 2 * ceili(maxf(pivot.x, resolution - pivot.x))
	if frames * plan.size() * aligned_width * resolution * settings.scale * settings.scale > 33554432:
		capture.close()
		return {"error": "镜像锚点补边后的画面过大，请调整构图或减少导出尺寸。"}
	var anims: Array = []
	for a: Dictionary in plan:
		var recipe: Resource = preset.legacy_recipe.copy()
		recipe.seed += a.seed_offset
		capture.camera.transform = initial
		if a.direction != null:
			var rotation := Basis(Vector3.UP, deg_to_rad(float(a.direction)))
			var focus := Vector3(0, .8, 0)
			capture.camera.transform = Transform3D(rotation * initial.basis, focus + rotation * (initial.origin - focus))
		capture.set_recipe(recipe)
		var images: Array = []
		for i in frames:
			if watches_camera and not is_instance_valid(source_camera):
				capture.close()
				return {"error": "导出已取消：工坊已关闭。"}
			var time: float = float(i) / fps * recipe.playback_speed
			var img: Image = await capture.sample(time)
			if a.mirror:
				img.flip_x()
			images.append(img)
		anims.append({"name": a.name, "frames": images, "origin": Vector2(resolution - pivot.x, pivot.y) if a.mirror else pivot})
	capture.close()
	return FxExport.align_animation_origins({"anims": anims, "fps": fps, "loop": preset.legacy_recipe.looping, "origin": pivot,
		"canvas": Vector2i(resolution, resolution), "durations": PackedFloat32Array()})
