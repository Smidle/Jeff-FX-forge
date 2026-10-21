@tool
extends RefCounted
## 一个图层一帧的强度画布。
##   v：亮度 0~1（决定用色板里哪一阶颜色）
##   a：可见度 0~1（0 = 空；小于 1 时按「消散方式」处理）
## 写像素一律取较大值（max 混合）。
##
## 性能约定：模块自己写大循环时
##   var bv := buf.v
##   var ba := buf.a
##   buf.release()          # 让数组只剩一个引用，写入时不会整块复制
##   ……写 bv[i] / ba[i] ……
##   buf.restore(bv, ba)
##   buf.touch(...)         # 更新包围盒
## 下面的绘制原语直接写自己的成员，可以放心调用（每个原语一次调用，内层循环已内联）。

var w: int
var h: int
var v: PackedFloat32Array
var a: PackedFloat32Array
## 写入过的包围盒（含边界）；x1 < x0 表示还是空的
var x0: int
var y0: int
var x1: int
var y1: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	v.resize(w * h)
	v.fill(0.0)
	a.resize(w * h)
	a.fill(0.0)
	x0 = w
	y0 = h
	x1 = -1
	y1 = -1


func is_empty() -> bool:
	return x1 < x0


func release() -> void:
	v = PackedFloat32Array()
	a = PackedFloat32Array()


func restore(nv: PackedFloat32Array, na: PackedFloat32Array) -> void:
	v = nv
	a = na


func touch(xa: int, ya: int, xb: int, yb: int) -> void:
	x0 = mini(x0, maxi(xa, 0))
	y0 = mini(y0, maxi(ya, 0))
	x1 = maxi(x1, mini(xb, w - 1))
	y1 = maxi(y1, mini(yb, h - 1))


## 单个像素
func plot(x: int, y: int, val: float, alpha: float) -> void:
	if x < 0 or y < 0 or x >= w or y >= h:
		return
	var i := y * w + x
	if val > v[i]:
		v[i] = val
	if alpha > a[i]:
		a[i] = alpha
	touch(x, y, x, y)


## 实心圆（亮度从中心 v_center 线性过渡到边缘 v_edge）
func disc(cx: float, cy: float, r: float, v_center: float, v_edge: float, alpha: float) -> void:
	if r <= 0.0:
		return
	var xa := maxi(floori(cx - r), 0)
	var xb := mini(ceili(cx + r), w - 1)
	var ya := maxi(floori(cy - r), 0)
	var yb := mini(ceili(cy + r), h - 1)
	if xa > xb or ya > yb:
		return
	var r2 := r * r
	var inv_r := 1.0 / r
	var dv := v_edge - v_center
	var drew := false
	for y in range(ya, yb + 1):
		var dy := float(y) + 0.5 - cy
		var dy2 := dy * dy
		var row := y * w
		for x in range(xa, xb + 1):
			var dx := float(x) + 0.5 - cx
			var d2 := dx * dx + dy2
			if d2 > r2:
				continue
			var val := v_center + dv * sqrt(d2) * inv_r
			var i := row + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
			drew = true
	if drew:
		touch(xa, ya, xb, yb)


## 粗细、亮度都可渐变的线段（胶囊）
func capsule(ax: float, ay: float, bx: float, by: float, r0: float, r1: float, v0: float, v1: float, alpha: float) -> void:
	var rm := maxf(r0, r1)
	if rm <= 0.0:
		return
	var xa := maxi(floori(minf(ax, bx) - rm), 0)
	var xb := mini(ceili(maxf(ax, bx) + rm), w - 1)
	var ya := maxi(floori(minf(ay, by) - rm), 0)
	var yb := mini(ceili(maxf(ay, by) + rm), h - 1)
	if xa > xb or ya > yb:
		return
	var dx := bx - ax
	var dy := by - ay
	var len2 := dx * dx + dy * dy
	var inv_len2 := 0.0 if len2 < 0.000001 else 1.0 / len2
	var dr := r1 - r0
	var dvv := v1 - v0
	var drew := false
	for y in range(ya, yb + 1):
		var py := float(y) + 0.5 - ay
		var row := y * w
		for x in range(xa, xb + 1):
			var px := float(x) + 0.5 - ax
			var t := (px * dx + py * dy) * inv_len2
			if t < 0.0:
				t = 0.0
			elif t > 1.0:
				t = 1.0
			var qx := px - dx * t
			var qy := py - dy * t
			var rr := r0 + dr * t
			if qx * qx + qy * qy > rr * rr:
				continue
			var val := v0 + dvv * t
			var i := row + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
			drew = true
	if drew:
		touch(xa, ya, xb, yb)


## 1 像素宽直线（Bresenham）
func line_px(xa: int, ya: int, xb: int, yb: int, val: float, alpha: float) -> void:
	var dx := absi(xb - xa)
	var dy := -absi(yb - ya)
	var sx := 1 if xa < xb else -1
	var sy := 1 if ya < yb else -1
	var err := dx + dy
	var x := xa
	var y := ya
	while true:
		if x >= 0 and y >= 0 and x < w and y < h:
			var i := y * w + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
		if x == xb and y == yb:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	touch(mini(xa, xb), mini(ya, yb), maxi(xa, xb), maxi(ya, yb))


## 实心矩形（整数像素坐标）
func rect(rx: int, ry: int, rw: int, rh: int, val: float, alpha: float) -> void:
	var xa := maxi(rx, 0)
	var ya := maxi(ry, 0)
	var xb := mini(rx + rw - 1, w - 1)
	var yb := mini(ry + rh - 1, h - 1)
	if xa > xb or ya > yb:
		return
	for y in range(ya, yb + 1):
		var row := y * w
		for x in range(xa, xb + 1):
			var i := row + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
	touch(xa, ya, xb, yb)


## 菱形（|dx| + |dy| ≤ r），亮度从中心过渡到边缘
func diamond(cx: float, cy: float, r: float, v_center: float, v_edge: float, alpha: float) -> void:
	if r <= 0.0:
		return
	var xa := maxi(floori(cx - r), 0)
	var xb := mini(ceili(cx + r), w - 1)
	var ya := maxi(floori(cy - r), 0)
	var yb := mini(ceili(cy + r), h - 1)
	if xa > xb or ya > yb:
		return
	var inv_r := 1.0 / r
	var dv := v_edge - v_center
	var drew := false
	for y in range(ya, yb + 1):
		var dy := absf(float(y) + 0.5 - cy)
		var row := y * w
		for x in range(xa, xb + 1):
			var d := absf(float(x) + 0.5 - cx) + dy
			if d > r:
				continue
			var val := v_center + dv * d * inv_r
			var i := row + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
			drew = true
	if drew:
		touch(xa, ya, xb, yb)


## 折线（每段一根等粗的胶囊线）；closed = true 时首尾相连
func polyline(points: PackedVector2Array, radius: float, val: float, alpha: float, closed: bool = false) -> void:
	var n := points.size()
	if n < 2:
		if n == 1:
			disc(points[0].x, points[0].y, maxf(radius, 0.5), val, val, alpha)
		return
	var last := n if closed else n - 1
	for i in last:
		var p0 := points[i]
		var p1 := points[(i + 1) % n]
		capsule(p0.x, p0.y, p1.x, p1.y, radius, radius, val, val, alpha)


## 实心椭圆（亮度从中心过渡到边缘）
func ellipse(cx: float, cy: float, rx: float, ry: float, v_center: float, v_edge: float, alpha: float) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var xa := maxi(floori(cx - rx), 0)
	var xb := mini(ceili(cx + rx), w - 1)
	var ya := maxi(floori(cy - ry), 0)
	var yb := mini(ceili(cy + ry), h - 1)
	if xa > xb or ya > yb:
		return
	var irx := 1.0 / rx
	var iry := 1.0 / ry
	var dv := v_edge - v_center
	var drew := false
	for y in range(ya, yb + 1):
		var dy := (float(y) + 0.5 - cy) * iry
		var dy2 := dy * dy
		var row := y * w
		for x in range(xa, xb + 1):
			var dx := (float(x) + 0.5 - cx) * irx
			var d2 := dx * dx + dy2
			if d2 > 1.0:
				continue
			var val := v_center + dv * sqrt(d2)
			var i := row + x
			if val > v[i]:
				v[i] = val
			if alpha > a[i]:
				a[i] = alpha
			drew = true
	if drew:
		touch(xa, ya, xb, yb)


## 多边形填充（扫描线，奇偶规则），在像素中心采样
func polygon(points: PackedVector2Array, val: float, alpha: float) -> void:
	var n := points.size()
	if n < 3:
		return
	var min_y := INF
	var max_y := -INF
	var min_x := INF
	var max_x := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
	var ya := maxi(floori(min_y), 0)
	var yb := mini(ceili(max_y), h - 1)
	var drew := false
	var xs := PackedFloat32Array()
	for y in range(ya, yb + 1):
		var sy := float(y) + 0.5
		xs.clear()
		for k in n:
			var p0 := points[k]
			var p1 := points[(k + 1) % n]
			if (p0.y <= sy and p1.y > sy) or (p1.y <= sy and p0.y > sy):
				xs.append(p0.x + (sy - p0.y) / (p1.y - p0.y) * (p1.x - p0.x))
		if xs.size() < 2:
			continue
		xs.sort()
		var row := y * w
		var k2 := 0
		while k2 + 1 < xs.size():
			var xa := maxi(ceili(xs[k2] - 0.5), 0)
			var xb := mini(floori(xs[k2 + 1] - 0.5), w - 1)
			for x in range(xa, xb + 1):
				var i := row + x
				if val > v[i]:
					v[i] = val
				if alpha > a[i]:
					a[i] = alpha
				drew = true
			k2 += 2
	if drew:
		touch(maxi(floori(min_x), 0), ya, mini(ceili(max_x), w - 1), yb)
