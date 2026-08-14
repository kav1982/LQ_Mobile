Shader "MMN/Repro/CameraFade & Vignetting"
{
    Properties
    {
        [Enum(Fade, 0, Vignetting, 1)] _ScreenFXMode ("Screen FX Mode", Float) = 1
        _VignettingSmooth ("Vignetting Smooth", Range(0, 1)) = 0.18
        _VignettingRange ("Vignetting Range", Range(0, 1)) = 0.567
        _Color ("Base Color", Color) = (0, 0, 0, 0.702)
        _Intensity_Color ("Intensity Color", Float) = 1
        _Intensity_Alpha ("Intensity Alpha", Float) = 1
        [Header(Rendering Options)]
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent+1050"
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Transparent"
        }

        Pass
        {
            Name "Unlit"
            Tags { "LightMode" = "ScreenSpaceRenderObjects" }
            ZTest Always
            ZWrite Off
            Cull Off
            Blend [_BlendSrc] [_BlendDst]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _ScreenFXMode;
                float _VignettingSmooth;
                float _VignettingRange;
                float4 _Color;
                float _Intensity_Color;
                float _Intensity_Alpha;
            CBUFFER_END

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.positionHCS = TransformObjectToHClip(input.positionOS);
                output.uv = input.uv;
                output.color = input.color;
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float alpha = _Color.a * _Intensity_Alpha * input.color.a;
                if (_ScreenFXMode > 0.5)
                {
                    float2 centered = input.uv * 2.0 - 1.0;
                    float distanceFromCenter = length(centered);
                    float edge = smoothstep(
                        saturate(_VignettingRange),
                        saturate(_VignettingRange + max(_VignettingSmooth, 0.0001)),
                        distanceFromCenter);
                    alpha *= edge;
                }

                half3 color = saturate(_Color.rgb * _Intensity_Color) * input.color.rgb;
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }
}
