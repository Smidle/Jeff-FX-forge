@tool
extends RefCounted
## 一次渲染任务。FxRenderer.make_job() 在主线程把预设解析成只读数据，
## render_frame(i) 可以在任意工作线程里调用：只写 results[i]，不碰其他共享状态。

const FxBuffer := preload("fx_buffer.gd")
const FxPost := preload("fx_post.gd")
const FxModule := preload("../modules/fx_module.gd")

var w: int = 0
var h: int = 0
var frame_count: int = 1
var fps: int = 12
var loop: bool = false
## 每帧的时长倍数（1 = 普通帧；打击停顿的那一帧更长），长度 = frame_count
var durations := PackedFloat32Array()
## 原点（像素坐标），导出时作为场景锚点
var origin := Vector2.ZERO
## 本任务要渲染的帧号
var frame_ids := PackedInt32Array()
## 每项 {module, params, state, ctx, t0, t1, r, g, b, outline}
var layers: Array = []
var post: Dictionary = {}
## 与 frame_ids 一一对应：{image: Image, frame: int, opaque: int, edge: bool, bbox: Rect2i}
var results: Array = []
## 调用方自用的标记（例如区分新旧请求）
var tag: int = 0


## 每帧时长倍数：第 hold_frame 帧（从 1 数起，0 = 不停顿）停 hold_mult 倍，其余为 1
static func durations_for(frame_count: int, hold_frame: int, hold_mult: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(frame_count)
	out.fill(1.0)
	if hold_frame >= 1 and hold_frame <= frame_count:
		out[hold_frame - 1] = maxf(hold_mult, 1.0)
	return out


## 整段动画的时长（秒）
func total_seconds() -> float:
	var sum := 0.0
	for d in durations:
		sum += d
	if durations.is_empty():
		sum = float(frame_count)
	return sum / maxf(float(fps), 1.0)


## 第 f 帧对应的全局时间 0~1：一次性特效取帧中点（首尾不出空帧），循环特效从 0 开始
func frame_time(f: int) -> float:
	if loop:
		return float(f) / float(frame_count)
	return (float(f) + 0.5) / float(frame_count)


func render_frame(idx: int) -> void:
	var f := frame_ids[idx]
	var t := frame_time(f)
	var parts: Array = []
	for layer: Dictionary in layers:
		var t0: float = layer["t0"]
		var dur: float = float(layer["t1"]) - t0
		if dur <= 0.0001:
			continue
		var u := (t - t0) / dur
		if loop:
			u = fposmod(u, 1.0)
		elif u < 0.0 or u > 1.0:
			continue
		var buf := FxBuffer.new(w, h)
		var m: FxModule = layer["module"]
		var fade := clampf(m.render(buf, layer["params"], layer["state"], u, layer["ctx"]), 0.0, 1.0)
		parts.append({"buf": buf, "fade": fade, "r": layer["r"], "g": layer["g"], "b": layer["b"],
			"outline": layer["outline"], "dissolve": layer.get("dissolve", -1), "keep": layer.get("keep", false)})
	var res := FxPost.new(w, h).run(parts, post)
	var pixels: PackedInt32Array = res["pixels"]
	res.erase("pixels")
	res["image"] = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, pixels.to_byte_array())
	res["frame"] = f
	results[idx] = res


## 所有结果里的图片（按 frame_ids 顺序）
func images() -> Array:
	var out: Array = []
	for r: Variant in results:
		out.append((r as Dictionary)["image"] if r is Dictionary else null)
	return out
