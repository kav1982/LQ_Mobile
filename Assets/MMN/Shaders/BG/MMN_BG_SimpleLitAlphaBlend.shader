Shader "MMN/BG/SimpleLitAlphaBlend"
{
                    Properties
    {
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Gloss ("Glossiness", Range(0.01, 5)) = 1
        _SpecGlossMap ("Specular Map", 2D) = "white" {}
        _SmoothnessSource ("Smoothness Source", Float) = 0
        _SpecularHighlights ("Specular Highlights", Float) = 1
        _BumpScale ("Scale", Float) = 1
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        _Surface ("__surface", Float) = 0
        _Blend ("__blend", Float) = 0
        _AlphaClip ("__clip", Float) = 0
        _SrcBlend ("__src", Float) = 1
        _DstBlend ("__dst", Float) = 0
        _ZWrite ("__zw", Float) = 1
        [ToggleUI] _ReceiveShadows ("Receive Shadows", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0.01
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        unity_Lightmaps ("unity_Lightmaps", 2D) = "white" {}
        unity_LightmapsInd ("unity_LightmapsInd", 2D) = "white" {}
        unity_ShadowMasks ("unity_ShadowMasks", 2D) = "white" {}
        _WindMultiply ("Wind Multiply（风细节）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速权重）", Range(0, 40)) = 7
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        [Toggle] _VertexAniOn ("开启顶点动画", Float) = 1
        [Toggle] _UseVertexAnimation ("在 GUI 中关闭顶点动画", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
        LOD 200
        Cull [_Cull]
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half _VertexColorWeight;
                half4 _EmissionColor; half _EmissionIntensity;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; float4 color:TEXCOORD3; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS;
                o.normalWS=GetVertexNormalInputs(v.normalOS).normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); o.color=v.color; return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
                albedo.rgb*=lerp(half3(1,1,1), i.color.rgb, _VertexColorWeight);
                albedo.a*=i.color.a;
                half3 n=normalize(i.normalWS);
                Light L=GetMainLight();
                half ndl=saturate(dot(n, L.direction))*0.5+0.5;
                half3 lighting=L.color*ndl+SampleSH(n);
            #if defined(_ADDITIONAL_LIGHTS)
                // No shadow term: this pass has no shadow path at all, not even for the main
                // light, and transparent surfaces do not sample the additional light shadowmaps.
                uint addCount=GetAdditionalLightsCount();
                for(uint li=0u; li<addCount; ++li)
                {
                    Light al=GetAdditionalLight(li, i.positionWS);
                    half w=saturate(dot(n, al.direction)*0.5h+0.5h);
                    lighting+=al.color*w*al.distanceAttenuation;
                }
            #endif
                half3 col=albedo.rgb*lighting;
                col+=SAMPLE_TEXTURE2D(_EmissionMap,sampler_EmissionMap,i.uv).rgb*_EmissionColor.rgb*_EmissionIntensity;
                return half4(col, albedo.a);
            }
            ENDHLSL
        }

    
        // NOT-IMPLEMENTED: contract pass shell; original GPU program was not recoverable.
        Pass
        {
            Name "BaseSSAOMask"
            Tags { "LightMode" = "BaseSSAOMask" }
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vertContractShell
            #pragma fragment fragContractShell
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct ContractAttributes { float4 positionOS : POSITION; };
            float4 vertContractShell(ContractAttributes input) : SV_POSITION
            { return TransformObjectToHClip(input.positionOS.xyz); }
            half4 fragContractShell() : SV_Target { return 0; }
            ENDHLSL
        }
}

    FallBack Off

}
