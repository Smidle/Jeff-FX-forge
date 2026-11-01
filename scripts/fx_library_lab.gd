@tool
extends Node3D
## Standalone 3D integration lab. F6 runs this scene without changing the courtyard.
const Classic := preload("res://addons/fx_forge/presets/classic_presets.gd")
const Catalog := preload("res://addons/fx_forge/presets/library_catalog.gd")
const Instance := preload("res://addons/fx_forge/legacy/runtime/fx_instance.gd")
const FONT := preload("res://assets/courtyard/fonts/Unifont16.otf")
const SceneMenu := preload("res://scripts/scene_menu.gd")

@onready var camera: Camera3D = $Camera3D
@onready var actor: CharacterBody3D = $Actor
@onready var target: Node3D = $Target
@onready var wall: MeshInstance3D = $Occluder
@onready var environment: Environment = $WorldEnvironment.environment
@onready var effects: Node3D = $Effects
@onready var trigger: Area3D = $TriggerZone

var effect: Instance
var entries: Array = []
var selected: Dictionary = {}
var list: ItemList
var search: LineEdit
var usage: OptionButton
var style: OptionButton
var method: OptionButton
var mode: OptionButton
var quality: OptionButton
var title: Label
var details: Label
var metrics: Label
var timeline: HSlider
var _seeking := false
var _clock := 0.0
var _finished := 0
var _arrived := 0
var _mode := 0
var _quality := Instance.Quality.STANDARD
var _preview_scale := 1.0
var _orbit := false
var _yaw := .38
var _pitch := .62
var _distance := 11.0
var _timeline_dragging := false

func _ready() -> void:
	if Engine.is_editor_hint() and not has_meta("library_qa_preview"):
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	_build_grid()
	_build_ui()
	trigger.body_entered.connect(_on_trigger_entered)
	_reload_catalog()
	_rebuild_list()
	if list.item_count > 0:
		var initial := 0
		for i in list.item_count:
			if str(list.get_item_metadata(i).get("id", "")).begins_with("classic_ext_"):
				initial = i
				break
		list.select(initial)
		list.ensure_current_is_visible()
		_select(initial)
	_update_camera()
	add_child(SceneMenu.new())

func _exit_tree() -> void:
	_clear_effect()

func _build_grid() -> void:
	var grid := MeshInstance3D.new()
	grid.name = "MeterGrid"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-8, 9):
		mesh.surface_add_vertex(Vector3(i, .002, -6))
		mesh.surface_add_vertex(Vector3(i, .002, 6))
	for i in range(-6, 7):
		mesh.surface_add_vertex(Vector3(-8, .002, i))
		mesh.surface_add_vertex(Vector3(8, .002, i))
	mesh.surface_end()
	grid.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("294353")
	grid.material_override = material
	add_child(grid)

func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.035, .07, .11, .96)
	box.border_color = Color("345166")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "LabHUD"
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = FONT
	root.theme.default_font_size = 16
	canvas.add_child(root)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = 292
	panel.offset_bottom = -16
	panel.add_theme_stylebox_override("panel", _panel())
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Jeff FX · 3D 分类试验场"
	heading.add_theme_color_override("font_color", Color("83dfcf"))
	column.add_child(heading)
	search = LineEdit.new()
	search.placeholder_text = "名称、题材、元素…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: _rebuild_list())
	column.add_child(search)
	usage = _facet(column, "usage", "全部用途")
	style = _facet(column, "style", "全部画风")
	method = _facet(column, "method", "全部制作方式")
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(240, 170)
	list.item_selected.connect(_select)
	column.add_child(list)
	var refresh := Button.new()
	refresh.text = "刷新已验收效果"
	refresh.pressed.connect(func() -> void:
		_reload_catalog()
		_rebuild_list())
	column.add_child(refresh)
	var hint := Label.new()
	hint.text = "只播放当前效果\nWASD / 方向键移动参照人\n右键拖动视角 · 滚轮缩放\nR 重播 · P 暂停 · F 单步\nEsc 切换测试场景"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("91a5b4"))
	column.add_child(hint)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 308
	top.offset_top = 16
	top.offset_right = -16
	top.offset_bottom = 178
	top.add_theme_stylebox_override("panel", _panel())
	root.add_child(top)
	var controls := VBoxContainer.new()
	top.add_child(controls)
	title = Label.new()
	title.text = "选择一个效果"
	title.add_theme_font_size_override("font_size", 22)
	controls.add_child(title)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color("9db3c0"))
	controls.add_child(details)
	var row := HFlowContainer.new()
	controls.add_child(row)
	mode = _option(row, ["固定位置", "移动目标", "进入区域触发", "跟随角色"])
	mode.item_selected.connect(func(i: int) -> void:
		_mode = i
		_reset_motion()
		_clear_effect()
		if i != 2: _spawn())
	var projection := _option(row, ["正交镜头", "透视镜头"])
	projection.item_selected.connect(func(i: int) -> void:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if i == 0 else Camera3D.PROJECTION_PERSPECTIVE)
	quality = _option(row, ["标准档", "精简档"])
	quality.item_selected.connect(func(i: int) -> void:
		_quality = Instance.Quality.STANDARD if i == 0 else Instance.Quality.REDUCED
		_spawn())
	var background := _option(row, ["深色背景", "浅色背景"])
	background.item_selected.connect(func(i: int) -> void:
		environment.background_color = Color("0a1320") if i == 0 else Color("d8e0e4"))
	var wall_toggle := CheckBox.new()
	wall_toggle.text = "遮挡墙"
	wall_toggle.toggled.connect(func(on: bool) -> void: wall.visible = on)
	row.add_child(wall_toggle)
	_button(row, "重置角色 / 镜头", func() -> void:
		_reset_motion()
		_yaw = .38; _pitch = .62; _distance = 11
		_update_camera())
	var footer := PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left = 308
	footer.offset_top = -152
	footer.offset_right = -16
	footer.offset_bottom = -16
	footer.add_theme_stylebox_override("panel", _panel())
	root.add_child(footer)
	var bottom := VBoxContainer.new()
	footer.add_child(bottom)
	var playback := HFlowContainer.new()
	bottom.add_child(playback)
	_button(playback, "播放", func() -> void:
		if is_instance_valid(effect): effect.play()
		else: _spawn())
	_button(playback, "暂停", _pause)
	_button(playback, "重播", _spawn)
	_button(playback, "单步", _step)
	_button(playback, "停止并消散", func() -> void:
		if is_instance_valid(effect): effect.stop())
	_button(playback, "触发一次", _spawn)
	var speed := _option(playback, ["0.25×", "0.5×", "1×", "2×"])
	speed.select(2)
	speed.item_selected.connect(func(i: int) -> void:
		if is_instance_valid(effect): effect.speed_multiplier = [.25, .5, 1.0, 2.0][i])
	var sizes := _option(playback, ["世界尺寸 1×", "世界尺寸 0.5×", "世界尺寸 2×"])
	sizes.item_selected.connect(func(i: int) -> void:
		_preview_scale = [1.0, .5, 2.0][i]
		_spawn())
	timeline = HSlider.new()
	timeline.min_value = 0.0
	timeline.max_value = 3.0
	timeline.step = 1.0 / 60.0
	timeline.drag_started.connect(func() -> void: _timeline_dragging = true)
	timeline.drag_ended.connect(func(_changed: bool) -> void: _timeline_dragging = false)
	timeline.value_changed.connect(func(value: float) -> void:
		if not _seeking and is_instance_valid(effect): effect.seek(value))
	bottom.add_child(timeline)
	metrics = Label.new()
	metrics.add_theme_font_size_override("font_size", 14)
	metrics.add_theme_color_override("font_color", Color("a9becd"))
	bottom.add_child(metrics)

func _facet(parent: Node, facet: String, all_label: String) -> OptionButton:
	var button := OptionButton.new()
	button.add_item(all_label)
	button.set_item_metadata(0, "")
	for entry: Dictionary in Catalog.options(facet):
		button.add_item(str(entry.label))
		button.set_item_metadata(button.item_count - 1, str(entry.id))
	button.item_selected.connect(func(_i: int) -> void: _rebuild_list())
	parent.add_child(button)
	return button

func _option(parent: Node, labels: Array) -> OptionButton:
	var button := OptionButton.new()
	for text: String in labels: button.add_item(text)
	parent.add_child(button)
	return button

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _reload_catalog() -> void:
	var all_entries := Classic.catalog()
	entries.clear()
	# The lab opens on the new batch; the workshop retains its catalog order.
	for entry: Dictionary in all_entries:
		if str(entry.id).begins_with("classic_ext_"): entries.append(entry)
	for entry: Dictionary in all_entries:
		if not str(entry.id).begins_with("classic_ext_" ): entries.append(entry)

func _rebuild_list() -> void:
	if list == null: return
	list.clear()
	var query := search.text.strip_edges().to_lower()
	for entry: Dictionary in entries:
		var matches := true
		for pair: Array in [["usage", usage], ["style", style], ["method", method]]:
			var button: OptionButton = pair[1]
			var value: String = str(button.get_selected_metadata())
			if not value.is_empty() and str(entry.get(pair[0], "")) != value: matches = false
		if not matches: continue
		var haystack := (str(entry.get("display_name", "")) + " " + str(entry.get("description", "")) + " " + str(entry)).to_lower()
		if not query.is_empty() and not haystack.contains(query): continue
		var index := list.add_item(str(entry.get("display_name", entry.id)))
		list.set_item_metadata(index, entry)
		list.set_item_tooltip(index, str(entry.get("description", "")))
		if entry.id == selected.get("id", ""): list.select(index)

func _select(index: int) -> void:
	selected = list.get_item_metadata(index)
	title.text = str(selected.get("display_name", selected.id))
	var tags: Array[String] = []
	for key: String in ["usage", "subtype", "style", "method", "playback", "anchor"]:
		var value := str(selected.get(key, ""))
		if not value.is_empty(): tags.append(Catalog.name_for(key, value))
	details.text = " · ".join(tags) + "\n" + str(selected.get("description", ""))
	_finished = 0
	_arrived = 0
	_clear_effect()
	if _mode != 2: _spawn()

func _clear_effect() -> void:
	if is_instance_valid(effect):
		effect.stop(true)
		effect.queue_free()
	effect = null

func _spawn() -> void:
	if selected.is_empty(): return
	var preset: Resource = Classic.find(str(selected.id))
	if preset == null or preset.legacy_recipe == null: return
	_clear_effect()
	effect = Instance.new()
	effect.name = "SelectedEffect"
	effect.preset = preset.legacy_recipe.copy()
	effect.preset.effect_scale *= _preview_scale
	effect.autoplay = false
	effect.preview_enabled = Engine.is_editor_hint()
	effect.quality = _quality
	effect.auto_free = false
	var following := _mode == 3
	(actor if following else effects).add_child(effect)
	if following:
		effect.position = Vector3.ZERO
	elif _mode == 1 and not effect.preset.has_missile():
		effect.global_position = target.global_position
	else:
		effect.position = Vector3.ZERO
	if effect.preset.has_missile():
		effect.bind_target(target, Vector3(0, .9, 0))
	effect.finished.connect(func() -> void: _finished += 1)
	effect.arrived.connect(func(_index: int, _at: Vector3) -> void: _arrived += 1)
	timeline.max_value = maxf(.1, 10.0 if effect.preset.looping else effect.preset.total_duration())
	effect.play()

func _pause() -> void:
	if is_instance_valid(effect): effect.pause()

func _step() -> void:
	if is_instance_valid(effect): effect.step(1.0 / 30.0)

func _reset_motion() -> void:
	actor.position = Vector3(-2.2, 0, .8)
	target.position = Vector3(2.2, 0, -.4)
	_clock = 0

func _on_trigger_entered(body: Node3D) -> void:
	if _mode == 2 and body == actor: _spawn()

func _physics_process(delta: float) -> void:
	var direction := Vector3.ZERO
	if not _has_text_focus():
		direction.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		direction.z = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	actor.velocity = direction.normalized() * 3.0
	actor.move_and_slide()
	actor.position.x = clampf(actor.position.x, -6.5, 6.5)
	actor.position.z = clampf(actor.position.z, -4.5, 4.5)
	actor.position.y = 0
	if _mode == 1:
		_clock += delta
		target.position = Vector3(2.2 * cos(_clock * .7), 0, 1.7 * sin(_clock * .7))

func _process(_delta: float) -> void:
	if not is_instance_valid(effect):
		if metrics != null: metrics.text = "已验收 3D 效果 %d 款 · 当前无活动实例" % entries.size()
		return
	if not _timeline_dragging:
		_seeking = true
		timeline.set_value_no_signal(effect.time)
		_seeking = false
	metrics.text = "%.2f 秒 · %s · 图层 %d · 粒子容量 %d · 到达 %d · 完成 %d · %.0f FPS" % [effect.time, effect.backend_label(), effect._visuals.size(), effect.preset.particle_capacity(effect.is_reduced()), _arrived, _finished, Engine.get_frames_per_second()]

func _has_text_focus() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _has_text_focus():
		match event.physical_keycode:
			KEY_R: _spawn()
			KEY_P: _pause()
			KEY_F: _step()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: _orbit = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_distance = clampf(_distance * (.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 3.0, 24.0)
			_update_camera()
	if event is InputEventMouseMotion and _orbit:
		_yaw -= event.relative.x * .006
		_pitch = clampf(_pitch + event.relative.y * .006, .12, 1.35)
		_update_camera()

func _update_camera() -> void:
	var focus := Vector3(0, .65, 0)
	camera.position = focus + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	camera.size = _distance * .7
	camera.look_at(focus)
