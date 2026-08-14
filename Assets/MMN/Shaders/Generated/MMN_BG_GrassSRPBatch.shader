Shader "MMN/BG/GrassSRPBatch"
{
    // NOT-IMPLEMENTED: generated compatibility shell; original HLSL unavailable.
                Properties
    {
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        [Toggle] _ALPHATEST ("Alpha Test", Float) = 1
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _TopColor ("TopColor(VertexColor G)", Color) = (0,0,0,0)
        _ShadowDim ("ShadowDimming（阴影影响）", Range(0, 1)) = 0
        _GlobalTextureBlending ("GlobalTextureBlending", Range(0, 1)) = 0
        _TextureBlendingScroll ("TextureBlendingScroll（跟随云层速度）", Range(0, 2)) = 0.1
        _TextureBlendingWeight ("TextureBlendingWeight（全局贴图权重）", Range(-1, 1)) = 0
        [Toggle] _ShowGlobalTexture ("显示全局贴图（调试）", Float) = 0
        _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        [PowerSlider(10)] _Glossiness ("Smoothness", Range(0.1, 1)) = 0.5
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        _WindMultiply ("Wind Multiply（风细节）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速权重）", Range(0, 40)) = 7
        _GrassPushPower ("GrassPushPower（推力影响）", Float) = 1
        [Toggle] _VertexAniOff ("强制关闭顶点动画", Float) = 0
        _Surface ("__surface", Float) = 0
        _Blend ("__blend", Float) = 0
        _AlphaClip ("__clip", Float) = 0
        _SrcBlend ("__src", Float) = 1
        _DstBlend ("__dst", Float) = 0
        _ZWrite ("__zw", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _Smoothness ("SMoothness", Float) = 0.5
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        _GrassVisualRange ("最大可见距离", Range(-10, 10)) = 0
        [Toggle] _GrassVisualActionToggle ("启用草出现/消失演出", Float) = 1
        _InstancingColor ("_Instancing Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }
        LOD 100
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "ForwardLit" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 positionOS : POSITION; };
            float4 vert(A v) : SV_POSITION { return TransformObjectToHClip(v.positionOS.xyz); }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 positionOS : POSITION; };
            float4 vert(A v) : SV_POSITION { return TransformObjectToHClip(v.positionOS.xyz); }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
        Pass
        {
            Name "BaseSSAOMask"
            Tags { "LightMode" = "BaseSSAOMask" }
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
