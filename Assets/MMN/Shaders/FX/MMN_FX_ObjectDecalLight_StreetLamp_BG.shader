Shader "MMN/FX/ObjectDecalLight_StreetLamp_BG"
{
                    Properties
    {
        _EmissionColor ("灯光颜色", Color) = (0,0,0,1)
        [Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("何时开启灯光", Float) = 0
        _FalloffRange ("光源中心距离（min, max）", Vector) = (0.01,0.06,0,0)
        [Header(Rendering Options)] [Space(10)] [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 1
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
        _LightPositionWS ("xyz: position, w: size", Vector) = (0,0,0,10)
        // Legacy preview properties still consumed by current HLSL.
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 2.5
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
}

    FallBack Off

}
