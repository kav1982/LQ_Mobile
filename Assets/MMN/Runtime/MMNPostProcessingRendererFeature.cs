using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace MMN.PostProcessing
{
    public sealed class MMNPostProcessingRendererFeature : ScriptableRendererFeature
    {
        public enum QualityPreset
        {
            HighFidelity,
            Balanced,
            Performant,
        }

        public enum CameraFadeMode
        {
            Fade,
            Vignetting,
        }

        public enum ScreenEffectMode
        {
            Circular,
            Wave,
            Wipe,
            Blackout,
            Vignetting,
        }

        [Serializable]
        public sealed class CameraFilterSettings
        {
            public bool gameCameras = true;
            public bool sceneView = true;
            public bool previewCameras;
            public bool overlayCameras;
            [Tooltip("URP Camera 必须开启 Post Processing，原生 Bloom/DOF/Motion Blur 才会执行。")]
            public bool requirePostProcessing = true;
        }

        [Serializable]
        public sealed class BloomSettings
        {
            public bool enabled = true;
            [Min(0f)] public float threshold = 1f;
            [Min(0f)] public float intensity = 1f;
            [Range(0f, 1f)] public float scatter = 0.7f;
            [Min(0f)] public float clamp = 65472f;
            public Color tint = Color.white;
            public bool highQualityFiltering;
            public BloomDownscaleMode downscale = BloomDownscaleMode.Half;
            [Range(2, 8)] public int maxIterations = 6;
            public Texture dirtTexture;
            [Min(0f)] public float dirtIntensity;
        }

        [Serializable]
        public sealed class VignetteSettings
        {
            public bool enabled = true;
            public Color color = Color.black;
            public Vector2 center = new Vector2(0.5f, 0.5f);
            [Range(0f, 1f)] public float intensity = 0.25f;
            [Range(0.01f, 1f)] public float smoothness = 0.4f;
            public bool rounded;
        }

        [Serializable]
        public sealed class TonemappingSettings
        {
            public bool enabled = true;
            public TonemappingMode mode = TonemappingMode.Neutral;
        }

        [Serializable]
        public sealed class DepthOfFieldSettings
        {
            public bool enabled;
            public DepthOfFieldMode mode = DepthOfFieldMode.Gaussian;
            [Min(0f)] public float focusDistance = 10f;
            [Min(0f)] public float gaussianStart = 5f;
            [Min(0f)] public float gaussianEnd = 20f;
            [Range(0.5f, 1.5f)] public float gaussianMaxRadius = 1f;
            public bool highQualitySampling;
            [Range(1f, 32f)] public float aperture = 5.6f;
            [Range(1f, 300f)] public float focalLength = 50f;
            [Range(3, 9)] public int bladeCount = 5;
            [Range(0f, 1f)] public float bladeCurvature = 1f;
            [Range(-180f, 180f)] public float bladeRotation;
        }

        [Serializable]
        public sealed class MotionBlurSettings
        {
            public bool enabled;
            public MotionBlurMode mode = MotionBlurMode.CameraOnly;
            public MotionBlurQuality quality = MotionBlurQuality.Medium;
            [Range(0f, 1f)] public float intensity = 0.2f;
            [Range(0.05f, 0.2f)] public float clamp = 0.05f;
        }

        [Serializable]
        public sealed class VolumeStackSettings
        {
            [Tooltip("开启后，本 Feature 的数值覆盖相机当前 Volume Stack 中对应效果。")]
            public bool overrideVolumeStack = true;
            public BloomSettings bloom = new BloomSettings();
            public VignetteSettings vignette = new VignetteSettings();
            public TonemappingSettings tonemapping = new TonemappingSettings();
            public DepthOfFieldSettings depthOfField = new DepthOfFieldSettings();
            public MotionBlurSettings motionBlur = new MotionBlurSettings();
        }

        [Serializable]
        public sealed class CameraFadeSettings
        {
            public bool enabled = true;
            public CameraFadeMode mode = CameraFadeMode.Vignetting;
            public Color color = new Color(0f, 0f, 0f, 0.702f);
            [Range(0f, 1f)] public float vignettingRange = 0.567f;
            [Range(0.001f, 1f)] public float vignettingSmoothness = 0.18f;
            [Min(0f)] public float colorIntensity = 1f;
            [Min(0f)] public float alphaIntensity = 1f;
        }

        [Serializable]
        public sealed class ScreenEffectSettings
        {
            public bool enabled;
            public ScreenEffectMode mode = ScreenEffectMode.Circular;
            [Range(0f, 1f)] public float progress;
            public bool inverse;
            public Color color = Color.black;
            [Range(0.001f, 0.2f)] public float softness = 0.02f;
            [Range(0f, 0.25f)] public float waveAmplitude = 0.04f;
            [Range(1f, 32f)] public float waveFrequency = 12f;
            [Range(0f, 1f)] public float vignettingRange = 0.567f;
            [Range(0.001f, 1f)] public float vignettingSmoothness = 0.18f;
        }

        [Serializable]
        public sealed class PremiumBlurSettings
        {
            [Tooltip("生成 _MMNPremiumBlurTexture，供 MMN/Repro/UI Premium Blur 使用。")]
            public bool enabled;
            [Range(1, 4)] public int downsample = 2;
            [Range(1, 4)] public int iterations = 2;
            [Range(1, 28)] public int kernelSize = 4;
            [Range(1f, 16f)] public float sampleSpacing = 4f;
            [Range(0.001f, 10f)] public float sigma = 2f;
            public Texture maskTexture;
            [Range(0f, 1f)] public float levelFrom;
            [Range(0f, 1f)] public float levelTo = 0.5f;
            public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
        }

        [Serializable]
        public sealed class CompositeSettings
        {
            public CameraFadeSettings cameraFade = new CameraFadeSettings();
            public ScreenEffectSettings screenEffect = new ScreenEffectSettings();
            public RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
        }

        public CameraFilterSettings cameraFilter = new CameraFilterSettings();
        public VolumeStackSettings volumeStack = new VolumeStackSettings();
        public CompositeSettings fullScreenComposite = new CompositeSettings();
        public PremiumBlurSettings premiumBlur = new PremiumBlurSettings();

        [SerializeField, HideInInspector] Shader compositeShader;
        [SerializeField, HideInInspector] Shader blurShader;

        Material _compositeMaterial;
        Material _blurMaterial;
        RequirementsPass _requirementsPass;
        PremiumBlurPass _premiumBlurPass;
        CompositePass _compositePass;

        static readonly int PremiumBlurAvailableId = Shader.PropertyToID("_MMNPremiumBlurAvailable");

        public override void Create()
        {
            CreateMaterials();
            _requirementsPass = new RequirementsPass();
            _premiumBlurPass = new PremiumBlurPass();
            _compositePass = new CompositePass();
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            if (!ShouldRender(in renderingData))
            {
                Shader.SetGlobalFloat(PremiumBlurAvailableId, 0f);
                return;
            }

            ApplyVolumeStack(ref renderingData);

            if (volumeStack.overrideVolumeStack &&
                (volumeStack.depthOfField.enabled || volumeStack.motionBlur.enabled))
            {
                _requirementsPass.Setup(
                    volumeStack.depthOfField.enabled,
                    volumeStack.motionBlur.enabled);
                renderer.EnqueuePass(_requirementsPass);
            }

            if (premiumBlur.enabled && _blurMaterial != null)
            {
                _premiumBlurPass.Setup(premiumBlur, _blurMaterial);
                renderer.EnqueuePass(_premiumBlurPass);
            }
            else
            {
                Shader.SetGlobalFloat(PremiumBlurAvailableId, 0f);
            }

            if (HasCompositeEffect() && _compositeMaterial != null)
            {
                _compositePass.Setup(fullScreenComposite, _compositeMaterial);
                renderer.EnqueuePass(_compositePass);
            }
        }

        public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
        {
            if (!ShouldRender(in renderingData)) return;
            var source = renderer.cameraColorTargetHandle;
            if (premiumBlur.enabled && _blurMaterial != null)
                _premiumBlurPass.SetSource(source);
            if (HasCompositeEffect() && _compositeMaterial != null)
                _compositePass.SetSource(source);
        }

        protected override void Dispose(bool disposing)
        {
            CoreUtils.Destroy(_compositeMaterial);
            CoreUtils.Destroy(_blurMaterial);
            _compositeMaterial = null;
            _blurMaterial = null;
            _premiumBlurPass?.Dispose();
            _compositePass?.Dispose();
        }

        public void ConfigureShaders(Shader composite, Shader blur)
        {
            compositeShader = composite;
            blurShader = blur;
            CreateMaterials();
        }

        public void ApplyQualityPreset(QualityPreset preset)
        {
            volumeStack.bloom.enabled = true;
            volumeStack.vignette.enabled = true;
            volumeStack.tonemapping.enabled = true;
            volumeStack.depthOfField.enabled = false;
            volumeStack.motionBlur.enabled = false;
            fullScreenComposite.cameraFade.enabled = true;
            fullScreenComposite.screenEffect.enabled = false;

            switch (preset)
            {
                case QualityPreset.HighFidelity:
                    volumeStack.bloom.intensity = 1f;
                    volumeStack.bloom.scatter = 0.7f;
                    volumeStack.bloom.maxIterations = 6;
                    volumeStack.bloom.highQualityFiltering = true;
                    volumeStack.vignette.intensity = 0.25f;
                    premiumBlur.downsample = 2;
                    premiumBlur.iterations = 2;
                    break;
                case QualityPreset.Balanced:
                    volumeStack.bloom.intensity = 0.7f;
                    volumeStack.bloom.scatter = 0.6f;
                    volumeStack.bloom.maxIterations = 4;
                    volumeStack.bloom.highQualityFiltering = false;
                    volumeStack.vignette.intensity = 0.2f;
                    premiumBlur.downsample = 4;
                    premiumBlur.iterations = 1;
                    break;
                case QualityPreset.Performant:
                    volumeStack.bloom.intensity = 0.35f;
                    volumeStack.bloom.scatter = 0.5f;
                    volumeStack.bloom.maxIterations = 3;
                    volumeStack.bloom.highQualityFiltering = false;
                    volumeStack.vignette.intensity = 0.15f;
                    premiumBlur.enabled = false;
                    premiumBlur.downsample = 4;
                    premiumBlur.iterations = 1;
                    break;
            }
        }

        void CreateMaterials()
        {
            if (compositeShader == null)
                compositeShader = Shader.Find("Hidden/MMN/PostProcessingComposite");
            if (blurShader == null)
                blurShader = Shader.Find("Hidden/MMN/PremiumBlurCapture");

            if (_compositeMaterial == null || _compositeMaterial.shader != compositeShader)
            {
                CoreUtils.Destroy(_compositeMaterial);
                if (compositeShader != null)
                    _compositeMaterial = CoreUtils.CreateEngineMaterial(compositeShader);
            }

            if (_blurMaterial == null || _blurMaterial.shader != blurShader)
            {
                CoreUtils.Destroy(_blurMaterial);
                if (blurShader != null)
                    _blurMaterial = CoreUtils.CreateEngineMaterial(blurShader);
            }
        }

        bool ShouldRender(in RenderingData renderingData)
        {
            var cameraData = renderingData.cameraData;
            if (cameraData.isPreviewCamera) return cameraFilter.previewCameras;
            if (cameraData.isSceneViewCamera) return cameraFilter.sceneView;
            if (cameraData.renderType == CameraRenderType.Overlay && !cameraFilter.overlayCameras) return false;
            if (cameraData.cameraType == CameraType.Game && !cameraFilter.gameCameras) return false;
            return true;
        }

        bool HasCompositeEffect()
        {
            if (MMNPostProcessingRuntime.TryGetCameraFade(out _)) return true;
            if (MMNPostProcessingRuntime.TryGetScreenEffect(out _)) return true;
            if (fullScreenComposite.cameraFade.enabled) return true;
            return fullScreenComposite.screenEffect.enabled &&
                   fullScreenComposite.screenEffect.progress > 0f;
        }

        void ApplyVolumeStack(ref RenderingData renderingData)
        {
            if (!volumeStack.overrideVolumeStack) return;
            if (cameraFilter.requirePostProcessing && !renderingData.cameraData.postProcessEnabled) return;

            var stack = VolumeManager.instance.stack;
            if (stack == null) return;

            ApplyBloom(stack.GetComponent<Bloom>());
            ApplyVignette(stack.GetComponent<Vignette>());
            ApplyTonemapping(stack.GetComponent<Tonemapping>());
            ApplyDepthOfField(stack.GetComponent<DepthOfField>());
            ApplyMotionBlur(stack.GetComponent<MotionBlur>());
        }

        void ApplyBloom(Bloom component)
        {
            if (component == null) return;
            var settings = volumeStack.bloom;
            component.active = settings.enabled;
            Override(component.threshold, settings.threshold);
            Override(component.intensity, settings.intensity);
            Override(component.scatter, settings.scatter);
            Override(component.clamp, settings.clamp);
            Override(component.tint, settings.tint);
            Override(component.highQualityFiltering, settings.highQualityFiltering);
            Override(component.downscale, settings.downscale);
            Override(component.maxIterations, settings.maxIterations);
            Override(component.dirtTexture, settings.dirtTexture);
            Override(component.dirtIntensity, settings.dirtIntensity);
        }

        void ApplyVignette(Vignette component)
        {
            if (component == null) return;
            var settings = volumeStack.vignette;
            component.active = settings.enabled;
            Override(component.color, settings.color);
            Override(component.center, settings.center);
            Override(component.intensity, settings.intensity);
            Override(component.smoothness, settings.smoothness);
            Override(component.rounded, settings.rounded);
        }

        void ApplyTonemapping(Tonemapping component)
        {
            if (component == null) return;
            component.active = volumeStack.tonemapping.enabled;
            Override(component.mode, volumeStack.tonemapping.mode);
        }

        void ApplyDepthOfField(DepthOfField component)
        {
            if (component == null) return;
            var settings = volumeStack.depthOfField;
            component.active = settings.enabled;
            Override(component.mode, settings.mode);
            Override(component.focusDistance, settings.focusDistance);
            Override(component.gaussianStart, settings.gaussianStart);
            Override(component.gaussianEnd, Mathf.Max(settings.gaussianStart, settings.gaussianEnd));
            Override(component.gaussianMaxRadius, settings.gaussianMaxRadius);
            Override(component.highQualitySampling, settings.highQualitySampling);
            Override(component.aperture, settings.aperture);
            Override(component.focalLength, settings.focalLength);
            Override(component.bladeCount, settings.bladeCount);
            Override(component.bladeCurvature, settings.bladeCurvature);
            Override(component.bladeRotation, settings.bladeRotation);
        }

        void ApplyMotionBlur(MotionBlur component)
        {
            if (component == null) return;
            var settings = volumeStack.motionBlur;
            component.active = settings.enabled;
            Override(component.mode, settings.mode);
            Override(component.quality, settings.quality);
            Override(component.intensity, settings.intensity);
            Override(component.clamp, settings.clamp);
        }

        static void Override<T>(VolumeParameter<T> parameter, T value)
        {
            parameter.overrideState = true;
            parameter.value = value;
        }

        sealed class RequirementsPass : ScriptableRenderPass
        {
            public RequirementsPass()
            {
                renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;
            }

            public void Setup(bool depthOfField, bool motionBlur)
            {
                var input = ScriptableRenderPassInput.None;
                if (depthOfField || motionBlur) input |= ScriptableRenderPassInput.Depth;
                if (motionBlur) input |= ScriptableRenderPassInput.Motion;
                ConfigureInput(input);
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
            }
        }

        sealed class PremiumBlurPass : ScriptableRenderPass
        {
            static readonly int BlurRadiusId = Shader.PropertyToID("_BlurRadius");
            static readonly int SampleSpacingId = Shader.PropertyToID("_SampleSpacing");
            static readonly int SigmaId = Shader.PropertyToID("_Sigma");
            static readonly int PremiumBlurTextureId = Shader.PropertyToID("_MMNPremiumBlurTexture");
            static readonly int PremiumBlurMaskId = Shader.PropertyToID("_MMNPremiumBlurMaskTexture");
            static readonly int PremiumBlurUseMaskId = Shader.PropertyToID("_MMNPremiumBlurUseMask");
            static readonly int PremiumBlurLevelFromId = Shader.PropertyToID("_MMNPremiumBlurLevelFrom");
            static readonly int PremiumBlurLevelToId = Shader.PropertyToID("_MMNPremiumBlurLevelTo");

            readonly ProfilingSampler _profilingSampler = new ProfilingSampler("MMN Premium Blur");
            PremiumBlurSettings _settings;
            Material _material;
            RTHandle _source;
            RTHandle _blurA;
            RTHandle _blurB;

            public PremiumBlurPass()
            {
                ConfigureInput(ScriptableRenderPassInput.Color);
            }

            public void Setup(PremiumBlurSettings settings, Material material)
            {
                _settings = settings;
                _material = material;
                renderPassEvent = settings.injectionPoint;
            }

            public void SetSource(RTHandle source)
            {
                _source = source;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                int downsample = Mathf.Clamp(_settings.downsample, 1, 4);
                descriptor.width = Mathf.Max(1, descriptor.width / downsample);
                descriptor.height = Mathf.Max(1, descriptor.height / downsample);
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                RenderingUtils.ReAllocateIfNeeded(
                    ref _blurA, descriptor, FilterMode.Bilinear,
                    TextureWrapMode.Clamp, name: "_MMNPremiumBlurA");
                RenderingUtils.ReAllocateIfNeeded(
                    ref _blurB, descriptor, FilterMode.Bilinear,
                    TextureWrapMode.Clamp, name: "_MMNPremiumBlurB");
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_source == null || _material == null || _blurA == null || _blurB == null) return;

                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    _material.SetFloat(BlurRadiusId, Mathf.Ceil(_settings.kernelSize * 0.5f));
                    _material.SetFloat(SampleSpacingId, _settings.sampleSpacing);
                    _material.SetFloat(SigmaId, _settings.sigma);

                    Blitter.BlitCameraTexture(cmd, _source, _blurA, _material, 0);
                    Blitter.BlitCameraTexture(cmd, _blurA, _blurB, _material, 1);
                    for (int iteration = 1; iteration < Mathf.Clamp(_settings.iterations, 1, 4); iteration++)
                    {
                        Blitter.BlitCameraTexture(cmd, _blurB, _blurA, _material, 0);
                        Blitter.BlitCameraTexture(cmd, _blurA, _blurB, _material, 1);
                    }

                    cmd.SetGlobalTexture(PremiumBlurTextureId, _blurB.nameID);
                    cmd.SetGlobalTexture(
                        PremiumBlurMaskId,
                        new RenderTargetIdentifier(_settings.maskTexture != null
                            ? _settings.maskTexture
                            : Texture2D.whiteTexture));
                    cmd.SetGlobalFloat(PremiumBlurUseMaskId, _settings.maskTexture != null ? 1f : 0f);
                    cmd.SetGlobalFloat(PremiumBlurLevelFromId, _settings.levelFrom);
                    cmd.SetGlobalFloat(PremiumBlurLevelToId, _settings.levelTo);
                    cmd.SetGlobalFloat(PremiumBlurAvailableId, 1f);
                }

                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            public void Dispose()
            {
                _blurA?.Release();
                _blurB?.Release();
                _blurA = null;
                _blurB = null;
            }
        }

        sealed class CompositePass : ScriptableRenderPass
        {
            static readonly int CameraFadeEnabledId = Shader.PropertyToID("_CameraFadeEnabled");
            static readonly int CameraFadeModeId = Shader.PropertyToID("_CameraFadeMode");
            static readonly int CameraFadeColorId = Shader.PropertyToID("_CameraFadeColor");
            static readonly int CameraVignettingRangeId = Shader.PropertyToID("_CameraVignettingRange");
            static readonly int CameraVignettingSmoothId = Shader.PropertyToID("_CameraVignettingSmooth");
            static readonly int CameraColorIntensityId = Shader.PropertyToID("_CameraColorIntensity");
            static readonly int CameraAlphaIntensityId = Shader.PropertyToID("_CameraAlphaIntensity");
            static readonly int ScreenEffectEnabledId = Shader.PropertyToID("_ScreenEffectEnabled");
            static readonly int ScreenEffectModeId = Shader.PropertyToID("_ScreenEffectMode");
            static readonly int ScreenProgressId = Shader.PropertyToID("_ScreenProgress");
            static readonly int ScreenInverseId = Shader.PropertyToID("_ScreenInverse");
            static readonly int ScreenColorId = Shader.PropertyToID("_ScreenColor");
            static readonly int ScreenSoftnessId = Shader.PropertyToID("_ScreenSoftness");
            static readonly int ScreenWaveAmplitudeId = Shader.PropertyToID("_ScreenWaveAmplitude");
            static readonly int ScreenWaveFrequencyId = Shader.PropertyToID("_ScreenWaveFrequency");
            static readonly int ScreenVignettingRangeId = Shader.PropertyToID("_ScreenVignettingRange");
            static readonly int ScreenVignettingSmoothId = Shader.PropertyToID("_ScreenVignettingSmooth");

            readonly ProfilingSampler _profilingSampler = new ProfilingSampler("MMN Full Screen Composite");
            CompositeSettings _settings;
            Material _material;
            RTHandle _source;
            RTHandle _temporary;

            public CompositePass()
            {
                ConfigureInput(ScriptableRenderPassInput.Color);
            }

            public void Setup(CompositeSettings settings, Material material)
            {
                _settings = settings;
                _material = material;
                renderPassEvent = settings.injectionPoint;
            }

            public void SetSource(RTHandle source)
            {
                _source = source;
            }

            public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
            {
                var descriptor = renderingData.cameraData.cameraTargetDescriptor;
                descriptor.depthBufferBits = 0;
                descriptor.msaaSamples = 1;
                RenderingUtils.ReAllocateIfNeeded(
                    ref _temporary, descriptor, FilterMode.Bilinear,
                    TextureWrapMode.Clamp, name: "_MMNPostProcessingComposite");
            }

            public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
            {
                if (_source == null || _temporary == null || _material == null) return;
                ApplyMaterialProperties();

                var cmd = CommandBufferPool.Get();
                using (new ProfilingScope(cmd, _profilingSampler))
                {
                    Blitter.BlitCameraTexture(cmd, _source, _temporary, _material, 0);
                    Blitter.BlitCameraTexture(cmd, _temporary, _source);
                }
                context.ExecuteCommandBuffer(cmd);
                CommandBufferPool.Release(cmd);
            }

            void ApplyMaterialProperties()
            {
                var cameraFade = _settings.cameraFade;
                bool cameraFadeEnabled = cameraFade.enabled;
                var cameraFadeMode = cameraFade.mode;
                var cameraFadeColor = cameraFade.color;
                float cameraRange = cameraFade.vignettingRange;
                float cameraSmoothness = cameraFade.vignettingSmoothness;
                float cameraColorIntensity = cameraFade.colorIntensity;
                float cameraAlphaIntensity = cameraFade.alphaIntensity;

                if (MMNPostProcessingRuntime.TryGetCameraFade(out var cameraOverride))
                {
                    cameraFadeEnabled = true;
                    cameraFadeMode = cameraOverride.mode;
                    cameraFadeColor = cameraOverride.color;
                    cameraRange = cameraOverride.vignettingRange;
                    cameraSmoothness = cameraOverride.vignettingSmoothness;
                    cameraColorIntensity = cameraOverride.colorIntensity;
                    cameraAlphaIntensity = cameraOverride.alphaIntensity;
                }

                _material.SetFloat(CameraFadeEnabledId, cameraFadeEnabled ? 1f : 0f);
                _material.SetFloat(CameraFadeModeId, (float)cameraFadeMode);
                _material.SetColor(CameraFadeColorId, cameraFadeColor);
                _material.SetFloat(CameraVignettingRangeId, cameraRange);
                _material.SetFloat(CameraVignettingSmoothId, cameraSmoothness);
                _material.SetFloat(CameraColorIntensityId, cameraColorIntensity);
                _material.SetFloat(CameraAlphaIntensityId, cameraAlphaIntensity);

                var screenEffect = _settings.screenEffect;
                bool screenEffectEnabled = screenEffect.enabled;
                var screenMode = screenEffect.mode;
                float screenProgress = screenEffect.progress;
                bool screenInverse = screenEffect.inverse;
                var screenColor = screenEffect.color;
                float screenSoftness = screenEffect.softness;
                float waveAmplitude = screenEffect.waveAmplitude;
                float waveFrequency = screenEffect.waveFrequency;
                float screenRange = screenEffect.vignettingRange;
                float screenSmoothness = screenEffect.vignettingSmoothness;

                if (MMNPostProcessingRuntime.TryGetScreenEffect(out var screenOverride))
                {
                    screenEffectEnabled = true;
                    screenMode = screenOverride.mode;
                    screenProgress = screenOverride.progress;
                    screenInverse = screenOverride.inverse;
                    screenColor = screenOverride.color;
                    screenSoftness = screenOverride.softness;
                    waveAmplitude = screenOverride.waveAmplitude;
                    waveFrequency = screenOverride.waveFrequency;
                    screenRange = screenOverride.vignettingRange;
                    screenSmoothness = screenOverride.vignettingSmoothness;
                }

                _material.SetFloat(ScreenEffectEnabledId, screenEffectEnabled ? 1f : 0f);
                _material.SetFloat(ScreenEffectModeId, (float)screenMode);
                _material.SetFloat(ScreenProgressId, screenProgress);
                _material.SetFloat(ScreenInverseId, screenInverse ? -1f : 1f);
                _material.SetColor(ScreenColorId, screenColor);
                _material.SetFloat(ScreenSoftnessId, screenSoftness);
                _material.SetFloat(ScreenWaveAmplitudeId, waveAmplitude);
                _material.SetFloat(ScreenWaveFrequencyId, waveFrequency);
                _material.SetFloat(ScreenVignettingRangeId, screenRange);
                _material.SetFloat(ScreenVignettingSmoothId, screenSmoothness);
            }

            public void Dispose()
            {
                _temporary?.Release();
                _temporary = null;
            }
        }
    }
}
