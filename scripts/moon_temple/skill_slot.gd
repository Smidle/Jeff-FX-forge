extends Button
## Pixel icon + clockwise remaining-cooldown sector, independent of frame rate.
var icon_texture: Texture2D
var binding := "1"
var remaining := 0.0
var cooldown := 0.5
var large := false
var active := false

func icon_rect() -> Rect2:
	# Native pixels, with breathing room and a separate top-left key label.
	var edge := 40.0 if large else 28.0
	return Rect2(((size - Vector2.ONE * edge) * 0.5 + Vector2(0, 5)).floor(), Vector2.ONE * edge)

func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	var box := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	draw_rect(Rect2(Vector2.ZERO, size), Color("09121d"))
	draw_rect(box, Color("14212c"))
	if icon_texture: draw_texture_rect(icon_texture, icon_rect(), false)
	var ratio := clampf(remaining / maxf(cooldown, 0.01), 0, 1)
	if ratio > 0:
		# The clockwise sector covers the inner frame, including its blank margin.
		var center := size * 0.5
		var half := size.x * 0.5 - 3
		var polygon := PackedVector2Array([center])
		for i in range(65):
			var angle := -PI / 2 + TAU * ratio * float(i) / 64
			var ray := Vector2(cos(angle), sin(angle))
			polygon.append(center + ray * half / maxf(absf(ray.x), absf(ray.y)))
		draw_colored_polygon(polygon, Color(0.02, 0.04, 0.08, 0.8))
		draw_line(center, polygon[polygon.size() - 1], Color(0.93, 0.85, 0.64, 0.8), 1)
	draw_rect(box, Color("b6ac8a") if active or is_hovered() else Color("536671"), false, 2 if active else 1)
	var font := get_theme_default_font()
	draw_string(font, Vector2(7, 18), binding, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d9d2bc"))
	if remaining > 0:
		var text := "%.1f" % remaining
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(font, Vector2((size.x - width) / 2, size.y / 2 + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("101a26"))
		draw_string(font, Vector2((size.x - width) / 2, size.y / 2 + 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fff3d0"))
