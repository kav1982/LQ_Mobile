Shader "MMN/BG/DetailNormal"
{
    // URP stand-in: original rain vertex anim, ramp, stencil and dither
    // shadows are contract-only. Snow overlay uses world-normal Y vs
    // _SecondMapOffset / _SecondMapBlendHardness / _SecondMapScale.
    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        _ContactShadowIntensity ("Contact Shadow 强度", Range(0, 1)) = 1
        [Toggle] _NEARHALFTONECLIP ("近裁剪", Float) = 0
        [Toggle] _ALPHATEST ("Alpha Test", Float) = 0
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _VertexColorOverlayEnable ("顶点色覆盖", Float) = 0
        _VertexColorOverlayWeight ("顶点色覆盖权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        _RampY ("Ramp Y", Range(0, 1)) = 0.5
        _halfLambertWeight ("halfLambertWeight", Range(0, 1)) = 0
        _BaseMap ("Base Map (RGB)", 2D) = "white" {}
        _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        _ShadowDim ("ShadowDimming（阴影影响）", Range(0, 1)) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _DetailMap ("Detail Map", 2D) = "gray" {}
        [Toggle] _DetailMapYenable ("Detail 使用世界 XZ", Float) = 0
        [Toggle] _SECONDMAP ("启用第二层贴图", Float) = 0
        _SecondMap ("Second Map (Snow)", 2D) = "white" {}
        _SecondMapOffset ("Second Map Offset", Range(-1, 1)) = 0.2
        _SecondMapScale ("Second Map Scale", Range(0, 4)) = 1
        _SecondMapBlendHardness ("Second Map Blend Hardness", Range(0.01, 2)) = 0.5
        _SpecColor ("Specular Color", Color) = (0,0,0,0)
        _Glossiness ("Glossiness", Range(0, 8)) = 0.01
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Surface ("Surface", Float) = 0
        _Blend ("Blend", Float) = 0
        _AlphaClip ("AlphaClip", Float) = 0
        _SrcBlend ("SrcBlend", Float) = 1
        _DstBlend ("DstBlend", Float) = 0
        _ZWrite ("ZWrite", Float) = 1
        _ReceiveShadows ("Receive Shadows", Float) = 1
        [Toggle] _IsRaindrop ("是否下雨/积雪", Float) = 1
        [Toggle] _IsSnowSparkling ("IsSnowSparkling", Float) = 0
        _SnowSparklingMap ("SnowSparklingMap", 2D) = "black" {}
        _SnowSparklingIntensity ("SnowSparkling Intensity", Range(0, 20)) = 5
        _SnowSparklingSpecularIntensity ("SnowSparkling Specular Intensity", Range(0, 5)) = 0.5
        _SnowSparklingTiling ("SnowSparkling Tiling", Vector) = (1,1,0.22,0.22)
        _SnowSparklingNormalStep ("SnowSparklingNormalStep", Range(0, 1)) = 0.5
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
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
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_SecondMap); SAMPLER(sampler_SecondMap);
            TEXTURE2D(_DetailMap); SAMPLER(sampler_DetailMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            TEXTURE2D(_SnowSparklingMap); SAMPLER(sampler_SnowSparklingMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _SecondMap_ST;
                float4 _DetailMap_ST;
                half4 _BaseColor;
                half4 _Color;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _VertexColorOverlayEnable;
                half _VertexColorOverlayWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
                half _SECONDMAP;
                half _SecondMapOffset;
                half _SecondMapScale;
                half _SecondMapBlendHardness;
                half _DetailMapYenable;
                half _IsSnowSparkling;
                half4 _SnowSparklingTiling;
                half _SnowSparklingIntensity;
                half _SnowSparklingSpecularIntensity;
                half _SnowSparklingNormalStep;
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
                o.uv = v.uv;
                o.color = v.color;
                o.fogFactor = ComputeFogFactor(pos.positionCS.z);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 baseUV = TRANSFORM_TEX(i.uv, _BaseMap);
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, baseUV);
                half4 albedo = baseMap * _BaseColor * _Color;

                float2 detailUV = _DetailMapYenable > 0.5h
                    ? i.positionWS.xz * _DetailMap_ST.xy + _DetailMap_ST.zw
                    : TRANSFORM_TEX(i.uv, _DetailMap);
                half4 detail = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, detailUV);
                albedo.rgb *= detail.rgb * 2.0h;

                half3 n = normalize(i.normalWS);
                half snowMask = 0;
                if (_SECONDMAP > 0.5h)
                {
                    float2 secondUV = TRANSFORM_TEX(i.uv, _SecondMap);
                    half3 snow = SAMPLE_TEXTURE2D(_SecondMap, sampler_SecondMap, secondUV).rgb;
                    half ny = saturate(n.y * _SecondMapScale);
                    snowMask = saturate((ny - _SecondMapOffset) / max(0.0001h, _SecondMapBlendHardness));
                    albedo.rgb = lerp(albedo.rgb, snow, snowMask);
                }

                half3 vc = lerp(half3(1,1,1), i.color.rgb, _VertexColorWeight);
                albedo.rgb *= vc;
                if (_VertexColorOverlayEnable > 0.5h)
                    albedo.rgb = lerp(albedo.rgb, i.color.rgb, _VertexColorOverlayWeight);
                albedo.rgb = lerp(albedo.rgb, albedo.rgb * (1 + _AlbedoTintStrength), saturate(abs(_AlbedoTintStrength)));

                if (_ALPHATEST > 0.5)
                    clip(albedo.a - _Cutoff);

                if (_ShowVertexColor > 0.5)
                    return half4(i.color.rgb, 1);
                if (_ShowVertexAlpha > 0.5)
                    return half4(i.color.aaa, 1);

                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half ndl = saturate(dot(n, mainLight.direction));
                half hl = lerp(ndl, ndl * 0.5 + 0.5, _halfLambertWeight);
                half shade = lerp(_ShadowDim, 1, hl * mainLight.shadowAttenuation);
                half3 lighting = mainLight.color * shade + SampleSH(n);

            #if defined(_ADDITIONAL_LIGHTS)
                uint addCount = GetAdditionalLightsCount();
                for (uint li = 0u; li < addCount; ++li)
                {
                    Light al = GetAdditionalLight(li, i.positionWS, half4(1, 1, 1, 1));
                    half d = dot(n, al.direction);
                    half w = lerp(saturate(d), saturate(d * 0.5h + 0.5h), _halfLambertWeight);
                    lighting += al.color * w * al.distanceAttenuation * al.shadowAttenuation;
                }
            #endif

                half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, baseUV).rgb * _EmissionColor.rgb * _EmissionIntensity;
                if (_IsSnowSparkling > 0.5h && snowMask > 0.01h)
                {
                    float2 spUV = i.uv * _SnowSparklingTiling.xy + _Time.y * _SnowSparklingTiling.zw;
                    half spark = SAMPLE_TEXTURE2D(_SnowSparklingMap, sampler_SnowSparklingMap, spUV).r;
                    half3 view = GetWorldSpaceNormalizeViewDir(i.positionWS);
                    half spec = pow(saturate(dot(n, normalize(mainLight.direction + view))), lerp(8.0h, 64.0h, _SnowSparklingNormalStep));
                    emission += spark * snowMask * (_SnowSparklingIntensity * 0.15h + spec * _SnowSparklingSpecularIntensity);
                }

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
                float4 _SecondMap_ST;
                float4 _DetailMap_ST;
                half4 _BaseColor;
                half4 _Color;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _VertexColorOverlayEnable;
                half _VertexColorOverlayWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
                half _SECONDMAP;
                half _SecondMapOffset;
                half _SecondMapScale;
                half _SecondMapBlendHardness;
                half _DetailMapYenable;
                half _IsSnowSparkling;
                half4 _SnowSparklingTiling;
                half _SnowSparklingIntensity;
                half _SnowSparklingSpecularIntensity;
                half _SnowSparklingNormalStep;
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
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a * _Color.a - _Cutoff);
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
                float4 _SecondMap_ST;
                float4 _DetailMap_ST;
                half4 _BaseColor;
                half4 _Color;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _VertexColorOverlayEnable;
                half _VertexColorOverlayWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
                half _SECONDMAP;
                half _SecondMapOffset;
                half _SecondMapScale;
                half _SecondMapBlendHardness;
                half _DetailMapYenable;
                half _IsSnowSparkling;
                half4 _SnowSparklingTiling;
                half _SnowSparklingIntensity;
                half _SnowSparklingSpecularIntensity;
                half _SnowSparklingNormalStep;
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
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a * _Color.a - _Cutoff);
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
                float4 _SecondMap_ST;
                float4 _DetailMap_ST;
                half4 _BaseColor;
                half4 _Color;
                half _AlbedoTintStrength;
                half _Cutoff;
                half _ALPHATEST;
                half _VertexColorWeight;
                half _VertexColorOverlayEnable;
                half _VertexColorOverlayWeight;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
                half4 _EmissionColor;
                half _EmissionIntensity;
                half _ShadowDim;
                half _Smoothness;
                half _halfLambertWeight;
                half _SECONDMAP;
                half _SecondMapOffset;
                half _SecondMapScale;
                half _SecondMapBlendHardness;
                half _DetailMapYenable;
                half _IsSnowSparkling;
                half4 _SnowSparklingTiling;
                half _SnowSparklingIntensity;
                half _SnowSparklingSpecularIntensity;
                half _SnowSparklingNormalStep;
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
                    clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).a * _BaseColor.a * _Color.a - _Cutoff);
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
