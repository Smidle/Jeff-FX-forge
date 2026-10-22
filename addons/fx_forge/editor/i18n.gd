@tool
extends RefCounted
## 界面多语言（结构已就位，目前只有中文）。
## 用法：界面上显示的文字一律写成 I18n.T("中文原文")——中文原文就是键（和 Godot 的 tr()、gettext 一样），
## 其他语言在 lang_xx.gd 的 TABLE 里补「中文原文 → 译文」，缺的条目自动显示中文。
## 参数说明表和模块自带英文名（label_en、get_display_name_en），用 label() / module_name() 取当前语言的名字。
## 单元测试会检查界面脚本里没有漏掉 I18n.T() 的中文文字。

const LangEn := preload("lang_en.gd")

## 当前界面语言："zh" = 中文。英文表补全后可以改成 "en"，或者跟随编辑器语言
static var language := "zh"


## 界面文字：返回当前语言的译文，没有译文时返回中文原文
static func T(text: String) -> String:
	if language == "zh" or text.is_empty():
		return text
	if language == "en":
		return LangEn.TABLE.get(text, text)
	return text


## 参数说明表里一项参数的名字
static func label(d: Dictionary) -> String:
	if language != "zh" and not str(d.get("label_en", "")).is_empty():
		return d["label_en"]
	return T(str(d.get("label", d.get("id", ""))))


## 模块名
static func module_name(m: Object) -> String:
	if m == null:
		return ""
	if language != "zh":
		var en := str(m.call(&"get_display_name_en"))
		if not en.is_empty():
			return en
	return T(str(m.call(&"get_display_name")))
