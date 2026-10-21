extends "res://tests/test_base.gd"
## GIF 编码器测试：用测试里自带的解码器做「编码 → 解码」往返比对（颜色、透明、帧时长、循环、LZW 码表写满重置）；
## 打击停顿的帧时长换算；导出用的 GIF 输入（一次性特效末尾的空白停顿）。

const FxGif := preload("res://addons/fx_forge/export/fx_gif.gd")
const FxExport := preload("res://addons/fx_forge/export/fx_export.gd")
const FxJob := preload("res://addons/fx_forge/core/fx_job.gd")
const Builtin := preload("res://addons/fx_forge/presets/builtin_presets.gd")


## 把 RGBA 颜色列表（-1 = 透明）变成 RGBA8 字节
func _frame(pixels: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	for c in pixels:
		if c < 0:
			out.append_array(PackedByteArray([0, 0, 0, 0]))
		else:
			out.append_array(PackedByteArray([(c >> 16) & 0xff, (c >> 8) & 0xff, c & 0xff, 255]))
	return out


func test_roundtrip_exact() -> bool:
	var w := 20
	var h := 12
	var cols := [0xff0000, 0x00ff00, 0x0000ff, 0xffffff, 0x123456]
	var frames: Array = []
	var sources: Array = []
	for f in 3:
		var px := PackedInt32Array()
		for y in h:
			for x in w:
				px.append(-1 if (x + y + f) % 4 == 0 else cols[(x * 3 + y + f) % cols.size()])
		sources.append(px)
		frames.append(_frame(px))
	var bytes := FxGif.encode(frames, w, h, PackedInt32Array([5, 7, 10]))
	var d := _decode(bytes)
	check_eq(d.get("error", ""), "", "解码没有出错")
	check_eq(d["w"], w, "宽度")
	check_eq(d["h"], h, "高度")
	check_eq(d["loop"], 0, "无限循环")
	check_eq((d["frames"] as Array).size(), 3, "帧数")
	var bad := 0
	for f in 3:
		var fr: Dictionary = d["frames"][f]
		check_eq(fr["delay"], [5, 7, 10][f], "第 %d 帧停留时间" % f)
		var src: PackedInt32Array = sources[f]
		var idx: PackedByteArray = fr["indices"]
		for i in w * h:
			var k := idx[i]
			var got := -1 if k == fr["transparent"] else (d["palette"] as PackedInt32Array)[k]
			if got != src[i]:
				bad += 1
	check_eq(bad, 0, "每个像素的颜色和透明都和原图一致")
	return true


func test_many_colors_and_table_reset() -> bool:
	# 200×200、几百种颜色的噪声图：LZW 码表会写满并发清除码重来；颜色超过 255 种时就近映射
	var w := 200
	var h := 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var px := PackedInt32Array()
	for i in w * h:
		px.append(rng.randi_range(0, 599) * 0x010203 & 0xffffff)
	var bytes := FxGif.encode([_frame(px)], w, h, PackedInt32Array([4]), Color.BLACK)
	var d := _decode(bytes)
	check_eq(d.get("error", ""), "", "解码没有出错")
	var fr: Dictionary = d["frames"][0]
	check_eq((fr["indices"] as PackedByteArray).size(), w * h, "像素数完整")
	check_eq(fr["transparent"], -1, "有底色时没有透明色")
	var pal: PackedInt32Array = d["palette"]
	check_eq(pal.size(), 256, "色板 256 色")
	# 只用 50 种颜色的大图：必须逐像素无损
	var px2 := PackedInt32Array()
	for i in w * h:
		px2.append((rng.randi_range(0, 49) * 0x050301) & 0xffffff)
	var d2 := _decode(FxGif.encode([_frame(px2)], w, h, PackedInt32Array([4]), Color.BLACK))
	var idx: PackedByteArray = (d2["frames"][0] as Dictionary)["indices"]
	var pal2: PackedInt32Array = d2["palette"]
	var bad := 0
	for i in w * h:
		if pal2[idx[i]] != px2[i]:
			bad += 1
	check_eq(bad, 0, "50 色大图逐像素无损（码表多次写满重置）")
	return true


func test_semi_transparent_dither() -> bool:
	# 半透明像素按 4×4 点阵显示一部分
	var w := 8
	var h := 8
	var data := PackedByteArray()
	for i in w * h:
		data.append_array(PackedByteArray([200, 100, 50, 128]))
	var d := _decode(FxGif.encode([data], w, h, PackedInt32Array([10])))
	var fr: Dictionary = d["frames"][0]
	var shown := 0
	for k in (fr["indices"] as PackedByteArray):
		if k != fr["transparent"]:
			shown += 1
	check(shown > 20 and shown < 44, "50%% 透明的像素大约一半显示（%d/64）" % shown)
	return true


func test_delays_and_durations() -> bool:
	var dl := FxGif.delays_for(15, 15.0)
	var sum := 0
	for v in dl:
		sum += v
	check_eq(sum, 100, "15 帧 15 帧/秒合计正好 1 秒（累计取整）")
	var mults := FxJob.durations_for(10, 3, 4.0)
	check_eq(mults[2], 4.0, "第 3 帧停 4 倍")
	check_eq(mults[0], 1.0, "其他帧 1 倍")
	check_eq(FxJob.durations_for(5, 9, 3.0), PackedFloat32Array([1, 1, 1, 1, 1]), "停顿帧超出帧数时不停顿")
	var held := FxGif.delays_for(4, 10.0, PackedFloat32Array([1, 3, 1, 1]))
	check_eq(held, PackedInt32Array([10, 30, 10, 10]), "GIF 停留时间跟着停顿倍数")
	return true


func test_gif_input_and_hold_export() -> bool:
	var p: Resource = Builtin.find("hit_basic").clone()
	p.globals["hold_frame"] = 2
	p.globals["hold_mult"] = 3.0
	var s := FxExport.normalize_settings({"gif": true, "gif_scale": 2}, p)
	var rendered := FxExport.render_animations(p, s)
	var sheet := FxExport.build_sheet(rendered, s)
	var gi := FxExport.gif_input(rendered, sheet, s)
	var n: int = rendered["anims"][0]["frames"].size()
	check_eq((gi["frames"] as Array).size(), n + 1, "一次性特效的 GIF 末尾多一帧空白停顿")
	check_eq(gi["w"], int(rendered["canvas"].x) * 2, "GIF 按自己的倍数放大")
	var delays: PackedInt32Array = gi["delays"]
	check(delays[1] > delays[0] * 2, "停顿帧在 GIF 里停得更久（%s）" % delays)
	var json: Dictionary = JSON.parse_string(FxExport.build_json(sheet, rendered, s, "x.png"))
	var frames: Array = json["frames"]
	check(int(frames[1]["duration"]) > int(frames[0]["duration"]) * 2, "JSON 里停顿帧的时长更长")
	var sf := FxExport.build_sprite_frames(ImageTexture.create_from_image(sheet["image"]), sheet, rendered)
	check_near(sf.get_frame_duration(&"default", 1), 3.0, 0.001, "SpriteFrames 里停顿帧的时长倍数")
	check_near(sf.get_frame_duration(&"default", 0), 1.0, 0.001, "其他帧时长 1")
	var loop_p: Resource = Builtin.find("campfire")
	var ls := FxExport.normalize_settings({"gif": true}, loop_p)
	var lr := FxExport.render_animations(loop_p, ls)
	var lgi := FxExport.gif_input(lr, FxExport.build_sheet(lr, ls), ls)
	check_eq((lgi["frames"] as Array).size(), int(loop_p.globals["frames"]), "循环特效不加空白帧")
	var bytes := FxGif.encode(gi["frames"], gi["w"], gi["h"], gi["delays"], gi["background"], gi["scale"])
	check_eq(_decode(bytes).get("error", ""), "", "导出的 GIF 能解码")
	return true


## ---------------------------------------------------------------- 测试用的最小 GIF 解码器
## 返回 {w, h, palette: PackedInt32Array, loop, frames: [{indices, delay, transparent}], error}
func _decode(b: PackedByteArray) -> Dictionary:
	var out := {"w": 0, "h": 0, "palette": PackedInt32Array(), "loop": -1, "frames": [], "error": ""}
	if b.size() < 13 or b.slice(0, 6).get_string_from_ascii() != "GIF89a":
		out["error"] = "文件头不对"
		return out
	out["w"] = b[6] | (b[7] << 8)
	out["h"] = b[8] | (b[9] << 8)
	var packed := b[10]
	var p := 13
	if packed & 0x80:
		var size := 2 << (packed & 7)
		var pal := PackedInt32Array()
		for k in size:
			pal.append((b[p] << 16) | (b[p + 1] << 8) | b[p + 2])
			p += 3
		out["palette"] = pal
	var delay := 0
	var transparent := -1
	while p < b.size():
		var tag := b[p]
		if tag == 0x21:
			var label := b[p + 1]
			p += 2
			if label == 0xf9:
				var gp := b[p + 1]
				delay = b[p + 2] | (b[p + 3] << 8)
				transparent = b[p + 4] if gp & 1 else -1
				p += 6
			else:
				var app := ""
				if label == 0xff:
					app = b.slice(p + 1, p + 12).get_string_from_ascii()
					p += 1 + b[p]
				while b[p] != 0:
					if app == "NETSCAPE2.0" and b[p] == 3 and b[p + 1] == 1:
						out["loop"] = b[p + 2] | (b[p + 3] << 8)
					p += 1 + b[p]
				p += 1
		elif tag == 0x2c:
			var fw := b[p + 5] | (b[p + 6] << 8)
			var fh := b[p + 7] | (b[p + 8] << 8)
			p += 10
			var min_size := b[p]
			p += 1
			var data := PackedByteArray()
			while b[p] != 0:
				data.append_array(b.slice(p + 1, p + 1 + b[p]))
				p += 1 + b[p]
			p += 1
			var idx := _lzw_decode(data, min_size)
			if idx.size() != fw * fh:
				out["error"] = "像素数不对（%d / %d）" % [idx.size(), fw * fh]
			(out["frames"] as Array).append({"indices": idx, "delay": delay, "transparent": transparent})
		elif tag == 0x3b:
			break
		else:
			out["error"] = "未知数据块 %d" % tag
			break
	return out


func _lzw_decode(data: PackedByteArray, min_size: int) -> PackedByteArray:
	var clear := 1 << min_size
	var eoi := clear + 1
	var table: Array = []
	for i in clear:
		table.append(PackedByteArray([i]))
	table.append(PackedByteArray())
	table.append(PackedByteArray())
	var size := min_size + 1
	var out := PackedByteArray()
	var prev := -1
	var bit := 0
	var total := data.size() * 8
	while bit + size <= total:
		var code := 0
		for k in size:
			if data[(bit + k) >> 3] & (1 << ((bit + k) & 7)):
				code |= 1 << k
		bit += size
		if code == clear:
			table.resize(clear + 2)
			size = min_size + 1
			prev = -1
			continue
		if code == eoi:
			break
		var entry: PackedByteArray
		if code < table.size():
			entry = table[code]
		elif code == table.size() and prev >= 0:
			entry = (table[prev] as PackedByteArray).duplicate()
			entry.append((table[prev] as PackedByteArray)[0])
		else:
			break
		out.append_array(entry)
		if prev >= 0 and table.size() < 4096:
			var ne := (table[prev] as PackedByteArray).duplicate()
			ne.append(entry[0])
			table.append(ne)
			if table.size() == (1 << size) and size < 12:
				size += 1
		prev = code
	return out
