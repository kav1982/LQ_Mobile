Shader "Characters/Infant/Reconstructed/SimpleLit"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _Color ("Legacy Color", Color) = (1,1,1,1)
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Cull [_Cull]
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "InfantReconstructedCommon.hlsl"
            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; half3 normalWS : TEXCOORD1; float4 shadowCoord : TEXCOORD2; };
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial) float4 _BaseMap_ST; half4 _BaseColor; half4 _Color; CBUFFER_END
            Varyings Vert(Attributes input) { Varyings output; float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); output.positionHCS = TransformWorldToHClip(positionWS); output.uv = TRANSFORM_TEX(input.uv, _BaseMap); output.normalWS = TransformObjectToWorldNormal(input.normalOS); output.shadowCoord = TransformWorldToShadowCoord(positionWS); return output; }
            half4 Frag(Varyings input) : SV_Target { half4 sample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv); half4 baseColor = sample * _BaseColor * _Color; return half4(baseColor.rgb * GetInfantLighting(input.normalWS, input.shadowCoord), baseColor.a); }
            ENDHLSL
        }
    }
}
