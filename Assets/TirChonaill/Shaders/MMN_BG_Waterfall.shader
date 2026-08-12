Shader "MMN/BG/Waterfall"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (0.7,0.85,1,0.6)
        _ScrollSpeed ("Scroll Speed", Vector) = (0,-0.4,0,0)
        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            float4 _BaseMap_ST; half4 _BaseColor; float4 _ScrollSpeed;
            struct Attr { float4 positionOS:POSITION; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };
            Var vert(Attr v){ Var o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=TRANSFORM_TEX(v.uv,_BaseMap)+_ScrollSpeed.xy*_Time.y; return o; }
            half4 frag(Var i):SV_Target{ return SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor; }
            ENDHLSL
        }
    }
    FallBack Off
}
