@tool
extends RefCounted
## A static coroutine survives its caller without an unretained temporary
## RefCounted instance. The weak recipient also allows safe plugin shutdown.
const Exporter := preload("fx_exporter.gd")
static func run(preset: Resource, settings: Dictionary, camera: Camera3D, recipient: WeakRef) -> void:
	var result: Dictionary = await Exporter.run(preset, settings, camera)
	var panel: Node = recipient.get_ref()
	if is_instance_valid(panel) and panel.is_inside_tree():
		panel.export_completed(result, settings)
