@tool
extends RefCounted
## 特效模块基类。
## 模块必须无状态：所有随机数据都放进 prepare() 返回的字典；render() 只读参数和这个字典、
## 只写传进来的画布——这样各帧才能在多个工作线程里同时渲染。
## 子类也要写 @tool（@tool 不会被继承）。

const FxBuffer := preload("../core/fx_buffer.gd")
const FxContext := preload("../core/fx_context.gd")


func get_id() -> String:
	return ""


func get_display_name() -> String:
	return ""


func get_display_name_en() -> String:
	return ""


func get_description() -> String:
	return ""


## 是否受「方向」影响（多方向批量导出时用）
func is_directional() -> bool:
	return false


## 参数说明表，见 core/fx_params.gd
func get_param_defs() -> Array:
	return []


## 新建这种图层时的默认图层设置（例如粒子默认用辅色板、不描边）
func get_layer_defaults() -> Dictionary:
	return {}


## 主线程调用：生成只读数据（随机表、噪声表……）。rng 已按图层种子初始化。
func prepare(_p: Dictionary, _ctx: FxContext, _rng: RandomNumberGenerator) -> Dictionary:
	return {}


## 工作线程调用：把图层本地时间 u（0~1）时刻画进 buf。
## 返回图层整体可见度（0~1），小于 1 时按「消散方式」变淡。
func render(_buf: FxBuffer, _p: Dictionary, _state: Dictionary, _u: float, _ctx: FxContext) -> float:
	return 1.0
