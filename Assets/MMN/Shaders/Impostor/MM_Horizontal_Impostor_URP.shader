Shader "Amplify Impostors/MM_Horizontal Impostor URP"
{
                    Properties
    {
        _Albedo ("BaseMap", 2D) = "white" {}
        _Normals ("Normals & Depth", 2D) = "white" {}
        _Frames ("Frames", Float) = 16
        _ClipMask ("Clip", Range(0, 1)) = 0.01
        _TextureBias ("Texture Bias", Float) = -1
        [Toggle(_USE_PARALLAX_ON)] _Use_Parallax ("Use Parallax", Float) = 0
        _Parallax ("Parallax", Range(-1, 1)) = 1
        _AI_ShadowBias ("Shadow Bias", Range(0, 2)) = 0.25
        _AI_ShadowView ("Shadow View", Range(0, 1)) = 1
        _FramesX ("Frames X", Float) = 16
        _FramesY ("Frames Y", Float) = 16
        _DepthSize ("DepthSize", Float) = 1
        _ImpostorSize ("Impostor Size", Vector) = (1,1,1,1)
        _Offset ("Offset", Vector) = (0,0,0,0)
        _AI_SizeOffset ("Size & Offset", Vector) = (0,0,0,0)
        [Toggle(EFFECT_HUE_VARIATION)] _Hue ("Use SpeedTree Hue", Float) = 0
        _HueVariation ("Hue Variation", Color) = (0,0,0,0)
        [Toggle] _AI_AlphaToCoverage ("Alpha To Coverage", Float) = 0
        _ReceiveShadowStrength ("接收阴影强度", Range(0, 1)) = 0.5
        _ShadingPow ("明暗锐利度", Range(0.01, 3)) = 1
        _GIStrength ("暗部提亮", Range(0, 1)) = 0
        _TintColor ("Tint 颜色", Color) = (1,1,1,1)
        _TintStr ("Tint 强度", Float) = 0
        [Toggle] _IsRaindrop ("是否下雨/积雪", Float) = 1
        // Legacy preview properties still consumed by current HLSL.
        [MainColor] _Color ("Color", Color) = (1,1,1,1)
        _Cutoff ("Alpha Cutoff", Range(0, 1)) = 0.5
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

    
        // NOT-IMPLEMENTED: contract pass shell; original GPU program was not recoverable.
        Pass
        {
            Name "Base"
            Tags { "LightMode" = "Base" }
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

        // NOT-IMPLEMENTED: contract pass shell; original GPU program was not recoverable.
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
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
