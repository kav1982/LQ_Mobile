# Human/Infant 角色资源

资源来自游戏原始 Unity AssetBundle，保留 Mesh、骨骼、BlendShape、Avatar、材质参数、贴图和面部 AnimationClip。

- `Source/`：按原始路径整理的 AssetRipper 原生导出资源。
- `Generated/InfantCharacterCatalog.asset`：按身体、脸型、眼型、发型和时装分类的总目录，并记录 `Shared/Female/Male` 性别归属。
- `Reconstructed/Female/`：女性 Infant 示例的 Prefab、材质、场景和预览。
- `Reconstructed/Male/`：男性 Infant 示例的 Prefab、材质、场景和预览。
- `Reconstructed/Prefabs/`、`Reconstructed/Scenes/`：女性兼容入口，暂时保留。

重新生成示例：`Tools/Characters/Infant/Build Reconstructed Sample`。

原游戏的 Magica Cloth 等自定义脚本程序集未包含在资源包中，因此相关组件可能显示为 Missing Script；蒙皮、骨骼和静态预览不受影响。
