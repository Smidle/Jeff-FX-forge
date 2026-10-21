extends "res://tests/test_base.gd"
## 编辑会话测试（无撤销管理器时修改直接生效）：图层增删排序复制、新图层的默认设置、过期撤销动作被忽略

const FxSession := preload("res://addons/fx_forge/editor/fx_session.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")


func _session(id: String) -> FxSession:
	var s := FxSession.new()
	s.load_preset(Builtin.find(id), "", id)
	return s


func test_layer_operations() -> bool:
	var s := _session("hit_heavy")
	check_eq(s.layer_count(), 3, "重击有 3 个图层")
	s.add_layer("streak")
	check_eq(s.layer_count(), 4, "添加后 4 个图层")
	check_eq(s.layer_index, 3, "新图层被选中")
	check_eq(s.preset.layers[3]["module"], "streak", "新图层是冲刺线")
	check((s.preset.layers[3]["params"] as Dictionary).has("length"), "新图层的模块参数已补齐")
	s.move_layer(3, -1)
	check_eq(s.preset.layers[2]["module"], "streak", "下移一层")
	check_eq(s.layer_index, 2, "选中跟着移动")
	s.duplicate_layer(2)
	check_eq(s.layer_count(), 5, "复制后 5 个图层")
	check(str(s.preset.layers[3]["name"]).ends_with("副本"), "副本名字带「副本」")
	s.remove_layer(0)
	check_eq(s.layer_count(), 4, "删除后 4 个图层")
	check(s.dirty, "结构修改标记为未保存")
	while s.layer_count() > 1:
		s.remove_layer(0)
	s.remove_layer(0)
	check_eq(s.layer_count(), 1, "至少保留一个图层")
	s.move_layer(0, 1)
	check_eq(s.layer_count(), 1, "越界移动被忽略")
	return true


func test_new_layer_uses_module_defaults() -> bool:
	var s := _session("slash_basic")
	s.add_layer("particles")
	var l: Dictionary = s.preset.layers[1]
	check_eq(l["palette_slot"], "accent", "粒子图层默认用辅色板")
	check_eq(l["outline"], false, "粒子图层默认不描边")
	s.add_layer("ring")
	check_eq(s.preset.layers[2]["palette_slot"], "main", "环图层用主色板")
	return true


func test_set_value_and_layer_name() -> bool:
	var s := _session("slash_basic")
	s.set_value("param", 0, "radius", 30.0)
	check_eq(s.get_value("param", 0, "radius"), 30.0, "修改模块参数")
	s.set_value("layer", 0, "name", "新名字")
	check_eq(s.preset.layers[0]["name"], "新名字", "修改图层名")
	return true


func test_stale_undo_is_ignored() -> bool:
	var s := _session("slash_basic")
	var old_gen: int = s._generation
	s.load_preset(Builtin.find("hit_basic"), "", "hit_basic")
	s._apply(old_gen, "global", -1, {"seed": 999})
	check_eq(s.get_value("global", -1, "seed"), 1, "旧预设留下的撤销动作不影响新预设")
	s._apply_layers(old_gen, [], 0)
	check_eq(s.layer_count(), 1, "旧预设的结构撤销也被忽略")
	check(not s.dirty, "新预设仍是未修改状态")
	return true
