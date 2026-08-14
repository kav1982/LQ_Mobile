using UnityEngine;

namespace MMN.PostProcessing
{
    /// <summary>
    /// Runtime overrides for event-driven screen effects. Renderer Feature values remain
    /// the defaults; gameplay and Timeline code can temporarily override them here.
    /// </summary>
    public static class MMNPostProcessingRuntime
    {
        internal struct ScreenEffectOverride
        {
            public MMNPostProcessingRendererFeature.ScreenEffectMode mode;
            public float progress;
            public bool inverse;
            public Color color;
            public float softness;
            public float waveAmplitude;
            public float waveFrequency;
            public float vignettingRange;
            public float vignettingSmoothness;
        }

        internal struct CameraFadeOverride
        {
            public MMNPostProcessingRendererFeature.CameraFadeMode mode;
            public Color color;
            public float vignettingRange;
            public float vignettingSmoothness;
            public float colorIntensity;
            public float alphaIntensity;
        }

        static bool _hasScreenEffectOverride;
        static bool _hasCameraFadeOverride;
        static ScreenEffectOverride _screenEffectOverride;
        static CameraFadeOverride _cameraFadeOverride;

        public static void SetScreenEffect(
            MMNPostProcessingRendererFeature.ScreenEffectMode mode,
            float progress,
            bool inverse = false,
            Color? color = null,
            float softness = 0.02f,
            float waveAmplitude = 0.04f,
            float waveFrequency = 12f,
            float vignettingRange = 0.567f,
            float vignettingSmoothness = 0.18f)
        {
            _screenEffectOverride = new ScreenEffectOverride
            {
                mode = mode,
                progress = Mathf.Clamp01(progress),
                inverse = inverse,
                color = color ?? Color.black,
                softness = Mathf.Clamp(softness, 0.001f, 0.2f),
                waveAmplitude = Mathf.Clamp(waveAmplitude, 0f, 0.25f),
                waveFrequency = Mathf.Clamp(waveFrequency, 1f, 32f),
                vignettingRange = Mathf.Clamp01(vignettingRange),
                vignettingSmoothness = Mathf.Clamp(vignettingSmoothness, 0.001f, 1f),
            };
            _hasScreenEffectOverride = true;
        }

        public static void ClearScreenEffect()
        {
            _hasScreenEffectOverride = false;
        }

        public static void SetCameraFade(
            MMNPostProcessingRendererFeature.CameraFadeMode mode,
            Color color,
            float vignettingRange = 0.567f,
            float vignettingSmoothness = 0.18f,
            float colorIntensity = 1f,
            float alphaIntensity = 1f)
        {
            _cameraFadeOverride = new CameraFadeOverride
            {
                mode = mode,
                color = color,
                vignettingRange = Mathf.Clamp01(vignettingRange),
                vignettingSmoothness = Mathf.Clamp(vignettingSmoothness, 0.001f, 1f),
                colorIntensity = Mathf.Max(0f, colorIntensity),
                alphaIntensity = Mathf.Max(0f, alphaIntensity),
            };
            _hasCameraFadeOverride = true;
        }

        public static void ClearCameraFade()
        {
            _hasCameraFadeOverride = false;
        }

        internal static bool TryGetScreenEffect(out ScreenEffectOverride value)
        {
            value = _screenEffectOverride;
            return _hasScreenEffectOverride;
        }

        internal static bool TryGetCameraFade(out CameraFadeOverride value)
        {
            value = _cameraFadeOverride;
            return _hasCameraFadeOverride;
        }
    }
}
