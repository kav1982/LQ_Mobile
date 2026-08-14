Shader "Characters/Infant/Reconstructed/EyeShadeHighlight"
{
    Properties
    {
        _BaseMap ("Shade Mask", 2D) = "white" {}
        _ShadeColor ("Shade / Highlight Color", Color) = (0,0,0,1)
        [Toggle] _HasBaseMap ("Use Shade Mask", Float) = 1
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent+10" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _ShadeColor;
                half _HasBaseMap;
                half _Cutoff;
            CBUFFER_END
            Varyings Vert(Attributes input) { Varyings output; output.positionHCS = TransformObjectToHClip(input.positionOS.xyz); output.uv = TRANSFORM_TEX(input.uv, _BaseMap); return output; }
            half4 Frag(Varyings input) : SV_Target
            {
                half4 mask = _HasBaseMap > 0.5h ? SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) : half4(1,1,1,1);
                // The source shade texture is an opaque grayscale mask. Its red
                // channel is coverage; the alpha channel is always one.
                half coverage = _HasBaseMap > 0.5h ? mask.r : 1.0h;
                half alpha = coverage * _ShadeColor.a;
                clip(alpha - _Cutoff);
                return half4(_ShadeColor.rgb, alpha);
            }
            ENDHLSL
        }
    }
}
