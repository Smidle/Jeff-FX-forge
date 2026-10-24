extends CharacterBody2D
signal marker(actor, action)
signal action_finished(actor, action)
signal stepped(actor)
signal damaged(actor, amount, blocked, source_kind)
signal died(actor)

@export_enum("hero", "melee", "ranged", "boss") var kind := "hero"
@export var max_hp := 100.0
@export var speed := 160.0
@export var actor_name := "姐夫"
var practice_target := false
var hit_effect_id := "hit_heavy"
var hit_count := 0
var hit_flash := 0.0
var recoil_direction := Vector2.ZERO
var hp := 100.0
var shield := 0.0
var shield_time := 0.0
var facing := Vector2.DOWN
var action := ""
var action_time := 0.0
var released := false
var marker_frame := 2
var charging := false
var guarding := false # Retained for diagnostics; K never grants a damage block.
var enabled := true
var invulnerable := 0.0
var movement := Vector2.ZERO
var dash_direction := Vector2.ZERO
var _step_distance := 0.0
var _keys: Array[int] = []
var _name_tween: Tween
var visual: AnimatedSprite2D
const GroundShadow = preload("ground_shadow.gd")
static var _ground_contact_cache: Dictionary = {}
var ground_shadow: Node2D
var ground_profile: Dictionary = {}
var base_pivot := Vector2.ZERO
var title: Label
var actions: Dictionary = {}
var tint := Color.WHITE
var combat_side := -1
var combat_time := 0.0
const DASH_DURATION := 10.0 / 24.0
const DASH_MOVE_DURATION := 0.28
const DIRECTION_BINDINGS := [[KEY_W, KEY_UP, Vector2.UP], [KEY_S, KEY_DOWN, Vector2.DOWN], [KEY_A, KEY_LEFT, Vector2.LEFT], [KEY_D, KEY_RIGHT, Vector2.RIGHT]]

func _ready() -> void:
	hp = max_hp
	add_to_group("moon_actor")
	add_to_group("moon_player" if kind == "hero" else "moon_enemy")
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10
	shape.shape = circle
	add_child(shape)
	visual = AnimatedSprite2D.new()
	if kind == "hero":
		visual.sprite_frames = preload("res://assets/courtyard/hero_frames.tres")
		visual.offset = Vector2(-80, -60)
		visual.scale = Vector2(3, 3)
		for item in JSON.parse_string(FileAccess.get_file_as_string("res://data/courtyard/hero_actions.json")).animations:
			actions[item.name] = item
	else:
		visual.sprite_frames = load("res://assets/moon_temple/bandit%d_frames.tres" % (2 if kind == "ranged" else 1))
		visual.offset = Vector2(-43, -57)
		visual.scale = Vector2(3, 3)
		tint = Color("b7b5e6") if kind == "boss" else Color.WHITE
	base_pivot = -visual.offset
	if _ground_contact_cache.is_empty():
		_ground_contact_cache = JSON.parse_string(FileAccess.get_file_as_string("res://data/courtyard/ground_contacts.json")).profiles
	ground_profile = _ground_contact_cache.get("hero" if kind == "hero" else "bandit2" if kind == "ranged" else "bandit1", {})
	visual.centered = false
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var flash_material := ShaderMaterial.new()
	flash_material.shader = preload("hit_flash.gdshader")
	visual.material = flash_material
	add_child(visual)
	ground_shadow = GroundShadow.new()
	ground_shadow.name = "GroundContactShadow"
	add_child(ground_shadow)
	visual.frame_changed.connect(_frame_changed)
	visual.animation_changed.connect(_sync_grounding)
	visual.animation_finished.connect(_animation_finished)
	title = Label.new()
	title.position = Vector2(-125, -134)
	title.size = Vector2(250, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://assets/courtyard/fonts/pixel_font.tres"))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color("0c1722"))
	title.modulate.a = 0
	add_child(title)
	_play_pose("idle")
	_sync_grounding()

func _sync_grounding() -> void:
	if not is_instance_valid(ground_shadow) or visual == null: return
	var frames: Array = ground_profile.get(String(visual.animation), [])
	var contact: Dictionary = frames[mini(visual.frame,frames.size()-1)] if not frames.is_empty() else {}
	var lying := String(visual.animation).begins_with("dead")
	# Correct padding in the boot region, not the full image bounds (which
	# include sword trails). Original sprite pixels and action timing stay intact.
	visual.offset.y = -base_pivot.y + (0.0 if lying else float(contact.get("offset_y",0)))
	var feet: Array = []
	for foot in contact.get("feet",[0]):
		feet.append(float(foot)*visual.scale.x*(-1.0 if visual.flip_h else 1.0))
	var elevation := maxf(0,-visual.position.y) if action=="dash" else 0.0
	var ground_offset := Vector2.ZERO if action=="dash" else visual.position
	ground_shadow.set_pose(feet,elevation,ground_offset)

func _input(event: InputEvent) -> void:
	if kind != "hero" or not enabled or not event is InputEventKey or event.echo: return
	var keycode: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	for i in range(DIRECTION_BINDINGS.size()):
		if keycode not in [DIRECTION_BINDINGS[i][0], DIRECTION_BINDINGS[i][1]]: continue
		if event.pressed:
			# Preserve event order even when two directions and Space arrive in
			# one frame; polling alone would prioritize the array's last axis.
			_keys.erase(i)
			_keys.append(i)
		elif not Input.is_physical_key_pressed(DIRECTION_BINDINGS[i][0]) and not Input.is_physical_key_pressed(DIRECTION_BINDINGS[i][1]):
			_keys.erase(i)

func direction_input() -> Vector2:
	var bindings := DIRECTION_BINDINGS
	for i in range(4):
		var pressed := Input.is_physical_key_pressed(bindings[i][0]) or Input.is_physical_key_pressed(bindings[i][1])
		if pressed and not _keys.has(i): _keys.append(i)
		if not pressed: _keys.erase(i)
	return Vector2.ZERO if _keys.is_empty() else bindings[_keys.back()][2]

func _physics_process(delta: float) -> void:
	if not enabled: return
	action_time += delta
	hit_flash = maxf(0, hit_flash - delta * 7.5)
	visual.material.set_shader_parameter("hit_flash", hit_flash)
	combat_time = maxf(0, combat_time - delta)
	invulnerable = maxf(0, invulnerable - delta)
	shield_time = maxf(0, shield_time - delta)
	if shield_time <= 0: shield = 0
	if hp <= 0: return
	var direction := direction_input() if kind == "hero" else Vector2.ZERO if practice_target else movement
	guarding = false
	charging = kind == "hero" and action.is_empty() and Input.is_physical_key_pressed(KEY_K)
	if direction != Vector2.ZERO and action.is_empty() and not charging: facing = direction
	if absf(facing.x) > 0.1: combat_side = 1 if facing.x > 0 else -1
	velocity = direction * speed if action.is_empty() and not charging else Vector2.ZERO
	if action == "dash":
		velocity = dash_direction * 380 if action_time < DASH_MOVE_DURATION else Vector2.ZERO
		visual.position.y = -sin(clampf(action_time / DASH_DURATION, 0, 1) * PI) * GroundShadow.MAX_HOP
		if action_time >= DASH_DURATION: _finish_action()
	else: visual.position = Vector2.ZERO
	if practice_target and action == "hurt":
		var recoil := sin(clampf(action_time / 0.22, 0, 1) * PI)
		visual.position = (recoil_direction * recoil * 7).round()
		visual.skew = recoil_direction.x * recoil * 0.045
	else: visual.skew = 0
	if kind != "hero" and action == "hurt" and action_time >= 0.22: _finish_action()
	var before := position
	move_and_slide()
	if action != "dash": _step_distance += position.distance_to(before)
	if _step_distance >= 37 and action != "dash":
		_step_distance = 0
		stepped.emit(self)
	if action.is_empty():
		if charging:
			# Hold the native pre-release healing/cultivation pose; no block mechanics.
			_play_pose("heal_cast")
			visual.set_frame_and_progress(2, 0)
			visual.pause()
		else: _play_pose("run" if velocity.length() > 1 else "battle_idle" if kind == "hero" and combat_time > 0 else "idle")
	visual.modulate = tint
	z_index = int(position.y)
	_sync_grounding()

func suffix() -> String:
	if kind != "hero": return "up" if facing.y < -0.1 else "down"
	return "down" if facing.y > 0.1 else "up" if facing.y < -0.1 else "right" if facing.x > 0 else "left"

func _animation_name(pose: String) -> String:
	var direction := suffix()
	# These source atlases contain genuine left/right combat, not rear/front attacks.
	if kind == "hero" and pose not in ["idle", "run", "dash"]:
		direction = "right" if combat_side > 0 else "left"
	var anim := pose + "_" + direction
	return anim if visual.sprite_frames.has_animation(anim) else "idle_" + suffix()

func _play_pose(pose: String) -> void:
	visual.flip_h = kind != "hero" and facing.x > 0.1
	visual.play(_animation_name(pose))

func resolve_dash_direction() -> Vector2:
	# Input may arrive before the next physics tick. Do not dash along a stale
	# movement direction, or along a diagonal aim vector left by a targeted cast.
	var requested := direction_input() if kind == "hero" else movement
	if requested.is_zero_approx(): requested = facing
	if requested.is_zero_approx(): return Vector2.DOWN
	if absf(requested.x) >= absf(requested.y): return Vector2(signf(requested.x), 0)
	return Vector2(0, signf(requested.y))

func begin_action(request: String, pose_override := "") -> bool:
	if not enabled or hp <= 0 or not action.is_empty(): return false
	action = request
	action_time = 0
	released = false
	guarding = false
	charging = false
	if absf(facing.x) > 0.1: combat_side = 1 if facing.x > 0 else -1
	var pose := "sword_cast" if request.begins_with("skill_") else request
	if not pose_override.is_empty(): pose = pose_override
	if request == "dash":
		dash_direction = resolve_dash_direction()
		facing = dash_direction
		if not is_zero_approx(facing.x): combat_side = int(facing.x)
		_step_distance = 0
		invulnerable = 0.3
		pose = "dash"
	if kind != "hero" and request.begins_with("attack"): pose = "attack"
	if request.begins_with("attack") or request.begins_with("skill_"): combat_time = 2.0
	# Set the marker before play(), which can synchronously emit frame_changed.
	marker_frame = int(actions.get(_animation_name(pose), {}).get("release_frame", 2))
	if marker_frame < 0: marker_frame = 2
	_play_pose(pose)
	visual.set_frame_and_progress(0, 0)
	return true

func _frame_changed() -> void:
	_sync_grounding()
	if action.is_empty() or action in ["dash", "hurt", "dead"] or released: return
	if visual.frame >= marker_frame:
		released = true
		marker.emit(self, action)

func _animation_finished() -> void:
	if action not in ["", "dash", "dead"]: _finish_action()

func _finish_action() -> void:
	var old := action
	action = ""
	if old == "dash": _step_distance = 0
	visual.position.y = 0
	_sync_grounding()
	action_finished.emit(self, old)

func receive_damage(amount: float, origin: Vector2, source_kind: String = "skill") -> bool:
	if practice_target:
		hit_count += 1
		hit_flash = 1.0
		visual.material.set_shader_parameter("hit_flash", 1.0)
		recoil_direction = (position - origin).normalized()
		if recoil_direction == Vector2.ZERO: recoil_direction = Vector2.RIGHT
		action = "hurt"
		action_time = 0
		movement = Vector2.ZERO
		velocity = Vector2.ZERO
		_play_pose("idle")
		damaged.emit(self, amount, false, source_kind)
		return true
	if hp <= 0 or invulnerable > 0: return false
	hit_flash = 1.0
	var block := false
	var applied := amount
	var absorbed := minf(shield, applied)
	shield -= absorbed
	applied -= absorbed
	hp = maxf(0, hp - applied)
	damaged.emit(self, applied, absorbed > 0, source_kind)
	if hp <= 0:
		action = "dead"
		movement = Vector2.ZERO
		if kind == "hero": _play_pose("dead")
		else: visual.pause(); visual.rotation = -PI / 2; visual.position.y = 20
		died.emit(self)
	elif not block and applied > 0:
		# Interruption before release leaves cooldown untouched.
		action = ""
		begin_action("hurt")
		invulnerable = 0.18
	return true

func show_title(text: String) -> void:
	if _name_tween != null and _name_tween.is_valid(): _name_tween.kill()
	title.text = text
	title.modulate.a = 0
	title.position.y = -134
	_name_tween = create_tween()
	_name_tween.tween_property(title, "modulate:a", 1.0, 0.1)
	_name_tween.tween_interval(0.4)
	_name_tween.tween_property(title, "modulate:a", 0.0, 0.25)
	_name_tween.parallel().tween_property(title, "position:y", -145.0, 0.25)
