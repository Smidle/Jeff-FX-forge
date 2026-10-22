@tool
extends RefCounted
## Local to the workshop. Never changes EditorSettings or the host editor theme.
const IDS := ["navy"]

static func colors(_id: String) -> Dictionary:
	return {"bg": Color("0d1928"), "panel": Color("132438"), "control": Color("1e334b"), "hover": Color("2b4661"), "line": Color("35536c"), "text": Color("e1edf4"), "muted": Color("9bb2c4"), "accent": Color("73dfbb"), "selected": Color("254f51")}

static func box(fill: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.content_margin_left = 8
	b.content_margin_right = 8
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	return b

static func create(id: String, base: Theme) -> Theme:
	var t := Theme.new()
	t.merge_with(base)
	var c := colors(id)
	for type: String in ["Button", "OptionButton", "MenuButton", "CheckBox", "CheckButton", "Label", "LineEdit", "TextEdit", "ItemList", "Tree", "PopupMenu", "SpinBox", "EditorSpinSlider", "TabBar", "RichTextLabel"]:
		for name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "default_color"]:
			t.set_color(name, type, c.text)
		t.set_color("font_disabled_color", type, c.muted)
		t.set_color("font_selected_color", type, c.text)
		t.set_color("font_uneditable_color", type, c.muted)
		t.set_color("font_placeholder_color", type, c.muted)
		t.set_color("selection_color", type, c.selected)
		t.set_color("caret_color", type, c.accent)
		for icon_color: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
			t.set_color(icon_color, type, c.text)
		t.set_color("icon_disabled_color", type, c.muted)
	for type: String in ["Button", "OptionButton", "MenuButton", "LineEdit", "TextEdit", "EditorSpinSlider"]:
		t.set_stylebox("normal", type, box(c.control, c.line))
		t.set_stylebox("hover", type, box(c.hover, c.accent))
		t.set_stylebox("pressed", type, box(c.selected, c.accent))
		t.set_stylebox("disabled", type, box(c.panel, c.line))
		t.set_stylebox("read_only", type, box(c.panel, c.line))
		var focus := box(Color(0, 0, 0, 0), c.accent)
		focus.draw_center = false
		t.set_stylebox("focus", type, focus)
	for type: String in ["ItemList", "Tree", "PopupMenu", "Panel", "PanelContainer", "TabContainer", "AcceptDialog"]:
		t.set_stylebox("panel", type, box(c.panel, c.line))
		for key: String in ["selected", "selected_focus", "hover"]:
			t.set_stylebox(key, type, box(c.selected, c.accent))
	for type: String in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", type, box(c.control, c.line, 2))
		t.set_stylebox("grabber_area", type, box(c.accent, c.accent, 2))
		t.set_stylebox("grabber_area_highlight", type, box(c.accent, c.accent, 2))
	for type: String in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", type, box(c.bg, c.bg, 2))
		for key: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			t.set_stylebox(key, type, box(c.line, c.line, 3))
	for state: String in ["unchecked", "checked", "unchecked_disabled", "checked_disabled"]:
		var checked := state.begins_with("checked")
		var ink: Color = c.accent if checked else c.muted
		var tick := '<path d="M4 8l3 3 5-6" fill="none" stroke="#%s" stroke-width="2"/>' % c.bg.to_html(false) if checked else ""
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><rect x="2" y="2" width="12" height="12" rx="2" fill="%s" stroke="#%s"/>%s</svg>' % [("#" + ink.to_html(false)) if checked else "none", ink.to_html(false), tick]
		var img := Image.new()
		img.load_svg_from_string(svg)
		t.set_icon(state, "CheckBox", ImageTexture.create_from_image(img))
	t.set_color("property_color", "Editor", c.text)
	t.set_color("font_color", "Editor", c.text)
	t.set_color("accent_color", "Editor", c.accent)
	t.set_color("background", "JeffFX", c.bg)
	t.set_color("preview_surround", "JeffFX", c.panel)
	t.set_constant("separation", "VBoxContainer", 8)
	t.set_constant("separation", "HBoxContainer", 8)
	return t
