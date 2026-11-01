extends Node
## 夏日花火大会（第三个测试场景）：夜晚的 HD-2D 海港。
## 一群人站在山坡露台上，都背对镜头望向右上方的夜空：一对恋人、一家三口、老夫妻、孩子们，还有抬头的小猫；
## 头顶挂着一串灯笼，草地上有萤火虫和发光的铃兰。
## 按「放烟花」后镜头顺着众人的视线往右上方升起、仰向夜空，十几发烟花依次绽放，压轴连发之后镜头落回原处。
##
## 远景用《铃兰之剑》登录画面切开的分层贴图（天空、远山、海面、对岸城市、船、近处城市），
## 每层是一块面向参考镜头的平面：先定好它在参考镜头画面里的位置，再按离镜头的远近换算到三维里。
## 所以参考镜头下各层拼成一幅完整的画，镜头升起时各层按远近产生视差。
## 角色、远景、道具素材只在本机（assets/convallaria，见那里的 README），缺少时只显示夜空和烟花。

const SceneMenu := preload("res://scripts/scene_menu.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")
const Fireworks := preload("res://addons/fx_forge/presets/firework_presets.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const POST_SHADER := preload("res://assets/iso_stage/hd2d_post.gdshader")
const SKY_SHADER := preload("res://assets/festival/night_sky.gdshader")
const LAYER_SHADER := preload("res://assets/festival/backdrop_layer.gdshader")
const GROUND_SHADER := preload("res://assets/festival/terrace_ground.gdshader")
const SHADOW_SHADER := preload("res://assets/festival/contact_shadow.gdshader")
const FONT := preload("res://assets/courtyard/fonts/Unifont16.otf")
const ART := "res://assets/convallaria/"

## 参考镜头（待机时的镜头）：在人群后方远处、略高，俯视露台和山坡下的港口。远景各层按这个镜头下的画面位置摆放
const REF_POS := Vector3(0, 4.0, 17.0)
const REF_PITCH := -9.0
const REF_FOV := 40.0
## 参考画面的大小（单位：远景贴图的像素），16:9，左上角为 (0, 0)
const REF_SIZE := Vector2(1900, 1069)
## 众人视线的方向：参考镜头正前方往右偏多少度（负数 = 往右）。烟花在这个方向的夜空里绽放
const GAZE_YAW := -22.0
## 看烟花的镜头：顺着视线往右上方升起，转向右边、仰望夜空
const SKY_POS := REF_POS + Vector3(3.5, 3.0, -3.5)
const SKY_PITCH := 16.0
const SKY_FOV := 58.0
## 压轴：镜头落到人群后方、往下压、拉宽，前排人群的背影在画面下方，上方是空中和岸边的连发
const FINALE_T := 16.2
const FINALE_POS := REF_POS + Vector3(1.5, 0.2, -4.0)
const FINALE_YAW := -20.0
const FINALE_PITCH := 11.0
const FINALE_FOV := 64.0
## 镜头升起、落回所用的秒数
const CRANE_UP := 3.8
const CRANE_DOWN := 3.6

## 绘制顺序（透明物体按这个先后画，和远近无关）：天空 → 远山 → 海面 → 空中的烟花 → 对岸城市 → 岸边的烟花 → 船 → 近处城市
const ORDER_SHELLS := -7
const ORDER_SHORE := -5
## 远景分层（远 → 近）：文件、离参考镜头的距离（米）、参考画面里的左上角、缩放、绘制顺序、
## 左右镜像延伸（各几倍宽，镜头往右摇得很远，要多延伸一些）、顶部渐隐、亮度（压暗一点，烟花更显眼）、烟花照亮的强度。
## 可选：fade_side（左右两端渐隐的宽度，占贴图宽度的比例；城市贴图的右端是切开的）
const LAYERS := [
	{"file": "sky", "depth": 230.0, "at": Vector2(-74, -150), "scale": Vector2(1.0, 1.0), "order": -10, "extend": 2.0, "fade_top": 0.5, "dim": 0.75, "flash": 0.3},
	{"file": "hills", "depth": 110.0, "at": Vector2(-74, 112), "scale": Vector2(1.0, 1.0), "order": -9, "extend": 2.0, "fade_top": 0.0, "dim": 0.8, "flash": 0.2},
	{"file": "sea", "depth": 95.0, "at": Vector2(-74, 212), "scale": Vector2(1.0, 0.8), "order": -8, "extend": 2.0, "fade_top": 0.0, "dim": 0.66, "flash": 0.6},
	{"file": "city_far", "depth": 62.0, "at": Vector2(900, 330), "scale": Vector2(0.8, 0.8), "order": -6, "extend": 0.0, "fade_top": 0.0, "dim": 0.85, "flash": 0.45, "fade_side": Vector2(0.0, 0.16)},
	{"file": "boats", "depth": 48.0, "at": Vector2(-60, 460), "scale": Vector2(0.7, 0.7), "order": -4, "extend": 0.0, "fade_top": 0.0, "dim": 0.8, "flash": 0.5},
	{"file": "city_near", "depth": 34.0, "at": Vector2(830, 430), "scale": Vector2(0.9, 0.9), "order": -3, "extend": 0.0, "fade_top": 0.0, "dim": 0.85, "flash": 0.45, "fade_side": Vector2(0.0, 0.12)},
]
## 远景的夜色（再乘各层的亮度）
const NIGHT_TINT := Color(0.94, 0.96, 1.08)

## 空中烟花的发射高度（参考画面里的 y）：对岸城市楼群的中间，比天际线（约 360）低，
## 烟花先画、对岸城市后画，所以发射点藏在楼后面，升空的尾迹从屋顶上方冒出来
const BAY_Y := 430.0
## 烟花每个像素在世界里多大（米）：烟花在对岸城市后面很远的地方，弹也大
const FW_PIXEL := 0.42
## 节目单：按下按钮后第几秒发射、预设、参考画面里的 x、离参考镜头多远（米）。
## 可选：y（参考画面里的发射点高度）、scale（大小倍数）、hold（循环烟花放多久）、order（绘制顺序）。
## 先在参考画面里排好，再整体转到众人视线的方向（GAZE_YAW），所以 x 以画面中间 950 为中心排。
## 空中烟花都在对岸城市（62 米）后面，分成远近三层，看起来有前后层次：
## 近（92～105 米）的大、炸得高；中（118～150 米）；远（160～190 米）的小、低、颜色淡（见 FAR_DIM）
const SHOW := [
	{"t": 2.4, "id": "firework_sphere", "x": 950, "depth": 120.0},
	{"t": 4.1, "id": "firework_willow", "x": 620, "depth": 178.0},
	{"t": 4.7, "id": "firework_ring", "x": 1290, "depth": 94.0},
	{"t": 6.4, "id": "firework_heart", "x": 980, "depth": 118.0},
	{"t": 8.0, "id": "firework_crossette", "x": 700, "depth": 96.0},
	{"t": 8.4, "id": "firework_multibreak", "x": 1250, "depth": 182.0},
	{"t": 10.1, "id": "firework_saturn", "x": 960, "depth": 128.0},
	{"t": 11.7, "id": "firework_palm", "x": 650, "depth": 172.0},
	{"t": 12.0, "id": "firework_smile", "x": 1270, "depth": 100.0},
	{"t": 13.6, "id": "firework_strobe", "x": 980, "depth": 150.0},
	{"t": 15.0, "id": "firework_star", "x": 760, "depth": 96.0},
	{"t": 15.3, "id": "firework_crackle", "x": 1200, "depth": 186.0},
	# 压轴：对岸海边的礼花筒齐射，空中远近交错的连发
	{"t": 16.8, "id": "firework_fan", "x": 600, "y": 560, "depth": 66.0, "scale": 0.6, "order": ORDER_SHORE},
	{"t": 17.0, "id": "firework_fan", "x": 1380, "y": 560, "depth": 66.0, "scale": 0.6, "order": ORDER_SHORE},
	{"t": 17.2, "id": "firework_sphere", "x": 560, "depth": 168.0},
	{"t": 17.5, "id": "firework_willow", "x": 960, "depth": 125.0, "scale": 1.15},
	{"t": 17.8, "id": "firework_sphere", "x": 1380, "depth": 96.0},
	{"t": 18.6, "id": "firework_crackle", "x": 780, "depth": 100.0},
	{"t": 18.8, "id": "firework_heart", "x": 1170, "depth": 176.0},
	{"t": 19.8, "id": "firework_willow", "x": 700, "depth": 160.0},
	{"t": 20.0, "id": "firework_willow", "x": 1240, "depth": 110.0},
	# 最后一发：炸开成「Jeff Studio」，放在近处，在空中停约 9 秒
	{"t": 21.6, "id": "firework_text", "x": 950, "depth": 104.0},
]
## 远处的烟花隔着夜雾：从 NEAR_DEPTH 到 FAR_DEPTH，亮度降到 FAR_DIM、颜色略偏冷；照亮场景的闪光也跟着变弱
const NEAR_DEPTH := 100.0
const FAR_DEPTH := 185.0
const FAR_DIM := 0.62
## 所有烟花都放完之后再看几秒，镜头才落回去
const SHOW_TAIL := 1.2
## 不升空的烟花：没有炸开的闪光
const GROUND_PIECES := ["firework_fountain", "firework_fan", "firework_waterfall"]

## 角色：都背对镜头、朝右后方（右上 45°）望向夜空，不左右翻转
const SPRITE_PIXEL := 0.036
const SPRITE_TINT := Color(0.66, 0.7, 0.88)
## 路人的背面帧：wait_4 是正背面，wait_5 头再往右转一点；大部分时间望着前方，不时往右看
const LOOK := [4, 4, 4, 5, 5, 5, 5, 4]
## 每个角色：素材名、站在哪里。可选：anim、frames（默认路人的 wait + LOOK）、fps（默认 1.6）、shadow（影子半径）
const CHARACTERS := [
	# 前排靠着栏杆：一对恋人在画面中间偏左（右后方的待机帧，有呼吸起伏），旁边是老夫妻、年轻人和孩子
	{"name": "HiriaFprinceMset01", "anim": "idle", "frames": [4, 5, 6, 7], "fps": 5.0, "pos": Vector3(-1.25, 0, 2.3)},
	{"name": "HiriaLadymunaF2set01", "anim": "idle", "frames": [4, 5, 6, 7], "fps": 5.0, "pos": Vector3(-0.5, 0, 2.25)},
	# 小猫：背对镜头坐着望向右上方，不时把头再往右转、甩甩尾巴
	{"name": "secretcat", "frames": [8, 9, 8, 11, 12, 12, 11, 9, 10, 9], "fps": 3.0, "pos": Vector3(0.3, 0, 2.75), "shadow": 0.22},
	{"name": "npc06", "pos": Vector3(-4.4, 0, 2.4)},
	{"name": "npc07", "pos": Vector3(-3.7, 0, 2.35)},
	{"name": "npc19", "pos": Vector3(5.2, 0, 2.5)},
	{"name": "npc63", "pos": Vector3(5.9, 0, 2.4)},
	{"name": "npc13", "pos": Vector3(-6.9, 0, 2.5), "shadow": 0.26},
	{"name": "npc111", "pos": Vector3(6.8, 0, 2.7)},
	# 中间：一家三口、跑开的孩子
	{"name": "npc44", "pos": Vector3(2.4, 0, 3.7)},
	{"name": "npc05", "pos": Vector3(3.1, 0, 3.6)},
	{"name": "npc08", "pos": Vector3(2.75, 0, 4.3), "shadow": 0.24},
	{"name": "npc14", "pos": Vector3(-6.0, 0, 4.2), "shadow": 0.26},
	# 前景：画面左右两边离镜头近的几个人
	{"name": "npc57", "pos": Vector3(-4.6, 0, 7.4)},
	{"name": "npc41", "pos": Vector3(-3.8, 0, 8.0), "shadow": 0.24},
	{"name": "npc56", "pos": Vector3(3.3, 0, 8.0)},
	{"name": "npc65", "frames": [5, 6, 7, 8, 9], "fps": 5.0, "pos": Vector3(4.0, 0, 8.7)},
]
## 栏杆所在的位置（露台边缘）
const RAIL_Z := 1.5
const RAIL_HALF := 30.0
## 灯笼串：两根竹竿之间一条下垂的绳子
const LANTERN_ROPE := [Vector3(-9.5, 4.3, 2.6), Vector3(9.5, 4.3, 2.6)]
const LANTERN_SAG := 0.8
const LANTERN_COUNT := 15
## 灯笼像素图：0 顶盖、1~4 灯身从暗到亮、5 流苏
const LANTERN_ROWS := ["..0000..", "..1111..", ".122221.", "12333321", "13444431", "13444431", "12333321", ".122221.", "..1111..", "..0000..", "...55..."]
const LANTERN_COLORS := [
	["2a1a14", "7a1822", "c02a2a", "f0553c", "ffb36a", "d8a040"],
	["2a1a14", "9a7050", "e0bc8c", "fff0c8", "ffffff", "d8a040"],
]

var container: SubViewportContainer
var world: Node3D
var camera: Camera3D
var fireworks: Node3D
var button: Button
var status: Label
var _post: ShaderMaterial
var _sky: ShaderMaterial
## 烟花照亮的对象：[材质或贴图, 强度]
var _lit: Array = []
var _sprites: Array[SpriteBase3D] = []
var _rail_mat: StandardMaterial3D
var _lanterns: Array[Node3D] = []
var _fireflies: Array[Dictionary] = []
var _flash := Color(0, 0, 0)
var _clock := 0.0
## 渲染好的烟花：id → {frames, origin, size, color}
var _fx: Dictionary = {}
var _queue: Array[String] = []
var _job: RefCounted
var _task := -1
## 表演进度：idle / up / show / down
var _stage := "idle"
var _t := 0.0
var _next := 0
var _bursts: Array = []
var _holds: Array = []
var _from: Transform3D
var _from_fov := REF_FOV
## 炸开时夜空里的一团柔光：[贴图, 已过秒数]
var _glows: Array = []
var _halo_tex: ImageTexture
var _missing := false


func _ready() -> void:
	_build_world()
	_build_ui()
	add_child(SceneMenu.new())
	for item: Dictionary in SHOW:
		if not item.id in _queue:
			_queue.append(item.id)
	_update_status()
	_place_camera(_ref_transform(), REF_FOV)


func _exit_tree() -> void:
	# 换场景时如果还在渲染，等它完成（任务引用着 job）
	if _task >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1


# ---------- 场景 ----------

func _build_world() -> void:
	container = SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_post = ShaderMaterial.new()
	_post.shader = POST_SHADER
	_post.set_shader_parameter("focus_center", 0.52)
	_post.set_shader_parameter("focus_half", 0.2)
	container.material = _post
	add_child(container)
	var viewport := SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	world = Node3D.new()
	world.name = "World"
	viewport.add_child(world)

	# 夜空（不用泛光：兼容渲染器下泛光会把背景整片提亮）
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = _sky
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.35, 0.5)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 600.0
	world.add_child(camera)

	_missing = not FileAccess.file_exists(ART + "backdrop/sky.png")
	if not _missing:
		for layer: Dictionary in LAYERS:
			_add_layer(layer)
	_build_terrace()
	if not _missing:
		for c: Dictionary in CHARACTERS:
			_add_character(c)
		_add_lilies()
	_add_lanterns()
	_add_fireflies()

	fireworks = Node3D.new()
	fireworks.name = "Fireworks"
	world.add_child(fireworks)


## 参考镜头的朝向
func _ref_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(REF_PITCH), 0, 0))


func _ref_transform() -> Transform3D:
	return Transform3D(_ref_basis(), REF_POS)


## 参考画面上的一点（单位同 REF_SIZE）在离参考镜头 depth 米处的世界坐标
func _ref_point(p: Vector2, depth: float) -> Vector3:
	var unit := _ref_unit(depth)
	var local := Vector3((p.x - REF_SIZE.x * 0.5) * unit, (REF_SIZE.y * 0.5 - p.y) * unit, -depth)
	return REF_POS + _ref_basis() * local


## 节目单里的一点：先在参考画面里定位，再绕参考镜头整体转到众人视线的方向（右上方的夜空）
func _show_point(p: Vector2, depth: float) -> Vector3:
	return REF_POS + Basis(Vector3.UP, deg_to_rad(GAZE_YAW)) * (_ref_point(p, depth) - REF_POS)


## 离参考镜头 depth 米处，参考画面的一个单位是多少米
func _ref_unit(depth: float) -> float:
	return depth * tan(deg_to_rad(REF_FOV) * 0.5) / (REF_SIZE.y * 0.5)


## 读本机素材的 PNG（不经过导入：导入设置用在 3D 里会被压缩）
func _image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _add_layer(layer: Dictionary) -> void:
	var img := _image(ART + "backdrop/%s.png" % layer.file)
	if img == null:
		return
	img.generate_mipmaps()
	var size := Vector2(img.get_width(), img.get_height()) * (layer.scale as Vector2)
	var extend: float = layer.extend
	var unit := _ref_unit(layer.depth)
	var center: Vector2 = (layer.at as Vector2) + size * 0.5
	var quad := QuadMesh.new()
	quad.size = Vector2(size.x * (1.0 + 2.0 * extend), size.y) * unit
	var mat := ShaderMaterial.new()
	mat.shader = LAYER_SHADER
	mat.render_priority = layer.order
	mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("u_range", Vector2(-extend, 1.0 + extend))
	mat.set_shader_parameter("fade_top", layer.fade_top)
	mat.set_shader_parameter("fade_side", layer.get("fade_side", Vector2.ZERO))
	mat.set_shader_parameter("tint", NIGHT_TINT * float(layer.dim))
	mat.set_shader_parameter("flash_gain", layer.flash)
	var mesh := MeshInstance3D.new()
	mesh.name = "Backdrop_" + layer.file
	mesh.mesh = quad
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.transform = Transform3D(_ref_basis(), _ref_point(center, layer.depth))
	world.add_child(mesh)
	_lit.append([mat, 1.0])


## 露台：草地、栏杆、灯笼的竹竿
func _build_terrace() -> void:
	var grass := _image(ART + "ground/grass.png")
	var ground := MeshInstance3D.new()
	ground.name = "Terrace"
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	# 草地从栏杆外 0.5 米一直铺到镜头后面，左右很宽：镜头往右摇、压轴时都看不到露台的尽头
	ground.position = Vector3(0, 0, RAIL_Z - 0.5 + 40.0)
	var mat := ShaderMaterial.new()
	mat.shader = GROUND_SHADER
	if grass != null:
		mat.set_shader_parameter("tex", ImageTexture.create_from_image(grass))
	# 草地贴图 160 像素，和角色同样的像素密度
	mat.set_shader_parameter("tiles", 80.0 / (160.0 * SPRITE_PIXEL))
	# 栏杆边 1.5 米这一段变暗
	mat.set_shader_parameter("fade_band", 1.5 / 80.0)
	ground.material_override = mat
	world.add_child(ground)
	_lit.append([mat, 1.0])

	_rail_mat = StandardMaterial3D.new()
	_rail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rail_mat.albedo_color = Color(0.1, 0.08, 0.11)
	# 栏杆：扶手、横档和立柱，夜里只看得到深色的剪影
	for y: float in [0.92, 0.5]:
		_box(Vector3(RAIL_HALF * 2.0, 0.07 if y > 0.6 else 0.045, 0.07), Vector3(0, y, RAIL_Z))
	var x := -RAIL_HALF
	while x <= RAIL_HALF + 0.01:
		_box(Vector3(0.09, 0.98, 0.09), Vector3(x, 0.49, RAIL_Z))
		x += 1.3
	# 挂灯笼的两根竹竿
	for p: Vector3 in LANTERN_ROPE:
		_box(Vector3(0.08, p.y + 0.15, 0.08), Vector3(p.x, (p.y + 0.15) * 0.5, p.z))


func _box(size: Vector3, pos: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _rail_mat
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mesh)


## 一个像素角色：帧的大小不一样，先按脚底中间对齐到同样大的画布上；帧底下的透明行去掉，脚才踩在地上。
## frames 可以重复同一帧（路人大部分时间停在正背面），每张图只读一次
func _add_character(c: Dictionary) -> void:
	var anim: String = c.get("anim", "wait")
	var order: Array = c.get("frames", LOOK)
	var images: Dictionary = {}
	var w := 0
	var h := 0
	for i: int in order:
		if images.has(i):
			continue
		var img := _image(ART + "characters/%s/%s_%s_%d.png" % [c.name, c.name, anim, i])
		if img == null:
			return
		img.convert(Image.FORMAT_RGBA8)
		images[i] = img
		w = maxi(w, img.get_width())
	# 素材每帧脚下都留了透明行（1 像素就让人离地 4 厘米）：按各帧里最少的那几行一起裁掉，帧之间的起伏不变
	var margin := 1 << 20
	for i: int in images:
		var img: Image = images[i]
		margin = mini(margin, img.get_height() - img.get_used_rect().end.y)
	for i: int in images:
		h = maxi(h, (images[i] as Image).get_height() - margin)
	var textures: Dictionary = {}
	for i: int in images:
		var img: Image = images[i]
		var canvas := Image.create(w, h, false, Image.FORMAT_RGBA8)
		var keep := img.get_height() - margin
		canvas.blit_rect(img, Rect2i(0, 0, img.get_width(), keep), Vector2i((w - img.get_width()) >> 1, h - keep))
		textures[i] = ImageTexture.create_from_image(canvas)
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", c.get("fps", 1.6))
	for i: int in order:
		frames.add_frame("default", textures[i])
	var sprite := AnimatedSprite3D.new()
	sprite.name = c.name
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = Vector2(-w * 0.5, 0)
	sprite.pixel_size = SPRITE_PIXEL
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.modulate = SPRITE_TINT
	sprite.position = c.pos
	world.add_child(sprite)
	# 每人的动作错开、快慢略有不同，不要整齐划一地动
	var n := _sprites.size()
	sprite.play("default")
	sprite.frame = (n * 5) % frames.get_frame_count("default")
	sprite.speed_scale = 0.85 + 0.3 * fposmod(n * 0.618, 1.0)
	_sprites.append(sprite)
	world.add_child(_shadow(c.pos, c.get("shadow", 0.3)))


## 脚下的影子：比脚宽、前后够深的柔和椭圆，中间接触的地方更深（contact_shadow.gdshader）
func _shadow(pos: Vector3, radius: float) -> MeshInstance3D:
	var shadow := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.6, radius * 1.9)
	shadow.mesh = plane
	shadow.position = pos + Vector3(0, 0.01, 0)
	var mat := ShaderMaterial.new()
	mat.shader = SHADOW_SHADER
	shadow.material_override = mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return shadow


## 一团柔光（圆形渐变，越往外越透明），颜色和透明度用 modulate
func _halo(color: Color, size: float) -> Sprite3D:
	if _halo_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(1, 1, 1, pow(clampf(1.0 - d, 0.0, 1.0), 2.2)))
		_halo_tex = ImageTexture.create_from_image(img)
	var halo := Sprite3D.new()
	halo.texture = _halo_tex
	halo.modulate = color
	halo.pixel_size = size / 32.0
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.shaded = false
	halo.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return halo


## 栏杆边发光的铃兰（贴图是 2×2 的四朵花）
func _add_lilies() -> void:
	var img := _image(ART + "props/fx_linglanhua_207.png")
	if img == null:
		return
	var tex := ImageTexture.create_from_image(img)
	var spots := [[-3.0, 1.95, 0], [-2.1, 2.15, 3], [-5.2, 2.05, 1], [1.5, 2.0, 2], [4.2, 2.2, 0], [6.6, 1.95, 3], [-1.9, 1.9, 1],
		[-8.3, 2.0, 2], [-9.6, 2.2, 0], [8.0, 2.1, 1], [9.3, 1.95, 3]]
	for s: Array in spots:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2((s[2] % 2) * 256, floori(s[2] / 2.0) * 256, 256, 256)
		var lily := Sprite3D.new()
		lily.texture = atlas
		lily.pixel_size = 0.0015
		lily.offset = Vector2(0, 110)
		lily.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lily.shaded = false
		lily.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		lily.modulate = Color(0.85, 0.95, 0.9)
		lily.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lily.position = Vector3(s[0], 0.0, s[1])
		world.add_child(lily)
		var halo := _halo(Color(0.75, 1.0, 0.85, 0.35), 0.9)
		halo.position = lily.position + Vector3(0, 0.25, 0.02)
		world.add_child(halo)


## 灯笼串：红白相间，挂在下垂的绳子上，轻轻摇晃
func _add_lanterns() -> void:
	var images: Array[ImageTexture] = []
	for colors: Array in LANTERN_COLORS:
		var img := Image.create(8, LANTERN_ROWS.size(), false, Image.FORMAT_RGBA8)
		for y in LANTERN_ROWS.size():
			var row: String = LANTERN_ROWS[y]
			for x in row.length():
				if row[x] != ".":
					img.set_pixel(x, y, Color(colors[int(row[x])]))
		images.append(ImageTexture.create_from_image(img))
	# 绳子：分段的细条
	var prev: Vector3 = LANTERN_ROPE[0]
	for i in range(1, 25):
		var p := _rope_point(float(i) / 24.0)
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.025, 0.025, prev.distance_to(p))
		seg.mesh = box
		seg.material_override = _rail_mat
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(seg)
		seg.look_at_from_position((prev + p) * 0.5, p, Vector3.UP)
		prev = p
	for i in LANTERN_COUNT:
		var k := (float(i) + 0.5) / float(LANTERN_COUNT)
		var pivot := Node3D.new()
		pivot.position = _rope_point(k)
		world.add_child(pivot)
		var lantern := Sprite3D.new()
		lantern.texture = images[i % 2]
		lantern.pixel_size = 0.036
		lantern.centered = false
		lantern.offset = Vector2(-4, -LANTERN_ROWS.size())
		lantern.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lantern.shaded = false
		lantern.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		lantern.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(lantern)
		var halo := _halo(Color(1.0, 0.62, 0.32, 0.45) if i % 2 == 0 else Color(1.0, 0.85, 0.6, 0.4), 1.3)
		halo.position = Vector3(0, -0.2, 0.01)
		pivot.add_child(halo)
		pivot.set_meta("phase", randf() * TAU)
		_lanterns.append(pivot)


## 绳子上 k（0~1）处的点：两端之间按抛物线下垂
func _rope_point(k: float) -> Vector3:
	var a: Vector3 = LANTERN_ROPE[0]
	var b: Vector3 = LANTERN_ROPE[1]
	return a.lerp(b, k) - Vector3(0, LANTERN_SAG * 4.0 * k * (1.0 - k), 0)


## 草地上飘的萤火虫
func _add_fireflies() -> void:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.set_pixel(1, 1, Color("f6ffb0"))
	for p: Vector2i in [Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 0), Vector2i(1, 2)]:
		img.set_pixel(p.x, p.y, Color(0.75, 1.0, 0.45, 0.55))
	var tex := ImageTexture.create_from_image(img)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 34:
		var fly := Sprite3D.new()
		fly.texture = tex
		fly.pixel_size = 0.03
		fly.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fly.shaded = false
		fly.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		fly.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		fly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(fly)
		var glow := _halo(Color(0.7, 1.0, 0.4, 0.3), 0.35)
		fly.add_child(glow)
		var side := -1.0 if i % 2 == 0 else 1.0
		_fireflies.append({"node": fly, "base": Vector3(side * rng.randf_range(0.8, 10.0), rng.randf_range(0.25, 1.6), rng.randf_range(1.8, 9.0)),
			"speed": Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.3, 0.7), rng.randf_range(0.2, 0.45)), "phase": rng.randf() * TAU})


# ---------- 界面 ----------

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.1, 0.78)
	style.border_color = Color("8f896f")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(3)
	return style


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
	panel.position = Vector2(12, 12)
	panel.add_theme_stylebox_override("panel", _panel())
	root.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Jeff FX · 夏日花火大会"
	heading.add_theme_color_override("font_color", Color("ffd27a"))
	column.add_child(heading)
	var hint := Label.new()
	hint.text = "按「放烟花」（或空格）开始\nEsc 菜单：切换测试场景"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("91a5b4"))
	column.add_child(hint)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("a9becd"))
	column.add_child(status)

	button = Button.new()
	button.text = "放烟花"
	button.add_theme_font_size_override("font_size", 22)
	button.custom_minimum_size = Vector2(196, 64)
	button.focus_mode = Control.FOCUS_NONE
	var icon := _image(ART + "props/fx_hanabi_101.png")
	if icon != null:
		button.icon = ImageTexture.create_from_image(icon)
	button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button.position = Vector2(-98, -88)
	button.pressed.connect(_start_show)
	root.add_child(button)


func _update_status() -> void:
	var total := _fx.size() + _queue.size()
	if _missing:
		status.text = "缺少本机素材 assets/convallaria（见 README），只显示夜空和烟花"
	elif not _queue.is_empty():
		status.text = "烟花准备中 %d / %d" % [_fx.size(), total]
	elif _stage == "idle":
		status.text = "%d 种烟花已准备好" % total
	else:
		status.text = "花火大会进行中……"
	button.disabled = not _queue.is_empty() or _stage != "idle"
	button.text = "放烟花" if _stage == "idle" else "观赏中"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE and not button.disabled:
		_start_show()


# ---------- 烟花：后台渲染 ----------

## 每帧检查后台渲染：一次渲染一款（每款内部已经多线程），完成后做成动画帧
func _pump_render() -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_group_task_completed(_task):
			return
		WorkerThreadPool.wait_for_group_task_completion(_task)
		_task = -1
		_store(_queue.pop_front(), _job)
		_job = null
		_update_status()
	if _queue.is_empty():
		return
	var preset: Resource = Builtin.find(_queue[0])
	if preset == null:
		push_warning("没有这款烟花：" + _queue[0])
		_queue.pop_front()
		return
	# 烟花自带的「光源」图层（照亮夜空的一大团点阵光）放大到三维天空里会变成一块方形的网点，
	# 这里关掉，改由场景在炸点放一团平滑的柔光，并照亮整个场景
	preset = preset.clone()
	for layer: Dictionary in preset.layers:
		if layer.get("module", "") == "light":
			layer["enabled"] = false
	_job = FxRenderer.make_job(preset)
	_task = FxRenderer.start_async(_job)


func _store(id: String, job: RefCounted) -> void:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", job.fps)
	frames.set_animation_loop("default", job.loop)
	var images: Array = job.images()
	for i in images.size():
		if images[i] != null:
			frames.add_frame("default", ImageTexture.create_from_image(images[i]), job.durations[i] if i < job.durations.size() else 1.0)
	# 炸开时照亮场景的颜色：主色板中间偏亮的那一格
	var color := Color(1.0, 0.85, 0.6)
	var pal: Variant = Builtin.find(id).globals.get("palette_main")
	if pal is PackedColorArray and (pal as PackedColorArray).size() > 4:
		color = (pal as PackedColorArray)[4]
	# 放一遍要多少秒（循环的烟花按节目单里的 hold 算）
	var length := 0.0
	for i in images.size():
		length += (job.durations[i] if i < job.durations.size() else 1.0) / float(job.fps)
	_fx[id] = {"frames": frames, "origin": job.origin, "size": Vector2(job.w, job.h), "color": color, "length": length}


# ---------- 表演 ----------

func _start_show() -> void:
	if _stage != "idle" or not _queue.is_empty():
		return
	_stage = "up"
	_t = 0.0
	_next = 0
	_bursts.clear()
	_from = camera.global_transform
	_update_status()


func _launch(item: Dictionary) -> void:
	var data: Dictionary = _fx.get(item.id, {})
	if data.is_empty():
		return
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = data.frames
	sprite.centered = false
	sprite.offset = Vector2(-data.origin.x, -(data.size.y - data.origin.y))
	sprite.pixel_size = FW_PIXEL * float(item.get("scale", 1.0))
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# 柔光、叠加光、半透明烟要按透明度混合，不能用透明裁切
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.shaded = false
	sprite.render_priority = item.get("order", ORDER_SHELLS)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 越远越暗、略偏冷，有前后层次
	var haze := _haze(item.depth)
	sprite.modulate = Color(haze, haze, lerpf(1.0, haze, 0.6))
	fireworks.add_child(sprite)
	sprite.global_position = _show_point(Vector2(item.x, item.get("y", BAY_Y)), item.depth)
	sprite.play("default")
	if item.has("hold"):
		_holds.append([_t + float(item.hold), sprite])
	else:
		sprite.animation_finished.connect(sprite.queue_free)
	if not item.id in GROUND_PIECES:
		var burst_at := sprite.global_position + Vector3.UP * Fireworks.RISE * sprite.pixel_size
		_bursts.append([_t + Fireworks.CLIMB, data.color * haze, burst_at, sprite.pixel_size])


## 离参考镜头 depth 米的烟花有多亮（1 = 近处，FAR_DIM = 最远处）
func _haze(depth: float) -> float:
	return lerpf(1.0, FAR_DIM, clampf((depth - NEAR_DEPTH) / (FAR_DEPTH - NEAR_DEPTH), 0.0, 1.0))


func _process(delta: float) -> void:
	_pump_render()
	_clock += delta
	_animate_props(delta)
	match _stage:
		"idle":
			_place_camera(_idle_transform(), REF_FOV)
		"up":
			_t += delta
			var k := smoothstep(0.0, 1.0, _t / CRANE_UP)
			_place_camera(_crane(_from, _sky_transform(), k), lerpf(REF_FOV, SKY_FOV, k))
			_set_focus(k)
			_run_program()
			if _t >= CRANE_UP:
				_stage = "show"
		"show":
			_t += delta
			_place_camera(_sky_transform(), lerpf(SKY_FOV, FINALE_FOV, _finale()))
			_run_program()
			if _next >= SHOW.size() and _t >= _show_end():
				_stage = "down"
				_from = camera.global_transform
				_from_fov = camera.fov
				_t = 0.0
		"down":
			_t += delta
			var k := smoothstep(0.0, 1.0, _t / CRANE_DOWN)
			_place_camera(_crane(_from, _idle_transform(), k), lerpf(_from_fov, REF_FOV, k))
			_set_focus(1.0 - k)
			_finish_holds()
			if _t >= CRANE_DOWN:
				_stage = "idle"
				_update_status()
	_apply_flash(delta)
	_fade_glows(delta)


## 待机：镜头在参考位置附近轻轻呼吸
func _idle_transform() -> Transform3D:
	return Transform3D(_ref_basis(), REF_POS + Vector3(sin(_clock * 0.31) * 0.12, sin(_clock * 0.23) * 0.05, 0))


## 看烟花时镜头朝着众人视线的方向，缓缓左右摇（从升到位那一刻开始，不跳）；压轴时退回人群后方、往下压
func _sky_transform() -> Transform3D:
	var t := _t - CRANE_UP if _stage == "show" else 0.0
	var f := _finale()
	var yaw := lerpf(GAZE_YAW + sin(t * 0.22) * 4.0, FINALE_YAW, f)
	var pitch := lerpf(SKY_PITCH, FINALE_PITCH, f)
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)), SKY_POS.lerp(FINALE_POS, f))


## 节目结束的时刻：每一发发射时刻加上它放完的时长，取最晚的，再看 SHOW_TAIL 秒
func _show_end() -> float:
	var end := 0.0
	for item: Dictionary in SHOW:
		var data: Dictionary = _fx.get(item.id, {})
		end = maxf(end, float(item.t) + float(item.get("hold", data.get("length", 0.0))))
	return end + SHOW_TAIL


## 压轴运镜的进度（0~1）
func _finale() -> float:
	return smoothstep(FINALE_T, FINALE_T + 1.8, _t) if _stage == "show" else 0.0


## 升降镜头：位置先升后移（弧线），朝向按四元数插值（升起时一边仰起一边转向右边）
func _crane(from: Transform3D, to: Transform3D, k: float) -> Transform3D:
	var rise := smoothstep(0.0, 0.7, k)
	var pos := Vector3(lerpf(from.origin.x, to.origin.x, k), lerpf(from.origin.y, to.origin.y, rise), lerpf(from.origin.z, to.origin.z, k))
	var rot := from.basis.get_rotation_quaternion().slerp(to.basis.get_rotation_quaternion(), k)
	return Transform3D(Basis(rot), pos)


func _place_camera(t: Transform3D, fov: float) -> void:
	camera.global_transform = t
	camera.fov = fov


## 移轴模糊：看人群时上下模糊，仰望夜空时几乎不模糊
func _set_focus(sky: float) -> void:
	_post.set_shader_parameter("max_blur", lerpf(2.6, 0.6, sky))
	_post.set_shader_parameter("focus_half", lerpf(0.2, 0.32, sky))


func _run_program() -> void:
	while _next < SHOW.size() and float(SHOW[_next].t) <= _t:
		_launch(SHOW[_next])
		_next += 1
	for i in range(_bursts.size() - 1, -1, -1):
		if _bursts[i][0] <= _t:
			var c: Color = _bursts[i][1]
			_flash = Color(maxf(_flash.r, c.r * 0.3), maxf(_flash.g, c.g * 0.3), maxf(_flash.b, c.b * 0.3))
			var glow := _halo(Color(c.r, c.g, c.b, 0.0), 190.0 * float(_bursts[i][3]))
			glow.render_priority = ORDER_SHELLS - 1
			fireworks.add_child(glow)
			glow.global_position = _bursts[i][2]
			_glows.append([glow, 0.0])
			_bursts.remove_at(i)
	_finish_holds()


## 循环播放的烟花（节目单里带 hold 的）放够时间后移除
func _finish_holds() -> void:
	for i in range(_holds.size() - 1, -1, -1):
		var node: Node = _holds[i][1]
		if _stage == "down" or _holds[i][0] <= _t:
			if is_instance_valid(node):
				node.queue_free()
			_holds.remove_at(i)


## 炸开的闪光照亮夜空、远景、草地、栏杆和人物，然后很快暗下去
func _apply_flash(delta: float) -> void:
	_flash = _flash * exp(-3.0 * delta)
	var f := Vector3(_flash.r, _flash.g, _flash.b)
	_sky.set_shader_parameter("flash", f)
	for item: Array in _lit:
		(item[0] as ShaderMaterial).set_shader_parameter("flash", f * float(item[1]))
	_rail_mat.albedo_color = Color(0.1, 0.08, 0.11) + _flash * 0.35
	for sprite: SpriteBase3D in _sprites:
		sprite.modulate = SPRITE_TINT + _flash * 0.6


## 炸点的柔光：很快亮起，再慢慢暗下去
func _fade_glows(delta: float) -> void:
	for i in range(_glows.size() - 1, -1, -1):
		var glow: Sprite3D = _glows[i][0]
		var age: float = _glows[i][1] + delta
		_glows[i][1] = age
		if age > 1.8 or not is_instance_valid(glow):
			if is_instance_valid(glow):
				glow.queue_free()
			_glows.remove_at(i)
			continue
		glow.modulate.a = 0.32 * smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.15, 1.8, age))


## 灯笼摇晃、萤火虫飘飞闪烁
func _animate_props(_delta: float) -> void:
	for pivot: Node3D in _lanterns:
		var ph: float = pivot.get_meta("phase")
		pivot.rotation.z = sin(_clock * 1.3 + ph) * 0.06
	for fly: Dictionary in _fireflies:
		var s: Vector3 = fly.speed
		var ph: float = fly.phase
		var node: Sprite3D = fly.node
		node.position = fly.base + Vector3(sin(_clock * s.x + ph) * 0.9, sin(_clock * s.y + ph * 1.7) * 0.35, cos(_clock * s.z + ph * 0.6) * 0.7)
		var blink := clampf(0.5 + 0.8 * sin(_clock * 1.7 + ph * 3.0), 0.0, 1.0)
		node.modulate = Color(1, 1, 1, blink)
