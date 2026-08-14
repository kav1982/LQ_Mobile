Shader "Characters/Infant/Reconstructed/EyePupil"
{
    Properties
    {
        [Header(Pupil Atlas)] _BaseMap ("Pupil Dye Atlas", 2D) = "white" {}
        _BaseMapAtlasSize ("Columns Rows Index Rotation", Vector) = (1,1,1,0)
        _BaseMapScalePosition ("Scale Position", Vector) = (1,1,0,0)
        _AlphaOverride ("Alpha", Range(0,1)) = 1
        [Toggle] _IsDyable ("Decode Dye Map", Float) = 1
        [Header(Iris Colors)] _DyeColor1 ("Iris Color", Color) = (1,1,1,1)
        _DyeColor2 ("Secondary Iris Color", Color) = (1,1,1,1)
        _DyeColor3 ("Pupil Detail Color", Color) = (1,1,1,1)
        _EmissionMap ("Emission", 2D) = "black" {}
        [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionIntensity ("Emission Intensity", Range(0,10)) = 1
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.05
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="TransparentCutout" "Queue"="AlphaTest+10" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Cull Off
            ZWrite On

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "InfantReconstructedCommon.hlsl"
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _BaseMapAtlasSize;
                float4 _BaseMapScalePosition;
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
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv * _BaseMapScalePosition.xy + _BaseMapScalePosition.zw;
                return output;
            }
            half4 Frag(Varyings input) : SV_Target
            {
                float2 atlasUV = GetAtlasUV(input.uv, _BaseMapAtlasSize);
                half4 sample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, atlasUV);
                half3 decoded = DecodeInfantDyeMap(sample.rgb, _DyeColor1.rgb, _DyeColor2.rgb, _DyeColor3.rgb);
                half3 color = lerp(sample.rgb, decoded, saturate(_IsDyable));
                half alpha = sample.a * _AlphaOverride;
                clip(alpha - _Cutoff);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
}
