@tool
extends ConfirmationDialog
## 色板编辑对话框：编辑一条从暗到亮的色阶（2~12 色）。
## 三种做法：逐个改色块；用一个颜色自动生成色阶；导入 Lospec .hex / GIMP .gpl / 调色板图片后点选颜色。
## 确认后发出 palette_confirmed(colors)。

signal palette_confirmed(colors: PackedColorArray)

const I18n := preload("i18n.gd")
const FxPalette := preload("../core/fx_palette.gd")
const MAX_COLORS := 12

var _colors := PackedColorArray()
var _ramp_box: HFlowContainer
var _preview: TextureRect
var _base: ColorPickerButton
var _steps: SpinBox
var _import_box: HFlowContainer
var _import_label: Label
var _import_buttons: HBoxContainer
var _imported := PackedColorArray()
var _file_dialog: FileDialog
var _scale := 1.0


func _init() -> void:
	title = I18n.T("编辑色板")
	ok_button_text = I18n.T("使用这个色板")
	cancel_button_text = I18n.T("取消")
	confirmed.connect(func() -> void: palette_confirmed.emit(_colors.duplicate()))


func _ready() -> void:
	_scale = EditorInterface.get_editor_scale()
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(520, 0) * _scale
	root.add_theme_constant_override("separation", int(8 * _scale))
	add_child(root)

	root.add_child(_hint(I18n.T("色阶从暗到亮排列：特效最暗的地方用左边的颜色，最亮的地方用右边的颜色。点色块改颜色。")))
	_ramp_box = HFlowContainer.new()
	root.add_child(_ramp_box)
	_preview = TextureRect.new()
	_preview.custom_minimum_size = Vector2(0, 14) * _scale
	_preview.stretch_mode = TextureRect.STRETCH_SCALE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_preview)
	var tools := HBoxContainer.new()
	tools.add_child(_button(I18n.T("按亮度排序"), I18n.T("把颜色按从暗到亮重新排列"), func() -> void: _set_colors(FxPalette.sort_by_luminance(_colors))))
	tools.add_child(_button(I18n.T("反转"), I18n.T("左右顺序颠倒"), func() -> void:
		var r := _colors.duplicate()
		r.reverse()
		_set_colors(r)))
	root.add_child(tools)

	root.add_child(HSeparator.new())
	root.add_child(_title(I18n.T("用一个颜色生成色阶")))
	var gen := HBoxContainer.new()
	_base = ColorPickerButton.new()
	_base.color = Color("4f8fd8")
	_base.edit_alpha = false
	_base.custom_minimum_size = Vector2(64, 0) * _scale
	gen.add_child(_base)
	var sl := Label.new()
	sl.text = I18n.T("颜色数")
	gen.add_child(sl)
	_steps = SpinBox.new()
	_steps.min_value = 3
	_steps.max_value = 8
	_steps.value = 6
	gen.add_child(_steps)
	gen.add_child(_button(I18n.T("生成"), I18n.T("暗部偏冷、亮部偏暖的像素画常用色阶，会替换上面的色阶"), func() -> void:
		_set_colors(FxPalette.ramp_from_color(_base.color, int(_steps.value)))))
	root.add_child(gen)

	root.add_child(HSeparator.new())
	root.add_child(_title(I18n.T("导入色板文件")))
	var imp := HBoxContainer.new()
	imp.add_child(_button(I18n.T("选择文件…"), I18n.T("支持 Lospec 的 .hex、GIMP / Aseprite 的 .gpl、调色板 PNG 图片"), func() -> void:
		_file_dialog.popup_centered_ratio(0.6)))
	_import_label = Label.new()
	_import_label.text = I18n.T("支持 Lospec .hex、GIMP .gpl、调色板图片")
	_import_label.modulate = Color(1, 1, 1, 0.6)
	imp.add_child(_import_label)
	root.add_child(imp)
	_import_box = HFlowContainer.new()
	root.add_child(_import_box)
	_import_buttons = HBoxContainer.new()
	_import_buttons.add_child(_button(I18n.T("挑 6 个当色阶"), I18n.T("按亮度均匀挑 6 个颜色，替换上面的色阶"), func() -> void:
		_set_colors(FxPalette.pick_ramp(_imported, 6))))
	_import_buttons.add_child(_button(I18n.T("全部使用"), I18n.T("按亮度排序后全部放进色阶（最多 12 个）"), func() -> void:
		_set_colors(FxPalette.pick_ramp(_imported, MAX_COLORS))))
	_import_buttons.visible = false
	root.add_child(_import_buttons)
	root.add_child(_hint(I18n.T("点上面导入的任意颜色，可以把它加到色阶末尾。")))

	_file_dialog = FileDialog.new()
	_file_dialog.title = I18n.T("导入色板文件")
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters = PackedStringArray(["*.hex ; Lospec HEX", I18n.T("*.gpl ; GIMP / Aseprite 色板"), I18n.T("*.png ; 调色板图片")])
	_file_dialog.file_selected.connect(_import_file)
	add_child(_file_dialog)


## 打开对话框编辑一条色阶
func open(colors: PackedColorArray, slot_name: String) -> void:
	title = I18n.T("编辑色板：") + slot_name
	_set_colors(colors)
	popup_centered()


func _set_colors(colors: PackedColorArray) -> void:
	_colors = colors.duplicate()
	if _colors.size() > MAX_COLORS:
		_colors.resize(MAX_COLORS)
	_rebuild_ramp()


func _rebuild_ramp() -> void:
	for c in _ramp_box.get_children():
		c.queue_free()
	for i in _colors.size():
		var cell := VBoxContainer.new()
		var cp := ColorPickerButton.new()
		cp.color = _colors[i]
		cp.edit_alpha = false
		cp.custom_minimum_size = Vector2(34, 26) * _scale
		cp.tooltip_text = "#" + _colors[i].to_html(false)
		var idx := i
		cp.color_changed.connect(func(c: Color) -> void:
			_colors[idx] = c
			_update_preview())
		cell.add_child(cp)
		var del := Button.new()
		del.text = "×"
		del.flat = true
		del.tooltip_text = I18n.T("删掉这个颜色")
		del.disabled = _colors.size() <= 2
		del.pressed.connect(func() -> void:
			_colors.remove_at(idx)
			_rebuild_ramp())
		cell.add_child(del)
		_ramp_box.add_child(cell)
	if _colors.size() < MAX_COLORS:
		var add := Button.new()
		add.text = "+"
		add.tooltip_text = I18n.T("在末尾加一个更亮的颜色")
		add.custom_minimum_size = Vector2(34, 26) * _scale
		add.pressed.connect(func() -> void:
			var last := _colors[_colors.size() - 1] if not _colors.is_empty() else Color.GRAY
			_colors.append(last.lightened(0.25))
			_rebuild_ramp())
		_ramp_box.add_child(add)
	_update_preview()
	get_ok_button().disabled = _colors.size() < 2


func _update_preview() -> void:
	if _colors.is_empty():
		_preview.texture = null
		return
	var img := Image.create_empty(_colors.size(), 1, false, Image.FORMAT_RGBA8)
	for i in _colors.size():
		img.set_pixel(i, 0, _colors[i])
	_preview.texture = ImageTexture.create_from_image(img)


func _import_file(path: String) -> void:
	_imported = FxPalette.load_file(path)
	for c in _import_box.get_children():
		c.queue_free()
	if _imported.is_empty():
		_import_label.text = I18n.T("没有从这个文件里读到颜色：") + path.get_file()
		_import_buttons.visible = false
		return
	_import_label.text = I18n.T("%s：%d 种颜色") % [path.get_file(), _imported.size()]
	for c in _imported:
		var b := Button.new()
		b.custom_minimum_size = Vector2(20, 20) * _scale
		b.tooltip_text = I18n.T("#%s —— 点击加到色阶末尾") % c.to_html(false)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		var picked := c
		b.pressed.connect(func() -> void:
			if _colors.size() < MAX_COLORS:
				_colors.append(picked)
				_rebuild_ramp())
		_import_box.add_child(b)
	_import_buttons.visible = true


func _button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(cb)
	return b


func _title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", EditorInterface.get_editor_theme().get_font(&"bold", &"EditorFonts"))
	return l


func _hint(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0.65)
	return l
