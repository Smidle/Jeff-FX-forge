extends SceneTree
## 无头测试入口：
##   godot --headless --path . --script res://tests/run_tests.gd [-- 测试文件名过滤]
## 任一测试失败则以退出码 1 结束。

const SUITES: Array[String] = [
	"res://tests/test_smoke.gd",
]


func _initialize() -> void:
	_prepare_output_dir()
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0]
	var total := 0
	var failed := 0
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		if not filter.is_empty() and not path.contains(filter):
			continue
		var script := load(path) as GDScript
		if script == null:
			print("  FAIL  无法加载测试脚本 ", path)
			failed += 1
			continue
		for m: Dictionary in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var suite: RefCounted = script.new()
			var t1 := Time.get_ticks_usec()
			var result: Variant = suite.call(name)
			var ms := (Time.get_ticks_usec() - t1) / 1000.0
			var errors: PackedStringArray = suite.get("errors")
			if result != true:
				errors.append("测试中途中断（多半是脚本错误，见上方日志）")
			if errors.is_empty():
				print("  ok    %s :: %s  (%.1f ms)" % [path.get_file(), name, ms])
			else:
				failed += 1
				print("  FAIL  %s :: %s" % [path.get_file(), name])
				for e in errors:
					print("        - ", e)
	print("")
	print("共 %d 个测试，失败 %d 个，用时 %d ms" % [total, failed, Time.get_ticks_msec() - t0])
	quit(1 if failed > 0 else 0)


func _prepare_output_dir() -> void:
	var dir := ProjectSettings.globalize_path("res://tests/output")
	DirAccess.make_dir_recursive_absolute(dir)
	var ignore := dir.path_join(".gdignore")
	if not FileAccess.file_exists(ignore):
		var f := FileAccess.open(ignore, FileAccess.WRITE)
		if f != null:
			f.store_string("")
