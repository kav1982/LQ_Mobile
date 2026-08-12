Shader "MMN/BG/WindowGlass"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (0.6,0.75,0.9,0.35)
        _Smoothness ("Smoothness", Range(0,1)) = 0.9
        [HDR] _EmissionColor ("Emission", Color) = (0.1,0.15,0.2,1)
        _EmissionIntensity ("Emission Intensity", Range(0,10)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half _Smoothness; half4 _EmissionColor; half _EmissionIntensity;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS;
                o.normalWS=GetVertexNormalInputs(v.normalOS).normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
                half3 n=normalize(i.normalWS);
                half3 v=GetWorldSpaceNormalizeViewDir(i.positionWS);
                half fresnel=pow(1-saturate(dot(n,v)), 3);
                Light L=GetMainLight();
                half3 col=albedo.rgb*(SampleSH(n)+L.color*0.3)+_EmissionColor.rgb*_EmissionIntensity;
                col+=fresnel*_Smoothness;
                return half4(col, saturate(albedo.a+fresnel*0.2));
            }
            ENDHLSL
        }
    }
    FallBack Off
}
