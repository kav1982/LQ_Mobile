Shader "MMN/BG/Waterfall"
{
                    Properties
    {
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        _ScatterColor2 ("Scatter Color 2", Color) = (0.06,0.2,0.4,1)
        _Turbidity ("Turbidity", Range(0, 1)) = 0.5
        _FresnelColor ("Fresnel Color", Color) = (0.576471,0.698039,0.8,1)
        _VertexFlowSpeed ("顶点流动速度", Float) = 3
        _VertexFlowCrmpled ("顶点流动褶皱", Range(0, 1)) = 0.3
        _DistortionTexture ("DistortionTexture", 2D) = "black" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamOpacity ("Foam Opacity", Range(0, 1)) = 1
        _FoamOffset ("Foam Offset", Range(-1, 1)) = 0.1
        _FlowSpeed ("Flow Speed", Float) = 1
        _BumpMap ("Normal Map ", 2D) = "bump" {}
        _DistortionAmount ("Distortion Amount", Range(0, 1)) = 1
        _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        [PowerSlider(5.0)] _Glossiness ("Glossiness", Range(1, 256)) = 128
        // Legacy preview properties still consumed by current HLSL.
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (0.7,0.85,1,0.6)
        _ScrollSpeed ("Scroll Speed", Vector) = (0,-0.4,0,0)
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
