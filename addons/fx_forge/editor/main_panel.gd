@tool
extends VBoxContainer
## 「特效工坊」主界面：预设库 | 预览舞台 + 时间轴 | 参数面板。
## 插件卸载前会调用 shutdown()，等后台渲染任务结束。

const FxSession := preload("fx_session.gd")
const RenderScheduler := preload("render_scheduler.gd")
const PresetBrowser := preload("preset_browser.gd")
const PreviewStage := preload("preview_stage.gd")
const Timeline := preload("timeline.gd")
const ParamPanel := preload("param_panel.gd")
const FxPreset := preload("../core/fx_preset.gd")
const FxPresetUtil := preload("../core/fx_preset_util.gd")
const FxRenderer := preload("../core/fx_renderer.gd")
const FxPalette := preload("../core/fx_palette.gd")
const FxJob := preload("../core/fx_job.gd")
const FxRegistry := preload("../core/fx_registry.gd")
const FxModule := preload("../modules/fx_module.gd")
const Builtin := preload("../presets/builtin_presets.gd")
const ExportDialog := preload("export_dialog.gd")
const FxExport := preload("../export/fx_export.gd")
const FxExporter := preload("../export/fx_exporter.gd")

## 一次性特效循环预览时，播完后停顿多久再重播（秒）
const LOOP_GAP := 0.35
## 整段渲染超过这个耗时（毫秒）时，拖动滑条只重算当前帧
const DRAG_FULL_BUDGET_MS := 45.0
const META := "fx_forge"
const ZOOMS := [0, 1, 2, 3, 4, 6, 8, 12, 16]

var session := FxSession.new()
var _scheduler: RenderScheduler
var _browser: PresetBrowser
var _stage: PreviewStage
var _timeline: Timeline
var _params: ParamPanel
var _title: Label
var _status: Label
var _warning: Label
var _fit_button: Button
var _zoom_option: OptionButton
var _bg_color: ColorPickerButton
var _ref_clear: Button
var _export_button: Button
var _discard_dialog: ConfirmationDialog
var _save_dialog: ConfirmationDialog
var _save_name: LineEdit
var _save_file: LineEdit
var _ref_dialog: FileDialog
var _export_dialog: ExportDialog
var _overwrite_dialog: ConfirmationDialog
var _result_dialog: AcceptDialog
var _pending: Array = []
var _pending_export := {}
var _result_files := PackedStringArray()
var _exporting := false

var _textures: Array = []
var _images: Array = []
var _frame := 0
var _playing := true
var _loop_preview := true
var _speed := 1.0
var _acc := 0.0
var _gap := 0.0
var _last_full_ms := 0.0
var _dragging := false
var _last_job: FxJob = null


func _init() -> void:
	_scheduler = RenderScheduler.new(func() -> Variant: return session.preset)


## 插件把编辑器的撤销管理器交进来
func setup(undo: EditorUndoRedoManager) -> void:
	session.undo = undo


func _ready() -> void:
	var s := EditorInterface.get_editor_scale()
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_make_toolbar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_browser = PresetBrowser.new()
	split.add_child(_browser)

	var split2 := HSplitContainer.new()
	split2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(split2)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split2.add_child(center)
	center.add_child(_make_preview_bar())
	_stage = PreviewStage.new()
	center.add_child(_stage)
	_timeline = Timeline.new()
	center.add_child(_timeline)
	center.add_child(_make_status_bar())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 350 * s
	split2.add_child(scroll)
	_params = ParamPanel.new()
	_params.session = session
	_params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_params)

	_make_dialogs()

	session.loaded.connect(_on_loaded)
	session.changed.connect(_on_changed)
	_scheduler.finished.connect(_on_rendered)
	_browser.preset_chosen.connect(_on_preset_chosen)
	_params.value_edited.connect(_on_value_edited)
	_params.theme_chosen.connect(_on_theme_chosen)
	_params.layer_selected.connect(func(i: int) -> void:
		session.layer_index = i
		_params.build.call_deferred())
	_params.action_requested.connect(_on_action)
	_params.layer_action.connect(_on_layer_action)
	_timeline.play_toggled.connect(_toggle_play)
	_timeline.step.connect(_step)
	_timeline.jump.connect(_jump)
	_timeline.seek.connect(_seek)
	_timeline.speed_changed.connect(func(m: float) -> void: _speed = m)
	_timeline.loop_toggled.connect(func(on: bool) -> void: _loop_preview = on)
	_stage.zoom_changed.connect(_on_stage_zoom)

	_load_initial()


func shutdown() -> void:
	_scheduler.shutdown()


func open_preset(res: Resource) -> void:
	if res is FxPreset:
		_on_preset_chosen(res, res.resource_path, "")


func has_unsaved_changes() -> bool:
	return session.dirty


func unsaved_message() -> String:
	if session.is_user_preset():
		return "特效工坊里的「%s」有未保存的修改。" % session.preset.display_name
	return "特效工坊里的「%s」有未保存的修改（选择保存会另存到「我的预设」）。" % session.preset.display_name


## 编辑器保存 / 退出时调用：用户预设直接保存；内置预设和新特效自动另存一份，避免修改丢失
func save_if_possible() -> void:
	if not session.dirty:
		return
	if session.is_user_preset():
		_save_to(session.source_path)
		return
	var file := _suggest_file_name(session.preset.preset_id)
	session.set_values("meta", -1, {"display_name": session.preset.display_name + "（自动保存）", "preset_id": file, "category": "custom"})
	_save_to(FxSession.USER_DIR + file + ".tres")


# ---------------------------------------------------------------- 界面搭建

func _icon(name: StringName) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	return theme.get_icon(name, &"EditorIcons") if theme.has_icon(name, &"EditorIcons") else null


func _tool_button(icon: StringName, text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = _icon(icon)
	b.tooltip_text = tip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _make_toolbar() -> Control:
	var bar := HBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_override("font", EditorInterface.get_editor_theme().get_font(&"bold", &"EditorFonts"))
	_title.custom_minimum_size.x = 160 * EditorInterface.get_editor_scale()
	bar.add_child(_title)
	bar.add_child(VSeparator.new())
	bar.add_child(_tool_button(&"New", "新建", "新建一个空白特效", _on_new))
	bar.add_child(_tool_button(&"Save", "保存", "保存到「我的预设」；内置预设会改为另存为", _on_save))
	bar.add_child(_tool_button(&"Duplicate", "另存为…", "另存为一个新的「我的预设」", _on_save_as))
	bar.add_child(VSeparator.new())
	bar.add_child(_tool_button(&"UndoRedo", "撤销", "撤销上一步修改（Ctrl+Z）", _on_undo))
	bar.add_child(_tool_button(&"Reload", "重做", "重做（Ctrl+Shift+Z）", _on_redo))
	bar.add_child(VSeparator.new())
	bar.add_child(_tool_button(&"RandomNumberGenerator", "换种子", "随机换一个种子，看看同一特效的其他随机变化", _on_reseed))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_export_button = Button.new()
	_export_button.text = "导出精灵图…"
	_export_button.icon = _icon(&"Save")
	_export_button.tooltip_text = "导出精灵图、SpriteFrames 和即用场景"
	_export_button.pressed.connect(_on_export)
	bar.add_child(_export_button)
	return bar


func _make_preview_bar() -> Control:
	var bar := HBoxContainer.new()
	var zl := Label.new()
	zl.text = "缩放"
	bar.add_child(zl)
	_zoom_option = OptionButton.new()
	for z: int in ZOOMS:
		_zoom_option.add_item("自适应" if z == 0 else "%d×" % z)
	_zoom_option.select(0)
	_zoom_option.tooltip_text = "预览放大倍数（只影响预览，不影响导出）"
	_zoom_option.item_selected.connect(func(i: int) -> void:
		if ZOOMS[i] == 0:
			_stage.reset_view()
		else:
			_stage.set_zoom(ZOOMS[i]))
	bar.add_child(_zoom_option)

	var bl := Label.new()
	bl.text = "背景"
	bar.add_child(bl)
	var bg := OptionButton.new()
	for t: String in ["棋盘格", "深色", "浅色", "自定义"]:
		bg.add_item(t)
	bar.add_child(bg)
	_bg_color = ColorPickerButton.new()
	_bg_color.custom_minimum_size.x = 36 * EditorInterface.get_editor_scale()
	_bg_color.color = _meta_get("bg_color", Color(0.32, 0.42, 0.36))
	_bg_color.edit_alpha = false
	bar.add_child(_bg_color)
	var bg_mode: int = _meta_get("bg_mode", 0)
	bg.select(bg_mode)
	_bg_color.visible = bg_mode == PreviewStage.Bg.CUSTOM
	bg.item_selected.connect(func(i: int) -> void:
		_stage.bg_mode = i
		_bg_color.visible = i == PreviewStage.Bg.CUSTOM
		_meta_set("bg_mode", i)
		_stage.queue_redraw())
	_bg_color.color_changed.connect(func(c: Color) -> void:
		_stage.bg_custom = c
		_meta_set("bg_color", c)
		_stage.queue_redraw())

	var grid := CheckBox.new()
	grid.text = "网格"
	grid.tooltip_text = "放大到 6 倍以上时显示像素网格"
	grid.button_pressed = _meta_get("show_grid", false)
	grid.toggled.connect(func(on: bool) -> void:
		_stage.show_grid = on
		_meta_set("show_grid", on)
		_stage.queue_redraw())
	bar.add_child(grid)
	var pivot := CheckBox.new()
	pivot.text = "锚点"
	pivot.tooltip_text = "红色十字 = 特效原点（导出后就是场景的定位点）"
	pivot.button_pressed = _meta_get("show_pivot", true)
	pivot.toggled.connect(func(on: bool) -> void:
		_stage.show_pivot = on
		_meta_set("show_pivot", on)
		_stage.queue_redraw())
	bar.add_child(pivot)

	var ref := Button.new()
	ref.text = "参考图…"
	ref.icon = _icon(&"Image")
	ref.tooltip_text = "放一张角色图片在特效后面对比大小（右键拖动可以移动）"
	ref.pressed.connect(func() -> void: _ref_dialog.popup_centered_ratio(0.6))
	bar.add_child(ref)
	_ref_clear = Button.new()
	_ref_clear.text = "移除参考图"
	_ref_clear.visible = false
	_ref_clear.pressed.connect(func() -> void:
		_stage.reference = null
		_ref_clear.visible = false
		_stage.queue_redraw())
	bar.add_child(_ref_clear)

	# 预览设置在舞台创建后再套用
	_apply_stage_prefs.call_deferred(bg_mode, grid.button_pressed, pivot.button_pressed)
	return bar


func _apply_stage_prefs(bg_mode: int, grid: bool, pivot: bool) -> void:
	_stage.bg_mode = bg_mode
	_stage.bg_custom = _bg_color.color
	_stage.show_grid = grid
	_stage.show_pivot = pivot
	_stage.queue_redraw()


func _make_status_bar() -> Control:
	var bar := HBoxContainer.new()
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.clip_text = true
	_status.modulate = Color(1, 1, 1, 0.75)
	bar.add_child(_status)
	_warning = Label.new()
	_warning.text = "⚠ 特效超出画布"
	_warning.tooltip_text = "有像素碰到了画布边缘，导出后会被裁掉"
	_warning.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_warning.visible = false
	bar.add_child(_warning)
	_fit_button = Button.new()
	_fit_button.text = "自动适配画布"
	_fit_button.visible = false
	_fit_button.pressed.connect(_fit_canvas)
	bar.add_child(_fit_button)
	return bar


func _make_dialogs() -> void:
	var s := EditorInterface.get_editor_scale()
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "放弃未保存的修改？"
	_discard_dialog.ok_button_text = "放弃修改"
	_discard_dialog.cancel_button_text = "取消"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	_discard_dialog.canceled.connect(_on_discard_canceled)
	add_child(_discard_dialog)

	_save_dialog = ConfirmationDialog.new()
	_save_dialog.title = "另存为我的预设"
	_save_dialog.ok_button_text = "保存"
	_save_dialog.cancel_button_text = "取消"
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 420 * s
	var l1 := Label.new()
	l1.text = "名称（可以用中文）"
	vb.add_child(l1)
	_save_name = LineEdit.new()
	vb.add_child(_save_name)
	var l2 := Label.new()
	l2.text = "文件名（英文字母、数字、下划线）"
	vb.add_child(l2)
	_save_file = LineEdit.new()
	vb.add_child(_save_file)
	var l3 := Label.new()
	l3.text = "保存到 " + FxSession.USER_DIR
	l3.modulate = Color(1, 1, 1, 0.6)
	vb.add_child(l3)
	_save_dialog.add_child(vb)
	_save_dialog.register_text_enter(_save_file)
	_save_dialog.confirmed.connect(_on_save_as_confirmed)
	add_child(_save_dialog)

	_ref_dialog = FileDialog.new()
	_ref_dialog.title = "选择参考图（例如你的角色图片）"
	_ref_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_ref_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_ref_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "图片")
	_ref_dialog.file_selected.connect(_on_reference_selected)
	add_child(_ref_dialog)

	_export_dialog = ExportDialog.new()
	_export_dialog.export_requested.connect(_on_export_requested)
	add_child(_export_dialog)

	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = "覆盖已有文件？"
	_overwrite_dialog.ok_button_text = "覆盖并导出"
	_overwrite_dialog.cancel_button_text = "取消"
	_overwrite_dialog.confirmed.connect(func() -> void:
		if not _pending_export.is_empty():
			_run_export(_pending_export)
		_pending_export = {})
	add_child(_overwrite_dialog)

	_result_dialog = AcceptDialog.new()
	_result_dialog.title = "导出结果"
	_result_dialog.ok_button_text = "好的"
	_result_dialog.add_button("在文件系统中显示", true, "show")
	_result_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"show" and not _result_files.is_empty():
			var target := _result_files[0]
			for f: String in _result_files:
				if f.ends_with(".tscn"):
					target = f
			EditorInterface.select_file(target)
			_result_dialog.hide())
	add_child(_result_dialog)


# ---------------------------------------------------------------- 预设载入与修改

func _load_initial() -> void:
	var last: String = _meta_get("last_preset", "builtin:slash_basic")
	if last.begins_with("user:"):
		var path := last.trim_prefix("user:")
		if ResourceLoader.exists(path):
			var res := load(path)
			if res is FxPreset:
				session.load_preset(res, path, "")
				return
	var p: FxPreset = Builtin.find(last.trim_prefix("builtin:"))
	if p == null:
		p = Builtin.find("slash_basic")
	session.load_preset(p, "", p.preset_id)


func _current_key() -> String:
	if session.is_user_preset():
		return "user:" + session.source_path
	if not session.builtin_id.is_empty():
		return "builtin:" + session.builtin_id
	return ""


func _on_preset_chosen(p: Resource, path: String, builtin: String) -> void:
	if session.dirty:
		_pending = [p, path, builtin]
		_discard_dialog.dialog_text = "「%s」有未保存的修改，切换后这些修改会丢失。\n要放弃修改吗？" % session.preset.display_name
		_discard_dialog.popup_centered()
		return
	session.load_preset(p, path, builtin)


func _on_discard_confirmed() -> void:
	if _pending.size() == 3:
		session.load_preset(_pending[0], _pending[1], _pending[2])
	_pending.clear()


func _on_discard_canceled() -> void:
	_pending.clear()
	_browser.select_key(_current_key())


func _on_loaded() -> void:
	_params.build()
	_browser.select_key(_current_key())
	_frame = 0
	_acc = 0.0
	_gap = 0.0
	_playing = true
	_textures.clear()
	_images.clear()
	_stage.reset_view()
	_zoom_option.select(0)
	_scheduler.request_full()
	_update_title()
	var key := _current_key()
	if not key.is_empty():
		_meta_set("last_preset", key)


func _on_changed(scope: String) -> void:
	_update_title()
	if scope == "meta" or scope == "all":
		return
	if scope == "structure":
		_params.build()
		_scheduler.request_full()
		return
	if not _dragging:
		_scheduler.request_full()
		_params.sync_values()


func _on_value_edited(scope: String, layer: int, id: String, value: Variant, phase: int) -> void:
	if phase == 3:
		_dragging = false
		_scheduler.request_full()
		_params.sync_values()
		return
	_dragging = phase == 1 or phase == 2
	var merge := phase == 2
	if scope == "global" and id.begins_with("palette_"):
		# 手动换色板：如果和当前主题对不上，主题显示为「自定义」
		var vals := {id: value}
		var slots := FxPalette.theme_slots(str(session.get_value("global", -1, "theme")))
		if slots.get(id.trim_prefix("palette_"), null) != value:
			vals["theme"] = "custom"
		session.set_values(scope, layer, vals, merge)
	else:
		session.set_value(scope, layer, id, value, merge)
	if scope == "layer" and (id == "name" or id == "enabled"):
		# 图层列表里显示名称和显示状态，需要重建
		_params.build.call_deferred()
	if _dragging:
		if _last_full_ms <= DRAG_FULL_BUDGET_MS:
			_scheduler.request_full()
		else:
			_scheduler.request_frame(_frame)


func _on_theme_chosen(theme_id: String) -> void:
	var vals := {"theme": theme_id}
	var slots := FxPalette.theme_slots(theme_id)
	for k: String in slots:
		vals["palette_" + k] = slots[k]
	session.set_values("global", -1, vals)


func _on_action(action: String) -> void:
	if action == "fit_canvas":
		_fit_canvas()


func _on_layer_action(action: String, index: int, arg: String) -> void:
	match action:
		"add":
			session.add_layer(arg)
		"up":
			session.move_layer(index, 1)
		"down":
			session.move_layer(index, -1)
		"dup":
			session.duplicate_layer(index)
		"del":
			session.remove_layer(index)


func _update_title() -> void:
	if session.preset == null:
		return
	_title.text = ("● " if session.dirty else "") + session.preset.display_name
	_title.tooltip_text = "有未保存的修改" if session.dirty else ""


# ---------------------------------------------------------------- 渲染结果与播放

func _on_rendered(job: RefCounted, full: bool, ms: float) -> void:
	var j := job as FxJob
	if j == null:
		return
	if full:
		_last_full_ms = ms
		_last_job = j
		_images = j.images()
		_textures.clear()
		for img: Image in _images:
			_textures.append(ImageTexture.create_from_image(img))
		_stage.set_canvas(Vector2i(j.w, j.h), j.origin)
		_timeline.set_frames(_textures)
		if _frame >= _textures.size():
			_frame = 0
		_show_frame()
		_update_status()
		return
	var r: Dictionary = j.results[0]
	var f: int = r["frame"]
	var img: Image = r["image"]
	if f < _images.size() and (_images[f] as Image).get_size() == img.get_size():
		_images[f] = img
		(_textures[f] as ImageTexture).update(img)
		_timeline.set_single_frame(f, _textures[f])
		_show_frame()
	else:
		_scheduler.request_full()


func _update_status() -> void:
	var j := _last_job
	if j == null:
		return
	var colors := {}
	var edge := false
	for r: Dictionary in j.results:
		colors.merge(r.get("colors", {}))
		edge = edge or bool(r["edge"])
	var ncol := str(colors.size()) if colors.size() < 256 else "256+"
	_status.text = "%d×%d 像素 · %d 帧 · %d 帧/秒（%.2f 秒）· %s 种颜色 · 渲染 %.0f 毫秒" % [
		j.w, j.h, j.frame_count, j.fps, float(j.frame_count) / float(j.fps), ncol, _last_full_ms]
	_warning.visible = edge
	_fit_button.visible = edge


func _process(delta: float) -> void:
	_scheduler.poll()
	if not is_visible_in_tree():
		return
	_browser.process_thumbnails()
	if not _playing or _textures.is_empty():
		return
	if _dragging and _last_full_ms > DRAG_FULL_BUDGET_MS:
		return
	if _gap > 0.0:
		_gap -= delta * _speed
		if _gap <= 0.0:
			_frame = 0
			_acc = 0.0
			_show_frame()
		return
	var fps := maxf(float(session.get_value("global", -1, "fps")), 1.0)
	var dur := 1.0 / fps
	_acc += delta * _speed
	var advanced := false
	while _acc >= dur:
		_acc -= dur
		_frame += 1
		advanced = true
		if _frame >= _textures.size():
			if bool(session.get_value("global", -1, "loop")):
				_frame = 0
			elif _loop_preview:
				_frame = _textures.size() - 1
				_gap = LOOP_GAP
				_acc = 0.0
				_show_frame(true)
				return
			else:
				_frame = _textures.size() - 1
				_playing = false
				break
	if advanced:
		_show_frame()


func _show_frame(blank: bool = false) -> void:
	if _textures.is_empty():
		_stage.set_frame(null)
		return
	_frame = clampi(_frame, 0, _textures.size() - 1)
	_stage.set_frame(_textures[_frame], blank)
	_timeline.set_current(-1 if blank else _frame, _textures.size(), _playing)


func _toggle_play() -> void:
	_playing = not _playing
	_gap = 0.0
	_acc = 0.0
	if _playing and _frame >= _textures.size() - 1 and not bool(session.get_value("global", -1, "loop")):
		_frame = 0
	_show_frame()


func _step(d: int) -> void:
	_playing = false
	_gap = 0.0
	if _textures.is_empty():
		return
	_frame = posmod(_frame + d, _textures.size())
	_show_frame()


func _jump(to_end: bool) -> void:
	_playing = false
	_gap = 0.0
	_frame = _textures.size() - 1 if to_end else 0
	_show_frame()


func _seek(f: int) -> void:
	_playing = false
	_gap = 0.0
	_frame = f
	_show_frame()


func _on_stage_zoom(z: int) -> void:
	if _stage.auto_zoom:
		_zoom_option.select(0)
		return
	var i := ZOOMS.find(z)
	if i >= 0:
		_zoom_option.select(i)
	else:
		_zoom_option.select(0)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.ctrl_pressed or k.alt_pressed or k.meta_pressed:
		return
	match k.keycode:
		KEY_SPACE:
			if not k.echo:
				_toggle_play()
		KEY_LEFT:
			_step(-1)
		KEY_RIGHT:
			_step(1)
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 工具栏动作

func _on_new() -> void:
	_on_preset_chosen(FxPresetUtil.new_blank(), "", "")


func _on_save() -> void:
	if session.is_user_preset():
		_save_to(session.source_path)
	else:
		_on_save_as()


func _on_save_as() -> void:
	var p := session.preset
	_save_name.text = p.display_name if session.is_user_preset() else p.display_name + "（我的）"
	_save_file.text = _suggest_file_name(p.preset_id)
	_save_dialog.popup_centered()
	_save_name.grab_focus()


func _on_save_as_confirmed() -> void:
	var file := _sanitize(_save_file.text)
	if file.is_empty():
		_status.text = "文件名不能为空，只能用英文字母、数字和下划线。"
		return
	var display := _save_name.text.strip_edges()
	if display.is_empty():
		display = file
	session.set_values("meta", -1, {"display_name": display, "preset_id": file, "category": "custom"})
	_save_to(FxSession.USER_DIR + file + ".tres")


func _save_to(path: String) -> void:
	var err := session.save_to(path)
	if err != OK:
		_status.text = "保存失败（%s）：%s" % [error_string(err), path]
		return
	_browser.refresh()
	_browser.select_key(_current_key())
	_meta_set("last_preset", _current_key())
	_status.text = "已保存到 " + path
	_params.build()


func _suggest_file_name(base: String) -> String:
	base = _sanitize(base)
	if base.is_empty():
		base = "my_effect"
	if not base.ends_with("_custom"):
		base += "_custom"
	var name := base
	var n := 2
	while FileAccess.file_exists(FxSession.USER_DIR + name + ".tres"):
		name = "%s_%d" % [base, n]
		n += 1
	return name


func _sanitize(text: String) -> String:
	var out := ""
	for ch in text.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-":
			out += ch
	return out


func _history() -> UndoRedo:
	if session.undo == null:
		return null
	return session.undo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)


func _on_undo() -> void:
	var h := _history()
	if h != null and h.has_undo():
		h.undo()


func _on_redo() -> void:
	var h := _history()
	if h != null and h.has_redo():
		h.redo()


func _on_reseed() -> void:
	session.set_value("global", -1, "seed", randi() % 100000)


func _on_export() -> void:
	var p := session.preset
	var saved: Variant = _meta_get("export_" + p.preset_id, {})
	var s := FxExport.normalize_settings(saved if saved is Dictionary else {}, p)
	var directional := false
	for l: Dictionary in p.layers:
		var m: FxModule = FxRegistry.get_module(l.get("module", ""))
		if m != null and m.is_directional() and l.get("follow_dir", true):
			directional = true
	_export_dialog.open(s, int(session.get_value("global", -1, "frames")), directional)


func _on_export_requested(settings: Dictionary) -> void:
	var s := FxExport.normalize_settings(settings, session.preset)
	_meta_set("export_" + session.preset.preset_id, s)
	var existing := FxExporter.existing_files(s)
	if not existing.is_empty():
		_pending_export = s
		_overwrite_dialog.dialog_text = "下面这些文件已经存在，导出会覆盖它们：\n\n" + "\n".join(existing) \
				+ "\n\n游戏里引用它们的场景会自动用上新效果。"
		_overwrite_dialog.popup_centered()
		return
	_run_export(s)


func _run_export(s: Dictionary) -> void:
	if _exporting:
		return
	_exporting = true
	_export_button.disabled = true
	_status.text = "正在导出……"
	var res: Dictionary = await FxExporter.run(session.preset, s)
	_exporting = false
	_export_button.disabled = false
	_result_files = res["files"]
	var lines := PackedStringArray([str(res["message"])])
	if not _result_files.is_empty():
		lines.append("")
		lines.append("生成的文件：")
		for f: String in _result_files:
			lines.append("  " + f)
	if res["ok"] and s["scene"]:
		lines.append("")
		lines.append("用法：把 %s%s.tscn 拖进游戏场景，或在代码里 instantiate() 后 add_child()，播完会自动消失。" % [s["out_dir"], s["base_name"]])
	_result_dialog.dialog_text = "\n".join(lines)
	_result_dialog.popup_centered()
	_status.text = str(res["message"])


func _on_reference_selected(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_status.text = "无法读取图片：" + path
		return
	_stage.reference = ImageTexture.create_from_image(img)
	_stage.reference_offset = Vector2.ZERO
	_ref_clear.visible = true
	_stage.queue_redraw()


## 按整段动画的实际范围重新设置画布大小和原点（留 2 像素边距）
func _fit_canvas() -> void:
	var p: FxPreset = session.preset.clone()
	var g := p.globals
	g["canvas_w"] = mini(int(g["canvas_w"]) * 3, 512)
	g["canvas_h"] = mini(int(g["canvas_h"]) * 3, 512)
	g["origin_x"] = 0.5
	g["origin_y"] = 0.5
	var job := FxRenderer.make_job(p)
	FxRenderer.render_sync(job)
	var u := Rect2i()
	for r: Dictionary in job.results:
		var b: Rect2i = r["bbox"]
		if b.size.x > 0:
			u = b if u.size.x == 0 else u.merge(b)
	if u.size.x == 0:
		_status.text = "画面里没有可见像素，无法适配画布。"
		return
	var sc: float = float(session.get_value("global", -1, "size_scale"))
	var margin := 2.0 * sc
	var left := job.origin.x - u.position.x + margin
	var right := u.end.x - job.origin.x + margin
	var top := job.origin.y - u.position.y + margin
	var bottom := u.end.y - job.origin.y + margin
	var nw := clampi(ceili((left + right) / sc), 8, 512)
	var nh := clampi(ceili((top + bottom) / sc), 8, 512)
	nw += nw % 2
	nh += nh % 2
	session.set_values("global", -1, {
		"canvas_w": nw, "canvas_h": nh,
		"origin_x": clampf(left / sc / nw, 0.0, 1.0), "origin_y": clampf(top / sc / nh, 0.0, 1.0),
	})
	_status.text = "画布已调整为 %d×%d" % [nw, nh]


func _meta_get(key: String, default: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(META, key, default)


func _meta_set(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(META, key, value)
