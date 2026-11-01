@tool
extends RefCounted
## 飞弹的像素命中：命中效果用像素引擎画（「飞弹命中系」预设，presets/missile_hit_presets.gd）。
## 按飞弹的像素密度和「命中大小」缩放，像素格和弹头一样大；主色板、烟尘色板按飞弹配方的主色换色相，
## 辅色板（白闪、火花）不换。同样的参数只渲染一次，缓存起来，之后的飞弹直接复用。
## 发射时开始后台渲染，飞行途中就渲染好了；命中时还没好（例如拖动时间轴直接跳到命中）就等它完成。

const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const FxPalette := preload("res://addons/fx_forge/core/fx_palette.gd")

## 像素命中样式（JeffForge3DMissileConfig.Impact）→ 预设 id，以及预设设计时对应的配方主色（这个颜色下不换色相）
const PRESETS := {
	6: ["missile_hit_fire", Color(1, 0.61, 0.18)],
	7: ["missile_hit_ice", Color(0.66, 0.94, 1)],
	8: ["missile_hit_shadow", Color(0.7, 0.43, 0.96)],
	9: ["missile_hit_sword", Color(0.69, 0.91, 0.85)],
}
## 「命中大小」1 米、像素密度 64 时预设不缩放（预设里主体约 64 像素）
const NOMINAL := 64.0

static var _cache := {}


static func is_pixel(style: int) -> bool:
	return PRESETS.has(style)


## 取（必要时开始渲染）一组命中帧。返回的字典在渲染完成前 textures 为空，用 textures_of() 取帧
static func request(style: int, primary: Color, saturation: float, density: int, size_m: float) -> Dictionary:
	var scale := clampf(size_m * float(density) / NOMINAL, 0.2, 4.0)
	var key := "%d|%s|%.2f|%.2f" % [style, primary.to_html(false), saturation, scale]
	if _cache.has(key):
		return _cache[key]
	var preset: Resource = Builtin.find(PRESETS[style][0])
	var design: Color = PRESETS[style][1]
	var g: Dictionary = preset.globals
	g["size_scale"] = scale
	g["palette_main"] = _recolor(FxPalette.colors_of(g["palette_main"]), design, primary, saturation)
	g["palette_smoke"] = _recolor(FxPalette.colors_of(g["palette_smoke"]), design, primary, saturation)
	var job: RefCounted = FxRenderer.make_job(preset)
	var entry := {"job": job, "task": FxRenderer.start_async(job), "textures": [], "origin": job.origin,
		"size": Vector2(job.w, job.h)}
	_cache[key] = entry
	return entry


## 渲染好的帧（ImageTexture）。wait = true 时还没渲染完就等它完成
static func textures_of(entry: Dictionary, wait: bool) -> Array:
	if entry.textures.is_empty() and int(entry.task) >= 0:
		if not wait and not WorkerThreadPool.is_group_task_completed(entry.task):
			return []
		WorkerThreadPool.wait_for_group_task_completion(entry.task)
		entry.task = -1
		for image: Image in entry.job.images():
			entry.textures.append(ImageTexture.create_from_image(image))
		entry.job = null
	return entry.textures


## 色板换色相：把预设设计时的主色转到配方的主色，饱和度乘「饱和度」。灰色（烟、白）不动
static func _recolor(colors: PackedColorArray, design: Color, target: Color, saturation: float) -> PackedColorArray:
	var shift := target.h - design.h if target.s > 0.12 else 0.0
	var out := PackedColorArray()
	for c in colors:
		if c.s < 0.12:
			out.append(c)
		else:
			out.append(Color.from_hsv(fposmod(c.h + shift, 1.0), clampf(c.s * saturation, 0.0, 1.0), c.v, c.a))
	return out
