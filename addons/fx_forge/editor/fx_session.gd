@tool
extends RefCounted
## 编辑会话：正在编辑的特效（工作副本）、来源、未保存标记，以及撤销 / 重做。
## 撤销动作挂在本对象（RefCounted）上，进入编辑器的全局历史，不会把正在编辑的场景标成未保存。

## scope：global（全局参数）/ layer（图层设置）/ param（模块参数）/ meta（名称等）/ all
signal changed(scope: String)
signal loaded

const FxPreset := preload("../core/fx_preset.gd")
const FxPresetUtil := preload("../core/fx_preset_util.gd")

const USER_DIR := "res://fx_forge_presets/"

var preset: FxPreset = null
## 用户预设的文件路径；内置预设为空
var source_path := ""
## 内置预设 id（新建的空白特效两者都为空）
var builtin_id := ""
var dirty := false
var layer_index := 0
var undo: EditorUndoRedoManager = null
## 每次载入新预设加一；旧预设留下的撤销动作执行时发现代数不同就跳过
var _generation := 0


func load_preset(p: FxPreset, path: String = "", builtin: String = "") -> void:
	preset = p.clone()
	FxPresetUtil.fill_defaults(preset)
	source_path = path
	builtin_id = builtin
	dirty = false
	layer_index = 0
	_generation += 1
	loaded.emit()
	changed.emit("all")


func is_user_preset() -> bool:
	return not source_path.is_empty()


func layer_count() -> int:
	return preset.layers.size() if preset != null else 0


func get_value(scope: String, layer: int, id: String) -> Variant:
	if preset == null:
		return null
	match scope:
		"global":
			return preset.globals.get(id)
		"layer":
			return (preset.layers[layer] as Dictionary).get(id)
		"param":
			return ((preset.layers[layer] as Dictionary)["params"] as Dictionary).get(id)
		"meta":
			return preset.get(id)
	return null


## 修改一个值（进入撤销历史）。merge = true：并入上一次同名操作（一次连续拖动只算一步）
func set_value(scope: String, layer: int, id: String, value: Variant, merge: bool = false) -> void:
	set_values(scope, layer, {id: value}, merge)


func set_values(scope: String, layer: int, values: Dictionary, merge: bool = false) -> void:
	if preset == null:
		return
	var old := {}
	var any_change := false
	for id: String in values:
		old[id] = _copy(get_value(scope, layer, id))
		if not _same(old[id], values[id]):
			any_change = true
	if not any_change:
		return
	if undo == null:
		_apply(_generation, scope, layer, values)
		return
	var action := "特效工坊：修改 " + ", ".join(PackedStringArray(values.keys()))
	undo.create_action(action, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE, self, false, false)
	undo.add_do_method(self, &"_apply", _generation, scope, layer, values.duplicate(true))
	undo.add_undo_method(self, &"_apply", _generation, scope, layer, old)
	undo.commit_action()


func _apply(generation: int, scope: String, layer: int, values: Dictionary) -> void:
	if generation != _generation or preset == null:
		return
	if scope != "global" and scope != "meta" and layer >= preset.layers.size():
		return
	for id: String in values:
		var v: Variant = _copy(values[id])
		match scope:
			"global":
				preset.globals[id] = v
			"layer":
				(preset.layers[layer] as Dictionary)[id] = v
			"param":
				((preset.layers[layer] as Dictionary)["params"] as Dictionary)[id] = v
			"meta":
				preset.set(id, v)
	dirty = true
	changed.emit(scope)


## 保存到文件（成为用户预设）
func save_to(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var p: FxPreset = preset.clone()
	p.take_over_path(path)
	var err := ResourceSaver.save(p, path)
	if err == OK:
		source_path = path
		builtin_id = ""
		dirty = false
		changed.emit("meta")
	return err


static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	if v is PackedColorArray:
		return (v as PackedColorArray).duplicate()
	return v


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT or typeof(b) == TYPE_FLOAT:
		if (typeof(a) == TYPE_FLOAT or typeof(a) == TYPE_INT) and (typeof(b) == TYPE_FLOAT or typeof(b) == TYPE_INT):
			return is_equal_approx(float(a), float(b))
		return false
	return typeof(a) == typeof(b) and a == b
