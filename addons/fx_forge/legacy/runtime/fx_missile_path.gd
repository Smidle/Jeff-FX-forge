@tool
extends RefCounted
const Config=preload("res://addons/fx_forge/legacy/runtime/fx_missile_config.gd")

static func noise(seed: int, index: int) -> float:
	return fposmod(sin(float(posmod(seed,1000003)+index*1973)*.1271)*43758.5453,1)

static func frame(start: Vector3, end: Vector3) -> Basis:
	var x: Vector3=(end-start).normalized()
	if x.length_squared()<.5:
		x=Vector3.RIGHT
	var up: Vector3=Vector3.BACK if absf(x.dot(Vector3.UP))>.98 else Vector3.UP
	var z: Vector3=x.cross(up).normalized()
	return Basis(x,z.cross(x).normalized(),z)

static func offset(c: Resource, u: float, seed: int) -> Vector3:
	if u<=0: return Vector3.ZERO
	if u>=1: return Vector3.RIGHT
	var envelope: float=sin(u*PI)
	var y: float=0
	var z: float=clampf(c.side_offset,-5,5)*envelope
	match c.path_mode:
		Config.PathMode.ARC:
			y=4*u*(1-u)*clampf(c.arc_height,-5,5)
		Config.PathMode.S_CURVE:
			y=envelope*clampf(c.arc_height,-5,5)*.35
			z+=sin(u*TAU)*clampf(c.random_spread,0,4)
		Config.PathMode.HELIX:
			var a: float=u*TAU*clampf(c.helix_turns,.25,6)
			y=envelope*(clampf(c.arc_height,-5,5)+sin(a)*clampf(c.random_spread,0,4))
			z+=envelope*cos(a)*clampf(c.random_spread,0,4)
		Config.PathMode.RANDOM_ARC:
			y=envelope*(clampf(c.arc_height,-5,5)+clampf(c.random_spread,0,4)*(noise(seed,1)*2-1+sin(u*TAU+noise(seed,3)*TAU)*.5))
			z+=envelope*clampf(c.random_spread,0,4)*(noise(seed,2)*2-1+sin(u*PI+noise(seed,4)*TAU)*.6)
		Config.PathMode.CUSTOM:
			if c.custom_curve!=null and c.custom_curve.point_count>=2:
				return c.custom_curve.sample_baked(u*c.custom_curve.get_baked_length(),true)
	return Vector3(u,y,z)

static func world_point(c: Resource, u: float, start: Vector3, end: Vector3, seed: int) -> Vector3:
	if start.is_equal_approx(end): return start
	var p: Vector3=offset(c,u,seed)
	var basis: Basis=frame(start,end)
	return start+(end-start)*p.x+basis.y*p.y+basis.z*p.z

static func build(c: Resource, start: Vector3, end: Vector3, seed: int) -> Dictionary:
	var points:=PackedVector3Array()
	var distances:=PackedFloat32Array()
	var length: float=0
	for i in 129:
		var point: Vector3=world_point(c,i/128.0,start,end,seed)
		if i>0: length+=point.distance_to(points[-1])
		points.append(point)
		distances.append(length)
	return {"points":points,"distances":distances,"length":length}

static func progress(u: float, mode: int) -> float:
	u=clampf(u,0,1)
	match mode:
		Config.Progress.EASE_IN: return u*u
		Config.Progress.EASE_OUT: return 1-(1-u)*(1-u)
		Config.Progress.SMOOTH: return u*u*(3-2*u)
	return u

static func sample(path: Dictionary, fraction: float) -> Vector3:
	var points: PackedVector3Array=path.points
	var distances: PackedFloat32Array=path.distances
	var target: float=clampf(fraction,0,1)*float(path.length)
	var lo: int=0
	var hi: int=points.size()-1
	while hi-lo>1:
		var mid: int=(lo+hi)/2
		if distances[mid]<target: lo=mid
		else: hi=mid
	return points[lo].lerp(points[hi],clampf((target-distances[lo])/maxf(.000001,distances[hi]-distances[lo]),0,1))

static func editable(c: Resource, seed: int) -> Curve3D:
	var curve:=Curve3D.new()
	curve.bake_interval=.015
	for i in 9:
		var u: float=i/8.0
		var p: Vector3=offset(c,u,seed)
		var tangent: Vector3=(offset(c,minf(1,u+.002),seed)-offset(c,maxf(0,u-.002),seed))/maxf(.002,minf(1,u+.002)-maxf(0,u-.002))/24
		curve.add_point(p,-tangent if i>0 else Vector3.ZERO,tangent if i<8 else Vector3.ZERO)
	return curve
