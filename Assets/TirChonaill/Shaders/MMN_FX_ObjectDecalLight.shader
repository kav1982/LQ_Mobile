Shader "MMN/FX/ObjectDecalLight"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        [HDR] _EmissionColor ("Emission", Color) = (1,0.8,0.4,1)
        _EmissionIntensity ("Emission Intensity", Range(0,10)) = 2
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        LOD 100
        Cull [_Cull]
        Blend SrcAlpha One
        ZWrite Off
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST; half4 _BaseColor; half4 _EmissionColor; half _EmissionIntensity;
            struct Attr { float4 positionOS:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float4 color:TEXCOORD1; };
            Var vert(Attr v){ Var o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=TRANSFORM_TEX(v.uv,_BaseMap); o.color=v.color; return o; }
            half4 frag(Var i):SV_Target{
                half4 t=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor*i.color;
                half3 col=t.rgb*_EmissionColor.rgb*_EmissionIntensity;
                return half4(col, t.a);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
