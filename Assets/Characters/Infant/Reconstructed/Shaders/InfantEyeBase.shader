Shader "Characters/Infant/Reconstructed/EyeBase"
{
    Properties
    {
        _BaseMap ("Eye Base Palette", 2D) = "white" {}
        _AlphaOverride ("Alpha", Range(0,1)) = 0.5
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.01
        [HideInInspector] _StencilRef ("Eye Stencil Reference", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="AlphaTest+5" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite On
            Stencil
            {
                Ref [_StencilRef]
                Comp Always
                Pass Replace
            }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half _AlphaOverride;
                half _Cutoff;
            CBUFFER_END
            Varyings Vert(Attributes input) { Varyings output; output.positionHCS = TransformObjectToHClip(input.positionOS.xyz); output.uv = TRANSFORM_TEX(input.uv, _BaseMap); return output; }
            half4 Frag(Varyings input) : SV_Target { half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv); color.a *= _AlphaOverride; clip(color.a - _Cutoff); return color; }
            ENDHLSL
        }
    }
}
