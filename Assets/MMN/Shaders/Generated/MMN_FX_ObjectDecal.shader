Shader "MMN/FX/ObjectDecal"
{
    // NOT-IMPLEMENTED: generated compatibility shell; original HLSL unavailable.
                Properties
    {
        [Header(Texture)] [Space(10)] _BaseMap ("Decal 贴图", 2D) = "white" {}
        _BaseColor ("基础 Tint", Color) = (1,1,1,1)
        [Header(Emission)] _EmissionColor ("Emission 颜色", Color) = (0,0,0,1)
        [Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("何时开启 Emission", Float) = 0
        [Header(Rendering Options)] [Space(10)] [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Header(Shadow)] [Space(10)] [Toggle] _ReceiveShadows ("接收阴影", Float) = 0
        [Header(Fog)] [Space(10)] [Toggle] _ReceiveFog ("应用雾", Float) = 1
        [Toggle(_RAYCAST_ON)] _Raycast ("_Raycast", Float) = 1
        _TransitionValue ("Transition 值", Float) = 1
        _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        _RaycastMinimumAlpha ("raycastMinimumAlpha", Range(0, 1)) = 0
        _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 1)) = 0
        _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        unity_Lightmaps ("unity_Lightmaps", 2D) = "white" {}
        unity_LightmapsInd ("unity_LightmapsInd", 2D) = "white" {}
        unity_ShadowMasks ("unity_ShadowMasks", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }
        LOD 100
        Pass
        {
            Name "Base"
            Tags { "LightMode" = "Base" }
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
