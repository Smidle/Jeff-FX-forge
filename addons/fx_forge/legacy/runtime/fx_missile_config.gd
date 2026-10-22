@tool
class_name JeffForge3DMissileConfig
extends Resource
## Appearance/path recipe only. Scene target references belong to JeffForge3DInstance.
enum PathMode { STRAIGHT, ARC, S_CURVE, HELIX, RANDOM_ARC, CUSTOM }
enum Progress { LINEAR, EASE_IN, EASE_OUT, SMOOTH }
enum Head { SWORD, FIREBALL, ICE_ARROW, SHADOW_ARROW }
enum Trail { RIBBON, THREAD, MOTES, FLAME, FROST, SHADOW }
enum Impact { SPARK, WAVE, STAR, FLAME, ICE, SHADOW }
@export var start: Vector3 = Vector3(-2,1,0)
@export var end: Vector3 = Vector3(2,1,0)
@export_range(1,16,1) var projectile_count: int = 1
@export_range(0,1,.01) var launch_interval: float = .08
@export_range(.1,10,.05) var flight_time: float = .8
@export var path_mode: PathMode = PathMode.ARC
@export var progress: Progress = Progress.LINEAR
@export_range(-5,5,.05) var arc_height: float = .65
@export_range(-5,5,.05) var side_offset: float = 0
@export_range(0,4,.05) var random_spread: float = .45
@export_range(.25,6,.25) var helix_turns: float = 1.5
@export var custom_curve: Curve3D
@export_range(.1,100,.1) var teleport_threshold: float = 5
## Zero remains the approved sword, including all existing saved recipes.
@export var head_style: Head = Head.SWORD
@export_range(.1,2,.01) var head_size: float = .85
@export_range(.25,3,.05) var head_aspect: float = 1
@export_range(-180,180,1) var head_rotation: float = 0
@export_range(0,1,.05) var deformation: float = .25
@export_range(0,2,.05) var saturation: float = 1
@export_range(0,1,.05) var halo: float = .12
@export_range(16,128,8) var pixel_density: int = 64
## Optional procedural orbit ribbons and glyphs. Legacy recipes remain undecorated.
@export_range(0,1,.05) var magic_ornament: float = 0
@export_range(0,3,.05) var orbit_speed: float = 1
@export var trail_style: Trail = Trail.RIBBON
@export_range(0,10,.05) var trail_length: float = 1.4
@export_range(.01,1,.01) var trail_width: float = .10
@export_range(.05,2,.05) var trail_head_width: float = 1
@export_range(0,1,.05) var trail_tip_width: float = 0
@export_range(.2,4,.1) var trail_taper: float = .8
@export_range(0,1,.05) var trail_color_mix: float = .7
@export_range(0,.5,.01) var turbulence: float = .025
@export_range(0,24,1) var motes: int = 8
## Tail drains toward contact; the joined spine lasts at least head_dissolve.
@export_range(.05,2,.05) var trail_fade: float = .35
@export var impact_enabled: bool = true
## Hilt-to-tip pixel conversion, not uniform alpha fade. Zero skips steel recovery.
@export_range(0,.4,.01) var head_dissolve: float = .16
@export var impact_style: Impact = Impact.STAR
@export_range(.1,3,.05) var impact_size: float = .8
@export_range(.05,2,.05) var impact_duration: float = .35
@export_range(0,24,1) var impact_fragments: int = 10
@export_enum("朝向镜头 / Camera","固定地面 / Ground","沿入射方向 / Incoming") var impact_facing: int = 0

func copy() -> JeffForge3DMissileConfig:
	var result := duplicate(false) as JeffForge3DMissileConfig
	if custom_curve != null:
		result.custom_curve = custom_curve.duplicate(true)
	return result

func flight_seconds() -> float:
	return clampf(flight_time,.1,10)

func tail_seconds() -> float:
	return maxf(maxf(clampf(trail_fade,.05,2),clampf(head_dissolve,0,.4)),clampf(impact_duration,.05,2) if impact_enabled else 0)

func total_seconds() -> float:
	return flight_seconds()+clampf(launch_interval,0,1)*(clampi(projectile_count,1,16)-1)+tail_seconds()
