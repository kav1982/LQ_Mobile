Shader "Amplify Impostors/MM_Horizontal Impostor URP"
{
    Properties
    {
        [MainTexture] _Albedo ("Albedo", 2D) = "white" {}
        _Normals ("Normals", 2D) = "bump" {}
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5
        [HideInInspector] _BaseMap ("Base Map Alias", 2D) = "white" {}
        [HideInInspector] _BaseColor ("Base Color Alias", Color) = (1,1,1,1)
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        Cull Off
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_Albedo); SAMPLER(sampler_Albedo);
            TEXTURE2D(_Normals); SAMPLER(sampler_Normals);
            float4 _Albedo_ST; half4 _Color; half _Cutoff;
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS;
                o.normalWS=GetVertexNormalInputs(v.normalOS).normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_Albedo); return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_Albedo,sampler_Albedo,i.uv)*_Color;
                clip(albedo.a-_Cutoff);
                // NormalDepth packed texture: rgb=normal-ish, a unused for preview
                half3 packed=SAMPLE_TEXTURE2D(_Normals,sampler_Normals,i.uv).xyz*2-1;
                half3 n=normalize(i.normalWS+packed*0.35);
                Light L=GetMainLight();
                half ndl=saturate(dot(n,L.direction))*0.5+0.5;
                half3 col=albedo.rgb*(L.color*ndl+SampleSH(n));
                return half4(col,1);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
