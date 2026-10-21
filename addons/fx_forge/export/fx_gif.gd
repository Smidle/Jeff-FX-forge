@tool
extends RefCounted
## GIF 动图编码器（GIF89a，纯计算，可以放在工作线程里跑）：全局色板（最多 255 色 + 1 个透明色）、LZW 压缩、无限循环。
## 输入是 RGBA8 原始字节（Image.get_data()），不直接碰 Image——工作线程不碰 Resource。
## 像素画颜色少，通常能无损保存；颜色超过 255 种（柔光的半透明过渡）时保留最常用的 255 种，其余就近映射。
## GIF 只有「全透明 / 不透明」两种像素：透明背景时，半透明像素按 4×4 点阵决定显示还是透明（和插件的抖动溶解一致）。

const BAYER4 := [
	0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0,
]
const _MAX_CODE := 4096


## frames：每帧的 RGBA8 字节（PackedByteArray，w × h × 4）；delays：每帧停留时间（单位 1/100 秒）。
## background：null = 透明背景；Color = 把半透明像素合成到这个底色上（没有透明）。
## pixel_scale：帧已经放大的倍数，点阵按原始像素对齐（放大后点阵不会变得更细碎）。
static func encode(frames: Array, w: int, h: int, delays: PackedInt32Array, background: Variant = null, pixel_scale: int = 1) -> PackedByteArray:
	var n := w * h
	var transparent := background == null
	var bg := Color.BLACK if transparent else (background as Color)
	var bgr := bg.r8
	var bgg := bg.g8
	var bgb := bg.b8
	var sc := maxi(pixel_scale, 1)
	var bayer := PackedFloat32Array(BAYER4)
	# 1. 每帧换成 24 位颜色（-1 = 透明），顺便统计每种颜色出现的次数
	var rgb_frames: Array = []
	var counts := {}
	for data: PackedByteArray in frames:
		var rgb := PackedInt32Array()
		rgb.resize(n)
		for y in h:
			var row := y * w
			@warning_ignore("integer_division")
			var by := ((y / sc) & 3) << 2
			for x in w:
				var j := (row + x) * 4
				var a := data[j + 3]
				var c := -1
				if transparent:
					@warning_ignore("integer_division")
					if a >= 255 or (a > 0 and float(a) / 255.0 > bayer[by | ((x / sc) & 3)]):
						c = (data[j] << 16) | (data[j + 1] << 8) | data[j + 2]
				else:
					var fa := float(a) / 255.0
					var r := roundi(data[j] * fa + bgr * (1.0 - fa))
					var g := roundi(data[j + 1] * fa + bgg * (1.0 - fa))
					var b := roundi(data[j + 2] * fa + bgb * (1.0 - fa))
					c = (r << 16) | (g << 8) | b
				rgb[row + x] = c
				if c >= 0:
					counts[c] = counts.get(c, 0) + 1
		rgb_frames.append(rgb)

	# 2. 色板：透明时 0 号是透明色
	var first := 1 if transparent else 0
	var colors: Array = counts.keys()
	if colors.size() > 256 - first:
		colors.sort_custom(func(p: int, q: int) -> bool: return counts[p] > counts[q])
		colors.resize(256 - first)
	if colors.is_empty():
		colors.append(bg.to_rgba32() >> 8)
	var index := {}
	for k in colors.size():
		index[colors[k]] = k + first
	var total := colors.size() + first
	var bits := 1
	while (1 << bits) < total:
		bits += 1
	var table_size := 1 << bits

	# 3. 文件头 + 逻辑屏幕 + 全局色板 + 循环扩展
	var out := PackedByteArray()
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0x80 | 0x70 | (bits - 1))
	out.append(0)
	out.append(0)
	for k in table_size:
		var c := 0
		if k >= first and k - first < colors.size():
			c = colors[k - first]
		out.append((c >> 16) & 0xff)
		out.append((c >> 8) & 0xff)
		out.append(c & 0xff)
	out.append_array(PackedByteArray([0x21, 0xff, 0x0b]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))

	# 4. 每一帧：图形控制扩展（停留时间、恢复背景、透明色）+ 图像描述 + LZW 数据
	var min_size := maxi(bits, 2)
	var nearest := {}
	for f in rgb_frames.size():
		var rgb: PackedInt32Array = rgb_frames[f]
		var idx := PackedByteArray()
		idx.resize(n)
		for i in n:
			var c := rgb[i]
			if c < 0:
				idx[i] = 0
				continue
			var k: int = index.get(c, -1)
			if k < 0:
				k = nearest.get(c, -1)
				if k < 0:
					k = _closest(c, colors) + first
					nearest[c] = k
			idx[i] = k
		var delay: int = delays[f] if f < delays.size() else 10
		out.append_array(PackedByteArray([0x21, 0xf9, 0x04, (2 << 2) | (1 if transparent else 0)]))
		_u16(out, clampi(delay, 1, 65535))
		out.append(0)
		out.append(0)
		out.append(0x2c)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, w)
		_u16(out, h)
		out.append(0)
		out.append(min_size)
		var data := lzw(idx, min_size)
		var p := 0
		while p < data.size():
			var chunk := mini(255, data.size() - p)
			out.append(chunk)
			out.append_array(data.slice(p, p + chunk))
			p += chunk
		out.append(0)
	out.append(0x3b)
	return out


## GIF 的 LZW 压缩（变长码 3~12 位，码表满了发清除码重来）。逻辑和经典的 GIFEncoder / LZWEncoder 一致。
static func lzw(idx: PackedByteArray, min_size: int) -> PackedByteArray:
	var st := _BitState.new()
	var clear := 1 << min_size
	st.init_bits = min_size + 1
	st.n_bits = st.init_bits
	st.maxcode = (1 << st.n_bits) - 1
	st.free_ent = clear + 2
	var table := {}
	st.put(clear)
	if idx.is_empty():
		st.put(clear + 1)
		st.flush()
		return st.out
	var ent := int(idx[0])
	for i in range(1, idx.size()):
		var c := int(idx[i])
		var key := (c << 12) | ent
		var found: int = table.get(key, -1)
		if found >= 0:
			ent = found
			continue
		st.put(ent)
		ent = c
		if st.free_ent < _MAX_CODE:
			table[key] = st.free_ent
			st.free_ent += 1
		else:
			table.clear()
			st.free_ent = clear + 2
			st.clear_flg = true
			st.put(clear)
	st.put(ent)
	st.put(clear + 1)
	st.flush()
	return st.out


## 帧率 → 每帧停留时间（1/100 秒）。累计取整，长时间播放不会越来越快或越来越慢；
## multipliers：每帧的时长倍数（打击停顿），不给就都是 1
static func delays_for(frame_count: int, fps: float, multipliers: PackedFloat32Array = PackedFloat32Array()) -> PackedInt32Array:
	var out := PackedInt32Array()
	var t := 0.0
	var prev := 0
	for i in frame_count:
		var m := multipliers[i] if i < multipliers.size() else 1.0
		t += 100.0 * m / maxf(fps, 0.01)
		var now := roundi(t)
		out.append(maxi(now - prev, 1))
		prev = now
	return out


static func _closest(c: int, colors: Array) -> int:
	var r := (c >> 16) & 0xff
	var g := (c >> 8) & 0xff
	var b := c & 0xff
	var best := 0
	var best_d := 1 << 30
	for k in colors.size():
		var o: int = colors[k]
		var dr := ((o >> 16) & 0xff) - r
		var dg := ((o >> 8) & 0xff) - g
		var db := (o & 0xff) - b
		var d := dr * dr * 3 + dg * dg * 4 + db * db * 2
		if d < best_d:
			best_d = d
			best = k
	return best


static func _u16(out: PackedByteArray, v: int) -> void:
	out.append(v & 0xff)
	out.append((v >> 8) & 0xff)


## LZW 输出位流的状态（按码调用，不是按像素调用）
class _BitState:
	extends RefCounted
	const MAX_CODE := 4096
	var out := PackedByteArray()
	var acc := 0
	var acc_bits := 0
	var n_bits := 0
	var init_bits := 0
	var maxcode := 0
	var free_ent := 0
	var clear_flg := false

	func put(code: int) -> void:
		acc |= code << acc_bits
		acc_bits += n_bits
		while acc_bits >= 8:
			out.append(acc & 0xff)
			acc >>= 8
			acc_bits -= 8
		# 下一个码放不下了就加宽一位；刚发过清除码就回到初始宽度
		if free_ent > maxcode or clear_flg:
			if clear_flg:
				n_bits = init_bits
				maxcode = (1 << n_bits) - 1
				clear_flg = false
			else:
				n_bits += 1
				maxcode = MAX_CODE if n_bits == 12 else (1 << n_bits) - 1

	func flush() -> void:
		if acc_bits > 0:
			out.append(acc & 0xff)
		acc = 0
		acc_bits = 0
