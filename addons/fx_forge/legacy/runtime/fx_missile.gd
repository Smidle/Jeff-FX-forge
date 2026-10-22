@tool
extends Node3D
## Fixed-step world-space simulation. Nodes, textures and mesh buffers are allocated once.
const Config=preload("res://addons/fx_forge/legacy/runtime/fx_missile_config.gd")
const Path=preload("res://addons/fx_forge/legacy/runtime/fx_missile_path.gd")
const Art=preload("res://addons/fx_forge/legacy/runtime/fx_missile_art.gd")
const Buffers=preload("res://addons/fx_forge/legacy/runtime/fx_missile_buffers.gd")
# Retain shader resources across instances; load() alone leaves only weak cache entries.
const SPRITE_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_sprite.gdshader")
const TRAIL_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_trail.gdshader")
const SHARDS_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_shards.gdshader")
const ORNAMENT_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_magic_ornament.gdshader")
const MAGIC_IMPACT_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_magic_impact.gdshader")
const MAGIC_FRAGMENTS_SHADER=preload("res://addons/fx_forge/legacy/assets/missile_magic_fragments.gdshader")
const STEP: float=1.0/60.0
var config: Resource
var states: Array[Dictionary]=[]
var events: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var binding_required: bool=false
var target: WeakRef
var target_offset: Vector3
var target_sampler: Callable
var source: Node3D
var source_samples: Dictionary={}
var seed: int=42
var capacity: int=128
var appearance: float=1
var clock: float=0
var tick: int=-1
var stopped: bool=false
var replay: bool=false
var cpu_usec: int=0
var peak_usec: int=0
var head_art: RefCounted
var head_texture: ImageTexture
var _head_frame: int=-1
var _brightness: float=1
var _opacity: float=1
var _mote_count: int=0
var _impact_fragments: int=0
var _shard_count: int=0
var _fixed_end: Vector3
var _target_last: Vector3
var _target_known: bool=false
var _target_valid: bool=true

func configure(recipe: Resource, layer: Resource, reduced: bool, owner_instance: Node3D) -> void:
	config=layer.missile.copy() if layer.missile!=null else Config.new()
	seed=recipe.seed
	capacity=64 if reduced else 128
	appearance=clampf(recipe.effect_scale,.01,100)
	_brightness=recipe.brightness
	_opacity=layer.opacity*recipe.primary_color.a
	_mote_count=clampi(config.motes,0,24)/(2 if reduced else 1)
	_impact_fragments=clampi(config.impact_fragments,0,24)/(2 if reduced else 1)
	_shard_count=3 if reduced else 6
	source=owner_instance
	_fixed_end=source.to_global(config.end)
	top_level=true
	global_transform=Transform3D.IDENTITY
	head_art=Art.new(clampi(config.pixel_density,16,128))
	head_art.colors(recipe.primary_color,recipe.secondary_color,config.saturation)
	head_art.head(config.head_style,0,config.deformation,config.halo)
	head_texture=ImageTexture.create_from_image(head_art.image)
	for i in clampi(config.projectile_count,1,16):
		var s: Dictionary={"index":i,"launched":false,"ended":false,"cancelled":false,"end_time":0.0,
			"position":Vector3.ZERO,"velocity":Vector3.RIGHT,"end":Vector3.ZERO,"guide_time":-1.0,
			"history":PackedVector3Array(),"path":{},"trail_frozen":false,"trail_uploads":0,"launch":i*clampf(config.launch_interval,0,1)}
		s.head=_sprite(head_texture,3,config.head_size*appearance,config.head_aspect)
		s.head.material_override.render_priority=1
		# Rotate in the flight plane, keeping the physical tip and tail joint aligned.
		s.head.material_override.set_shader_parameter("pixel_density",float(head_art.size))
		s.head.material_override.set_shader_parameter("hot_color",head_art.palette[3])
		s.head.material_override.set_shader_parameter("element",config.head_style)
		s.gpu_impact=config.impact_style>=Config.Impact.FLAME
		s.impact_art=null; s.impact_texture=null
		if s.gpu_impact:
			s.impact=_magic_quad(MAGIC_IMPACT_SHADER,config.impact_size*appearance)
			s.impact.material_override.set_shader_parameter("style",config.impact_style)
			s.impact.material_override.set_shader_parameter("facing",config.impact_facing)
			s.impact.material_override.set_shader_parameter("ornament",clampf(config.magic_ornament,0,1))
			s.impact_fragments=_magic_fragments(i,_impact_fragments,config.impact_style-2,true)
		else:
			s.impact_art=Art.new(clampi(config.pixel_density,16,128))
			s.impact_art.colors(recipe.primary_color,recipe.secondary_color,config.saturation)
			s.impact_texture=ImageTexture.create_from_image(s.impact_art.image)
			s.impact=_sprite(s.impact_texture,config.impact_facing,config.impact_size*appearance,1)
			s.impact_fragments=null
		s.impact_frame=-1
		s.trail=_trail(s)
		s.shards=_shards(i) if config.head_style==Config.Head.SWORD else _magic_fragments(i,_shard_count,config.head_style,false)
		s.ornaments=null
		if config.head_style!=Config.Head.SWORD:
			s.ornaments=_magic_quad(ORNAMENT_SHADER,config.head_size*appearance)
			var material: ShaderMaterial=s.ornaments.material_override
			material.set_shader_parameter("element",config.head_style)
			material.set_shader_parameter("aspect",maxf(.25,config.head_aspect))
			material.set_shader_parameter("strength",clampf(config.magic_ornament,0,1))
			material.set_shader_parameter("speed",clampf(config.orbit_speed,0,3))
			material.set_shader_parameter("reduced",reduced)
		var mote_image:=Image.create(3,3,false,Image.FORMAT_RGBA8)
		mote_image.fill(Color.TRANSPARENT)
		for p in [Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(1,2)]:
			mote_image.set_pixelv(p,head_art.palette[3] if p==Vector2i(1,1) else head_art.palette[1])
		var mote_texture:=ImageTexture.create_from_image(mote_image)
		var mote_mesh:=QuadMesh.new()
		mote_mesh.size=Vector2.ONE
		var mote_mat:=_sprite_material(mote_texture,0,.035*appearance,1)
		# MultiMesh transforms supply positions; its shader uses their world origin.
		mote_mesh.material=mote_mat
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=mote_mesh
		mm.instance_count=_mote_count
		mm.visible_instance_count=0
		var motes:=MultiMeshInstance3D.new()
		motes.multimesh=mm
		motes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(motes)
		s.motes=motes
		s.mote_positions=PackedVector3Array()
		s.mote_positions.resize(_mote_count)
		states.append(s)

func _head_direction(velocity: Vector3) -> Vector3:
	var direction: Vector3=velocity.normalized() if velocity.length_squared()>.000001 else Vector3.RIGHT
	var up: Vector3=Vector3.UP if absf(direction.dot(Vector3.UP))<.99 else Vector3.FORWARD
	return direction.rotated(direction.cross(up).normalized(),deg_to_rad(config.head_rotation))

func _shards(index: int) -> MultiMeshInstance3D:
	var material:=ShaderMaterial.new()
	material.shader=SHARDS_SHADER
	material.set_shader_parameter("age",-1.0)
	material.set_shader_parameter("element",config.head_style)
	material.set_shader_parameter("light_color",head_art.palette[2])
	material.set_shader_parameter("hot_color",head_art.palette[3])
	material.set_shader_parameter("size",config.head_size*appearance)
	material.set_shader_parameter("brightness",_brightness)
	material.set_shader_parameter("opacity",_opacity)
	material.set_shader_parameter("dissolve_duration",clampf(config.head_dissolve,0,.4))
	material.set_shader_parameter("tail_duration",maxf(clampf(config.head_dissolve,0,.4),clampf(config.trail_fade,.05,2)))
	var mesh:=QuadMesh.new(); mesh.size=Vector2.ONE; mesh.material=material
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_custom_data=true
	mm.mesh=mesh; mm.instance_count=_shard_count
	for i in _shard_count:
		mm.set_instance_transform(i,Transform3D.IDENTITY)
		mm.set_instance_custom_data(i,Color((i+.5)/_shard_count,Path.noise(seed+index,800+i),float(i%2),1))
	var node:=MultiMeshInstance3D.new(); node.multimesh=mm
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3.ONE*-config.head_size*appearance*2,Vector3.ONE*config.head_size*appearance*4)
	node.visible=false; add_child(node)
	return node

func _tail_root() -> float:
	return [.84,.60,.74,.72][clampi(config.head_style,0,3)]

func _magic_material(shader: Shader, size: float) -> ShaderMaterial:
	var material:=ShaderMaterial.new(); material.shader=shader
	for pair in [["dark_color",0],["mid_color",1],["light_color",2],["hot_color",3]]:
		material.set_shader_parameter(pair[0],head_art.palette[pair[1]])
	material.set_shader_parameter("size",size)
	material.set_shader_parameter("density",float(head_art.size))
	material.set_shader_parameter("brightness",_brightness)
	material.set_shader_parameter("opacity",_opacity)
	return material

func _magic_quad(shader: Shader, size: float) -> MeshInstance3D:
	var node:=MeshInstance3D.new(); node.mesh=QuadMesh.new(); node.mesh.size=Vector2.ONE
	node.material_override=_magic_material(shader,size)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin=maxf(1,size*1.5/maxf(.25,config.head_aspect))
	node.visible=false; add_child(node)
	return node

func _magic_fragments(index: int, count: int, element: int, impact: bool) -> MultiMeshInstance3D:
	var size: float=(config.impact_size if impact else config.head_size)*appearance
	var material:=_magic_material(MAGIC_FRAGMENTS_SHADER,size)
	material.set_shader_parameter("element",element)
	material.set_shader_parameter("impact_mode",impact)
	material.set_shader_parameter("duration",config.impact_duration if impact else maxf(config.head_dissolve,config.trail_fade))
	material.set_shader_parameter("dissolve_duration",config.head_dissolve)
	material.set_shader_parameter("body_length",_tail_root())
	var mesh:=QuadMesh.new(); mesh.size=Vector2.ONE; mesh.material=material
	var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.use_custom_data=true
	mm.mesh=mesh; mm.instance_count=count
	for i in count:
		mm.set_instance_transform(i,Transform3D.IDENTITY)
		mm.set_instance_custom_data(i,Color((i+.5)/maxi(1,count),Path.noise(seed+index,900+i),float(i%2),1))
	var node:=MultiMeshInstance3D.new(); node.multimesh=mm
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb=AABB(Vector3.ONE*-size*2,Vector3.ONE*size*4)
	node.visible=false; add_child(node)
	return node

func bind(node: Node3D, offset: Vector3, sampler: Callable=Callable(), required: bool=false) -> void:
	binding_required=required
	target=weakref(node) if node!=null else null
	target_offset=offset
	target_sampler=sampler

func _sprite_material(texture: Texture2D, facing: int, size: float, aspect: float) -> ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=SPRITE_SHADER
	material.set_shader_parameter("pixels",texture)
	material.set_shader_parameter("size",size)
	material.set_shader_parameter("aspect",maxf(.25,aspect))
	material.set_shader_parameter("facing",facing)
	material.set_shader_parameter("brightness",_brightness)
	material.set_shader_parameter("opacity",_opacity)
	return material

func _sprite(texture: Texture2D, facing: int, size: float, aspect: float) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	node.mesh=QuadMesh.new()
	node.mesh.size=Vector2.ONE
	node.material_override=_sprite_material(texture,facing,size,aspect)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin=maxf(1,maxf(size,size/maxf(.25,aspect)))
	node.visible=false
	add_child(node)
	return node

func _trail(s: Dictionary) -> MeshInstance3D:
	var mesh:=ArrayMesh.new()
	var arrays: Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var uv:=PackedVector2Array()
	var indices:=PackedInt32Array()
	vertices.resize(capacity*2)
	colors.resize(capacity*2)
	uv.resize(capacity*2)
	for i in capacity:
		for side in 2:
			vertices[i*2+side]=Vector3(i*.001,side*.001,0)
			colors[i*2+side]=Color(1,.5,.5,1)
			uv[i*2+side]=Vector2(i/float(capacity-1),side)
		if i<capacity-1:
			indices.append_array(PackedInt32Array([i*2,i*2+1,i*2+2,i*2+1,i*2+3,i*2+2]))
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
	var format: int=mesh.surface_get_format(0)
	s.buffers=Buffers.new(format,capacity*2)
	var mat:=ShaderMaterial.new()
	mat.shader=TRAIL_SHADER
	for pair in [["dark_color",0],["mid_color",1],["light_color",2],["hot_color",3]]:
		mat.set_shader_parameter(pair[0],head_art.palette[pair[1]])
	for pair in [["width",config.trail_width*appearance],["head_width",config.trail_head_width],["tip_width",config.trail_tip_width],["taper",config.trail_taper],["density",config.pixel_density/appearance],["color_mix",config.trail_color_mix],["turbulence",config.turbulence*appearance],["trail_style",config.trail_style],["brightness",_brightness]]:
		mat.set_shader_parameter(pair[0],pair[1])
	mat.set_shader_parameter("head_element",config.head_style)
	mat.set_shader_parameter("ornament",clampf(config.magic_ornament,0,1))
	mat.set_shader_parameter("orbit_speed",clampf(config.orbit_speed,0,3))
	var node:=MeshInstance3D.new()
	node.mesh=mesh
	node.material_override=mat
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible=false
	add_child(node)
	return node

func cancel(at_time: float) -> void:
	stopped=true
	for s in states:
		if not s.ended:
			s.cancelled=true
			s.ended=true
			s.end_time=at_time
	events.clear()

func _target_sample(at_time: float, index: int) -> Dictionary:
	if index<samples.size():
		_target_last=samples[index].position
		_target_valid=samples[index].valid
		_target_known=true
		return samples[index]
	# A scrub can replay history, but never invent a real target's future.
	if replay and target!=null: return {"valid":false,"position":_target_last}
	var point: Vector3
	var valid: bool=true
	if target_sampler.is_valid():
		point=target_sampler.call(at_time)
	elif target!=null or binding_required:
		var node: Node3D=target.get_ref() as Node3D if target!=null else null
		valid=is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()
		if valid: point=node.to_global(target_offset)
	else:
		point=_fixed_end
	valid=valid and point.is_finite()
	if target!=null or target_sampler.is_valid():
		if _target_known and point.distance_to(_target_last)>maxf(.1,config.teleport_threshold): valid=false
		valid=valid and _target_valid
	_target_known=true
	_target_valid=valid
	_target_last=point
	var value: Dictionary={"valid":valid,"position":point}
	samples.append(value)
	return value

func sync(at_time: float, seeking: bool=false) -> void:
	var began: int=Time.get_ticks_usec()
	replay=seeking
	var wanted: int=int(floor((clampf(at_time,0,config.total_seconds())+.000001)/STEP))
	while tick<wanted:
		tick+=1
		clock=tick*STEP
		_simulate(clock,seeking)
	_render(maxf(0,at_time))
	cpu_usec=Time.get_ticks_usec()-began
	peak_usec=maxi(peak_usec,cpu_usec)

func _simulate(t: float, seeking: bool) -> void:
	var sample: Dictionary=_target_sample(t,tick)
	for s in states:
		if s.ended or t+.000001<float(s.launch): continue
		if not sample.valid:
			s.ended=true
			s.cancelled=true
			s.end_time=t
			continue
		if not s.launched:
			var start: Vector3=source_samples.get(s.index,source.to_global(config.start))
			if not start.is_finite():
				s.ended=true
				s.cancelled=true
				s.end_time=t
				continue
			source_samples[s.index]=start
			s.launched=true
			s.position=start
			s.end=sample.position
			s.zero_distance=start.is_equal_approx(s.end)
			s.path=Path.build(config,start,s.end,seed+s.index*7919)
			s.velocity=(Path.sample(s.path,.001)-start).normalized()*float(s.path.length)/config.flight_seconds()
			s.history=PackedVector3Array([start-_head_direction(s.velocity)*config.head_size*appearance*_tail_root()])
		var elapsed: float=t-float(s.launch)
		var duration: float=config.flight_seconds()
		var u: float=clampf(elapsed/duration,0,1)
		var previous: Vector3=s.position
		if target!=null or target_sampler.is_valid():
			if not s.end.is_equal_approx(sample.position):
				var remaining: float=maxf(STEP,duration-elapsed+STEP)
				s.guide_time=maxf(0,elapsed-STEP)
				s.p0=previous
				s.p1=previous+s.velocity*remaining/3
				var toward: Vector3=(sample.position-previous).normalized()
				s.p2=sample.position-toward*previous.distance_to(sample.position)/3
				s.end=sample.position
		if float(s.guide_time)>=0:
			var g: float=clampf((elapsed-float(s.guide_time))/maxf(STEP,duration-float(s.guide_time)),0,1)
			s.position=s.p0.bezier_interpolate(s.p1,s.p2,s.end,g)
		else:
			s.position=Path.sample(s.path,Path.progress(u,config.progress))
		if u>=1 or s.zero_distance or float(s.path.length)<.00001:
			s.position=sample.position if target!=null or target_sampler.is_valid() else s.end
			s.ended=true
			s.end_time=t
			if not seeking:
				events.append({"index":s.index,"position":s.position})
		var move: Vector3=s.position-previous
		if move.length_squared()>.00000001: s.velocity=move/STEP
		if s.zero_distance: s.history=PackedVector3Array()
		else: _append_history(s,s.position-_head_direction(s.velocity)*config.head_size*appearance*_tail_root())

func _append_history(s: Dictionary, point: Vector3) -> void:
	var h: PackedVector3Array=s.history
	if h.is_empty() or h[-1].distance_squared_to(point)>.00000001: h.append(point)
	var remaining: float=maxf(0,config.trail_length)
	var first: int=h.size()-1
	while first>0:
		var segment: float=h[first].distance_to(h[first-1])
		if segment>=remaining:
			h[first-1]=h[first].lerp(h[first-1],remaining/maxf(.000001,segment))
			first-=1
			break
		remaining-=segment
		first-=1
	if first>0: h=h.slice(first)
	if h.size()>capacity-1:
		# Remove the least curved interior sample, retaining both ends and world history.
		# This bounds memory without chopping a slow projectile's trail short.
		var best: int=1
		var error: float=INF
		for i in range(1,h.size()-1):
			var e: float=h[i-1].distance_to(h[i])+h[i].distance_to(h[i+1])-h[i-1].distance_to(h[i+1])
			if e<error: error=e; best=i
		h.remove_at(best)
	s.history=h

func _render(t: float) -> void:
	var frame: int=int(t*24)
	var animate_head: bool=config.head_style==Config.Head.SWORD
	if not animate_head:
		for s in states:
			if s.launched and (not s.ended or t-float(s.end_time)<(.08 if s.cancelled else config.head_dissolve)):
				animate_head=true; break
	if animate_head and frame!=_head_frame:
		_head_frame=frame
		head_art.head(config.head_style,frame/24.0,config.deformation,config.halo)
		head_texture.update(head_art.image)
	for s in states:
		var tail_age: float=maxf(0,t-float(s.end_time)) if s.ended else 0
		var head_duration: float=.08 if s.cancelled else clampf(config.head_dissolve,0,.4)
		var dissolving: bool=s.ended and head_duration>0 and tail_age<head_duration and not s.get("zero_distance",false)
		s.head.visible=s.launched and (not s.ended or dissolving)
		var head_progress: float=clampf(tail_age/maxf(.001,head_duration),0,1) if s.ended else 0
		if s.ended:
			s.head.material_override.set_shader_parameter("dissolve",head_progress if not s.cancelled else 0.0)
			s.head.material_override.set_shader_parameter("contact",(1.0-head_progress)*.7 if dissolving and not s.cancelled else 0.0)
			s.head.material_override.set_shader_parameter("opacity",_opacity*(1.0-head_progress) if s.cancelled else _opacity)
		var direction: Vector3=_head_direction(s.velocity)
		s.head.position=s.position-direction*config.head_size*appearance*.44
		s.head.material_override.set_shader_parameter("direction",direction)
		var release_duration: float=maxf(head_duration,clampf(config.trail_fade,.05,2))
		var release: float=clampf(tail_age/release_duration,0,1) if s.ended else 0
		var fade: float=1-release
		_draw_trail(s,release,t)
		# Submit the transparent shard pass during flight too. Its first GPU use must
		# not occur at arrival (some Compatibility drivers compile lazily here).
		s.shards.visible=s.launched and not s.cancelled and not s.get("zero_distance",false) and config.head_dissolve>0 and (not s.ended or tail_age<release_duration)
		if s.shards.visible:
			s.shards.position=s.position
			s.shards.multimesh.mesh.material.set_shader_parameter("direction",direction)
			s.shards.multimesh.mesh.material.set_shader_parameter("age",tail_age if s.ended else -1.0)
		s.impact.visible=s.ended and s.launched and not s.cancelled and config.impact_enabled and tail_age<config.impact_duration
		if s.gpu_impact:
			s.impact.material_override.set_shader_parameter("progress",tail_age/maxf(.05,config.impact_duration) if s.impact.visible else -1.0)
			s.impact_fragments.visible=s.launched and not s.cancelled and config.impact_enabled and (not s.ended or tail_age<config.impact_duration)
			s.impact_fragments.position=s.position
			s.impact_fragments.multimesh.mesh.material.set_shader_parameter("age",tail_age if s.ended and not s.cancelled else -1.0)
			s.impact_fragments.multimesh.mesh.material.set_shader_parameter("direction",direction)
		elif s.impact.visible:
			var impact_frame: int=int(tail_age*30)
			if impact_frame!=s.impact_frame:
				s.impact_frame=impact_frame
				s.impact_art.impact(tail_age/maxf(.05,config.impact_duration),config.impact_style,_impact_fragments,seed+s.index*7919)
				s.impact_texture.update(s.impact_art.image)
		s.impact.position=s.position
		s.impact.material_override.set_shader_parameter("direction",s.velocity.normalized() if s.velocity.length_squared()>.000001 else Vector3.RIGHT)
		if s.ornaments!=null:
			s.ornaments.visible=s.launched and config.magic_ornament>0 and (not s.ended or tail_age<release_duration) and not s.get("zero_distance",false)
			s.ornaments.position=s.head.position
			var ornament_material: ShaderMaterial=s.ornaments.material_override
			ornament_material.set_shader_parameter("direction",direction)
			ornament_material.set_shader_parameter("effect_time",t)
			ornament_material.set_shader_parameter("release",head_progress if s.cancelled else release)

		var mm: MultiMesh=s.motes.multimesh
		mm.visible_instance_count=_mote_count if s.launched and fade>.01 and s.history.size()>1 else 0
		for j in mm.visible_instance_count:
			var mote_time: float=float(s.end_time) if s.ended else t
			var phase: float=fposmod(mote_time*1.3+Path.noise(seed+s.index,100+j),1)
			var h: PackedVector3Array=s.history
			var location: Vector3=h[clampi(int((1-phase)*(h.size()-1)),0,h.size()-1)]
			location+=Vector3(sin(j*2.4+t*2),sin(j*3.1+t*1.4),cos(j*1.7+t*2))*phase*.09*appearance
			s.mote_positions[j]=location
			mm.set_instance_transform(j,Transform3D(Basis.IDENTITY,location))
		mm.mesh.material.set_shader_parameter("opacity",fade*_opacity)

func _draw_trail(s: Dictionary, release: float, t: float) -> void:
	var h: PackedVector3Array=s.history
	s.trail.visible=h.size()>1 and release<1 and config.trail_length>0
	if not s.trail.visible: return
	var material: ShaderMaterial=s.trail.material_override
	if not s.trail_frozen:
		var history_length: float=0
		for i in range(1,h.size()): history_length+=h[i].distance_to(h[i-1])
		# One reserved vertex pair joins the hilt to the tip. It is visible under the
		# eroding blade, so neither arrival nor a short head duration exposes a gap.
		var total: float=history_length+h[-1].distance_to(s.position)
		var distance: float=0
		var buffers: RefCounted=s.buffers
		var bounds:=AABB(h[0],Vector3.ZERO)
		for i in capacity:
			var n: int=mini(i,h.size())
			var point: Vector3=h[n] if n<h.size() else s.position
			var previous: Vector3=h[maxi(0,n-1)]
			var next: Vector3=h[n+1] if n+1<h.size() else s.position
			if i>0 and i<=h.size(): distance+=point.distance_to(previous)
			var direction: Vector3=(next-previous).normalized()
			if direction.length_squared()<.5: direction=_head_direction(s.velocity)
			bounds=bounds.expand(point)
			for side in 2:
				buffers.write(i*2+side,point,direction,distance/maxf(.000001,total),float(side))
		var mesh: ArrayMesh=s.trail.mesh
		buffers.upload(mesh)
		mesh.custom_aabb=bounds.grow((config.trail_width*2+config.turbulence*2)*appearance+.05)
		material.set_shader_parameter("trail_length",total)
		material.set_shader_parameter("body_start",history_length/maxf(.000001,total))
		material.set_shader_parameter("neck_width",minf(config.trail_width*config.trail_head_width,config.head_size*float([.042,.18,.065,.09][clampi(config.head_style,0,3)])/maxf(.25,config.head_aspect))*appearance)
		s.trail_uploads+=1
		s.trail_frozen=s.ended
	material.set_shader_parameter("release",release)
	material.set_shader_parameter("opacity",_opacity)
	material.set_shader_parameter("effect_time",minf(t,float(s.end_time)) if s.ended else t)

func history_record() -> Dictionary:
	return {"targets":samples.duplicate(true),"sources":source_samples.duplicate(true),"fixed_end":_fixed_end,"real_target":binding_required and not target_sampler.is_valid()}

func restore_record(record: Dictionary) -> void:
	samples.assign(record.get("targets",[]))
	source_samples=record.get("sources",{}).duplicate(true)
	_fixed_end=record.get("fixed_end",_fixed_end)

func metrics() -> Dictionary:
	var bytes: int=0
	var pixel_bytes: int=head_art.size*head_art.size*4
	for s in states:
		bytes+=s.buffers.byte_count()+capacity*12+_mote_count*12+_shard_count*80
		if s.gpu_impact: bytes+=_impact_fragments*80
		else: pixel_bytes+=head_art.size*head_art.size*4
	return {"projectiles":states.size(),"trail_capacity":capacity,"buffer_bytes":bytes,"cpu_usec":cpu_usec,"peak_usec":peak_usec,"target_samples":samples.size(),"nodes":get_child_count(),"pixel_bytes":pixel_bytes}

func ended_at() -> float:
	var end: float=0
	for s in states:
		if not s.ended: return -1
		if s.launched:
			end=maxf(end,float(s.end_time)+(maxf(.08,config.trail_fade) if s.cancelled else config.tail_seconds()))
	return end
