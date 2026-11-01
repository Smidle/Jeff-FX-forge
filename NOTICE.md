# 版权、素材与署名

## 代码和文档

Jeff FX 的代码、庭院测试脚本与本仓库文档采用根目录 [MIT License](LICENSE)。原 Jeff Studio FX 运行模块保留在 `addons/fx_forge/legacy/`，附原 MIT 许可。

## 插件原创特效

插件内 `addons/fx_forge/legacy/assets/` 的原创纹理、缩略图和爆炸 Logo 按 **CC0 1.0 Universal** 提供，见 [素材声明](addons/fx_forge/legacy/assets/LICENSE.txt)。测试场景 `assets/effects/` 和 `assets/courtyard/fx_variants/` 为这些原创效果的程序生成/录制结果。

部分像素图由代码或 Aseprite 原生绘制；部分使用生成式图像工具制作原创图，再经 Aseprite 整理。庭院背景、练功石和技能图标也采用上述原创制作流程，并按 CC0 1.0 提供。角色和头像不在这项声明内。

## 工坊参考角色

工坊 3D 场景里的参考角色（`addons/fx_forge/editor/reference_figure.gd`）由代码现场生成，不含贴图素材，随插件代码采用 MIT。生成方式（三维骨架、两段 IK、椭球拼身体、经深度缓冲画成平涂像素并描边）参考 [pixelfx](https://github.com/patch-gg/pixelfx) 的 `src/core/rig.js`，Copyright (c) 2026 Patch, Hugo Duprez，MIT License；代码为 GDScript 重写，没有复制原文件。

## 稻草人靶子

飞弹预览终点的稻草人（`addons/fx_forge/runtime/fx_straw_target.gd`）由代码现场画出，不含贴图素材，随插件代码采用 MIT。它被打中时的弹簧摇晃、闪白、染色和飞出的稻草，参考 [pixelfx](https://github.com/patch-gg/pixelfx) 的 `src/core/act.js`（Copyright (c) 2026 Patch, Hugo Duprez，MIT License），而 pixelfx 的这部分又参考了 [Hollow Crown](https://github.com/rehan-remade/hollow-crown)（Copyright (c) 2026 rehan-remade，MIT License）。代码为 GDScript 重写，造型重新绘制，没有复制原文件。

## 第三方演示角色和头像

庭院主角使用《逸剑风云决》提取素材 `TongYong/Hero`，两名固定靶使用 `TongYong/ShanZei_1`、`TongYong/ShanZei_2`；头像使用 `T_Hero_HeadImage.png`。由仓库维护者提供素材，并于 **2026-10-23 确认已取得公开再分发授权**，本次按其授权确认随演示工程保留。

适用文件：

- `assets/courtyard/hero.png`、`hero_frames.tres`；
- `assets/moon_temple/bandit1.png`、`bandit2.png` 及对应帧资源；
- `assets/courtyard/ui/hero_portrait.png`；
- 用户手册中包含这些角色的庭院运行截图。

版权仍归原权利人所有。上述第三方素材**不采用本仓库代码的 MIT，也不采用原创特效的 CC0**。本说明不是对下游任意商用、素材提取或再次授权的承诺；超出演示使用的权利请自行向权利人确认。动作来源和切帧记录在 `data/courtyard/hero_actions.json`，公开记录不包含开发机器的绝对路径。

## 字体

庭院使用 **GNU Unifont 18.0.01 / 16px**，选用其 **SIL Open Font License 1.1** 许可。字体未修改，完整声明位于 [字体 LICENSE](assets/courtyard/fonts/LICENSE.txt) 与 [OFL-1.1](assets/courtyard/fonts/OFL-1.1.txt)，来源见 [SOURCE.json](assets/courtyard/fonts/SOURCE.json)。

## 分发范围

专用 Release 附件 `Jeff-FX-1.1-plugin.zip` 只包含 `addons/fx_forge/`，不包含测试场景、第三方角色、头像或字体。仓库源码下载包含完整测试工程，需同时遵守上述各类许可。你自行导入的参考图、字体或其他素材仍遵守各自来源许可。

## 只在维护者本机使用的第三方素材

两个测试场景在维护者本机还用到了第三方游戏素材，版权属于原作者，**仓库和 Release 都不包含**（`.gitignore` 已排除）：

- 等距测试场的「林间遗迹 · 山贼营地」场景模型与贴图：`assets/octopath/`（《八方旅人》）。
- 夏日花火大会的人物、远景、草地和道具：`assets/convallaria/`（《铃兰之剑》）。

没有这些素材时，两个场景照常运行：等距测试场只有地面、角色和特效，花火大会只有夜空、灯笼、萤火虫和烟花，画面上会给出提示。

## 社群图片

`docs/community/` 中的微信群与 QQ 群二维码截图由维护者提供，用于展示入群方式，不属于 CC0 特效素材。
