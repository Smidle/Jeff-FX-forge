@tool
extends RefCounted
## 预览渲染调度：同一时刻最多一个任务在后台线程里跑；新请求只保留最新的一个，跑完马上接着跑。
## 主界面每帧调用 poll()；插件卸载前必须调用 shutdown()（等正在跑的任务结束）。

signal finished(job: RefCounted, full: bool, ms: float)

const FxRenderer := preload("../core/fx_renderer.gd")
const FxJob := preload("../core/fx_job.gd")

var _source: Callable
var _job: FxJob = null
var _gid := -1
var _t0 := 0
var _want_full := false
var _want_frame := -1


## source：返回当前要渲染的 FxPreset 的函数
func _init(source: Callable) -> void:
	_source = source


func request_full() -> void:
	_want_full = true
	_want_frame = -1


## 只重算一帧（拖动滑条时用）；已经排了整段渲染就不必了
func request_frame(frame: int) -> void:
	if not _want_full:
		_want_frame = frame


func is_busy() -> bool:
	return _gid != -1


func poll() -> void:
	if _gid != -1:
		if not WorkerThreadPool.is_group_task_completed(_gid):
			return
		WorkerThreadPool.wait_for_group_task_completion(_gid)
		_gid = -1
		var job := _job
		_job = null
		finished.emit(job, job.tag == 1, (Time.get_ticks_usec() - _t0) / 1000.0)
	if _want_full or _want_frame >= 0:
		_start()


func _start() -> void:
	var preset: Variant = _source.call()
	var full := _want_full
	var frame := _want_frame
	_want_full = false
	_want_frame = -1
	if preset == null:
		return
	var opts := {}
	if not full:
		opts["frames"] = PackedInt32Array([frame])
	var job := FxRenderer.make_job(preset, opts)
	job.tag = 1 if full else 0
	_job = job
	_t0 = Time.get_ticks_usec()
	_gid = FxRenderer.start_async(job)


func shutdown() -> void:
	if _gid != -1:
		WorkerThreadPool.wait_for_group_task_completion(_gid)
		_gid = -1
	_job = null
	_want_full = false
	_want_frame = -1
