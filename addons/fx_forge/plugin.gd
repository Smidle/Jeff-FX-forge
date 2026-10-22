@tool
extends EditorPlugin
## 插件入口：只负责注册「特效工坊」主屏幕标签页。
## 规则：这里只 preload 脚本，不预加载图片/场景（Godot 4.7 在首次导入资源前就会加载插件）。

const Placement := preload("editor/classic_placement.gd")
const I18n := preload("editor/i18n.gd")
const MainPanel := preload("editor/main_panel.gd")
const FxPreset := preload("core/fx_preset.gd")

var _placement := Placement.new()
var _panel: Control
var _placement_task := -1
var _placement_job: RefCounted
var _placement_generation := 0


func _enter_tree() -> void:
	_panel = MainPanel.new()
	_panel.name = "FxForgeMainPanel"
	_panel.setup(get_undo_redo())
	_panel.place_requested.connect(_begin_placement)
	set_input_event_forwarding_always_enabled()
	scene_changed.connect(func(_root: Node) -> void: _placement.cancel())
	_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_panel)
	_make_visible(false)


func _exit_tree() -> void:
	_placement_generation += 1
	if _placement_task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_placement_task)
		_placement_task = -1
	_placement.cancel()
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
	return "Jeff FX"


func _get_plugin_icon() -> Texture2D:
	var img := Image.new()
	if img.load_png_from_buffer(FileAccess.get_file_as_bytes("res://addons/fx_forge/legacy/assets/branding/explosion/logo_explosion_tab.png")) != OK:
		return null
	return ImageTexture.create_from_image(img)


func _handles(object: Object) -> bool:
	return object is FxPreset


func _edit(object: Object) -> void:
	if object != null and is_instance_valid(_panel):
		_panel.open_preset(object)


func _get_unsaved_status(for_scene: String) -> String:
	if not for_scene.is_empty() or not is_instance_valid(_panel):
		return ""
	if _panel.has_unsaved_changes():
		return _panel.unsaved_message()
	return ""


func _save_external_data() -> void:
	if is_instance_valid(_panel):
		_panel.save_if_possible()


func _begin_placement(preset: Resource) -> void:
	if _placement_task >= 0:
		return
	var root := EditorInterface.get_edited_scene_root()
	var generation := _placement_generation
	var animation: Resource
	if preset.legacy_recipe == null and (root is Node3D or root is Node2D):
		_placement_job = preload("core/fx_renderer.gd").make_job(preset)
		_placement_task = preload("core/fx_renderer.gd").start_async(_placement_job)
		_panel._status.text = I18n.T("正在准备场景动画……")
		while not WorkerThreadPool.is_group_task_completed(_placement_task):
			await get_tree().process_frame
			if generation != _placement_generation:
				return
		WorkerThreadPool.wait_for_group_task_completion(_placement_task)
		_placement_task = -1
		animation = preload("runtime/sprite_animation.gd").from_job(_placement_job)
		_placement_job = null
		if root != EditorInterface.get_edited_scene_root():
			return
	var recipe: Resource = preset.legacy_recipe if preset.legacy_recipe != null else preset
	if _placement.begin(recipe, root, get_undo_redo(), animation):
		EditorInterface.set_main_screen_editor("2D" if root is Node2D else "3D")
		update_overlays()
	else:
		_panel._result_dialog.dialog_text = I18n.T("请先打开场景：经典效果需要 Node3D 根节点，像素效果支持 Node3D 或 Node2D。点击选择位置，Esc 或右键取消。")
		_panel._result_dialog.popup_centered()

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var consumed := _placement.input_2d(event)
	if consumed: update_overlays()
	return consumed

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _placement.active() or not _placement.scene is Node2D:
		return
	var font := EditorInterface.get_editor_theme().get_font(&"main", &"EditorFonts")
	overlay.draw_style_box(preload("editor/workshop_theme.gd").box(Color("132438"), Color("73dfbb")), Rect2(12, 12, 480, 38))
	overlay.draw_string(font, Vector2(24, 37), I18n.T("Jeff FX · 点击画布放置 · Esc / 右键取消"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e1edf4"))

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _placement.input(camera, event):
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	if not _placement.active():
		return
	var font := EditorInterface.get_editor_theme().get_font(&"main", &"EditorFonts")
	overlay.draw_style_box(preload("editor/workshop_theme.gd").box(Color("132438"), Color("73dfbb")), Rect2(12, 12, 480, 38))
	overlay.draw_string(font, Vector2(24, 37), I18n.T("Jeff FX · 点击地面放置 · Esc / 右键取消"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e1edf4"))

func _process(_delta: float) -> void:
	_placement.tick()
	if _placement.active() and EditorInterface.get_edited_scene_root() != _placement.scene:
		_placement.cancel()
