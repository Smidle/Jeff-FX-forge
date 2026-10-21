@tool
extends EditorPlugin
## 插件入口：只负责注册「特效工坊」主屏幕标签页。
## 规则：这里只 preload 脚本，不预加载图片/场景（Godot 4.7 在首次导入资源前就会加载插件）。

const MainPanel := preload("editor/main_panel.gd")
const FxPreset := preload("core/fx_preset.gd")

var _panel: Control


func _enter_tree() -> void:
	_panel = MainPanel.new()
	_panel.name = "FxForgeMainPanel"
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	if is_instance_valid(_panel):
		_panel.shutdown()
		_panel.queue_free()
	_panel = null


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_panel):
		_panel.visible = visible


func _get_plugin_name() -> String:
	return "特效工坊"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"AnimatedSprite2D", &"EditorIcons")


func _handles(object: Object) -> bool:
	return object is FxPreset


func _edit(object: Object) -> void:
	if object != null and is_instance_valid(_panel):
		_panel.open_preset(object)


func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(_panel):
		return ""
	if _panel.has_unsaved_changes():
		return "特效工坊里的预设有未保存的修改。"
	return ""


func _save_external_data() -> void:
	if is_instance_valid(_panel):
		_panel.save_if_possible()
