@tool
extends VBoxContainer
## 预设库：内置预设 + 我的预设（res://fx_forge_presets/），带缩略图、搜索和分类筛选。
## 缩略图在主界面空闲时逐个生成（process_thumbnails 每帧最多一个），取几个时刻里画面最饱满的一帧。
## 右键菜单：打开、重命名、复制、在文件系统中显示、删除（我的预设）；复制为我的预设（内置预设）。

signal preset_chosen(preset: Resource, path: String, builtin_id: String)
## action：open / rename / duplicate / show / delete
signal preset_action(action: String, preset: Resource, path: String, builtin_id: String)

const I18n := preload("i18n.gd")
const Classic := preload("../presets/classic_presets.gd")
const Builtin := preload("../presets/builtin_presets.gd")
const FxPreset := preload("../core/fx_preset.gd")
const FxRenderer := preload("../core/fx_renderer.gd")
const FxSession := preload("fx_session.gd")

const CATEGORIES := [["", "全部"], ["combat", "战斗打击"], ["element", "爆炸与元素"], ["magic", "魔法与状态"], ["env", "环境与通用"], ["classic_environment", "经典 · 环境"], ["classic_wuxia", "经典 · 武侠"], ["classic_xianxia", "经典 · 仙侠"], ["classic_magic", "经典 · 魔法"], ["custom", "我的预设"]]
const THUMB := 56
## 缩略图在这几个时刻里挑不透明像素最多的一帧
const THUMB_SAMPLES := [0.2, 0.35, 0.5, 0.65]
const MENU_ACTIONS := ["open", "rename", "duplicate", "show", "delete"]

var _search: LineEdit
var _source: OptionButton
var _category: OptionButton
var _list: ItemList
## 每项 {preset, path, builtin, key}
var _entries: Array = []
var _thumbs := {}
var _queue: Array = []
var _placeholder: Texture2D
var _selected_key := ""
var _thumb_px := THUMB
var _menu: PopupMenu
## 右键菜单对应的条目（_entries 的下标）
var _menu_entry := -1
## 右键点击也会选中条目：这时不当作「打开预设」
var _rmb_click := false


func _ready() -> void:
	var scale := EditorInterface.get_editor_scale()
	var theme := EditorInterface.get_editor_theme()
	_thumb_px = int(THUMB * scale)
	custom_minimum_size.x = 210 * scale

	var title := Label.new()
	title.text = I18n.T("预设库")
	title.add_theme_font_override("font", theme.get_font(&"bold", &"EditorFonts"))
	add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = I18n.T("搜索预设…")
	_search.clear_button_enabled = true
	_search.right_icon = theme.get_icon(&"Search", &"EditorIcons")
	_search.text_changed.connect(func(_t: String) -> void: _rebuild())
	add_child(_search)

	_source = OptionButton.new()
	for text: String in [I18n.T("全部效果 · 82 款"), I18n.T("像素工坊 · 38 款"), I18n.T("经典效果库 · 44 款")]:
		_source.add_item(text)
	_source.item_selected.connect(func(_i: int) -> void: _rebuild())
	add_child(_source)

	_category = OptionButton.new()
	for c: Array in CATEGORIES:
		_category.add_item(I18n.T(c[1]))
	_category.item_selected.connect(func(_i: int) -> void: _rebuild())
	add_child(_category)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 2
	_list.same_column_width = true
	_list.fixed_column_width = int(88 * scale)
	_list.fixed_icon_size = Vector2i(_thumb_px, _thumb_px)
	_list.max_text_lines = 2
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.item_selected.connect(_on_selected)
	_list.allow_rmb_select = true
	_list.item_clicked.connect(_on_item_clicked)
	# 按宽度自动决定分几列
	_list.resized.connect(func() -> void:
		_list.max_columns = maxi(1, int(_list.size.x / (_list.fixed_column_width + 10 * scale))))
	add_child(_list)

	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)

	var blank := Image.create_empty(_thumb_px, _thumb_px, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0.12, 0.12, 0.16))
	_placeholder = ImageTexture.create_from_image(blank)
	refresh()


## 重新扫描预设（保存 / 另存为之后调用）
func refresh() -> void:
	_entries.clear()
	for p: FxPreset in Builtin.all() + Classic.all():
		_entries.append({"preset": p, "path": "", "builtin": p.preset_id, "key": "builtin:" + p.preset_id})
	var dir := FxSession.USER_DIR
	if DirAccess.dir_exists_absolute(dir):
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f: String in files:
			if not f.ends_with(".tres"):
				continue
			var path := dir.path_join(f)
			var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
			if res is FxPreset:
				var key := "user:" + path
				_entries.append({"preset": res, "path": path, "builtin": "", "key": key})
				_thumbs.erase(key)
	var classic_count := 0
	for entry: Dictionary in _entries:
		if entry.preset.legacy_recipe != null:
			classic_count += 1
	_source.set_item_text(0, I18n.T("全部效果 · %d 款") % _entries.size())
	_source.set_item_text(1, I18n.T("像素工坊 · %d 款") % (_entries.size() - classic_count))
	_source.set_item_text(2, I18n.T("经典效果库 · %d 款") % classic_count)
	_queue.clear()
	for e: Dictionary in _entries:
		if not _thumbs.has(e["key"]):
			_queue.append(e["key"])
	_rebuild()


## 选中某个预设（不发信号）
func select_key(key: String) -> void:
	_selected_key = key
	_list.deselect_all()
	for i in _list.item_count:
		var e: Dictionary = _entries[_list.get_item_metadata(i)]
		if e["key"] == key:
			_list.select(i)
			_list.ensure_current_is_visible()
			return


func process_thumbnails() -> void:
	if _queue.is_empty():
		return
	var key: String = _queue.pop_front()
	for e: Dictionary in _entries:
		if e["key"] == key:
			_thumbs[key] = _make_thumb(e["preset"])
			_update_icon(key)
			return


func _rebuild() -> void:
	_list.clear()
	var priority: Array = []
	var q := _search.text.strip_edges().to_lower()
	var cat: String = CATEGORIES[maxi(_category.selected, 0)][0]
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var p: FxPreset = e["preset"]
		if (_source.selected == 1 and p.legacy_recipe != null) or (_source.selected == 2 and p.legacy_recipe == null):
			continue
		var category := "custom" if not str(e["path"]).is_empty() else p.category
		if not cat.is_empty() and category != cat:
			continue
		if not q.is_empty() and not (p.display_name.to_lower().contains(q) or p.preset_id.to_lower().contains(q) or p.description.to_lower().contains(q)):
			continue
		if not _thumbs.has(e["key"]):
			priority.append(e["key"])
		var idx := _list.add_item(I18n.T(p.display_name), _thumbs.get(e["key"], _placeholder))
		_list.set_item_metadata(idx, i)
		var where := I18n.T("我的预设 · ") + str(e["path"]).get_file() if not str(e["path"]).is_empty() else I18n.T("内置 · ") + I18n.T(p.get_category_name())
		_list.set_item_tooltip(idx, "%s\n%s\n%s" % [I18n.T(p.display_name), where, I18n.T(p.description)])
		if e["key"] == _selected_key:
			_list.select(idx)

	for key: String in _queue:
		if not priority.has(key):
			priority.append(key)
	_queue = priority
	_list.ensure_current_is_visible.call_deferred()


func _update_icon(key: String) -> void:
	for i in _list.item_count:
		var e: Dictionary = _entries[_list.get_item_metadata(i)]
		if e["key"] == key:
			_list.set_item_icon(i, _thumbs[key])


func _on_selected(idx: int) -> void:
	if _rmb_click:
		# 右键只是打开菜单：恢复原来的选中项
		_rmb_click = false
		select_key.call_deferred(_selected_key)
		return
	var e: Dictionary = _entries[_list.get_item_metadata(idx)]
	_selected_key = e["key"]
	preset_chosen.emit(e["preset"], e["path"], e["builtin"])


func _on_item_clicked(idx: int, at: Vector2, button: int) -> void:
	if button != MOUSE_BUTTON_RIGHT:
		return
	_rmb_click = true
	_menu_entry = _list.get_item_metadata(idx)
	var e: Dictionary = _entries[_menu_entry]
	var theme := EditorInterface.get_editor_theme()
	_menu.clear()
	_menu.add_icon_item(theme.get_icon(&"Load", &"EditorIcons"), I18n.T("打开"), 0)
	if str(e["path"]).is_empty():
		_menu.add_icon_item(theme.get_icon(&"Duplicate", &"EditorIcons"), I18n.T("复制为我的预设"), 2)
	else:
		_menu.add_icon_item(theme.get_icon(&"Rename", &"EditorIcons"), I18n.T("重命名…"), 1)
		_menu.add_icon_item(theme.get_icon(&"Duplicate", &"EditorIcons"), I18n.T("复制一份"), 2)
		_menu.add_icon_item(theme.get_icon(&"Filesystem", &"EditorIcons"), I18n.T("在文件系统中显示"), 3)
		_menu.add_separator()
		_menu.add_icon_item(theme.get_icon(&"Remove", &"EditorIcons"), I18n.T("删除…"), 4)
	_menu.reset_size()
	_menu.position = Vector2i(_list.get_screen_position() + at)
	_menu.popup()


func _on_menu(id: int) -> void:
	_rmb_click = false
	if _menu_entry < 0 or _menu_entry >= _entries.size() or id < 0 or id >= MENU_ACTIONS.size():
		return
	var e: Dictionary = _entries[_menu_entry]
	preset_action.emit(MENU_ACTIONS[id], e["preset"], e["path"], e["builtin"])


## 渲染代表帧做缩略图：在几个时刻里挑不透明像素最多（画面最饱满）的一帧；特效整体偏暗时用浅色底
func _make_thumb(p: FxPreset) -> Texture2D:
	var img := representative_frame(p)
	var w := img.get_width()
	var h := img.get_height()
	var k := float(_thumb_px) / float(maxi(w, h))
	if k >= 1.0:
		k = floorf(k)
	var tw := maxi(1, int(w * k))
	var th := maxi(1, int(h * k))
	var big := img.duplicate() as Image
	big.resize(tw, th, Image.INTERPOLATE_NEAREST)
	var lum := 0.0
	var n := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				lum += c.get_luminance()
				n += 1
	var dark := n > 0 and lum / n < 0.32
	var out := Image.create_empty(_thumb_px, _thumb_px, false, Image.FORMAT_RGBA8)
	out.fill(img.get_pixel(0, 0) if p.legacy_recipe != null else (Color(0.9, 0.88, 0.82) if dark else Color(0.12, 0.12, 0.16)))
	out.blend_rect(big, Rect2i(0, 0, tw, th), Vector2i((_thumb_px - tw) / 2, (_thumb_px - th) / 2))
	return ImageTexture.create_from_image(out)


## 预设最有代表性的一帧（不透明像素最多）
static func representative_frame(p: FxPreset) -> Image:
	if p.legacy_recipe != null:
			return Classic.thumbnail(p)
	var n := clampi(int(p.globals.get("frames", 12)), 1, 64)
	var ids := PackedInt32Array()
	for r: float in THUMB_SAMPLES:
		var f := clampi(int(r * n), 0, n - 1)
		if not ids.has(f):
			ids.append(f)
	var job := FxRenderer.make_job(p, {"frames": ids})
	FxRenderer.render_sync(job)
	var best: Dictionary = job.results[0]
	for r: Dictionary in job.results:
		if int(r["opaque"]) > int(best["opaque"]):
			best = r
	return best["image"]
