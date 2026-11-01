extends RefCounted
## 测试场景列表与切换。
## 月下庭院大门前的传送阵按这个顺序进入「下一个」；各场景的 Esc 菜单也按这个顺序列出。
## 切换时先淡到黑屏、换场景、再淡回来；遮罩挂在根节点上，换场景时不会被一起释放。

const LIST := [
	{"name": "月下庭院", "path": "res://scenes/moon_temple/main.tscn", "desc": "2D 武侠庭院：角色、技能和按键（主场景，F5）"},
	{"name": "等距测试场", "path": "res://scenes/iso_lab.tscn", "desc": "3D 斜视场景里试放全部效果和追踪飞弹"},
	{"name": "夏日花火大会", "path": "res://scenes/festival.tscn", "desc": "夜晚的 HD-2D 海港：按「放烟花」，镜头升向夜空看一场烟花大会"},
	{"name": "3D 分类试验场", "path": "res://scenes/fx_library_lab.tscn", "desc": "按分类检查三维效果的尺寸、运动、跟随和遮挡"},
]
const FADE_OUT := 0.3
const FADE_IN := 0.35


static func index_of(path: String) -> int:
	for i in LIST.size():
		if LIST[i]["path"] == path:
			return i
	return -1


## 列表里的下一个场景（最后一个之后回到第一个）
static func next_of(path: String) -> Dictionary:
	return LIST[(index_of(path) + 1) % LIST.size()]


## 当前场景的路径。主场景在 _ready 里调用时 current_scene 可能还没设好，就取根节点下最后一个场景
static func current_path(tree: SceneTree) -> String:
	if tree.current_scene != null:
		return tree.current_scene.scene_file_path
	for i in range(tree.root.get_child_count() - 1, -1, -1):
		var node := tree.root.get_child(i)
		if not node.scene_file_path.is_empty():
			return node.scene_file_path
	return ""


## 淡出 → 切换场景 → 淡入。暂停中也能进行（Esc 菜单里点选时游戏是暂停的）。
static func change(tree: SceneTree, path: String) -> void:
	if tree.root.has_node("SceneFade"):
		return
	var overlay := CanvasLayer.new()
	overlay.name = "SceneFade"
	overlay.layer = 128
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.05, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	tree.root.add_child(overlay)
	var tween := overlay.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(shade, "color:a", 1.0, FADE_OUT)
	tween.tween_callback(func() -> void:
		tree.paused = false
		tree.change_scene_to_file(path))
	# 新场景搭建世界要几帧，稍等再淡回来
	tween.tween_interval(0.2)
	tween.tween_property(shade, "color:a", 0.0, FADE_IN)
	tween.tween_callback(overlay.queue_free)
