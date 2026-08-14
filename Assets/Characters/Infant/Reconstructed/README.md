# Infant 当前示例角色重建

本目录是 `Infant_Cute_01` 当前阶段的材质与 Shader 重建结果。源资源保留在 `Source/`，分类总目录保留在 `Generated/InfantCharacterCatalog.asset`。

## 生成内容

- `Prefabs/Infant_Cute_01_Reconstructed.prefab`
- `Scenes/InfantCharacterReconstructed.unity`
- `Materials/`：按源材质 GUID 独立生成的材质。
- `Shaders/`：按源 Shader 家族拆分为 Standard、SkinBody、SkinFace、EyePupil、EyeBase、EyeEmotion、EyeShadeHighlight、HairShadow、SimpleLit。
- `Previews/Infant_Cute_01_Reconstructed_WithMouth.png`：Game View 最终预览。
- `Previews/Infant_Cute_01_Reconstructed_WithMouth_SceneView.png`：Scene View 面部近景。

## 重新生成

在 Unity 菜单执行：`Tools/Characters/Infant/Build Reconstructed Sample`。

生成器会复制源材质中目标 Shader 已声明的贴图、贴图缩放、偏移、颜色、向量和浮点属性，不复用原 Shader，也不强制继承源材质的 `renderQueue=2000`。

普通预览默认关闭 `Mesh_EyeBasePlane`（表情眼）以及 `Mesh_BP_*` / `Mesh_SP_*` 辅助网格；表情眼材质仍会生成，可单独启用验证。

## 眼睛重建要点

- 瞳孔使用源 `2×2` 图集，`_BaseMapAtlasSize=(2,2,1,0)` 选择第一格。
- 表情眼使用 `4×8` 图集，并分别计算左右眼格子；左右眼网格使用 `Cull Off`。
- `Eye_ShadeHighlight_Sample.png` 的 Alpha 恒为 1，红通道才是遮罩覆盖率；`EyeShadeHighlight` 使用红通道叠加，避免整只眼睛变黑。

## 嘴巴重建要点

- Head Prefab 的源材质没有固定 `_MouthMap`；当前示例默认选择 `Infant_Lips_00.png`。
- `SkinFace` 使用独立 Forward Pass，在脸部染色解码后合成基础嘴型或 `4×8` 表情嘴图集。
- 嘴型贴图使用头部网格的第二套 UV（UV1 / `TEXCOORD1`）；UV1 为 `(0,0)` 的非嘴部区域不参与采样，越界坐标使用 Clamp，避免嘴型重复出现在额头或脸侧。
- `_MouthMapScalePosition` 按源材质参数调整尺寸和位置。
