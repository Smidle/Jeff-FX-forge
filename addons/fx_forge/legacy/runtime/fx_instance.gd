@tool
class_name JeffForge3DInstance
extends Node3D
## A complete effect, including particles, sprites and mesh layers.
## Editor previews explicitly opt in; normal editor instances never simulate.

signal arrived(projectile_index: int, world_position: Vector3)
signal finished
signal playback_changed

const Missile = preload("res://addons/fx_forge/legacy/runtime/fx_missile.gd")
const PixelField = preload("res://addons/fx_forge/legacy/runtime/fx_field.gd")
const PixelProcedural = preload("res://addons/fx_forge/legacy/runtime/fx_procedural.gd")

# Shader code is shared; uniforms always remain on instance-local materials.
static var _additive_shader: Shader
static var _additive_source: String = ""

enum Quality { AUTO, STANDARD, REDUCED }
enum Backend { AUTO, CPU, GPU }

@export var preset: JeffForge3DPreset
@export var autoplay: bool = true
@export var auto_free: bool = false
@export var quality: Quality = Quality.AUTO
@export var backend: Backend = Backend.AUTO
## Target binding belongs to the scene instance, never to a saved preset.
@export_node_path("Node3D") var target_path: NodePath
@export var target_offset: Vector3 = Vector3.ZERO
var target_sampler: Callable
var _target_ref: WeakRef
var _replay_records: Dictionary = {}
var _arrival_queue: Array[Dictionary] = []

var preview_enabled: bool = false
var solo_layer: int = -1
var time: float = 0.0
var playing: bool = false
var paused: bool = false
var speed_multiplier: float = 1.0
var _visuals: Array[Node3D] = []
var _indices: Array[int] = []
var _started: Array[bool] = []
var _stopping: bool = false
var _stop_time: float = 0.0
var _end_time: float = 0.0
var _completed: bool = false
var _playback_preset_id: int=0
var _recipe: JeffForge3DPreset
var _build_generation: int = 0
var _pending_seeks: Array[int] = []
var _last_position: Vector3 = Vector3.ZERO
var _motion_direction: Vector3 = Vector3.RIGHT

func _ready() -> void:
	set_process(false)
	if not Engine.is_editor_hint() and autoplay and not preview_enabled:
		play()

func is_reduced() -> bool:
	return quality == Quality.REDUCED or (quality == Quality.AUTO and OS.has_feature("mobile"))

func uses_gpu() -> bool:
	if backend != Backend.AUTO:
		return backend == Backend.GPU
	return RenderingServer.get_current_rendering_method() != "gl_compatibility" and DisplayServer.get_name() != "headless"

func backend_label() -> String:
	return "GPU" if uses_gpu() else "CPU"

func play() -> void:
	if preset == null or (Engine.is_editor_hint() and not preview_enabled):
		return
	if playing and paused:
		paused = false
		set_process(true)
		_set_particle_speed()
		playback_changed.emit()
		return
	if playing:
		return
	restart()

func restart() -> void:
	if preset == null or (Engine.is_editor_hint() and not preview_enabled):
		return
	_replay_records.clear()
	_reset_playback()
	_build()
	_sync(0.0, false)
	set_process(true)
	playback_changed.emit()

func _reset_playback() -> void:
	time = 0.0
	_stopping = false
	_completed = false
	paused = false
	playing = true
	_playback_preset_id=preset.get_instance_id()
	_recipe = preset.copy()
	_last_position = global_position
	_motion_direction = global_basis.x.normalized()
	_end_time = _recipe.total_duration()

func pause() -> void:
	paused = true
	set_process(false)
	_set_particle_speed()
	playback_changed.emit()

func stop(immediate: bool = false) -> void:
	if immediate:
		var notify_finished: bool = playing and not _completed
		playing = false
		paused = false
		_clear()
		var finished_generation: int = _build_generation
		_completed = true
		set_process(false)
		playback_changed.emit()
		if notify_finished:
			finished.emit()
		if auto_free and not preview_enabled and _build_generation == finished_generation and not playing:
			queue_free()
		return
	if not playing or _stopping:
		return
	_stopping = true
	_stop_time = time
	paused = false
	set_process(true)
	var tail: float = 0.0
	for i in _visuals.size():
		var layer: JeffForge3DLayer = _recipe.layers[_indices[i]]
		if _started[i]:
			var source: JeffForge3DLayer = _recipe.layers[layer.motion_source] if layer.kind == JeffForge3DLayer.Kind.FIELD and layer.motion_source >= 0 and layer.motion_source < _recipe.layers.size() else layer
			tail = maxf(tail, layer.missile.tail_seconds() if layer.kind == JeffForge3DLayer.Kind.MISSILE and layer.missile != null else layer.fade_out if layer.kind in [JeffForge3DLayer.Kind.SHAPE, JeffForge3DLayer.Kind.PROCEDURAL] else source.tail_time())
			if layer.kind == JeffForge3DLayer.Kind.MISSILE:
				_visuals[i].cancel(maxf(0, time-layer.delay))
				tail = maxf(tail, layer.missile.tail_seconds())
			elif layer.kind == JeffForge3DLayer.Kind.PARTICLES:
				_visuals[i].set("emitting", false)
	_end_time = time + tail
	_set_particle_speed()
	playback_changed.emit()

func seek(seconds: float) -> void:
	# Reset and simulate only preview copies. Reverse scrubbing never rewinds a live game.
	if preset == null or (Engine.is_editor_hint() and not preview_enabled):
		return
	_capture_records()
	_reset_playback()
	time = clampf(seconds, 0.0, 10.0 if _recipe.looping else _end_time)
	for record in _replay_records.values():
		if bool(record.get("real_target",false)) and not record.targets.is_empty(): time=minf(time,(record.targets.size()-1)/60.0+float(record.get("delay",0)))
	paused = true
	set_process(false)
	# Build once without an initial emission before deterministic simulation.
	_build()
	_sync(0.0, true)
	_set_particle_speed()
	playback_changed.emit()

func step(seconds: float = 1.0 / 30.0) -> void:
	if not playing:
		restart()
	if _recipe == null:
		return
	paused = true
	set_process(false)
	time += maxf(seconds, 0.0)
	_sync(seconds, false)
	for i in _visuals.size():
		if _recipe.layers[_indices[i]].kind == JeffForge3DLayer.Kind.PARTICLES and _started[i]:
			var node: Node3D = _visuals[i]
			node.set("speed_scale", 0.0)
			var active_delta: float = minf(maxf(time - _recipe.layers[_indices[i]].delay, 0.0), maxf(seconds, 0.0))
			node.call("request_particles_process", active_delta if bool(node.get("emitting")) else 0.0, 0.0 if bool(node.get("emitting")) else active_delta)
	_check_finish()

func refresh(at_time: float = -1.0) -> void:
	var previous_time: float = time if at_time < 0.0 else at_time
	var was_paused: bool = paused
	seek(previous_time)
	if not was_paused:
		play()

func _process(delta: float) -> void:
	if not playing or paused or _recipe == null:
		return
	var dt: float = delta * _recipe.playback_speed * speed_multiplier
	time += dt
	_sync(dt, false)
	_set_particle_speed()
	_check_finish()

func _check_finish() -> void:
	if _recipe!=null and _recipe.has_missile():
		var actual_end: float=0
		var all_missiles: bool=not _visuals.is_empty()
		for i in _visuals.size():
			if not _visuals[i] is Missile or _visuals[i].ended_at()<0:
				all_missiles=false; break
			actual_end=maxf(actual_end,_visuals[i].ended_at()+_recipe.layers[_indices[i]].delay)
		if all_missiles: _end_time=minf(_end_time,actual_end)
	if _recipe == null or (_recipe.looping and not _stopping):
		return
	if time + .000001 >= _end_time and not _completed:
		var arrival_generation: int=_build_generation
		_deliver_arrivals(arrival_generation)
		if arrival_generation!=_build_generation or time+.000001<_end_time or is_queued_for_deletion(): return
		_completed = true
		playing = false
		_set_particle_speed()
		set_process(false)
		var finished_generation: int = _build_generation
		finished.emit()
		playback_changed.emit()
		# A completion handler may synchronously restart this instance.
		if auto_free and not preview_enabled and _build_generation == finished_generation and not playing:
			queue_free()

func _clear() -> void:
	_build_generation += 1
	_pending_seeks.clear()
	_arrival_queue.clear()
	for node in _visuals:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_visuals.clear()
	_indices.clear()
	_started.clear()

func _build() -> void:
	_clear()
	if _recipe == null:
		return
	for index in _recipe.layers.size():
		var layer: JeffForge3DLayer = _recipe.layers[index]
		if not layer.enabled or (is_reduced() and layer.decorative) or (solo_layer >= 0 and solo_layer != index):
			continue
		for repeat in (clampi(layer.repeat_count, 1, 12) if layer.kind in [JeffForge3DLayer.Kind.SHAPE, JeffForge3DLayer.Kind.PROCEDURAL] else 1):
			var visual: Node3D
			if layer.kind == JeffForge3DLayer.Kind.MISSILE:
				visual = Missile.new()
			elif layer.kind == JeffForge3DLayer.Kind.PARTICLES:
				visual = _make_particles(layer, index)
			elif layer.kind == JeffForge3DLayer.Kind.FIELD:
				visual = PixelField.new()
				visual.configure(_recipe, index, is_reduced(), _material(layer, false))
			elif layer.kind == JeffForge3DLayer.Kind.PROCEDURAL:
				visual = PixelProcedural.new()
				visual.configure(_recipe, index, is_reduced(), _material(layer, false), repeat)
			else:
				visual = _make_shape(layer)
			visual.name = "FX_%02d_%02d" % [index, repeat]
			visual.visible = false
			visual.set_meta("repeat_index", repeat)
			add_child(visual)
			if layer.kind == JeffForge3DLayer.Kind.MISSILE:
				visual.configure(_recipe, layer, is_reduced(), self)
				visual.bind(get_target(), target_offset, target_sampler, not target_path.is_empty() or _target_ref!=null)
				if _replay_records.has(index): visual.restore_record(_replay_records[index])
			else:
				visual.position = layer.offset * _recipe.effect_scale if layer.kind != JeffForge3DLayer.Kind.FIELD else Vector3.ZERO
			if layer.kind in [JeffForge3DLayer.Kind.SHAPE, JeffForge3DLayer.Kind.PROCEDURAL]:
				visual.position += layer.repeat_spacing * (repeat - (layer.repeat_count - 1) * .5) * _recipe.effect_scale
			if layer.kind == JeffForge3DLayer.Kind.PARTICLES:
				visual.rotation_degrees = layer.rotation_degrees
			_visuals.append(visual)
			_indices.append(index)
			_started.append(false)
	_set_particle_speed()

func _color(layer: JeffForge3DLayer) -> Color:
	var tint: Color = ((_recipe.secondary_color if layer.secondary else _recipe.primary_color) if layer.use_palette_tint else Color.WHITE) * layer.color
	if layer.kind == JeffForge3DLayer.Kind.PROCEDURAL:
		# Both palette colors are already present in the generated pixels.
		tint = Color(1, 1, 1, _recipe.primary_color.a if layer.use_palette_tint else 1.0) * layer.color
	if layer.palette_hue_shift and layer.use_palette_tint:
		# Hue replacement is handled by the shader; keep opacity and local tint here.
		var palette: Color = _recipe.secondary_color if layer.secondary else _recipe.primary_color
		tint = Color(1, 1, 1, palette.a) * layer.color
	tint.r *= _recipe.brightness
	tint.g *= _recipe.brightness
	tint.b *= _recipe.brightness
	tint.a *= layer.opacity
	return tint

func _material(layer: JeffForge3DLayer, particle: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader: Shader = load("res://addons/fx_forge/legacy/assets/pixel_fx.gdshader")
	if layer.additive:
		if _additive_shader == null or _additive_source != shader.code:
			_additive_source = shader.code
			_additive_shader = Shader.new()
			_additive_shader.code = shader.code.replace("depth_draw_never;", "depth_draw_never, blend_add;")
		shader = _additive_shader
	mat.shader = shader
	mat.render_priority = layer.sort_priority
	if layer.kind != JeffForge3DLayer.Kind.PROCEDURAL:
		mat.set_shader_parameter("mask_texture", load("res://addons/fx_forge/legacy/assets/textures/%s.png" % layer.texture_name))
	mat.set_shader_parameter("tint", _color(layer))
	mat.set_shader_parameter("palette_hue_shift", layer.palette_hue_shift and layer.use_palette_tint)
	mat.set_shader_parameter("palette_reference", layer.palette_reference)
	mat.set_shader_parameter("palette_target", _recipe.secondary_color if layer.secondary else _recipe.primary_color)
	mat.set_shader_parameter("face_camera", layer.facing == JeffForge3DLayer.Facing.CAMERA)
	mat.set_shader_parameter("ground_particle", particle and layer.facing == JeffForge3DLayer.Facing.GROUND)
	mat.set_shader_parameter("particle", particle)
	mat.set_shader_parameter("field", layer.kind == JeffForge3DLayer.Kind.FIELD)
	if layer.kind == JeffForge3DLayer.Kind.FIELD:
		mat.set_shader_parameter("shape_angle", deg_to_rad(layer.rotation_degrees.z))
	mat.set_shader_parameter("hard_edge", layer.hard_edge)
	mat.set_shader_parameter("atlas_frames", layer.atlas_frames)
	mat.set_shader_parameter("animation_cycles", layer.animation_fps * layer.lifetime / maxi(1, layer.atlas_frames))
	mat.set_shader_parameter("animation_loop", layer.animation_loop)
	mat.set_shader_parameter("arc_span", deg_to_rad(layer.arc_degrees))
	mat.set_shader_parameter("branch_count", layer.branch_count)
	mat.set_shader_parameter("motif_count", layer.motif_count)
	return mat

func _make_particles(layer: JeffForge3DLayer, index: int) -> Node3D:
	var cpu := CPUParticles3D.new()
	cpu.emitting = false
	cpu.one_shot = not layer.continuous
	cpu.amount = maxi(1, int(layer.count * clampf(_recipe.density, 0.05, 3.0) * (0.45 if is_reduced() else 1.0)))
	cpu.lifetime = maxf(layer.lifetime, 0.05)
	cpu.explosiveness = 0.0 if layer.continuous else layer.explosiveness
	cpu.randomness = 0.15
	cpu.use_fixed_seed = true
	cpu.seed = absi(_recipe.seed + index * 7919)
	cpu.local_coords = layer.local_space
	cpu.fixed_fps = 30
	cpu.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	cpu.direction = layer.direction
	cpu.spread = layer.spread
	cpu.gravity = layer.gravity * _recipe.effect_scale
	cpu.initial_velocity_min = minf(layer.velocity_min, layer.velocity_max) * _recipe.effect_scale
	cpu.initial_velocity_max = maxf(layer.velocity_min, layer.velocity_max) * _recipe.effect_scale
	cpu.scale_amount_min = layer.size * 0.65 * _recipe.effect_scale
	cpu.scale_amount_max = layer.size * _recipe.effect_scale
	cpu.color = _color(layer)
	cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cpu.emission_box_extents = layer.emission_box * _recipe.effect_scale
	cpu.angular_velocity_min = -layer.spin
	cpu.angular_velocity_max = layer.spin
	cpu.particle_flag_rotate_y = true
	cpu.anim_speed_min = 1.0
	cpu.anim_speed_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.5), Color.WHITE, Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
	cpu.color_ramp = ramp
	var curve := Curve.new()
	curve.max_value = maxf(1.0, layer.end_size)
	curve.add_point(Vector2(0, 0.65))
	curve.add_point(Vector2(0.18, 1))
	curve.add_point(Vector2(1, layer.end_size))
	cpu.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = layer.aspect
	quad.material = _material(layer, true)
	cpu.mesh = quad
	cpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var radius: float = (layer.emission_box.length() + maxf(layer.velocity_min, layer.velocity_max) * layer.lifetime + layer.gravity.length() * layer.lifetime * layer.lifetime + layer.size * maxf(layer.aspect.x, layer.aspect.y) + 2.0) * _recipe.effect_scale
	cpu.visibility_aabb = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	if not uses_gpu():
		return cpu
	var gpu := GPUParticles3D.new()
	gpu.convert_from_particles(cpu)
	gpu.emitting = false
	gpu.use_fixed_seed = true
	gpu.seed = cpu.seed
	gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpu.visibility_aabb = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)
	cpu.free()
	return gpu

func _make_shape(layer: JeffForge3DLayer) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = layer.aspect
	quad.material = _material(layer, false)
	node.mesh = quad
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	return node

func _sync(_delta: float, seeking: bool) -> void:
	var movement: Vector3 = global_position - _last_position
	if movement.length_squared() > .000001:
		_motion_direction = movement.normalized()
	_last_position = global_position
	var camera: Camera3D = get_viewport().get_camera_3d()
	var projected: Vector3 = camera.global_basis.inverse() * _motion_direction if camera != null else _motion_direction
	var motion_angle: float = atan2(projected.y, projected.x)
	for i in _visuals.size():
		var node: Node3D = _visuals[i]
		var layer: JeffForge3DLayer = _recipe.layers[_indices[i]]
		var age: float = time - layer.delay - float(node.get_meta("repeat_index", 0)) * layer.repeat_delay
		if age < 0:
			continue
		if _stopping and not _started[i]:
			continue
		if layer.kind == JeffForge3DLayer.Kind.MISSILE:
			_started[i] = true
			node.visible = true
			node.sync(age, seeking)
			if not seeking and not preview_enabled:
				for event in node.events:
					_arrival_queue.append(event)
			node.events.clear()
			continue
		if layer.kind == JeffForge3DLayer.Kind.FIELD:
			_started[i] = true
			node.visible = true
			node.sync(time, _stop_time if _stopping else (-1.0 if _recipe.looping else _recipe.duration))
			continue
		if layer.kind == JeffForge3DLayer.Kind.PARTICLES:
			# At the exact emission boundary there is no simulation interval yet.
			# Avoid a renderer-dependent restart frame when seeking to zero age.
			if seeking and age <= 0.000001:
				continue
			if not _started[i] and not _stopping:
				_started[i] = true
				node.visible = true
				node.call("restart", true)
				if seeking:
					node.set("speed_scale", 0.0)
					var emission_time: float = age
					var residual: float = 0.0
					if layer.continuous and not _recipe.looping:
						emission_time = minf(age, maxf(0.0, _recipe.duration - layer.delay))
						residual = age - emission_time
					if node is GPUParticles3D and DisplayServer.get_name() != "headless":
						_seek_gpu_after_upload(node, emission_time, residual, _build_generation)
					else:
						node.call("request_particles_process", emission_time, residual)
			if _stopping or (layer.continuous and not _recipe.looping and time >= _recipe.duration):
				node.set("emitting", false)
		else:
			_started[i] = true
			var mesh := node as MeshInstance3D
			var ratio: float = clampf(age / maxf(layer.duration, 0.05), 0.0, 1.0)
			var alpha: float = 1.0
			var size_now: float
			if _recipe.looping:
				size_now = layer.size * (1.0 + sin(age * layer.pulse_speed) * layer.pulse)
				alpha = minf(age / maxf(.001, layer.fade_in), 1.0)
			else:
				size_now = lerpf(layer.size, layer.end_size, 1.0 - pow(1.0 - ratio, 2.0))
				alpha = minf(age / maxf(.001, layer.fade_in), 1.0) * clampf((layer.duration - age) / maxf(.001, layer.fade_out), 0, 1)
			if _stopping:
				alpha *= clampf(1.0 - (time - _stop_time) / maxf(.001, layer.fade_out), 0.0, 1.0)
			mesh.visible = alpha > 0.005 and size_now > 0.001
			if layer.kind == JeffForge3DLayer.Kind.PROCEDURAL and mesh.visible:
				# Stop freezes the current path and lets the common opacity tail finish.
				node.sync(age - maxf(0, time - _stop_time) if _stopping else age)
			mesh.scale = Vector3.ONE * maxf(size_now * _recipe.effect_scale, 0.001)
			mesh.rotation_degrees = layer.rotation_degrees
			if layer.facing == JeffForge3DLayer.Facing.GROUND:
				mesh.rotation_degrees.x -= 90.0
			mesh.rotate_object_local(Vector3.FORWARD, deg_to_rad(age * layer.spin))
			var mat := mesh.mesh.material as ShaderMaterial
			var tint: Color = _color(layer)
			tint.a *= alpha
			mat.set_shader_parameter("tint", tint)
			if layer.kind == JeffForge3DLayer.Kind.PROCEDURAL:
				node.apply_path_transform(_recipe.effect_scale, tint)
			mat.set_shader_parameter("shape_frame", fposmod(floorf(age * layer.animation_fps), maxi(1, layer.atlas_frames)) if layer.animation_loop else minf(layer.atlas_frames - 1, floorf(age * layer.animation_fps)))
			mat.set_shader_parameter("shape_angle", deg_to_rad(layer.rotation_degrees.z + age * layer.spin) + (motion_angle if layer.align_to_motion and layer.facing == JeffForge3DLayer.Facing.CAMERA else 0.0))

	if not _arrival_queue.is_empty():
		_deliver_arrivals.call_deferred(_build_generation)

func _set_particle_speed() -> void:
	if _recipe == null:
		return
	for i in _visuals.size():
		if _recipe.layers[_indices[i]].kind == JeffForge3DLayer.Kind.PARTICLES:
			_visuals[i].set("speed_scale", 0.0 if paused or not playing or _pending_seeks.has(_visuals[i].get_instance_id()) else _recipe.playback_speed * speed_multiplier)

func _seek_gpu_after_upload(node: GPUParticles3D, emission_time: float, residual: float, generation: int) -> void:
	# A newly allocated GPU emitter must reach the renderer before it can seek.
	# Otherwise the initial GPU reset silently discards the processing request.
	var id: int = node.get_instance_id()
	_pending_seeks.append(id)
	for frame in 2:
		await RenderingServer.frame_post_draw
	if not is_instance_valid(node) or generation != _build_generation:
		return
	node.restart(true)
	node.speed_scale = 0
	node.request_particles_process(emission_time, residual)
	await RenderingServer.frame_post_draw
	if generation != _build_generation:
		return
	_pending_seeks.erase(id)
	_set_particle_speed()

func wait_for_seek() -> void:
	while not _pending_seeks.is_empty() and is_inside_tree():
		await RenderingServer.frame_post_draw

func visual_count() -> int:
	return _visuals.size()

func bind_target(node: Node3D, offset: Vector3 = Vector3.ZERO) -> void:
	_target_ref = weakref(node) if node != null else null
	target_offset = offset
	if node==null: target_path=NodePath()
	if node != null and is_inside_tree() and node.is_inside_tree():
		target_path = get_path_to(node)

func get_target() -> Node3D:
	if not target_path.is_empty(): return get_node_or_null(target_path) as Node3D
	if _target_ref != null:
		return _target_ref.get_ref() as Node3D
	return get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null

func _capture_records() -> void:
	_replay_records.clear()
	# Parameter edits install a new recipe; histories from the old recipe cannot apply.
	if preset==null or preset.get_instance_id()!=_playback_preset_id: return
	for i in _visuals.size():
		if _recipe != null and _recipe.layers[_indices[i]].kind == JeffForge3DLayer.Kind.MISSILE:
			if not _visuals[i].target_sampler.is_valid():
				var record: Dictionary=_visuals[i].history_record()
				record.delay=_recipe.layers[_indices[i]].delay
				_replay_records[_indices[i]]=record

func _deliver_arrivals(generation: int) -> void:
	if generation != _build_generation or _stopping or preview_enabled: return
	var pending: Array[Dictionary] = _arrival_queue.duplicate()
	_arrival_queue.clear()
	for event in pending:
		if generation != _build_generation or is_queued_for_deletion() or _stopping: break
		arrived.emit(event.index, event.position)

func missile_metrics() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in _visuals:
		if node is Missile: result.append(node.metrics())
	return result
