Shader "MMN/BG/SimpleLitAlphaBlend"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
        _VertexColorWeight ("Vertex Color Weight", Range(0, 1)) = 1
        [HDR] _EmissionColor ("Emission", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
        [HideInInspector] _Color ("Legacy Color", Color) = (1,1,1,1)
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
    }
    FallBack Off
}
