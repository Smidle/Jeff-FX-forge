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
const Catalog := preload("../presets/library_catalog.gd")
const Builtin := preload("../presets/builtin_presets.gd")
const FxPreset := preload("../core/fx_preset.gd")
const FxRenderer := preload("../core/fx_renderer.gd")
const FxSession := preload("fx_session.gd")

## 来源下拉框各项对应的制作者（第 0 项是全部效果）
const SOURCES := ["", "claude", "codex", "pixelfx"]
const CATEGORIES := [["", "全部"], ["combat", "战斗打击"], ["element", "爆炸与元素"], ["magic", "魔法与状态"], ["env", "环境与通用"], ["classic_environment", "经典 · 环境"], ["classic_wuxia", "经典 · 武侠"], ["classic_xianxia", "经典 · 仙侠"], ["classic_magic", "经典 · 魔法"], ["custom", "我的预设"]]
const THUMB := 56
## 缩略图在这几个时刻里挑不透明像素最多的一帧
const THUMB_SAMPLES := [0.2, 0.35, 0.5, 0.65]
const MENU_ACTIONS := ["open", "rename", "duplicate", "show", "delete"]

var _search: LineEdit
var _source: OptionButton
var _category: OptionButton
var _usage: OptionButton
var _subtype: OptionButton
var _style: OptionButton
var _details: VBoxContainer
var _facets: Dictionary = {}
var _count: Label
var _loaded: Dictionary = {}
var _loaded_order: Array[String] = []
const LOADED_LIMIT := 12
var _list: ItemList
## Each descriptor is metadata-only until selected; only a small resource cache is retained.
## {preset, path, builtin, key, metadata}
var _entries: Array = []
var _thumbs := {}
var _queue: Array = []
var _queuing_thumbnails := false
var _thumbnail_refresh_pending := true
var _thumb_stamps: Dictionary = {}
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
	for text: String in [I18n.T("全部效果"), I18n.T("Claude 制作"), I18n.T("Codex 制作"), I18n.T("pixelfx 升级版")]:
		_source.add_item(text)
	_source.item_selected.connect(func(_i: int) -> void: _rebuild())
	add_child(_source)

	_usage = _add_facet(self, "battle", I18n.T("全部用途"))
	_subtype = _add_facet(self, "school", I18n.T("全部子类"))
	_style = _add_facet(self, "style", I18n.T("全部画风"))
	var more := Button.new()
	more.text = I18n.T("更多筛选")
	more.toggle_mode = true
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(more)
	_details = VBoxContainer.new()
	_details.visible = false
	add_child(_details)
	more.toggled.connect(func(open: bool) -> void: _details.visible = open)
	_add_facet(_details, "method", I18n.T("全部制作方式"))
	_add_facet(_details, "theme", I18n.T("全部题材"))
	_add_facet(_details, "elements", I18n.T("全部元素"))
	_add_facet(_details, "playback", I18n.T("全部播放类型"))
	_add_facet(_details, "anchor", I18n.T("全部空间朝向"))
	_add_facet(_details, "space", I18n.T("全部位置归属"))
	_category = OptionButton.new()
	for c: Array in CATEGORIES:
		_category.add_item(I18n.T(c[1]))
	_category.tooltip_text = I18n.T("原有分类与我的预设")
	_category.item_selected.connect(func(_i: int) -> void: _rebuild())
	_details.add_child(_category)
	var reset := Button.new()
	reset.text = I18n.T("清除筛选")
	reset.pressed.connect(_clear_filters)
	_details.add_child(reset)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12 * scale)
	add_child(_count)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.icon_mode = ItemList.ICON_MODE_TOP
	_list.max_columns = 2
	_list.same_column_width = true
	_list.fixed_column_width = int(88 * scale)
	_list.fixed_icon_size = Vector2i(_thumb_px, _thumb_px)
	_list.max_text_lines = 3
	_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_list.item_selected.connect(_on_selected)
	_list.allow_rmb_select = true
	_list.item_clicked.connect(_on_item_clicked)
	# 按宽度自动决定分几列
	_list.resized.connect(func() -> void:
		_list.max_columns = maxi(1, int(_list.size.x / (_list.fixed_column_width + 10 * scale))))
	add_child(_list)
	_list.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _request_thumbnail_refresh())
	_list.resized.connect(_request_thumbnail_refresh)
	_list.visibility_changed.connect(_request_thumbnail_refresh)

	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu)
	add_child(_menu)

	var blank := Image.create_empty(_thumb_px, _thumb_px, false, Image.FORMAT_RGBA8)
	blank.fill(Color(0.12, 0.12, 0.16))
	_placeholder = ImageTexture.create_from_image(blank)
	refresh()


## Refresh descriptors, never instantiate the entire built-in resource library.
func refresh() -> void:
	Catalog.invalidate()
	_entries.clear()
	_loaded.clear()
	_loaded_order.clear()
	for definition: Dictionary in Builtin._defs():
		var metadata := Catalog.pixel_metadata(definition)
		_entries.append({"preset": null, "path": "", "builtin": metadata.id, "key": "builtin:" + str(metadata.id), "metadata": metadata})
	for metadata: Dictionary in Classic.catalog():
		_entries.append({"preset": null, "path": "", "builtin": metadata.id, "key": "builtin:" + str(metadata.id), "metadata": metadata})
	var dir := FxSession.USER_DIR
	if DirAccess.dir_exists_absolute(dir):
		var files := DirAccess.get_files_at(dir)
		files.sort()
		for f: String in files:
			if not f.ends_with(".tres"):
				continue
			var path := dir.path_join(f)
			# Catalog refresh must not replace a Resource already used by another scene.
			var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if res is FxPreset:
				var key := "user:" + path
				_entries.append({"preset": res, "path": path, "builtin": "", "key": key, "metadata": _metadata_for_saved(res)})
				_thumbs.erase(key)
	var counts := {"claude": 0, "codex": 0, "pixelfx": 0}
	var active_keys: Dictionary = {}
	for entry: Dictionary in _entries:
		active_keys[entry.key] = true
		var maker := Catalog.maker_of(entry.metadata)
		counts[maker] = int(counts.get(maker, 0)) + 1
		var path := str(entry.metadata.get("thumbnail", ""))
		if not path.is_empty() and FileAccess.file_exists(path):
			var stamp := FileAccess.get_modified_time(path)
			if _thumb_stamps.get(entry.key, -1) != stamp:
				_thumbs.erase(entry.key)
			_thumb_stamps[entry.key] = stamp
	for key: String in _thumbs.keys():
		if not active_keys.has(key):
			_thumbs.erase(key)
			_thumb_stamps.erase(key)
	_source.set_item_text(0, I18n.T("全部效果 · %d 款") % _entries.size())
	_source.set_item_text(1, I18n.T("Claude 制作 · %d 款") % counts["claude"])
	_source.set_item_text(2, I18n.T("Codex 制作 · %d 款") % counts["codex"])
	_source.set_item_text(3, I18n.T("pixelfx 升级版 · %d 款") % counts["pixelfx"])
	_queue.clear()
	_update_subtypes()
	_rebuild()


func _metadata_for_saved(p: FxPreset) -> Dictionary:
	var metadata := p.library_metadata.duplicate(true)
	if metadata.is_empty():
		if p.legacy_recipe != null and Classic.has_id(p.legacy_recipe.id):
			metadata = Catalog.classic_metadata(p.legacy_recipe.id)
		else:
			metadata = Catalog.pixel_metadata({"id": p.preset_id, "name": p.display_name, "description": p.description, "category": p.category, "globals": p.globals})
	metadata["display_name"] = p.display_name
	metadata["description"] = p.description
	metadata["id"] = p.preset_id
	metadata["category"] = "custom"
	metadata["is_classic"] = p.legacy_recipe != null
	# Playback belongs to the saved recipe; copied catalog tags can be stale
	# after the user changes its loop setting. Do not mutate stored metadata.
	var is_looping: bool = bool(p.legacy_recipe.looping) if p.legacy_recipe != null else bool(p.globals.get("loop", false))
	metadata["playback"] = "loop" if is_looping else "one_shot"
	return metadata


func _preset_for(entry: Dictionary) -> FxPreset:
	if entry.preset != null:
		return entry.preset
	var key := str(entry.key)
	if _loaded.has(key):
		_loaded_order.erase(key)
		_loaded_order.append(key)
		return _loaded[key]
	var p: FxPreset = Classic.find(str(entry.builtin)) if bool(entry.metadata.get("is_classic", false)) else Builtin.find(str(entry.builtin))
	if p == null:
		return null
	p.library_metadata = (entry.metadata as Dictionary).duplicate(true)
	_loaded[key] = p
	_loaded_order.append(key)
	while _loaded_order.size() > LOADED_LIMIT:
		_loaded.erase(_loaded_order.pop_front())
	return p


func _add_facet(parent: Node, facet: String, empty_label: String) -> OptionButton:
	var option := OptionButton.new()
	option.add_item(empty_label)
	option.set_item_metadata(0, "")
	for choice: Dictionary in Catalog.options(facet):
		option.add_item(I18n.T(str(choice.label)))
		option.set_item_metadata(option.item_count - 1, choice.id)
	option.item_selected.connect(func(_i: int) -> void:
		if facet == "battle":
			_update_subtypes()
		_rebuild())
	parent.add_child(option)
	_facets[facet] = option
	return option


func _facet_value(facet: String) -> String:
	var option: OptionButton = _facets[facet]
	return str(option.get_item_metadata(maxi(0, option.selected)))


## Only schools that actually contain effects under the chosen use are listed.
func _update_subtypes() -> void:
	var previous := _facet_value("school")
	var battle := _facet_value("battle")
	var present: Dictionary = {}
	for entry: Dictionary in _entries:
		if battle.is_empty() or Catalog.facet_value(entry.metadata, "battle") == battle:
			present[Catalog.facet_value(entry.metadata, "school")] = true
	_subtype.clear()
	_subtype.add_item(I18n.T("全部子类"))
	_subtype.set_item_metadata(0, "")
	_subtype.select(0)
	for choice: Dictionary in Catalog.options("school"):
		if not present.has(str(choice.id)):
			continue
		_subtype.add_item(I18n.T(str(choice.label)))
		var index := _subtype.item_count - 1
		_subtype.set_item_metadata(index, choice.id)
		if str(choice.id) == previous:
			_subtype.select(index)


func _clear_filters() -> void:
	_search.text = ""
	_source.select(0)
	_category.select(0)
	for option: OptionButton in _facets.values():
		option.select(0)
	_update_subtypes()
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
	if not _has_thumbnail_view():
		_queue.clear()
		_thumbnail_refresh_pending = true
		return
	if _thumbnail_refresh_pending:
		_thumbnail_refresh_pending = false
		_queue_visible_thumbnails()
	if _queue.is_empty():
		return
	var key: String = _queue.pop_front()
	for entry: Dictionary in _entries:
		if entry.key != key:
			continue
		var thumbnail := str(entry.metadata.get("thumbnail", ""))
		if not str(entry.path).is_empty():
			var saved: FxPreset = entry.preset
			if saved != null and not saved.preview_png.is_empty():
				_thumbs[key] = _make_thumb(saved)
				_update_icon(key)
				return
		if bool(entry.metadata.get("is_classic", false)):
			# A stored actual capture needs no recipe, particle simulation or texture imports.
			if not thumbnail.is_empty() and FileAccess.file_exists(thumbnail):
				var img := Image.new()
				if img.load_png_from_buffer(FileAccess.get_file_as_bytes(thumbnail)) == OK:
					_thumbs[key] = _thumb_from_image(img, true)
			if not _thumbs.has(key):
				_thumbs[key] = _placeholder
		else:
			var p := _preset_for(entry)
			_thumbs[key] = _make_thumb(p) if p != null else _placeholder
		_update_icon(key)
		return


func _request_thumbnail_refresh() -> void:
	# Resize, scrollbar and visibility changes may happen together in one layout pass.
	# Coalesce them; never force another layout from inside a resize callback.
	_thumbnail_refresh_pending = true


func _has_thumbnail_view() -> bool:
	return is_instance_valid(_list) and _list.is_inside_tree() and _list.is_visible_in_tree() and _list.item_count > 0 and _list.size.is_finite() and _list.size.x >= float(_thumb_px) and _list.size.y > 0.0


func _queue_visible_thumbnails() -> void:
	if _queuing_thumbnails:
		return
	_queue.clear()
	if not _has_thumbnail_view():
		return
	_queuing_thumbnails = true
	_list.force_update_list_size()
	# A container may have been resized again by the forced layout.
	if not _has_thumbnail_view():
		_queuing_thumbnails = false
		return
	var scroll := _list.get_v_scroll_bar().value
	if not is_finite(scroll):
		_queuing_thumbnails = false
		return
	var view := Rect2(0, scroll, _list.size.x, _list.size.y)
	for index in _list.item_count:
		var entry: Dictionary = _entries[_list.get_item_metadata(index)]
		if _thumbs.has(entry.key):
			continue
		# Do not expand the final column while a small/hidden ItemList is laying out.
		# Expanded widths can temporarily be negative when the available width is zero.
		var rect := _list.get_item_rect(index, false)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not rect.position.is_finite() or not rect.size.is_finite():
			continue
		if rect.intersects(view.grow(_thumb_px)) and not _queue.has(entry.key):
			_queue.append(entry.key)
	_queuing_thumbnails = false


func _matches(metadata: Dictionary, query: String) -> bool:
	for facet: String in _facets:
		var value := _facet_value(facet)
		if value.is_empty():
			continue
		var stored: Variant = Catalog.facet_value(metadata, facet)
		if stored is Array or stored is PackedStringArray:
			if not value in stored:
				return false
		elif str(stored) != value:
			return false
	if query.is_empty():
		return true
	var words := [str(metadata.get("id", "")), str(metadata.get("display_name", "")), str(metadata.get("description", ""))]
	for facet: String in Catalog.LABELS:
		var stored: Variant = Catalog.facet_value(metadata, facet)
		var values: Array = Array(stored) if stored is Array or stored is PackedStringArray else [str(stored)]
		for value: String in values:
			words.append(value)
			words.append(Catalog.name_for(facet, value))
	for tag: String in metadata.get("tags", []):
		words.append(tag)
	var haystack := " ".join(words).to_lower()
	for token: String in query.split(" ", false):
		if not haystack.contains(token):
			return false
	return true


func _rebuild() -> void:
	if not is_instance_valid(_list):
		return
	_list.clear()
	var query := _search.text.strip_edges().to_lower()
	var category: String = CATEGORIES[maxi(_category.selected, 0)][0]
	for i in _entries.size():
		var entry: Dictionary = _entries[i]
		var metadata: Dictionary = entry.metadata
		# 来源按制作者筛选，与是否走三维运行时无关（飞弹是三维配方，但属于 Claude 制作）
		var maker := Catalog.maker_of(metadata)
		if _source.selected > 0 and maker != SOURCES[_source.selected]:
			continue
		if not category.is_empty() and str(metadata.get("category", "custom")) != category:
			continue
		if not _matches(metadata, query):
			continue
		var method := I18n.T(Catalog.name_for("method", str(metadata.get("method", ""))))
		var playback := I18n.T(Catalog.name_for("playback", str(metadata.get("playback", ""))))
		var text := "%s\n%s · %s" % [I18n.T(str(metadata.display_name)), method, playback]
		var index := _list.add_item(text, _thumbs.get(entry.key, _placeholder))
		_list.set_item_metadata(index, i)
		var where := I18n.T("我的预设 · ") + str(entry.path).get_file() if not str(entry.path).is_empty() else I18n.T("内置 · ") + I18n.T(Catalog.name_for("style", str(metadata.get("style", ""))))
		var facets := "%s / %s · %s" % [I18n.T(Catalog.name_for("battle", str(Catalog.facet_value(metadata, "battle")))), I18n.T(Catalog.name_for("school", str(Catalog.facet_value(metadata, "school")))), I18n.T(Catalog.name_for("anchor", str(metadata.get("anchor", ""))))]
		_list.set_item_tooltip(index, "%s\n%s\n%s\n%s" % [I18n.T(str(metadata.display_name)), where, facets, I18n.T(str(metadata.get("description", "")))])
		if entry.key == _selected_key:
			_list.select(index)
	_count.text = I18n.T("显示 %d / %d 款") % [_list.item_count, _entries.size()]
	_queue.clear()
	_request_thumbnail_refresh()
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
	var p := _preset_for(e)
	if p != null:
		preset_chosen.emit(p, e["path"], e["builtin"])


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
	var p := _preset_for(e)
	if p != null:
		preset_action.emit(MENU_ACTIONS[id], p, e["path"], e["builtin"])


## 渲染代表帧做缩略图：在几个时刻里挑不透明像素最多（画面最饱满）的一帧；特效整体偏暗时用浅色底
func _make_thumb(p: FxPreset) -> Texture2D:
	return _thumb_from_image(representative_frame(p), p.legacy_recipe != null)


func _thumb_from_image(img: Image, classic: bool) -> Texture2D:
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
	out.fill(img.get_pixel(0, 0) if classic else (Color(0.9, 0.88, 0.82) if dark else Color(0.12, 0.12, 0.16)))
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
