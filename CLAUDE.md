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
    fx_buffer.gd            图层强度画布（v 亮度 / a 可见度）+ 绘制原语
    fx_post.gd              后期合成：着色、消散、清理、描边、柔光、翻转、打包 RGBA8
    fx_job.gd / fx_renderer.gd   渲染任务（工作线程逐帧并行）/ 入口（同步、异步）
    fx_registry.gd          模块注册表
    fx_preset.gd            预设 Resource（class_name FxForgePreset）
    fx_preset_util.gd       预设构造、规范化
  modules/                  特效模块：fx_module.gd 基类，arc.gd 弧光
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
- [ ] M4 战斗打击包：burst / ring / particles / streak 模块、图层增删排序界面、柔光细化、12 个预设（火焰斩可加火星粒子层）
- [ ] M5 爆炸与元素：blob / flame / bolt 模块、循环首尾校验、9 个预设
- [ ] M6 魔法与状态：orb / glyph / beam 模块、粒子汇聚、8 个预设
- [ ] M7 环境与通用：8 个预设
- [ ] M8 打磨：GIF 导出、色板编辑与导入、帧停留（打击停顿）、多语言、性能优化

## 已知小问题 / 待办

- 预设库没有右键菜单（删除 / 重命名「我的预设」）。
- 「固定描边色」在「主色板最暗色」模式下也会显示。
- 「左右镜像」批量导出时，如果原点 X 不在 0.5，left 动画的锚点会偏（保持原点水平居中即可）。
- 撤销 / 重做按钮直接操作编辑器全局历史，会连带撤销其他全局操作（和 Ctrl+Z 行为一致）。
