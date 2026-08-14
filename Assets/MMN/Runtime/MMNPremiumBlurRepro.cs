using UnityEngine;
using UnityEngine.UI;

namespace MMN.PostProcessing
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public sealed class MMNPremiumBlurRepro : MonoBehaviour
    {
        [Range(1, 28)] public int kernelSize = 4;
        [Range(1f, 16f)] public float sampleSpacing = 4f;
        [Range(0.001f, 10f)] public float sigma = 2f;
        [Range(0f, 1f)] public float levelFrom;
        [Range(0f, 1f)] public float levelTo = 0.5f;
        public Texture maskTexture;
        public Shader premiumBlurShader;

        Graphic _graphic;
        Material _material;
        Material _previousMaterial;

        static readonly int MaskTexId = Shader.PropertyToID("_MaskTex");
        static readonly int KernelSizeId = Shader.PropertyToID("_KernelSize");
        static readonly int SampleSpacingId = Shader.PropertyToID("_SampleSpacing");
        static readonly int SigmaId = Shader.PropertyToID("_Sigma");
        static readonly int LevelFromId = Shader.PropertyToID("_LevelFrom");
        static readonly int LevelToId = Shader.PropertyToID("_LevelTo");
        static readonly int BlendSrcId = Shader.PropertyToID("_BlendSrc");
        static readonly int BlendDstId = Shader.PropertyToID("_BlendDst");

        void OnEnable()
        {
            Apply();
        }

        void OnDisable()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall -= ApplyAfterValidate;
#endif
            RestoreMaterial();
        }

        void OnValidate()
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                UnityEditor.EditorApplication.delayCall -= ApplyAfterValidate;
                UnityEditor.EditorApplication.delayCall += ApplyAfterValidate;
                return;
            }
#endif
            if (isActiveAndEnabled) Apply();
        }

#if UNITY_EDITOR
        void ApplyAfterValidate()
        {
            UnityEditor.EditorApplication.delayCall -= ApplyAfterValidate;
            if (this != null && isActiveAndEnabled) Apply();
        }
#endif

        public void Apply()
        {
            EnsureMaterial();
            if (_material == null) return;

            _material.SetTexture(MaskTexId, maskTexture != null ? maskTexture : Texture2D.whiteTexture);
            _material.SetFloat(KernelSizeId, kernelSize);
            _material.SetFloat(SampleSpacingId, sampleSpacing);
            _material.SetFloat(SigmaId, sigma);
            _material.SetFloat(LevelFromId, levelFrom);
            _material.SetFloat(LevelToId, levelTo);
            _material.SetFloat(BlendSrcId, (float)UnityEngine.Rendering.BlendMode.One);
            _material.SetFloat(BlendDstId, (float)UnityEngine.Rendering.BlendMode.Zero);
        }

        void EnsureMaterial()
        {
            if (_graphic == null) _graphic = GetComponent<Graphic>();
            if (_graphic == null) return;
            if (_material != null) return;

            var shader = premiumBlurShader != null
                ? premiumBlurShader
                : Shader.Find("MMN/Repro/UI Premium Blur");
            if (shader == null) return;

            _previousMaterial = _graphic.material;
            _material = new Material(shader)
            {
                name = "MMN UI Premium Blur Runtime",
                hideFlags = HideFlags.HideAndDontSave,
            };
            _graphic.material = _material;
        }

        void RestoreMaterial()
        {
            if (_graphic != null && _graphic.material == _material)
                _graphic.material = _previousMaterial;

            if (_material != null)
            {
                if (Application.isPlaying) Destroy(_material);
                else DestroyImmediate(_material);
                _material = null;
            }
        }
    }
}
