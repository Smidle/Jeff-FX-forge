# Jeff FX 1.1

适用于 Godot 4.7 的像素特效插件，包含 129 款内置效果：像素工坊 63 款（含 pixelfx 升级版 25 款：升级版、烟花、飞弹命中）与三维效果库 66 款（含多风格扩展 18 款、追踪飞弹 4 款）。

复制整个 `fx_forge` 文件夹到工程的 `addons/`，在“项目 → 项目设置 → 插件”中启用 **Jeff FX**，点击编辑器顶部 **Jeff FX**。

- 个人配方：`res://fx_forge_presets/`
- 默认导出：`res://fx_exports/`
- 两类效果均可导出透明精灵图和放置到场景。
- 直接放置的效果与可编辑配方依赖插件；导出的二维即用场景连同 PNG / SpriteFrames 可独立使用。
- 像素特效可以在工坊的「3D 场景」里放进三维世界预览，旁边有参考角色；飞弹预览的终点有会受击的稻草人（`runtime/fx_straw_target.gd`，游戏里也能当测试目标）。
- 实测 Godot 4.7.2 / macOS / Compatibility；其他渲染器与设备尚未完成画面验收。

[完整图文说明](https://github.com/jeffstudio-dev/Jeff-FX-forge/blob/v1.1/docs/manual.md) · [追踪飞弹](https://github.com/jeffstudio-dev/Jeff-FX-forge/blob/v1.1/docs/missiles.md) · [特效库说明](https://github.com/jeffstudio-dev/Jeff-FX-forge/blob/v1.1/docs/multistyle-library.md) · [已知限制](https://github.com/jeffstudio-dev/Jeff-FX-forge/blob/v1.1/docs/compatibility.md) · [MIT 许可](LICENSE) · [素材说明](https://github.com/jeffstudio-dev/Jeff-FX-forge/blob/v1.1/NOTICE.md)
