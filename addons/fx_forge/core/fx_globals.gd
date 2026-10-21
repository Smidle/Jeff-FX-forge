@tool
extends RefCounted
## 全局参数、图层通用参数的说明表，以及参数分组的中文名。

const P := preload("fx_params.gd")
const PAL := preload("fx_palette.gd")

## 分组 id → 中文名（界面按这个顺序显示分组）
const GROUP_NAMES := {
	"canvas": "画布与时间",
	"direction": "方向",
	"look": "外观",
	"outline": "描边",
	"cleanup": "清理",
	"layer": "图层设置",
	"shape": "形状",
	"motion": "运动",
	"detail": "细节",
}

const DISSOLVE_OPTIONS := [["dither", "抖动溶解"], ["shrink", "收缩"], ["darken", "变暗"], ["fade", "淡出"]]
const OUTLINE_OPTIONS := [["none", "无"], ["outer", "外描边"], ["inner", "内描边"], ["selective", "选择性描边"]]


static func global_defs() -> Array:
	return [
		P.integer("canvas_w", "画布宽", "Canvas Width", 8, 512, 64, {group = "canvas", unit = "px", tip = "单帧图片的宽度（像素）"}),
		P.integer("canvas_h", "画布高", "Canvas Height", 8, 512, 64, {group = "canvas", unit = "px", tip = "单帧图片的高度（像素）"}),
		P.num("size_scale", "整体缩放", "Overall Scale", 0.25, 4.0, 1.0, {group = "canvas", step = 0.05, unit = "×", tip = "画布和所有尺寸参数一起放大缩小，描边宽度保持不变"}),
		P.integer("frames", "帧数", "Frames", 2, 64, 12, {group = "canvas", tip = "动画一共多少帧"}),
		P.integer("fps", "帧率", "FPS", 1, 60, 15, {group = "canvas", unit = "帧/秒", tip = "每秒播放多少帧；帧数 ÷ 帧率 = 动画时长"}),
		P.boolean("loop", "循环", "Loop", false, {group = "canvas", tip = "循环特效（火焰、光环）最后一帧无缝接回第一帧；一次性特效（斩击、爆炸）播完消失"}),
		P.integer("seed", "随机种子", "Seed", 0, 99999, 1, {group = "canvas", tip = "换一个数字，就得到同一特效的另一种随机变化"}),
		P.num("origin_x", "原点 X", "Origin X", 0.0, 1.0, 0.5, {group = "canvas", advanced = true, tip = "特效中心在画布中的水平位置（0 左 · 1 右），导出后就是场景的定位点"}),
		P.num("origin_y", "原点 Y", "Origin Y", 0.0, 1.0, 0.5, {group = "canvas", advanced = true, tip = "特效中心在画布中的垂直位置（0 上 · 1 下）"}),
		P.angle("direction", "方向", "Direction", 0.0, {group = "direction", tip = "0° 朝右，90° 朝下，180° 朝左，270° 朝上"}),
		P.boolean("flip_h", "水平翻转", "Flip H", false, {group = "direction"}),
		P.boolean("flip_v", "垂直翻转", "Flip V", false, {group = "direction"}),
		P.choice("theme", "配色主题", "Color Theme", PAL.theme_options(), "steel", {group = "look", tip = "一键给所有图层换配色"}),
		P.palette("palette_main", "主色板", "Main Palette", "steel", {group = "look", tip = "大多数图层使用的颜色"}),
		P.palette("palette_accent", "辅色板", "Accent Palette", "spark", {group = "look", tip = "火星、闪光等点缀用色"}),
		P.palette("palette_smoke", "烟尘色板", "Smoke Palette", "smoke", {group = "look", tip = "烟雾、尘土用色"}),
		P.num("soft", "柔光强度", "Soft Glow", 0.0, 1.0, 0.0, {group = "look", step = 0.05, tip = "0 = 纯硬边像素；调高后外圈出现分级半透明的发光"}),
		P.integer("alpha_levels", "透明度层级", "Alpha Levels", 1, 4, 3, {group = "look", advanced = true, tip = "半透明像素允许几种透明度（柔光与淡出时生效）"}),
		P.choice("dither", "色阶抖动", "Dither", [["none", "无"], ["bayer2", "2×2 点阵"], ["bayer4", "4×4 点阵"]], "none", {group = "look", tip = "相邻两种颜色之间用点阵过渡"}),
		P.num("dither_strength", "抖动强度", "Dither Strength", 0.0, 1.0, 0.6, {group = "look", advanced = true, hide_if = ["dither", "none"]}),
		P.choice("dissolve", "消散方式", "Dissolve", DISSOLVE_OPTIONS, "dither", {group = "look", tip = "特效（或残影）变淡时的表现方式"}),
		P.choice("outline", "描边", "Outline", OUTLINE_OPTIONS, "outer", {group = "outline", tip = "选择性描边：描边颜色跟随旁边的像素自动加深"}),
		P.integer("outline_width", "描边宽度", "Outline Width", 1, 3, 1, {group = "outline", unit = "px", hide_if = ["outline", "none"]}),
		P.choice("outline_color_mode", "描边颜色", "Outline Color", [["darkest", "主色板最暗色"], ["fixed", "固定颜色"]], "darkest", {group = "outline", hide_if = ["outline", "none"], tip = "选择性描边的颜色总是跟随旁边像素，不受这里影响"}),
		P.color("outline_color", "固定描边色", "Fixed Outline Color", Color("140f1e"), {group = "outline", show_if = ["outline_color_mode", "fixed"], hide_if = ["outline", "none"]}),
		P.choice("outline_corner", "描边拐角", "Outline Corners", [["round", "圆角"], ["square", "方角"]], "round", {group = "outline", advanced = true, hide_if = ["outline", "none"], tip = "圆角：斜角不补像素，更柔和；方角：斜角也描"}),
		P.boolean("cleanup", "去除孤立像素", "Remove Orphans", true, {group = "cleanup", tip = "去掉周围没有邻居的零散单像素，画面更干净"}),
		P.integer("min_cluster", "最小团块", "Min Cluster", 1, 8, 1, {group = "cleanup", advanced = true, tip = "小于这个像素数的碎块会被去掉"}),
	]


static func layer_defs() -> Array:
	return [
		P.boolean("enabled", "显示", "Visible", true, {group = "layer"}),
		P.slot("palette_slot", "色板", "Palette Slot", "main", {group = "layer", tip = "这个图层用哪个全局色板"}),
		P.num("t_start", "开始时间", "Start", 0.0, 1.0, 0.0, {group = "layer", tip = "图层在时间轴上从哪里开始（0~1）"}),
		P.num("t_end", "结束时间", "End", 0.0, 1.0, 1.0, {group = "layer", tip = "图层在时间轴上到哪里结束（0~1）"}),
		P.boolean("follow_dir", "跟随方向", "Follow Direction", true, {group = "layer", tip = "是否跟着全局方向一起转"}),
		P.angle("angle_offset", "角度偏移", "Angle Offset", 0.0, {group = "layer"}),
		P.num("offset_x", "位置偏移 X", "Offset X", -256.0, 256.0, 0.0, {group = "layer", unit = "px", scale = true, step = 0.5}),
		P.num("offset_y", "位置偏移 Y", "Offset Y", -256.0, 256.0, 0.0, {group = "layer", unit = "px", scale = true, step = 0.5}),
		P.boolean("outline", "参与描边", "Outlined", true, {group = "layer"}),
	]
