using UnityEngine;
using UnityEngine.Rendering;

namespace Characters.Infant
{
    public static class InfantPreviewMaterialUtility
    {
        static readonly string[] BaseTextureProperties =
        {
            "_BaseMap",
            "_MainTex",
            "_BaseTex",
        };

        public static void CopyProperties(Material source, Material destination)
        {
            string shaderName = source.shader != null ? source.shader.name : string.Empty;
            string textureProperty = FindTextureProperty(source, shaderName);
            Texture texture = textureProperty != null ? source.GetTexture(textureProperty) : null;

            Color baseColor = GetBaseColor(source, shaderName);
            bool isDyeMap = texture != null &&
                            source.HasProperty("_IsDyable") &&
                            source.GetFloat("_IsDyable") > 0.5f;
            bool isSolidColor = texture == null || shaderName == "MMN/CH/Eye_Base";
            float materialMode = isDyeMap ? 0f : isSolidColor ? 2f : 1f;
            float alpha = GetFloat(source, "_AlphaOverride", GetFloat(source, "_Alpha", 1f));
            bool isEye = shaderName.StartsWith("MMN/CH/Eye_");
            bool isTransparent = alpha * baseColor.a < 0.999f ||
                                 isEye ||
                                 shaderName == "MMN/CH/Hair_Shadow";

            destination.SetTexture("_BaseMap", texture);
            if (textureProperty != null)
            {
                destination.SetTextureScale("_BaseMap", source.GetTextureScale(textureProperty));
                destination.SetTextureOffset("_BaseMap", source.GetTextureOffset(textureProperty));
            }
            destination.SetColor("_BaseColor", baseColor);
            destination.SetColor("_DyeColor1", GetColor(source, "_DyeColor1", Color.white));
            destination.SetColor("_DyeColor2", GetColor(source, "_DyeColor2", Color.white));
            destination.SetColor("_DyeColor3", GetColor(source, "_DyeColor3", Color.white));
            destination.SetFloat("_MaterialMode", materialMode);
            destination.SetFloat("_HasBaseMap", texture != null ? 1f : 0f);
            destination.SetFloat("_AlphaOverride", alpha);
            destination.SetFloat("_Cutoff", GetFloat(source, "_Cutoff", 0.05f));
            destination.SetFloat("_Unlit", isEye || shaderName == "MMN/CH/Hair_Shadow" ? 1f : 0f);
            destination.SetFloat("_Cull", GetFloat(source, "_CullType", (float)CullMode.Back));

            ConfigureRenderState(destination, isTransparent);
        }

        static string FindTextureProperty(Material source, string shaderName)
        {
            if (shaderName == "MMN/CH/Eye_Emotion" && HasTexture(source, "_EyeballTexture"))
                return "_EyeballTexture";

            foreach (string property in BaseTextureProperties)
            {
                if (HasTexture(source, property)) return property;
            }
            return null;
        }

        static bool HasTexture(Material material, string property)
        {
            return material.HasProperty(property) && material.GetTexture(property) != null;
        }

        static Color GetBaseColor(Material source, string shaderName)
        {
            if (shaderName == "MMN/CH/Eye_Base") return Color.white;
            if (shaderName == "MMN/CH/Eye_Shade_Highlight")
                return GetColor(source, "_ShadeColor", Color.white);
            if (source.HasProperty("_BaseColor")) return source.GetColor("_BaseColor");
            if (source.HasProperty("_Color")) return source.GetColor("_Color");
            if (source.HasProperty("_TintColor")) return source.GetColor("_TintColor");
            return Color.white;
        }

        static Color GetColor(Material source, string property, Color fallback)
        {
            return source.HasProperty(property) ? source.GetColor(property) : fallback;
        }

        static float GetFloat(Material source, string property, float fallback)
        {
            return source.HasProperty(property) ? source.GetFloat(property) : fallback;
        }

        static void ConfigureRenderState(Material material, bool isTransparent)
        {
            material.SetFloat("_SrcBlend", (float)(isTransparent ? BlendMode.SrcAlpha : BlendMode.One));
            material.SetFloat("_DstBlend", (float)(isTransparent ? BlendMode.OneMinusSrcAlpha : BlendMode.Zero));
            material.SetFloat("_ZWrite", isTransparent ? 0f : 1f);
            material.renderQueue = isTransparent ? (int)RenderQueue.Transparent : (int)RenderQueue.AlphaTest;
            material.SetOverrideTag("RenderType", isTransparent ? "Transparent" : "TransparentCutout");
        }
    }
}
