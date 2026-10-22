@tool
extends MultiMeshInstance3D
## Analytic, fixed-seed fields. Paired rain/ripples and insects/halos share samples.
## No physics, timers, or independent random particle emitters can desynchronize them.

var layer: JeffForge3DLayer
var source: JeffForge3DLayer
var effect_scale: float = 1.0
var samples: Array[Vector4] = []
var _sample_position: Vector3
var _sample_alpha: float
var _sample_frame: float

func configure(recipe: JeffForge3DPreset, index: int, reduced: bool, material: Material) -> void:
	layer = recipe.layers[index]
	var source_index: int = layer.motion_source if layer.motion_source >= 0 and layer.motion_source < recipe.layers.size() else index
	source = recipe.layers[source_index]
	samples.clear()
	effect_scale = recipe.effect_scale
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = layer.aspect
	quad.material = material
	multimesh.mesh = quad
	var body_count: int = maxi(1, int(source.count * clampf(recipe.density, .05, 3.0) * (.45 if reduced else 1.0)))
	multimesh.instance_count = body_count * (clampi(layer.satellite_count, 1, 4) if layer.field_motion == JeffForge3DLayer.FieldMotion.FIREFLY_MOTES else 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(recipe.seed + source_index * 7919)
	for i in body_count:
		samples.append(Vector4(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf()))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fall_time: float = source.fall_height / maxf(.1, source.motion_speed)
	var radius: float = (source.emission_box.length() + source.fall_height + source.offset.length() + layer.offset.length() + source.wander + layer.satellite_radius + layer.size * maxf(layer.aspect.x, layer.aspect.y) + source.wind.length() * fall_time + 2) * effect_scale
	custom_aabb = AABB(-Vector3.ONE * radius, Vector3.ONE * radius * 2)

func sample_at(index: int, effect_time: float, stopped_at: float = -1.0) -> Dictionary:
	# Public inspection returns an independent snapshot; the hot update path
	# avoids allocating a Dictionary and rebuilding a Basis for every particle.
	_evaluate(index, effect_time, stopped_at)
	return {"position": _sample_position, "alpha": _sample_alpha, "size": layer.size * effect_scale, "frame": _sample_frame}

func _evaluate(index: int, effect_time: float, stopped_at: float) -> void:
	var is_mote: bool = layer.field_motion == JeffForge3DLayer.FieldMotion.FIREFLY_MOTES
	var sample: Vector4 = samples[index / clampi(layer.satellite_count, 1, 4) if is_mote else index]
	var age: float = effect_time - source.delay
	var point := Vector3(sample.x, sample.y, sample.z) * source.emission_box
	var opacity: float = 1.0
	var frame: float = 0.0
	if source.field_motion == JeffForge3DLayer.FieldMotion.RAIN:
		var fall: float = source.fall_height / maxf(.1, source.motion_speed)
		var cycle: float = fall + maxf(source.ripple_duration, .05)
		var elapsed: float = age - sample.w * cycle
		var birth: float = source.delay + sample.w * cycle + floorf(elapsed / cycle) * cycle
		var phase: float = fposmod(elapsed, cycle)
		point.y = 0.0
		if elapsed < 0 or (stopped_at >= 0 and birth > stopped_at):
			opacity = 0
		if layer.field_motion == JeffForge3DLayer.FieldMotion.RAIN:
			if phase >= fall:
				opacity = 0
			point.y += maxf(0, source.fall_height - phase * source.motion_speed)
			point += Vector3(source.wind.x, 0, source.wind.z) * minf(phase, fall)
		else:
			if phase < fall:
				opacity = 0
			point += Vector3(source.wind.x, 0, source.wind.z) * fall
			var ripple_age: float = maxf(0, phase - fall)
			frame = minf(layer.atlas_frames - 1, floorf(ripple_age / maxf(.05, source.ripple_duration) * layer.atlas_frames))
	else:
		var phase: float = sample.w * TAU
		var variation: float = clampf(source.flight_variation, 0, 1)
		# Analytic phase modulation eases between hovering and travel. Unlike
		# accumulated noise it gives exactly the same path after reverse seeking.
		var flight_time: float = age * source.motion_speed
		var varied_time: float = flight_time * (1.0 + sample.x * .25) + .65 * sin(flight_time * .7 + phase)
		var travel: float = lerpf(flight_time, varied_time, variation)
		point += Vector3(sin(travel + phase), sin(travel * .73 + phase) * .5, cos(travel * .81 + phase)) * source.wander
		point += Vector3(sin(travel * 1.91 + phase * 2.3) * .22, sin(travel * 1.37 + phase * 1.7) * .18, cos(travel * 1.53 - phase) * .2) * source.wander * variation
		var blink: float = .5 + .5 * sin(age * source.blink_speed + phase)
		opacity = (.15 + blink * .65) if layer.field_motion == JeffForge3DLayer.FieldMotion.FIREFLY_GLOW else (.65 + blink * .35)
		opacity *= clampf(age / maxf(.01, source.fade_in), 0, 1)
		if stopped_at >= 0:
			opacity *= clampf(1 - (effect_time - stopped_at) / maxf(.01, source.fade_out), 0, 1)
		frame = fposmod(floorf(age * layer.animation_fps + sample.w * layer.atlas_frames), maxi(1, layer.atlas_frames))
		if is_mote:
			var satellite: int = index % clampi(layer.satellite_count, 1, 4)
			var orbit: float = phase + satellite * TAU / clampi(layer.satellite_count, 1, 4) + age * layer.satellite_speed
			point += Vector3(cos(orbit), sin(orbit * .83) * .55, sin(orbit)) * layer.satellite_radius
			opacity *= .35 + .65 * pow(.5 + .5 * sin(age * 3.7 + phase + satellite * 2.1), 2)
			frame = fposmod(frame + satellite * 3, maxi(1, layer.atlas_frames))
	point = (point + source.offset + (layer.offset if layer.motion_source >= 0 else Vector3.ZERO)) * effect_scale
	_sample_position = point
	_sample_alpha = opacity
	_sample_frame = frame

func sync(effect_time: float, stopped_at: float = -1.0) -> void:
	var basis := Basis.from_euler(layer.rotation_degrees * PI / 180.0)
	if layer.facing == JeffForge3DLayer.Facing.GROUND:
		basis = basis * Basis(Vector3.RIGHT, -PI / 2)
	basis = basis.scaled(Vector3.ONE * maxf(.001, layer.size * effect_scale))
	for i in multimesh.instance_count:
		_evaluate(i, effect_time, stopped_at)
		multimesh.set_instance_transform(i, Transform3D(basis, _sample_position))
		multimesh.set_instance_custom_data(i, Color(0, _sample_alpha, _sample_frame, 0))
