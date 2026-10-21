@tool
extends RefCounted
## 数学小工具：缓动曲线、周期噪声表。
## 只在「每帧 / 每图层」级别调用，不要放进逐像素循环（逐像素请查表）。

const EASE_OPTIONS := [
	["linear", "匀速"], ["out_quad", "缓出"], ["out_cubic", "强缓出"], ["out_expo", "爆发"],
	["in_quad", "缓入"], ["in_out", "缓入缓出"], ["out_back", "回弹"],
]

## 噪声用的整数频率（保证严格周期、又不显得规律）
const _NOISE_FREQS := [2, 3, 5, 8, 13, 21]


static func apply_ease(id: String, x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	match id:
		"linear":
			return x
		"out_quad":
			return 1.0 - (1.0 - x) * (1.0 - x)
		"out_cubic":
			var k := 1.0 - x
			return 1.0 - k * k * k
		"out_expo":
			return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)
		"in_quad":
			return x * x
		"in_out":
			return x * x * (3.0 - 2.0 * x)
		"out_back":
			var c1 := 1.70158
			var k2 := x - 1.0
			return 1.0 + (c1 + 1.0) * k2 * k2 * k2 + c1 * k2 * k2
	return x


## 长度为 n 的周期平滑噪声（首尾相接），取值 0~1
static func periodic_noise(n: int, octaves: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	octaves = clampi(octaves, 1, _NOISE_FREQS.size())
	var phases := PackedFloat32Array()
	var amps := PackedFloat32Array()
	for o in octaves:
		phases.append(rng.randf() * TAU)
		amps.append(pow(0.6, o))
	var lo := INF
	var hi := -INF
	for i in n:
		var x := TAU * float(i) / float(n)
		var s := 0.0
		for o in octaves:
			s += amps[o] * sin(float(_NOISE_FREQS[o]) * x + phases[o])
		out[i] = s
		lo = minf(lo, s)
		hi = maxf(hi, s)
	var span := maxf(hi - lo, 0.0001)
	for i in n:
		out[i] = (out[i] - lo) / span
	return out


## 由种子和序号派生新种子（跨平台确定）
static func mix_seed(seed: int, salt: int) -> int:
	return hash(Vector2i(seed, salt))
