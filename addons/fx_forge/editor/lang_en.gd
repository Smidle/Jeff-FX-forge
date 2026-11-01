@tool
extends RefCounted
## 英文界面对照表：「中文原文 → 英文」。目前只放了几条示例，缺的条目会显示中文。
## 补全方法：运行 tests/extract_ui_text.gd 导出全部界面文字（tests/output/ui_text.tsv），把译文填进下面的 TABLE。
## 带 %s / %d 的文字，译文里要保留同样数量、同样顺序的占位符。

const TABLE := {
	"特效工坊": "FX Forge",
	"预设库": "Presets",
	"导出精灵图…": "Export Sprite Sheet…",
	"保存": "Save",
	"另存为…": "Save As…",
	"2D 画布": "2D Canvas",
	"3D 场景": "3D Scene",
	"3D 场景：把像素特效当作面向镜头的贴图放进三维世界，和参考角色同一比例，HD-2D 游戏里就是这样显示的。pixelfx 升级版和烟花默认用 3D 场景": "3D Scene: shows the pixel effect as a camera-facing sprite in a 3D world at the reference character's scale, the way HD-2D games display it. pixelfx upgrades and fireworks open in 3D by default",
	"HD-2D 场景": "HD-2D Scene",
	"放置：自动": "Place: Auto",
	"放置：脚底": "Place: Feet",
	"放置：身上（离地 0.8 米）": "Place: Body (0.8 m up)",
	"特效原点放在哪里。自动：原点画在画布下部的（爆炸、尘土、烟雾弹）放脚底，其余（刀光、命中）放身体高度。": "Where the effect's origin goes. Auto: effects whose origin is low on the canvas (explosions, dust, smoke bombs) sit at the feet; others (slashes, hits) at body height.",
	"在特效原点放一个约 1.9 米高的参考角色，用来对照大小。": "Places a ~1.9 m reference character at the effect's origin for scale.",
	"右键拖动转镜头 · 滚轮缩放": "Right-drag to orbit · Wheel to zoom",
}
