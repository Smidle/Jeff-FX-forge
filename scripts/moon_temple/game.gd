extends Node2D
const Actor = preload("actor.gd")
const Service = preload("fx_service.gd")
const Skill = preload("skill.gd")
const Hud = preload("test_hud.gd")
const TargetMarker = preload("target_marker.gd")
var combat_settings: Resource = preload("res://data/courtyard/combat_settings.tres")
var dash_settings: Resource = preload("res://data/courtyard/dash_settings.tres")
var dash_ground_state: Dictionary = {}
const SKILL_KEYS = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
const GATE = "res://scenes/moon_temple/basic_courtyard.tscn"
var level: Node2D
var player: CharacterBody2D
var fx: Node2D
var target: CharacterBody2D
var skills: Array[Resource] = []
var cooldowns: Array = []
var generation := 0
var transitioning := false
var combo_queued := false
var ai_states: Dictionary = {}
var pending_skill: Dictionary = {}
var current_area := "gate"
var flags: Dictionary = {}
var audit: Array[Dictionary] = []
var frame_samples: Array[float] = []
var rng := RandomNumberGenerator.new()
var hud: CanvasLayer
var debug_panel: PanelContainer
var debug_stats: Label
var debug_select: OptionButton
var summary_visible := false
var ai_enabled := false
var target_ring: Node2D
var shield_visual: Node2D
var charge_visual: Node2D
var buff_visual: Node2D
var buff_time := 0.0

func _ready() -> void:
	if has_node("EditorPreview"): $EditorPreview.free()
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 20261022
	for path in ["void", "thunder", "heal", "bell", "buff", "explosion", "poison", "icefall", "earth", "icecage"]:
		skills.append(load("res://data/moon_temple/" + path + ".tres"))
	cooldowns.resize(skills.size())
	cooldowns.fill(0.0)
	_build_hud()
	request_area("gate")

func request_area(area: String, reset := false) -> bool:
	if transitioning: return false
	if area != "gate":
		show_message("当前使用基础庭院实战场景。按 F9 可重置或调试效果。", 5)
		return false
	transitioning = true
	call_deferred("_transition", area, reset)
	return true

func _transition(area: String, reset: bool) -> void:
	get_tree().paused = false
	generation += 1
	var saved_hp: float = 100.0 if reset or not is_instance_valid(player) else player.hp
	if is_instance_valid(level):
		player.enabled = false
		fx.shutdown()
		level.process_mode = Node.PROCESS_MODE_DISABLED
		remove_child(level)
		level.queue_free()
		await get_tree().process_frame
	ai_states.clear()
	shield_visual = null
	charge_visual = null
	buff_visual = null
	buff_time = 0
	dash_ground_state.clear()
	level = load(GATE).instantiate()
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	fx = Service.new()
	fx.name = "LevelEffects"
	level.add_child(fx)
	player = Actor.new()
	player.name = "Player"
	player.position = level.checkpoint
	level.add_child(player)
	player.hp = saved_hp
	_bind_actor(player)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(0, -200)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1672
	camera.limit_bottom = 941
	camera.zoom = Vector2.ONE
	player.add_child(camera)
	target_ring = TargetMarker.new()
	level.add_child(target_ring)
	for spawn in level.get_node("Enemies").get_children():
		var enemy = Actor.new()
		enemy.kind = spawn.get_meta("kind", "melee")
		enemy.max_hp = 35 if enemy.kind == "ranged" else 180 if enemy.kind == "boss" else 45
		enemy.actor_name = "绿巾刀客" if enemy.kind == "melee" else "庭院暗哨"
		enemy.speed = 0
		enemy.practice_target = true
		enemy.hit_effect_id = "hit_heavy" if spawn.name == "Guard" else "hit_crit"
		enemy.actor_name = "重击试练靶" if spawn.name == "Guard" else "暴击试练靶"
		enemy.facing = Vector2.LEFT
		enemy.position = spawn.position
		level.add_child(enemy)
		_bind_actor(enemy)
		ai_states[enemy.get_instance_id()] = {"decision": 0.0, "cooldown": 1.0, "home": spawn.position}
	level.get_node("PracticeRock").struck.connect(func(where): fx.play("block_sparks", where, {"scale": 1.8}))
	for point in level.get_node("Ambient").get_children():
		fx.play(point.get_meta("effect"), point.position, {"loop": true, "scale": point.get_meta("scale", 0.4), "ground": point.get_meta("ground", false)})
	target = null
	pending_skill.clear()
	combo_queued = false
	if reset: cooldowns.fill(0.0)
	current_area = area
	transitioning = false
	hud.close_menu()
	audit.append({"event": "area_ready", "generation": generation, "area": area, "level_id": level.get_instance_id(), "players": get_tree().get_nodes_in_group("moon_player").size()})
	show_message("左靶重击 · 右靶暴击 · 石头格挡火花 · Esc 查看按键", 5)

func _bind_actor(actor) -> void:
	actor.marker.connect(_action_marker)
	actor.action_finished.connect(_action_finished)
	actor.stepped.connect(_stepped)
	actor.damaged.connect(_damaged)
	actor.died.connect(_died)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_F9:
		debug_panel.visible = not debug_panel.visible
		get_viewport().set_input_as_handled()
		return
	if key == KEY_ESCAPE:
		hud.escape()
		get_viewport().set_input_as_handled()
		return
	if transitioning or get_tree().paused or not is_instance_valid(player) or player.hp <= 0: return
	match key:
		KEY_J:
			if player.action == "attack1": combo_queued = true
			else: player.begin_action("attack1")
		KEY_SPACE:
			if player.begin_action("dash"):
				dash_ground_state = {"last_position": player.position, "count": 1}
				_play_dash_ground(player, false)
		KEY_TAB: select_target(true)
		KEY_E: interact()
	if key in SKILL_KEYS: cast(SKILL_KEYS.find(key))

func _physics_process(delta: float) -> void:
	if transitioning or get_tree().paused or not is_instance_valid(player): return
	for i in range(skills.size()): cooldowns[i] = maxf(0, cooldowns[i] - delta)
	if is_instance_valid(shield_visual) and (player.shield <= 0 or player.shield_time <= 0 or player.hp <= 0):
		shield_visual.stop_soft(0.2)
		shield_visual = null
	if not is_instance_valid(target) or target.hp <= 0 or target.position.distance_to(player.position) > 650: target = null
	_update_status_effects(delta)
	_update_dash_ground()
	hud.refresh(player, cooldowns, buff_time)
	target_ring.visible = is_instance_valid(target)
	if is_instance_valid(target): target_ring.position = target.position.round()
	if debug_panel.visible:
		debug_stats.text = "区域 %s · 世代 %d\n角色 %d · 玩家 %d · 活跃特效 %d\n实际事件 %s\n调试播放 %s" % [current_area, generation, get_tree().get_nodes_in_group("moon_actor").size(), get_tree().get_nodes_in_group("moon_player").size(), fx.get_child_count(), str(fx.gameplay_counts), str(fx.debug_counts)]
	queue_redraw()

func _process(delta: float) -> void:
	if not get_tree().paused and not transitioning:
		frame_samples.append(delta * 1000)
		if frame_samples.size() > 3600: frame_samples.pop_front()

func _play_dash_ground(actor, landing: bool) -> Node2D:
	var direction: Vector2 = actor.dash_direction
	var settings := dash_settings
	var id: String = settings.landing_effect if landing else settings.travel_effect
	var speed: float = settings.landing_speed if landing else settings.travel_speed
	var at: Vector2 = actor.position + settings.foot_offset
	if not landing: at -= direction * settings.behind_feet
	var mark = fx.play(id, at, {
		"ground": true,
		"scale": settings.landing_scale if landing else settings.travel_scale,
		"speed": speed,
		"duration": float(fx.catalog[id].duration) / speed,
		"color": Color(1, 1, 1, settings.landing_opacity if landing else settings.travel_opacity),
	})
	# Ground marks stay at their actual foot contact; they never follow the
	# jumping sprite, turn with later input, or get dragged by the next dash.
	mark.set_meta("dash_stage", "landing" if landing else "travel")
	mark.set_meta("dash_direction", direction)
	if landing:
		# Dust is an upright plume; mirror sideways, never turn it upside down.
		mark.scale.x = -1.0 if direction.x < 0 else 1.0
	else:
		# Rotate the wind along movement, then project onto the courtyard floor.
		var depth: float = settings.ground_depth
		mark.transform = Transform2D(Vector2(direction.x, direction.y * depth), Vector2(-direction.y, direction.x * depth), at)
	return mark

func _update_dash_ground() -> void:
	if dash_ground_state.is_empty(): return
	if player.action != "dash":
		dash_ground_state.clear()
		return
	if player.action_time >= Actor.DASH_MOVE_DURATION or dash_ground_state.count >= dash_settings.max_travel_marks: return
	if player.position.distance_to(dash_ground_state.last_position) >= dash_settings.mark_distance:
		_play_dash_ground(player, false)
		dash_ground_state.last_position = player.position
		dash_ground_state.count += 1

func melee_contains(actor: Node2D, point: Vector2, second: bool, body_radius := -1.0) -> bool:
	var direction: Vector2 = Vector2(actor.combat_side, 0) if actor.kind == "hero" else actor.facing.normalized()
	var delta := point - actor.position
	var radius: float = combat_settings.target_radius if body_radius < 0 else body_radius
	var forward := delta.dot(direction)
	var sideways := absf(delta.dot(direction.orthogonal()))
	var reach: float = combat_settings.thrust_reach if second else combat_settings.slash_reach
	var half_width: float = combat_settings.thrust_half_width if second else combat_settings.slash_half_width
	# Target footprint extends the visible contact edge; no hits behind the attacker.
	return forward >= 0 and forward <= reach + radius and sideways <= half_width + radius

func visible_to(a: Node2D, b: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(a.position, b.position, 2)
	return a.get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func select_target(cycle := false) -> void:
	var candidates: Array = []
	for enemy in get_tree().get_nodes_in_group("moon_enemy"):
		if enemy.hp <= 0 or player.position.distance_to(enemy.position) > 560 or not visible_to(player, enemy): continue
		if cycle or player.facing.dot((enemy.position - player.position).normalized()) > -0.05: candidates.append(enemy)
	candidates.sort_custom(func(a, b): return player.position.distance_squared_to(a.position) < player.position.distance_squared_to(b.position))
	if candidates.is_empty(): target = null; return
	var index := candidates.find(target)
	target = candidates[(index + 1) % candidates.size()] if cycle else candidates[0]

func cast(index: int) -> bool:
	if index < 0 or index >= skills.size() or get_tree().paused or transitioning or player.hp <= 0 or cooldowns[index] > 0 or not player.action.is_empty(): return false
	if skills[index].target_mode != "self" and not is_instance_valid(target): select_target()
	if skills[index].target_mode != "self" and is_instance_valid(target):
		player.facing = (target.position - player.position).normalized()
	if not player.begin_action("skill_%d" % index, skills[index].animation): return false
	if skills[index].release_frame >= 0: player.marker_frame = skills[index].release_frame
	pending_skill = {"index": index, "target": weakref(target) if skills[index].target_mode != "self" and is_instance_valid(target) else null}
	player.show_title(skills[index].title)
	return true

func _action_marker(actor, action: String) -> void:
	if transitioning or actor.hp <= 0: return
	if action.begins_with("attack"):
		var second := action == "attack2"
		# First slash is baked into the actor atlas; only the second thrust is additive.
		if second:
			var attack_direction: Vector2 = Vector2(actor.combat_side, 0) if actor.kind == "hero" else actor.facing
			fx.play("thrust", actor.position + attack_direction * 24 + Vector2(0, -48), {"rotation": attack_direction.angle(), "scale": 1.5})
		var victims := get_tree().get_nodes_in_group("moon_enemy") if actor == player else [player]
		for victim in victims:
			if victim.hp <= 0: continue
			if melee_contains(actor, victim.position, second) and visible_to(actor, victim):
				victim.receive_damage(22 if second else 16 if actor == player else 12, actor.position, "melee")
		for rock in get_tree().get_nodes_in_group("moon_rock"):
			var ray: Dictionary = actor.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(actor.position, rock.position, 2))
			if melee_contains(actor, rock.position, second, 34.0) and ray.get("collider") == rock:
				rock.receive_damage(1, actor.position)
		return
	if actor != player or not action.begins_with("skill_") or pending_skill.is_empty(): return
	var index: int = pending_skill.index
	var had_target: bool = pending_skill.target != null
	var chosen = pending_skill.target.get_ref() if pending_skill.target != null else null
	pending_skill.clear()
	if had_target and (not is_instance_valid(chosen) or chosen.hp <= 0): return
	cooldowns[index] = skills[index].cooldown
	var destination: Vector2 = chosen.position if is_instance_valid(chosen) else player.position + player.facing * 300
	# Clamp untargeted casts to the first wall, never behind sealed architecture.
	var wall := player.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(player.position, destination, 2))
	if not wall.is_empty(): destination = wall.position - player.facing * 12
	audit.append({"event": "skill_released", "skill": skills[index].id, "generation": generation})
	match index:
		0: _ground_skill(index, destination, generation)
		1: _thunder(destination, generation)
		2:
			player.hp = minf(player.max_hp, player.hp + skills[index].heal_amount)
			fx.play(skills[index].effect_id, player.position, {"ground": true, "scale": skills[index].effect_scale})
			fx.play("heal", player.position + Vector2(0, -25), {"follow": player, "offset": Vector2(0, -25), "scale": 1.6})
		3:
			player.shield = skills[index].shield_amount
			player.shield_time = skills[index].duration
			if is_instance_valid(shield_visual): shield_visual.stop_soft(0.2)
			shield_visual = fx.play(skills[index].effect_id, player.position + Vector2(-4, 6), {"follow": player, "offset": Vector2(-4, 6), "loop": true, "scale": skills[index].effect_scale, "stable_frames": Vector2i(10, 16)})
		4:
			buff_time = skills[index].duration
			if not is_instance_valid(buff_visual):
				buff_visual = fx.play("buff_aura", player.position, {"follow": player, "ground": true, "loop": true, "scale": skills[index].effect_scale})
		_:
			_ground_skill(index, destination, generation)

func _thunder(where: Vector2, token: int) -> void:
	var warning_width: float = fx.catalog["magic_circle"].rects[0][2]
	fx.play("magic_circle", where, {"ground": true, "scale": skills[1].radius * 2.0 / warning_width, "duration": 0.5})
	await get_tree().create_timer(0.48, false).timeout
	if token != generation or not is_instance_valid(level): return
	var bolt = fx.play(skills[1].effect_id, where, {"scale": skills[1].effect_scale})
	# The authored first strike is frame 11 (zero based), after the pre-flash frames.
	bolt.sprite.frame_changed.connect(func():
		if token != generation or not is_instance_valid(level) or bolt.get_meta("damage_released", false): return
		if bolt.sprite.frame < skills[1].impact_frame: return
		bolt.set_meta("damage_released", true)
		audit.append({"event": "thunder_impact", "frame": bolt.sprite.frame, "effect_elapsed": bolt.elapsed, "generation": generation})
		for enemy in get_tree().get_nodes_in_group("moon_enemy"):
			if enemy.hp > 0 and enemy.position.distance_to(where) < skills[1].radius: enemy.receive_damage(skills[1].damage, where, "skill")
	)

func _action_finished(actor, action: String) -> void:
	if actor != player: return
	if action == "attack1" and combo_queued:
		combo_queued = false
		player.begin_action("attack2")
	elif action == "dash":
		dash_ground_state.clear()
		if level.surface_at(player.position) == "water":
			fx.play("water_splash", player.position, {"ground": true, "scale": 0.8})
		else: _play_dash_ground(player, true)
	elif action.begins_with("skill_"): pending_skill.clear()

func _stepped(actor) -> void:
	if actor != player: return
	var surface: String = level.surface_at(actor.position)
	if surface == "water": fx.play("water_splash", actor.position, {"ground": true, "scale": 0.65})
	elif surface == "dirt": fx.play("run_dust", actor.position, {"ground": true, "scale": 1.25})
	else: fx.play("run_dust", actor.position, {"ground": true, "scale": 0.35, "color": Color(0.6, 0.7, 0.8, 0.28)})

func _damaged(actor, amount: float, blocked: bool, source_kind: String) -> void:
	# Skills keep their own effect. Only J contact requests a separate hit/burst.
	if source_kind == "melee":
		fx.play(actor.hit_effect_id if actor.practice_target else "hit_heavy" if amount >= 25 else "hit_basic", actor.position + Vector2(0, -54), {"scale": 2.0, "variant": "courtyard"})
	if blocked and actor.shield_time > 0: fx.play("shield", actor.position + Vector2(0, -50), {"follow": actor, "offset": Vector2(0, -50), "scale": 1.8})
	if actor == player and not blocked:
		pending_skill.clear()
		combo_queued = false

func _died(actor) -> void:
	if actor != player:
		actor.set_meta("loot", true)
		fx.play("pickup_sparkle", actor.position, {"duration": 2.0, "scale": 0.7})
		return
	show_message("胜败乃兵家常事 · 片刻后返回庭院检查点", 3)
	var token := generation
	await get_tree().create_timer(1.5, false).timeout
	if token == generation: request_area("gate", true)

func _update_status_effects(delta: float) -> void:
	if player.charging and player.hp > 0:
		if not is_instance_valid(charge_visual):
			charge_visual = fx.play("charge", player.position + Vector2(0, -48), {"follow": player, "offset": Vector2(0, -48), "loop": true, "scale": 1.25})
	elif is_instance_valid(charge_visual):
		charge_visual.stop_soft(0.18)
		charge_visual = null
	buff_time = maxf(0, buff_time - delta)
	if is_instance_valid(buff_visual) and (buff_time <= 0 or player.hp <= 0):
		buff_visual.stop_soft(0.3)
		buff_visual = null

func _ground_skill(index: int, where: Vector2, token: int) -> void:
	var skill: Resource = skills[index]
	fx.play(skill.effect_id, where + skill.display_offset, {"scale": skill.effect_scale, "ground": skill.id == "void"})
	# Damage feedback is synchronized to the visible burst/ground contact, not key-down.
	var delay: float = 0.2 if index == 0 else [0.12, 0.2, 0.38, 0.32, 0.4][index - 5]
	await get_tree().create_timer(delay, false).timeout
	if token != generation or not is_instance_valid(level): return
	for enemy in get_tree().get_nodes_in_group("moon_enemy"):
		if enemy.position.distance_to(where) < skill.radius: enemy.receive_damage(skill.damage, where)
	for rock in get_tree().get_nodes_in_group("moon_rock"):
		if rock.position.distance_to(where) < skill.radius: rock.receive_damage(1, where)

func interact() -> void:
	player.hp = player.max_hp
	show_message("气血已恢复；技能也可在满血时测试表现")

func show_message(text: String, seconds := 2.5) -> void:
	hud.show_notice(text, seconds)

func _label(text: String, size := 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e4ddc6"))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color("111c29"))
	return label

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.065, 0.09, 0.9)
	style.border_color = Color("6a766e")
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _build_hud() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -100
	add_child(backdrop)
	var night := ColorRect.new()
	night.color = Color("0b1824")
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(night)
	hud = Hud.new()
	add_child(hud)
	hud.build(skills)
	hud.skill_pressed.connect(cast)
	hud.reset_requested.connect(func(): request_area("gate", true))
	var root: Control = hud.root
	debug_panel = _panel()
	debug_panel.position = Vector2(390, 160)
	debug_panel.custom_minimum_size = Vector2(570, 300)
	root.add_child(debug_panel)
	var column := VBoxContainer.new()
	debug_panel.add_child(column)
	column.add_child(_label("开发诊断 · 手动播放不计入游戏接入覆盖", 18))
	debug_select = OptionButton.new()
	for item in JSON.parse_string(FileAccess.get_file_as_string("res://data/effects.json")):
		debug_select.add_item(item.name)
		debug_select.set_item_metadata(debug_select.item_count - 1, item.id)
	column.add_child(debug_select)
	var play := Button.new()
	play.text = "手动播放选定效果"
	play.pressed.connect(func(): fx.play(debug_select.get_item_metadata(debug_select.selected), player.position, {"debug": true, "scale": 0.7}))
	column.add_child(play)
	var reset := Button.new()
	reset.text = "重新进入本区（检验卸载与节点清理）"
	reset.pressed.connect(func(): request_area("gate", true))
	column.add_child(reset)
	debug_stats = _label("", 13)
	debug_stats.custom_minimum_size = Vector2(520, 150)
	debug_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(debug_stats)
	column.add_child(_label("手动播放 82 款效果；调试播放与实际技能触发分别计数。", 14))
	debug_panel.hide()
