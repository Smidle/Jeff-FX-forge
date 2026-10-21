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


func get_param_defs() -> Array:
	return [
		P.integer("count", "数量", "Count", 1, 300, 16, {group = "shape"}),
		P.choice("shape", "形状", "Shape", FxParticles.SHAPE_OPTIONS, "square", {group = "shape"}),
		P.num("size", "大小", "Size", 1.0, 24.0, 2.0, {group = "shape", unit = "px", scale = true, step = 0.5}),
		P.num("size_end", "结束时大小", "End Size", 0.0, 3.0, 0.5, {group = "shape", unit = "×", tip = "粒子快消失时的大小是开始的几倍（尘土可以大于 1，越飘越大）"}),
		P.num("size_random", "大小随机", "Size Random", 0.0, 1.0, 0.4, {group = "shape"}),
		P.choice("emit_shape", "发射区域", "Emit Area", FxParticles.EMIT_SHAPE_OPTIONS, "point", {group = "shape", tip = "粒子从哪里冒出来：圆环上的粒子会沿径向飞出"}),
		P.num("emit_radius", "发射范围", "Emit Radius", 0.0, 240.0, 4.0, {group = "shape", unit = "px", scale = true, step = 0.5, hide_if = ["emit_shape", "point"]}),
		P.num("spread", "扩散角", "Spread", 0.0, 360.0, 360.0, {group = "motion", unit = "°", step = 1.0, tip = "360 = 四面八方；越小越集中朝「方向」喷出"}),
		P.num("speed", "速度", "Speed", 0.0, 800.0, 70.0, {group = "motion", unit = "px", scale = true, step = 1.0, tip = "数值越大飞得越远"}),
		P.num("speed_random", "速度随机", "Speed Random", 0.0, 1.0, 0.5, {group = "motion"}),
		P.num("gravity", "重力", "Gravity", -800.0, 800.0, 0.0, {group = "motion", unit = "px", scale = true, step = 5.0, tip = "正数往下掉，负数往上飘"}),
		P.num("drag", "阻力", "Drag", 0.0, 10.0, 2.5, {group = "motion", step = 0.1, tip = "越大减速越快"}),
		P.choice("emit_mode", "发射方式", "Emit Mode", FxParticles.EMIT_MODE_OPTIONS, "burst", {group = "motion"}),
		P.num("emit_time", "发射时长", "Emit Time", 0.0, 1.0, 0.05, {group = "motion", tip = "粒子在多长时间内陆续冒出来（占图层时长的比例）"}),
		P.num("life", "寿命", "Lifetime", 0.05, 1.0, 0.75, {group = "motion", tip = "每个粒子存在多久（占图层时长的比例）"}),
		P.num("life_random", "寿命随机", "Life Random", 0.0, 1.0, 0.3, {group = "motion"}),
		P.num("bright", "亮度", "Brightness", 0.0, 1.0, 1.0, {group = "detail"}),
		P.num("cool", "冷却变暗", "Cooling", 0.0, 1.0, 0.6, {group = "detail", tip = "粒子随时间变暗的程度（火星从白热变成暗红）"}),
		P.num("flicker", "闪烁", "Flicker", 0.0, 1.0, 0.0, {group = "detail"}),
		P.num("streak_len", "拖影长度", "Streak Length", 0.0, 2.0, 0.4, {group = "detail", show_if = ["shape", "streak"]}),
		P.num("spin", "旋转", "Spin", 0.0, 4.0, 1.0, {group = "detail", unit = "圈", step = 0.1, tip = "碎片、四角星在一段动画里转几圈"}),
	]


func prepare(p: Dictionary, ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	var cfg := {
		"count": p["count"], "emit_shape": p["emit_shape"], "emit_radius": p["emit_radius"],
		"angle": ctx.angle, "spread": p["spread"], "speed": p["speed"], "speed_random": p["speed_random"],
		"life": p["life"], "life_random": p["life_random"], "emit_mode": p["emit_mode"], "emit_time": p["emit_time"],
		"size": p["size"], "size_random": p["size_random"], "spin": p["spin"],
	}
	return {"table": FxParticles.spawn(cfg, rng)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var cfg := {
		"shape": FxParticles.shape_index(p["shape"]), "size_end": p["size_end"], "gravity": p["gravity"],
		"drag": p["drag"], "cool": p["cool"], "bright": p["bright"], "flicker": p["flicker"],
		"streak_len": p["streak_len"], "loop": ctx.loop, "ox": ctx.ox, "oy": ctx.oy,
	}
	FxParticles.draw(buf, st["table"], cfg, u)
	return 1.0
