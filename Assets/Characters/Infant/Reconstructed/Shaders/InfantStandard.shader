Shader "Characters/Infant/Reconstructed/Standard"
{
    Properties
    {
        [Header(Texture)] _BaseMap ("Base / Dye Map", 2D) = "white" {}
        _TintColor ("Tint Color", Color) = (1,1,1,1)
        _AlphaOverride ("Alpha", Range(0,1)) = 1
        [Toggle] _IsDyable ("Decode Dye Map", Float) = 1
        [Header(Dye Colors)] _DyeColor1 ("Dye Color 1", Color) = (1,1,1,1)
        _DyeColor2 ("Dye Color 2", Color) = (1,1,1,1)
        _DyeColor3 ("Dye Color 3", Color) = (1,1,1,1)
        [Header(Shading)] _FlatShadingAmountTop ("Top Flat Shading", Range(0,1)) = 1
        _FlatShadingAmountBottom ("Bottom Flat Shading", Range(0,1)) = 0
        _ReceiveShadowStrength ("Receive Shadow", Range(0,1)) = 1
        [Header(Outline)] [Toggle] _OutlineOff ("Disable Outline", Float) = 0
        _OutlineColor ("Outline Color", Color) = (1,1,1,1)
        [Enum(UnityEngine.Rendering.CullMode)] _CullType ("Cull", Float) = 2
        [Toggle] _ZWrite ("Z Write", Float) = 1
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.05
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Cull [_CullType]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #include "InfantReconstructedCommon.hlsl"

            struct Attributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; half3 normalWS : TEXCOORD1; float4 shadowCoord : TEXCOORD2; half fogFactor : TEXCOORD3; };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _TintColor;
                half4 _DyeColor1;
                half4 _DyeColor2;
                half4 _DyeColor3;
                half _AlphaOverride;
                half _IsDyable;
                half _Cutoff;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionHCS = TransformWorldToHClip(positionWS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.shadowCoord = TransformWorldToShadowCoord(positionWS);
                output.fogFactor = ComputeFogFactor(output.positionHCS.z);
                return output;
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 sample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 decoded = DecodeInfantDyeMap(sample.rgb, _DyeColor1.rgb, _DyeColor2.rgb, _DyeColor3.rgb);
                half3 baseColor = lerp(sample.rgb, decoded, saturate(_IsDyable)) * _TintColor.rgb;
                half alpha = sample.a * _TintColor.a * _AlphaOverride;
                clip(alpha - _Cutoff);
                half3 color = baseColor * GetInfantLighting(input.normalWS, input.shadowCoord);
                return half4(MixFog(color, input.fogFactor), alpha);
            }
            ENDHLSL
        }
    }
}
