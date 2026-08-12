Shader "MMN/BG/SimpleLit"
{
    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        _ContactShadowIntensity ("接触阴影强度", Range(0, 1)) = 0
        [Toggle] _NEARHALFTONECLIP ("近裁剪", Float) = 0
        [Toggle] _ALPHATEST ("Alpha 测试", Float) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("BackfaceCull", Float) = 2
        [Toggle] _BackFaceNormalturn ("翻转背面法线，让背面法线也朝前", Float) = 0
        _RaycastHarftoneClip ("射线检测半调裁剪", Range(0, 1)) = 0
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试用）", Float) = 0
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试用）", Float) = 0
        [MainTexture] _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        _ShadowDim ("Shadow Dim", Range(0, 1)) = 0.5
        _SpecColor ("Specular Color", Color) = (0.2,0.2,0.2,1)
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Gloss ("Gloss", Range(0, 1)) = 0.5
        _SpecGlossMap ("Specular Gloss Map", 2D) = "white" {}
        [Toggle] _SpecularHighlights ("Specular Highlights", Float) = 1
        [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        [Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("Emission 何时开启", Float) = 0
        [Toggle] _IsRaindrop ("是否下雨 / 积雪", Float) = 1
        [Toggle] _VertexAniOn ("Vertex Animation", Float) = 0
        _WindMultiply ("Wind Multiply", Range(0, 2)) = 1
        _WindSpeedMultiply ("Wind Speed Multiply", Range(0, 2)) = 1
        [Toggle] _UseVertexAnimation ("Use Vertex Animation", Float) = 0
        [Toggle] _IsSnowSparkling ("Snow Sparkling", Float) = 0
        _SnowSparklingMap ("Snow Sparkling Map", 2D) = "white" {}
        _SnowSparklingIntensity ("Snow Sparkling Intensity", Range(0, 2)) = 0
        _SnowSparklingSpecularIntensity ("Snow Sparkling Specular", Range(0, 2)) = 0
        _SnowSparklingTiling ("Snow Sparkling Tiling", Float) = 1
        _SnowSparklingNormalStep ("Snow Sparkling Normal Step", Float) = 0
        _halfLambertWeight ("Half Lambert Weight", Range(0, 1)) = 0.5
        _QueueOffset ("Queue Offset", Float) = 0
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
        [HideInInspector] _Color ("Legacy Color", Color) = (1,1,1,1)
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

            float3 _LightDirection;
            float3 _LightPosition;

            float4 vert(float4 positionOS : POSITION, float3 normalOS : NORMAL) : SV_POSITION
            {
                float3 positionWS = TransformObjectToWorld(positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);
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
                return positionCS;
            }
            half4 frag() : SV_Target { return 0; }
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
