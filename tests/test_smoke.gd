extends "res://tests/test_base.gd"
## 冒烟测试：预设资源能正确保存、读回、深拷贝

const FxPreset := preload("res://addons/fx_forge/core/fx_preset.gd")


func test_preset_save_and_load_roundtrip() -> bool:
	var p: Resource = FxPreset.new()
	p.preset_id = "roundtrip"
	p.display_name = "往返测试"
	p.globals = {"canvas_w": 48, "palette_main": PackedColorArray([Color.RED, Color.BLUE])}
	p.layers = [{"module": "arc", "params": {"radius": 12.5, "easing": "out_cubic"}}]
	var path := OUTPUT_DIR + "roundtrip.tres"
	check_eq(ResourceSaver.save(p, path), OK, "保存预设")
	var q: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(q != null, "重新加载预设")
	if q == null:
		return true
	check_eq(q.display_name, "往返测试", "中文名称")
	check_eq(q.globals["canvas_w"], 48, "整数参数")
	check_eq(q.globals["palette_main"], PackedColorArray([Color.RED, Color.BLUE]), "颜色数组")
	check_eq(q.layers[0]["params"]["radius"], 12.5, "图层参数")
	check_eq(q.layers[0]["params"]["easing"], "out_cubic", "枚举存字符串")
	return true


func test_clone_is_deep() -> bool:
	var p: Resource = FxPreset.new()
	p.globals = {"seed": 3}
	p.layers = [{"params": {"radius": 10.0}}]
	var c: Resource = p.clone()
	c.globals["seed"] = 99
	c.layers[0]["params"]["radius"] = 20.0
	check_eq(p.globals["seed"], 3, "修改副本不影响原件的全局参数")
	check_eq(p.layers[0]["params"]["radius"], 10.0, "修改副本不影响原件的图层参数")
	return true
