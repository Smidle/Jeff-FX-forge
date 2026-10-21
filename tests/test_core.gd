extends "res://tests/test_base.gd"
## 核心层单元测试：参数表、色板、后期合成（描边 / 清理 / 消散 / 翻转 / 柔光 / 打包）

const FxParams := preload("res://addons/fx_forge/core/fx_params.gd")
const FxPalette := preload("res://addons/fx_forge/core/fx_palette.gd")
const FxBuffer := preload("res://addons/fx_forge/core/fx_buffer.gd")
const FxPost := preload("res://addons/fx_forge/core/fx_post.gd")
const FxRenderer := preload("res://addons/fx_forge/core/fx_renderer.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")


func _settings(overrides: Dictionary = {}) -> Dictionary:
	var s := {
		"bayer": FxPalette.BAYER4, "dither_tab": FxPalette.FLAT, "dither_strength": 0.0,
		"dissolve": FxPost.Dissolve.DITHER, "alpha_levels": 3, "cleanup": false, "min_cluster": 1,
		"outline": FxPost.Outline.NONE, "outline_width": 1, "outline_square": false,
		"outline_rgb": Color(0, 0, 0), "soft": 0.0, "glow_rgb": Color(1, 1, 1),
		"flip_h": false, "flip_v": false,
	}
	s.merge(overrides, true)
	return s


## 两阶灰度色板：暗 0.25 / 亮 1.0
func _part(buf: FxBuffer, fade: float = 1.0) -> Dictionary:
	var c := PackedFloat32Array([0.25, 1.0])
	return {"buf": buf, "fade": fade, "r": c, "g": c, "b": c, "outline": true}


func _run(buf: FxBuffer, s: Dictionary, fade: float = 1.0) -> Dictionary:
	return FxPost.new(buf.w, buf.h).run([_part(buf, fade)], s)


func _count(res: Dictionary) -> int:
	var n := 0
	for c in res["pixels"] as PackedInt32Array:
		if c != 0:
			n += 1
	return n


func _at(res: Dictionary, w: int, x: int, y: int) -> int:
	return (res["pixels"] as PackedInt32Array)[y * w + x]


func test_params_normalize() -> bool:
	var defs := [
		FxParams.num("r", "半径", "R", 0.0, 10.0, 5.0),
		FxParams.integer("n", "数量", "N", 1, 4, 2),
		FxParams.choice("e", "曲线", "E", [["a", "A"], ["b", "B"]], "a"),
		FxParams.boolean("f", "开关", "F", false),
		FxParams.angle("ang", "角度", "Angle", 0.0),
	]
	var out := FxParams.normalize(defs, {"r": 99.0, "n": 2.6, "e": "zzz", "ang": -90.0, "extra": 1})
	check_eq(out["r"], 10.0, "数值被夹到上限")
	check_eq(out["n"], 3, "整数四舍五入")
	check_eq(out["e"], "a", "非法枚举回到默认值")
	check_eq(out["f"], false, "缺省的参数补上默认值")
	check_eq(out["ang"], 270.0, "角度绕回 0~360")
	check(not out.has("extra"), "多余的键被丢弃")
	return true


func test_apply_scale_only_marked() -> bool:
	var defs := [
		FxParams.num("radius", "半径", "R", 0.0, 100.0, 10.0, {scale = true}),
		FxParams.num("taper", "尖锐", "T", 0.0, 1.0, 0.5),
	]
	var out := FxParams.apply_scale(defs, {"radius": 10.0, "taper": 0.5}, 2.0)
	check_eq(out["radius"], 20.0, "尺寸参数跟随缩放")
	check_eq(out["taper"], 0.5, "比例参数不缩放")
	return true


func test_palettes_and_themes() -> bool:
	check_eq(FxPalette.colors_of("steel").size(), 6, "钢铁色板 6 阶")
	check_eq(FxPalette.colors_of("不存在"), FxPalette.colors_of("steel"), "未知色板回到钢铁")
	var custom := PackedColorArray([Color.BLACK, Color.WHITE])
	check_eq(FxPalette.colors_of(custom), custom, "自定义颜色原样使用")
	for id: String in FxPalette.THEMES:
		var slots := FxPalette.theme_slots(id)
		for key: String in ["main", "accent", "smoke"]:
			check(FxPalette.PALETTES.has(slots[key]), "主题 %s 的 %s 色板存在" % [id, key])
	for id: String in FxPalette.PALETTES:
		var cols := FxPalette.colors_of(id)
		check(cols.size() >= 4, "色板 %s 至少 4 阶" % id)
		check(cols[0].get_luminance() < cols[cols.size() - 1].get_luminance(), "色板 %s 从暗到亮" % id)
	check_eq(FxPalette.ramp_from_color(Color.ORANGE, 5).size(), 5, "单色生成色阶")
	return true


func test_bayer_tables() -> bool:
	var seen := {}
	for v in FxPalette.BAYER4:
		check(v > 0.0 and v < 1.0, "Bayer 阈值在 0~1 之间")
		seen[v] = true
	check_eq(seen.size(), 16, "4×4 Bayer 有 16 个不同阈值")
	seen.clear()
	for v in FxPalette.BAYER2:
		seen[v] = true
	check_eq(seen.size(), 4, "2×2 Bayer 有 4 个不同阈值")
	return true


func test_outline_round_and_square() -> bool:
	var buf := FxBuffer.new(9, 9)
	buf.plot(4, 4, 1.0, 1.0)
	var round_res := _run(buf, _settings({"outline": FxPost.Outline.OUTER}))
	check_eq(_count(round_res), 5, "圆角外描边：单像素 + 十字 4 个")
	var square_res := _run(buf, _settings({"outline": FxPost.Outline.OUTER, "outline_square": true}))
	check_eq(_count(square_res), 9, "方角外描边：3×3")
	var wide := _run(buf, _settings({"outline": FxPost.Outline.OUTER, "outline_width": 2}))
	check_eq(_count(wide), 13, "两圈圆角描边：菱形 13 个像素")
	return true


func test_outline_inner_keeps_size() -> bool:
	var buf := FxBuffer.new(9, 9)
	for y in range(2, 7):
		for x in range(2, 7):
			buf.plot(x, y, 1.0, 1.0)
	var res := _run(buf, _settings({"outline": FxPost.Outline.INNER, "outline_rgb": Color(1, 0, 0)}))
	check_eq(_count(res), 25, "内描边不改变像素总数")
	# 打包格式 r | g<<8 | b<<16 | a<<24：纯红的低 24 位是 0x0000ff
	check_eq(_at(res, 9, 2, 4) & 0xffffff, 0x0000ff, "边缘像素变成描边色（红）")
	check_eq(_at(res, 9, 4, 4) & 0xffffff, 0xffffff, "中心像素保持亮色")
	return true


func test_cleanup_removes_orphans_and_small_clusters() -> bool:
	var buf := FxBuffer.new(12, 12)
	buf.plot(1, 1, 1.0, 1.0)
	buf.plot(5, 5, 1.0, 1.0)
	buf.plot(6, 5, 1.0, 1.0)
	for x in range(8, 12):
		buf.plot(x, 9, 1.0, 1.0)
	var res := _run(buf, _settings({"cleanup": true}))
	check_eq(_at(res, 12, 1, 1), 0, "孤立像素被去掉")
	check(_at(res, 12, 5, 5) != 0, "两个相连的像素保留")
	check_eq(_count(res), 6, "只去掉孤立像素")
	var res2 := _run(buf, _settings({"cleanup": true, "min_cluster": 3}))
	check_eq(_count(res2), 4, "小于 3 像素的碎块也去掉")
	return true


func test_dither_dissolve_keeps_half() -> bool:
	var buf := FxBuffer.new(8, 8)
	for y in 8:
		for x in 8:
			buf.plot(x, y, 1.0, 1.0)
	var res := _run(buf, _settings(), 0.5)
	check_eq(_count(res), 32, "可见度 0.5 的抖动溶解保留一半像素")
	var res_fade := _run(buf, _settings({"dissolve": FxPost.Dissolve.FADE, "alpha_levels": 2}), 0.5)
	check_eq(_count(res_fade), 64, "淡出模式全部保留")
	var a := (_at(res_fade, 8, 3, 3) >> 24) & 0xff
	check_eq(a, 128, "淡出模式按层级量化透明度（2 级 → 50%）")
	return true


func test_flip_and_pack() -> bool:
	var buf := FxBuffer.new(8, 8)
	buf.plot(1, 2, 1.0, 1.0)
	var res := _run(buf, _settings({"flip_h": true}))
	check(_at(res, 8, 6, 2) != 0, "水平翻转后像素在 (6, 2)")
	check_eq(_at(res, 8, 1, 2), 0, "原位置变空")
	var img := Image.create_from_data(8, 8, false, Image.FORMAT_RGBA8, (res["pixels"] as PackedInt32Array).to_byte_array())
	check_eq(img.get_pixel(6, 2), Color(1, 1, 1, 1), "打包后颜色正确（白色、不透明）")
	check_eq(res["bbox"], Rect2i(6, 2, 1, 1), "包围盒")
	check(not res["edge"], "未贴边")
	return true


func test_glow_adds_soft_pixels() -> bool:
	var buf := FxBuffer.new(16, 16)
	buf.disc(8.0, 8.0, 3.0, 1.0, 1.0, 1.0)
	var res := _run(buf, _settings({"soft": 1.0}))
	var soft_px := 0
	for c in res["pixels"] as PackedInt32Array:
		var a := (c >> 24) & 0xff
		if a > 0 and a < 255:
			soft_px += 1
	check(soft_px > 8, "柔光在外圈产生半透明像素（%d 个）" % soft_px)
	return true


func test_palette_import_and_custom() -> bool:
	var hex := FxPalette.parse_hex("ff0000\n00ff00\r\n#0000ff\n\nzzzzzz\nff0000\nFF112233")
	check_eq(hex.size(), 4, "Lospec .hex：4 个有效且不重复的颜色")
	check_eq(hex[0], Color("ff0000"), "第一个颜色")
	check_eq(hex[3], Color("112233"), "8 位十六进制取后 6 位")
	var gpl := FxPalette.parse_gpl("GIMP Palette\nName: test\nColumns: 4\n# 注释\n255   0   0\tRed\n  0 255   0 Green\n0 0 255\n")
	check_eq(gpl.size(), 3, "GIMP .gpl：3 个颜色")
	check_eq(gpl[1], Color8(0, 255, 0), "第二个颜色是绿色")
	var img := Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(0, 0, Color.RED)
	img.set_pixel(1, 0, Color.RED)
	img.set_pixel(2, 0, Color.WHITE)
	img.set_pixel(3, 1, Color.BLUE)
	check_eq(FxPalette.from_image(img).size(), 3, "调色板图片：3 种不透明颜色")
	var path := OUTPUT_DIR + "palette_test.hex"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("000000\n808080\nffffff\n")
	f.close()
	check_eq(FxPalette.load_file(ProjectSettings.globalize_path(path)).size(), 3, "按扩展名读取 .hex 文件")
	var many := PackedColorArray()
	for i in 10:
		many.append(Color(1.0 - i * 0.1, 0.5, 0.2))
	var ramp := FxPalette.pick_ramp(many, 4)
	check_eq(ramp.size(), 4, "从 10 色里挑 4 个")
	check(FxPalette.luminance(ramp[0]) < FxPalette.luminance(ramp[3]), "挑出的色阶从暗到亮")
	# 自定义色板直接参与渲染
	var p: Resource = Builtin.find("hit_basic").clone()
	var custom := PackedColorArray([Color("102030"), Color("406080"), Color("80c0ff")])
	p.globals["palette_main"] = custom
	p.globals["palette_accent"] = custom
	p.globals["outline"] = "none"
	var imgs := FxRenderer.render_images(p, {"frames": PackedInt32Array([1])})
	var bad := 0
	var used := 0
	var frame: Image = imgs[0]
	for y in frame.get_height():
		for x in frame.get_width():
			var c := frame.get_pixel(x, y)
			if c.a < 1.0:
				continue
			used += 1
			var ok := false
			for k in custom:
				if c.is_equal_approx(k):
					ok = true
			if not ok:
				bad += 1
	check(used > 0 and bad == 0, "自定义色板：画面只用色板里的颜色（%d 个像素里 %d 个不在色板中）" % [used, bad])
	return true
