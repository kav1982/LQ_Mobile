Shader "MMN/BG/SimpleLitLOD"
{
    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        [Toggle] _ALPHATEST ("Alpha 测试", Float) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("BackfaceCull", Float) = 2
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试用）", Float) = 0
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试用）", Float) = 0
        [MainTexture] _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        [Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("Emission 何时开启", Float) = 0
        [Toggle] _IsRaindrop ("是否下雨 / 积雪", Float) = 1
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
        [HideInInspector] _Color ("Legacy Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
        LOD 200
        Cull [_Cull]
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half _AlbedoTintStrength; half _Cutoff; half _ALPHATEST;
                half _VertexColorWeight; half _ShowVertexColor; half _ShowVertexAlpha;
                half4 _EmissionColor; half _EmissionIntensity;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; float4 color:TEXCOORD3; float fog:TEXCOORD4; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs n=GetVertexNormalInputs(v.normalOS);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS; o.normalWS=n.normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); o.color=v.color; o.fog=ComputeFogFactor(p.positionCS.z); return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
                albedo.rgb*=lerp(half3(1,1,1), i.color.rgb, _VertexColorWeight);
                if(_ALPHATEST>0.5) clip(albedo.a-_Cutoff);
                if(_ShowVertexColor>0.5) return half4(i.color.rgb,1);
                if(_ShowVertexAlpha>0.5) return half4(i.color.aaa,1);
                half3 n=normalize(i.normalWS);
                Light L=GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half ndl=saturate(dot(n, L.direction));
                half3 lighting=L.color*(ndl*L.shadowAttenuation*0.5+0.5)+SampleSH(n);
            #if defined(_ADDITIONAL_LIGHTS)
                // This LOD variant has no _halfLambertWeight, so the wrap is fixed at 0.5 to match
                // its hardcoded main light term rather than introducing a property the shipped
                // shader does not declare.
                uint addCount=GetAdditionalLightsCount();
                for(uint li=0u; li<addCount; ++li)
                {
                    Light al=GetAdditionalLight(li, i.positionWS, half4(1,1,1,1));
                    half w=saturate(dot(n, al.direction)*0.5h+0.5h);
                    lighting+=al.color*w*al.distanceAttenuation*al.shadowAttenuation;
                }
            #endif
                half3 lit=albedo.rgb*lighting;
                lit+=SAMPLE_TEXTURE2D(_EmissionMap,sampler_EmissionMap,i.uv).rgb*_EmissionColor.rgb*_EmissionIntensity;
                return half4(MixFog(lit,i.fog), albedo.a);
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On ZTest LEqual ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            float3 _LightDirection;
            float3 _LightPosition;
            float4 vert(float4 positionOS:POSITION, float3 normalOS:NORMAL):SV_POSITION{
                float3 positionWS=TransformObjectToWorld(positionOS.xyz);
                float3 normalWS=TransformObjectToWorldNormal(normalOS);
            #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                float3 lightDirectionWS=normalize(_LightPosition-positionWS);
            #else
                float3 lightDirectionWS=_LightDirection;
            #endif
                float4 positionCS=TransformWorldToHClip(ApplyShadowBias(positionWS,normalWS,lightDirectionWS));
            #if UNITY_REVERSED_Z
                positionCS.z=min(positionCS.z,UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z=max(positionCS.z,UNITY_NEAR_CLIP_VALUE);
            #endif
                return positionCS;
            }
            half4 frag():SV_Target{return 0;}
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            float4 vert(float4 p:POSITION):SV_POSITION{return TransformWorldToHClip(TransformObjectToWorld(p.xyz));}
            half4 frag():SV_Target{return 0;}
            ENDHLSL
        }
    }
    FallBack Off
}
