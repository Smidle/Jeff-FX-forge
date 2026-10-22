@tool
class_name FxForgePreset
extends Resource
## 特效预设：全局参数 + 图层列表。
## 参数都存在字典里，加载时按参数说明表补齐/校正，所以以后增删参数不会让旧预设失效。
## 注意：load() 返回的是共享缓存，编辑前先 clone()。

const FORMAT_VERSION := 1

## 分类 id → 中文名
const CATEGORY_NAMES := {
	"combat": "战斗打击",
	"element": "爆炸与元素",
	"magic": "魔法与状态",
	"env": "环境与通用",
	"custom": "我的预设",
	"classic_environment": "经典 · 环境", "classic_wuxia": "经典 · 武侠",
	"classic_xianxia": "经典 · 仙侠", "classic_magic": "经典 · 魔法",
}

@export var format_version: int = FORMAT_VERSION
@export var preset_id: String = ""
@export var display_name: String = ""
@export var category: String = "custom"
@export_multiline var description: String = ""
## 全局参数（画布、时间、方向、外观、描边……），键见 fx_globals.gd
@export var legacy_recipe: Resource
@export var preview_png: PackedByteArray = PackedByteArray()

@export var globals: Dictionary = {}
## 图层列表，每项是一个 Dictionary：module / name / enabled / params ……，见 fx_preset_util.gd
@export var layers: Array = []
## 上一次导出时的设置
@export var export_settings: Dictionary = {}


## 深拷贝出一份可以随便改的副本
func clone() -> Resource:
	var copy: Resource = (get_script() as Script).new()
	copy.format_version = format_version
	copy.preset_id = preset_id
	copy.display_name = display_name
	copy.category = category
	copy.description = description
	copy.globals = globals.duplicate(true)
	copy.layers = layers.duplicate(true)
	copy.export_settings = export_settings.duplicate(true)
	copy.preview_png = preview_png.duplicate()
	copy.legacy_recipe = legacy_recipe.copy() if legacy_recipe != null else null
	return copy


func get_category_name() -> String:
	return CATEGORY_NAMES.get(category, category)
