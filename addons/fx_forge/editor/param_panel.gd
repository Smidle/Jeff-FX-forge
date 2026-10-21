@tool
extends VBoxContainer
## 参数面板：根据参数说明表自动生成控件（滑条 / 开关 / 下拉 / 颜色 / 色板）。
## 用户改动通过 value_edited 发出，phase 表示拖动状态：
##   0 普通修改；1 拖动开始后的第一次修改；2 拖动中的后续修改；3 拖动结束（只为触发完整渲染）

signal value_edited(scope: String, layer: int, id: String, value: Variant, phase: int)
signal theme_chosen(theme_id: String)
signal layer_selected(index: int)
signal action_requested(action: String)

const FxParams := preload("../core/fx_params.gd")
const FxGlobals := preload("../core/fx_globals.gd")
const FxPalette := preload("../core/fx_palette.gd")
const FxRegistry := preload("../core/fx_registry.gd")
const FxModule := preload("../modules/fx_module.gd")
const FxSession := preload("fx_session.gd")

const Kind := FxParams.Kind
const GLOBAL_GROUPS := ["canvas", "direction", "look", "outline", "cleanup"]
const PARAM_GROUPS := ["shape", "motion", "detail"]
const FOLDED_BY_DEFAULT := ["cleanup", "layer"]
## 八方向快捷按钮：[角度, 文字]（-1 = 中间空位）
const DIR_PAD := [[225, "↖"], [270, "↑"], [315, "↗"], [180, "←"], [-1, ""], [0, "→"], [135, "↙"], [90, "↓"], [45, "↘"]]
const CUSTOM_PALETTE := "__custom__"

var session: FxSession = null
var show_advanced := false
var _folded := {}
## key → {kind, control, scope, layer, id}
var _controls := {}
## key → 1（拖动刚开始）/ 2（拖动中）
var _drag := {}
var _swatches := {}
var _scale := 1.0
var _bold: Font = null


func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_controls.clear()
	_drag.clear()
	if session == null or session.preset == null:
		return
	_scale = EditorInterface.get_editor_scale()
	_bold = EditorInterface.get_editor_theme().get_font(&"bold", &"EditorFonts")
	_add_header()
	var gdefs := FxGlobals.global_defs()
	for group: String in GLOBAL_GROUPS:
		var box := _section(group, FxGlobals.GROUP_NAMES[group])
		if group == "canvas":
			_add_size_tiers(box)
		elif group == "direction":
			_add_direction_pad(box)
		for d: Dictionary in gdefs:
			if d["group"] == group and _is_shown(d):
				_add_row(box, "global", -1, d)
		if group == "canvas":
			_add_action_button(box, "自动适配画布", "按整段动画的实际范围重新设置画布大小和原点", "fit_canvas")
	if session.layer_count() > 0:
		_add_layers()
	var adv := CheckBox.new()
	adv.text = "显示高级参数"
	adv.button_pressed = show_advanced
	adv.toggled.connect(func(on: bool) -> void:
		show_advanced = on
		build.call_deferred())
	add_child(adv)


## 撤销 / 重做 / 换主题后，把控件刷新成会话里的值（不发信号）
func sync_values() -> void:
	if session == null or session.preset == null:
		return
	for key: String in _controls:
		if _drag.has(key):
			continue
		var e: Dictionary = _controls[key]
		var v: Variant = session.get_value(e["scope"], e["layer"], e["id"])
		var c: Control = e["control"]
		match int(e["kind"]):
			Kind.NUM, Kind.INT, Kind.ANGLE:
				(c as EditorSpinSlider).set_value_no_signal(float(v))
			Kind.BOOL:
				(c as CheckBox).set_pressed_no_signal(bool(v))
			Kind.ENUM, Kind.SLOT, Kind.PALETTE:
				var ob := c as OptionButton
				var target: Variant = CUSTOM_PALETTE if v is PackedColorArray else v
				for i in ob.item_count:
					if ob.get_item_metadata(i) == target:
						ob.select(i)
						break
			Kind.COLOR:
				(c as ColorPickerButton).color = v


func _is_shown(d: Dictionary) -> bool:
	return show_advanced or not d.get("advanced", false)


func _key(scope: String, id: String) -> String:
	return scope + "|" + id


func _add_header() -> void:
	var p := session.preset
	var name_edit := LineEdit.new()
	name_edit.text = p.display_name
	name_edit.placeholder_text = "特效名称"
	name_edit.tooltip_text = "特效名称（显示在预设库里）"
	if _bold != null:
		name_edit.add_theme_font_override("font", _bold)
	name_edit.text_submitted.connect(func(t: String) -> void: value_edited.emit("meta", -1, "display_name", t, 0))
	name_edit.focus_exited.connect(func() -> void: value_edited.emit("meta", -1, "display_name", name_edit.text, 0))
	add_child(name_edit)
	var info := Label.new()
	var source := "未保存的新特效"
	if session.is_user_preset():
		source = "我的预设 · " + session.source_path.get_file()
	elif not session.builtin_id.is_empty():
		source = "内置预设（修改后请「另存为」）"
	info.text = p.get_category_name() + " · " + source
	info.modulate = Color(1, 1, 1, 0.6)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(info)
	if not p.description.is_empty():
		var desc := Label.new()
		desc.text = p.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.modulate = Color(1, 1, 1, 0.78)
		add_child(desc)


func _section(group: String, title: String) -> VBoxContainer:
	var theme := EditorInterface.get_editor_theme()
	var down := theme.get_icon(&"GuiTreeArrowDown", &"EditorIcons")
	var right := theme.get_icon(&"GuiTreeArrowRight", &"EditorIcons")
	var head := Button.new()
	head.text = title
	head.flat = true
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.focus_mode = Control.FOCUS_NONE
	if _bold != null:
		head.add_theme_font_override("font", _bold)
	var body := VBoxContainer.new()
	var folded: bool = _folded.get(group, FOLDED_BY_DEFAULT.has(group))
	body.visible = not folded
	head.icon = right if folded else down
	head.pressed.connect(func() -> void:
		body.visible = not body.visible
		_folded[group] = not body.visible
		head.icon = down if body.visible else right)
	add_child(HSeparator.new())
	add_child(head)
	add_child(body)
	return body


func _label(text: String, tip: String) -> Label:
	var l := Label.new()
	l.text = text
	l.tooltip_text = tip
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.custom_minimum_size.x = 88 * _scale
	l.clip_text = true
	return l


func _tip(d: Dictionary) -> String:
	var tip: String = d.get("tip", "")
	var dv: Variant = d["default"]
	var shown := str(dv)
	if int(d["kind"]) == Kind.BOOL:
		shown = "开" if dv else "关"
	elif int(d["kind"]) == Kind.ENUM or int(d["kind"]) == Kind.SLOT:
		for o: Array in d["options"]:
			if o[0] == dv:
				shown = o[1]
	elif int(d["kind"]) == Kind.PALETTE:
		shown = FxPalette.palette_name(dv)
	var unit: String = d.get("unit", "")
	var parts := PackedStringArray()
	if not tip.is_empty():
		parts.append(tip)
	parts.append("默认：%s%s" % [shown, unit])
	return "\n".join(parts)


func _add_row(box: VBoxContainer, scope: String, layer: int, d: Dictionary) -> void:
	var id: String = d["id"]
	var key := _key(scope, id)
	var kind := int(d["kind"])
	var value: Variant = session.get_value(scope, layer, id)
	var row := HBoxContainer.new()
	row.add_child(_label(d["label"], _tip(d)))
	var ctrl: Control = null
	match kind:
		Kind.NUM, Kind.INT, Kind.ANGLE:
			ctrl = _make_slider(scope, layer, d, value)
		Kind.BOOL:
			var cb := CheckBox.new()
			cb.button_pressed = bool(value)
			cb.text = "开"
			cb.toggled.connect(func(on: bool) -> void: value_edited.emit(scope, layer, id, on, 0))
			ctrl = cb
		Kind.ENUM, Kind.SLOT:
			var ob := OptionButton.new()
			var options: Array = d["options"]
			for i in options.size():
				ob.add_item(options[i][1])
				ob.set_item_metadata(i, options[i][0])
				if options[i][0] == value:
					ob.select(i)
			ob.item_selected.connect(func(i: int) -> void:
				var picked: String = ob.get_item_metadata(i)
				if scope == "global" and id == "theme":
					theme_chosen.emit(picked)
				else:
					value_edited.emit(scope, layer, id, picked, 0))
			ctrl = ob
		Kind.COLOR:
			var cp := ColorPickerButton.new()
			cp.color = value
			cp.edit_alpha = false
			cp.custom_minimum_size = Vector2(64, 0) * _scale
			cp.color_changed.connect(func(c: Color) -> void:
				if not _drag.has(key):
					_drag[key] = 1
				_emit(key, scope, layer, id, c))
			cp.popup_closed.connect(func() -> void: _end_drag(key, scope, layer, id, cp.color))
			ctrl = cp
		Kind.PALETTE:
			ctrl = _make_palette_picker(scope, layer, id, value)
	if ctrl == null:
		return
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl.tooltip_text = _tip(d)
	row.add_child(ctrl)
	var reset := Button.new()
	reset.flat = true
	reset.focus_mode = Control.FOCUS_NONE
	reset.icon = EditorInterface.get_editor_theme().get_icon(&"Reload", &"EditorIcons")
	reset.tooltip_text = "恢复默认值"
	reset.pressed.connect(func() -> void:
		if scope == "global" and id == "theme":
			theme_chosen.emit(d["default"])
		else:
			value_edited.emit(scope, layer, id, FxParams._copy(d["default"]), 0))
	row.add_child(reset)
	box.add_child(row)
	_controls[key] = {"kind": kind, "control": ctrl, "scope": scope, "layer": layer, "id": id}


func _make_slider(scope: String, layer: int, d: Dictionary, value: Variant) -> EditorSpinSlider:
	var id: String = d["id"]
	var key := _key(scope, id)
	var kind := int(d["kind"])
	var sp := EditorSpinSlider.new()
	sp.min_value = float(d["min"])
	sp.max_value = 359.0 if kind == Kind.ANGLE else float(d["max"])
	sp.step = float(d["step"])
	sp.editing_integer = kind == Kind.INT
	sp.suffix = str(d.get("unit", ""))
	sp.set_value_no_signal(float(value))
	sp.grabbed.connect(func() -> void: _drag[key] = 1)
	sp.ungrabbed.connect(func() -> void: _end_drag(key, scope, layer, id, _num(kind, sp.value)))
	sp.value_changed.connect(func(v: float) -> void: _emit(key, scope, layer, id, _num(kind, v)))
	return sp


func _num(kind: int, v: float) -> Variant:
	return roundi(v) if kind == Kind.INT else v


func _emit(key: String, scope: String, layer: int, id: String, value: Variant) -> void:
	var phase := 0
	if _drag.has(key):
		phase = _drag[key]
		_drag[key] = 2
	value_edited.emit(scope, layer, id, value, phase)


func _end_drag(key: String, scope: String, layer: int, id: String, value: Variant) -> void:
	if _drag.has(key):
		_drag.erase(key)
		value_edited.emit(scope, layer, id, value, 3)


func _make_palette_picker(scope: String, layer: int, id: String, value: Variant) -> OptionButton:
	var ob := OptionButton.new()
	var opts := FxPalette.palette_options()
	for i in opts.size():
		ob.add_icon_item(_swatch(opts[i][0]), opts[i][1])
		ob.set_item_metadata(i, opts[i][0])
		if value is String and value == opts[i][0]:
			ob.select(i)
	if value is PackedColorArray:
		ob.add_icon_item(_swatch(value), "自定义")
		ob.set_item_metadata(opts.size(), CUSTOM_PALETTE)
		ob.select(opts.size())
	ob.item_selected.connect(func(i: int) -> void:
		var picked: String = ob.get_item_metadata(i)
		if picked != CUSTOM_PALETTE:
			value_edited.emit(scope, layer, id, picked, 0))
	return ob


## 色板色块图标
func _swatch(palette: Variant) -> Texture2D:
	var key := str(palette) if palette is String else ""
	if not key.is_empty() and _swatches.has(key):
		return _swatches[key]
	var cols := FxPalette.colors_of(palette)
	var cell := 7
	var img := Image.create_empty(cell * cols.size(), 12, false, Image.FORMAT_RGBA8)
	for i in cols.size():
		img.fill_rect(Rect2i(i * cell, 0, cell, 12), cols[i])
	var tex := ImageTexture.create_from_image(img)
	if not key.is_empty():
		_swatches[key] = tex
	return tex


func _add_size_tiers(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label("尺寸档", "一键整体缩放：小 = 0.5 倍，中 = 1 倍，大 = 2 倍"))
	for t: Array in [[0.5, "小"], [1.0, "中"], [2.0, "大"]]:
		var b := Button.new()
		b.text = t[1]
		b.tooltip_text = "整体缩放 ×%s" % str(t[0])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var factor: float = t[0]
		b.pressed.connect(func() -> void: value_edited.emit("global", -1, "size_scale", factor, 0))
		row.add_child(b)
	box.add_child(row)


func _add_direction_pad(box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_child(_label("快捷方向", "点箭头直接设置方向"))
	var grid := GridContainer.new()
	grid.columns = 3
	for e: Array in DIR_PAD:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 26) * _scale
		b.focus_mode = Control.FOCUS_NONE
		if e[0] < 0:
			b.disabled = true
			b.flat = true
		else:
			b.text = e[1]
			b.tooltip_text = "%d°" % e[0]
			var ang := float(e[0])
			b.pressed.connect(func() -> void: value_edited.emit("global", -1, "direction", ang, 0))
		grid.add_child(b)
	row.add_child(grid)
	box.add_child(row)


func _add_action_button(box: VBoxContainer, text: String, tip: String, action: String) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(func() -> void: action_requested.emit(action))
	box.add_child(b)


func _add_layers() -> void:
	var layers := session.preset.layers
	var li := clampi(session.layer_index, 0, layers.size() - 1)
	var layer: Dictionary = layers[li]
	var m: FxModule = FxRegistry.get_module(layer["module"])
	var module_name: String = m.get_display_name() if m != null else str(layer["module"])

	add_child(HSeparator.new())
	var row := HBoxContainer.new()
	row.add_child(_label("当前图层", "一个特效可以由多个图层叠成；这里选择要编辑哪一层"))
	var sel := OptionButton.new()
	sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in layers.size():
		var l: Dictionary = layers[i]
		var lm: FxModule = FxRegistry.get_module(l["module"])
		sel.add_item("%d. %s（%s）" % [i + 1, l["name"], lm.get_display_name() if lm != null else l["module"]])
	sel.select(li)
	sel.item_selected.connect(func(i: int) -> void: layer_selected.emit(i))
	row.add_child(sel)
	add_child(row)

	var lbox := _section("layer", "图层设置 · " + str(layer["name"]))
	for d: Dictionary in FxGlobals.layer_defs():
		if _is_shown(d):
			_add_row(lbox, "layer", li, d)
	if m == null:
		return
	var mdefs := m.get_param_defs()
	for group: String in PARAM_GROUPS:
		var defs: Array = []
		for d: Dictionary in mdefs:
			if d.get("group", "detail") == group and _is_shown(d):
				defs.append(d)
		if defs.is_empty():
			continue
		var box := _section(group, "%s · %s" % [FxGlobals.GROUP_NAMES[group], module_name])
		for d: Dictionary in defs:
			_add_row(box, "param", li, d)
