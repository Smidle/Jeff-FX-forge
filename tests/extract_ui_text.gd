extends SceneTree
## 导出全部待翻译的界面文字（做英文界面时用）：
##   godot --headless --path . --script res://tests/extract_ui_text.gd
## 输出 tests/output/ui_text.tsv：每行「中文<TAB>已有英文译文」。来源：
##   界面脚本里所有 I18n.T("…")、参数名（带英文名）、选项、分组名、模块名和说明、色板 / 主题名、分类名、内置预设名和说明。
## 把译文填进 addons/fx_forge/editor/lang_en.gd 的 TABLE 即可。

const LangEn := preload("res://addons/fx_forge/editor/lang_en.gd")
const FxGlobals := preload("res://addons/fx_forge/core/fx_globals.gd")
const FxPalette := preload("res://addons/fx_forge/core/fx_palette.gd")
const FxRegistry := preload("res://addons/fx_forge/core/fx_registry.gd")
const FxPreset := preload("res://addons/fx_forge/core/fx_preset.gd")
const FxExport := preload("res://addons/fx_forge/export/fx_export.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")

const OUT := "res://tests/output/ui_text.tsv"

var _rows := {}


func _initialize() -> void:
	var call := RegEx.create_from_string("I18n\\.T\\(\"((?:[^\"\\\\]|\\\\.)*)\"\\)")
	for dir: String in ["res://addons/fx_forge/", "res://addons/fx_forge/editor/"]:
		for f: String in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				for m in call.search_all(FileAccess.get_file_as_string(dir + f)):
					_add(m.get_string(1).c_unescape(), "")
	for d: Dictionary in FxGlobals.global_defs() + FxGlobals.layer_defs():
		_add_def(d)
	for g: String in FxGlobals.GROUP_NAMES:
		_add(FxGlobals.GROUP_NAMES[g], "")
	for id: String in FxRegistry.module_ids():
		var m: RefCounted = FxRegistry.get_module(id)
		_add(m.get_display_name(), m.get_display_name_en())
		_add(m.get_description(), "")
		for d: Dictionary in m.get_param_defs():
			_add_def(d)
	for id: String in FxPalette.PALETTES:
		_add(FxPalette.PALETTES[id][0], FxPalette.PALETTES[id][1])
	for id: String in FxPalette.THEMES:
		_add(FxPalette.THEMES[id][0], FxPalette.THEMES[id][1])
	for c: String in FxPreset.CATEGORY_NAMES:
		_add(FxPreset.CATEGORY_NAMES[c], "")
	for opts: Array in [FxExport.LAYOUT_OPTIONS, FxExport.DIRECTION_OPTIONS, FxExport.BLEND_OPTIONS, FxExport.GIF_BG_OPTIONS]:
		for o: Array in opts:
			_add(str(o[1]), "")
	for p: FxPreset in Builtin.all():
		_add(p.display_name, "")
		_add(p.description, "")
	var keys := _rows.keys()
	keys.sort()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_line("中文\t英文")
	var done := 0
	for k: String in keys:
		var en: String = LangEn.TABLE.get(k, _rows[k])
		if not en.is_empty():
			done += 1
		f.store_line("%s\t%s" % [k.c_escape(), en.c_escape()])
	f.close()
	print("共 %d 条界面文字，已有译文 %d 条 → %s" % [keys.size(), done, ProjectSettings.globalize_path(OUT)])
	quit(0)


func _add_def(d: Dictionary) -> void:
	_add(str(d.get("label", "")), str(d.get("label_en", "")))
	_add(str(d.get("tip", "")), "")
	_add(str(d.get("unit", "")), "")
	for o: Array in d.get("options", []):
		_add(str(o[1]), "")


func _add(zh: String, en: String) -> void:
	if zh.is_empty() or zh.is_valid_float():
		return
	if not _rows.has(zh) or str(_rows[zh]).is_empty():
		_rows[zh] = en
