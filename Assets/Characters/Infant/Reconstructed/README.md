# Infant 示例角色重建

本目录保存 Infant 女性/男性示例角色的材质与 Shader 重建结果。源资源保留在 `Source/`，分类总目录保留在 `Generated/InfantCharacterCatalog.asset`。

## 生成内容

- `Female/Prefabs/Infant_Cute_01_Female_Reconstructed.prefab`
- `Female/Scenes/InfantFemaleReconstructed.unity`
- `Male/Prefabs/Infant_Cute_01_Male_Reconstructed.prefab`
- `Male/Prefabs/Outfits/`：`ChristmasOutfit`、`PiratesEpicA`、`Sanrio01` 三套男性时装变体 Prefab。
- `Male/Scenes/InfantMaleReconstructed.unity`
- `Female/Materials/`、`Male/Materials/`：按源材质 GUID 独立生成的材质。
- 根目录 `Prefabs/Infant_Cute_01_Reconstructed.prefab` 与 `Scenes/InfantCharacterReconstructed.unity`：女性兼容入口，暂时保留。
- `Female/Previews/`、`Male/Previews/`：对应性别的预览截图目录；男性场景并排预览三套时装变体，基础套装保留在主 Prefab 中。
- `Shaders/`：Standard、SkinBody、SkinFace、EyePupil、EyeBase、EyeEmotion、EyeShadeHighlight、HairShadow、SimpleLit。

## 重建

在 Unity 菜单执行：`Tools/Characters/Infant/Build Reconstructed Sample`。

该命令会同时生成 Female、Male 和根目录女性兼容入口。男性示例使用 `InfantMale_Body_00`、共享默认头部、默认眼型、`Infant_Hair_Dandy_00` 与 `Infant_Kindergarten_M_OnePiece_00`，并额外生成 Christmas、Pirates Epic A、Sanrio 三套时装；眼球材质会切换到 `Infant_EyeBall_M_00_DyeMap.png`。

普通预览默认隐藏 `Mesh_EyeBasePlane`、`Mesh_BP_*` 和 `Mesh_SP_*` 辅助网格；嘴巴采样使用头部网格 UV1，并由 `SkinFace` Shader 合成。
