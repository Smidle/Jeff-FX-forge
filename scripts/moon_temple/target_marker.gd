extends Node2D
## One ground-plane reticle, always below actors and above ground effects.
func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	# Four interrupted arcs leave the feet and their shadow readable.
	for y in range(-15, 16):
		for x in range(-34, 35):
			var q := Vector2(x / 31.0, (y - 3) / 11.0)
			var radius := q.length()
			if radius < 0.90 or radius > 1.06: continue
			if absf(q.x) < 0.18 or absf(q.y) < 0.22: continue
			var c := Color("d7bf87") if y > 3 else Color("7f927e")
			draw_rect(Rect2(x, y, 1, 1), c)
	for side in [-1, 1]:
		var x: int = side * 36
		draw_rect(Rect2(x - 2, 2, 5, 3), Color("e9d7a2"))
		draw_rect(Rect2(x, 0, 1, 7), Color("e9d7a2"))
