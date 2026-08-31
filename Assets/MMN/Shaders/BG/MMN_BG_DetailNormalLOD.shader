Shader "MMN/BG/DetailNormalLOD"
{
    // LOD stand-in of MMN/BG/DetailNormal: snow overlay only, no sparkling.
    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        [Toggle] _ALPHATEST ("Alpha Test", Float) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _VertexColorOverlayEnable ("顶点色覆盖", Float) = 0
        _VertexColorOverlayWeight ("顶点色覆盖权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        _BaseMap ("Base Map (RGB)", 2D) = "white" {}
        _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
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
        [Toggle] _IsRaindrop ("是否下雨/积雪", Float) = 1
        _Color ("Base Color", Color) = (1,1,1,1)
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
            TEXTURE2D(_SecondMap); SAMPLER(sampler_SecondMap);
            TEXTURE2D(_DetailMap); SAMPLER(sampler_DetailMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; float4 _SecondMap_ST; float4 _DetailMap_ST;
                half4 _BaseColor; half4 _Color; half _AlbedoTintStrength; half _Cutoff; half _ALPHATEST;
                half _VertexColorWeight; half _VertexColorOverlayEnable; half _VertexColorOverlayWeight;
                half _ShowVertexColor; half _ShowVertexAlpha;
                half4 _EmissionColor; half _EmissionIntensity;
                half _SECONDMAP; half _SecondMapOffset; half _SecondMapScale; half _SecondMapBlendHardness;
                half _DetailMapYenable;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; float4 color:TEXCOORD3; float fog:TEXCOORD4; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs n=GetVertexNormalInputs(v.normalOS);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS; o.normalWS=n.normalWS;
                o.uv=v.uv; o.color=v.color; o.fog=ComputeFogFactor(p.positionCS.z); return o;
            }
            half4 frag(Var i):SV_Target{
                float2 baseUV=TRANSFORM_TEX(i.uv,_BaseMap);
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,baseUV)*_BaseColor*_Color;
                float2 detailUV=_DetailMapYenable>0.5h ? i.positionWS.xz*_DetailMap_ST.xy+_DetailMap_ST.zw : TRANSFORM_TEX(i.uv,_DetailMap);
                albedo.rgb*=SAMPLE_TEXTURE2D(_DetailMap,sampler_DetailMap,detailUV).rgb*2.0h;
                half3 n=normalize(i.normalWS);
                if(_SECONDMAP>0.5h){
                    half3 snow=SAMPLE_TEXTURE2D(_SecondMap,sampler_SecondMap,TRANSFORM_TEX(i.uv,_SecondMap)).rgb;
                    half ny=saturate(n.y*_SecondMapScale);
                    half snowMask=saturate((ny-_SecondMapOffset)/max(0.0001h,_SecondMapBlendHardness));
                    albedo.rgb=lerp(albedo.rgb,snow,snowMask);
                }
                albedo.rgb*=lerp(half3(1,1,1), i.color.rgb, _VertexColorWeight);
                if(_VertexColorOverlayEnable>0.5h)
                    albedo.rgb=lerp(albedo.rgb,i.color.rgb,_VertexColorOverlayWeight);
                if(_ALPHATEST>0.5) clip(albedo.a-_Cutoff);
                if(_ShowVertexColor>0.5) return half4(i.color.rgb,1);
                if(_ShowVertexAlpha>0.5) return half4(i.color.aaa,1);
                Light L=GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half ndl=saturate(dot(n, L.direction));
                half3 lighting=L.color*(ndl*L.shadowAttenuation*0.5+0.5)+SampleSH(n);
            #if defined(_ADDITIONAL_LIGHTS)
                uint addCount=GetAdditionalLightsCount();
                for(uint li=0u; li<addCount; ++li)
                {
                    Light al=GetAdditionalLight(li, i.positionWS, half4(1,1,1,1));
                    half w=saturate(dot(n, al.direction)*0.5h+0.5h);
                    lighting+=al.color*w*al.distanceAttenuation*al.shadowAttenuation;
                }
            #endif
                half3 lit=albedo.rgb*lighting;
                lit+=SAMPLE_TEXTURE2D(_EmissionMap,sampler_EmissionMap,baseUV).rgb*_EmissionColor.rgb*_EmissionIntensity;
                lit=MixFog(lit,i.fog);
                return half4(lit,albedo.a);
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; float4 _SecondMap_ST; float4 _DetailMap_ST;
                half4 _BaseColor; half4 _Color; half _AlbedoTintStrength; half _Cutoff; half _ALPHATEST;
                half _VertexColorWeight; half _VertexColorOverlayEnable; half _VertexColorOverlayWeight;
                half _ShowVertexColor; half _ShowVertexAlpha;
                half4 _EmissionColor; half _EmissionIntensity;
                half _SECONDMAP; half _SecondMapOffset; half _SecondMapScale; half _SecondMapBlendHardness;
                half _DetailMapYenable;
            CBUFFER_END
            float3 _LightDirection;
            struct Attributes { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Varyings { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
            Varyings vert(Attributes v){
                Varyings o;
                float3 ws=TransformObjectToWorld(v.positionOS.xyz);
                float3 n=TransformObjectToWorldNormal(v.normalOS);
                o.positionCS=TransformWorldToHClip(ApplyShadowBias(ws,n,_LightDirection));
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap);
                return o;
            }
            half4 frag(Varyings i):SV_Target{
                if(_ALPHATEST>0.5h) clip(SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv).a*_BaseColor.a*_Color.a-_Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }
    FallBack Off
}
