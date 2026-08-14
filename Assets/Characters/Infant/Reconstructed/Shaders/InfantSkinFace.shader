Shader "Characters/Infant/Reconstructed/SkinFace"
{
    Properties
    {
        [Header(Skin Texture)] _BaseMap ("Face Dye Map", 2D) = "white" {}
        _TintColor ("Face Tint", Color) = (1,1,1,1)
        _AlphaOverride ("Alpha", Range(0,1)) = 1
        [Toggle] _IsDyable ("Decode Face Dye Map", Float) = 1
        [Header(Skin Colors)] _DyeColor1 ("Primary Skin Color", Color) = (1,1,1,1)
        _DyeColor2 ("Secondary Skin Color", Color) = (1,1,1,1)
        _DyeColor3 ("Detail Skin Color", Color) = (1,1,1,1)
        [Header(Mouth)] [Enum(Base,0,Emotion,1)] _MouthShowType ("Mouth Mode", Float) = 0
        _MouthMap ("Mouth Map", 2D) = "black" {}
        _MouthMapScalePosition ("Mouth Scale Position", Vector) = (1,1,0,0)
        _MouthMapRotation ("Mouth Rotation", Float) = 0
        _EmotionMouthMap ("Emotion Mouth Atlas", 2D) = "black" {}
        _EmotionMouthMapAtlasSize ("Mouth Atlas Columns Rows Index Rotation", Vector) = (4,8,1,0)
        _EmotionMouthMapScalePositionBase ("Emotion Mouth Scale Position", Vector) = (1,1,0,0)
        _EmotionMouthMapScalePosition ("Emotion Mouth Animated Scale Position", Vector) = (1,1,0,0)
        _MouthPushStrength ("Mouth Push", Range(0,1)) = 0.1
        [Header(Tattoo)] _TattooMap ("Tattoo / Scar", 2D) = "black" {}
        [Header(Accessory)] _AccessoryMap ("Face Accessory", 2D) = "black" {}
        [Header(Shading)] _FlatShadingAmountTop ("Top Flat Shading", Range(0,1)) = 1
        _FlatShadingAmountBottom ("Bottom Flat Shading", Range(0,1)) = 0
        [HideInInspector] _CullType ("Cull", Float) = 2
        [HideInInspector] _ZWrite ("Z Write", Float) = 1
        [HideInInspector] _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float2 mouthUV : TEXCOORD1;
            };
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 baseUV : TEXCOORD0;
                float2 mouthUV : TEXCOORD1;
                half3 normalWS : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                half fogFactor : TEXCOORD4;
            };

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MouthMap); SAMPLER(sampler_MouthMap);
            TEXTURE2D(_EmotionMouthMap); SAMPLER(sampler_EmotionMouthMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _TintColor;
                half4 _DyeColor1;
                half4 _DyeColor2;
                half4 _DyeColor3;
                half _AlphaOverride;
                half _IsDyable;
                half _MouthShowType;
                half _MouthMapRotation;
                half _MouthPushStrength;
                half _CullType;
                half _ZWrite;
                half _Cutoff;
                float4 _MouthMapScalePosition;
                float4 _EmotionMouthMapAtlasSize;
                float4 _EmotionMouthMapScalePositionBase;
                float4 _EmotionMouthMapScalePosition;
            CBUFFER_END

            Varyings Vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionHCS = TransformWorldToHClip(positionWS);
                output.baseUV = TRANSFORM_TEX(input.uv, _BaseMap);
                output.mouthUV = input.mouthUV;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.shadowCoord = TransformWorldToShadowCoord(positionWS);
                output.fogFactor = ComputeFogFactor(output.positionHCS.z);
                return output;
            }

            float2 RotateMouthUV(float2 uv, half rotation)
            {
                float angle = rotation * 1.57079632679;
                float sine = sin(angle);
                float cosine = cos(angle);
                float2 centered = uv - 0.5;
                return float2(centered.x * cosine - centered.y * sine,
                              centered.x * sine + centered.y * cosine) + 0.5;
            }

            half IsInsideUnitUV(float2 uv)
            {
                return step(0.0, uv.x) * step(uv.x, 1.0) *
                       step(0.0, uv.y) * step(uv.y, 1.0);
            }

            half4 SampleMouth(float2 mouthUV)
            {
                half validMouthUV = step(0.0001h, max(abs(mouthUV.x), abs(mouthUV.y)));

                float2 baseMouthUV = mouthUV * _MouthMapScalePosition.xy - _MouthMapScalePosition.zw;
                baseMouthUV = RotateMouthUV(baseMouthUV, _MouthMapRotation);
                half baseCoverage = validMouthUV * IsInsideUnitUV(baseMouthUV);
                half4 baseMouth = SAMPLE_TEXTURE2D(_MouthMap, sampler_LinearClamp, saturate(baseMouthUV));
                baseMouth.a *= baseCoverage;

                float2 emotionTransform = _EmotionMouthMapScalePosition.xy;
                float2 emotionOffset = _EmotionMouthMapScalePosition.zw;
                if (abs(emotionTransform.x) < 0.001 || abs(emotionTransform.y) < 0.001)
                {
                    emotionTransform = _EmotionMouthMapScalePositionBase.xy;
                    emotionOffset = _EmotionMouthMapScalePositionBase.zw;
                }
                float2 emotionUV = mouthUV * emotionTransform - emotionOffset;
                emotionUV = RotateMouthUV(emotionUV, _EmotionMouthMapAtlasSize.w);
                half emotionCoverage = validMouthUV * IsInsideUnitUV(emotionUV);
                float2 atlasUV = GetAtlasUV(saturate(emotionUV), _EmotionMouthMapAtlasSize);
                half4 emotionMouth = SAMPLE_TEXTURE2D(_EmotionMouthMap, sampler_LinearClamp, atlasUV);
                emotionMouth.a *= emotionCoverage;
                return lerp(baseMouth, emotionMouth, step(0.5h, _MouthShowType));
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 sample = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
                half3 decoded = DecodeInfantDyeMap(sample.rgb, _DyeColor1.rgb, _DyeColor2.rgb, _DyeColor3.rgb);
                half3 baseColor = lerp(sample.rgb, decoded, saturate(_IsDyable)) * _TintColor.rgb;
                half alpha = sample.a * _TintColor.a * _AlphaOverride;
                clip(alpha - _Cutoff);

                half4 mouth = SampleMouth(input.mouthUV);
                baseColor = lerp(baseColor, mouth.rgb, saturate(mouth.a));
                half3 color = baseColor * GetInfantLighting(input.normalWS, input.shadowCoord);
                return half4(MixFog(color, input.fogFactor), alpha);
            }
            ENDHLSL
        }
    }
}
