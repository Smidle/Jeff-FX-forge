extends Node
## 等距测试场（路线 A）：3D 场景 + 斜视镜头，现有像素角色以面向镜头的平面贴图出现。
## 三维配方（Codex 制作的效果库和 Claude 制作的追踪飞弹）作为真 3D 实例运行；
## Claude 制作的像素效果在运行时渲染成帧，以平面贴图播放。
## 布景（八方旅人素材搭的林间遗迹营地、光照）在 iso_stage.gd；这里负责角色、镜头、界面和播放效果。
const STAGE := preload("res://scenes/iso_stage.tscn")
const POST_SHADER := preload("res://assets/iso_stage/hd2d_post.gdshader")
const Classic := preload("res://addons/fx_forge/presets/classic_presets.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const Catalog := preload("res://addons/fx_forge/presets/library_catalog.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const Instance := preload("res://addons/fx_forge/legacy/runtime/fx_instance.gd")
const FX3D := preload("res://addons/fx_forge/runtime/fx_3d.gd")
const FONT := preload("res://assets/courtyard/fonts/Unifont16.otf")
const HERO_FRAMES := preload("res://assets/courtyard/hero_frames.tres")
const BANDIT_FRAMES := preload("res://assets/moon_temple/bandit1_frames.tres")
const SceneMenu := preload("res://scripts/scene_menu.gd")
const Scenes := preload("res://scripts/test_scenes.gd")

## 角色约 45 像素高 → 约 1.7 米。庭院里角色放大 3 倍、像素效果放大 1.5 倍，这里保持同样的相对比例。
const HERO_PIXEL := 0.038
const FX_PIXEL_RATIO := 0.5
const LOOP_SECONDS := 4.0
## 打开场景时的默认设置（下拉框序号）：低角度 2.5D、透视镜头、不像素化、像素特效大小 2×、木桩静止、傍晚、开后期
const DEFAULTS := {"angle": 2, "projection": 1, "pixelate": 0, "sizes": 2, "moving": false, "missile_tuning": 0, "lighting": 0, "post": 0}
## 像素特效的放置方式，由效果自身的画面分布决定（见 _pixel_layout）：
##   decal  地面圆环：平铺在地上，按画面比例还原成正圆，角色站在上面会挡住它
##   ground 贴地但有立体部分（光环、水花、召唤阵、扬尘、拾取闪光）：脚底，抬到最低像素刚好着地
##   feet   从底部往上画的（篝火、落雷、治疗、传送光柱、消散）：脚底
##   body   围绕中心画的（刀光、命中、爆炸、护盾、蓄力……）：身体高度
const PIXEL_DECALS := ["magic_circle", "ground_shockwave"]
const PIXEL_GROUND := ["buff_aura", "water_splash", "summon_circle", "landing_dust", "run_dust", "pickup_sparkle"]
## 原点画在地面上、但地面冲击环和尘浪伸到原点下方较多的（统计会误判成「身上」）：原点直接放在脚底
const PIXEL_FEET := ["explosion_small_v2", "explosion_big_v2", "smoke_bomb_v2"]
## 锚点下方画面少于这个比例，视为「从底部往上画」
const BOTTOM_ANCHORED := 0.15
const BODY_HEIGHT := 0.8
const PLACE_LABELS := {"decal": "平铺地面", "ground": "脚底贴地", "feet": "脚底", "body": "身上"}
## 测试场调整：飞弹像素粗细对齐角色（角色每米约 26 像素，像素密度取最接近的 24），
## 拖尾加长加宽、飞行稍慢，适应约 5 米的测试距离。只在测试场生效，插件内置配方不变。
const MISSILE_TUNING := {
	"classic_missile_spirit_sword": {"pixel_density": 24, "head_size": 1.0, "flight_time": 0.95, "trail_length": 2.0, "trail_width": 0.12},
	"classic_missile_fireball": {"pixel_density": 24, "flight_time": 1.0, "trail_length": 1.6, "trail_width": 0.2},
	"classic_missile_ice_arrow": {"pixel_density": 24, "flight_time": 0.8, "trail_length": 2.2, "trail_width": 0.12},
	"classic_missile_shadow_arrow": {"pixel_density": 24, "flight_time": 1.05, "trail_length": 1.9, "trail_width": 0.17},
}
## 飞行类效果（奥术飞弹、飞剑剑气、暗器破空、火球弹、魔法飞弹）本身在原地循环播放、由游戏负责移动，
## 测试场替游戏把它们从角色身前直线飞向发射时木桩的位置（不追踪），单位 米/秒
const PROJECTILE_SPEED := 7.0
## 暗器只在前 0.3 秒可见，要飞得快才能在消散前到达
const PROJECTILE_SPEEDS := {"classic_wuxia_needle": 18.0}
## 归在「远程发射」里、其实是命中效果的（暗影侵蚀：诅咒或暗系命中），直接放在木桩身上
const HIT_AT_TARGET := ["classic_magic_shadow"]
## 花火之门：通往第三个测试场景「夏日花火大会」。传送阵（Codex 三维）两侧各一座地面喷泉烟花，上方挂着指示牌；
## 角色走进去，脚下升起传送光柱，门的上空炸开一发烟花，然后淡出切换场景
const GATE_POS := Vector3(1.2, 0, 5.8)
const GATE_RADIUS := 0.75
const GATE_SCENE := "res://scenes/festival.tscn"
const CAMERA_PRESETS := [["标准等距 30°/45°", -30.0, 45.0], ["试验场角度 35°/22°", -35.0, 22.0], ["低角度 2.5D 20°/0°", -20.0, 0.0]]

var container: SubViewportContainer
var world: Node3D
var stage: Node3D
var camera: Camera3D
var hero: Node3D
var hero_sprite: AnimatedSprite3D
var dummy: Node3D
var dummy_sprite: AnimatedSprite3D
var effects: Node3D
var list: ItemList
var search: LineEdit
var source: OptionButton
var status: Label
var entries: Array[Dictionary] = []
var _pixel_cache: Dictionary = {}
var _facing := "down"
var _side := "right"
var _attacking := 0.0
var _move_dummy := false
var _clock := 0.0
var _pitch := -30.0
var _yaw := 45.0
var _zoom := 9.0
var _pixel_scale := 1.0
var _current: Array[Node] = []
## 绑定到按键 1 的技能（点击左侧列表绑定）
var _bound: Dictionary = {}
var _binding: Label
var _missile_tuned := true
var _pixel_place := ""
var _endpoint_ids: Dictionary = {}
## 正在直线飞行的效果：{node, from, to, age, duration}
var _flights: Array[Dictionary] = []
var _gate_used := false


func _ready() -> void:
	_build_world()
	_build_gate()
	_build_ui()
	_load_entries()
	_rebuild_list()
	_update_camera(true)
	# Esc 菜单：第一项是原来 Esc 的「清除场上效果」，下面是切换测试场景
	var menu := SceneMenu.new()
	menu.add_action("清除场上效果", _clear_current)
	add_child(menu)


# ---------- 场景 ----------

func _build_world() -> void:
	container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var post := ShaderMaterial.new()
	post.shader = POST_SHADER
	container.material = post
	add_child(container)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)

	# 布景：地面、物件、树林、光照和环境都在 iso_stage 里
	stage = STAGE.instantiate()
	world.add_child(stage)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 260.0
	world.add_child(camera)

	effects = Node3D.new()
	effects.name = "Effects"
	world.add_child(effects)

	hero = Node3D.new()
	hero.name = "Hero"
	hero.position = Vector3(-2, 0, 2)
	world.add_child(hero)
	hero_sprite = _billboard(HERO_FRAMES, Vector2(80, 60), Vector2(160, 64), HERO_PIXEL)
	hero.add_child(hero_sprite)
	hero.add_child(_blob_shadow(0.42))
	hero_sprite.animation_finished.connect(func() -> void: _attacking = 0.0)
	hero_sprite.play("idle_down")

	dummy = Node3D.new()
	dummy.name = "Dummy"
	dummy.position = Vector3(2.5, 0, -1.5)
	world.add_child(dummy)
	dummy_sprite = _billboard(BANDIT_FRAMES, Vector2(43, 57), Vector2(86, 58), HERO_PIXEL)
	dummy_sprite.play("idle_down")
	dummy.add_child(dummy_sprite)
	dummy.add_child(_blob_shadow(0.42))


## 花火之门：传送阵、两侧的地面喷泉烟花、指示牌
func _build_gate() -> void:
	var gate := Node3D.new()
	gate.name = "FestivalGate"
	gate.position = GATE_POS
	world.add_child(gate)
	var portal: Resource = Classic.find("classic_portal")
	if portal != null:
		FX3D.spawn(portal.legacy_recipe, gate, Transform3D(Basis.IDENTITY, GATE_POS))
	var fountain: Resource = Builtin.find("firework_fountain")
	if fountain != null:
		var data := _pixel_data(fountain, -1.0)
		for side: float in [-1.0, 1.0]:
			# 喷泉的火星只有 1 像素粗，比其他像素特效放大一些才看得清
			var sprite := _billboard(data.frames, data.origin, data.size, HERO_PIXEL * 0.8)
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			sprite.render_priority = 1
			sprite.position = Vector3(side * 1.3, 0, 0)
			gate.add_child(sprite)
			sprite.play("default")
			# 两座喷泉错开半拍
			sprite.frame = 0 if side < 0.0 else data.frames.get_frame_count("default") >> 1
	var plate := Label3D.new()
	plate.text = "前往夏日花火大会"
	plate.font = FONT
	plate.font_size = 40
	plate.pixel_size = 0.009
	plate.outline_size = 10
	plate.modulate = Color("ffd27a")
	plate.outline_modulate = Color(0.06, 0.04, 0.1)
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plate.position = Vector3(0, 0.2, 1.45)
	gate.add_child(plate)
	# 进门时放的烟花和传送光柱，先渲染好，进门时不卡
	for id: String in ["firework_sphere", "teleport_beam"]:
		var preset: Resource = Builtin.find(id)
		if preset != null:
			_pixel_data(preset, -1.0)


## 走进花火之门：脚下升起传送光柱，门的上空炸开一发烟花，角色渐隐，然后切换到夏日花火大会
func _enter_gate() -> void:
	_gate_used = true
	_attacking = 99.0
	hero_sprite.play("idle_" + _facing)
	status.text = "穿过花火之门，前往夏日花火大会……"
	for item: Array in [["teleport_beam", hero.global_position, HERO_PIXEL * FX_PIXEL_RATIO], ["firework_sphere", GATE_POS + Vector3(0, 0.2, -0.3), HERO_PIXEL * 0.48]]:
		var preset: Resource = Builtin.find(item[0])
		if preset == null:
			continue
		var data := _pixel_data(preset, -1.0)
		var sprite := _billboard(data.frames, data.origin, data.size, item[2])
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.render_priority = 2
		effects.add_child(sprite)
		sprite.global_position = item[1]
		sprite.play("default")
		sprite.animation_finished.connect(sprite.queue_free)
	var tween := create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(hero_sprite, "modulate:a", 0.0, 0.45)
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void: Scenes.change(get_tree(), GATE_SCENE))


## 帧图左上为原点、y 向下；Sprite3D 的偏移以左下为原点、y 向上，所以脚底像素要换算。
func _billboard(frames: SpriteFrames, pivot: Vector2, cell: Vector2, pixel: float) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-pivot.x, -(cell.y - pivot.y))
	sprite.pixel_size = pixel
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	# 面向镜头的贴图投出的影子是歪的；角色用脚下的圆形影子
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return sprite


func _blob_shadow(radius: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc.radial_segments = 20
	shadow.mesh = disc
	shadow.position.y = 0.01
	shadow.scale = Vector3(1, 1, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.35)
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow


func _blocked(pos: Vector3) -> bool:
	return stage.blocked(pos)


## 光照预设（傍晚／白天／夜晚）。角色贴图不受场景灯光影响，换一个色调配合。
func _set_lighting(index: int) -> void:
	stage.set_lighting(index)
	hero_sprite.modulate = stage.sprite_tint
	dummy_sprite.modulate = stage.sprite_tint


## 画面后期：移轴模糊、暗角、泛光、调色和飘浮光点一起开关，方便对比特效本身的样子
func _set_post(on: bool) -> void:
	(container.material as ShaderMaterial).set_shader_parameter("enabled", on)
	stage.environment.glow_enabled = on
	stage.environment.adjustment_enabled = on
	stage.set_ambience(on)


# ---------- 界面 ----------

func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.035, .07, .11, .92)
	box.border_color = Color("345166")
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(10)
	return box


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Theme.new()
	root.theme.default_font = FONT
	root.theme.default_font_size = 16
	canvas.add_child(root)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 272
	panel.offset_bottom = -12
	panel.add_theme_stylebox_override("panel", _panel())
	root.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Jeff FX · 等距测试场"
	heading.add_theme_color_override("font_color", Color("83dfcf"))
	column.add_child(heading)
	source = OptionButton.new()
	for text: String in ["全部效果", "Claude 制作", "Codex 制作", "pixelfx 升级版"]:
		source.add_item(text)
	source.item_selected.connect(func(_i: int) -> void: _rebuild_list())
	column.add_child(source)
	search = LineEdit.new()
	search.placeholder_text = "搜索名称、系、用途…"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_t: String) -> void: _rebuild_list())
	column.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i: int) -> void:
		_bind(list.get_item_metadata(i))
		list.release_focus())
	column.add_child(list)
	var hint := Label.new()
	hint.text = "WASD 移动 · J 普攻\n点击左侧技能 → 绑定到按键 1\n按 1 释放 · 滚轮缩放\n走进下方的花火之门 → 夏日花火大会\nEsc 菜单：清除效果 / 切换场景"
	if stage != null and not stage.get("has_art"):
		hint.text += "\n没有本机场景素材 assets/octopath（第三方版权素材，不随仓库发布），只显示地面和特效"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("91a5b4"))
	column.add_child(hint)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 284
	top.offset_top = 12
	top.offset_right = -12
	top.add_theme_stylebox_override("panel", _panel())
	root.add_child(top)
	var rows := VBoxContainer.new()
	top.add_child(rows)
	var row := HFlowContainer.new()
	rows.add_child(row)
	var angle := _option(row, CAMERA_PRESETS.map(func(p: Array) -> String: return p[0]))
	angle.item_selected.connect(func(i: int) -> void:
		_pitch = CAMERA_PRESETS[i][1]
		_yaw = CAMERA_PRESETS[i][2]
		_update_camera(true))
	var projection := _option(row, ["正交镜头", "透视镜头"])
	projection.item_selected.connect(func(i: int) -> void:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if i == 0 else Camera3D.PROJECTION_PERSPECTIVE
		_update_camera(true))
	var pixelate := _option(row, ["像素化：关", "像素化 2×", "像素化 3×"])
	pixelate.item_selected.connect(func(i: int) -> void: container.stretch_shrink = i + 1)
	var sizes := _option(row, ["像素特效大小 1×", "像素特效大小 0.5×", "像素特效大小 2×"])
	sizes.tooltip_text = "只调整 Claude 制作的像素特效显示多大；三维特效和追踪飞弹不受影响。"
	sizes.item_selected.connect(func(i: int) -> void:
		_pixel_scale = [1.0, 0.5, 2.0][i])
	var tuning := _option(row, ["飞弹：测试场调整", "飞弹：插件原版"])
	tuning.tooltip_text = "测试场调整：飞弹像素粗细对齐角色，拖尾加长加宽、飞行稍慢。只影响本测试场。"
	tuning.item_selected.connect(func(i: int) -> void: _missile_tuned = i == 0)
	var lighting := _option(row, ["光照：傍晚", "光照：白天", "光照：夜晚"])
	lighting.tooltip_text = "场景光照。夜晚火盆和火把的火光更明显，适合看发光类特效。"
	lighting.item_selected.connect(_set_lighting)
	var post := _option(row, ["后期：HD-2D", "后期：关"])
	post.tooltip_text = "HD-2D 后期：画面上下移轴模糊、暗角、泛光、调色和飘浮光点。关掉后可以看特效本身的样子。"
	post.item_selected.connect(func(i: int) -> void: _set_post(i == 0))
	var moving := CheckBox.new()
	moving.text = "木桩移动"
	moving.toggled.connect(func(on: bool) -> void: _move_dummy = on)
	# 通过同一条选择回调套用默认值，界面显示和实际状态不会不一致
	for pair: Array in [[angle, DEFAULTS.angle], [projection, DEFAULTS.projection], [pixelate, DEFAULTS.pixelate], [sizes, DEFAULTS.sizes], [tuning, DEFAULTS.missile_tuning], [lighting, DEFAULTS.lighting], [post, DEFAULTS.post]]:
		var option: OptionButton = pair[0]
		option.select(pair[1])
		option.item_selected.emit(pair[1])
	moving.button_pressed = DEFAULTS.moving
	row.add_child(moving)
	_binding = Label.new()
	_binding.text = "按键 1：未绑定（点击左侧技能绑定）"
	_binding.add_theme_color_override("font_color", Color("f4e1a1"))
	rows.add_child(_binding)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("a9becd"))
	rows.add_child(status)
	for control: Control in [angle, projection, pixelate, sizes, tuning, lighting, post, moving, source]:
		control.focus_mode = Control.FOCUS_NONE


func _option(parent: Node, labels: Array) -> OptionButton:
	var button := OptionButton.new()
	for text: String in labels:
		button.add_item(text)
	parent.add_child(button)
	return button


# ---------- 效果目录 ----------

func _load_entries() -> void:
	entries.clear()
	for definition: Dictionary in Builtin._defs():
		entries.append(Catalog.pixel_metadata(definition))
	# 四款追踪飞弹已并入插件，和效果库一起由 Classic.catalog() 提供
	for metadata: Dictionary in Classic.catalog():
		entries.append(metadata)


func _rebuild_list() -> void:
	list.clear()
	var query := search.text.strip_edges().to_lower()
	for entry: Dictionary in entries:
		var codex := bool(entry.get("is_classic", false))
		var maker := Catalog.maker_of(entry)
		if source.selected > 0 and maker != ["", "claude", "codex", "pixelfx"][source.selected]:
			continue
		var school := Catalog.name_for("school", Catalog.school_for(entry))
		var battle := Catalog.name_for("battle", str(Catalog.facet_value(entry, "battle")))
		var text := "%s  [%s]" % [entry.display_name, "追踪" if entry.get("is_missile", false) else "3D" if codex else "像素"]
		if not query.is_empty() and not (text + " " + school + " " + battle + " " + str(entry.get("description", ""))).to_lower().contains(query):
			continue
		var index := list.add_item(text)
		list.set_item_metadata(index, entry)
		list.set_item_tooltip(index, "%s · %s · %s\n%s" % [Catalog.name_for("maker", maker), battle, school, entry.get("description", "")])


func _entry(id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if entry.id == id:
			return entry
	return {}


# ---------- 播放 ----------

func _play_id(id: String) -> void:
	var entry := _entry(id)
	if entry.is_empty():
		status.text = "找不到效果：" + id
		return
	_play(entry, false)


## 放置规则：追踪飞弹从角色胸口发射并持续追踪木桩；其他飞行类从角色身前直线飞向木桩；
## 跟随类挂在角色身上；带起终点的流光／电弧从角色胸口连到木桩；有方向的从角色朝木桩发出；
## 命中类在木桩身体高度；其余落在木桩脚下。
func _play(entry: Dictionary, remember: bool) -> void:
	var codex := bool(entry.get("is_classic", false))
	var node := _spawn_codex(entry) if codex else _spawn_pixel(entry)
	if node == null:
		status.text = "无法播放：" + str(entry.display_name)
		return
	if remember:
		_current.append(node)
	status.text = "%s · %s · %s · %s" % [entry.display_name, "Claude 制作 · 3D 追踪飞弹" if entry.get("is_missile", false) else "Codex 制作 · 3D 实例" if codex else Catalog.name_for("maker", Catalog.maker_of(entry)) + " · 平面贴图", Catalog.name_for("school", Catalog.school_for(entry)), _placement_label(entry)]


func _placement_label(entry: Dictionary) -> String:
	if not bool(entry.get("is_classic", false)) and not _pixel_place.is_empty():
		return _pixel_place
	if str(entry.get("space", "")) == "follow":
		return "跟随角色"
	if entry.get("is_missile", false):
		return "追踪木桩"
	if entry.id in _endpoint_ids:
		return "角色 → 木桩连线"
	if _straight(entry):
		return "角色 → 木桩直线飞行"
	if entry.id in HIT_AT_TARGET:
		return "木桩位置"
	if str(entry.get("anchor", "")) == "direction":
		return "角色 → 木桩方向"
	return "木桩位置"


func _aim() -> Vector3:
	var d := dummy.global_position - hero.global_position
	d.y = 0
	return d.normalized() if d.length() > 0.01 else Vector3.RIGHT


## 飞行类：「远程发射」里既不追踪、也不是起终点连线的效果
func _straight(entry: Dictionary) -> bool:
	return str(entry.get("subtype", "")) == "projectile" and not entry.get("is_missile", false) and not entry.id in _endpoint_ids and not entry.id in HIT_AT_TARGET


## 按速度从起点直线移到终点，在 _process 里推进
func _fly(node: Node3D, from: Vector3, to: Vector3, speed: float) -> void:
	node.global_position = from
	_flights.append({"node": node, "from": from, "to": to, "age": 0.0, "duration": maxf(0.05, from.distance_to(to) / speed)})


func _spawn_codex(entry: Dictionary) -> Node:
	var preset: Resource = Classic.find(str(entry.id))
	if preset == null or preset.legacy_recipe == null:
		return null
	if preset.legacy_recipe.has_missile():
		var recipe: Resource = preset.legacy_recipe
		if _missile_tuned and MISSILE_TUNING.has(entry.id):
			recipe = recipe.copy()
			for layer: Resource in recipe.layers:
				if layer.missile != null:
					for field: String in MISSILE_TUNING[entry.id]:
						layer.missile.set(field, MISSILE_TUNING[entry.id][field])
		# 发射后一直追踪木桩（含移动中的木桩），命中胸口高度
		return FX3D.spawn_to(recipe, effects, hero.global_position + Vector3(0, 0.9, 0), dummy, Vector3(0, 0.9, 0))
	var chest := Vector3(0, 0.9, 0)
	var linked := FX3D.spawn_between(preset.legacy_recipe, effects, hero.global_position + chest, dummy.global_position + chest)
	if linked != null:
		_endpoint_ids[entry.id] = true
		return linked
	var effect := Instance.new()
	effect.preset = preset.legacy_recipe.copy()
	effect.autoplay = false
	effect.auto_free = true
	var follow := str(entry.get("space", "")) == "follow"
	var flying := _straight(entry)
	(hero if follow else effects).add_child(effect)
	var x := _aim()
	var facing := Basis(x, Vector3.UP, x.cross(Vector3.UP))
	if follow:
		effect.position = Vector3.ZERO
	elif entry.id in HIT_AT_TARGET:
		effect.global_transform = Transform3D(facing, dummy.global_position)
	elif effect.preset.has_missile() or str(entry.get("anchor", "")) == "direction":
		# 飞行类贴地移动：图层自带离地高度；朝向木桩，跟随运动方向转向从第一帧就对
		effect.global_transform = Transform3D(facing, hero.global_position + (x * 0.3 if flying else Vector3.ZERO))
	else:
		effect.global_position = dummy.global_position
	if effect.preset.has_missile():
		effect.bind_target(dummy, Vector3(0, 0.9, 0))
	effect.play()
	if flying:
		_fly(effect, effect.global_position, dummy.global_position, PROJECTILE_SPEEDS.get(entry.id, PROJECTILE_SPEED))
	elif effect.preset.looping:
		_stop_later(effect)
	return effect


## Claude 制作的效果：运行时渲染成帧，按方向缓存；以面向镜头的平面贴图播放。
func _spawn_pixel(entry: Dictionary) -> Node:
	var preset: Resource = Builtin.find(str(entry.id))
	if preset == null:
		return null
	var directional := str(entry.get("subtype", "")) in ["slash", "thrust", "projectile", "movement"]
	var data := _pixel_data(preset, _screen_angle() if directional else -1.0)
	var pixel := HERO_PIXEL * FX_PIXEL_RATIO * _pixel_scale
	var mode := _pixel_layout(entry, data)
	var follow := str(entry.get("space", "")) == "follow"
	var flying := _straight(entry)
	var height := 0.0
	match mode:
		"body":
			height = BODY_HEIGHT
		"ground":
			height = maxf(0.0, float(data.low) - data.origin.y) * pixel
		"decal":
			height = 0.02
	var sprite := _decal(data.frames, data.origin, data.size, pixel, float(data.ratio)) if mode == "decal" else _billboard(data.frames, data.origin, data.size, pixel)
	# 效果画在角色之前，避免与角色贴图互相切穿（平铺在地上的圆环除外：角色要能挡住它）
	sprite.render_priority = 0 if mode == "decal" else 1
	sprite.no_depth_test = false
	# 角色贴图用透明裁切；特效里的柔光、叠加光、半透明烟雾要按透明度混合，否则不到一半透明度的像素会被整个裁掉
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	if follow:
		hero.add_child(sprite)
		sprite.position = Vector3(0, height, 0)
	else:
		effects.add_child(sprite)
		sprite.global_position = (hero.global_position + _aim() * 0.6 if directional else dummy.global_position) + Vector3(0, height, 0)
	_pixel_place = ("角色" if follow or directional else "木桩") + PLACE_LABELS[mode]
	sprite.play("default")
	if not data.loop:
		sprite.animation_finished.connect(sprite.queue_free)
	if flying:
		# 像素飞弹的原点在弹体中心：从胸口高度飞到木桩胸口
		var chest := Vector3(0, 0.9, 0)
		_fly(sprite, hero.global_position + _aim() * 0.3 + chest, dummy.global_position + chest, PROJECTILE_SPEEDS.get(entry.id, PROJECTILE_SPEED))
		_pixel_place = "角色 → 木桩直线飞行"
	elif data.loop:
		_stop_later(sprite)
	return sprite


## 渲染像素特效的全部帧（按方向缓存）。angle < 0 表示不改方向
func _pixel_data(preset: Resource, angle: float) -> Dictionary:
	var key := "%s@%d" % [preset.preset_id, int(angle)]
	if not _pixel_cache.has(key):
		var opts := {}
		if angle >= 0.0:
			opts["direction"] = angle
		var job := FxRenderer.make_job(preset, opts)
		FxRenderer.render_sync(job)
		var frames := SpriteFrames.new()
		frames.set_animation_speed("default", job.fps)
		frames.set_animation_loop("default", job.loop)
		var images := job.images()
		for i in images.size():
			if images[i] != null:
				frames.add_frame("default", ImageTexture.create_from_image(images[i]), job.durations[i] if i < job.durations.size() else 1.0)
		var data := _pixel_stats(images, job.origin)
		data.merge({"frames": frames, "origin": job.origin, "size": Vector2(job.w, job.h), "loop": job.loop})
		_pixel_cache[key] = data
	return _pixel_cache[key]


## 从渲染出的帧里统计：锚点下方画面的比例、最低像素所在行、整体外框的高宽比（圆环用）
static func _pixel_stats(images: Array, origin: Vector2) -> Dictionary:
	var total := 0
	var below := 0
	var low := origin.y
	var bounds := Rect2i()
	for img: Image in images:
		if img == null:
			continue
		var used := img.get_used_rect()
		if used.size.x <= 0:
			continue
		bounds = used if bounds.size.x <= 0 else bounds.merge(used)
		for y in range(used.position.y, used.end.y, 2):
			for x in range(used.position.x, used.end.x, 2):
				if img.get_pixel(x, y).a > 0.2:
					total += 1
					if y > origin.y:
						below += 1
					low = maxf(low, y)
	return {"below": float(below) / maxf(1.0, total), "low": low, "ratio": float(bounds.size.y) / maxf(1.0, bounds.size.x)}


func _pixel_layout(entry: Dictionary, data: Dictionary) -> String:
	if entry.id in PIXEL_DECALS:
		return "decal"
	if entry.id in PIXEL_GROUND or str(entry.get("anchor", "")) == "ground":
		return "ground"
	if entry.id in PIXEL_FEET:
		return "feet"
	return "feet" if float(data.below) < BOTTOM_ANCHORED else "body"


## 平铺在地上的像素圆环：画面里的椭圆是「斜着看的圆」，沿画面纵向拉回正圆，再由镜头自然压扁
func _decal(frames: SpriteFrames, origin: Vector2, cell: Vector2, pixel: float, ratio: float) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-origin.x, -(cell.y - origin.y))
	sprite.pixel_size = pixel
	sprite.axis = Vector3.AXIS_Y
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.scale = Vector3(1, 1, 1.0 / clampf(ratio, 0.2, 1.0))
	sprite.rotation.y = deg_to_rad(_yaw)
	return sprite


## 角色 → 木桩在屏幕上的角度（0° 朝右，90° 朝下），取 45° 的倍数以便缓存
func _screen_angle() -> float:
	var a := camera.unproject_position(hero.global_position)
	var b := camera.unproject_position(dummy.global_position)
	var deg := fposmod(rad_to_deg((b - a).angle()), 360.0)
	return fposmod(roundf(deg / 45.0) * 45.0, 360.0)


func _stop_later(node: Node) -> void:
	get_tree().create_timer(LOOP_SECONDS).timeout.connect(func() -> void:
		if not is_instance_valid(node):
			return
		if node is Instance:
			node.stop()
		else:
			node.queue_free())


## 推进直线飞行。到达后：循环的三维效果 stop()，尾迹和留在空中的碎光自然消散；
## 单次的（暗器）停在木桩处播完；像素贴图直接移除。
func _process(delta: float) -> void:
	for i in range(_flights.size() - 1, -1, -1):
		var flight: Dictionary = _flights[i]
		var node = flight.node
		if not is_instance_valid(node):
			_flights.remove_at(i)
			continue
		flight.age += delta
		var u := minf(1.0, flight.age / flight.duration)
		node.global_position = flight.from.lerp(flight.to, u)
		if u < 1.0:
			continue
		_flights.remove_at(i)
		if node is Instance:
			if node.preset.looping:
				node.stop()
		else:
			node.queue_free()


## 点击左侧列表：把技能绑定到按键 1（不立即释放）
func _bind(entry: Dictionary) -> void:
	_bound = entry
	_binding.text = "按键 1：%s" % entry.display_name
	status.text = "已绑定到按键 1：%s · %s · 按 1 释放" % [entry.display_name, Catalog.name_for("school", Catalog.school_for(entry))]


func _cast_bound() -> void:
	if _bound.is_empty():
		status.text = "先在左侧点击一个技能，绑定到按键 1"
		return
	_play(_bound, true)


func _clear_current() -> void:
	for node: Node in _current:
		if is_instance_valid(node):
			if node is Instance:
				node.stop(true)
			node.queue_free()
	_current.clear()


# ---------- 角色与镜头 ----------

func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if not _typing():
		input.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		input.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	if _attacking > 0.0:
		_attacking -= delta
		input = Vector2.ZERO
	if input != Vector2.ZERO:
		input = input.normalized()
		# 屏幕方向 → 地面方向：右 = 镜头 x 轴，上 = 镜头朝向压平到地面
		var right := camera.global_basis.x
		right.y = 0
		var forward := -camera.global_basis.z
		forward.y = 0
		var move := (right.normalized() * input.x - forward.normalized() * input.y) * 3.2 * delta
		for step: Vector3 in [move, Vector3(move.x, 0, 0), Vector3(0, 0, move.z)]:
			if not _blocked(hero.position + step * 2.0):
				hero.position += step
				break
		if absf(input.x) >= absf(input.y):
			_facing = "right" if input.x > 0 else "left"
			_side = _facing
		else:
			_facing = "down" if input.y > 0 else "up"
		hero_sprite.play("run_" + _facing)
	elif _attacking <= 0.0:
		hero_sprite.play("idle_" + _facing)
	if not _gate_used and Vector2(hero.position.x - GATE_POS.x, hero.position.z - GATE_POS.z).length() < GATE_RADIUS:
		_enter_gate()
	if _move_dummy:
		_clock += delta
		dummy.position = Vector3(2.5 + 2.0 * cos(_clock * 0.6), 0, -1.0 + 1.6 * sin(_clock * 0.6))
	_update_camera(false)


func _attack() -> void:
	if _attacking > 0.0:
		return
	# 角色的攻击动画自带刀光，这里不再叠加特效刀光
	hero_sprite.play("attack1_" + _side)
	_attacking = 0.55


func _update_camera(snap: bool) -> void:
	var basis := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0))
	var focus := hero.global_position + Vector3(0, 0.8, 0)
	var goal := Transform3D(basis, focus + basis.z * 30.0)
	camera.global_transform = goal if snap else camera.global_transform.interpolate_with(goal, 0.12)
	camera.size = _zoom
	camera.fov = 2.0 * rad_to_deg(atan(_zoom * 0.5 / 30.0))


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _typing():
		match event.physical_keycode:
			KEY_J:
				_attack()
			KEY_1:
				_cast_bound()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom = clampf(_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 4.0, 22.0)
