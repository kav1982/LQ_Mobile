using MMN.PostProcessing;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace MMN.Editor
{
    public static class MMNPostProcessingRendererFeatureInstaller
    {
        const string CompositeShaderPath = "Assets/MMN/Shaders/Special/MMN_PostProcessingComposite.shader";
        const string BlurShaderPath = "Assets/MMN/Shaders/Special/MMN_PremiumBlurCapture.shader";

        [MenuItem("Tools/MMN/Post Processing/Install Renderer Features")]
        public static void Install()
        {
            var compositeShader = AssetDatabase.LoadAssetAtPath<Shader>(CompositeShaderPath);
            var blurShader = AssetDatabase.LoadAssetAtPath<Shader>(BlurShaderPath);
            if (compositeShader == null || blurShader == null)
            {
                Debug.LogError("[MMN PostProcessing] Required shaders are missing.");
                return;
            }

            Install(
                "Assets/Settings/URP-HighFidelity-Renderer.asset",
                MMNPostProcessingRendererFeature.QualityPreset.HighFidelity,
                compositeShader,
                blurShader);
            Install(
                "Assets/Settings/URP-Balanced-Renderer.asset",
                MMNPostProcessingRendererFeature.QualityPreset.Balanced,
                compositeShader,
                blurShader);
            Install(
                "Assets/Settings/URP-Performant-Renderer.asset",
                MMNPostProcessingRendererFeature.QualityPreset.Performant,
                compositeShader,
                blurShader);

            AssetDatabase.SaveAssets();
            Debug.Log("[MMN PostProcessing] Renderer Features installed for all quality tiers.");
        }

        static void Install(
            string rendererPath,
            MMNPostProcessingRendererFeature.QualityPreset preset,
            Shader compositeShader,
            Shader blurShader)
        {
            var rendererData = AssetDatabase.LoadAssetAtPath<UniversalRendererData>(rendererPath);
            if (rendererData == null)
            {
                Debug.LogError($"[MMN PostProcessing] Renderer Data not found: {rendererPath}");
                return;
            }

            MMNPostProcessingRendererFeature feature = null;
            foreach (var rendererFeature in rendererData.rendererFeatures)
            {
                if (rendererFeature is MMNPostProcessingRendererFeature existing)
                {
                    feature = existing;
                    break;
                }
            }

            if (feature == null)
            {
                feature = ScriptableObject.CreateInstance<MMNPostProcessingRendererFeature>();
                feature.name = "MMN Post Processing";
                feature.ApplyQualityPreset(preset);
                AssetDatabase.AddObjectToAsset(feature, rendererData);
                rendererData.rendererFeatures.Add(feature);
            }

            feature.ConfigureShaders(compositeShader, blurShader);
            feature.SetActive(true);
            EditorUtility.SetDirty(feature);
            rendererData.SetDirty();
            EditorUtility.SetDirty(rendererData);
        }
    }
}
