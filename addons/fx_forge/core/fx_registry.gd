@tool
extends RefCounted
## 特效模块注册表。新增模块：写好 modules/xxx.gd，再在 _SCRIPTS 里加一行。

const FxModule := preload("../modules/fx_module.gd")

const _SCRIPTS := {
	"arc": preload("../modules/arc.gd"),
	"burst": preload("../modules/burst.gd"),
	"ring": preload("../modules/ring.gd"),
	"particles": preload("../modules/particles.gd"),
	"streak": preload("../modules/streak.gd"),
}

## 模块实例无状态，全局共用一份（在主线程加载脚本时创建）
static var _modules: Dictionary = _create_all()


static func _create_all() -> Dictionary:
	var out := {}
	for id: String in _SCRIPTS:
		out[id] = (_SCRIPTS[id] as Script).new()
	return out


static func get_module(id: String) -> FxModule:
	return _modules.get(id)


static func has_module(id: String) -> bool:
	return _modules.has(id)


static func module_ids() -> Array:
	return _SCRIPTS.keys()
