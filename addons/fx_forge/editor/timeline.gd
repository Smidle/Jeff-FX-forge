@tool
extends VBoxContainer
## 时间轴：播放控制、逐帧、进度条、帧缩略条。只负责显示和发信号，播放状态由主界面管理。

const I18n := preload("i18n.gd")

signal play_toggled
signal step(delta: int)
signal jump(to_end: bool)
signal seek(frame: int)
signal speed_changed(mult: float)
signal loop_toggled(on: bool)

const SPEEDS := [0.25, 0.5, 1.0, 2.0]

var _play: Button
var _slider: HSlider
var _label: Label
var _strip_scroll: ScrollContainer
var _strip: HBoxContainer
var _group := ButtonGroup.new()
var _syncing := false
var _current := -1
var _icon_play: Texture2D
var _icon_pause: Texture2D


func _ready() -> void:
	var scale := EditorInterface.get_editor_scale()
	var theme := EditorInterface.get_editor_theme()
	_icon_play = theme.get_icon(&"Play", &"EditorIcons")
	_icon_pause = theme.get_icon(&"Pause", &"EditorIcons")

	var bar := HBoxContainer.new()
	add_child(bar)
	bar.add_child(_button("|<", I18n.T("首帧"), func() -> void: jump.emit(false)))
	bar.add_child(_button("<", I18n.T("上一帧（←）"), func() -> void: step.emit(-1)))
	_play = _button("", I18n.T("播放 / 暂停（空格）"), func() -> void: play_toggled.emit())
	_play.icon = _icon_pause
	bar.add_child(_play)
	bar.add_child(_button(">", I18n.T("下一帧（→）"), func() -> void: step.emit(1)))
	bar.add_child(_button(">|", I18n.T("末帧"), func() -> void: jump.emit(true)))

	_slider = HSlider.new()
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.step = 1
	_slider.min_value = 0
	_slider.value_changed.connect(func(v: float) -> void:
		if not _syncing:
			seek.emit(int(v)))
	bar.add_child(_slider)

	_label = Label.new()
	_label.custom_minimum_size.x = 56 * scale
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(_label)

	var loop := CheckBox.new()
	loop.text = I18n.T("循环预览")
	loop.button_pressed = true
	loop.tooltip_text = I18n.T("一次性特效播完后停顿一下再重播")
	loop.toggled.connect(func(on: bool) -> void: loop_toggled.emit(on))
	bar.add_child(loop)

	var speed := OptionButton.new()
	for s: float in SPEEDS:
		speed.add_item("%s×" % str(s))
	speed.select(2)
	speed.tooltip_text = I18n.T("预览播放速度（不影响导出）")
	speed.item_selected.connect(func(i: int) -> void: speed_changed.emit(SPEEDS[i]))
	bar.add_child(speed)

	_strip_scroll = ScrollContainer.new()
	_strip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip_scroll.custom_minimum_size.y = 46 * scale
	add_child(_strip_scroll)
	_strip = HBoxContainer.new()
	_strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_strip_scroll.add_child(_strip)


func _button(text: String, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## 帧缩略图更新（帧数变化时重建按钮）
func set_frames(textures: Array) -> void:
	_strip_scroll.show()
	var n := textures.size()
	if _strip.get_child_count() != n:
		_current = -1
		for c in _strip.get_children():
			_strip.remove_child(c)
			c.queue_free()
		var scale := EditorInterface.get_editor_scale()
		for i in n:
			var b := Button.new()
			b.toggle_mode = true
			b.button_group = _group
			b.focus_mode = Control.FOCUS_NONE
			b.expand_icon = true
			b.custom_minimum_size = Vector2(38, 38) * scale
			b.tooltip_text = I18n.T("第 %d 帧") % (i + 1)
			b.pressed.connect(func() -> void: seek.emit(i))
			_strip.add_child(b)
	for i in n:
		(_strip.get_child(i) as Button).icon = textures[i]
	_syncing = true
	_slider.max_value = maxi(n - 1, 0)
	_syncing = false


func set_single_frame(index: int, tex: Texture2D) -> void:
	if index >= 0 and index < _strip.get_child_count():
		(_strip.get_child(index) as Button).icon = tex


func set_current(frame: int, count: int, playing: bool) -> void:
	_syncing = true
	if frame >= 0:
		_slider.set_value_no_signal(frame)
	_syncing = false
	_label.text = "%d / %d" % [maxi(frame, 0) + 1, count] if frame >= 0 else "— / %d" % count
	# set_pressed_no_signal 不经过按钮组，需要自己取消上一个
	if _current >= 0 and _current < _strip.get_child_count() and _current != frame:
		(_strip.get_child(_current) as Button).set_pressed_no_signal(false)
	if frame >= 0 and frame < _strip.get_child_count():
		(_strip.get_child(frame) as Button).set_pressed_no_signal(true)
	_current = frame
	_play.icon = _icon_pause if playing else _icon_play


## 3D playback uses time, not baked image thumbnails.
func set_live_frames(count: int) -> void:
	_strip_scroll.hide()
	_syncing = true
	_slider.max_value = maxi(0, count - 1)
	_syncing = false
