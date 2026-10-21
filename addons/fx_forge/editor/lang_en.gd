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
}
