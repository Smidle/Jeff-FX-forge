extends CanvasLayer
signal skill_pressed(index)
signal reset_requested
const Slot = preload("skill_slot.gd")
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
var root: Control
var slots: Array[Button] = []
var hp_bar: ProgressBar
var health: Label
var states: Label
var menu: Control
var menu_home: VBoxContainer
var bindings_page: VBoxContainer
var first_button: Button
var bindings_text: RichTextLabel
var notice: Label
var notice_time := 0.0

func label(text: String, font_size := 16) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	return item

func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.10, 0.94)
	style.border_color = Color("8f896f")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	return p

func build(skills: Array[Resource]) -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font = preload("res://assets/courtyard/fonts/pixel_font.tres")
	font.base_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.base_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	theme.default_font = font
	theme.default_font_size = 16
	root.theme = theme
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	var card := panel()
	card.position = Vector2(20, 20)
	card.custom_minimum_size = Vector2(332, 108)
	root.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = preload("res://assets/courtyard/ui/hero_portrait.png")
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = 210
	row.add_child(details)
	details.add_child(label("姐夫", 32))
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(210, 16)
	hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9c514d")
	hp_bar.add_theme_stylebox_override("fill", fill)
	details.add_child(hp_bar)
	health = label("气血 100 / 100", 16)
	details.add_child(health)
	states = label("无护体 · 无增益", 16)
	states.add_theme_color_override("font_color", Color("c7bc9c"))
	details.add_child(states)
	var bars := VBoxContainer.new()
	bars.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	bars.position += Vector2(20, -174)
	bars.add_theme_constant_override("separation", 8)
	root.add_child(bars)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 5)
	bars.add_child(secondary)
	var primary := HBoxContainer.new()
	primary.add_theme_constant_override("separation", 7)
	bars.add_child(primary)
	for i in range(skills.size()):
		var slot := Slot.new()
		slot.name = "Skill" + str(i + 1)
		slot.icon_texture = load("res://assets/courtyard/ui/skill_%d.png" % (i + 1))
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.large = i < 4
		slot.custom_minimum_size = Vector2(70, 70) if i < 4 else Vector2(54, 54)
		slot.binding = KEYS[i]
		slot.cooldown = skills[i].cooldown
		slot.tooltip_text = "%s  %s\n冷却 %.1f 秒 · %s" % [KEYS[i], skills[i].title, skills[i].cooldown, "自身" if skills[i].target_mode == "self" else "选中目标 / 前方"]
		slot.pressed.connect(func(): skill_pressed.emit(i))
		(primary if i < 4 else secondary).add_child(slot)
		slots.append(slot)
	bars.add_child(label("J 连击   K 蓄力   空格轻功   Esc 菜单", 16))
	notice = label("", 16)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notice.position += Vector2(20, -205)
	root.add_child(notice)
	_build_menu(skills)

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build_menu(skills: Array[Resource]) -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.03, 0.055, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var window := panel()
	window.custom_minimum_size = Vector2(580, 280)
	center.add_child(window)
	var content := VBoxContainer.new()
	window.add_child(content)
	menu_home = VBoxContainer.new()
	menu_home.add_theme_constant_override("separation", 12)
	content.add_child(menu_home)
	menu_home.add_child(label("月下庭院 · 测试暂停", 32))
	first_button = _button("按键绑定查询", menu_home, show_bindings)
	_button("重置关卡", menu_home, func(): close_menu(); reset_requested.emit())
	_button("继续测试", menu_home, close_menu)
	bindings_page = VBoxContainer.new()
	content.add_child(bindings_page)
	bindings_page.add_child(label("按键绑定查询", 32))
	bindings_text = RichTextLabel.new()
	bindings_text.custom_minimum_size = Vector2(550, 480)
	bindings_text.bbcode_enabled = true
	bindings_text.text = "[color=#e4cc92]移动与动作[/color]\nWASD / 方向键　四向移动，后按方向优先\nJ　挥剑；第一段中再按 J 接第二段突刺\n空格　轻功闪避，落地扬尘\n按住 K　原地蓄力（不减伤）；松开停止\nTab　轮换附近可见的固定靶\nE　恢复生命\n\n[color=#e4cc92]技能 · 冷却均为 0.5 秒[/color]\n"
	for i in range(skills.size()): bindings_text.text += "%s　%s%s\n" % [KEYS[i], skills[i].title, "（自身）" if skills[i].target_mode == "self" else "（目标 / 前方）"]
	bindings_text.text += "\nEsc　暂停 / 返回 / 继续\nF9　82 款特效调试（与实际技能计数分开）\n鼠标点击技能图标也可释放；指向图标查看说明。\n\n两名固定靶不移动、不攻击、不死亡。\n左靶：重击反馈；右靶：暴击反馈。石头：格挡火花。\n攻击动作未收招时不能开始新技能；0.5 秒是冷却。"
	bindings_page.add_child(bindings_text)
	_button("返回菜单", bindings_page, func(): bindings_page.hide(); menu_home.show(); first_button.grab_focus())
	bindings_page.hide()
	menu.hide()

func show_bindings() -> void:
	menu_home.hide()
	bindings_page.show()
	bindings_page.get_child(bindings_page.get_child_count() - 1).grab_focus()

func escape() -> void:
	if menu.visible:
		if bindings_page.visible:
			bindings_page.hide(); menu_home.show(); first_button.grab_focus()
		else: close_menu()
	else:
		get_tree().paused = true
		menu.show(); menu_home.show(); bindings_page.hide(); first_button.grab_focus()

func close_menu() -> void:
	menu.hide()
	get_tree().paused = false
	var owner := root.get_viewport().gui_get_focus_owner()
	if owner: owner.release_focus()

func refresh(actor, cooldowns: Array, buff_time: float) -> void:
	hp_bar.max_value = actor.max_hp
	hp_bar.value = actor.hp
	health.text = "气血 %d / %d" % [actor.hp, actor.max_hp]
	states.text = "护体 %d · %s" % [actor.shield, "增益 %.1fs" % buff_time if buff_time > 0 else "无增益"]
	for i in range(slots.size()):
		slots[i].remaining = cooldowns[i]
		slots[i].active = (i == 3 and actor.shield_time > 0) or (i == 4 and buff_time > 0)
		slots[i].queue_redraw()

func show_notice(text: String, seconds: float) -> void:
	notice.text = text
	notice.modulate.a = 1
	notice_time = seconds

func _process(delta: float) -> void:
	if get_tree().paused or notice == null: return
	notice_time -= delta
	if notice_time < 0: notice.modulate.a = maxf(0, notice.modulate.a - delta * 3)
