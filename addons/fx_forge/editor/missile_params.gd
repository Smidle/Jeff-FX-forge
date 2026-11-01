@tool
extends RefCounted
## Nested parameter descriptions for the retained 3D missile runtime.
## This module reads resources only; scene targets and Curve3D handles stay in
## their existing Inspector/runtime APIs instead of becoming saved node paths.
const P := preload("../core/fx_params.gd")
const Layer := preload("../legacy/runtime/fx_layer.gd")
const Config := preload("../legacy/runtime/fx_missile_config.gd")

const MAIN := ["head_style", "head_size", "head_glow", "saturation", "projectile_count", "path_mode", "flight_time", "trail_length", "trail_style", "trail_width", "trail_particles", "afterimages", "impact_enabled", "impact_style", "impact_size"]
const MOTION := ["launch_interval", "progress", "arc_height", "side_offset", "random_spread", "helix_turns", "deformation", "turbulence", "head_dissolve", "trail_fade", "particle_life", "impact_duration", "orbit_speed"]
const SPACE := ["start", "end", "head_aspect", "head_rotation", "impact_facing"]
const ADVANCED := ["pixel_density", "halo", "magic_ornament", "motes", "trail_head_width", "trail_tip_width", "trail_taper", "trail_color_mix", "impact_fragments", "teleport_threshold"]
const LABELS := {
	"head_style": "弹头造型", "head_size": "弹头大小", "saturation": "颜色饱和度", "projectile_count": "飞弹数量", "path_mode": "飞行轨迹", "flight_time": "飞行时长",
	"head_glow": "弹头光晕亮度", "trail_length": "实际拖尾长度", "trail_style": "拖尾造型", "trail_width": "拖尾宽度", "impact_enabled": "播放命中效果", "impact_style": "命中造型", "impact_size": "命中大小",
	"launch_interval": "逐枚发射间隔", "progress": "飞行进度", "arc_height": "路径弧高", "side_offset": "路径侧偏", "random_spread": "路径幅度", "helix_turns": "螺旋圈数",
	"deformation": "弹头形变", "turbulence": "拖尾扰动", "head_dissolve": "弹头消散时间", "trail_fade": "尾部消散时间", "impact_duration": "命中持续时间", "orbit_speed": "环绕速度",
	"start": "发射起点", "end": "固定终点", "head_aspect": "弹头长宽比", "head_rotation": "弹头旋转", "impact_facing": "命中朝向",
	"pixel_density": "弹头像素精度", "halo": "弹头光晕", "magic_ornament": "魔法装饰强度", "motes": "伴随碎光数量", "trail_head_width": "尾根宽度比例", "trail_tip_width": "尾尖宽度比例", "trail_taper": "拖尾收尖曲线", "trail_color_mix": "拖尾颜色过渡", "impact_fragments": "命中碎屑数量", "teleport_threshold": "目标瞬移阈值",
	"trail_particles": "拖尾粒子数量", "particle_life": "粒子存留时间", "afterimages": "残影数量"
}
const CHOICES := {
	"path_mode": [[0, "直线"], [1, "抛物线"], [2, "S 形"], [3, "螺旋"], [4, "随机弧线"], [5, "自定义曲线"]],
	"progress": [[0, "匀速"], [1, "加速"], [2, "减速"], [3, "平滑起停"]],
	"head_style": [[0, "御剑"], [1, "火球"], [2, "寒冰箭"], [3, "暗影箭"]],
	"trail_style": [[0, "流带"], [1, "丝线"], [2, "碎光"], [3, "焰流"], [4, "霜线"], [5, "影雾"], [6, "焰旋"], [7, "流光"], [8, "冰雾"]],
	"impact_style": [[0, "火星"], [1, "气浪"], [2, "星爆"], [3, "爆燃"], [4, "冰碎"], [5, "影裂"], [6, "火球爆燃（像素）"], [7, "冰晶迸裂（像素）"], [8, "暗影裂爆（像素）"], [9, "剑光星爆（像素）"]],
	"impact_facing": [[0, "朝向镜头"], [1, "固定地面"], [2, "沿入射方向"]]
}
const TIPS := {
	"head_style": "只改变弹体造型，路径、拖尾和命中可以独立搭配。",
	"head_size": "弹体的世界尺寸，同时受整体外观缩放影响；改变路径长度不会改变弹体大小。",
	"saturation": "0 为灰阶，1 保持配色，较高值增强色彩；亮度另由整体亮度控制。",
	"projectile_count": "最多 16 枚。多枚使用各自的固定种子，并汇入同一终点。",
	"path_mode": "选自定义曲线后，在预览里拖动节点和切线小柄编辑路径；第一次切换会从当前路径生成曲线。",
	"flight_time": "每枚飞弹从发射到视觉到达的时间；改变路径长度仍保持此时长。",
	"trail_length": "保留实际飞过的世界路径，单位为米；0 关闭拖尾，已留下的轨迹不会随目标转动。",
	"trail_style": "只改变拖尾内部造型，不改变飞行与命中时序。焰旋是绕飞行方向旋转的两股火焰（转速由环绕速度控制），流光是细亮光带，冰雾是点阵寒气加断续霜线。",
	"trail_width": "拖尾的世界宽度，受整体外观缩放影响。",
	"impact_enabled": "关闭后不显示命中爆发，但弹头与拖尾仍完成消散；视觉到达事件仍保持原时序。",
	"head_glow": "弹头周围一团随飞行闪动的叠加光，把周围照亮；0 = 不加光。暗色背景下最明显。",
	"impact_style": "命中表现独立于弹头造型，可自由搭配。带「像素」的四种用像素引擎画：白闪、冷却、烟和飞散的碎屑，像素格和弹头一样大，颜色跟随主色；在像素工坊的「飞弹命中系」里也能单独打开。",
	"impact_size": "命中爆发的世界尺寸，受整体外观缩放影响。",
	"launch_interval": "仅多枚发射时生效；影响整组的最终结束时间。",
	"progress": "按路径弧长分配飞行进度；加减速不会改变最终到达时刻。",
	"arc_height": "相对起终点连线的高度，单位为米。负值向相反方向弯曲。",
	"side_offset": "相对起终点连线的横向偏移；两端仍连接起点与终点。",
	"random_spread": "S 形的摆幅、螺旋半径或随机弧线的偏移幅度，单位为米。",
	"helix_turns": "仅螺旋路径生效，控制绕起终点连线的圈数。",
	"deformation": "改变火核翻卷、箭体细节或御剑光边的形变；御剑与冰箭需保留光晕才能看到部分形变。",
	"turbulence": "改变拖尾表面的扰动，不重写实际飞行轨迹。",
	"head_dissolve": "到达后弹体转换为碎光或元素残留的时间，0 立即结束弹体。取消飞行使用单独的短淡出。",
	"trail_fade": "到达后的尾部收束时间；与弹体消散共同决定收尾长度，不改变到达事件。",
	"impact_duration": "命中表现的播放时长；整组 finished 等待所有尾部结束。",
	"orbit_speed": "魔法环带、拖尾装饰和焰旋拖尾的旋转速度。",
	"start": "相对效果实例的本地坐标，单位为米；发射时换算为世界位置。外观缩放不会拉长路径。",
	"end": "未绑定移动目标时使用的本地终点，单位为米；追踪目标由场景实例或游戏调用绑定。",
	"head_aspect": "改变弹体长宽比例，不拉长路径。",
	"head_rotation": "在飞行平面内旋转弹体，仍保持尖端与拖尾连接。",
	"impact_facing": "控制命中平面朝向。沿入射方向保留到达瞬间方向。",
	"pixel_density": "弹头的程序纹理精度，16–128；更高精度增加纹理与生成开销。",
	"halo": "控制弹头周围的像素光边或伴随亮片；不会修改宿主项目后处理。",
	"magic_ornament": "控制元素飞弹环带、符纹和元素命中装饰；0 关闭这些附加细节。",
	"motes": "伴随飞弹的独立碎光数量；精简档降低数量。",
	"trail_particles": "沿飞行路线留在空中的粒子，样子跟随弹头造型：御剑是十字剑光，火球是火星和烟团，寒冰是冰晶和雪花，暗影是暗影絮。0 关闭；精简档数量减半。",
	"particle_life": "每个粒子从出现到消失的时间；越长，粒子在身后留得越远。",
	"afterimages": "沿飞过的路线留下弹头的残影，越远越淡，到达后向弹头收拢。0 关闭。",
	"trail_head_width": "靠近弹体处的拖尾宽度倍率。",
	"trail_tip_width": "最远尾尖的宽度倍率，0 收成尖端。",
	"trail_taper": "控制从尾尖到尾根的粗细变化。",
	"trail_color_mix": "调整主辅色在拖尾上的分布。",
	"impact_fragments": "命中碎屑数量；精简档降低数量。",
	"teleport_threshold": "移动目标一次采样位移超过此值时取消飞行并消散；固定终点预览无法演示此条件。"
}

static func group(id: String) -> String:
	var field: String = id.trim_prefix("missile.").get_slice(".", 0)
	return "main" if MAIN.has(field) else "motion" if MOTION.has(field) else "space" if SPACE.has(field) else "advanced"

static func defs(layer: Resource, defaults: Resource = null) -> Array:
	if not layer is Layer or layer.kind != Layer.Kind.MISSILE or layer.missile == null:
		return []
	var config: Resource = layer.missile
	var initial: Resource = defaults.missile if defaults is Layer and defaults.missile != null else defaults if defaults is Config else config
	var properties: Dictionary = {}
	for prop: Dictionary in config.get_property_list():
		properties[prop.name] = prop
	var result: Array = []
	for field: String in MAIN + MOTION + SPACE + ADVANCED:
		if not _visible(field, config):
			continue
		var id: String = "missile." + field
		var label: String = LABELS[field]
		var value: Variant = config.get(field)
		var original: Variant = initial.get(field)
		var options := {"group": group(id), "tip": TIPS.get(field, ""), "advanced": group(id) == "advanced"}
		if value is Vector3:
			for axis: String in ["x", "y", "z"]:
				var definition := P.num(id + "." + axis, label + " " + axis.to_upper(), field + " " + axis.to_upper(), -100.0, 100.0, original[axis], options)
				definition.unit = "m"
				definition.step = 0.05
				result.append(definition)
		elif CHOICES.has(field):
			var definition := P.choice(id, label, field, CHOICES[field], "", options)
			definition.default = original
			result.append(definition)
		elif value is bool:
			result.append(P.boolean(id, label, field, original, options))
		else:
			var prop: Dictionary = properties.get(field, {})
			var bounds := [0.0, 1.0, 0.01]
			if int(prop.get("hint", PROPERTY_HINT_NONE)) == PROPERTY_HINT_RANGE:
				var hints: PackedStringArray = str(prop.hint_string).split(",")
				if hints.size() >= 2: bounds = [float(hints[0]), float(hints[1]), float(hints[2]) if hints.size() >= 3 else 0.01]
			var definition: Dictionary = P.integer(id, label, field, int(bounds[0]), int(bounds[1]), original, options) if value is int else P.num(id, label, field, bounds[0], bounds[1], original, options)
			definition.step = bounds[2]
			if field in ["flight_time", "launch_interval", "head_dissolve", "trail_fade", "impact_duration", "particle_life"]: definition.unit = "s"
			if field in ["head_size", "trail_length", "trail_width", "impact_size", "arc_height", "side_offset", "random_spread", "turbulence", "teleport_threshold"]: definition.unit = "m"
			if field == "head_rotation": definition.unit = "°"
			result.append(definition)
	return result

static func _visible(field: String, c: Resource) -> bool:
	if field == "launch_interval": return c.projectile_count > 1
	if field == "arc_height": return c.path_mode in [Config.PathMode.ARC, Config.PathMode.S_CURVE, Config.PathMode.HELIX, Config.PathMode.RANDOM_ARC]
	if field == "side_offset": return c.path_mode != Config.PathMode.CUSTOM
	if field == "random_spread": return c.path_mode in [Config.PathMode.S_CURVE, Config.PathMode.HELIX, Config.PathMode.RANDOM_ARC]
	if field == "helix_turns": return c.path_mode == Config.PathMode.HELIX
	if field in ["trail_style", "trail_width", "trail_head_width", "trail_tip_width", "trail_taper", "trail_color_mix", "turbulence"]: return c.trail_length > 0
	if field in ["impact_style", "impact_size", "impact_duration"]: return c.impact_enabled
	# 像素命中自带碎屑、总是面向镜头（来势朝左时左右翻转），这两项不起作用
	if field in ["impact_fragments", "impact_facing"]: return c.impact_enabled and c.impact_style < Config.Impact.PIXEL_FIRE
	if field == "magic_ornament": return c.head_style != Config.Head.SWORD or (c.impact_enabled and c.impact_style >= Config.Impact.FLAME and c.impact_style < Config.Impact.PIXEL_FIRE)
	if field == "orbit_speed": return (c.magic_ornament > 0 and c.head_style != Config.Head.SWORD) or (c.trail_length > 0 and c.trail_style == Config.Trail.SPIRAL)
	if field == "particle_life": return c.trail_particles > 0
	if field == "deformation" and c.head_style in [Config.Head.SWORD, Config.Head.ICE_ARROW]: return c.halo > 0.01
	return true
