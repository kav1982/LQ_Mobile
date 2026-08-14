# Human/Infant 角色资源

资源来自游戏原始 Unity AssetBundle，保留原始 Mesh、骨骼、BlendShape、Avatar、材质参数、贴图和面部 AnimationClip。

- `Source/`：按原始路径整理的 AssetRipper 原生导出资源。
- `Generated/InfantCharacterCatalog.asset`：按身体、脸型、眼型、发型和时装分类的总目录，供后续批量导出使用。
- `Reconstructed/`：当前示例角色的 Shader、材质、Prefab、预览场景和最终截图。
- `Reconstructed/Prefabs/Infant_Cute_01_Reconstructed.prefab`：双马尾和幼儿园套装的当前组合示例。
- `Reconstructed/Scenes/InfantCharacterReconstructed.unity`：当前材质还原预览场景。
- `Reconstructed/Previews/`：Game View 与 Scene View 的最终验证截图。

重新生成当前示例：`Tools/Characters/Infant/Build Reconstructed Sample`。

原游戏的 Magica Cloth 等自定义脚本程序集未包含在资源包中，因此相关组件可能显示为 Missing Script；蒙皮、骨骼和静态预览不受影响。
