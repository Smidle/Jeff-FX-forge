# 可选的三维播放入口（开发版）

`addons/fx_forge/runtime/fx_3d.gd` 是静态适配器，不需要 Autoload，也不替换现有场景脚本。此入口未被旧 82 款配方或庭院测试场景调用。

```gdscript
const FX3D = preload("res://addons/fx_forge/runtime/fx_3d.gd")

# recipe 可为工坊 FxForgePreset，也可为底层 JeffForge3DPreset。
var effect = FX3D.spawn_between(recipe, get_tree().current_scene,
    muzzle.global_position, target.global_position)

# 偏移使用目标的局部坐标；目标转动时偏移跟随它转动。
var homing = FX3D.spawn_to(recipe, get_tree().current_scene,
    muzzle.global_position, target, Vector3(0, 1, 0))
if homing != null:
    homing.arrived.connect(_on_visual_arrived)
```

- `spawn(recipe, parent, world_transform, options)`：按世界变换创建一般三维效果。
- `spawn_between(recipe, parent, start, end, options)`：世界起终点，支持飞弹与现有双端点流光／电弧图层。
- `spawn_to(recipe, parent, start, target, target_offset, options)`：绑定有效 `Node3D`，仅支持包含飞弹图层的配方。
- 每次复制配方、图层、飞弹配置和自定义曲线；不会改写传入的内置／个人资源。
- 非有限坐标、缺失目标、已离场目标、无效父节点或不可逆父变换返回 `null`。起终点相同交由原飞弹运行层处理为命中。
- 父节点有旋转或缩放时，传入坐标仍是世界坐标。已发射飞弹保留世界轨迹。
- 返回的实例默认 `auto_free=true`，尾部结束后回收。需要复用时传入 `{"auto_free": false}`。
- 可选项：`quality`、`backend` 沿用 `JeffForge3DInstance` 枚举；`preview=true` 仅供编辑器临时预览，抑制真实到达事件。
- 创建时先关闭自动播放，设置位置及目标，再开始播放，避免目标绑定前先发出一帧。

`arrived` 表示视觉到达，不等于物理碰撞或伤害判定。游戏应独立处理伤害和战斗规则。

## 回归脚本

`tests/library_missile_regression.gd` 提供 `run(host, args)`，请复制到工程 `res://` 外后交由现有后台 QA host 执行。支持 `output_dir`，会把四种原有弹头的临时 `.tres` 保存在测试输出目录，不加入素材库。

覆盖嵌套参数编辑、依赖项隐藏、曲线复制隔离、保存重载、六种轨迹、垂直路径、世界起终点、移动目标及局部偏移、删除／离场／瞬移／停止、到达与结束事件、暂停倒拖、24／120 Hz 固定步长一致性、1／3／16 发和两档容量。

此脚本检查运行逻辑和缓冲容量；关闭的离屏视口不构成美术验收或 GPU 性能证明。编辑器 QA 显式构建预览后再启用真实运行信号，未更改全局编辑器状态。
