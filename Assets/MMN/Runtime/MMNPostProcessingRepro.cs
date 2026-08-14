using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.UI;

namespace MMN.PostProcessing
{
    /// <summary>
    /// Reproduces the post-processing stack observed in the shipped game.
    ///
    /// The game combines a Beautify/Volume-style stack (Bloom, tone mapping, vignette,
    /// optional DOF and motion blur) with a separate full-screen CameraFade/Vignetting
    /// material. This component keeps those two paths separate so the parameters can be
    /// compared independently during reverse-engineering.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public sealed class MMNPostProcessingRepro : MonoBehaviour
    {
        [Header("URP Volume stack")]
        public bool enableVolumeStack = true;
        public bool enableDepthOfField;
        public bool enableMotionBlur;
        [Range(0f, 5f)] public float bloomIntensity = 1f;
        [Range(0f, 1f)] public float bloomThreshold = 1f;
        [Range(0f, 1f)] public float bloomScatter = 0.7f;
        [Range(0f, 1f)] public float vignetteIntensity = 0.25f;
        [Range(0.01f, 1f)] public float vignetteSmoothness = 0.4f;
        [Range(0f, 10f)] public float depthOfFieldFocusDistance = 10f;
        [Range(0f, 1f)] public float motionBlurIntensity = 0.2f;

        [Header("CameraFade & Vignetting overlay")]
        public bool enableScreenOverlay = true;
        public bool overlayVignetting = true;
        [Range(0f, 1f)] public float overlayRange = 0.567f;
        [Range(0f, 1f)] public float overlaySmoothness = 0.18f;
        [Range(0f, 1f)] public float overlayAlpha = 0.702f;
        public Color overlayColor = Color.black;
        public Shader overlayShader;

        Volume _volume;
        VolumeProfile _runtimeProfile;
        Canvas _overlayCanvas;
        Image _overlayImage;
        Material _overlayMaterial;
        VolumeProfile _previousProfile;

        static readonly int ScreenFxModeId = Shader.PropertyToID("_ScreenFXMode");
        static readonly int VignettingRangeId = Shader.PropertyToID("_VignettingRange");
        static readonly int VignettingSmoothId = Shader.PropertyToID("_VignettingSmooth");
        static readonly int ColorId = Shader.PropertyToID("_Color");
        static readonly int IntensityColorId = Shader.PropertyToID("_Intensity_Color");
        static readonly int IntensityAlphaId = Shader.PropertyToID("_Intensity_Alpha");

        void OnEnable()
        {
            Apply();
        }

        void OnDisable()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall -= ApplyAfterValidate;
#endif
            RestoreVolume();
            DestroyOverlay();
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
            EnsureCameraPostProcessing();
            if (enableVolumeStack) EnsureVolume();
            else RestoreVolume();
            if (enableScreenOverlay) EnsureOverlay();
            else DestroyOverlay();
            ApplyOverlayProperties();
        }

        void EnsureCameraPostProcessing()
        {
            var camera = GetComponent<Camera>();
            if (camera == null) camera = Camera.main;
            if (camera == null) return;

            var data = camera.GetComponent<UniversalAdditionalCameraData>();
            if (data == null) data = camera.gameObject.AddComponent<UniversalAdditionalCameraData>();
            data.renderPostProcessing = true;
            data.requiresDepthTexture = enableDepthOfField || enableMotionBlur;
            camera.allowHDR = true;
        }

        void EnsureVolume()
        {
            if (_volume == null)
            {
                _volume = GetComponent<Volume>();
                if (_volume == null) _volume = gameObject.AddComponent<Volume>();
                _previousProfile = _volume.sharedProfile;
                _volume.isGlobal = true;
                _volume.priority = 100f;
                _volume.weight = 1f;
            }

            if (_runtimeProfile == null)
            {
                _runtimeProfile = ScriptableObject.CreateInstance<VolumeProfile>();
                _runtimeProfile.name = "MMN_PostProcessing_Repro_Runtime";
                _runtimeProfile.hideFlags = HideFlags.HideAndDontSave;
                _volume.sharedProfile = _runtimeProfile;
            }

            var bloom = GetOrAdd<Bloom>(_runtimeProfile);
            bloom.active = true;
            bloom.threshold.overrideState = true;
            bloom.threshold.value = bloomThreshold;
            bloom.intensity.overrideState = true;
            bloom.intensity.value = bloomIntensity;
            bloom.scatter.overrideState = true;
            bloom.scatter.value = bloomScatter;
            bloom.maxIterations.overrideState = true;
            bloom.maxIterations.value = 6;

            var vignette = GetOrAdd<Vignette>(_runtimeProfile);
            vignette.active = true;
            vignette.intensity.overrideState = true;
            vignette.intensity.value = vignetteIntensity;
            vignette.smoothness.overrideState = true;
            vignette.smoothness.value = vignetteSmoothness;

            var tonemapping = GetOrAdd<Tonemapping>(_runtimeProfile);
            tonemapping.active = true;
            tonemapping.mode.overrideState = true;
            tonemapping.mode.value = TonemappingMode.Neutral;

            var dof = GetOrAdd<DepthOfField>(_runtimeProfile);
            dof.active = enableDepthOfField;
            dof.mode.overrideState = true;
            dof.mode.value = DepthOfFieldMode.Gaussian;
            dof.focusDistance.overrideState = true;
            dof.focusDistance.value = depthOfFieldFocusDistance;
            dof.gaussianStart.overrideState = true;
            dof.gaussianStart.value = Mathf.Max(0.1f, depthOfFieldFocusDistance * 0.5f);
            dof.gaussianEnd.overrideState = true;
            dof.gaussianEnd.value = depthOfFieldFocusDistance * 2f;
            dof.gaussianMaxRadius.overrideState = true;
            dof.gaussianMaxRadius.value = 1f;

            var motionBlur = GetOrAdd<MotionBlur>(_runtimeProfile);
            motionBlur.active = enableMotionBlur;
            motionBlur.mode.overrideState = true;
            motionBlur.mode.value = MotionBlurMode.CameraOnly;
            motionBlur.intensity.overrideState = true;
            motionBlur.intensity.value = motionBlurIntensity;
            motionBlur.quality.overrideState = true;
            motionBlur.quality.value = MotionBlurQuality.Medium;
        }

        void RestoreVolume()
        {
            if (_volume != null && _volume.sharedProfile == _runtimeProfile)
                _volume.sharedProfile = _previousProfile;
            if (_runtimeProfile != null)
            {
                if (Application.isPlaying) Destroy(_runtimeProfile);
                else DestroyImmediate(_runtimeProfile);
                _runtimeProfile = null;
            }
        }

        static T GetOrAdd<T>(VolumeProfile profile) where T : VolumeComponent
        {
            if (profile.TryGet(out T component)) return component;
            return profile.Add<T>(true);
        }

        void EnsureOverlay()
        {
            if (_overlayCanvas == null)
            {
                var canvasObject = new GameObject("MMN CameraFade Vignetting Overlay");
                canvasObject.transform.SetParent(transform, false);
                canvasObject.hideFlags = HideFlags.HideAndDontSave;
                _overlayCanvas = canvasObject.AddComponent<Canvas>();
                _overlayCanvas.renderMode = RenderMode.ScreenSpaceOverlay;
                _overlayCanvas.sortingOrder = short.MaxValue;
                _overlayCanvas.pixelPerfect = false;

                _overlayImage = canvasObject.AddComponent<Image>();
                _overlayImage.raycastTarget = false;
                var rect = _overlayImage.rectTransform;
                rect.anchorMin = Vector2.zero;
                rect.anchorMax = Vector2.one;
                rect.offsetMin = Vector2.zero;
                rect.offsetMax = Vector2.zero;
            }

            if (_overlayMaterial == null)
            {
                var shader = overlayShader != null
                    ? overlayShader
                    : Shader.Find("MMN/Repro/CameraFade & Vignetting");
                if (shader == null) return;
                _overlayMaterial = new Material(shader)
                {
                    name = "MMN CameraFade Vignetting Runtime",
                    hideFlags = HideFlags.HideAndDontSave,
                };
                _overlayImage.material = _overlayMaterial;
            }
        }

        void ApplyOverlayProperties()
        {
            if (_overlayMaterial == null) return;
            _overlayMaterial.SetFloat(ScreenFxModeId, overlayVignetting ? 1f : 0f);
            _overlayMaterial.SetFloat(VignettingRangeId, overlayRange);
            _overlayMaterial.SetFloat(VignettingSmoothId, overlaySmoothness);
            _overlayMaterial.SetColor(ColorId, new Color(overlayColor.r, overlayColor.g, overlayColor.b, overlayAlpha));
            _overlayMaterial.SetFloat(IntensityColorId, 1f);
            _overlayMaterial.SetFloat(IntensityAlphaId, 1f);
            if (_overlayImage != null) _overlayImage.enabled = enableScreenOverlay;
        }

        void DestroyOverlay()
        {
            if (_overlayMaterial != null)
            {
                if (Application.isPlaying) Destroy(_overlayMaterial);
                else DestroyImmediate(_overlayMaterial);
                _overlayMaterial = null;
            }
            if (_overlayCanvas != null)
            {
                if (Application.isPlaying) Destroy(_overlayCanvas.gameObject);
                else DestroyImmediate(_overlayCanvas.gameObject);
                _overlayCanvas = null;
                _overlayImage = null;
            }
        }
    }
}
