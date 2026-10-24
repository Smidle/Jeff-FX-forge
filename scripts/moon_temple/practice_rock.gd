@tool
extends StaticBody2D
signal struck(where)
var hit_count := 0
var recoil := 0.0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("moon_rock")

func receive_damage(_amount: float, origin: Vector2) -> bool:
	hit_count += 1
	recoil = 0.12
	var edge := global_position + (origin - global_position).normalized() * 35
	struck.emit(edge + Vector2(0, -22))
	return true

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	recoil = maxf(0, recoil - delta)
	$Sprite.position.x = roundf(sin(recoil * 90) * 2 * recoil / 0.12)
