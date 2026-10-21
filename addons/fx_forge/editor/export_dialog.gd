@tool
extends ConfirmationDialog
## 导出设置对话框。确认后发出 export_requested(settings)。

signal export_requested(settings: Dictionary)

const FxExport := preload("../export/fx_export.gd")

var _base: LineEdit
var _dir: LineEdit
var _dir_dialog: FileDialog
var _layout: OptionButton
var _columns: SpinBox
var _columns_label: Label
var _padding: SpinBox
var _margin: SpinBox
var _trim: CheckBox
var _scale: OptionButton
var _dirs: OptionButton
var _dirs_hint: Label
var _variants: SpinBox
var _json: CheckBox
var _sf: CheckBox
var _scene: CheckBox
var _seq: CheckBox
var _copy: CheckBox
var _blend: OptionButton
var _summary: Label
var _frames := 1


func _init() -> void:
	title = "导出精灵图"
	ok_button_text = "导出"
	cancel_button_text = "取消"
	confirmed.connect(func() -> void: export_requested.emit(collect()))


func _ready() -> void:
	var s := EditorInterface.get_editor_scale()
	var root := VBoxContainer.new()
	root.custom_minimum_size.x = 460 * s
	add_child(root)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(10 * s))
	root.add_child(grid)

	_base = LineEdit.new()
	_base.tooltip_text = "导出文件的名字，只能用英文字母、数字、下划线"
	_add_row(grid, "文件名", _base)

	var dir_row := HBoxContainer.new()
	_dir = LineEdit.new()
	_dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_row.add_child(_dir)
	var browse := Button.new()
	browse.text = "浏览…"
	browse.pressed.connect(func() -> void: _dir_dialog.popup_centered_ratio(0.5))
	dir_row.add_child(browse)
	_add_row(grid, "保存到", dir_row)

	var layout_row := HBoxContainer.new()
	_layout = _option(FxExport.LAYOUT_OPTIONS)
	_layout.item_selected.connect(func(_i: int) -> void: _refresh())
	layout_row.add_child(_layout)
	_columns_label = Label.new()
	_columns_label.text = "列数"
	layout_row.add_child(_columns_label)
	_columns = _spin(1, 64)
	layout_row.add_child(_columns)
	_add_row(grid, "排列", layout_row)

	var gap_row := HBoxContainer.new()
	_padding = _spin(0, 16)
	_padding.suffix = "px"
	_padding.tooltip_text = "相邻两帧之间留多少空白"
	gap_row.add_child(_padding)
	var ml := Label.new()
	ml.text = "边距"
	gap_row.add_child(ml)
	_margin = _spin(0, 16)
	_margin.suffix = "px"
	_margin.tooltip_text = "整张图四周留多少空白"
	gap_row.add_child(_margin)
	_add_row(grid, "间距", gap_row)

	_trim = CheckBox.new()
	_trim.text = "裁掉所有帧共同的空白（锚点自动换算）"
	_add_row(grid, "裁边", _trim)

	_scale = _option([[1, "1×（游戏里用这个）"], [2, "2×"], [3, "3×"], [4, "4×"]])
	_scale.tooltip_text = "放大导出，适合发图分享；游戏里一般用 1× 再整体放大画面"
	_add_row(grid, "放大倍数", _scale)

	var dirs_box := VBoxContainer.new()
	_dirs = _option(FxExport.DIRECTION_OPTIONS)
	_dirs.item_selected.connect(func(_i: int) -> void: _refresh())
	dirs_box.add_child(_dirs)
	_dirs_hint = Label.new()
	_dirs_hint.modulate = Color(1, 1, 1, 0.6)
	_dirs_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dirs_box.add_child(_dirs_hint)
	_add_row(grid, "方向批量", dirs_box)

	_variants = _spin(1, 8)
	_variants.tooltip_text = "用不同的随机种子各导出一份，游戏里随机挑一个播放更自然"
	_variants.value_changed.connect(func(_v: float) -> void: _refresh())
	_add_row(grid, "随机变体", _variants)

	var outs := VBoxContainer.new()
	var png := CheckBox.new()
	png.text = "精灵图 PNG（必选）"
	png.button_pressed = true
	png.disabled = true
	outs.add_child(png)
	_json = _check(outs, "JSON 数据（Aseprite 格式，其他引擎可读）")
	_sf = _check(outs, "SpriteFrames 动画资源（.tres）")
	_scene = _check(outs, "即用场景（.tscn，拖进游戏就能播放）")
	_seq = _check(outs, "单帧序列 PNG（可在 Aseprite 里打开修改）")
	_copy = _check(outs, "预设副本（以后双击它回来继续改）")
	_scene.toggled.connect(func(on: bool) -> void:
		if on:
			_sf.button_pressed = true
		_sf.disabled = on)
	_add_row(grid, "导出内容", outs)

	_blend = _option(FxExport.BLEND_OPTIONS)
	_blend.tooltip_text = "发光叠加：特效颜色叠加到背景上，适合火焰、魔法等发光特效"
	_add_row(grid, "场景混合", _blend)

	_summary = Label.new()
	_summary.modulate = Color(0.75, 0.9, 1.0)
	root.add_child(_summary)

	_dir_dialog = FileDialog.new()
	_dir_dialog.title = "选择导出目录"
	_dir_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = FileDialog.ACCESS_RESOURCES
	_dir_dialog.dir_selected.connect(func(d: String) -> void:
		_dir.text = d if d.ends_with("/") else d + "/")
	add_child(_dir_dialog)


## frames：每个动画的帧数；directional：特效里有没有受方向影响的图层
func open(settings: Dictionary, frames: int, directional: bool) -> void:
	_frames = frames
	_base.text = settings["base_name"]
	_dir.text = settings["out_dir"]
	_select(_layout, settings["layout"])
	_columns.value = settings["columns"]
	_padding.value = settings["padding"]
	_margin.value = settings["margin"]
	_trim.button_pressed = settings["trim"]
	_select(_scale, settings["scale"])
	_select(_dirs, settings["directions"])
	_variants.value = settings["variants"]
	_json.button_pressed = settings["json"]
	_sf.button_pressed = settings["sprite_frames"]
	_scene.button_pressed = settings["scene"]
	_sf.disabled = _scene.button_pressed
	_seq.button_pressed = settings["sequence"]
	_copy.button_pressed = settings["preset_copy"]
	_select(_blend, settings["blend"])
	_dirs_hint.text = "" if directional else "这个特效不受方向影响，各方向会完全一样。"
	_refresh()
	popup_centered()
	_base.grab_focus()


func collect() -> Dictionary:
	return {
		"base_name": _base.text,
		"out_dir": _dir.text,
		"layout": _layout.get_selected_metadata(),
		"columns": int(_columns.value),
		"padding": int(_padding.value),
		"margin": int(_margin.value),
		"trim": _trim.button_pressed,
		"scale": _scale.get_selected_metadata(),
		"directions": _dirs.get_selected_metadata(),
		"variants": int(_variants.value),
		"json": _json.button_pressed,
		"sprite_frames": _sf.button_pressed or _scene.button_pressed,
		"scene": _scene.button_pressed,
		"sequence": _seq.button_pressed,
		"preset_copy": _copy.button_pressed,
		"blend": _blend.get_selected_metadata(),
	}


func _refresh() -> void:
	var grid_mode: bool = _layout.get_selected_metadata() == "grid"
	_columns.visible = grid_mode
	_columns_label.visible = grid_mode
	var per_dir := {"none": 1, "mirror": 2, "4": 4, "8": 8}
	var n: int = per_dir.get(_dirs.get_selected_metadata(), 1) * int(_variants.value)
	_summary.text = "将导出 %d 个动画，每个 %d 帧。" % [n, _frames]


func _add_row(grid: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _option(options: Array) -> OptionButton:
	var ob := OptionButton.new()
	for i in options.size():
		ob.add_item(str(options[i][1]))
		ob.set_item_metadata(i, options[i][0])
	return ob


func _select(ob: OptionButton, value: Variant) -> void:
	for i in ob.item_count:
		if ob.get_item_metadata(i) == value:
			ob.select(i)
			return
	ob.select(0)


func _spin(lo: int, hi: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = 1
	return sb


func _check(box: VBoxContainer, text: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = text
	box.add_child(cb)
	return cb
