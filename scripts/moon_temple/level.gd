@tool
extends Node2D
@export var area_name := "山门夜径"
@export var objective := "沿石阶上山 · 清除拦路刀客 · 在山门前按 E"
@export var checkpoint := Vector2(755, 800)
@export var next_area := "courtyard"

func surface_at(point: Vector2) -> String:
	for surface in $Surfaces.get_children():
		if Geometry2D.is_point_in_polygon(point - surface.position, surface.polygon): return surface.name.to_lower()
	return "stone"

func _ready() -> void:
	if Engine.is_editor_hint(): return
	checkpoint = $Points/Checkpoint.position
	$Surfaces.hide()
	$WalkBoundary.hide()
	$EditorReference.hide()
	for marker in $Points.get_children():
		if marker is CanvasItem: marker.hide()
