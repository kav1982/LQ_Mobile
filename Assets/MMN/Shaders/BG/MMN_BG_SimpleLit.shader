Shader "MMN/BG/SimpleLit"
{
    // NOT-IMPLEMENTED: original emission flicker, rain/snow vertex animation,
    // snow sparkling, stencil and legacy specular-source controls are preserved
    // as material contract fields but have no visual effect in this URP version.
                    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        _ContactShadowIntensity ("Contact Shadow 强度", Range(0, 1)) = 1
        [Toggle] _NEARHALFTONECLIP ("近裁剪", Float) = 0
        [Toggle] _ALPHATEST ("Alpha Test", Float) = 0
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        [Toggle] _BackFaceNormalturn ("翻转背面法线，使背面也朝前", Float) = 0
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        _ShadowDim ("ShadowDimming（阴影影响）", Range(0, 1)) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _SpecColor ("Specular Color", Color) = (0,0,0,0)
        _Smoothness ("Smoothness", Range(0, 1)) = 0
        _Gloss ("Glossiness", Range(0.01, 5)) = 1
        _SpecGlossMap ("Specular Map", 2D) = "white" {}
        _SmoothnessSource ("Smoothness Source", Float) = 0
        _SpecularHighlights ("Specular Highlights", Float) = 1
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        [Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("何时开启 Emission", Float) = 0
        [Enum(None, 0, Uniform, 1, Smooth, 2, Step, 3)] _EmissionFlickerMode ("Emission 闪烁模式", Float) = 0
        _EmissionFlickerMin ("Emission 闪烁最小强度", Range(0, 1)) = 0.5
        _EmissionFlickerMax ("Emission 闪烁最大强度", Range(1, 10)) = 2
        _EmissionFlickerFrequency ("Emission 闪烁周期（速度）", Float) = 6
        _EmissionFlickerNoise ("Emission 闪烁噪声", 2D) = "gray" {}
        [Enum(UV, 0, Position_XZ, 1, Position_XY, 2, Triplanar, 3)] _EmissionFlickerNoiseUV ("Emission 闪烁噪声 UV", Float) = 0
        _EmissionFlickerNoiseScale ("Emission 闪烁噪声缩放", Float) = 1
        _EmissionFlickerNoiseSpeed ("Emission 闪烁噪声速度（XY）", Vector) = (0.1,0.1,0,0)
        _EmissionFlickerNoiseCellCount ("Emission 闪烁噪声单元格数", Float) = 16
        [Toggle] _EmissionFlickerDEBUG ("仅显示 Emission 闪烁噪声（调试）", Float) = 0
        _halfLambertWeight ("halfLambertWeight", Range(0, 1)) = 0
        [Toggle] _BackfaceReceiveShadowOff ("关闭背面接收阴影", Float) = 0
        _QueueOffset ("Queue offset", Float) = 0
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        unity_Lightmaps ("unity_Lightmaps", 2D) = "white" {}
        unity_LightmapsInd ("unity_LightmapsInd", 2D) = "white" {}
        unity_ShadowMasks ("unity_ShadowMasks", 2D) = "white" {}
        [Toggle] _IsRaindrop ("是否下雨/积雪", Float) = 1
        [Toggle] _VertexAniOn ("开启顶点动画", Float) = 1
        _WindMultiply ("Wind Multiply（风细节）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速权重）", Range(0, 40)) = 7
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        [Toggle] _UseVertexAnimation ("完全关闭顶点动画", Float) = 0
        [Header(Stencil Options)] [Space] _StencilRef ("Stencil Ref", Float) = 0
        [MaterialEnum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Float) = 0
        [MaterialEnum(UnityEngine.Rendering.StencilOp)] _StencilPass ("Stencil Pass", Float) = 0
        [Toggle] _IsSnowSparkling ("IsSnowSparkling", Float) = 0
        _SnowSparklingMap ("SnowSparklingMap", 2D) = "black" {}
        _SnowSparklingIntensity ("SnowSparkling Intensity", Range(0, 20)) = 5
        _SnowSparklingSpecularIntensity ("SnowSparkling Specular Intensity", Range(0, 5)) = 2
        _SnowSparklingTiling ("SnowSparkling Tiling", Vector) = (0.5,0.5,0.1,0.1)
        _SnowSparklingNormalStep ("SnowSparklingNormalStep", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "True"
        }
        LOD 300
        Cull [_Cull]

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma shader_feature_local _ALPHATEST_ON
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : TEXCOORD3;
                float fogFactor : TEXCOORD4;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS);
                o.positionCS = pos.positionCS;
                o.positionWS = pos.positionWS;
                o.normalWS = nrm.normalWS;
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
                o.fogFactor = ComputeFogFactor(pos.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half4 albedo = baseMap * _BaseColor;
                half3 vc = lerp(half3(1,1,1), i.color.rgb, _VertexColorWeight);
                albedo.rgb *= vc;
                albedo.rgb = lerp(albedo.rgb, albedo.rgb * (1 + _AlbedoTintStrength), saturate(abs(_AlbedoTintStrength)));

                if (_ALPHATEST > 0.5)
                    clip(albedo.a - _Cutoff);

                if (_ShowVertexColor > 0.5)
                    return half4(i.color.rgb, 1);
                if (_ShowVertexAlpha > 0.5)
                    return half4(i.color.aaa, 1);

                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half3 n = normalize(i.normalWS);
                half ndl = saturate(dot(n, mainLight.direction));
                half hl = lerp(ndl, ndl * 0.5 + 0.5, _halfLambertWeight);
                half shade = lerp(_ShadowDim, 1, hl * mainLight.shadowAttenuation);
                half3 lighting = mainLight.color * shade + SampleSH(n);

            #if defined(_ADDITIONAL_LIGHTS)
                uint addCount = GetAdditionalLightsCount();
                for (uint li = 0u; li < addCount; ++li)
                {
                    Light al = GetAdditionalLight(li, i.positionWS, half4(1, 1, 1, 1));
                    // The wrap is applied to the signed dot, unlike the main light above which
                    // floors at 0.5 on purpose. That floor would let a brazier bleed through onto
                    // faces turned away from it.
                    half d = dot(n, al.direction);
                    half w = lerp(saturate(d), saturate(d * 0.5h + 0.5h), _halfLambertWeight);
                    lighting += al.color * w * al.distanceAttenuation * al.shadowAttenuation;
                }
            #endif

                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv).rgb * _EmissionColor.rgb * _EmissionIntensity;
                half3 color = albedo.rgb * lighting + emission;
                color = MixFog(color, i.fogFactor);
                return half4(color, albedo.a);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask 0
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
            CBUFFER_END

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
            #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif
                // Without the bias the depth written here matches the receiver exactly and every
                // lit surface shadows itself, which reads as no shadowing at all.
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                output.positionCS = positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                if (_ALPHATEST > 0.5h)
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformWorldToHClip(TransformObjectToWorld(input.positionOS.xyz));
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                if (_ALPHATEST > 0.5h)
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "SSAODepthOnly"
            Tags { "LightMode" = "SSAODepthOnly" }
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformWorldToHClip(TransformObjectToWorld(input.positionOS.xyz));
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                if (_ALPHATEST > 0.5h)
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ImpactFramePrePass"
            Tags { "LightMode" = "ImpactFramePrePass" }
            Cull Back
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            float4 vert(float4 positionOS : POSITION) : SV_POSITION
            {
                return TransformWorldToHClip(TransformObjectToWorld(positionOS.xyz));
            }

            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
    }
    FallBack Off
}
