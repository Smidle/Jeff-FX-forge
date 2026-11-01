@tool
extends RefCounted
## Optional static factory. No autoload or manager is required.
## Accepts a workbench FxForgePreset or a JeffForge3DPreset recipe.
## Paths/targets use world coordinates; target_offset is target-local.
const Preset := preload("../core/fx_preset.gd")
const Recipe := preload("../legacy/runtime/fx_preset.gd")
const Layer := preload("../legacy/runtime/fx_layer.gd")
const Instance := preload("../legacy/runtime/fx_instance.gd")

static func spawn(preset: Resource, parent: Node, world_transform: Transform3D = Transform3D.IDENTITY, options: Dictionary = {}) -> Instance:
	var recipe := _copy_recipe(preset)
	if recipe == null or not _valid_parent(parent) or not _finite_transform(world_transform): return null
	var effect := _attach(recipe, parent, world_transform, options)
	if effect != null: effect.play()
	return effect

static func spawn_between(preset: Resource, parent: Node, start: Vector3, end: Vector3, options: Dictionary = {}) -> Instance:
	if not start.is_finite() or not end.is_finite() or not _valid_parent(parent): return null
	var recipe := _copy_recipe(preset)
	if recipe == null or not _set_endpoints(recipe, Vector3.ZERO, end - start): return null
	var effect := _attach(recipe, parent, Transform3D(Basis.IDENTITY, start), options)
	if effect != null: effect.play()
	return effect

static func spawn_to(preset: Resource, parent: Node, start: Vector3, target: Node3D, target_offset: Vector3 = Vector3.ZERO, options: Dictionary = {}) -> Instance:
	if not start.is_finite() or not target_offset.is_finite() or not _valid_parent(parent): return null
	if not is_instance_valid(target) or not target.is_inside_tree() or target.is_queued_for_deletion(): return null
	var end := target.to_global(target_offset)
	if not end.is_finite(): return null
	var recipe := _copy_recipe(preset)
	if recipe == null or not recipe.has_missile(): return null
	_set_endpoints(recipe, Vector3.ZERO, end - start)
	var effect := _attach(recipe, parent, Transform3D(Basis.IDENTITY, start), options)
	if effect == null: return null
	# Autoplay is disabled before attachment, so no frame can precede binding.
	effect.bind_target(target, target_offset)
	effect.play()
	return effect

static func _copy_recipe(preset: Resource) -> Recipe:
	if preset is Recipe: return preset.copy()
	if preset is Preset and preset.legacy_recipe is Recipe: return preset.legacy_recipe.copy()
	return null

static func _valid_parent(parent: Node) -> bool:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or parent.is_queued_for_deletion(): return false
	if parent is Node3D:
		return _finite_transform(parent.global_transform) and absf(parent.global_basis.determinant()) > 0.000001
	return true

static func _finite_transform(value: Transform3D) -> bool:
	return value.origin.is_finite() and value.basis.x.is_finite() and value.basis.y.is_finite() and value.basis.z.is_finite() and absf(value.basis.determinant()) > 0.000001

static func _set_endpoints(recipe: Recipe, start: Vector3, end: Vector3) -> bool:
	var supported := false
	for layer: Layer in recipe.layers:
		if layer.kind == Layer.Kind.MISSILE and layer.missile != null:
			layer.missile.start = start
			layer.missile.end = end
			supported = true
		elif layer.kind == Layer.Kind.PROCEDURAL and layer.procedural_motion in [Layer.ProceduralMotion.STREAK, Layer.ProceduralMotion.ARC]:
			# Legacy CPU paths apply effect_scale internally; invert it here so the
			# two world anchors remain fixed while only the appearance is scaled.
			var scale := maxf(0.001, recipe.effect_scale)
			layer.path_start = start / scale - layer.offset
			layer.path_end = end / scale - layer.offset
			supported = true
	return supported

static func _attach(recipe: Recipe, parent: Node, world_transform: Transform3D, options: Dictionary) -> Instance:
	var effect := Instance.new()
	effect.autoplay = false
	effect.auto_free = bool(options.get("auto_free", true))
	effect.preview_enabled = bool(options.get("preview", false))
	effect.quality = int(options.get("quality", Instance.Quality.AUTO))
	effect.backend = int(options.get("backend", Instance.Backend.AUTO))
	effect.preset = recipe
	parent.add_child(effect)
	effect.global_transform = world_transform
	return effect
