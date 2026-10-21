extends RefCounted
## 测试基类：断言失败只记录、不中断；每个测试函数最后 return true，
## 运行器据此识别「中途被脚本错误打断」的测试。

const OUTPUT_DIR := "res://tests/output/"

var errors: PackedStringArray = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		errors.append(msg)


func check_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if typeof(actual) != typeof(expected) and not (_is_number(actual) and _is_number(expected)):
		errors.append("%s（类型不同：实际 %s，期望 %s）" % [msg, type_string(typeof(actual)), type_string(typeof(expected))])
	elif actual != expected:
		errors.append("%s（实际 %s，期望 %s）" % [msg, str(actual), str(expected)])


func check_near(actual: float, expected: float, eps: float, msg: String) -> void:
	if absf(actual - expected) > eps:
		errors.append("%s（实际 %f，期望 %f ± %f）" % [msg, actual, expected, eps])


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
