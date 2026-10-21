@tool
extends RefCounted
## 编辑会话：正在编辑的特效（工作副本）、来源、未保存标记，以及撤销 / 重做。
## 撤销动作挂在本对象（RefCounted）上，进入编辑器的全局历史，不会把正在编辑的场景标成未保存。

## scope：global（全局参数）/ layer（图层设置）/ param（模块参数）/ meta（名称等）/
##        structure（图层增删、排序）/ all（载入了新预设）
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
## 编辑器的 EditorUndoRedoManager（无头测试时为空，修改直接生效）。
## 用 Object 类型而不是 EditorUndoRedoManager：后者只在编辑器里存在，写死类型会让无头测试无法加载本脚本。
var undo: Object = null
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


## 结构性修改（增删 / 排序 / 复制图层）：整组图层的前后快照进撤销历史
func set_layers(new_layers: Array, select: int, action: String) -> void:
	if preset == null:
		return
	if undo == null:
		_apply_layers(_generation, new_layers.duplicate(true), select)
		return
	undo.create_action("特效工坊：" + action, UndoRedo.MERGE_DISABLE, self, false, false)
	undo.add_do_method(self, &"_apply_layers", _generation, new_layers.duplicate(true), select)
	undo.add_undo_method(self, &"_apply_layers", _generation, preset.layers.duplicate(true), layer_index)
	undo.commit_action()


func _apply_layers(generation: int, layers: Array, select: int) -> void:
	if generation != _generation or preset == null:
		return
	preset.layers = layers.duplicate(true)
	layer_index = clampi(select, 0, maxi(preset.layers.size() - 1, 0))
	dirty = true
	changed.emit("structure")


func add_layer(module_id: String) -> void:
	var l := FxPresetUtil.normalize_layer(FxPresetUtil.make_layer(module_id))
	if l.is_empty():
		return
	var layers := preset.layers.duplicate(true)
	layers.append(l)
	set_layers(layers, layers.size() - 1, "添加图层")


func remove_layer(i: int) -> void:
	if preset == null or preset.layers.size() <= 1 or i < 0 or i >= preset.layers.size():
		return
	var layers := preset.layers.duplicate(true)
	layers.remove_at(i)
	set_layers(layers, mini(i, layers.size() - 1), "删除图层")


## delta = +1：往上（盖在更上面，画得更晚）；-1：往下
func move_layer(i: int, delta: int) -> void:
	if preset == null:
		return
	var j := i + delta
	var n := preset.layers.size()
	if i < 0 or j < 0 or i >= n or j >= n:
		return
	var layers := preset.layers.duplicate(true)
	var tmp: Variant = layers[i]
	layers[i] = layers[j]
	layers[j] = tmp
	set_layers(layers, j, "调整图层顺序")


func duplicate_layer(i: int) -> void:
	if preset == null or i < 0 or i >= preset.layers.size():
		return
	var layers := preset.layers.duplicate(true)
	var copy: Dictionary = (layers[i] as Dictionary).duplicate(true)
	copy["name"] = str(copy.get("name", "")) + " 副本"
	layers.insert(i + 1, copy)
	set_layers(layers, i + 1, "复制图层")


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
