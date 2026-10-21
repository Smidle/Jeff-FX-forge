extends SceneTree
## 运行时检查：导出的即用场景在游戏里能播放；一次性特效播完自动删除，循环特效持续播放；
## 演示场景能找到全部导出的特效。
##   godot --headless --fixed-fps 60 --path . --script res://tests/runtime_check.gd

const EXPORT_DIR := "res://fx_exports/"
const RUN_SECONDS := 3.0

var _nodes := {}
var _loops := {}
var _elapsed := 0.0
var _checked_playing := false
var _demo: Node
var _errors := PackedStringArray()


func _initialize() -> void:
	var files := DirAccess.get_files_at(EXPORT_DIR) if DirAccess.dir_exists_absolute(EXPORT_DIR) else PackedStringArray()
	for f: String in files:
		if not f.ends_with(".tscn"):
			continue
		var ps := load(EXPORT_DIR + f) as PackedScene
		if ps == null:
			_errors.append("无法加载 " + f)
			continue
		var node := ps.instantiate() as AnimatedSprite2D
		if node == null:
			_errors.append(f + " 的根节点不是 AnimatedSprite2D")
			continue
		_loops[f] = node.sprite_frames.get_animation_loop(StringName(node.autoplay))
		root.add_child(node)
		_nodes[f] = node
	if _nodes.is_empty():
		_errors.append("res://fx_exports/ 下没有导出的场景")
	_demo = (load("res://demo/demo.tscn") as PackedScene).instantiate()
	root.add_child(_demo)


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _checked_playing and _elapsed > 0.05:
		_checked_playing = true
		for f: String in _nodes:
			var n: AnimatedSprite2D = _nodes[f]
			if not n.is_playing():
				_errors.append(f + " 没有自动播放")
	if _elapsed < RUN_SECONDS:
		return false
	for f: String in _nodes:
		var alive := is_instance_valid(_nodes[f])
		if _loops[f] and not alive:
			_errors.append(f + "：循环特效不应被删除")
		elif not _loops[f] and alive:
			_errors.append(f + "：一次性特效播完没有自动删除")
		else:
			print("  ok    %s（%s）" % [f, "循环，持续播放" if _loops[f] else "一次性，播完已自动删除"])
	var found: int = (_demo.get("_scenes") as Array).size()
	if found != _nodes.size():
		_errors.append("演示场景找到 %d 个特效，应为 %d 个" % [found, _nodes.size()])
	else:
		print("  ok    演示场景找到全部 %d 个特效" % found)
	print("FXFORGE_RUNTIME: " + ("PASS" if _errors.is_empty() else "FAIL"))
	for e in _errors:
		print("  - ", e)
	quit(0 if _errors.is_empty() else 1)
	return true
