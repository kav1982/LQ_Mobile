# MMN Shader Contract Extensions

`Original/` 下的契约由 `appdata/_re_work/dump_shader_contracts.py` 自动生成，禁止手改。

本目录只登记项目有意增加的内容，例如 URP 必需的 `ShadowCaster` / `DepthOnly` Pass，或仍被导入器消费的 Legacy 属性。每个 shader 使用与 Original 契约相同的文件名 stem：

```json
{
  "shader": "MMN/BG/Example",
  "propertyExtensions": [
    {
      "name": "_LegacyProperty",
      "reason": "兼容已提取材质中的历史字段。",
      "consumer": "DungeonPackImporter.CreateMaterial"
    }
  ],
  "passExtensions": [
    {
      "name": "DepthOnly",
      "reason": "URP 深度纹理需要。",
      "consumer": "Universal Render Pipeline"
    }
  ]
}
```

扩展不得覆盖原版同名属性或 Pass；若必须偏离原版渲染状态，需要在对应 shader 顶部和验收报告中明确说明。
