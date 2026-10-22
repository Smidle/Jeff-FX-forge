# Jeff FX · 1.0.1

**Godot 4.7 像素特效插件：挑选效果、调整参数、放入场景，也可以导出透明精灵图。**

免费、离线使用。藏青色三栏工坊，包含 **82 款内置效果：38 款像素工坊预设 + 44 款经典三维效果**。

[图文用户说明书](docs/manual.md) · [版本记录](CHANGELOG.md) · [兼容性与已知限制](docs/compatibility.md) · [代码许可](LICENSE) · [素材与署名](NOTICE.md)

![Jeff FX 像素工坊实际界面](docs/images/01-workshop.png)

## 可以做什么

| 能力 | 像素工坊 · 38 款 | 经典效果库 · 44 款 |
|---|---|---|
| 内容 | 刀光、打击、爆炸、火焰、法阵、状态与环境 | 环境、武侠、仙侠、魔法 |
| 制作方式 | 代码逐像素生成，可组合模块图层 | 程序、粒子、像素序列帧与网格组合 |
| 编辑 | 画布、帧数、方向、色板、图层、消散等 | 配色、大小、速度、密度、空间及各图层参数 |
| 预览 | 时间轴、逐帧、背景、锚点和参考图 | 独立 3D 视口、正交/透视、旋转、标准/精简档 |
| 直接放置 | Node2D 或 Node3D 场景 | Node3D 场景 |
| 导出 | PNG、JSON、SpriteFrames、即用场景、单帧序列、GIF | 从当前三维镜头录制后导出相同格式 |

两类均支持保存个人预设和撤销重做。此插件负责特效制作与播放；技能按键、伤害、血量、碰撞和目标选择由游戏逻辑处理。

![经典三维效果实际界面](docs/images/07-classic.png)

## 安装：复制一个文件夹

1. 安装 Godot **4.7**；本版本实测 **4.7.2 / macOS / Compatibility**。
2. 从本仓库的 **Code → Download ZIP** 下载源码并解压，或克隆仓库。
3. 将 `addons/fx_forge/` 整个目录复制到你的 Godot 工程的 `addons/` 下。
4. 等资源导入完成，在 **项目 → 项目设置 → 插件** 中启用 **Jeff FX**。
5. 点击编辑器顶部的 **Jeff FX**。

仓库提供插件与说明文件，**不附带独立演示工程或 `project.godot`**；请安装到你自己的工程。首次使用也可以先创建一个空白 Godot 工程。

## 五分钟上手

1. 左侧选择 **像素工坊 → 火焰斩**。
2. 右侧调整大小、方向、配色；下方暂停或逐帧检查。
3. 点击 **另存为…**，把修改保存到“我的预设”。
4. 打开一个 Node2D 场景，返回工坊点击 **放置当前效果**，在画布上单击确认，按 Esc 取消。
5. 给场景保存文件，按 **F6** 运行当前场景；也可点击 **导出精灵图…** 获取动画文件。

每一步的界面、两类导出差别及脚本接入见 [用户说明书](docs/manual.md)。

## 文件存放与升级

```text
你的游戏/
├── addons/fx_forge/       插件本体
├── fx_forge_presets/      你保存的效果配方（自行生成）
└── fx_exports/            默认导出位置（自行生成）
```

升级前备份工程，停用插件后完整替换 `addons/fx_forge/`，再重新启用。保留 `fx_forge_presets/`、`fx_exports/` 和你的场景。

“预设”保存制作参数；“放置”把效果节点加入场景；“导出”生成定型的图片与动画。直接放置的效果依赖插件运行脚本，导出的即用二维场景连同它引用的 PNG / SpriteFrames 可独立使用。

## 兼容性

- 插件不改写宿主工程分辨率、相机、输入绑定或全局界面主题。
- 三维经典效果录制为二维帧，导出后不能重新旋转观察；持续效果的有限时间录制不保证无缝循环。
- 部分爆炸与烟雾预设仍有可见的末帧截断，详见 [已知限制](docs/compatibility.md)。
- Forward+、Mobile 渲染器及手机实机性能尚未完成画面验收；精简档不等于手机性能保证。

## 许可

代码与文档采用 **MIT**。所附原创特效贴图、像素图与 Logo 按 **CC0 1.0** 提供，含使用生成式工具并经 Aseprite 整理的原创素材；详见 [NOTICE](NOTICE.md)。仓库不包含第三方游戏提取素材。

---

**English:** Jeff FX 1.0.1 is a free, offline Godot 4.7 VFX editor with 38 procedural pixel presets and 44 classic 3D effects. Copy `addons/fx_forge` into your project, enable **Jeff FX** under Project Settings → Plugins, then open the **Jeff FX** workspace. Both libraries support sprite-sheet export and scene placement. The UI and illustrated manual are primarily Chinese. Tested with Godot 4.7.2 on macOS using Compatibility; other renderers and mobile hardware remain unverified.
