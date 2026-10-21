extends "res://tests/test_base.gd"
## 特效模块测试：每个模块用默认参数都能画出东西、结果确定；粒子 / 射线 / 环 / 冲刺线的关键行为；画布新原语

const FxRegistry := preload("res://addons/fx_forge/core/fx_registry.gd")
const FxBuffer := preload("res://addons/fx_forge/core/fx_buffer.gd")
const FxContext := preload("res://addons/fx_forge/core/fx_context.gd")
const FxPalette := preload("res://addons/fx_forge/core/fx_palette.gd")
const FxParams := preload("res://addons/fx_forge/core/fx_params.gd")
const FxParticles := preload("res://addons/fx_forge/core/fx_particles.gd")
const FxNoise := preload("res://addons/fx_forge/core/fx_noise.gd")
const FxPost := preload("res://addons/fx_forge/core/fx_post.gd")


func _ctx(size: int, angle_deg: float) -> FxContext:
	var c := FxContext.new()
	c.w = size
	c.h = size
	c.ox = size * 0.5
	c.oy = size * 0.5
	c.angle = deg_to_rad(angle_deg)
	c.cos_a = cos(c.angle)
	c.sin_a = sin(c.angle)
	c.frames = 10
	c.bayer = FxPalette.BAYER4
	return c


func _render(id: String, overrides: Dictionary = {}, u: float = 0.3, angle: float = 0.0, size: int = 128, loop: bool = false) -> FxBuffer:
	var m: RefCounted = FxRegistry.get_module(id)
	var p := FxParams.normalize(m.get_param_defs(), overrides)
	var ctx := _ctx(size, angle)
	ctx.loop = loop
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st: Dictionary = m.prepare(p, ctx, rng)
	var buf := FxBuffer.new(size, size)
	m.render(buf, p, st, u, ctx)
	return buf


func _count(buf: FxBuffer) -> int:
	var n := 0
	for v in buf.a:
		if v > 0.0:
			n += 1
	return n


## 有像素的位置的重心（相对画布中心）
func _centroid(buf: FxBuffer) -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for y in buf.h:
		for x in buf.w:
			if buf.a[y * buf.w + x] > 0.0:
				sum += Vector2(x + 0.5, y + 0.5)
				n += 1
	return Vector2.ZERO if n == 0 else sum / n - Vector2(buf.w, buf.h) * 0.5


func _extent(buf: FxBuffer) -> Vector2i:
	return Vector2i(buf.x1 - buf.x0 + 1, buf.y1 - buf.y0 + 1)


func test_every_module_draws_with_defaults() -> bool:
	for id: String in FxRegistry.module_ids():
		# 闪电之类会有熄灭的时刻，所以看几个时刻里至少有一个画出了东西
		var best: FxBuffer = null
		for u: float in [0.1, 0.3, 0.5]:
			var buf := _render(id, {}, u)
			if best == null or _count(buf) > _count(best):
				best = buf
		check(_count(best) > 0, "模块 %s 用默认参数能画出像素" % id)
		check(not best.is_empty(), "模块 %s 记录了包围盒" % id)
		var m: RefCounted = FxRegistry.get_module(id)
		for d: Dictionary in m.get_param_defs():
			check(["shape", "motion", "detail"].has(d["group"]), "%s.%s 的分组合法" % [id, d["id"]])
	return true


func test_modules_are_deterministic() -> bool:
	for id: String in FxRegistry.module_ids():
		var a := _render(id)
		var b := _render(id)
		check(a.v == b.v and a.a == b.a, "模块 %s 同参数同种子结果一致" % id)
	return true


func test_particles_spread_and_gravity() -> bool:
	var cone := _render("particles", {"spread": 40.0, "speed": 120.0, "count": 30}, 0.3)
	check(_centroid(cone).x > 6.0, "扩散角 40° 朝右时粒子在右边（%s）" % _centroid(cone))
	var light := _render("particles", {"spread": 40.0, "speed": 120.0, "count": 30}, 0.5)
	var heavy := _render("particles", {"spread": 40.0, "speed": 120.0, "count": 30, "gravity": 300.0}, 0.5)
	check(_centroid(heavy).y > _centroid(light).y + 2.0, "有重力时粒子往下掉")
	return true


func test_particle_spawn_tables() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var cfg := {"count": 25, "emit_shape": "ring", "emit_radius": 10.0, "angle": 0.0, "spread": 360.0, "speed": 50.0,
		"speed_random": 0.5, "life": 0.5, "life_random": 0.2, "emit_mode": "stream", "emit_time": 1.0, "size": 2.0,
		"size_random": 0.3, "spin": 1.0}
	var t := FxParticles.spawn(cfg, rng)
	for key: String in t:
		check_eq((t[key] as PackedFloat32Array).size(), 25, "粒子表 %s 有 25 项" % key)
	var t0: PackedFloat32Array = t["t0"]
	check(t0[0] < 0.1 and t0[24] > 0.9, "持续发射时出生时间铺满整段")
	var x: PackedFloat32Array = t["x"]
	var y: PackedFloat32Array = t["y"]
	check_near(Vector2(x[5], y[5]).length(), 10.0, 0.01, "圆环发射：出生点在半径 10 的圆上")
	# 循环模式：首尾两帧都有粒子
	var draw_cfg := {"shape": 1, "size_end": 1.0, "gravity": 0.0, "drag": 1.0, "cool": 0.0, "bright": 1.0,
		"flicker": 0.0, "streak_len": 0.4, "loop": true, "ox": 32.0, "oy": 32.0}
	var b0 := FxBuffer.new(64, 64)
	var b1 := FxBuffer.new(64, 64)
	check(FxParticles.draw(b0, t, draw_cfg, 0.02) > 0 and FxParticles.draw(b1, t, draw_cfg, 0.98) > 0, "循环模式首尾帧都有粒子")
	return true


func test_ring_squash_and_segments() -> bool:
	var full := _render("ring", {"radius": 30.0, "start": 1.0})
	var flat := _render("ring", {"radius": 30.0, "start": 1.0, "squash": 0.4})
	var seg := _render("ring", {"radius": 30.0, "start": 1.0, "segments": 8, "gap": 0.5})
	var e := _extent(full)
	check(absi(e.x - e.y) <= 1, "完整的环是圆的（%s）" % e)
	var f := _extent(flat)
	check(f.y < f.x * 0.6, "地面透视把环压扁（%s）" % f)
	check(_count(seg) < _count(full) * 0.7, "分段的环像素更少")
	return true


func test_burst_spread_points_to_direction() -> bool:
	var b := _render("burst", {"spread": 60.0, "flash": "none"}, 0.3, 180.0)
	check(_centroid(b).x < -3.0, "扩散角 60°、方向 180° 时射线在左边（%s）" % _centroid(b))
	return true


func test_streak_moves_forward() -> bool:
	var early := _centroid(_render("streak", {"count": 1}, 0.2, 90.0))
	var late := _centroid(_render("streak", {"count": 1}, 0.6, 90.0))
	check(late.y > early.y + 2.0, "方向 90° 时冲刺线向下冲（%s → %s）" % [early, late])
	return true


func test_noise_table() -> bool:
	var t := FxNoise.table(123, 16, 3)
	check_eq(t.size(), FxNoise.SIZE * FxNoise.SIZE, "噪声表大小")
	var lo := 1.0
	var hi := 0.0
	for v in t:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	check(lo >= 0.0 and hi <= 1.0 and hi - lo > 0.9, "取值铺满 0~1（%.2f~%.2f）" % [lo, hi])
	check(FxNoise.table(123, 16, 3) == t, "同种子取到缓存的同一张表")
	# 可平铺：最右一列和最左一列相邻，差值应该和普通相邻列差不多
	var edge := 0.0
	var inner := 0.0
	for y in FxNoise.SIZE:
		var row := y * FxNoise.SIZE
		edge += absf(t[row + FxNoise.SIZE - 1] - t[row])
		inner += absf(t[row + 64] - t[row + 63])
	check(edge < inner * 2.5 + 1.0, "左右边缘可以无缝拼接（边缘差 %.1f，内部差 %.1f）" % [edge, inner])
	return true


func test_blob_burns_out() -> bool:
	var mid := _count(_render("blob", {"burn": 0.9}, 0.45))
	var late := _count(_render("blob", {"burn": 0.9}, 0.95))
	check(late < mid * 0.6, "能量团后期被烧穿（%d → %d）" % [mid, late])
	var smoke := _render("blob", {"rise": 40.0}, 0.9)
	check(_centroid(smoke).y < -8.0, "上升距离让团块往上飘（%s）" % _centroid(smoke))
	return true


func test_flame_loops_seamlessly() -> bool:
	var a := _render("flame", {}, 0.0, 0.0, 96, true)
	var b := _render("flame", {}, 1.0, 0.0, 96, true)
	var c := _render("flame", {}, 0.4, 0.0, 96, true)
	check(a.v == b.v and a.a == b.a, "火焰在 u = 0 和 u = 1 完全相同")
	check(a.v != c.v, "火焰在动")
	check(_centroid(a).y < 0.0, "火焰在原点上方")
	return true


func test_bolt_flashes() -> bool:
	var params := {"flashes": 3, "on_ratio": 0.6, "mode": "arc"}
	var f0 := _render("bolt", params, 0.1)
	var f1 := _render("bolt", params, 0.43)
	var off := _render("bolt", params, 0.3)
	check(_count(f0) > 0 and _count(f1) > 0, "闪电亮的时候有像素")
	check(f0.v != f1.v, "每一下换一个形状")
	check_eq(_count(off), 0, "两下之间的熄灭期没有像素")
	return true


func test_layer_dissolve_override() -> bool:
	var buf := FxBuffer.new(8, 8)
	buf.rect(0, 0, 8, 8, 1.0, 1.0)
	var c := PackedFloat32Array([0.25, 1.0])
	var s := {
		"bayer": FxPalette.BAYER4, "dither_tab": FxPalette.FLAT, "dither_strength": 0.0,
		"dissolve": FxPost.Dissolve.DITHER, "alpha_levels": 2, "cleanup": false, "min_cluster": 1,
		"outline": FxPost.Outline.NONE, "outline_width": 1, "outline_square": false, "outline_rgb": Color.BLACK,
		"soft": 0.0, "glow_rgb": Color.WHITE, "flip_h": false, "flip_v": false,
	}
	var part := {"buf": buf, "fade": 0.5, "r": c, "g": c, "b": c, "outline": false, "dissolve": FxPost.Dissolve.FADE}
	var res := FxPost.new(8, 8).run([part], s)
	var px: PackedInt32Array = res["pixels"]
	check_eq((px[0] >> 24) & 0xff, 128, "图层设成淡出时，覆盖全局的抖动溶解（半透明）")
	return true


func test_buffer_primitives() -> bool:
	var buf := FxBuffer.new(32, 32)
	buf.rect(2, 3, 3, 2, 1.0, 1.0)
	check_eq(_count(buf), 6, "3×2 的矩形 6 个像素")
	var d := FxBuffer.new(32, 32)
	d.diamond(10.5, 10.5, 2.0, 1.0, 1.0, 1.0)
	check_eq(_count(d), 13, "半径 2 的菱形 13 个像素")
	var p := FxBuffer.new(32, 32)
	p.polygon(PackedVector2Array([Vector2(4, 4), Vector2(20, 4), Vector2(4, 20)]), 1.0, 1.0)
	var n := _count(p)
	check(n > 110 and n < 150, "直角三角形面积约 128（实际 %d）" % n)
	return true


func test_orb_trail_and_loop() -> bool:
	var right := _render("orb", {"trail": 30.0}, 0.3, 0.0)
	var left := _render("orb", {"trail": 30.0}, 0.3, 180.0)
	check(_centroid(right).x < -3.0, "飞向右边时拖尾在左边（%s）" % _centroid(right))
	check(_centroid(left).x > 3.0, "飞向左边时拖尾在右边（%s）" % _centroid(left))
	var params := {"shape": "flame", "orbiters": 3, "pulse": 0.5}
	var a := _render("orb", params, 0.0, 0.0, 96, true)
	var b := _render("orb", params, 1.0, 0.0, 96, true)
	var c := _render("orb", params, 0.4, 0.0, 96, true)
	check(a.v == b.v and a.a == b.a, "能量弹在 u = 0 和 u = 1 完全相同")
	check(a.v != c.v, "能量弹在动")
	return true


func test_glyph_draw_on_and_squash() -> bool:
	var early := _count(_render("glyph", {"draw_time": 0.6}, 0.1))
	var late := _count(_render("glyph", {"draw_time": 0.6}, 0.7))
	check(early > 0 and early < late * 0.5, "逐笔画出：开头只画了一部分（%d → %d）" % [early, late])
	var flat := _extent(_render("glyph", {"squash": 0.4, "radius": 40.0}))
	check(flat.y < flat.x * 0.6, "地面透视把法阵压扁（%s）" % flat)
	var a := _render("glyph", {"spin": 1.0}, 0.0, 0.0, 128, true)
	var b := _render("glyph", {"spin": 1.0}, 1.0, 0.0, 128, true)
	var c := _render("glyph", {"spin": 1.0}, 0.3, 0.0, 128, true)
	check(a.v == b.v, "整数圈旋转：首尾相同")
	check(a.v != c.v, "法阵在转")
	var faded := _count(_render("glyph", {"fade_out": 0.3}, 0.3))
	check(faded > 0, "结尾淡出不影响前段")
	return true


func test_beam_opens_and_points() -> bool:
	var up := _render("beam", {"length": 50.0}, 0.5, 270.0)
	check(_centroid(up).y < -10.0, "方向 270° 时光柱朝上（%s）" % _centroid(up))
	var opening := _count(_render("beam", {"open_time": 0.3}, 0.03))
	var open := _count(_render("beam", {"open_time": 0.3}, 0.5))
	check(opening < open * 0.5, "光柱从细线展开（%d → %d）" % [opening, open])
	var params := {"open_time": 0.0, "close_time": 0.0}
	var a := _render("beam", params, 0.0, 0.0, 96, true)
	var b := _render("beam", params, 1.0, 0.0, 96, true)
	check(a.v == b.v, "不展开收起时光柱首尾相同（可循环）")
	return true


func test_particles_gather_to_center() -> bool:
	var params := {"flow": "gather", "emit_mode": "burst", "emit_time": 0.0, "life": 1.0, "life_random": 0.0,
		"count": 30, "spread": 360.0, "shape": "square"}
	var early := _render("particles", params, 0.2)
	var late := _render("particles", params, 0.8)
	check(_extent(late).x < _extent(early).x * 0.7, "汇聚：越往后越靠近中心（%s → %s）" % [_extent(early), _extent(late)])
	return true


func test_stream_angles_not_sweeping() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var cfg := {"count": 32, "emit_shape": "ring", "emit_radius": 10.0, "angle": 0.0, "spread": 360.0, "speed": 50.0,
		"speed_random": 0.0, "life": 0.5, "life_random": 0.0, "emit_mode": "stream", "emit_time": 1.0, "size": 2.0,
		"size_random": 0.0, "spin": 0.0}
	var t := FxParticles.spawn(cfg, rng)
	# 最早出生的 8 个粒子应该分散在不同方向，而不是挤在同一个象限里（扫射）
	var quads := {}
	var x: PackedFloat32Array = t["x"]
	var y: PackedFloat32Array = t["y"]
	for i in 8:
		quads[int(floor(fposmod(atan2(y[i], x[i]), TAU) / (PI * 0.5)))] = true
	check(quads.size() >= 3, "持续发射的前 8 个粒子分布在 %d 个象限" % quads.size())
	return true


func test_buffer_polyline_and_ellipse() -> bool:
	var pl := FxBuffer.new(32, 32)
	# 坐标落在像素中心（.5）时，半径 0.5 的线正好 1 像素宽
	pl.polyline(PackedVector2Array([Vector2(4.5, 4.5), Vector2(24.5, 4.5), Vector2(24.5, 24.5), Vector2(4.5, 24.5)]), 0.5, 1.0, 1.0, true)
	var n := _count(pl)
	check(n >= 76 and n <= 90, "闭合折线画出正方形边框（%d 像素）" % n)
	var el := FxBuffer.new(64, 64)
	el.ellipse(32.0, 32.0, 20.0, 8.0, 1.0, 0.5, 1.0)
	var m := _count(el)
	check(absf(m - PI * 20.0 * 8.0) < 40.0, "椭圆面积约 πab（%d）" % m)
	check(el.v[32 * 64 + 32] > el.v[32 * 64 + 50], "椭圆中心比边缘亮")
	return true
