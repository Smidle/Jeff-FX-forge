@tool
extends VBoxContainer
## 预设库：内置预设 + 我的预设（res://fx_forge_presets/），带缩略图、搜索和分类筛选。
## 缩略图在主界面空闲时逐个生成（process_thumbnails 每帧最多一个）。

signal preset_chosen(preset: Resource, path: String, builtin_id: String)

const Builtin := preload("../presets/builtin_presets.gd")
const FxPreset := preload("../core/fx_preset.gd")
const FxRenderer := preload("../core/fx_renderer.gd")
const FxSession := preload("fx_session.gd")

const CATEGORIES := [["", "全部"], ["combat", "战斗打击"], ["element", "爆炸与元素"], ["magic", "魔法与状态"], ["env", "环境与通用"], ["custom", "我的预设"]]
const THUMB := 56

var _search: LineEdit
var _category: OptionButton
var _list: ItemList
## 每项 {preset, path, builtin, key}
var _entries: Array = []
var _thumbs := {}
var _queue: Array = []
var _placeholder: Texture2D
var _selected_key := ""
var _thumb_px := THUMB


func _ready() -> void:
	var scale := EditorInterface.get_editor_scale()
	var theme := EditorInterface.get_editor_theme()
	_thumb_px = int(THUMB * scale)
	custom_minimum_size.x = 210 * scale

	var title := Label.new()
	title.text = "预设库"
	title.add_theme_font_override("font", theme.get_font(&"bold", &"EditorFonts"))
	add_child(title)

	_search = LineEdit.new()
	_search.placeholder_text = "搜索预设…"
	_search.clear_button_enabled = true
	_search.right_icon = theme.get_icon(&"Search", &"EditorIcons")
	_search.text_changed.connect(func(_t: String) -> void: _rebuild())
	add_child(_search)

	_category = OptionButton.new()
	for c: Array in CATEGORIES:
		_category.add_item(c[1])
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
	# 按宽度自动决定分几列
	_list.resized.connect(func() -> void:
		_list.max_columns = maxi(1, int(_list.size.x / (_list.fixed_column_width + 10 * scale))))
	add_child(_list)

	var blank := Image.create_empty(_thumb_px, _thumb_px, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0.12, 0.12, 0.16))
	_placeholder = ImageTexture.create_from_image(blank)
	refresh()


## 重新扫描预设（保存 / 另存为之后调用）
func refresh() -> void:
	_entries.clear()
	for p: FxPreset in Builtin.all():
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
	var q := _search.text.strip_edges().to_lower()
	var cat: String = CATEGORIES[maxi(_category.selected, 0)][0]
	for i in _entries.size():
		var e: Dictionary = _entries[i]
		var p: FxPreset = e["preset"]
		var category := "custom" if not str(e["path"]).is_empty() else p.category
		if not cat.is_empty() and category != cat:
			continue
		if not q.is_empty() and not (p.display_name.to_lower().contains(q) or p.preset_id.to_lower().contains(q) or p.description.to_lower().contains(q)):
			continue
		var idx := _list.add_item(p.display_name, _thumbs.get(e["key"], _placeholder))
		_list.set_item_metadata(idx, i)
		var where := "我的预设 · " + str(e["path"]).get_file() if not str(e["path"]).is_empty() else "内置 · " + p.get_category_name()
		_list.set_item_tooltip(idx, "%s\n%s\n%s" % [p.display_name, where, p.description])
		if e["key"] == _selected_key:
			_list.select(idx)


func _update_icon(key: String) -> void:
	for i in _list.item_count:
		var e: Dictionary = _entries[_list.get_item_metadata(i)]
		if e["key"] == key:
			_list.set_item_icon(i, _thumbs[key])


func _on_selected(idx: int) -> void:
	var e: Dictionary = _entries[_list.get_item_metadata(idx)]
	_selected_key = e["key"]
	preset_chosen.emit(e["preset"], e["path"], e["builtin"])


## 渲染代表帧做缩略图；特效整体偏暗时用浅色底
func _make_thumb(p: FxPreset) -> Texture2D:
	var job := FxRenderer.make_job(p, {"frame_ratio": 0.4})
	FxRenderer.render_sync(job, false)
	var img: Image = job.results[0]["image"]
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
	out.fill(Color(0.9, 0.88, 0.82) if dark else Color(0.12, 0.12, 0.16))
	out.blend_rect(big, Rect2i(0, 0, tw, th), Vector2i((_thumb_px - tw) / 2, (_thumb_px - th) / 2))
	return ImageTexture.create_from_image(out)
