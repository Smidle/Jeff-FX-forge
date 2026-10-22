@tool
extends RefCounted
const P := preload("../core/fx_params.gd")
const Visibility := preload("classic_visibility.gd")
const Layer := preload("../legacy/runtime/fx_layer.gd")
const LABELS := {
	"primary_color": "主色", "secondary_color": "辅色", "effect_scale": "整体大小", "playback_speed": "播放速度", "density": "密度", "brightness": "亮度", "seed": "随机种子", "duration": "持续时间", "looping": "持续发射",
	"enabled": "启用图层", "decorative": "装饰层", "delay": "延迟", "color": "图层颜色", "secondary": "使用辅色", "use_palette_tint": "跟随配色", "palette_hue_shift": "保留色阶", "sort_priority": "排序优先级",
	"animation_fps": "动画帧率", "animation_loop": "动画循环", "aspect": "长宽比", "fade_in": "淡入", "fade_out": "消散", "pulse": "脉动幅度", "pulse_speed": "脉动速度", "repeat_count": "重复数量", "repeat_delay": "重复间隔", "repeat_spacing": "重复间距", "arc_degrees": "弧度", "branch_count": "分支数量", "motif_count": "装饰数量",
	"satellite_count": "伴随光点数", "satellite_radius": "伴随半径", "satellite_speed": "伴随速度", "motion_speed": "运动速度", "wander": "游动范围", "flight_variation": "飞行变化", "blink_speed": "闪烁速度", "fall_height": "下落高度", "ripple_duration": "涟漪时长", "wind": "风向", "facing": "空间朝向", "align_to_motion": "朝向运动方向", "offset": "偏移", "rotation_degrees": "旋转", "size": "尺寸", "end_size": "末端尺寸", "spin": "自转", "additive": "发光叠加", "hard_edge": "硬像素边缘", "opacity": "透明度",
	"count": "粒子容量", "lifetime": "粒子寿命", "continuous": "持续发射", "explosiveness": "爆发程度", "direction": "发射方向", "spread": "散布角", "velocity_min": "最小速度", "velocity_max": "最大速度", "gravity": "重力", "emission_box": "发射范围", "local_space": "跟随发射器",
	"path_start": "起点", "path_end": "终点", "strike_time": "闪击时间", "impact_enabled": "命中效果", "impact_radius": "命中半径", "impact_duration": "命中时长", "impact_sparks": "命中碎光", "pixel_resolution": "像素精度", "stroke_width": "线条宽度", "path_segments": "路径分段", "strand_count": "流光数量", "trail_length": "尾迹长度", "curvature": "弯曲", "path_jitter": "路径随机", "arc_branches": "电弧分叉", "redraw_fps": "绘制帧率",
	"flame_height": "火焰高度", "flame_width": "火焰宽度", "flame_lean": "火焰倾斜", "flame_turbulence": "火焰扰动", "flame_speed": "火焰速度", "flame_core": "火核比例", "flame_tongues": "火舌数量", "flame_embers": "余烬数量", "skill_count": "图案数量", "skill_spread": "图案散布", "skill_turns": "旋转圈数", "skill_detail": "细节强度"
}
const BASIC := ["primary_color", "secondary_color", "effect_scale", "playback_speed", "density", "brightness", "seed", "duration", "looping"]
const SIMPLE := ["enabled", "delay", "duration", "color", "size", "end_size", "opacity", "offset", "rotation_degrees", "fade_in", "fade_out"]
const PARTICLE := ["count", "lifetime", "continuous", "explosiveness", "direction", "spread", "velocity_min", "velocity_max", "gravity", "emission_box", "local_space"]
const FIELD := ["satellite_count", "satellite_radius", "satellite_speed", "motion_speed", "wander", "flight_variation", "blink_speed", "fall_height", "ripple_duration", "wind"]
const PROCEDURAL := ["path_start", "path_end", "strike_time", "impact_enabled", "impact_radius", "impact_duration", "impact_sparks", "pixel_resolution", "stroke_width", "path_segments", "strand_count", "trail_length", "curvature", "path_jitter", "arc_branches", "redraw_fps", "flame_height", "flame_width", "flame_lean", "flame_turbulence", "flame_speed", "flame_core", "flame_tongues", "flame_embers", "skill_count", "skill_spread", "skill_turns", "skill_detail"]
const RANGES := {"effect_scale": [0.1, 4.0], "playback_speed": [0.1, 3.0], "density": [0.05, 3.0], "brightness": [0.0, 4.0], "seed": [0, 100000], "size": [0.01, 12.0], "end_size": [0.0, 12.0], "duration": [0.01, 10.0], "delay": [0.0, 5.0], "count": [1, 256], "lifetime": [0.05, 8.0], "sort_priority": [-128, 127], "opacity": [0.0, 1.0], "explosiveness": [0.0, 1.0], "spread": [0.0, 180.0], "spin": [-720.0, 720.0], "animation_fps": [1, 60], "fade_in": [0.0, 3.0], "fade_out": [0.0, 4.0], "velocity_min": [0, 12], "velocity_max": [0, 12], "branch_count": [-1, 2], "motif_count": [-1, 6]}

## Only expose controls read by the selected runtime branch. Values remain in
## resources for backwards compatibility; hidden fields are never reset.
const IMPORTANT := ["enabled", "primary_color", "secondary_color", "effect_scale", "playback_speed", "density", "brightness", "color", "size", "end_size", "opacity", "count", "motion_speed", "path_start", "path_end", "flame_height", "flame_width", "skill_count"]
const MOTION := ["duration", "delay", "fade_in", "fade_out", "lifetime", "velocity_min", "velocity_max", "spread", "gravity", "direction", "emission_box", "fall_height", "wind", "ripple_duration", "wander", "flight_variation", "blink_speed", "satellite_count", "satellite_radius", "satellite_speed", "strike_time", "impact_enabled", "impact_radius", "impact_duration", "impact_sparks", "strand_count", "trail_length", "curvature", "path_jitter", "arc_branches", "flame_lean", "flame_turbulence", "flame_speed", "flame_core", "flame_tongues", "flame_embers", "skill_spread", "skill_turns", "skill_detail"]
const SPATIAL := ["facing", "offset", "rotation_degrees", "aspect"]

static func allowed(r: Resource, global: bool, recipe: Resource = null) -> Array:
	if global:
		var ids: Array = ["effect_scale", "playback_speed", "brightness"]
		for l: Resource in r.layers:
			if not l.enabled: continue
			if l.use_palette_tint:
				ids.append("secondary_color" if l.secondary else "primary_color")
				if l.kind == Layer.Kind.PROCEDURAL:
					ids.append_array(["primary_color", "secondary_color"])
			if l.kind in [Layer.Kind.PARTICLES, Layer.Kind.FIELD, Layer.Kind.PROCEDURAL]:
				ids.append("seed")
			if l.kind in [Layer.Kind.PARTICLES, Layer.Kind.FIELD] or (l.kind == Layer.Kind.PROCEDURAL and l.procedural_motion != Layer.ProceduralMotion.ARC):
				ids.append("density")
			if l.kind == Layer.Kind.FIELD or (l.kind == Layer.Kind.PARTICLES and l.continuous):
				if not r.looping: ids.append("duration")
		return ids
	var ids: Array = ["enabled", "color", "opacity", "offset", "size", "aspect", "additive", "hard_edge", "sort_priority", "use_palette_tint", "facing"]
	if r.use_palette_tint and r.kind != Layer.Kind.PROCEDURAL:
		ids.append("secondary")
		# Hue shifting is meaningful for authored coloured art only.
		if r.palette_reference.s > .01: ids.append("palette_hue_shift")
	if r.kind == Layer.Kind.PARTICLES:
		ids.append_array(PARTICLE)
		if r.continuous: ids.erase("explosiveness")
		ids.append_array(["delay", "end_size", "spin", "rotation_degrees"])
	elif r.kind == Layer.Kind.FIELD:
		ids.append("rotation_degrees")
		if r.motion_source < 0:
			ids.append_array(["delay", "count", "motion_speed", "emission_box"])
			if r.field_motion == Layer.FieldMotion.RAIN:
				ids.append_array(["fall_height", "ripple_duration", "wind"])
			else:
				ids.append_array(["wander", "flight_variation", "blink_speed", "fade_in", "fade_out"])
		if r.field_motion == Layer.FieldMotion.FIREFLY_MOTES:
			ids.append_array(["satellite_count", "satellite_radius", "satellite_speed"])
	else:
		ids.append_array(["delay", "fade_in", "fade_out", "repeat_count", "spin", "rotation_degrees"])
		if r.repeat_count > 1: ids.append_array(["repeat_delay", "repeat_spacing"])
		if recipe == null or not recipe.looping:
			ids.append_array(["duration", "end_size"])
		else:
			ids.append("pulse")
			if r.pulse > 0: ids.append("pulse_speed")
		if r.kind == Layer.Kind.PROCEDURAL:
			ids.append_array(["duration", "pixel_resolution", "redraw_fps"])
			match r.procedural_motion:
				Layer.ProceduralMotion.STREAK, Layer.ProceduralMotion.ARC:
					ids.append_array(["path_start", "path_end", "stroke_width", "path_segments", "curvature", "path_jitter"])
					for key: String in ["size", "end_size", "aspect", "spin", "rotation_degrees", "facing", "repeat_spacing", "pulse", "pulse_speed"]: ids.erase(key)
					if r.procedural_motion == Layer.ProceduralMotion.STREAK:
						ids.append_array(["strand_count", "trail_length"])
					else:
						ids.append_array(["strike_time", "arc_branches", "impact_enabled"])
						if r.impact_enabled: ids.append_array(["impact_radius", "impact_duration", "impact_sparks"])
				Layer.ProceduralMotion.FLAME:
					if recipe != null and recipe.looping: ids.erase("duration")
					ids.append_array(["flame_height", "flame_width", "flame_lean", "flame_turbulence", "flame_speed", "flame_core", "flame_tongues", "flame_embers"])
				_:
					ids.append_array(["skill_count", "skill_spread", "skill_detail", "stroke_width"])
					if r.procedural_motion not in [Layer.ProceduralMotion.GROUND_WAVE, Layer.ProceduralMotion.ICE_CAGE]: ids.append("skill_turns")
		else:
			ids.append("arc_degrees")
			if r.branch_count >= 0: ids.append("branch_count")
			if r.motif_count >= 0: ids.append("motif_count")
	if r.kind != Layer.Kind.PROCEDURAL and r.atlas_frames > 1:
		if r.kind != Layer.Kind.FIELD or r.field_motion not in [Layer.FieldMotion.RAIN, Layer.FieldMotion.RIPPLE]: ids.append("animation_fps")
		if r.kind != Layer.Kind.FIELD and ((r.lifetime if r.kind == Layer.Kind.PARTICLES else r.duration) * r.animation_fps > r.atlas_frames + .01 or (r.kind == Layer.Kind.SHAPE and recipe != null and recipe.looping)):
			ids.append("animation_loop")
	return ids

const TIPS := {
	"secondary_color": "用于当前效果的辅色图层，例如余烬、碎屑或伴随光点。主图层可能不会随它变色。",
	"facing": "朝向镜头只支持平面内 Z 旋转；固定地面或固定空间可调整 X/Y/Z。",
	"rotation_degrees": "面向镜头的图层只旋转 Z；粒子发射器旋转会改变发射方向和范围。",
	"use_palette_tint": "开启后读取整体主色或辅色；关闭后只用素材原色和图层颜色。默认配色与原图接近时，需先换整体配色才看得到区别。",
	"local_space": "开启后已发出的粒子跟随发射器移动；在静止预览中看不出差异。",
	"fade_out": "一次性效果的尾部消散时间；持续效果需停止发射后观察。",
	"hard_edge": "把半透明边缘量化为少量透明度阶。只有存在半透明像素时才会改变画面。",
	"sort_priority": "影响透明图层重叠时的前后排序，不改变图层自己的造型。",
	"redraw_fps": "程序像素画面每秒更新次数；飞行和效果时钟继续独立运行。",
	"repeat_count": "重复图层，配合重复间隔与间距使用。",
}

static func group(id: String) -> String:
	var base := id.get_slice(".", 0)
	return "main" if IMPORTANT.has(base) else "motion" if MOTION.has(base) else "space" if SPATIAL.has(base) else "advanced"

static func defs(resource: Resource, advanced: bool, global: bool, recipe: Resource = null, defaults: Resource = null) -> Array:
	var out: Array = []
	var supported := allowed(resource, global, recipe)
	for prop: Dictionary in resource.get_property_list():
		var id: String = prop.name
		if not LABELS.has(id) or not supported.has(id): continue
		if not advanced and group(id) == "advanced": continue
		var value: Variant = resource.get(id)
		var initial: Variant = defaults.get(id) if defaults != null else value
		var label: String = LABELS[id]
		if value is bool:
			out.append(P.boolean(id, label, id, initial))
		elif value is Color:
			out.append(P.color(id, label, id, initial))
		elif value is Vector2 or value is Vector3:
			for axis: String in (["x", "y", "z"] if value is Vector3 else ["x", "y"]):
				if id == "rotation_degrees" and resource.kind != Layer.Kind.PARTICLES and resource.facing == Layer.Facing.CAMERA and axis != "z": continue
				if id == "wind" and axis == "y": continue
				if id == "emission_box" and resource.kind == Layer.Kind.FIELD and resource.field_motion == Layer.FieldMotion.RAIN and axis == "y": continue
				var limit := 180.0 if id == "rotation_degrees" else 10.0
				var minimum := 0.05 if id == "aspect" else 0.0 if id == "emission_box" else -limit
				out.append(P.num(id + "." + axis, label + " " + axis.to_upper(), id, minimum, limit, initial[axis]))
		elif value is int or value is float:
			if id == "facing":
				var def := P.choice(id, label, id, [[0, "朝向镜头"], [1, "固定地面"], [2, "固定空间"]], "")
				def.default = initial
				out.append(def)
				continue
			var bounds: Array = RANGES.get(id, [0.0, maxf(5.0, float(value) * 2.0)])
			var step := 1.0 if value is int else 0.01
			if prop.hint == PROPERTY_HINT_RANGE:
				var parts: PackedStringArray = prop.hint_string.split(",")
				if parts.size() >= 2: bounds = [float(parts[0]), float(parts[1])]
				if parts.size() >= 3: step = float(parts[2])
			var def := P.integer(id, label, id, int(bounds[0]), int(bounds[1]), initial) if value is int else P.num(id, label, id, bounds[0], bounds[1], initial)
			def.step = step
			out.append(def)
	if recipe != null:
		var index: int = -1 if global else recipe.layers.find(resource)
		var hidden: Array = Visibility.HIDDEN.get(recipe.id + "/" + str(index), [])
		out = out.filter(func(d: Dictionary) -> bool: return not hidden.has(d.id))
	for d: Dictionary in out:
		var base: String = str(d.id).get_slice(".", 0)
		d.tip = TIPS.get(base, "")
		if base == "rotation_degrees": d.unit = "°"
		if base == "spin": d.unit = "°/s"
		if base == "end_size" and not global and resource.kind == Layer.Kind.PARTICLES:
			d.label = "末端尺寸比例"
			d.tip = "相对粒子初始尺寸的倍率，例如 0.5 表示缩小到一半。"
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ra := _order(a.id)
		var rb := _order(b.id)
		return str(a.id) < str(b.id) if ra == rb else ra < rb)
	return out

static func _order(id: String) -> int:
	var base := id.get_slice(".", 0)
	if IMPORTANT.has(base): return IMPORTANT.find(base)
	if MOTION.has(base): return 100 + MOTION.find(base)
	if SPATIAL.has(base): return 300 + SPATIAL.find(base)
	return 500
