@tool
extends MeshInstance3D
## Original analytic paths rasterized on a small native pixel grid, without atlases.
## Absolute effect time makes scrubbing independent of frame rate and play history.

const Skills = preload("res://addons/fx_forge/legacy/runtime/fx_pixel_skills.gd")
var _skill_count: int
var _detail: float
var _flame_heat: Array[float] = []
var pixels: Image
var pixel_texture: ImageTexture
var impact_pixels: Image
var impact_texture: ImageTexture
var impact_mesh: MeshInstance3D
var impact_air_pixels: Image
var impact_air_texture: ImageTexture
var impact_air_mesh: MeshInstance3D
var _impact_count: int
const PATH_MARGIN: float = 0.12
const PATH_SPAN: float = 0.76
var redraw_count: int = 0
var _layer: JeffForge3DLayer
var _seed: int
var _resolution: int
var _fps: int
var _strands: int
var _branches: int
var _tongues: int
var _embers: int
var _looping: bool
var _last_tick: int = -1
var _palette: Array[Color] = []

func configure(recipe: JeffForge3DPreset, index: int, reduced: bool, material: ShaderMaterial, copy_index: int = 0) -> void:
	_layer = recipe.layers[index]
	_seed = posmod(recipe.seed + index * 7919, 1000003)
	if uses_endpoints():
		_seed = posmod(_seed + copy_index * 104729, 1000003)
	_impact_count = clampi(_layer.impact_sparks, 0, 24)
	_resolution = clampi(_layer.pixel_resolution, 32, 128)
	_fps = clampi(_layer.redraw_fps, 6, 30)
	if reduced:
		_fps = mini(_fps, 15)
	_strands = clampi(int(_layer.strand_count * clampf(recipe.density, .1, 3)), 1, 8)
	_branches = clampi(_layer.arc_branches, 0, 4)
	_tongues = clampi(_layer.flame_tongues, 1, 5)
	_embers = clampi(roundi(_layer.flame_embers * clampf(recipe.density, .1, 3)), 0, 8)
	if reduced:
		_strands = maxi(1, ceili(_strands * .5))
		_branches = mini(_branches, 1)
		_impact_count = ceili(_impact_count * .5)
		_tongues = mini(_tongues, 2)
		_embers = ceili(_embers * .5)
	_skill_count = clampi(roundi(_layer.skill_count * clampf(recipe.density, .1, 3)), 1, 16)
	_detail = clampf(_layer.skill_detail, 0, 1)
	if reduced:
		_skill_count = maxi(1, floori(_skill_count * .6))
		_detail *= .5
	_looping = recipe.looping
	var primary: Color = recipe.primary_color if _layer.use_palette_tint else Color.WHITE
	var secondary: Color = recipe.secondary_color if _layer.use_palette_tint else Color(.6, .6, .6)
	_palette = [secondary.darkened(.35), secondary, primary, primary.lerp(Color.WHITE, .65)]
	if _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.FLAME:
		_palette = [secondary.darkened(.12), secondary.lerp(primary, .5), primary, primary.lerp(Color.WHITE, .78)]
	for i in _palette.size():
		_palette[i].a = 1.0
	if _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.FLAME:
		_flame_heat.resize(_resolution * _resolution)
	pixels = Image.create(_resolution, _resolution, false, Image.FORMAT_RGBA8)
	pixel_texture = ImageTexture.create_from_image(pixels)
	material.set_shader_parameter("mask_texture", pixel_texture)
	material.set_shader_parameter("atlas_frames", 1)
	material.set_shader_parameter("palette_hue_shift", false)
	material.set_shader_parameter("arc_span", TAU)
	material.set_shader_parameter("branch_count", -1)
	material.set_shader_parameter("motif_count", -1)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE if uses_endpoints() else _layer.aspect
	quad.material = material
	mesh = quad
	if uses_endpoints():
		material.set_shader_parameter("face_camera", false)
		material.set_shader_parameter("face_path_axis", true)
		# A camera-facing path can pivot out of the authored plane.
		custom_aabb = AABB(Vector3(-.5, -.5, -.5), Vector3.ONE)
	if _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.ARC and _layer.impact_enabled:
		impact_pixels = Image.create(_resolution, _resolution, false, Image.FORMAT_RGBA8)
		impact_texture = ImageTexture.create_from_image(impact_pixels)
		var impact_material: ShaderMaterial = material.duplicate()
		impact_material.set_shader_parameter("mask_texture", impact_texture)
		impact_material.set_shader_parameter("face_path_axis", false)
		impact_material.set_shader_parameter("face_camera", false)
		var ground := QuadMesh.new()
		ground.material = impact_material
		impact_mesh = MeshInstance3D.new()
		impact_mesh.mesh = ground
		impact_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact_mesh.visible = false
		add_child(impact_mesh)
		impact_air_pixels = Image.create(_resolution, _resolution, false, Image.FORMAT_RGBA8)
		impact_air_texture = ImageTexture.create_from_image(impact_air_pixels)
		var air_material: ShaderMaterial = impact_material.duplicate()
		air_material.set_shader_parameter("mask_texture", impact_air_texture)
		air_material.set_shader_parameter("face_path_axis", true)
		var air := QuadMesh.new()
		air.material = air_material
		impact_air_mesh = MeshInstance3D.new()
		impact_air_mesh.mesh = air
		impact_air_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact_air_mesh.custom_aabb = AABB(Vector3(-.5, -.5, -.5), Vector3.ONE)
		impact_air_mesh.visible = false
		add_child(impact_air_mesh)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)

func sync(age: float) -> void:
	var tick: int = maxi(0, floori(age * _fps + .00001))
	if tick == _last_tick:
		return
	_last_tick = tick
	redraw_count += 1
	pixels.fill(Color.TRANSPARENT)
	var elapsed: float = float(tick) / _fps
	var duration: float = maxf(.05, _layer.duration)
	var phase: float = fposmod(elapsed, duration) / duration if _looping else elapsed / duration
	if phase >= 0 and phase < 1:
		if _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.ARC:
			_draw_arc(phase * duration)
		elif _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.FLAME:
			_draw_flame(elapsed)
		elif _layer.procedural_motion == JeffForge3DLayer.ProceduralMotion.STREAK:
			_draw_streaks(phase)
		else:
			Skills.draw(self, phase)
	# Reuse the same CPU buffer and GPU texture, including when seeking within a tick.
	pixel_texture.update(pixels)
	if impact_pixels != null:
		# Reuse the raster helpers and palette, with a separate retained buffer.
		var bolt_pixels: Image = pixels
		pixels = impact_pixels
		pixels.fill(Color.TRANSPARENT)
		if phase >= 0 and phase < 1:
			_draw_impact(phase * duration - contact_time())
		pixels = bolt_pixels
		impact_texture.update(impact_pixels)
		impact_mesh.visible = not impact_pixels.is_invisible()
		pixels = impact_air_pixels
		pixels.fill(Color.TRANSPARENT)
		if phase >= 0 and phase < 1:
			_draw_impact_air(phase * duration - contact_time())
		pixels = bolt_pixels
		impact_air_texture.update(impact_air_pixels)
		impact_air_mesh.visible = not impact_air_pixels.is_invisible()

func _noise(key: int) -> float:
	var h: int = (key * 374761393 + _seed * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / 2147483647.0

func uses_endpoints() -> bool:
	return _layer.procedural_motion in [JeffForge3DLayer.ProceduralMotion.STREAK, JeffForge3DLayer.ProceduralMotion.ARC]

func contact_time() -> float:
	return clampf(_layer.strike_time, .01, maxf(.01, _layer.duration * .65))

func apply_path_transform(effect_scale: float, tint: Color) -> void:
	if not uses_endpoints():
		return
	var delta: Vector3 = _layer.path_end - _layer.path_start
	if not delta.is_finite() or delta.length_squared() < .000001:
		visible = false
		return
	var x: Vector3 = delta.normalized()
	var up: Vector3 = Vector3.RIGHT if absf(x.dot(Vector3.UP)) > .99 else Vector3.UP
	var z: Vector3 = x.cross(up).normalized()
	var y: Vector3 = z.cross(x).normalized()
	var side: float = delta.length() / PATH_SPAN * effect_scale
	transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * side), ((_layer.path_start + _layer.path_end) * .5 + _layer.offset) * effect_scale)
	if impact_mesh != null:
		var diameter: float = clampf(_layer.impact_radius, .05, 3) * 2.0 * effect_scale
		var ground_basis := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).scaled(Vector3.ONE * diameter)
		var ground := Transform3D(ground_basis, (_layer.path_end + _layer.offset) * effect_scale + Vector3.UP * .008 * effect_scale)
		impact_mesh.transform = transform.affine_inverse() * ground
		impact_mesh.mesh.material.set_shader_parameter("tint", tint)
		# Upright spray pivots around UP; its lower anchor stays at the contact point.
		var air_basis := Basis(Vector3.UP, Vector3.RIGHT, Vector3.FORWARD).scaled(Vector3.ONE * diameter)
		var air := Transform3D(air_basis, ground.origin + Vector3.UP * .35 * diameter)
		impact_air_mesh.transform = transform.affine_inverse() * air
		impact_air_mesh.mesh.material.set_shader_parameter("tint", tint)

func _draw_streaks(phase: float) -> void:
	var steps: int = clampi(_layer.path_segments, 4, 32)
	var length: float = clampf(_layer.trail_length, .1, 1)
	for strand in _strands:
		var offset: float = _noise(strand * 17 + 5) * .08
		var local_phase: float = clampf((phase - offset) / (1.0 - offset), 0, 1)
		if local_phase <= 0 or local_phase >= 1:
			continue
		var arrival: float = .62 + _noise(strand * 37 + 3) * .15
		var progress: float = minf(1, local_phase / arrival)
		var head: float = 1.0 - pow(1.0 - progress, 1.4)
		var retract: float = maxf(0, (local_phase - arrival) / (1.0 - arrival))
		var start: float = maxf(0, head - length * (1-retract))
		var previous: Vector2 = _streak_point(start, strand)
		for segment in range(1, steps + 1):
			var u: float = lerpf(start, head, float(segment) / steps)
			var tail: float = clampf((u - start) / maxf(.001, head-start), 0, 1)
			var point: Vector2 = _streak_point(u, strand)
			var width: int = maxi(1, roundi(clampi(_layer.stroke_width, 1, 6) * pow(tail, .7)))
			_line(previous, point, width, _palette[clampi(int(tail * 4), 0, 3)])
			previous = point

func _streak_point(u: float, strand: int) -> Vector2:
	# Both random lobes vanish at the anchors. No per-frame random teleports.
	var curve: float = clampf(_layer.curvature, -1, 1)
	var variation: float = clampf(_layer.path_jitter, 0, .35)
	var bend: float = curve * .15 + (_noise(strand * 83 + 17) * 2 - 1) * (absf(curve) * .16 + variation * .8)
	var wave: float = (_noise(strand * 127 + 43) * 2 - 1) * variation * .45
	var y: float = .5 + sin(u * PI) * bend + sin(u * TAU) * wave
	return Vector2(PATH_MARGIN + u * PATH_SPAN, clampf(y, .08, .92)) * (_resolution - 1)

func _arc_point(u: float, segment: int) -> Vector2:
	var bend: float = sin(u * PI) * clampf(_layer.curvature, -1, 1) * .22
	var jitter: float = (_noise(segment * 43 + 199) - .5) * 2 * clampf(_layer.path_jitter, 0, .35)
	return Vector2(PATH_MARGIN + u * PATH_SPAN, clampf(.5 + bend + jitter * sin(u * PI), .08, .92)) * (_resolution - 1)

func _draw_arc(elapsed: float) -> void:
	var contact: float = contact_time()
	var after: float = elapsed - contact
	# One leader advances, flashes on contact, then dies; the path never re-strikes.
	if after >= .16:
		return
	var segments: int = clampi(_layer.path_segments, 4, 32)
	var growth: float = clampf(elapsed / contact, 0, 1)
	if growth <= 0:
		return
	var width: int = clampi(_layer.stroke_width, 1, 6)
	if after > .07:
		width = maxi(1, width - 1)
	var previous: Vector2 = _arc_point(0, 0)
	for segment in range(1, segments + 1):
		var u: float = float(segment) / segments
		var point: Vector2 = _arc_point(u, segment)
		if float(segment - 1) / segments >= growth:
			break
		var endpoint: Vector2 = previous.lerp(point, clampf((growth - float(segment - 1) / segments) * segments, 0, 1))
		_line(previous, endpoint, width, _palette[1])
		if width > 1 or after < .07:
			_line(previous, endpoint, maxi(1, width - 2), _palette[3 if after >= 0 and after < .04 else 2])
		previous = point
	for branch in _branches:
		var root_segment: int = clampi(int(segments * (.25 + branch * .14)), 1, segments - 1)
		var root_u: float = float(root_segment) / segments
		if root_u >= growth or after > .09:
			continue
		var root: Vector2 = _arc_point(root_u, root_segment)
		var sign_y: float = -1 if branch % 2 == 0 else 1
		var spread: float = (.10 + _noise(branch * 19 + 71) * .10) * _resolution
		var middle: Vector2 = root + Vector2(.05 * _resolution, spread * sign_y * .5)
		var end: Vector2 = root + Vector2(.12 * _resolution, spread * sign_y)
		_line(root, middle, maxi(1, width - 1), _palette[1])
		_line(middle, end, 1, _palette[0])

func _draw_impact(age: float) -> void:
	var duration: float = minf(clampf(_layer.impact_duration, .05, 2), maxf(.01, _layer.duration - contact_time()))
	if age < 0 or age >= duration:
		return
	var p: float = age / duration
	var center := Vector2.ONE * (_resolution - 1) * .5
	if p < .3:
		var flash: float = (1 - p / .3) * _resolution * .18
		_ellipse(center, Vector2.ONE * flash, _palette[2])
		_line(center - Vector2(flash * 1.4, 0), center + Vector2(flash * 1.4, 0), 2, _palette[3])
		_line(center - Vector2(0, flash * 1.4), center + Vector2(0, flash * 1.4), 2, _palette[3])
	# A broken shock rim and ballistic splinters spread from the same contact point.
	var reach: float = .43 * _resolution * (1-pow(1-p, 2.4))
	for segment in 40:
		if p > .35 and _noise(segment + 501) < p * .8:
			continue
		var a: float = float(segment) / 40 * TAU
		var b: float = float(segment + 1) / 40 * TAU
		_line(center + Vector2.from_angle(a) * reach, center + Vector2.from_angle(b) * reach, 1, _palette[1 if p < .35 else 0])
	for spark in _impact_count:
		var angle: float = (float(spark) + _noise(spark + 601) * .8) / maxi(1, _impact_count) * TAU
		var direction := Vector2.from_angle(angle)
		var travel: float = reach * (.6 + _noise(spark + 641) * .4)
		var length: float = _resolution * .17 * pow(1-p, 1.7)
		_line(center + direction * maxf(0, travel-length), center + direction * travel, 2 if p < .5 else 1, _palette[2 if p < .65 else 1])

func _draw_impact_air(age: float) -> void:
	var duration: float = minf(clampf(_layer.impact_duration, .05, 2), maxf(.01, _layer.duration - contact_time()))
	if age < 0 or age >= duration:
		return
	var p: float = age / duration
	for spark in _impact_count:
		var vx: float = (_noise(spark + 701) * 2 - 1) * .35
		var height: float = .25 + _noise(spark + 743) * .4
		var life: float = p / (.65 + _noise(spark + 781) * .35)
		if life >= 1:
			continue
		# Ballistic rise and fall; the tail follows the tangent instead of flickering.
		var previous: float = maxf(0, life - .09 * (1-life))
		var head := Vector2(.15 + sin(life * PI) * height, .5 + vx * life)
		var tail := Vector2(.15 + sin(previous * PI) * height, .5 + vx * previous)
		_line(tail * (_resolution-1), head * (_resolution-1), 2 if life < .45 else 1, _palette[2 if life < .5 else 1])
		if life < .35:
			_line(head * (_resolution-1), head * (_resolution-1), 1, _palette[3])

func _draw_flame(elapsed: float) -> void:
	Skills.flame(self, elapsed)

func _span(y: int, left: float, right: float, ink: Color) -> void:
	var start: int = maxi(1, roundi(left))
	var end: int = mini(_resolution - 2, roundi(right))
	if start <= end:
		pixels.fill_rect(Rect2i(start, y, end - start + 1, 1), ink)

func _ellipse(center: Vector2, radius: Vector2, ink: Color) -> void:
	if radius.x < .35 or radius.y < .35:
		return
	for y in range(maxi(1, floori(center.y-radius.y)), mini(_resolution-1, ceili(center.y+radius.y))):
		var dy: float = (y + .5-center.y) / radius.y
		var span: float = radius.x * sqrt(maxf(0, 1-dy*dy))
		_span(y, center.x-span, center.x+span, ink)

func _line(from: Vector2, to: Vector2, width: int, ink: Color) -> void:
	var a := Vector2i(from.round())
	var b := Vector2i(to.round())
	var delta := b - a
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	var half: int = width / 2
	for step in steps + 1:
		var p := Vector2i(Vector2(a).lerp(Vector2(b), float(step) / maxi(1, steps)).round())
		# The grid has a protected border, even at extreme parameter values.
		var rect := Rect2i(p - Vector2i.ONE * half, Vector2i.ONE * width)
		rect = rect.intersection(Rect2i(1, 1, _resolution - 2, _resolution - 2))
		if rect.has_area():
			pixels.fill_rect(rect, ink)

func _polygon(points: PackedVector2Array, ink: Color) -> void:
	# Scan conversion at native resolution; no anti-aliased intermediary.
	var top: float = _resolution
	var bottom: float = 0
	for point in points:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	for y in range(maxi(1, floori(top)), mini(_resolution-1, ceili(bottom))):
		var crossings: Array[float] = []
		for i in points.size():
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i+1)%points.size()]
			if (a.y <= y+.5 and b.y > y+.5) or (b.y <= y+.5 and a.y > y+.5):
				crossings.append(a.x+(y+.5-a.y)/(b.y-a.y)*(b.x-a.x))
		crossings.sort()
		for i in range(0, crossings.size()-1, 2):
			_span(y, crossings[i], crossings[i+1], ink)
