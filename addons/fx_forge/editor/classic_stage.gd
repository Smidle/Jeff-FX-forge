@tool
extends VBoxContainer
## Isolated world; no preview node is ever added to the edited scene.
## 飞弹配方额外显示：模拟目标运动、路径辅助线、起终点和自定义曲线拖动编辑（missile_path_editor.gd）。
## 模拟目标只用于预览，不写入配方；拖动编辑通过 path_committed 交给会话记入撤销历史。
## 像素特效也可以在这里看（像素模式）：当前帧作为面向镜头的像素贴图放进三维世界，和参考角色同一比例，
## HD-2D 式的低角度透视和地面——游戏里像素特效就是这样出现在三维场景中的。
## 不开 Environment 的辉光：兼容渲染器开辉光会把纯色背景提亮 4 倍；像素特效自己已经带了叠加光。
signal path_committed(property: String, value: Variant)
signal convert_requested
## 像素模式里换了放置方式（脚底 / 身上），需要重新放当前帧
signal place_changed
const I18n := preload("i18n.gd")
const Instance := preload("../legacy/runtime/fx_instance.gd")
const Layer := preload("../legacy/runtime/fx_layer.gd")
const MissileConfig := preload("../legacy/runtime/fx_missile_config.gd")
const MissilePathEditor := preload("missile_path_editor.gd")
## 参考角色：由三维骨架画成的像素剑士（DNF 式比例），带呼吸的待机动画
const ReferenceFigure := preload("reference_figure.gd")
## 飞弹的终点放一个稻草人：被打中时摇晃、闪白、按元素染色
const StrawTarget := preload("../runtime/fx_straw_target.gd")
const TARGET_MODES := ["目标静止", "目标直线移动", "目标绕圈", "目标横向折返"]
const AXIS_MODES := ["拖动：镜头平面", "只沿 X 轴", "只沿 Y 轴", "只沿 Z 轴"]
## 像素特效在三维里的像素大小（米）：和等距测试场一致，角色约 45 像素 ≈ 1.7 米
const PIXEL_SIZE := 0.038
const PLACE_MODES := ["放置：自动", "放置：脚底", "放置：身上（离地 0.8 米）"]
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
var path_editor: Control
## 0 静止；1 直线移动；2 绕圈；3 横向折返
var target_mode := 0
var _live_recipe: Resource
var _missile_bar: HFlowContainer
var _axis_option: OptionButton
var _convert_button: Button
var _add_button: Button
var _delete_button: Button
var _reference: AnimatedSprite3D
var _show_reference := true
var _target: Node3D
var _show_target := true
## 像素模式
var pixel_mode := false
var _pixel: Sprite3D
var _floor: MeshInstance3D
var _pixel_bar: HFlowContainer
var _projection: OptionButton
var _quality_option: OptionButton
var _saved_projection := Camera3D.PROJECTION_ORTHOGONAL
var _pixel_reference := true
## 0 自动（按原点位置判断）；1 脚底；2 身上
var place_mode := 0

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
	_projection = projection
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
	_quality_option = quality
	var grid := CheckBox.new()
	grid.text = I18n.T("地面格线")
	grid.button_pressed = true
	grid.toggled.connect(func(on: bool) -> void: _grid.visible = on)
	bar.add_child(grid)
	var reset := Button.new()
	reset.text = I18n.T("重置视角")
	reset.pressed.connect(reset_camera)
	bar.add_child(reset)
	_build_missile_bar()
	_build_pixel_bar()
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
	# 像素模式的地面：比背景略亮的一块地，格线画在它上面
	_floor = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	_floor.mesh = plane
	_floor.position.y = -0.035
	var floor_material := StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.albedo_color = Color("1a2c3b")
	_floor.material_override = floor_material
	_floor.visible = false
	world.add_child(_floor)
	_reference = AnimatedSprite3D.new()
	var figure := SpriteFrames.new()
	figure.set_animation_speed("default", ReferenceFigure.FPS)
	for image: Image in ReferenceFigure.frames():
		figure.add_frame("default", ImageTexture.create_from_image(image))
	_reference.sprite_frames = figure
	# 脚底在原点；和像素特效同样的像素大小，约 50 像素 ≈ 1.9 米高，用来对照特效和飞弹的大小
	_reference.centered = false
	_reference.offset = Vector2(-ReferenceFigure.ORIGIN.x, -(ReferenceFigure.H - ReferenceFigure.ORIGIN.y))
	_reference.pixel_size = PIXEL_SIZE
	_reference.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_reference.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_reference.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_reference.shaded = false
	_reference.visible = false
	world.add_child(_reference)
	# 工坊在编辑器里运行，autoplay 不生效，要手动开始播放
	_reference.play("default")
	_target = StrawTarget.new()
	_target.auto_clock = false
	_target.pixel_size = PIXEL_SIZE
	_target.visible = false
	world.add_child(_target)
	path_editor = MissilePathEditor.new()
	path_editor.stage = self
	path_editor.visible = false
	_surface.add_child(path_editor)
	path_editor.committed.connect(func(property: String, _before: Variant, after: Variant) -> void: path_committed.emit(property, after))
	path_editor.preview_requested.connect(preview_config)
	path_editor.axis_changed.connect(func(value: int) -> void:
		if _axis_option != null: _axis_option.select(value))
	reset_camera()
	visibility_changed.connect(_visibility)

## recipe 是会话里正在编辑的配方本身；预览实例用它的副本，路径编辑层读它本身。
func set_recipe(recipe: Resource) -> void:
	clear_effect()
	_live_recipe = recipe
	effect = Instance.new()
	effect.preset = recipe.copy()
	effect.solo_layer = _solo
	effect.autoplay = false
	effect.preview_enabled = true
	effect.quality = Instance.Quality.STANDARD if _solo >= 0 else _quality
	world.add_child(effect)
	_bind_missile()
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
	if pixel_mode:
		# HD-2D 式的镜头：正面、低角度俯视、透视
		_focus = Vector3(0, 1.0, 0)
		_yaw = 0.0
		_pitch = 0.32
		_distance = 8.0
		camera.size = 5.0
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


# ---------------------------------------------------------------- 飞弹预览

func _build_missile_bar() -> void:
	_missile_bar = HFlowContainer.new()
	_missile_bar.visible = false
	add_child(_missile_bar)
	var title := Label.new()
	title.text = I18n.T("飞弹预览")
	_missile_bar.add_child(title)
	var target := OptionButton.new()
	for text: String in TARGET_MODES:
		target.add_item(I18n.T(text))
	target.tooltip_text = I18n.T("模拟目标移动来检查追踪路径。只影响预览，不保存到配方。")
	target.item_selected.connect(func(i: int) -> void:
		target_mode = i
		_apply_target())
	_missile_bar.add_child(target)
	var guides := CheckBox.new()
	guides.text = I18n.T("路径辅助线")
	guides.button_pressed = true
	guides.tooltip_text = I18n.T("青线为模板路径，黄线为追踪移动目标时的剩余路径；圆点可拖动。")
	guides.toggled.connect(func(on: bool) -> void:
		path_editor.guides = on
		path_editor.queue_redraw())
	_missile_bar.add_child(guides)
	var reference := CheckBox.new()
	reference.text = I18n.T("参考角色")
	reference.button_pressed = true
	reference.tooltip_text = I18n.T("在发射起点放一个约 1.9 米高的参考角色，用来对照大小。")
	reference.toggled.connect(func(on: bool) -> void:
		_show_reference = on
		_reference.visible = on and missile_config(_live_recipe) != null)
	_missile_bar.add_child(reference)
	var straw := CheckBox.new()
	straw.text = I18n.T("稻草人")
	straw.button_pressed = true
	straw.tooltip_text = I18n.T("在终点放一个稻草人（目标移动时跟着走）。飞弹打中时它会被推得摇晃、闪白，按元素染色：火烧黑、冰结霜、暗影发紫。")
	straw.toggled.connect(func(on: bool) -> void:
		_show_target = on
		_target.visible = on and missile_config(_live_recipe) != null)
	_missile_bar.add_child(straw)
	_convert_button = Button.new()
	_convert_button.text = I18n.T("转为自定义曲线")
	_convert_button.tooltip_text = I18n.T("把当前路径转成可拖动编辑的曲线（一步撤销）。")
	_convert_button.pressed.connect(func() -> void: convert_requested.emit())
	_missile_bar.add_child(_convert_button)
	_add_button = Button.new()
	_add_button.text = I18n.T("添加节点")
	_add_button.tooltip_text = I18n.T("在选中节点之后插入节点，曲线形状不变。")
	_add_button.pressed.connect(func() -> void: path_editor.add_point())
	_missile_bar.add_child(_add_button)
	_delete_button = Button.new()
	_delete_button.text = I18n.T("删除节点")
	_delete_button.tooltip_text = I18n.T("删除选中的中间节点（Delete 键）。首尾节点由起点和终点控制。")
	_delete_button.pressed.connect(func() -> void: path_editor.delete_point())
	_missile_bar.add_child(_delete_button)
	_axis_option = OptionButton.new()
	for text: String in AXIS_MODES:
		_axis_option.add_item(I18n.T(text))
	_axis_option.tooltip_text = I18n.T("拖动时限制移动方向。也可以在预览里按 X / Y / Z 切换，再按一次取消。")
	_axis_option.item_selected.connect(func(i: int) -> void: path_editor.axis = i)
	_missile_bar.add_child(_axis_option)
	var hint := Label.new()
	hint.text = I18n.T("左键拖动圆点 · 右键转镜头 · Esc 取消拖动")
	hint.modulate = Color(1, 1, 1, .6)
	_missile_bar.add_child(hint)


static func missile_layer(recipe: Resource) -> int:
	if recipe == null:
		return -1
	for i in recipe.layers.size():
		var layer: Resource = recipe.layers[i]
		if layer.kind == Layer.Kind.MISSILE and layer.missile != null:
			return i
	return -1


static func missile_config(recipe: Resource) -> Resource:
	var index := missile_layer(recipe)
	return recipe.layers[index].missile if index >= 0 else null


func _bind_missile() -> void:
	var c := missile_config(_live_recipe)
	_missile_bar.visible = c != null
	_reference.visible = c != null and _show_reference
	_target.visible = c != null and _show_target
	if is_instance_valid(effect):
		effect.target_sampler = missile_target if c != null and target_mode > 0 else Callable()
	path_editor.setup(c, int(_live_recipe.seed) if c != null else 42)
	if c == null:
		return
	_reference.position = Vector3(c.start.x, 0, c.start.z)
	var custom: bool = c.path_mode == MissileConfig.PathMode.CUSTOM and c.custom_curve != null
	_convert_button.visible = not custom
	_add_button.visible = custom
	_delete_button.visible = custom


## 预览用的模拟目标（世界坐标）：在终点附近按选定方式移动。预览实例在原点，所以本地坐标即世界坐标。
func missile_target(at_time: float) -> Vector3:
	var c: Resource = missile_config(effect.preset) if is_instance_valid(effect) else null
	if c == null:
		return Vector3.ZERO
	var offset := Vector3.ZERO
	match target_mode:
		1: offset = Vector3(0, 0, at_time * 1.4)
		2: offset = Vector3((cos(at_time * 3) - 1) * .65, 0, sin(at_time * 3) * .9)
		3: offset = Vector3(0, 0, asin(sin(at_time * 4)) * 1.1)
	return c.end + offset


func _apply_target() -> void:
	if not is_instance_valid(effect):
		return
	effect.target_sampler = missile_target if missile_config(effect.preset) != null and target_mode > 0 else Callable()
	effect._replay_records.clear()
	effect.seek(effect.time)


## 拖动中的临时预览：只换预览实例的配方副本，不改会话里的配方
func preview_config(c: Resource) -> void:
	if not is_instance_valid(effect) or _live_recipe == null or c == null:
		return
	var recipe: Resource = _live_recipe.copy()
	var index := missile_layer(recipe)
	if index < 0:
		return
	recipe.layers[index].missile = c.copy()
	var at: float = effect.time
	effect.preset = recipe
	effect._replay_records.clear()
	effect.seek(at)
	_reference.position = Vector3(c.start.x, 0, c.start.z)


## 稻草人跟着预览走：站在终点（目标移动时站在目标脚下），按预览里飞弹打中的时刻做反应
func _process(_delta: float) -> void:
	if _target == null or not _target.visible or not is_instance_valid(effect):
		return
	var c := missile_config(effect.preset)
	if c == null:
		return
	var at: Vector3 = missile_target(effect.time) if target_mode > 0 else c.end
	_target.position = Vector3(at.x, 0, at.z)
	_target.set_state(effect.time, _missile_hits())


## 预览里每枚飞弹打中的时刻、来势和元素（按配方算，来回拖动时间轴也一样）
func _missile_hits() -> Array:
	var hits: Array = []
	var index := missile_layer(effect.preset)
	if index < 0:
		return hits
	var layer: Resource = effect.preset.layers[index]
	var element := _element(layer.missile)
	for i in effect._visuals.size():
		if effect._indices[i] != index or not "states" in effect._visuals[i]:
			continue
		for s: Dictionary in effect._visuals[i].states:
			if s.launched and s.ended and not s.cancelled:
				hits.append({"t": float(layer.delay) + float(s.end_time), "element": element, "push": 1.2, "dir": s.velocity})
	return hits


## 飞弹打中时稻草人染什么色：看命中造型（火、冰、暗），其他命中造型看弹头造型；剑不染色
static func _element(c: Resource) -> String:
	if c.impact_style in [MissileConfig.Impact.PIXEL_FIRE, MissileConfig.Impact.FLAME]: return "fire"
	if c.impact_style in [MissileConfig.Impact.PIXEL_ICE, MissileConfig.Impact.ICE]: return "ice"
	if c.impact_style in [MissileConfig.Impact.PIXEL_SHADOW, MissileConfig.Impact.SHADOW]: return "shadow"
	return ["", "fire", "ice", "shadow"][clampi(c.head_style, 0, 3)]


# ---------------------------------------------------------------- 像素特效的三维预览

func _build_pixel_bar() -> void:
	_pixel_bar = HFlowContainer.new()
	_pixel_bar.visible = false
	add_child(_pixel_bar)
	var title := Label.new()
	title.text = I18n.T("HD-2D 场景")
	_pixel_bar.add_child(title)
	var place := OptionButton.new()
	for text: String in PLACE_MODES:
		place.add_item(I18n.T(text))
	place.tooltip_text = I18n.T("特效原点放在哪里。自动：原点画在画布下部的（爆炸、尘土、烟雾弹）放脚底，其余（刀光、命中）放身体高度。")
	place.item_selected.connect(func(i: int) -> void:
		place_mode = i
		place_changed.emit())
	_pixel_bar.add_child(place)
	var reference := CheckBox.new()
	reference.text = I18n.T("参考角色")
	reference.button_pressed = true
	reference.tooltip_text = I18n.T("在特效原点放一个约 1.9 米高的参考角色，用来对照大小。")
	reference.toggled.connect(func(on: bool) -> void:
		_pixel_reference = on
		_reference.visible = on and pixel_mode)
	_pixel_bar.add_child(reference)
	var hint := Label.new()
	hint.text = I18n.T("右键拖动转镜头 · 滚轮缩放")
	hint.modulate = Color(1, 1, 1, .6)
	_pixel_bar.add_child(hint)


## 进入像素模式：清掉三维配方实例，铺地面，透视低角度镜头
func enter_pixel_mode() -> void:
	if pixel_mode:
		return
	clear_effect()
	_live_recipe = null
	pixel_mode = true
	_missile_bar.visible = false
	path_editor.setup(null, 42)
	_pixel_bar.visible = true
	_quality_option.visible = false
	_floor.visible = true
	_reference.position = Vector3.ZERO
	_reference.visible = _pixel_reference
	_saved_projection = camera.projection
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_projection.select(1)
	reset_camera()


func exit_pixel_mode() -> void:
	if not pixel_mode:
		return
	pixel_mode = false
	if is_instance_valid(_pixel):
		_pixel.free()
	_pixel = null
	_pixel_bar.visible = false
	_quality_option.visible = true
	_floor.visible = false
	_reference.visible = false
	camera.projection = _saved_projection
	_projection.select(0 if _saved_projection == Camera3D.PROJECTION_ORTHOGONAL else 1)
	reset_camera()


## 显示像素特效的一帧。canvas / origin 是画布尺寸和原点（像素），on_ground = true 时原点贴地，否则在身体高度
func set_pixel_frame(texture: Texture2D, canvas: Vector2i, origin: Vector2, on_ground: bool) -> void:
	if not pixel_mode:
		return
	if not is_instance_valid(_pixel):
		_pixel = Sprite3D.new()
		_pixel.centered = false
		_pixel.pixel_size = PIXEL_SIZE
		_pixel.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_pixel.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# 柔光、叠加光、半透明烟雾要按透明度混合；特效总画在角色前面（游戏里命中、爆炸也是盖在角色身上）
		_pixel.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_pixel.no_depth_test = true
		_pixel.render_priority = 1
		_pixel.shaded = false
		_pixel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(_pixel)
	_pixel.texture = texture
	_pixel.visible = texture != null
	# 帧图左上为原点、y 向下；Sprite3D 的偏移以左下为原点、y 向上
	_pixel.offset = Vector2(-origin.x, -(canvas.y - origin.y))
	var ground := on_ground if place_mode == 0 else place_mode == 1
	_pixel.position = Vector3(0, 0.0 if ground else 0.8, 0)


## 让镜头框住整个像素特效：烟花这类很高的特效拉远、对准中间；矮的特效至少框住参考角色
func fit_pixel(canvas: Vector2i, origin: Vector2, on_ground: bool) -> void:
	if not pixel_mode:
		return
	var ground := on_ground if place_mode == 0 else place_mode == 1
	var base := 0.0 if ground else 0.8
	var top := base + origin.y * PIXEL_SIZE
	var bottom := minf(base - (float(canvas.y) - origin.y) * PIXEL_SIZE, 0.0)
	var half_w := maxf(origin.x, float(canvas.x) - origin.x) * PIXEL_SIZE
	var extent := maxf(maxf(top - bottom, half_w * 2.0 * 0.75), 2.4)
	_focus = Vector3(0, maxf((top + bottom) * 0.5, 0.9), 0)
	_yaw = 0.0
	_pitch = 0.32
	_distance = clampf(extent * 0.5 / tan(deg_to_rad(camera.fov * 0.5)) * 1.25, 6.0, 24.0)
	camera.size = clampf(extent * 1.2, 3.0, 18.0)
	_update_camera()
