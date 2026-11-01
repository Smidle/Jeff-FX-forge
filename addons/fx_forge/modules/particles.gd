@tool
extends "fx_module.gd"
## 粒子：火星、碎屑、尘土、冰屑、光点……
## 每个粒子按「出生点 + 初速度 + 阻力 + 重力」的闭式公式运动，任意一帧都能单独算出来。

const P := preload("../core/fx_params.gd")
const FxParticles := preload("../core/fx_particles.gd")


func get_id() -> String:
	return "particles"


func get_display_name() -> String:
	return "粒子"


func get_display_name_en() -> String:
	return "Particles"


func get_description() -> String:
	return "火星、碎屑、尘土、冰屑、光点"


func is_directional() -> bool:
	return true


func get_layer_defaults() -> Dictionary:
	return {"palette_slot": "accent", "outline": false}


func keeps_tiny_pixels() -> bool:
	return true


func get_param_defs() -> Array:
	return [
		P.integer("count", "数量", "Count", 1, 300, 16, {group = "shape"}),
		P.choice("shape", "形状", "Shape", FxParticles.SHAPE_OPTIONS, "square", {group = "shape"}),
		P.num("size", "大小", "Size", 1.0, 24.0, 2.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("size_end", "结束时大小", "End Size", 0.0, 3.0, 0.5, {group = "shape", unit = "×", tip = "粒子快消失时的大小是开始的几倍（尘土可以大于 1，越飘越大）"}),
		P.num("size_random", "大小随机", "Size Random", 0.0, 1.0, 0.4, {group = "shape"}),
		P.choice("emit_shape", "发射区域", "Emit Area", FxParticles.EMIT_SHAPE_OPTIONS, "point", {group = "shape", tip = "粒子从哪里冒出来：圆环上的粒子会沿径向飞出"}),
		P.text("text", "文字", "Text", "Jeff Studio", {group = "shape", show_if = ["emit_shape", "text"], tip = "要排的字：英文字母、数字和常用符号（像素字体，大写 5×7 格）。粒子数量和字的点数相同时一点一颗，少了字会缺笔画"}),
		P.num("emit_radius", "发射范围", "Emit Radius", 0.0, 240.0, 4.0, {group = "shape", unit = "px", scale = true, step = 0.5, hide_if = ["emit_shape", ["point", "heart", "star", "smile"]], tip = "圆的半径；横线、矩形的半宽；文字一开始的半宽（0 = 从原点炸开成字）"}),
		P.num("emit_height", "矩形高度", "Box Height", 1.0, 400.0, 24.0, {group = "shape", unit = "px", scale = true, step = 0.5, show_if = ["emit_shape", "box"]}),
		P.num("squash", "纵向压扁", "Squash", 0.15, 1.0, 1.0, {group = "shape", hide_if = ["emit_shape", "text"], tip = "出生位置和飞散速度的上下分量乘这个倍数：圆环发射变成地面上的扁椭圆（等距视角常用 0.3~0.5）"}),
		P.boolean("sphere", "球形炸开", "Sphere Burst", false, {group = "shape", tip = "速度按球面分布：侧面看，朝镜头和背向镜头飞的粒子显得慢，炸开是一个实心的球而不是一个圈（烟花、爆炸碎片）"}),
		P.num("emit_rise", "发射点上升", "Emitter Rise", 0.0, 400.0, 0.0, {group = "shape", unit = "px", scale = true, step = 1.0, tip = "在发射时长内，发射点从原点往上升这么高，先快后慢：礼花弹升空时一路洒下火星"}),
		P.boolean("emit_head", "升空亮头", "Rising Head", false, {group = "shape", hide_if = ["emit_rise", 0.0], tip = "发射点上升时画一个白热的亮点和一小段尾巴（礼花弹本身）"}),
		P.boolean("mirror", "左右对称", "Mirror", false, {group = "shape", hide_if = ["emit_shape", ["heart", "star", "smile", "text"]], tip = "一半粒子翻到另一侧，从原点往左右两边对称地飞（落地扬起的尘土）"}),
		P.choice("flow", "运动方式", "Flow", FxParticles.FLOW_OPTIONS, "out", {group = "motion", tip = "向中心汇聚：粒子从外面被吸进原点（蓄力、吸收）"}),
		P.num("spread", "扩散角", "Spread", 0.0, 360.0, 360.0, {group = "motion", unit = "°", step = 1.0, hide_if = ["emit_shape", ["heart", "star", "smile", "text"]], tip = "360 = 四面八方；越小越集中朝「方向」喷出"}),
		P.num("speed", "速度", "Speed", 0.0, 800.0, 70.0, {group = "motion", unit = "px", scale = true, step = 1.0, tip = "数值越大飞得越远（汇聚时决定从多远的地方吸进来）"}),
		P.num("speed_random", "速度随机", "Speed Random", 0.0, 1.0, 0.5, {group = "motion"}),
		P.num("gravity", "重力", "Gravity", -3000.0, 3000.0, 0.0, {group = "motion", unit = "px", scale = true, step = 5.0, hide_if = ["flow", "gather"], tip = "正数往下掉，负数往上飘"}),
		P.num("drag", "阻力", "Drag", 0.0, 10.0, 2.5, {group = "motion", step = 0.1, hide_if = ["flow", "gather"], tip = "越大减速越快"}),
		P.num("sway", "左右摆动", "Sway", 0.0, 40.0, 0.0, {group = "motion", unit = "px", scale = true, step = 0.5, hide_if = ["flow", "gather"], tip = "飘动时左右摇摆的幅度（灰烬、上升的光点）"}),
		P.boolean("use_floor", "落地消失", "Floor", false, {group = "motion", hide_if = ["flow", "gather"], tip = "粒子掉到地面线以下就消失（水花落回水面）"}),
		P.num("floor_y", "地面线", "Floor Y", -200.0, 200.0, 0.0, {group = "motion", unit = "px", scale = true, step = 0.5, show_if = ["use_floor", true], tip = "地面线在原点下方多少像素（负数 = 在原点上方）"}),
		P.num("bounce", "落地反弹", "Bounce", 0.0, 0.9, 0.0, {group = "motion", show_if = ["use_floor", true], tip = "0 = 碰到地面线就消失；大于 0 时粒子在地面上弹起（数值 = 弹起速度保留几成），最多弹 3 次，弹不动了就停在地面上，寿命到了再淡出（火星、碎石、冰碴）"}),
		P.choice("emit_mode", "发射方式", "Emit Mode", FxParticles.EMIT_MODE_OPTIONS, "burst", {group = "motion"}),
		P.num("emit_time", "发射时长", "Emit Time", 0.0, 1.0, 0.05, {group = "motion", tip = "粒子在多长时间内陆续冒出来（占图层时长的比例）"}),
		P.num("life", "寿命", "Lifetime", 0.05, 1.0, 0.75, {group = "motion", tip = "每个粒子存在多久（占图层时长的比例）"}),
		P.num("life_random", "寿命随机", "Life Random", 0.0, 1.0, 0.3, {group = "motion"}),
		P.num("bright", "亮度", "Brightness", 0.0, 1.0, 1.0, {group = "detail"}),
		P.num("cool", "冷却变暗", "Cooling", 0.0, 1.0, 0.6, {group = "detail", tip = "粒子随时间变暗的程度（火星从白热变成暗红）"}),
		P.num("flicker", "闪烁", "Flicker", 0.0, 1.0, 0.0, {group = "detail"}),
		P.num("flicker_from", "闪烁开始", "Flicker From", 0.0, 0.95, 0.0, {group = "detail", hide_if = ["flicker", 0.0], tip = "粒子寿命走到这里才开始闪烁（烟花星点快熄灭时才闪）"}),
		P.num("fade_from", "开始淡出", "Fade From", 0.0, 1.0, 0.6, {group = "detail", hide_if = ["flow", "gather"], tip = "粒子寿命走到这里开始变淡；1 = 一直不变淡，寿命到了直接消失（停在空中的文字要清楚地挂满全程）"}),
		P.num("flicker_rate", "闪烁频率", "Flicker Rate", 1.0, 40.0, 3.7, {group = "detail", step = 0.1, hide_if = ["flicker", 0.0], tip = "每个粒子一辈子闪几次。频闪烟花要快闪：寿命 2 秒、闪 16 次，大约每秒 8 下"}),
		P.num("trail", "尾迹", "Trail", 0.0, 0.6, 0.0, {group = "detail", hide_if = ["flow", "gather"], tip = "画出粒子过去这么长时间（占图层时长）走过的路径，1 像素的线，越往后越暗越淡：烟花星点的拖尾。落地反弹的粒子不画尾迹"}),
		P.integer("split", "分裂", "Split", 0, 8, 0, {group = "detail", hide_if = ["flow", "gather"], tip = "寿命走到「分裂时刻」时一颗分成几颗，向四周均匀散开（十字分裂、千轮、碎裂烟花）；0 = 不分裂。落地反弹的粒子不分裂"}),
		P.num("split_at", "分裂时刻", "Split At", 0.05, 0.95, 0.5, {group = "detail", hide_if = ["split", 0], tip = "占粒子寿命的比例"}),
		P.num("split_speed", "分裂速度", "Split Speed", 0.0, 400.0, 30.0, {group = "detail", unit = "px", scale = true, step = 1.0, hide_if = ["split", 0]}),
		P.num("split_life", "分裂后寿命", "Split Life", 0.1, 1.0, 1.0, {group = "detail", hide_if = ["split", 0], tip = "子粒子活到母粒子剩余寿命的几成：小值是一闪即灭的噼啪声"}),
		P.num("streak_len", "拖影长度", "Streak Length", 0.0, 2.0, 0.4, {group = "detail", show_if = ["shape", "streak"]}),
		P.num("spin", "旋转", "Spin", 0.0, 4.0, 1.0, {group = "detail", unit = "圈", step = 0.1, tip = "碎片、四角星在一段动画里转几圈"}),
		P.num("opacity", "不透明度", "Opacity", 0.05, 1.0, 1.0, {group = "detail", tip = "粒子刚出现时的可见度。烟、蒸汽、雾要真正半透明时调低，并把图层的「消散方式」设为淡出"}),
		P.num("thin", "越飘越稀", "Thinning", 0.0, 1.0, 0.0, {group = "detail", tip = "可见度随寿命降低的程度：烟团一边胀大一边变稀"}),
		P.num("soft_edge", "边缘透明", "Soft Edge", 0.0, 1.0, 0.0, {group = "detail", show_if = ["shape", ["puff", "smoke"]], tip = "烟团、烟雾的边缘比中心更透明（配合图层「半透明」消散）"}),
		P.num("glow", "发光", "Glow", 0.0, 1.0, 0.0, {group = "detail", tip = "每个粒子周围的叠加光（火星、余烬、闪光点）。亮度跟着粒子的冷却变暗"}),
		P.num("glow_size", "光晕半径", "Glow Radius", 1.0, 64.0, 6.0, {group = "detail", unit = "px", scale = true, step = 0.5, hide_if = ["glow", 0.0]}),
		P.num("glow_tone", "光色", "Glow Tone", 0.0, 1.0, 0.6, {group = "detail", advanced = true, hide_if = ["glow", 0.0], tip = "光取色板上哪个位置的颜色：0 = 最暗，1 = 最亮。中间偏亮的颜色光才有色相，太靠近白色会把画面洗白"}),
	]


func prepare(p: Dictionary, ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := {
		"count": p["count"], "emit_shape": p["emit_shape"], "emit_radius": p["emit_radius"], "emit_height": p["emit_height"],
		"angle": ctx.angle, "spread": p["spread"], "speed": p["speed"], "speed_random": p["speed_random"],
		"life": p["life"], "life_random": p["life_random"], "emit_mode": p["emit_mode"], "emit_time": p["emit_time"],
		"size": p["size"], "size_random": p["size_random"], "spin": p["spin"], "mirror": p["mirror"], "squash": p["squash"],
		"sphere": p["sphere"], "emit_rise": p["emit_rise"], "text": p["text"],
	}
	var table := FxParticles.spawn(cfg, rng)
	if p["use_floor"] and float(p["bounce"]) > 0.0 and p["flow"] != "gather":
		FxParticles.bounce_paths(table, p["gravity"], p["drag"], p["floor_y"], p["bounce"])
	return {"table": table}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var cfg := {
		"shape": FxParticles.shape_index(p["shape"]), "size_end": p["size_end"], "gravity": p["gravity"],
		"drag": p["drag"], "cool": p["cool"], "bright": p["bright"], "flicker": p["flicker"],
		"streak_len": p["streak_len"], "loop": ctx.loop, "ox": ctx.ox, "oy": ctx.oy,
		"gather": p["flow"] == "gather", "sway": p["sway"],
		"opacity": p["opacity"], "thin": p["thin"], "soft": p["soft_edge"],
		"glow": p["glow"], "glow_size": p["glow_size"], "glow_tone": p["glow_tone"],
		"flicker_from": p["flicker_from"], "flicker_rate": p["flicker_rate"], "fade_from": p["fade_from"], "trail": p["trail"], "split": p["split"], "split_at": p["split_at"],
		"split_speed": p["split_speed"], "split_life": p["split_life"],
		"emit_head": p["emit_head"], "emit_rise": p["emit_rise"], "emit_time": p["emit_time"],
	}
	if p["use_floor"]:
		cfg["floor_y"] = p["floor_y"]
	FxParticles.draw(buf, st["table"], cfg, u)
	return 1.0
