@tool
extends RefCounted
## 可四方平铺的值噪声表（SIZE × SIZE，取值 0~1），供模块逐像素查表：
##   table[((y & MASK) << SHIFT) | (x & MASK)]
## 采样位置绕圆周走一圈（或按整数圈滚动）就能做出首尾无缝的循环动画。
## 按「种子 + 参数」缓存；只在主线程（模块的 prepare）里调用。

const SIZE := 128
const MASK := 127
const SHIFT := 7
const _CACHE_LIMIT := 32

static var _cache := {}


## cell：最粗一层的格子大小（像素，需能整除 SIZE）；octaves：叠加几层（每层格子减半、强度减半）
static func table(seed: int, cell: int = 16, octaves: int = 3) -> PackedFloat32Array:
	var key := "%d_%d_%d" % [seed, cell, octaves]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var out := PackedFloat32Array()
	out.resize(SIZE * SIZE)
	out.fill(0.0)
	var amp := 1.0
	var c := clampi(cell, 2, SIZE)
	for o in octaves:
		@warning_ignore("integer_division")
		var n := maxi(SIZE / c, 1)
		var lat := PackedFloat32Array()
		lat.resize(n * n)
		for i in n * n:
			lat[i] = rng.randf()
		var inv_c := 1.0 / float(c)
		for y in SIZE:
			var gy := float(y) * inv_c
			var y0 := int(gy) % n
			var y1 := (y0 + 1) % n
			var fy := gy - floorf(gy)
			fy = fy * fy * (3.0 - 2.0 * fy)
			var row := y * SIZE
			for x in SIZE:
				var gx := float(x) * inv_c
				var x0 := int(gx) % n
				var x1 := (x0 + 1) % n
				var fx := gx - floorf(gx)
				fx = fx * fx * (3.0 - 2.0 * fx)
				var top := lat[y0 * n + x0] + (lat[y0 * n + x1] - lat[y0 * n + x0]) * fx
				var bottom := lat[y1 * n + x0] + (lat[y1 * n + x1] - lat[y1 * n + x0]) * fx
				out[row + x] += (top + (bottom - top) * fy) * amp
		amp *= 0.5
		@warning_ignore("integer_division")
		c = maxi(c / 2, 2)
	var lo := INF
	var hi := -INF
	for v in out:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 0.0001)
	for i in out.size():
		out[i] = (out[i] - lo) / span
	if _cache.size() >= _CACHE_LIMIT:
		_cache.clear()
	_cache[key] = out
	return out
