Shader "MMN/FX/Amplify shader/Environment/Additive_GodLay"
{
                    Properties
    {
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
        _GodlayTex ("Godlay Texture", 2D) = "white" {}
        _Softness ("Softness", Range(0, 10)) = 1
        _Speed ("Speed", Range(0, 3)) = 0.3
        _Color ("Color", Color) = (1,1,1,1)
        _Intensive ("Intensive", Range(0, 1)) = 0.3
        _Float0 ("柔和高度调节", Range(1, 10)) = 2
        [Toggle] [Space()] [Header(Night Setting)] [Space()] _NightToggle ("应用夜间设置", Float) = 0
        _Color_Night ("Color_Night", Color) = (1,1,1,1)
        _Intensive_Night ("Intensive_Night", Range(0, 1)) = 0.3
        _Float1 ("柔和高度调节（夜）", Range(1, 10)) = 2
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [Header(Z Buffer)] [Space(10)] _CullMode ("Cull Mode", Float) = 0
        _Mode ("Mode", Float) = -1
        _TransitionValue ("TransitionValue", Range(0, 1)) = 1
        _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        _RaycastMinimumAlpha ("minimumAlpha", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 18)) = 0
        _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] _LightReceive ("LightReceive", Range(0, 1)) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        [ToggleUI] _FogReceive ("FogReceive", Range(0, 1)) = 0
        _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle(_RAYCAST_ON)] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 0
        // Legacy preview properties still consumed by current HLSL.
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,0.8,1)
        _EmissionIntensity ("Intensity", Range(0, 10)) = 1.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        Blend SrcAlpha One
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
            float4 _BaseMap_ST; half4 _BaseColor; half4 _EmissionColor; half _EmissionIntensity;
            struct Attr { float4 positionOS:POSITION; float2 uv:TEXCOORD0; float4 color:COLOR; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float4 color:TEXCOORD1; };
            Var vert(Attr v){ Var o; o.positionCS=TransformObjectToHClip(v.positionOS.xyz); o.uv=TRANSFORM_TEX(v.uv,_BaseMap); o.color=v.color; return o; }
            half4 frag(Var i):SV_Target{
                half4 t=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor*i.color;
                return half4(t.rgb*_EmissionColor.rgb*_EmissionIntensity, t.a);
            }
            ENDHLSL
        }

    
        // NOT-IMPLEMENTED: contract pass shell; original GPU program was not recoverable.
        Pass
        {
            Name "Unlit"
            Tags { "LightMode" = "Unlit" }
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
