@tool
extends VBoxContainer
## 「特效工坊」主界面（M0 占位，M2 替换为完整界面）


func _init() -> void:
	var label := Label.new()
	label.text = "特效工坊（开发中）"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)


func shutdown() -> void:
	pass


func open_preset(_preset: Resource) -> void:
	pass


func has_unsaved_changes() -> bool:
	return false


func save_if_possible() -> void:
	pass
