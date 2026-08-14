# 游戏本体后处理逆向分析与 Unity 复现

## 结论

游戏本体并非只依赖一套通用后处理，而是同时使用了三条路径：

- Beautify/Volume 风格的全局相机后处理：Bloom、色调映射/色彩处理、景深等。
- 自定义全屏相机效果：Camera Motion Blur、Camera Fade、Vignetting、Blackout Curtain。
- UI 与特效合成：Gaussian/Premium Blur、UI Vignetting、圆形/波浪/擦除转场、屏幕扭曲和 ScreenUV 特效。

本次 Unity 复现完成了可直接验证的核心链路：URP Volume 的 Bloom、Vignette、Neutral Tonemapping、可选 Gaussian DOF、可选 Camera-only Motion Blur，以及按本体真实参数还原的 CameraFade/Vignetting 全屏覆盖层。UI 路径另提供 Premium Blur、Circular/Wave/Wipe 转场、Blackout 和 UI Vignetting 等价实现。高成本的 DOF、Motion Blur 和 UI Blur 默认关闭，适合移动端基线配置。

## 分析范围与方法

- 本体目录：`appdata/`
- 逆向工作目录：`appdata/_re_work/`
- 分析文件规模：约 16,172 个文件。
- Unity 目标工程：Unity 2022.3.62f3、URP 14.0.12。
- 主要方法：复核 UnityPy 解包结果、Shader 索引、Blob 中的 Shader ParsedForm、材质 JSON、场景 MonoBehaviour dump，以及 ResourcesPackage 索引字符串。

判断时优先使用可定位到 Blob、pathID 或真实材质参数的证据。仅由资源名推断的项目单独标记为“资源存在”，不直接等同于运行时一定启用。

## 已确认的技术

### 全局后处理

- Bloom：ResourcesPackage 索引含 `FX_GlowBloom_*`，当前 Unity 工程的 Volume Profile 也有 Bloom 配置。需要注意，名为 GlowBloom 的部分资源可能只是发光素材，不能全部当作全局 Bloom。
- Tone Mapping / 色彩处理：本体存在 Volume/Beautify 风格配置；复现采用 URP Neutral Tonemapping，避免 ACES 造成额外风格偏移。
- Depth of Field：`scene_env_dump.json` 中找到 5 个 `BeautifySettings` MonoBehaviour，含 `depthOfFieldTarget`。ResourcesPackage 索引同时出现 `Global_Volume_Profile_DOF_Effect_PC_Only`，证明 DOF 存在且至少有 PC 专用配置。
- Motion Blur：Shader 索引和 Blob 中确认 `MMN/PP/CameraMotionBlur`，包含两个全屏 Pass，使用 `ZTest Always`、`ZWrite Off`、`Cull Off`。
- SSAO：目标 Unity Renderer 已启用 SSAO Renderer Feature。它属于屏幕空间环境遮蔽，不应和 Bloom 等颜色后处理混为一类，但会影响最终画面层次。

### 自定义相机全屏效果

- `MMN/Special/CameraFade & Vignetting`
  - 来源：`AssetPackages/Starter/0031.blob#97`
  - pathID：`-4231167386557830639`
  - `_ScreenFXMode`：Fade=0、Vignetting=1
  - Pass LightMode：`ScreenSpaceRenderObjects`
  - Queue：`Transparent+1050`
  - 深度状态：`ZTest Always`、`ZWrite Off`
  - 混合方式由 `_BlendSrc` / `_BlendDst` 参数控制。
- `MMN/Special/CameraBlackoutCurtain`：来源 `AssetPackages/0387.blob#315`，pathID `-2547073874191565821`；只暴露 `_BaseMap` 与 `_BaseColor`，属于遮幕/剧情过场类屏幕合成。
- `MMN/Misc/Full Screen Blur Draw` 与 `MM/UI/UI Full Screen Blur Draw`：确认存在全屏模糊绘制路径。

### UI、转场与屏幕空间特效

- `MM/UI/UI_PremiumBlur`
  - 来源：`AssetPackages/Starter/0043.blob#4`
  - pathID：`-6840469445020073579`
  - Gaussian Blur 参数：`_KernelSize` 默认 4、范围 1–28；`_SampleSpacing` 默认 4、范围 1–16；`_Sigma` 默认 2。
  - 支持 `_MaskTex`、`_LevelFrom`、`_LevelTo`，说明它不只是无条件全屏模糊，还支持区域和层级控制。
- `MM/UI/UI_Vignetting`：UI 层独立暗角，来源 `AssetPackages/0387.blob#112`，pathID `-7082405632392231888`。
- `MM/UI/UI_ScreenTransition_Circular`：圆形转场，来源 `AssetPackages/0387.blob#108`，pathID `6403108277641546429`。
- `MM/UI/UI_ScreenTransition_Wave`：波浪转场，来源 `AssetPackages/0387.blob#109`，pathID `4939266269853370394`。
- `MM/UI/UI_ScreenTransition_Wipe`：擦除转场，来源 `AssetPackages/0387.blob#110`，pathID `-6647171225764078389`。
- 多种 ScreenUV、屏幕扭曲和 Glow Shader：用于特效粒子或 UI 对已渲染画面的采样与扰动。
- `MMN/BG/MMN_WaterSunGlare_Simple`：水面太阳眩光，属于场景材质/屏幕空间混合效果，不是通用相机 Bloom 的替代品。

## 本体真实暗角参数

真实材质来自：

`appdata/_re_work/tir_vegetation/materials/dedicated_bundle_7a769239__FX_Vinegtting_2.json`

- `_ScreenFXMode = 1`
- `_VignettingRange = 0.567`
- `_VignettingSmooth = 0.18`
- 颜色为黑色。
- Alpha 约为 `0.702`。
- `_BlendSrc = 5`
- `_BlendDst = 10`

另有白色暗角材质：

`appdata/_re_work/tir_vegetation/materials/dedicated_bundle_1ad323a4__FX_Vignetting_White.json`

这说明暗角并不只用于“压黑四周”，也可参与白闪、淡出或特殊过场。

## Unity 复现结构

### `MMNPostProcessingRepro`

路径：`Assets/MMN/Runtime/MMNPostProcessingRepro.cs`

- 自动开启相机 HDR 和 URP Post Processing。
- 运行时创建临时 `VolumeProfile`，不会覆盖工程中的现有 Profile 资产。
- 默认启用 Bloom、Vignette、Neutral Tonemapping。
- DOF 与 Motion Blur 作为独立开关，默认关闭。
- CameraFade/Vignetting 使用单独的全屏 Canvas 合成，和 Volume 栈分离，便于按本体两条渲染路径独立对比。
- 禁用组件时恢复相机原先的 Volume Profile，并销毁运行时材质和覆盖层。

### CameraFade/Vignetting Shader

路径：`Assets/MMN/Shaders/Special/MMN_Special_CameraFadeVignetting.shader`

- Shader 名：`MMN/Repro/CameraFade & Vignetting`
- 保留本体属性名、模式值、Queue、LightMode、深度状态和参数化 Blend 语义。
- 默认使用本体黑色暗角材质参数：Range 0.567、Smooth 0.18、Alpha 0.702。
- Fade 模式输出均匀全屏覆盖；Vignetting 模式根据屏幕中心距离生成边缘遮罩。

### UI Premium Blur

路径：

- `Assets/MMN/Shaders/Special/MMN_UI_PremiumBlur.shader`
- `Assets/MMN/Runtime/MMNPremiumBlurRepro.cs`

- 保留本体 `_MaskTex`、`_KernelSize`、`_SampleSpacing`、`_Sigma`、`_LevelFrom`、`_LevelTo`、Stencil 和 Blend 参数接口。
- 将本体 1–28 的 KernelSize 映射到 1–14 半径的十字 Gaussian 采样近似，Mask 的灰度区间通过 LevelFrom/LevelTo 重映射。
- 组件挂在 `RawImage` 或其他 `Graphic` 上；实际 UI 背景模糊时，`RawImage.texture` 应接入项目已有的降采样相机颜色 RenderTexture。
- 组件运行时使用 `One/Zero` 覆盖输出，避免 ParsedForm 默认 `One/One` 在普通 UI 画布上产生不受控叠加；如复原到本体的专用合成阶段，可直接在材质中恢复原 Blend 参数。

### UI 转场、遮幕和 UI Vignetting

路径：

- `Assets/MMN/Shaders/Special/MMN_UI_ScreenEffects.shader`
- `Assets/MMN/Runtime/MMNScreenEffectsRepro.cs`

- 统一保留 `_TransitionProgress` 与 `_Inverse` 的本体语义，并提供 Circular、Wave、Wipe 三类模式。
- Blackout 使用全屏进度控制，作为 `CameraBlackoutCurtain` 的 UI 合成等价路径。
- Vignetting 模式复用本体真实 Range/Smooth 参数。
- 自动创建独立的 Screen Space Overlay Canvas，不与 URP Volume 或 CameraFade/Vignetting 材质耦合。

### 示例场景

路径：`Assets/MMN/PostProcessing/Scenes/MMN_PostProcessing_Repro.unity`

生成菜单：`Tools/MMN/Post Processing/Create Reproduction Scene`

场景包括：

- 开启 HDR/Post Processing 的主相机。
- Directional Light 和移动端可接受的基础环境光。
- 暖色、冷色高强度 Emission 球，用于观察 Bloom。
- 中灰参考物体和多排深度标记，用于观察 Tonemapping 与可选 DOF。
- 已挂载并默认启用 `MMNPostProcessingRepro`。
- 已挂载 `MMNScreenEffectsRepro`，默认 Circular 且 Progress=0，不遮挡基线画面，可在 Inspector 中直接切换并拖动进度验证。

验证截图：`Assets/MMN/PostProcessing/Captures/MMN_PostProcessing_Repro_Direct.png`

Circular 中间态验证截图：`Assets/MMN/PostProcessing/Captures/MMN_PostProcessing_ScreenTransition_CameraCanvas.png`

Unity MCP 的相机截图不会包含 Screen Space Overlay Canvas，因此转场截图仅在采集时把运行时 Canvas 临时切到 Screen Space Camera；采集后已恢复 Overlay 和 Progress=0，示例场景没有保存临时测试状态。

## 默认参数与性能建议

- Bloom：默认开启，强度 1、阈值 1、Scatter 0.7、最多 6 次迭代。
- Vignette：URP Volume 暗角强度 0.25、Smoothness 0.4；本体自定义暗角覆盖层单独开启。
- DOF：默认关闭。证据表明本体存在 PC-only Profile，移动端应按机型分级开启。
- Motion Blur：默认关闭。移动端相机快速运动时再按质量档开启，避免额外全屏采样和拖影影响可读性。
- Premium/UI Blur：建议按 UI 窗口按需启用，使用降采样 RenderTexture，并限制 Kernel 与 SampleSpacing；不要常驻全分辨率 Gaussian Blur。
- 屏幕转场：适合事件驱动、短时播放，不应并入常驻 Volume 栈。
- SSAO：沿用 Renderer Feature 的质量分级；低端机优先降低采样数和分辨率。

## 已验证结果

- Unity 2022.3.62f3 下脚本编译通过，三个复现 Shader 均为 0 error、0 warning。
- 项目代码没有新增 Console error/warning；验证期间仅出现 Unity MCP 包自身的 WebSocket 未初始化警告，与复现代码无关。
- 示例场景可成功生成和加载。
- 相机已启用 HDR 与 URP Post Processing。
- 运行时 Volume 含 Bloom、Vignette、Tonemapping、DepthOfField、MotionBlur；前三项启用，后两项按默认策略关闭。
- CameraFade/Vignetting 覆盖层已在相机子对象下创建。
- UI Screen Effects 覆盖层可在 Circular、Wave、Wipe、Blackout、Vignetting 五种模式间切换。
- UI Premium Blur Shader 和材质控制组件编译通过，参数范围与本体 ParsedForm 对齐。
- 示例场景的直接相机渲染截图已生成。

## 当前限制

- `ResourcesPackage` 的 Blob 使用加密或自定义封装，现有 UnityPy 流程无法直接还原完整 Volume Profile 数值和 Beautify 参数；当前结论使用索引字符串、场景 dump、可解包 Shader 和材质进行交叉验证。
- 本次没有声称逐像素复刻 Beautify 私有实现。对于无法提取的内部曲线、LUT、DOF 核和 Motion Blur 权重，Unity 端使用 URP 14 的等价能力。
- 屏幕扭曲和水面 Sun Glare 已完成技术确认，但属于具体 VFX/水材质路径，没有强行并入相机后处理组件；目标工程已有多份 `T_WaterDistortion` 纹理和 MMN Water Renderer Feature，应在对应水材质与粒子调用点复原。
- UI Premium Blur 的精确 GPU 指令不可从 ParsedForm 恢复，本次是保持参数契约的 Gaussian 等价实现，不声称与本体私有字节码逐像素一致。
- 静态截图不能验证运动模糊的时间域效果；需要在运行态移动相机进行最终观感和性能调参。

## 后续复刻优先级

1. 把 `MMNPremiumBlurRepro` 接入实际 UI 窗口的降采样颜色纹理，按窗口做 Mask 和区域裁切。
2. 把 `MMNScreenEffectsRepro` 接入剧情/登录流程的现有状态机或 Timeline。
3. 在可获得运行时录屏或 RenderDoc 帧捕获后，校准 Bloom 阈值、暗角曲线和 Tone Mapping。
4. 针对 PC/高端移动/低端移动建立三档 Volume 与 Renderer 配置。

## Renderer Feature 统一入口（新增）

当前推荐使用 `Assets/MMN/Runtime/MMNPostProcessingRendererFeature.cs` 作为 URP 后处理的统一配置入口。Renderer Feature Inspector 已集中暴露：

- Volume Stack：Bloom、Vignette、Tonemapping、DOF、Motion Blur 及质量/采样参数；
- Camera Fade/Vignetting 与 Circular、Wave、Wipe、Blackout、Vignetting 屏幕效果；
- Premium Blur 的降采样、迭代、Kernel、Sigma、Mask、Level 区间和注入点；
- 相机类型过滤、是否要求 URP Post Processing、Volume Stack 覆盖开关。

运行时结构为：先覆盖当前相机的 `VolumeManager` stack，再按 DOF/Motion Blur 请求 Depth/Motion 输入；`PremiumBlurPass` 输出全局 `_MMNPremiumBlurTexture` 供 `MMN/Repro/UI Premium Blur` 采样；`CompositePass` 使用 `Assets/MMN/Shaders/Special/MMN_PostProcessingComposite.shader` 合成 Camera Fade 和屏幕转场。

已通过 `Tools/MMN/Post Processing/Install Renderer Features` 安装到三档 Renderer Data：HighFidelity（原有 SSAO/Render Objects + MMN Feature）、Balanced（SSAO + MMN Feature）、Performant（MMN Feature）。安装器会应用 HighFidelity、Balanced、Performant 质量预设，之后可直接在对应 Renderer Data 的 Feature Inspector 中逐项调整。

旧的 `MMNPostProcessingRepro`、`MMNScreenEffectsRepro` 组件保留用于兼容和独立调试，不应与新 Feature 同时启用，否则会重复叠加效果。Premium Blur 当前是依据逆向得到的参数契约实现的等价 Gaussian 路径，不宣称与私有 GPU 字节码逐像素一致。
