@tool
class_name JeffForge3DLayer
extends Resource
## A reusable visual layer. All distances are in Godot world units.

enum Kind { PARTICLES, SHAPE, FIELD, PROCEDURAL, MISSILE }
enum Facing { CAMERA, GROUND, DIRECTION }
enum FieldMotion { RAIN, RIPPLE, FIREFLY, FIREFLY_GLOW, FIREFLY_MOTES }
enum ProceduralMotion { STREAK, ARC, FLAME, RETURN_BLADE, GROUND_WAVE, SWORD_ARRAY, SPIRIT_BUTTERFLY, ICE_CAGE, VOID_VORTEX }
## Appended options are opt-in. LEGACY keeps every existing recipe's shader.
enum MaterialMode { LEGACY, PIXEL, SMOOTH }
enum Pattern { TEXTURE, SPIRIT_SPRING, CHARGE_LASER, FLAME_SIGIL, STAR_BOUNCE, INK_LOTUS, STONE_DUST, CRYSTAL_SPIKES, PORTAL_TILES, AEGIS_SHELL, BUBBLE_SHOT, BRUSH_PRISON, METAL_SPARKS }

@export var label: String = "Layer"
@export var kind: Kind = Kind.PARTICLES
@export var missile: JeffForge3DMissileConfig
@export var enabled: bool = true
@export var decorative: bool = false
@export var delay: float = 0.0
@export var duration: float = 0.5
@export var color: Color = Color.WHITE
@export var secondary: bool = false
@export var use_palette_tint: bool = true
## Colored pixel art keeps its original shade ramp while following the preset hue.
@export var palette_hue_shift: bool = false
@export var palette_reference: Color = Color.WHITE
@export_range(-128, 127, 1) var sort_priority: int = 0
## A legacy texture basename or a complete res:// path. Full paths permit
## self-contained authored packs without copying assets into the legacy folder.
@export var texture_name: String = "spark"
@export var material_mode: MaterialMode = MaterialMode.LEGACY
## Analytic GPU patterns are intended for SHAPE layers; no image redraw is needed.
@export var pattern: Pattern = Pattern.TEXTURE
## Zero columns derives the layout from frames/rows (the old horizontal strip
## when rows=1). Explicit columns allow an incomplete final row.
@export_range(0, 32, 1) var atlas_columns: int = 0
@export_range(1, 32, 1) var atlas_rows: int = 1
@export_range(1, 16, 1) var pattern_count: int = 6
@export_range(0.0, 1.0, 0.05) var pattern_detail: float = 0.65
@export_range(0.1, 3.0, 0.05) var pattern_motion: float = 1.0
@export_range(0.1, 1.0, 0.05) var pattern_width: float = 0.5
@export_range(0.0, 1.0, 0.05) var pattern_variation: float = 0.4
@export_range(0.0, 1.0, 0.05) var pattern_phase: float = 0.0
@export var atlas_frames: int = 1
@export var animation_fps: float = 12.0
@export var animation_loop: bool = false
@export var aspect: Vector2 = Vector2.ONE
@export var fade_in: float = 0.04
@export var fade_out: float = 0.2
@export var pulse: float = 0.0
@export var pulse_speed: float = 2.0
@export_range(1, 12, 1) var repeat_count: int = 1
@export var repeat_delay: float = 0.12
@export var repeat_spacing: Vector3 = Vector3.ZERO
@export_range(30, 360, 5) var arc_degrees: float = 360.0
@export_range(-1, 2, 1) var branch_count: int = -1
@export_range(-1, 6, 1) var motif_count: int = -1
@export var field_motion: FieldMotion = FieldMotion.RAIN
## A dependent field reads movement/count/seed from this layer (rain → ripple, insect → halo).
@export var motion_source: int = -1
@export_range(1, 4, 1) var satellite_count: int = 2
@export var satellite_radius: float = 0.22
@export var satellite_speed: float = 1.4
@export var motion_speed: float = 1.0
@export var wander: float = 0.3
## Zero preserves the original path. Higher values add smooth, per-insect variation.
@export_range(0.0, 1.0, 0.05) var flight_variation: float = 0.0
@export var blink_speed: float = 2.0
@export var fall_height: float = 4.0
@export var ripple_duration: float = 0.65
@export var wind: Vector3 = Vector3.ZERO
@export var facing: Facing = Facing.CAMERA
@export var align_to_motion: bool = false
@export var offset: Vector3 = Vector3.ZERO
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export var size: float = 1.0
@export var end_size: float = 0.0
@export var spin: float = 0.0
@export var additive: bool = false
@export var hard_edge: bool = true
@export var opacity: float = 1.0
@export var count: int = 24
@export var lifetime: float = 0.7
@export var continuous: bool = false
@export var explosiveness: float = 1.0
@export var direction: Vector3 = Vector3.UP
@export var spread: float = 45.0
@export var velocity_min: float = 0.5
@export var velocity_max: float = 2.0
@export var gravity: Vector3 = Vector3.ZERO
@export var emission_box: Vector3 = Vector3.ZERO
@export var local_space: bool = false

## Runtime pixel drawing; independent of texture_name and atlas_frames.
@export var procedural_motion: ProceduralMotion = ProceduralMotion.STREAK
## Local endpoints before the preset's overall scale and the layer offset.
## All strands share both anchors; random control points vanish at each endpoint.
@export var path_start: Vector3 = Vector3(-1.2, 1.0, 0.0)
@export var path_end: Vector3 = Vector3(1.2, 1.0, 0.0)
@export_range(0.01, 0.5, 0.01) var strike_time: float = 0.1
@export var impact_enabled: bool = true
@export_range(0.05, 3.0, 0.05) var impact_radius: float = 0.9
@export_range(0.05, 2.0, 0.05) var impact_duration: float = 0.55
@export_range(0, 24, 1) var impact_sparks: int = 12
@export_range(32, 128, 8) var pixel_resolution: int = 96
@export_range(1, 6, 1) var stroke_width: int = 3
@export_range(4, 32, 1) var path_segments: int = 18
@export_range(1, 8, 1) var strand_count: int = 4
@export_range(0.1, 1.0, 0.05) var trail_length: float = 0.45
@export_range(-1.0, 1.0, 0.05) var curvature: float = 0.35
@export_range(0.0, 0.35, 0.01) var path_jitter: float = 0.12
@export_range(0, 4, 1) var arc_branches: int = 2
@export_range(6, 30, 1) var redraw_fps: int = 24
@export_range(0.4, 1.1, 0.05) var flame_height: float = 0.9
@export_range(0.15, 0.65, 0.05) var flame_width: float = 0.48
@export_range(-1.0, 1.0, 0.05) var flame_lean: float = 0.0
@export_range(0.0, 1.0, 0.05) var flame_turbulence: float = 0.65
@export_range(0.2, 3.0, 0.1) var flame_speed: float = 1.0
@export_range(0.25, 0.8, 0.05) var flame_core: float = 0.6
@export_range(1, 5, 1) var flame_tongues: int = 3
@export_range(0, 8, 1) var flame_embers: int = 2

## Procedural skill controls. These do not alter two-point streak/arc behavior.
@export_range(1, 16, 1) var skill_count: int = 5
@export_range(0.2, 1.0, 0.05) var skill_spread: float = 0.8
@export_range(0.25, 4.0, 0.05) var skill_turns: float = 1.0
@export_range(0.0, 1.0, 0.05) var skill_detail: float = 0.6

func tail_time() -> float:
	if kind == Kind.MISSILE:
		return missile.total_seconds() if missile != null else 1.15
	if kind in [Kind.SHAPE, Kind.PROCEDURAL]:
		return duration + (maxi(1, repeat_count) - 1) * repeat_delay
	if kind == Kind.FIELD:
		return fall_height / maxf(motion_speed, 0.1) + ripple_duration if field_motion in [FieldMotion.RAIN, FieldMotion.RIPPLE] else fade_out
	return lifetime * (2.0 - explosiveness) if not continuous else lifetime

## Analytic patterns reuse a compact control surface with motif-specific meaning.
## Editor callers can use this contract without duplicating shader assumptions.
static func pattern_parameter_specs(pattern_id: int) -> Dictionary:
	var subjects: Array = []
	match pattern_id:
		Pattern.SPIRIT_SPRING: subjects = ["上升水珠", "灵光与泉环", "泉流粗细", "升腾摆幅"]
		Pattern.CHARGE_LASER: subjects = ["蓄力光点", "光点与双侧导轨", "光束宽度", "电流扰动"]
		Pattern.FLAME_SIGIL: subjects = ["焰瓣与断环", "内环与余烬", "焰瓣宽度", "焰瓣卷曲"]
		Pattern.STAR_BOUNCE: subjects = ["落点小星", "星尾与落点小星", "主星尺寸", "星体旋转"]
		Pattern.INK_LOTUS: subjects = ["荷瓣", "叶脉与墨点", "荷瓣宽度", "墨色边缘变化"]
		Pattern.STONE_DUST: subjects = ["沉降石屑", "柔尘浓度", "尘团扩散", "石屑散布"]
		Pattern.CRYSTAL_SPIKES: subjects = ["晶脊", "晶纹与地裂", "晶脊粗细", "晶脊高低"]
		Pattern.PORTAL_TILES: subjects = ["升起方片", "导光与薄边", "方片尺寸", "方片错拍"]
		Pattern.AEGIS_SHELL: subjects = ["护壳流纹", "流纹与亮点", "护壳弧厚", "流纹错位"]
		Pattern.BUBBLE_SHOT: subjects = ["前进泡泡", "泡面高光", "泡泡大小", "泡泡起伏"]
		Pattern.BRUSH_PRISON: subjects = ["竖向墨竹", "竹节与散墨", "笔画宽度", "竹笔高低"]
		Pattern.METAL_SPARKS: subjects = ["金属火星", "亮芯与短余烬", "火星粗细", "弹道散角"]
		_: return {}
	var late_note := ""
	if pattern_id == Pattern.CHARGE_LASER: late_note = "只在前 42% 的蓄力阶段显示。"
	if pattern_id == Pattern.STAR_BOUNCE: late_note = "只在落点弹开时显示，细节为零时关闭。"
	if pattern_id == Pattern.AEGIS_SHELL: late_note = "细节为零时关闭，主护壳保留。"
	return {
		"pattern_count": {"label": subjects[0] + "数量", "tip": late_note + "整体密度和质量档会按比例减少数量，上限 16。", "group": "main"},
		"pattern_detail": {"label": subjects[1], "tip": "控制次要层强度；设为零仍保留主要造型。", "group": "advanced"},
		"pattern_motion": {"label": "内部运动速度", "tip": "推进当前造型内部动画，不改变实例的持续时间。一次性动画加速后会提前完成内部阶段。", "group": "motion"},
		"pattern_width": {"label": subjects[2], "tip": "改变造型内部轮廓，不改变图层的世界尺寸。", "group": "main"},
		"pattern_variation": {"label": subjects[3], "tip": "固定种子下调节差异幅度；不会在每一帧重新抽样。", "group": "motion"},
		"pattern_phase": {"label": "起始相位", "tip": "从当前内部动画的指定位置开始，适合错开多个重复图层。", "group": "advanced"},
	}

func library_ignored_parameters() -> PackedStringArray:
	var result := PackedStringArray()
	if pattern != Pattern.TEXTURE:
		result.append_array(PackedStringArray(["texture_name", "atlas_columns", "atlas_rows", "atlas_frames", "animation_fps", "animation_loop", "branch_count", "motif_count", "palette_hue_shift", "palette_reference"]))
		if material_mode != MaterialMode.PIXEL: result.append("pixel_resolution")
		if pattern_detail <= 0.0 and pattern in [Pattern.CHARGE_LASER, Pattern.STAR_BOUNCE, Pattern.AEGIS_SHELL]: result.append("pattern_count")
		if pattern_detail <= 0.0 and pattern == Pattern.AEGIS_SHELL:
			result.append_array(PackedStringArray(["pattern_variation", "pattern_motion", "pattern_phase"]))
	if material_mode == MaterialMode.SMOOTH: result.append("hard_edge")
	return result

## Used by global controls: these motifs have no stochastic component when the
## only seeded decoration has been disabled. No resource values are erased.
func uses_pattern_seed() -> bool:
	match pattern:
		Pattern.TEXTURE: return false
		Pattern.CHARGE_LASER, Pattern.AEGIS_SHELL: return pattern_detail > 0.0 and pattern_variation > 0.0
		_: return true
