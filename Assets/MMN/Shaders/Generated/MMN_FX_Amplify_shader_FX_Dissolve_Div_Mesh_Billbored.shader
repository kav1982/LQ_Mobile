Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Mesh_Billbored"
{
    // NOT-IMPLEMENTED: generated compatibility shell; original HLSL unavailable.
                Properties
    {
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
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
        [Toggle( _RAYCAST_ON )] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Header(Flipbook)] [Space()] _Colums ("Colums", Float) = 1
        _Rows ("Rows", Float) = 1
        _Speed ("Speed", Float) = 1
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 1
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 1
        [Enum(Default,0,Billbored,1,Stretched,2)] [Header(Type)] [Space()] _BillboredType ("BillboredType", Float) = 1
        _Pivot ("Pivot", Vector) = (0,0,0,0)
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        _DefaultValues ("Default Values", Float) = 0
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        _EffectAlpha ("EffectAlpha", Float) = 1
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }
        LOD 100
        Pass
        {
            Name "Unlit"
            Tags { "LightMode" = "Unlit" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 positionOS : POSITION; };
            float4 vert(A v) : SV_POSITION { return TransformObjectToHClip(v.positionOS.xyz); }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
    }
    FallBack Off
}
