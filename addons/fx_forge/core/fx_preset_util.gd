@tool
extends RefCounted
## 预设的构造、规范化与迁移。

const FxPreset := preload("fx_preset.gd")
const FxParams := preload("fx_params.gd")
const FxGlobals := preload("fx_globals.gd")
const FxRegistry := preload("fx_registry.gd")
const FxModule := preload("../modules/fx_module.gd")


## 从简写字典创建预设：{id, name, category, description, globals, layers: [{module, name, params, ……图层设置}]}
static func from_dict(d: Dictionary) -> FxPreset:
	var p := FxPreset.new()
	p.preset_id = str(d.get("id", ""))
	p.display_name = str(d.get("name", p.preset_id))
	p.category = str(d.get("category", "custom"))
	p.description = str(d.get("description", ""))
	p.globals = (d.get("globals", {}) as Dictionary).duplicate(true)
	var layers: Array = []
	for l: Dictionary in d.get("layers", []):
		layers.append(make_layer(str(l.get("module", "arc")), str(l.get("name", "")), l.get("params", {}), l))
	p.layers = layers
	p.export_settings = (d.get("export", {}) as Dictionary).duplicate(true)
	return p


## 新建图层字典：先用图层设置默认值，再套模块自己的默认设置（get_layer_defaults），最后套 opts
static func make_layer(module_id: String, name: String = "", params: Dictionary = {}, opts: Dictionary = {}) -> Dictionary:
	var layer := FxParams.defaults(FxGlobals.layer_defs())
	var m: FxModule = FxRegistry.get_module(module_id)
	var module_defaults: Dictionary = m.get_layer_defaults() if m != null else {}
	for d: Dictionary in FxGlobals.layer_defs():
		var id: String = d["id"]
		if opts.has(id):
			layer[id] = opts[id]
		elif module_defaults.has(id):
			layer[id] = module_defaults[id]
	layer["module"] = module_id
	if name.is_empty():
		name = m.get_display_name() if m != null else module_id
	layer["name"] = name
	layer["params"] = params.duplicate(true)
	return layer


## 单个图层补齐并校正（模块参数也补齐）；未知模块返回空字典
static func normalize_layer(l: Dictionary) -> Dictionary:
	var module_id := str(l.get("module", ""))
	var m: FxModule = FxRegistry.get_module(module_id)
	if m == null:
		return {}
	var nl := FxParams.normalize(FxGlobals.layer_defs(), l)
	nl["module"] = module_id
	nl["name"] = str(l.get("name", m.get_display_name()))
	var params: Variant = l.get("params", {})
	nl["params"] = FxParams.normalize(m.get_param_defs(), params if params is Dictionary else {})
	return nl


## 规范化：补齐缺省、校正非法值、丢掉未知模块的图层（不改原件）。
## 返回 {globals: Dictionary, layers: Array}，图层里的 params 也已补齐。
static func normalized(preset: FxPreset) -> Dictionary:
	var g := FxParams.normalize(FxGlobals.global_defs(), preset.globals)
	var layers: Array = []
	for raw: Variant in preset.layers:
		if raw is Dictionary:
			var nl := normalize_layer(raw)
			if not nl.is_empty():
				layers.append(nl)
	return {"globals": g, "layers": layers}


## 把预设原地补齐成完整参数（编辑器打开预设时用，便于界面直接读写）
static func fill_defaults(preset: FxPreset) -> void:
	if preset.legacy_recipe != null:
		return
	var norm := normalized(preset)
	preset.globals = norm["globals"]
	preset.layers = norm["layers"]
	preset.format_version = FxPreset.FORMAT_VERSION


static func new_blank() -> FxPreset:
	var p := from_dict({"id": "new_effect", "name": "新特效", "category": "custom", "layers": [{"module": "arc"}]})
	fill_defaults(p)
	return p
