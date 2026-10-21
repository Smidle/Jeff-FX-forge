@tool
extends RefCounted
## 后期合成（每帧一个实例，在工作线程里使用）：
##   各图层强度图 → 着色（色板 + 抖动 + 消散）→ 按顺序合成 → 清理孤立像素 → 描边 → 柔光 → 翻转 → 打包 RGBA8
## 合成结果放在成员数组里，各步骤都是成员方法：Packed 数组是值类型，传参后修改只会改到副本。

const FxBuffer := preload("fx_buffer.gd")

enum Dissolve { DITHER, SHRINK, DARKEN, FADE }
enum Outline { NONE, OUTER, INNER, SELECTIVE }

var w: int
var h: int
var cr: PackedFloat32Array
var cg: PackedFloat32Array
var cb: PackedFloat32Array
var ca: PackedFloat32Array
## 1 = 参与描边的不透明像素
var om: PackedByteArray
## 抖动溶解程度（1 = 实心；小于 1 表示这个像素是溶解点阵的一部分：不当作孤立像素清理，描边也按同样密度溶解）
var dl: PackedFloat32Array
var bayer: PackedFloat32Array
## 当前有内容的区域（含边界）；bx1 < bx0 表示空
var bx0: int
var by0: int
var bx1: int
var by1: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	var n := w * h
	cr.resize(n)
	cr.fill(0.0)
	cg.resize(n)
	cg.fill(0.0)
	cb.resize(n)
	cb.fill(0.0)
	ca.resize(n)
	ca.fill(0.0)
	om.resize(n)
	om.fill(0)
	dl.resize(n)
	dl.fill(1.0)
	bx0 = w
	by0 = h
	bx1 = -1
	by1 = -1


## parts：每项 {buf: FxBuffer, fade: float, r/g/b: PackedFloat32Array（色板分量，暗→亮）, outline: bool}
## s：FxRenderer 解析好的后期设置
## 返回 {pixels: PackedInt32Array, opaque: int, edge: bool, bbox: Rect2i}
func run(parts: Array, s: Dictionary) -> Dictionary:
	bayer = s["bayer"]
	for part: Dictionary in parts:
		_shade(part, s)
	if bx1 >= bx0:
		if s["cleanup"]:
			_remove_orphans()
		var min_cluster: int = s["min_cluster"]
		if min_cluster > 1:
			_remove_small_clusters(min_cluster)
		var omode: int = s["outline"]
		var ow: int = s["outline_width"]
		if omode == Outline.INNER:
			_outline_inner(ow, s["outline_square"], s["outline_rgb"])
		elif omode != Outline.NONE:
			_grow(ow)
			_outline_outer(ow, s["outline_square"], s["outline_rgb"], omode == Outline.SELECTIVE)
		var soft: float = s["soft"]
		if soft > 0.0:
			var rad := 1 + roundi(soft * 3.0)
			_grow(rad * 2)
			_glow(rad, soft, s["alpha_levels"], s["glow_rgb"])
	return _pack(s["flip_h"], s["flip_v"])


func _grow(d: int) -> void:
	bx0 = maxi(bx0 - d, 0)
	by0 = maxi(by0 - d, 0)
	bx1 = mini(bx1 + d, w - 1)
	by1 = mini(by1 + d, h - 1)


## 着色并合成一个图层
func _shade(part: Dictionary, s: Dictionary) -> void:
	var buf: FxBuffer = part["buf"]
	var fade: float = part["fade"]
	if buf.is_empty() or fade <= 0.0:
		return
	var lv := buf.v
	var la := buf.a
	var pr: PackedFloat32Array = part["r"]
	var pg: PackedFloat32Array = part["g"]
	var pb: PackedFloat32Array = part["b"]
	var dtab: PackedFloat32Array = s["dither_tab"]
	var dmode: int = s["dissolve"]
	var levels: int = s["alpha_levels"]
	var flevels := float(levels)
	var steps := pr.size()
	var fsteps := float(steps)
	var damt: float = float(s["dither_strength"]) / fsteps
	var oflag: int = 1 if part["outline"] else 0
	bx0 = mini(bx0, buf.x0)
	by0 = mini(by0, buf.y0)
	bx1 = maxi(bx1, buf.x1)
	by1 = maxi(by1, buf.y1)
	for y in range(buf.y0, buf.y1 + 1):
		var row := y * w
		var yb := (y & 3) << 2
		for x in range(buf.x0, buf.x1 + 1):
			var i := row + x
			var av := la[i]
			if av <= 0.0:
				continue
			var ea := av * fade
			var vv := lv[i]
			var alpha := 1.0
			var dith := 1.0
			if ea < 1.0:
				if dmode == Dissolve.DITHER or (dmode == Dissolve.FADE and levels <= 1):
					if ea <= bayer[yb | (x & 3)]:
						continue
					dith = ea
				elif dmode == Dissolve.SHRINK:
					if vv < 1.0 - ea:
						continue
				elif dmode == Dissolve.DARKEN:
					vv -= 1.0 - ea
					if vv < 0.0:
						continue
				else:
					alpha = ceilf(ea * flevels) / flevels
			var ci := int((vv + (dtab[yb | (x & 3)] - 0.5) * damt) * fsteps)
			if ci < 0:
				ci = 0
			elif ci >= steps:
				ci = steps - 1
			if alpha >= 1.0:
				cr[i] = pr[ci]
				cg[i] = pg[ci]
				cb[i] = pb[ci]
				ca[i] = 1.0
				om[i] = oflag
				dl[i] = dith
			else:
				var keep := ca[i] * (1.0 - alpha)
				var na := alpha + keep
				cr[i] = (pr[ci] * alpha + cr[i] * keep) / na
				cg[i] = (pg[ci] * alpha + cg[i] * keep) / na
				cb[i] = (pb[ci] * alpha + cb[i] * keep) / na
				ca[i] = na
				if oflag == 1 and na >= 0.5:
					om[i] = 1


## 去掉周围 8 格都没有邻居的单个像素（斜向相连算邻居：像素画里的斜线是合法的；溶解点阵不清理）
func _remove_orphans() -> void:
	var kill := PackedInt32Array()
	for y in range(by0, by1 + 1):
		var row := y * w
		var up := y > 0
		var down := y < h - 1
		for x in range(bx0, bx1 + 1):
			var i := row + x
			if ca[i] <= 0.0 or dl[i] < 1.0:
				continue
			var left := x > 0
			var right := x < w - 1
			if left and ca[i - 1] > 0.0:
				continue
			if right and ca[i + 1] > 0.0:
				continue
			if up and (ca[i - w] > 0.0 or (left and ca[i - w - 1] > 0.0) or (right and ca[i - w + 1] > 0.0)):
				continue
			if down and (ca[i + w] > 0.0 or (left and ca[i + w - 1] > 0.0) or (right and ca[i + w + 1] > 0.0)):
				continue
			kill.append(i)
	for i in kill:
		ca[i] = 0.0
		om[i] = 0


## 去掉像素数小于 min_size 的连通碎块（八连通；溶解点阵不参与）
@warning_ignore("integer_division")
func _remove_small_clusters(min_size: int) -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var stack := PackedInt32Array()
	var comp := PackedInt32Array()
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			var start := y * w + x
			if seen[start] == 1 or ca[start] <= 0.0 or dl[start] < 1.0:
				continue
			comp.clear()
			stack.clear()
			stack.append(start)
			seen[start] = 1
			while not stack.is_empty():
				var i := stack[stack.size() - 1]
				stack.remove_at(stack.size() - 1)
				comp.append(i)
				var px := i % w
				var py := i / w
				for oy in range(-1, 2):
					var ny := py + oy
					if ny < 0 or ny >= h:
						continue
					for ox in range(-1, 2):
						var nx := px + ox
						if nx < 0 or nx >= w:
							continue
						var j := ny * w + nx
						if seen[j] == 0 and ca[j] > 0.0 and dl[j] >= 1.0:
							seen[j] = 1
							stack.append(j)
			if comp.size() < min_size:
				for i in comp:
					ca[i] = 0.0
					om[i] = 0


## 外描边：从参与描边的不透明像素向外长 width 圈
func _outline_outer(width: int, square: bool, oc: Color, selective: bool) -> void:
	var n := w * h
	var front := PackedByteArray()
	front.resize(n)
	front.fill(0)
	for y in range(by0, by1 + 1):
		var row := y * w
		for x in range(bx0, bx1 + 1):
			var i := row + x
			if om[i] == 1 and ca[i] >= 0.5:
				front[i] = 1
	for ring in width:
		var add := PackedInt32Array()
		var src := PackedInt32Array()
		for y in range(by0, by1 + 1):
			var row := y * w
			for x in range(bx0, bx1 + 1):
				var i := row + x
				if ca[i] >= 0.5:
					continue
				var j := -1
				if x > 0 and front[i - 1] == 1:
					j = i - 1
				elif x < w - 1 and front[i + 1] == 1:
					j = i + 1
				elif y > 0 and front[i - w] == 1:
					j = i - w
				elif y < h - 1 and front[i + w] == 1:
					j = i + w
				elif square:
					if x > 0 and y > 0 and front[i - w - 1] == 1:
						j = i - w - 1
					elif x < w - 1 and y > 0 and front[i - w + 1] == 1:
						j = i - w + 1
					elif x > 0 and y < h - 1 and front[i + w - 1] == 1:
						j = i + w - 1
					elif x < w - 1 and y < h - 1 and front[i + w + 1] == 1:
						j = i + w + 1
				if j < 0:
					continue
				# 旁边的像素正在溶解：描边按同样的密度溶解
				var dj := dl[j]
				if dj < 1.0 and bayer[((y & 3) << 2) | (x & 3)] >= dj:
					continue
				add.append(i)
				src.append(j)
		var next := PackedByteArray()
		next.resize(n)
		next.fill(0)
		for q in add.size():
			var i := add[q]
			var j := src[q]
			if selective:
				cr[i] = cr[j] * 0.42
				cg[i] = cg[j] * 0.40
				cb[i] = cb[j] * 0.50 + 0.02
			else:
				cr[i] = oc.r
				cg[i] = oc.g
				cb[i] = oc.b
			ca[i] = minf(ca[j], 1.0)
			dl[i] = dl[j]
			next[i] = 1
		front = next


## 内描边：把参与描边区域最外 width 圈像素改成描边色
func _outline_inner(width: int, square: bool, oc: Color) -> void:
	var mask := PackedByteArray()
	mask.resize(w * h)
	mask.fill(0)
	for y in range(by0, by1 + 1):
		var row := y * w
		for x in range(bx0, bx1 + 1):
			var i := row + x
			if om[i] == 1 and ca[i] >= 0.5:
				mask[i] = 1
	for ring in width:
		var edge := PackedInt32Array()
		for y in range(by0, by1 + 1):
			var row := y * w
			for x in range(bx0, bx1 + 1):
				var i := row + x
				if mask[i] == 0:
					continue
				var outside := (x > 0 and mask[i - 1] == 0) or (x < w - 1 and mask[i + 1] == 0) \
						or (y > 0 and mask[i - w] == 0) or (y < h - 1 and mask[i + w] == 0)
				if not outside and square:
					outside = (x > 0 and y > 0 and mask[i - w - 1] == 0) or (x < w - 1 and y > 0 and mask[i - w + 1] == 0) \
							or (x > 0 and y < h - 1 and mask[i + w - 1] == 0) or (x < w - 1 and y < h - 1 and mask[i + w + 1] == 0)
				if outside:
					edge.append(i)
		for i in edge:
			cr[i] = oc.r
			cg[i] = oc.g
			cb[i] = oc.b
			mask[i] = 0


## 柔光：把当前不透明度模糊两次，作为分级半透明的外晕垫在下面
func _glow(rad: int, soft: float, levels: int, gc: Color) -> void:
	var src := PackedFloat32Array()
	src.resize(w * h)
	src.fill(0.0)
	for y in range(by0, by1 + 1):
		var row := y * w
		for x in range(bx0, bx1 + 1):
			src[row + x] = ca[row + x]
	var blurred := _box_blur(_box_blur(src, rad), rad)
	var gl := float(maxi(levels, 2))
	var strength := (0.6 + 0.6 * soft) * 1.6
	for y in range(by0, by1 + 1):
		var row := y * w
		for x in range(bx0, bx1 + 1):
			var i := row + x
			var oa := ca[i]
			if oa >= 1.0:
				continue
			var gv := blurred[i] * strength
			if gv > 0.75:
				gv = 0.75
			gv = floorf(gv * gl + 0.5) / gl
			if gv <= 0.0:
				continue
			var keep := gv * (1.0 - oa)
			var na := oa + keep
			cr[i] = (cr[i] * oa + gc.r * keep) / na
			cg[i] = (cg[i] * oa + gc.g * keep) / na
			cb[i] = (cb[i] * oa + gc.b * keep) / na
			ca[i] = na


func _box_blur(src: PackedFloat32Array, rad: int) -> PackedFloat32Array:
	var n := w * h
	var tmp := PackedFloat32Array()
	tmp.resize(n)
	tmp.fill(0.0)
	var out := PackedFloat32Array()
	out.resize(n)
	out.fill(0.0)
	var inv := 1.0 / float(rad * 2 + 1)
	for y in range(by0, by1 + 1):
		var row := y * w
		for x in range(bx0, bx1 + 1):
			var acc := 0.0
			for xx in range(maxi(x - rad, bx0), mini(x + rad, bx1) + 1):
				acc += src[row + xx]
			tmp[row + x] = acc * inv
	for y in range(by0, by1 + 1):
		var row := y * w
		var ya := maxi(y - rad, by0)
		var yb := mini(y + rad, by1)
		for x in range(bx0, bx1 + 1):
			var acc := 0.0
			for yy in range(ya, yb + 1):
				acc += tmp[yy * w + x]
			out[row + x] = acc * inv
	return out


## 翻转并打包成 RGBA8 整数（小端：r | g<<8 | b<<16 | a<<24）
func _pack(flip_h: bool, flip_v: bool) -> Dictionary:
	var px := PackedInt32Array()
	px.resize(w * h)
	px.fill(0)
	var opaque := 0
	var edge := false
	var qx0 := w
	var qy0 := h
	var qx1 := -1
	var qy1 := -1
	for y in range(by0, by1 + 1):
		var row := y * w
		var ty := (h - 1 - y) if flip_v else y
		for x in range(bx0, bx1 + 1):
			var i := row + x
			var a8 := int(ca[i] * 255.0 + 0.5)
			if a8 <= 0:
				continue
			if a8 > 255:
				a8 = 255
			var r8 := clampi(int(cr[i] * 255.0 + 0.5), 0, 255)
			var g8 := clampi(int(cg[i] * 255.0 + 0.5), 0, 255)
			var b8 := clampi(int(cb[i] * 255.0 + 0.5), 0, 255)
			var c := r8 | (g8 << 8) | (b8 << 16) | (a8 << 24)
			if c >= 0x80000000:
				c -= 0x100000000
			var tx := (w - 1 - x) if flip_h else x
			px[ty * w + tx] = c
			if a8 >= 128:
				opaque += 1
			if tx == 0 or ty == 0 or tx == w - 1 or ty == h - 1:
				edge = true
			qx0 = mini(qx0, tx)
			qy0 = mini(qy0, ty)
			qx1 = maxi(qx1, tx)
			qy1 = maxi(qy1, ty)
	var bbox := Rect2i() if qx1 < qx0 else Rect2i(qx0, qy0, qx1 - qx0 + 1, qy1 - qy0 + 1)
	return {"pixels": px, "opaque": opaque, "edge": edge, "bbox": bbox}
