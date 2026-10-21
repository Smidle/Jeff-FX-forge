# FX Forge 像素特效工坊 — 开发说明

给 Claude（以及任何接手的开发者）看的项目说明。换电脑后先读这里，再读 `docs/design.md`（获批的完整设计方案）。

## 项目是什么

Godot 4.7 编辑器插件：用「预设 + 参数」在 CPU 上逐像素程序化生成像素风特效动画，导出 PNG 精灵图 / Aseprite JSON / SpriteFrames / 即用场景（.tscn）。
预设 = 若干图层，每层一个特效模块；参数由「参数说明表」驱动，界面自动生成。

## 和用户协作

- 用户不写代码、没有游戏策划经验：沟通用中文、少术语；技术决定自己做并说明理由；只有审美、用途、发布方式这类事才问用户。
- 每个里程碑：测试全过 → 渲染画廊图逐张自查美术效果 → 给用户简短说明和试用步骤 → git 提交并推送。
- 用户跨机器开发：项目知识写进仓库（本文件、`docs/`），不要只记在本机记忆里。改了规则 / 命令 / 进度就同步更新本文件。
- 用户正在用电脑时，不要做鼠标 / 键盘自动化；改用无头测试。

## 常用命令

Godot 路径用环境变量 `GODOT` 指定（**console 版**可执行文件）。原开发机默认：`C:\Tools\Godot-4.7.1\Godot_v4.7.1-stable_win64_console.exe`。

- Windows：`powershell -ExecutionPolicy Bypass -File tools/test.ps1 [unit|gallery|runtime|editor|selftest|all]`
- macOS / Linux：`tools/test.sh [unit|gallery|runtime|editor|selftest|all]`

| 套件 | 内容 |
|---|---|
| unit | 无头单元测试（tests/run_tests.gd 里的 SUITES） |
| gallery | 每个内置预设渲染成放大帧条：`tests/output/gallery/*.png`，看图调美术 |
| runtime | 在游戏环境里播放 `res://fx_exports/` 下所有导出场景：一次性特效必须自删、循环特效保持；演示场景能找到它们 |
| editor | 复制工程到临时目录，无头启动编辑器，检查插件加载无脚本错误、没被自动禁用 |
| selftest | 工程副本里跑编辑器内导出自检（新目录首次导出 + 覆盖导出，逐项校验） |

其他：
- 重新生成示例导出（写进本工程 `fx_exports/`）：`godot --headless --editor --path . -- --fxforge-export-samples`
- 截图检查界面：`godot --path . --editor -- --fxforge-show`（3 秒后自动切到特效工坊标签）
- 新机器第一次运行测试脚本会自动 `--import`。不要给 Godot 加 `-d`。
- Godot 运行时脚本错误不改变退出码：测试脚本会同时检索日志里的 `SCRIPT ERROR` / `Parse Error` 等。

## 目录

```
addons/fx_forge/
  plugin.gd                 只注册主屏幕标签和开发用启动参数（只 preload 脚本）
  core/                     纯计算，不碰任何 Editor API（可无头测试、可在游戏运行时用）
    fx_params.gd            参数说明表：构造、补默认、校正、按整体缩放换算
    fx_globals.gd           全局参数、图层通用参数、分组中文名
    fx_palette.gd           18 套色板、15 个配色主题、Bayer 抖动表、单色生成色阶
    fx_buffer.gd            图层强度画布（v 亮度 / a 可见度）+ 绘制原语（点、圆、胶囊线、直线、矩形、菱形、多边形、折线、椭圆）
    fx_particles.gd         解析式粒子：spawn() 主线程生成粒子表，draw() 按时间闭式求值（阻力 + 重力；或向中心汇聚）
    fx_noise.gd             可平铺的 128×128 值噪声表（按种子缓存），供模块逐像素查表
    fx_post.gd              后期合成：着色、消散、清理、描边、柔光（外晕取局部颜色）、翻转、打包 RGBA8
    fx_job.gd / fx_renderer.gd   渲染任务（工作线程逐帧并行）/ 入口（同步、异步）
    fx_registry.gd          模块注册表
    fx_preset.gd            预设 Resource（class_name FxForgePreset）
    fx_preset_util.gd       预设构造、规范化
  modules/                  特效模块：fx_module.gd 基类；arc 弧光、burst 射线爆发、ring 环、particles 粒子、streak 冲刺线、
                            blob 能量团、flame 火焰、bolt 闪电、orb 能量弹、glyph 法阵、beam 光柱
  presets/builtin_presets.gd  内置预设（代码定义）
  export/fx_export.gd       导出纯计算：动画规划、拼图、JSON、SpriteFrames、即用场景
  export/fx_exporter.gd     编辑器内落盘与导入（协程，调用方要 await）
  editor/                   main_panel / preset_browser / preview_stage / timeline / param_panel /
                            export_dialog / fx_session（编辑会话 + 撤销）/ render_scheduler / selftest
demo/                       演示场景（F5）
fx_exports/                 示例导出（演示场景和 runtime 测试会用到）
fx_forge_presets/           用户保存的预设（第一次保存时创建）
tests/                      测试与画廊脚本（tests/output 不入库）
tools/                      test.ps1 / test.sh
docs/                       design.md（设计方案）、images/
```

## 开发硬规则（Godot 4.7 源码核查 + 踩坑总结）

1. 插件脚本全部 `@tool`（导出场景里内嵌的运行时脚本除外）；重写引擎方法写全类型签名，每条分支都 return（4.7 起漏写 = 解析失败 = 插件被禁用）。
2. 插件内部互相引用用 `preload`；插件端脚本不预加载图片、场景等需要导入的资源（插件在首次导入前就加载）。界面全用代码构建，图标用编辑器主题图标。
3. `core/` 不碰 Editor API；编辑器功能只放 `editor/`、`export/fx_exporter.gd`。
4. 多线程：`WorkerThreadPool.add_group_task(..., high_priority = true)`；任务对象完成前保持引用；每个任务只 `wait_for_group_task_completion` 一次；插件关闭前先等任务结束（`render_scheduler.shutdown()`）。
5. 工作线程不碰共享随机数生成器、Resource、贴图或节点；随机数据在 `prepare()`（主线程）里预生成。
6. 逐像素循环里不调用 GDScript 函数、不查字典、不构造 Vector2/Color；用查表。
7. **Packed\*Array 是值类型**：传进函数后修改只改副本。大循环里写数组：要么写自己的成员，要么用 `var bv := buf.v; buf.release(); ……; buf.restore(bv, ba)` 模式（避免整块复制）。
8. 预设：`load()` 返回共享缓存，编辑前 `clone()`；内置预设只读；加载时按说明表规范化（整数取整、枚举存字符串 id）。
9. 撤销：动作挂在 `FxSession`（RefCounted）上进入编辑器全局历史，`mark_unsaved = false`；载入新预设后旧动作按「代数」失效。
10. 导出顺序：等编辑器空闲 → 写 PNG → 导入 → 加载贴图 → SpriteFrames（已存在则原地更新）→ 场景。**`update_file` 不会登记新目录里的文件（4.7.1 实测）**：目录对编辑器是新的时先 `efs.scan()` 并等扫描和导入结束。
11. SpriteFrames 循环用 4.7 的 `set_animation_loop_mode`（有 LOOP_NONE / LOOP_LINEAR / LOOP_PINGPONG）。
12. 导出场景的内嵌脚本不能是 `@tool`；不要在根节点保存 `animation_finished → queue_free` 连接（编辑器预览会删掉场景根）。
13. 提交插件的 `.uid` 文件。
14. Windows 下调用图形界面程序（如 Aseprite 命令行）要用 `Start-Process -Wait`，否则不会等它跑完。
15. 参数说明表可加 `show_if = [参数 id, 值]` / `hide_if = [参数 id, 值]`（同一作用域内比较），参数面板据此隐藏无关参数，依赖值变化时自动重建。
16. `FxSession.undo` 用 `Object` 类型：`EditorUndoRedoManager` 只在编辑器里存在，写死类型会让无头测试加载不了这个脚本。
17. 模块可以实现 `get_layer_defaults()`，规定新建这种图层时的默认图层设置（例如粒子默认用辅色板、不描边）。
18. 预设里的粒子图层要算好飞行距离（无阻力时速度 = 整段走过的像素；有阻力时最远约 速度 ÷ 阻力），画廊脚本和单元测试都会报「超出画布」。
19. 逐像素噪声一律查 `fx_noise.gd` 的表（`table[((y & MASK) << SHIFT) | (x & MASK)]`），表在 prepare 里取、按种子缓存。
20. 循环特效必须在 u = 0 和 u = 1 完全相同（单元测试逐字节校验每个循环预设的第 N 帧 = 第 0 帧）。做法：噪声采样点绕圆周
    移动（能量团）、两份相差一个周期的滚动噪声交叉淡化再做方差补偿（火焰）、随时间变化的量用整数圈的 sin/cos、粒子用 fposmod。
21. 图层的「消散方式」可以覆盖全局（渲染任务里 -1 = 跟随全局）。
22. 粒子图层默认用辅色板（`get_layer_defaults`）：预设里要用主色板、要描边的粒子层必须显式写 `palette_slot` / `outline`。
23. 柔光会把细线条之间的空隙糊成一片灰（法阵、细光丝）：线稿类预设柔光 ≤ 0.2；大面积发光体（护盾泡、能量弹）可以到 0.5。
24. 持续发射的粒子：出生时间按序号排，发射角度用打乱后的序号（否则整圈发射会像扫射一样转圈出现）。

## 新增特效模块

1. 新建 `modules/xxx.gd`：`@tool`，`extends "fx_module.gd"`；`get_param_defs()` 用 `fx_params.gd` 的构造函数（尺寸类参数加 `scale = true`，分组用 shape / motion / detail）；`prepare()` 预生成随机数据；`render()` 只写传入的画布，返回图层整体可见度（0~1，用于消散）。
2. 在 `core/fx_registry.gd` 的 `_SCRIPTS` 里加一行。
3. 在 `presets/builtin_presets.gd` 加预设。
4. `tools/test.ps1 all`，看 `tests/output/gallery/` 的图调效果；再用 `--fxforge-export-samples` 更新示例导出。

## 进度

- [x] M0 工程骨架、插件空壳、测试框架
- [x] M1 核心渲染管线 + 弧光模块 + 6 个弧光预设（含水墨「墨刃」）
- [x] M2 编辑器界面（预设库、预览、时间轴、自动参数面板、撤销重做、保存 / 另存为、参考图、自动适配画布）
- [x] M3 导出（PNG / JSON / SpriteFrames / 即用场景 / 单帧序列 / 预设副本，方向批量、变体、裁边、放大）+ 演示场景
      —— 第一版 0.1，已推到 GitHub 私有仓库 Smidle/Jeff-FX-forge
- [x] M4 战斗打击包（0.2）：burst / ring / particles / streak 模块；图层增删、复制、排序、隐藏、改名界面（可撤销）；
      参数按条件显示；柔光外晕取局部颜色；新增突刺、普通打击、重击、暴击、格挡火花、地面冲击波、能量冲击环，
      火焰斩加火星、寒冰斩加冰屑——内置预设共 13 个；编辑器自检加了界面冒烟（图层操作、改参数、换主题）
- [x] M5 爆炸与元素（0.3）：blob 能量团（内部噪声明暗、后半段噪声烧穿）、flame 火焰（多火舌 + 交叉淡化循环）、
      bolt 闪电（落雷 / 电弧 / 放射）；可平铺噪声表；图层级消散方式；循环首尾逐字节校验；
      新增小型 / 大型 / 毒气爆炸、篝火、火把、蓝焰、落雷、电弧、冰晶爆裂——内置预设共 22 个
- [x] M6 魔法与状态（0.4）：orb 能量弹（火球 / 圆球 / 菱形、波动拖尾、环绕光点）、glyph 法阵（多环 + 星形多边形 +
      刻度 + 顶点符文，可逐笔画出、地面透视）、beam 光柱（展开 / 收起、流动亮条、底部光斑）、粒子向中心汇聚、
      大十字粒子；新增火球弹、魔法飞弹、治疗、增益光环、护盾、蓄力、魔法阵、召唤阵展开——内置预设共 30 个
- [ ] M7 环境与通用：8 个预设
- [ ] M8 打磨：GIF 导出、色板编辑与导入、帧停留（打击停顿）、多语言、性能优化

## 已知小问题 / 待办

- 预设库没有右键菜单（删除 / 重命名「我的预设」）。
- 预设库缩略图固定取时间轴 40% 处的一帧，打击类特效不一定是最好看的那帧。
- README 里的界面截图还是 0.1 版的（图层区是下拉框）；用户不在用电脑时可以用 `-- --fxforge-show` 重拍。
- 「左右镜像」批量导出时，如果原点 X 不在 0.5，left 动画的锚点会偏（保持原点水平居中即可）。
- 撤销 / 重做按钮直接操作编辑器全局历史，会连带撤销其他全局操作（和 Ctrl+Z 行为一致）。
