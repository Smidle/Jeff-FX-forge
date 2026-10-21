@tool
extends RefCounted
## 图层渲染上下文：构建后只读，供工作线程读取。

var w: int = 0
var h: int = 0
## 图层原点（像素坐标，可带小数）
var ox: float = 0.0
var oy: float = 0.0
## 朝向（弧度）：0 = 朝右，顺时针为正（与 Godot 2D 一致）
var angle: float = 0.0
var cos_a: float = 1.0
var sin_a: float = 0.0
## 整体缩放（尺寸参数已按它换算，这里留给需要额外换算的模块）
var scale: float = 1.0
var frames: int = 1
var loop: bool = false
var seed: int = 0
## 4×4 Bayer 阈值表，模块需要局部溶解时用：bayer[((y & 3) << 2) | (x & 3)]
var bayer: PackedFloat32Array
