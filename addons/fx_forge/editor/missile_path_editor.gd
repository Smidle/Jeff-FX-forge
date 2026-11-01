@tool
extends Control
## 飞弹路径编辑覆盖层：画在 3D 预览上方，只在屏幕坐标里工作，不创建任何场景节点。
## 拖动起点 / 终点 / 曲线节点 / 切线小柄；每次完整拖动结束才提交一次（一步撤销），Esc 放弃当前拖动。
## 移植自旧版 Jeff Studio 特效插件的 missile_path_editor.gd。
signal committed(property: String, before: Variant, after: Variant)
signal preview_requested(config: Resource)
signal axis_changed(axis: int)

const I18n := preload("i18n.gd")
const Path := preload("../legacy/runtime/fx_missile_path.gd")
const Config := preload("../legacy/runtime/fx_missile_config.gd")

## 所属的 classic_stage：读取 camera、viewport、effect、target_mode、missile_target()
var stage: Control
var config: Resource
var seed: int = 42
var guides: bool = true
## 0 镜头平面；1/2/3 只沿世界 X/Y/Z 移动
var axis: int = 0:
	set(value):
		axis = clampi(value, 0, 3)
		axis_changed.emit(axis)
var selected_point: int = 1
var _handles: Array[Dictionary] = []
var _drag: Dictionary = {}
var _working: Resource
var _before: Variant
var _property: String


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_CLICK
	set_process(true)


func setup(value: Resource, random_seed: int) -> void:
	if not _drag.is_empty() and value != config:
		_drag.clear()
		_working = null
	config = value
	seed = random_seed
	visible = config != null
	queue_redraw()


func is_dragging() -> bool:
	return not _drag.is_empty()


func _process(_delta: float) -> void:
	if visible and guides:
		queue_redraw()


func project(p: Vector3) -> Vector2:
	return stage.camera.unproject_position(p) * size / Vector2(stage.viewport.size)


## 曲线坐标：X 为起终点连线上的比例（0 起点、1 终点），Y 为弧高（米），Z 为侧向（米）
func _world(p: Vector3, c: Resource) -> Vector3:
	var basis: Basis = Path.frame(c.start, c.end)
	return c.start + (c.end - c.start) * p.x + basis.y * p.y + basis.z * p.z


func _local(p: Vector3, c: Resource) -> Vector3:
	var basis: Basis = Path.frame(c.start, c.end)
	var v: Vector3 = p - c.start
	return Vector3(v.dot(basis.x) / maxf(.0001, c.start.distance_to(c.end)), v.dot(basis.y), v.dot(basis.z))


func _draw() -> void:
	_handles.clear()
	if not guides or config == null or stage == null or stage.camera == null or not is_instance_valid(stage.effect):
		return
	var c: Resource = _working if _working != null else config
	# 青线：模板路径（不含移动目标的修正）
	var path: Dictionary = Path.build(c, c.start, c.end, seed)
	var previous: Vector3 = path.points[0]
	for i in range(1, path.points.size()):
		var point: Vector3 = path.points[i]
		if not stage.camera.is_position_behind(previous) and not stage.camera.is_position_behind(point):
			draw_line(project(previous), project(point), Color(.35, .75, .8, .65), 1, true)
		previous = point
	var arrow: Vector2 = project(Path.sample(path, .56))
	var direction: Vector2 = (arrow - project(Path.sample(path, .52))).normalized()
	draw_line(arrow, arrow - direction.rotated(.55) * 11, Color("8de2d0"), 2, true)
	draw_line(arrow, arrow - direction.rotated(-.55) * 11, Color("8de2d0"), 2, true)
	_handle(c.start, "start", -1, Color("8ee1b4"), I18n.T("起点"))
	_handle(c.end, "end", -1, Color("edbc82"), I18n.T("终点"))
	if stage.target_mode > 0:
		var target: Vector3 = stage.missile_target(stage.effect.time)
		draw_arc(project(target), 10, 0, TAU, 24, Color("edbc82"), 2, true)
		_draw_tracking_path()
	if c.path_mode != Config.PathMode.CUSTOM or c.custom_curve == null:
		return
	var curve: Curve3D = c.custom_curve
	selected_point = clampi(selected_point, 0, curve.point_count - 1)
	for i in curve.point_count:
		var p: Vector3 = curve.get_point_position(i)
		if i > 0 and i < curve.point_count - 1:
			_handle(_world(p, c), "point", i, Color("f4e1a1") if i == selected_point else Color("91a8bb"), str(i))
		if i == selected_point:
			for part: String in ["in", "out"]:
				if (i == 0 and part == "in") or (i == curve.point_count - 1 and part == "out"):
					continue
				var offset: Vector3 = curve.get_point_in(i) if part == "in" else curve.get_point_out(i)
				var end: Vector3 = _world(p + offset, c)
				draw_line(project(_world(p, c)), project(end), Color("9aa7d5"), 1, true)
				_handle(end, part, i, Color("a1a1d5"), "")


func _handle(point: Vector3, kind: String, index: int, color: Color, label: String) -> void:
	if stage.camera.is_position_behind(point):
		return
	var screen: Vector2 = project(point)
	var radius := 5 if kind in ["in", "out"] else 7
	draw_circle(screen, radius, Color("101b28"))
	draw_arc(screen, radius, 0, TAU, 20, color, 2, true)
	if not label.is_empty():
		draw_string(ThemeDB.fallback_font, screen + Vector2(10, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	_handles.append({"world": point, "screen": screen, "kind": kind, "index": index})


func _gui_input(event: InputEvent) -> void:
	if config == null or not guides:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and not _drag.is_empty():
			cancel_drag()
			accept_event()
		elif event.keycode == KEY_DELETE:
			delete_point()
			accept_event()
		elif event.keycode in [KEY_X, KEY_Y, KEY_Z]:
			var picked: int = [KEY_X, KEY_Y, KEY_Z].find(event.keycode) + 1
			axis = 0 if axis == picked else picked
			accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var nearest: float = 14
			for handle: Dictionary in _handles:
				var distance: float = event.position.distance_to(handle.screen)
				if distance < nearest:
					_drag = handle
					nearest = distance
			if not _drag.is_empty():
				_working = config.copy()
				_property = _drag.kind if _drag.kind in ["start", "end"] else "custom_curve"
				_before = config.get(_property)
				selected_point = _drag.index if _drag.index >= 0 else (0 if _drag.kind == "start" else maxi(0, config.custom_curve.point_count - 1) if config.custom_curve != null else 0)
				grab_focus()
				accept_event()
		elif not _drag.is_empty():
			var value: Variant = _working.get(_property)
			_drag.clear()
			_working = null
			committed.emit(_property, _before, value)
			accept_event()
	elif event is InputEventMouseMotion and not _drag.is_empty():
		var screen: Vector2 = event.position * Vector2(stage.viewport.size) / size
		var origin: Vector3 = stage.camera.project_ray_origin(screen)
		var direction: Vector3 = stage.camera.project_ray_normal(screen)
		var plane := Plane(stage.camera.global_basis.z, _drag.world)
		var hit: Variant = plane.intersects_ray(origin, direction)
		if hit == null:
			return
		var destination: Vector3 = hit
		if axis > 0:
			var restricted: Vector3 = _drag.world
			restricted[axis - 1] = destination[axis - 1]
			destination = restricted
		if _property in ["start", "end"]:
			_working.set(_property, destination)
		else:
			var local: Vector3 = _local(destination, _working)
			var curve: Curve3D = _working.custom_curve
			var i: int = _drag.index
			if _drag.kind == "point":
				curve.set_point_position(i, local)
			elif _drag.kind == "in":
				curve.set_point_in(i, local - curve.get_point_position(i))
			else:
				curve.set_point_out(i, local - curve.get_point_position(i))
		preview_requested.emit(_working)
		queue_redraw()
		accept_event()


func cancel_drag() -> void:
	_drag.clear()
	_working = null
	if config != null:
		preview_requested.emit(config)
	queue_redraw()


## 在选中节点之后插入一个节点：用 de Casteljau 精确切分，曲线形状和两侧切线保持不变
func add_point() -> void:
	if config == null or config.custom_curve == null or config.path_mode != Config.PathMode.CUSTOM:
		return
	var before: Curve3D = config.custom_curve
	var after: Curve3D = before.duplicate(true)
	var segment: int = clampi(selected_point, 0, after.point_count - 2)
	var a: Vector3 = after.get_point_position(segment)
	var b: Vector3 = a + after.get_point_out(segment)
	var d: Vector3 = after.get_point_position(segment + 1)
	var c: Vector3 = d + after.get_point_in(segment + 1)
	var ab: Vector3 = (a + b) * .5
	var bc: Vector3 = (b + c) * .5
	var cd: Vector3 = (c + d) * .5
	var left: Vector3 = (ab + bc) * .5
	var right: Vector3 = (bc + cd) * .5
	var middle: Vector3 = (left + right) * .5
	after.set_point_out(segment, ab - a)
	after.set_point_in(segment + 1, cd - d)
	after.add_point(middle, left - middle, right - middle, segment + 1)
	selected_point = segment + 1
	committed.emit("custom_curve", before, after)


## 删除选中的中间节点（首尾节点由起点 / 终点控制，不能删）
func delete_point() -> void:
	if config == null or config.custom_curve == null or config.path_mode != Config.PathMode.CUSTOM:
		return
	if selected_point <= 0 or selected_point >= config.custom_curve.point_count - 1:
		return
	var after: Curve3D = config.custom_curve.duplicate(true)
	after.remove_point(selected_point)
	selected_point = maxi(1, selected_point - 1)
	committed.emit("custom_curve", config.custom_curve, after)


## 黄线：追踪移动目标时，每枚飞弹剩余的导引路径
func _draw_tracking_path() -> void:
	if not is_instance_valid(stage.effect):
		return
	for emitter: Node in stage.effect._visuals:
		if not emitter.has_method("history_record"):
			continue
		for s: Variant in emitter.states:
			if not s.launched or s.ended or float(s.guide_time) < 0:
				continue
			var duration: float = emitter.config.flight_seconds()
			var u: float = clampf((stage.effect.time - float(s.launch) - float(s.guide_time)) / maxf(.001, duration - float(s.guide_time)), 0, 1)
			var previous: Vector3 = s.position
			for i in range(1, 25):
				var next: Vector3 = s.p0.bezier_interpolate(s.p1, s.p2, s.end, lerpf(u, 1, i / 24.0))
				if not stage.camera.is_position_behind(previous) and not stage.camera.is_position_behind(next):
					draw_line(project(previous), project(next), Color(.8, .85, .45, .7), 1, true)
				previous = next
