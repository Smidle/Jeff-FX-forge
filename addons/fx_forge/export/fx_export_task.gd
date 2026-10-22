@tool
extends RefCounted
## Owns the coroutine independently of the panel. Disabling the plugin cannot
## resume an await on a freed Control or reopen a stale result dialog.
const Exporter := preload("fx_exporter.gd")
func run(preset: Resource, settings: Dictionary, camera: Camera3D, recipient: WeakRef) -> void:
	var result: Dictionary = await Exporter.run(preset, settings, camera)
	var panel: Node = recipient.get_ref()
	if is_instance_valid(panel) and panel.is_inside_tree():
		panel.export_completed(result, settings)
