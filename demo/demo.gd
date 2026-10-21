extends Node2D
## 演示场景：在游戏里试放从「特效工坊」导出的特效（res://fx_exports/ 下的 .tscn）。
##   左键：在鼠标处放出 · 空格：在小人前方放出 · 滚轮 / ← →：切换特效
##   F：左右镜像 · C：清除所有特效 · R：重新扫描导出目录

const EXPORT_DIR := "res://fx_exports/"
const VIEW := Vector2(640, 360)
const GROUND_Y := 290.0

var _scenes: Array[PackedScene] = []
var _names: PackedStringArray = []
var _index := 0
var _mirror := false
var _hero := Vector2(200, GROUND_Y)
var _fx_root: Node2D
var _label: Label


func _ready() -> void:
	_fx_root = Node2D.new()
	add_child(_fx_root)
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	layer.add_child(_label)
	_scan()


func _scan() -> void:
	_scenes.clear()
	_names.clear()
	if DirAccess.dir_exists_absolute(EXPORT_DIR):
		var files := DirAccess.get_files_at(EXPORT_DIR)
		files.sort()
		for f: String in files:
			# 导出游戏后 .tscn 会变成 .tscn.remap
			var file := f.trim_suffix(".remap")
			if not file.ends_with(".tscn"):
				continue
			var ps := load(EXPORT_DIR + file) as PackedScene
			if ps != null:
				_scenes.append(ps)
				_names.append(file.get_basename())
	_index = clampi(_index, 0, maxi(_scenes.size() - 1, 0))
	_update_label()
	queue_redraw()


func _update_label() -> void:
	if _scenes.is_empty():
		_label.text = "FX Forge 演示\n还没有导出的特效：在编辑器顶部「特效工坊」里选一个预设，点「导出精灵图…」，再回来按 F5。"
		return
	_label.text = "FX Forge 演示 · 左键：鼠标处放出 · 空格：小人前方放出 · 滚轮/←→：切换 · F：镜像（%s）· C：清除 · R：重新扫描\n当前特效：%s（%d/%d）" % [
		"开" if _mirror else "关", _names[_index], _index + 1, _scenes.size()]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("1b1b26"))
	draw_rect(Rect2(0, GROUND_Y, VIEW.x, VIEW.y - GROUND_Y), Color("262636"))
	draw_line(Vector2(0, GROUND_Y), Vector2(VIEW.x, GROUND_Y), Color("44445e"))
	# 示意小人（约 32 像素高），方便对比特效大小；特效原点默认在小人身体中心
	var p := _hero
	draw_rect(Rect2(p.x - 5, p.y - 8, 4, 8), Color("4a3b33"))
	draw_rect(Rect2(p.x + 1, p.y - 8, 4, 8), Color("4a3b33"))
	draw_rect(Rect2(p.x - 6, p.y - 22, 12, 14), Color("8c5a3c"))
	draw_rect(Rect2(p.x - 5, p.y - 31, 10, 9), Color("e8c9a8"))
	draw_rect(Rect2(p.x + 6, p.y - 20, 10, 2), Color("c8d0dc"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_spawn(get_global_mouse_position())
			MOUSE_BUTTON_WHEEL_UP:
				_select(-1)
			MOUSE_BUTTON_WHEEL_DOWN:
				_select(1)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_select(-1)
			KEY_RIGHT:
				_select(1)
			KEY_SPACE:
				_spawn(_hero + Vector2(-26.0 if _mirror else 26.0, -16))
			KEY_F:
				_mirror = not _mirror
				_update_label()
			KEY_C:
				for c in _fx_root.get_children():
					c.queue_free()
			KEY_R:
				_scan()


func _select(d: int) -> void:
	if _scenes.is_empty():
		return
	_index = posmod(_index + d, _scenes.size())
	_update_label()


func _spawn(pos: Vector2) -> void:
	if _scenes.is_empty():
		return
	var fx := _scenes[_index].instantiate() as Node2D
	fx.position = pos.round()
	if _mirror:
		fx.scale.x = -1
	_fx_root.add_child(fx)
