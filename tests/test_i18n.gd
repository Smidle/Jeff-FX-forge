extends "res://tests/test_base.gd"
## 多语言结构测试：界面脚本里的中文文字都经过 I18n.T()；翻译表的占位符一致；切换语言后取到译文、缺译文时退回中文。

const I18n := preload("res://addons/fx_forge/editor/i18n.gd")
const LangEn := preload("res://addons/fx_forge/editor/lang_en.gd")

## 要检查的界面脚本（自检脚本只给开发者看，不翻译）
const UI_SCRIPTS := [
	"res://addons/fx_forge/plugin.gd",
	"res://addons/fx_forge/editor/main_panel.gd",
	"res://addons/fx_forge/editor/param_panel.gd",
	"res://addons/fx_forge/editor/preset_browser.gd",
	"res://addons/fx_forge/editor/preview_stage.gd",
	"res://addons/fx_forge/editor/timeline.gd",
	"res://addons/fx_forge/editor/export_dialog.gd",
	"res://addons/fx_forge/editor/palette_editor.gd",
	"res://addons/fx_forge/editor/fx_session.gd",
]


func test_ui_text_goes_through_i18n() -> bool:
	var lit := RegEx.create_from_string("\"(?:[^\"\\\\]|\\\\.)*\"")
	var han := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")
	var missing := PackedStringArray()
	for path: String in UI_SCRIPTS:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for k in lines.size():
			var code := _strip_comment(lines[k])
			var st := code.strip_edges()
			if st.is_empty() or st.begins_with("const ") or st.begins_with("@") or st.begins_with("signal ") or st.begins_with("func ") or st.begins_with("static func "):
				continue
			for m in lit.search_all(code):
				if han.search(m.get_string()) == null:
					continue
				var before := code.substr(0, m.get_start())
				if not before.ends_with("I18n.T("):
					missing.append("%s:%d %s" % [path.get_file(), k + 1, m.get_string()])
	check(missing.is_empty(), "界面文字都经过 I18n.T()，漏掉的：\n  " + "\n  ".join(missing))
	return true


func test_translation_lookup() -> bool:
	check_eq(I18n.T("特效工坊"), "特效工坊", "中文界面原样返回")
	I18n.language = "en"
	check_eq(I18n.T("特效工坊"), "FX Forge", "英文界面取到译文")
	check_eq(I18n.T("还没有翻译的文字"), "还没有翻译的文字", "缺译文时退回中文")
	check_eq(I18n.label({"label": "宽度", "label_en": "Width"}), "Width", "参数名取英文名")
	I18n.language = "zh"
	check_eq(I18n.label({"label": "宽度", "label_en": "Width"}), "宽度", "切回中文")
	return true


func test_translation_placeholders_match() -> bool:
	var spec := RegEx.create_from_string("%[sdf%]|%\\.\\d+f")
	for zh: String in LangEn.TABLE:
		var a := spec.search_all(zh).map(func(m: RegExMatch) -> String: return m.get_string())
		var b := spec.search_all(str(LangEn.TABLE[zh])).map(func(m: RegExMatch) -> String: return m.get_string())
		check_eq(b, a, "「%s」的译文占位符和原文一致" % zh)
	return true


## 去掉行尾注释（字符串里的 # 不算）
func _strip_comment(line: String) -> String:
	var in_str := false
	var q := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if in_str:
			if c == "\\":
				i += 2
				continue
			if c == q:
				in_str = false
		elif c == "\"" or c == "'":
			in_str = true
			q = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line
