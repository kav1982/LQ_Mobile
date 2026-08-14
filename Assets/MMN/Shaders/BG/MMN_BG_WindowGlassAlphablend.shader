Shader "MMN/BG/WindowGlassAlphablend"
{
                    Properties
    {
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _Gloss ("Glossiness", Range(0.01, 5)) = 1
        _EmissionColorBright ("反射颜色与强度", Color) = (1,1,1,1)
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        // Legacy preview properties still consumed by current HLSL.
        [MainColor] _BaseColor ("Base Tint", Color) = (0.6,0.75,0.9,0.25)
        [HDR] _EmissionColor ("Emission", Color) = (0.15,0.2,0.3,1)
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
                float4 _BaseMap_ST; half4 _BaseColor; half4 _EmissionColor; half _EmissionIntensity;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS=p.positionCS; o.normalWS=GetVertexNormalInputs(v.normalOS).normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
                half3 col=albedo.rgb*SampleSH(normalize(i.normalWS))+_EmissionColor.rgb*_EmissionIntensity;
                return half4(col, albedo.a);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
