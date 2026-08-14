Shader "Hidden/MMN/PostProcessingComposite"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZTest Always
        ZWrite Off
        Cull Off

        Pass
        {
            Name "MMN Post Processing Composite"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            float _CameraFadeEnabled;
            float _CameraFadeMode;
            float4 _CameraFadeColor;
            float _CameraVignettingRange;
            float _CameraVignettingSmooth;
            float _CameraColorIntensity;
            float _CameraAlphaIntensity;

            float _ScreenEffectEnabled;
            float _ScreenEffectMode;
            float _ScreenProgress;
            float _ScreenInverse;
            float4 _ScreenColor;
            float _ScreenSoftness;
            float _ScreenWaveAmplitude;
            float _ScreenWaveFrequency;
            float _ScreenVignettingRange;
            float _ScreenVignettingSmooth;

            float CameraFadeMask(float2 uv)
            {
                if (_CameraFadeEnabled < 0.5) return 0.0;
                if (_CameraFadeMode < 0.5) return 1.0;

                float2 centered = uv * 2.0 - 1.0;
                return smoothstep(
                    saturate(_CameraVignettingRange),
                    saturate(_CameraVignettingRange + max(_CameraVignettingSmooth, 0.001)),
                    length(centered));
            }

            float ScreenEffectMask(float2 uv)
            {
                if (_ScreenEffectEnabled < 0.5) return 0.0;
                float progress = saturate(_ScreenProgress);
                float softness = max(_ScreenSoftness, 0.001);

                if (_ScreenEffectMode < 0.5)
                {
                    float aspect = _ScreenParams.x / max(_ScreenParams.y, 1.0);
                    float2 centered = uv - 0.5;
                    centered.x *= aspect;
                    float maximumRadius = length(float2(0.5 * aspect, 0.5));
                    float radius = lerp(-softness, maximumRadius + softness, progress);
                    return 1.0 - smoothstep(radius - softness, radius + softness, length(centered));
                }

                float directionUv = _ScreenInverse < 0.0 ? 1.0 - uv.x : uv.x;
                if (_ScreenEffectMode < 1.5)
                {
                    if (progress <= 0.0) return 0.0;
                    if (progress >= 1.0) return 1.0;
                    float boundary = progress +
                        sin(uv.y * _ScreenWaveFrequency * 6.2831853) * _ScreenWaveAmplitude;
                    return 1.0 - smoothstep(boundary - softness, boundary + softness, directionUv);
                }

                if (_ScreenEffectMode < 2.5)
                    return 1.0 - smoothstep(progress - softness, progress + softness, directionUv);
                if (_ScreenEffectMode < 3.5)
                    return progress;

                float2 centered = uv * 2.0 - 1.0;
                return smoothstep(
                    saturate(_ScreenVignettingRange),
                    saturate(_ScreenVignettingRange + max(_ScreenVignettingSmooth, 0.001)),
                    length(centered)) * progress;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                half4 source = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);

                float cameraAlpha = saturate(
                    _CameraFadeColor.a * _CameraAlphaIntensity * CameraFadeMask(input.texcoord));
                half3 cameraColor = saturate(_CameraFadeColor.rgb * _CameraColorIntensity);
                source.rgb = lerp(source.rgb, cameraColor, cameraAlpha);

                float screenAlpha = saturate(_ScreenColor.a * ScreenEffectMask(input.texcoord));
                source.rgb = lerp(source.rgb, _ScreenColor.rgb, screenAlpha);
                return source;
            }
            ENDHLSL
        }
    }
}
