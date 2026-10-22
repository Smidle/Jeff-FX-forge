@tool
extends RefCounted
## Temporary previews have no owner; only confirmation goes through scene undo history.
const I18n := preload("i18n.gd")
const Instance := preload("../legacy/runtime/fx_instance.gd")
const Sprite3 := preload("../runtime/sprite_effect_3d.gd")
const Sprite2 := preload("../runtime/sprite_effect_2d.gd")
var sprite_data: Resource
var preview: Node
var scene: Node
var recipe: Resource
var undo: Object
var valid_position := false

func begin(preset: Resource, edited_root: Node, history: Object, animation: Resource = null) -> bool:
	cancel()
	if not edited_root is Node3D and not (edited_root is Node2D and animation != null):
		return false
	scene = edited_root
	sprite_data = animation
	recipe = preset.copy() if animation == null else preset.clone()
	undo = history
	preview = _make_instance(true)
	preview.name = "JeffFXPlacementPreview"
	scene.add_child(preview)
	preview.visible = false
	preview.play()
	return true

func active() -> bool:
	return is_instance_valid(preview) and is_instance_valid(scene)

func cancel() -> void:
	if is_instance_valid(preview):
		if sprite_data == null:
			preview.stop(true)
		preview.free()
	preview = null
	scene = null
	recipe = null
	sprite_data = null
	valid_position = false

func input(camera: Camera3D, event: InputEvent) -> bool:
	if not active() or scene is Node2D:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		return true
	if event is InputEventMouse:
		var at: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		valid_position = at != null
		preview.visible = valid_position
		if valid_position:
			preview.global_position = at
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if valid_position:
				commit(preview.global_transform)
			return true
	return event is InputEventMouseMotion

func commit(world_transform: Transform3D) -> Node3D:
	if not active():
		return null
	var placed := _make_instance(false) as Node3D
	placed.transform = (scene as Node3D).global_transform.affine_inverse() * world_transform
	_commit_node(placed)
	return placed

func _make_instance(previewing: bool) -> Node:
	if sprite_data != null:
		var sprite: Node = Sprite2.new() if scene is Node2D else Sprite3.new()
		sprite.name = "JeffFX_" + recipe.preset_id
		sprite.effect_animation = sprite_data
		sprite.preview_enabled = previewing
		if sprite is AnimatedSprite3D:
			sprite.pixel_size = .025
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		return sprite
	var placed := Instance.new()
	placed.name = "JeffFX_" + recipe.id
	placed.preset = recipe.copy()
	placed.autoplay = not previewing
	placed.preview_enabled = previewing
	placed.auto_free = not recipe.looping
	return placed

func _commit_node(placed: Node) -> void:
	undo.create_action(I18n.T("放置 Jeff FX 效果"), UndoRedo.MERGE_DISABLE, scene)
	undo.add_do_method(scene, &"add_child", placed, true)
	undo.add_do_property(placed, &"owner", scene)
	undo.add_undo_method(scene, &"remove_child", placed)
	undo.add_do_reference(placed)
	undo.commit_action()
	cancel()

func input_2d(event: InputEvent) -> bool:
	if not active() or not scene is Node2D:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel()
		return true
	if event is InputEventMouse:
		preview.position = (scene as Node2D).get_global_transform_with_canvas().affine_inverse() * event.position
		preview.visible = true
		valid_position = true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			var placed := _make_instance(false) as Node2D
			placed.position = preview.position
			_commit_node(placed)
			return true
	return event is InputEventMouseMotion

func tick() -> void:
	if not active():
		return
	if sprite_data != null:
		if not preview.is_playing():
			preview.play()
	elif not preview.playing:
		preview.restart()
