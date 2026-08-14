using UnityEngine;
using UnityEngine.UI;

namespace MMN.PostProcessing
{
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public sealed class MMNScreenEffectsRepro : MonoBehaviour
    {
        public enum EffectMode
        {
            Circular,
            Wave,
            Wipe,
            Blackout,
            Vignetting,
        }

        public EffectMode effectMode;
        [Range(0f, 1f)] public float transitionProgress;
        public bool inverse;
        public Color effectColor = Color.black;
        [Range(0.001f, 0.2f)] public float softness = 0.02f;
        [Range(0f, 0.25f)] public float waveAmplitude = 0.04f;
        [Range(1f, 32f)] public float waveFrequency = 12f;
        [Range(0f, 1f)] public float vignettingRange = 0.567f;
        [Range(0.001f, 1f)] public float vignettingSmoothness = 0.18f;
        public Shader screenEffectsShader;

        Canvas _canvas;
        Image _image;
        Material _material;

        static readonly int EffectModeId = Shader.PropertyToID("_EffectMode");
        static readonly int TransitionProgressId = Shader.PropertyToID("_TransitionProgress");
        static readonly int InverseId = Shader.PropertyToID("_Inverse");
        static readonly int ColorId = Shader.PropertyToID("_Color");
        static readonly int SoftnessId = Shader.PropertyToID("_Softness");
        static readonly int WaveAmplitudeId = Shader.PropertyToID("_WaveAmplitude");
        static readonly int WaveFrequencyId = Shader.PropertyToID("_WaveFrequency");
        static readonly int VignettingRangeId = Shader.PropertyToID("_VignettingRange");
        static readonly int VignettingSmoothId = Shader.PropertyToID("_VignettingSmooth");

        void OnEnable()
        {
            Apply();
        }

        void OnDisable()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall -= ApplyAfterValidate;
#endif
            DestroyResources();
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
            EnsureResources();
            if (_material == null) return;

            _material.SetFloat(EffectModeId, (float)effectMode);
            _material.SetFloat(TransitionProgressId, transitionProgress);
            _material.SetFloat(InverseId, inverse ? -1f : 1f);
            _material.SetColor(ColorId, effectColor);
            _material.SetFloat(SoftnessId, softness);
            _material.SetFloat(WaveAmplitudeId, waveAmplitude);
            _material.SetFloat(WaveFrequencyId, waveFrequency);
            _material.SetFloat(VignettingRangeId, vignettingRange);
            _material.SetFloat(VignettingSmoothId, vignettingSmoothness);
        }

        void EnsureResources()
        {
            if (_canvas == null)
            {
                var canvasObject = new GameObject("MMN Screen Transition Overlay");
                canvasObject.transform.SetParent(transform, false);
                canvasObject.hideFlags = HideFlags.HideAndDontSave;

                _canvas = canvasObject.AddComponent<Canvas>();
                _canvas.renderMode = RenderMode.ScreenSpaceOverlay;
                _canvas.sortingOrder = short.MaxValue - 1;

                _image = canvasObject.AddComponent<Image>();
                _image.raycastTarget = false;
                var rect = _image.rectTransform;
                rect.anchorMin = Vector2.zero;
                rect.anchorMax = Vector2.one;
                rect.offsetMin = Vector2.zero;
                rect.offsetMax = Vector2.zero;
            }

            if (_material != null) return;
            var shader = screenEffectsShader != null
                ? screenEffectsShader
                : Shader.Find("MMN/Repro/UI Screen Effects");
            if (shader == null) return;

            _material = new Material(shader)
            {
                name = "MMN Screen Effects Runtime",
                hideFlags = HideFlags.HideAndDontSave,
            };
            _image.material = _material;
        }

        void DestroyResources()
        {
            if (_material != null)
            {
                if (Application.isPlaying) Destroy(_material);
                else DestroyImmediate(_material);
                _material = null;
            }

            if (_canvas != null)
            {
                if (Application.isPlaying) Destroy(_canvas.gameObject);
                else DestroyImmediate(_canvas.gameObject);
                _canvas = null;
                _image = null;
            }
        }
    }
}
