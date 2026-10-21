extends "res://tests/test_base.gd"
## 特效模块测试：每个模块用默认参数都能画出东西、结果确定；粒子 / 射线 / 环 / 冲刺线的关键行为；画布新原语

const FxRegistry := preload("res://addons/fx_forge/core/fx_registry.gd")
const FxBuffer := preload("res://addons/fx_forge/core/fx_buffer.gd")
const FxContext := preload("res://addons/fx_forge/core/fx_context.gd")
const FxPalette := preload("res://addons/fx_forge/core/fx_palette.gd")
const FxParams := preload("res://addons/fx_forge/core/fx_params.gd")
const FxParticles := preload("res://addons/fx_forge/core/fx_particles.gd")


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


func _render(id: String, overrides: Dictionary = {}, u: float = 0.3, angle: float = 0.0, size: int = 128) -> FxBuffer:
	var m: RefCounted = FxRegistry.get_module(id)
	var p := FxParams.normalize(m.get_param_defs(), overrides)
	var ctx := _ctx(size, angle)
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
		var buf := _render(id)
		check(_count(buf) > 0, "模块 %s 用默认参数能画出像素" % id)
		check(not buf.is_empty(), "模块 %s 记录了包围盒" % id)
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
