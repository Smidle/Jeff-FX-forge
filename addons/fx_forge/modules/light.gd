@tool
extends "fx_module.gd"
## 光源：只画叠加光、不画像素。命中、爆炸瞬间闪亮再熄灭的光，火堆、冰面映在地上的一摊光。
## 亮度先在「亮起用时」内升到最高，之后按剩余寿命的平方衰减（开头很亮、很快暗下去、尾巴拖得长）。
## 光色取图层色板上的一个位置；画面上是加到颜色上的光，在透明处变成半透明的光晕。

const P := preload("../core/fx_params.gd")
const M := preload("../core/fx_math.gd")


func get_id() -> String:
	return "light"


func get_display_name() -> String:
	return "光源"


func get_display_name_en() -> String:
	return "Light"


func get_description() -> String:
	return "闪亮再熄灭的叠加光、地面光斑"


func get_layer_defaults() -> Dictionary:
	return {"outline": false, "follow_dir": false}


func get_param_defs() -> Array:
	return [
		P.num("radius", "半径", "Radius", 2.0, 320.0, 32.0, {group = "shape", unit = "px", scale = true, step = 0.5, tip = "光晕从中心衰减到 0 的距离"}),
		P.num("start", "起始大小", "Start Size", 0.0, 1.0, 1.0, {group = "shape", hide_if = ["attack", 0.0], tip = "开始时的半径是最大半径的几成，随后在「亮起用时」内长到最大"}),
		P.num("squash", "地面透视", "Squash", 0.1, 1.0, 1.0, {group = "shape", tip = "压扁成椭圆：映在地面上的一摊光（等距视角常用 0.3~0.5）"}),
		P.num("strength", "亮度", "Strength", 0.0, 2.0, 0.6, {group = "detail", step = 0.05, tip = "中心的叠加亮度。0.2~0.5 是柔和的光，接近 1 时中心会被照成接近白色"}),
		P.num("tone", "光色", "Tone", 0.0, 1.0, 0.6, {group = "detail", tip = "取色板上哪个位置的颜色：0 = 最暗，1 = 最亮。白闪用 1；有色相的光用 0.5~0.7"}),
		P.num("attack", "亮起用时", "Attack", 0.0, 0.5, 0.0, {group = "motion", tip = "从暗到最亮所用的时间比例；0 = 一出现就是最亮（爆炸闪光）"}),
		P.num("flicker", "闪烁", "Flicker", 0.0, 1.0, 0.0, {group = "motion", tip = "亮度随时间不规则抖动（火光）"}),
	]


func prepare(_p: Dictionary, _ctx: FxContext, rng: RandomNumberGenerator) -> Dictionary:
	return {"noise": M.periodic_noise(64, 2, rng)}


func render(buf: FxBuffer, p: Dictionary, st: Dictionary, u: float, ctx: FxContext) -> float:
	var attack: float = p["attack"]
	var k: float = p["strength"]
	var grow := 1.0
	if attack > 0.0 and u < attack:
		var a := u / attack
		k *= a
		grow = a
	else:
		var rest := 1.0 - clampf((u - attack) / maxf(1.0 - attack, 0.001), 0.0, 1.0)
		k *= rest * rest
	var flicker: float = p["flicker"]
	if flicker > 0.0:
		var noise: PackedFloat32Array = st["noise"]
		k *= 1.0 - flicker * noise[int(u * 4.0 * noise.size()) % noise.size()]
	var r := float(p["radius"]) * lerpf(float(p["start"]), 1.0, grow)
	buf.glow(ctx.ox, ctx.oy, r, k, p["tone"], p["squash"])
	return 1.0
