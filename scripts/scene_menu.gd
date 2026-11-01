extends CanvasLayer
## Esc 菜单：切换测试场景。等距测试场、3D 分类试验场共用；月下庭院在自己的暂停菜单里加了同样的页面。
## 打开时暂停游戏；场景自己的操作可以用 add_action() 加在场景列表上方（例如「清除场上效果」）。

const Scenes := preload("res://scripts/test_scenes.gd")
const FONT := preload("res://assets/courtyard/fonts/Unifont16.otf")

var _menu: Control
var _list: VBoxContainer
var _first: Button
var _actions: Array = []


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


## 在场景列表上方加一个按钮；点击后先关闭菜单、恢复游戏，再执行 callback
func add_action(text: String, callback: Callable) -> void:
	_actions.append([text, callback])


func _ready() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	_menu.theme = theme
	add_child(_menu)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var window := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.10, 0.94)
	style.border_color = Color("8f896f")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(3)
	window.add_theme_stylebox_override("panel", style)
	window.custom_minimum_size = Vector2(520, 0)
	center.add_child(window)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	window.add_child(_list)
	_menu.hide()


func _build_buttons() -> void:
	for child in _list.get_children():
		child.free()
	_first = null
	var title := Label.new()
	title.text = "测试暂停 · 切换测试场景"
	title.add_theme_font_size_override("font_size", 24)
	_list.add_child(title)
	for action: Array in _actions:
		var callback: Callable = action[1]
		_button(action[0], func() -> void:
			close()
			callback.call())
	var current := Scenes.current_path(get_tree())
	for scene: Dictionary in Scenes.LIST:
		var here: bool = scene["path"] == current
		var b := _button("%s%s" % [scene["name"], "（当前）" if here else ""], func() -> void: Scenes.change(get_tree(), scene["path"]))
		b.tooltip_text = scene["desc"]
		b.disabled = here
	_button("继续测试（Esc）", close)
	for child in _list.get_children():
		if child is Button and not child.disabled:
			_first = child
			break


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	b.pressed.connect(callback)
	_list.add_child(b)
	return b


func is_open() -> bool:
	return _menu != null and _menu.visible


func open() -> void:
	_build_buttons()
	_menu.show()
	get_tree().paused = true
	_first.grab_focus()


func close() -> void:
	_menu.hide()
	get_tree().paused = false
	var focus := _menu.get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
