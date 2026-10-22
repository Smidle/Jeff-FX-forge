@tool
extends VBoxContainer
## Isolated world; no preview node is ever added to the edited scene.
const I18n := preload("i18n.gd")
const Instance := preload("../legacy/runtime/fx_instance.gd")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var environment: Environment
var effect: Instance
var _surface: SubViewportContainer
var _yaw := 0.35
var _pitch := 0.45
var _distance := 9.0
var _orbit := false
var _quality := Instance.Quality.STANDARD
var _background := Color("101b28")
var _focus := Vector3(0, .8, 0)
var _solo := -1
var _saved_view := {}
var _grid: MeshInstance3D

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bar := HBoxContainer.new()
	add_child(bar)
	var label := Label.new()
	label.text = I18n.T("3D 实时预览")
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(label)
	var projection := OptionButton.new()
	projection.add_item(I18n.T("正交"))
	projection.add_item(I18n.T("透视"))
	projection.item_selected.connect(func(i: int) -> void: camera.projection = Camera3D.PROJECTION_ORTHOGONAL if i == 0 else Camera3D.PROJECTION_PERSPECTIVE)
	bar.add_child(projection)
	var background := OptionButton.new()
	background.add_item(I18n.T("深色背景"))
	background.add_item(I18n.T("浅色背景"))
	background.tooltip_text = I18n.T("预览背景独立于界面主题，用于检查透明边缘")
	background.item_selected.connect(func(i: int) -> void: set_background(Color("101b28") if i == 0 else Color("f0eee6")))
	bar.add_child(background)
	var quality := OptionButton.new()
	quality.add_item(I18n.T("标准"))
	quality.add_item(I18n.T("精简"))
	quality.item_selected.connect(func(i: int) -> void:
		_quality = Instance.Quality.STANDARD if i == 0 else Instance.Quality.REDUCED
		if is_instance_valid(effect):
			effect.quality = Instance.Quality.STANDARD if _solo >= 0 else _quality
			effect.refresh())
	bar.add_child(quality)
	var grid := CheckBox.new()
	grid.text = I18n.T("地面格线")
	grid.button_pressed = true
	grid.toggled.connect(func(on: bool) -> void: _grid.visible = on)
	bar.add_child(grid)
	var reset := Button.new()
	reset.text = I18n.T("重置视角")
	reset.pressed.connect(reset_camera)
	bar.add_child(reset)
	_surface = SubViewportContainer.new()
	_surface.stretch = true
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.custom_minimum_size = Vector2(240, 220)
	_surface.gui_input.connect(_camera_input)
	add_child(_surface)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_surface.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _background
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	var env := WorldEnvironment.new()
	env.environment = environment
	world.add_child(env)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	camera.fov = 45.0
	camera.current = true
	world.add_child(camera)
	_grid = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-8, 9):
		mesh.surface_add_vertex(Vector3(i, -0.03, -8))
		mesh.surface_add_vertex(Vector3(i, -0.03, 8))
		mesh.surface_add_vertex(Vector3(-8, -0.03, i))
		mesh.surface_add_vertex(Vector3(8, -0.03, i))
	mesh.surface_end()
	_grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("30485b")
	_grid.material_override = material
	world.add_child(_grid)
	reset_camera()
	visibility_changed.connect(_visibility)

func set_recipe(recipe: Resource) -> void:
	clear_effect()
	effect = Instance.new()
	effect.preset = recipe.copy()
	effect.solo_layer = _solo
	effect.autoplay = false
	effect.preview_enabled = true
	effect.quality = Instance.Quality.STANDARD if _solo >= 0 else _quality
	world.add_child(effect)
	effect.seek(0.0)

func clear_effect() -> void:
	if is_instance_valid(effect):
		effect.stop(true)
		effect.free()
	effect = null

func set_background(color: Color) -> void:
	_background = color
	if environment != null:
		environment.background_color = color

func _visibility() -> void:
	if viewport != null:
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if is_visible_in_tree() else SubViewport.UPDATE_DISABLED

func reset_camera() -> void:
	_focus = Vector3(0, .8, 0)
	_yaw = 0.35
	_pitch = 0.45
	_distance = 9.0
	camera.size = 6.0
	_update_camera()

func _update_camera() -> void:
	var target := _focus
	camera.position = target + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.look_at(target)

func _camera_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbit = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			_distance = clampf(_distance * factor, .3, 24)
			camera.size = clampf(camera.size * factor, .1, 18)
			_update_camera()
	if event is InputEventMouseMotion and _orbit:
		_yaw -= event.relative.x * 0.008
		_pitch = clampf(_pitch + event.relative.y * 0.008, 0.05, 1.5)
		_update_camera()

func set_solo(index: int) -> void:
	if _solo < 0 and index >= 0:
		_saved_view = {"focus": _focus, "size": camera.size, "distance": _distance, "yaw": _yaw, "pitch": _pitch}
	_solo = index
	if is_instance_valid(effect):
		effect.solo_layer = index
		effect.quality = Instance.Quality.STANDARD if index >= 0 else _quality
		if index >= 0 and index < effect.preset.layers.size():
			var layer: Resource = effect.preset.layers[index]
			_focus = layer.offset * effect.preset.effect_scale
			camera.size = maxf(.5, layer.size * maxf(layer.aspect.x, layer.aspect.y) * effect.preset.effect_scale * 1.8)
			if layer.kind == 2: camera.size = 4.0
			_distance = 5.0
		elif not _saved_view.is_empty():
			_focus = _saved_view.focus
			camera.size = _saved_view.size
			_distance = _saved_view.distance
			_yaw = _saved_view.yaw
			_pitch = _saved_view.pitch
			_saved_view.clear()
		effect.seek(effect.time)
	_update_camera()
