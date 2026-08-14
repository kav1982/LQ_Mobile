Shader "Characters/Infant/Preview"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _DyeColor1 ("Dye Color 1", Color) = (1,1,1,1)
        _DyeColor2 ("Dye Color 2", Color) = (1,1,1,1)
        _DyeColor3 ("Dye Color 3", Color) = (1,1,1,1)
        [HideInInspector] _MaterialMode ("Material Mode", Float) = 0
        [HideInInspector] _HasBaseMap ("Has Base Map", Float) = 1
        [HideInInspector] _AlphaOverride ("Alpha Override", Float) = 1
        [HideInInspector] _Unlit ("Unlit", Float) = 0
        [HideInInspector] _SrcBlend ("Source Blend", Float) = 1
        [HideInInspector] _DstBlend ("Destination Blend", Float) = 0
        [HideInInspector] _ZWrite ("Z Write", Float) = 1
        [HideInInspector] _Cull ("Cull", Float) = 2
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
        }

        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }
            Blend [_SrcBlend] [_DstBlend]
            Cull [_Cull]
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 shadowCoord : TEXCOORD2;
                half fogFactor : TEXCOORD3;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _DyeColor1;
                half4 _DyeColor2;
                half4 _DyeColor3;
                half _MaterialMode;
                half _HasBaseMap;
                half _AlphaOverride;
                half _Unlit;
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

            half3 DecodeDyeMap(half3 sourceLinear)
            {
                half3 encoded = LinearToSRGB(saturate(sourceLinear));
                const half marker = 128.0h / 255.0h;
                const half tolerance = 10.0h / 255.0h;

                half slot1 = saturate(1.0h - max(abs(encoded.g - marker), abs(encoded.b - marker)) / tolerance);
                half slot2 = saturate(1.0h - max(abs(encoded.r - marker), abs(encoded.b - marker)) / tolerance);
                half slot3 = saturate(1.0h - max(abs(encoded.r - marker), abs(encoded.g - marker)) / tolerance);
                slot1 *= step(encoded.r + 1.0h / 255.0h, min(encoded.g, encoded.b));
                slot2 *= step(encoded.g + 1.0h / 255.0h, min(encoded.r, encoded.b));
                slot3 *= step(encoded.b + 1.0h / 255.0h, min(encoded.r, encoded.g));

                half3 dyed1 = _DyeColor1.rgb * (0.5h + encoded.r * 2.0h);
                half3 dyed2 = _DyeColor2.rgb * (0.5h + encoded.g * 2.0h);
                half3 dyed3 = _DyeColor3.rgb * (0.5h + encoded.b * 2.0h);
                half dyeWeight = max(slot1, max(slot2, slot3));
                half3 dyed = slot1 >= slot2 && slot1 >= slot3 ? dyed1 : slot2 >= slot3 ? dyed2 : dyed3;
                return lerp(sourceLinear, dyed, dyeWeight);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                half4 sample = _HasBaseMap > 0.5h
                    ? SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv)
                    : half4(1.0h, 1.0h, 1.0h, 1.0h);
                half3 baseColor = _MaterialMode < 0.5h
                    ? DecodeDyeMap(sample.rgb) * _BaseColor.rgb
                    : _MaterialMode < 1.5h ? sample.rgb * _BaseColor.rgb : _BaseColor.rgb;
                half alpha = sample.a * _BaseColor.a * _AlphaOverride;
                clip(alpha - _Cutoff);

                half3 normalWS = normalize(input.normalWS);
                Light mainLight = GetMainLight(input.shadowCoord);
                half NoL = saturate(dot(normalWS, mainLight.direction));
                half3 ambient = max(SampleSH(normalWS), half3(0.28h, 0.28h, 0.28h));
                half3 direct = mainLight.color * (0.25h + NoL * 0.55h) *
                               mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                half3 litColor = baseColor * min(ambient + direct, half3(1.25h, 1.25h, 1.25h));
                half3 finalColor = lerp(litColor, baseColor, _Unlit);
                finalColor = MixFog(finalColor, input.fogFactor);
                return half4(finalColor, alpha);
            }
            ENDHLSL
        }
    }
}
