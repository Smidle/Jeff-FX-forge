@tool
extends Control
## 预览舞台：画布区域铺棋盘格（或纯色），放大绘制当前帧；可显示像素网格、锚点、参考图。
## 滚轮缩放、中键拖动平移、右键拖动参考图、双击左键恢复自适应视图。

const I18n := preload("i18n.gd")

signal zoom_changed(zoom: int)

enum Bg { CHECKER, DARK, LIGHT, CUSTOM }

const MAX_ZOOM := 16

var texture: Texture2D = null
var canvas_size := Vector2i(64, 64)
## 锚点（画布像素坐标）
var origin := Vector2(32, 32)
var zoom := 4
var auto_zoom := true
var pan := Vector2.ZERO
var bg_mode := Bg.CHECKER
var bg_custom := Color(0.32, 0.42, 0.36)
var show_grid := false
var show_pivot := true
var reference: Texture2D = null
## 参考图中心相对锚点的偏移（画布像素）
var reference_offset := Vector2.ZERO
## 一次性特效循环预览时的间隔期：画布留空
var blank := false

var _pan_drag := false
var _ref_drag := false


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	focus_mode = Control.FOCUS_CLICK
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(240, 200)
	tooltip_text = I18n.T("滚轮缩放 · 中键拖动平移 · 右键拖动参考图 · 双击恢复视图")


func set_canvas(sz: Vector2i, org: Vector2) -> void:
	canvas_size = sz
	origin = org
	if auto_zoom:
		_fit()
	queue_redraw()


func set_frame(tex: Texture2D, is_blank: bool = false) -> void:
	texture = tex
	blank = is_blank
	queue_redraw()


func set_zoom(z: int) -> void:
	zoom = clampi(z, 1, MAX_ZOOM)
	auto_zoom = false
	zoom_changed.emit(zoom)
	queue_redraw()


func reset_view() -> void:
	auto_zoom = true
	pan = Vector2.ZERO
	_fit()
	queue_redraw()


func canvas_rect() -> Rect2:
	var cs := Vector2(canvas_size) * zoom
	return Rect2(((size - cs) * 0.5 + pan).floor(), cs)


func _fit() -> void:
	var avail := size - Vector2(24, 24)
	if avail.x <= 0 or avail.y <= 0 or canvas_size.x <= 0 or canvas_size.y <= 0:
		return
	zoom = clampi(int(floor(minf(avail.x / canvas_size.x, avail.y / canvas_size.y))), 1, MAX_ZOOM)
	zoom_changed.emit(zoom)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if auto_zoom:
			_fit()
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color("preview_surround", "JeffFX"))
	var r := canvas_rect()
	match bg_mode:
		Bg.CHECKER:
			_draw_checker(r)
		Bg.DARK:
			draw_rect(r, Color(0.12, 0.12, 0.16))
		Bg.LIGHT:
			draw_rect(r, Color(0.91, 0.89, 0.82))
		Bg.CUSTOM:
			draw_rect(r, bg_custom)
	if reference != null:
		var rs := Vector2(reference.get_size()) * zoom
		var center := r.position + (origin + reference_offset) * zoom
		draw_texture_rect(reference, Rect2((center - rs * 0.5).floor(), rs), false)
	if texture != null and not blank:
		draw_texture_rect(texture, r, false)
	if show_grid and zoom >= 6:
		_draw_grid(r)
	draw_rect(r, Color(1, 1, 1, 0.22), false, 1.0)
	if show_pivot:
		var p := (r.position + origin * zoom).floor() + Vector2(0.5, 0.5)
		var c := Color(1.0, 0.36, 0.32, 0.95)
		draw_line(p - Vector2(7, 0), p + Vector2(8, 0), c, 1.0)
		draw_line(p - Vector2(0, 7), p + Vector2(0, 8), c, 1.0)


func _draw_checker(r: Rect2) -> void:
	var cell := float(maxi(zoom * 4, 8))
	draw_rect(r, Color(0.165, 0.165, 0.205))
	var c2 := Color(0.205, 0.205, 0.255)
	var nx := int(ceil(r.size.x / cell))
	var ny := int(ceil(r.size.y / cell))
	for j in ny:
		for i in nx:
			if (i + j) % 2 == 1:
				draw_rect(Rect2(r.position + Vector2(i, j) * cell, Vector2(cell, cell)).intersection(r), c2)


func _draw_grid(r: Rect2) -> void:
	var c := Color(1, 1, 1, 0.07)
	var x0 := maxi(0, int((0.0 - r.position.x) / zoom))
	var x1 := mini(canvas_size.x, int((size.x - r.position.x) / zoom) + 1)
	var y0 := maxi(0, int((0.0 - r.position.y) / zoom))
	var y1 := mini(canvas_size.y, int((size.y - r.position.y) / zoom) + 1)
	for x in range(x0, x1 + 1):
		var px := r.position.x + x * zoom + 0.5
		draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), c, 1.0)
	for y in range(y0, y1 + 1):
		var py := r.position.y + y * zoom + 0.5
		draw_line(Vector2(r.position.x, py), Vector2(r.end.x, py), c, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoom(zoom + 1)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoom(zoom - 1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_pan_drag = mb.pressed
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and reference != null:
			_ref_drag = mb.pressed
			accept_event()
		elif mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			reset_view()
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pan_drag:
			pan += mm.relative
			queue_redraw()
			accept_event()
		elif _ref_drag:
			reference_offset += mm.relative / float(zoom)
			queue_redraw()
			accept_event()
