// Recreation of the shipped MMN/Special/PlanarReflectionWater, the shader on
// Colhen_Water_Stagnant_00 (the Colhen bay water plane).
//
// Property list, SubShader/pass structure, tags and render states are 1:1 with the extracted
// contract (_re_work/shader_contracts/MMN_Special_PlanarReflectionWater.contract.json): 25
// properties, two SubShaders (LOD 300 / LOD 100), one pass "Base" each with LightMode "Water",
// Queue Transparent-200, Blend SrcAlpha OneMinusSrcAlpha, ZWrite Off, ZClip Off, Cull Back.
// The shading itself is a reconstruction - see MMN_PlanarReflectionWater.hlsl for what the
// shipped uniform table says the passes do and what is left out.
//
// LightMode "Water" is not one of URP's built-in pass tags, so a RenderObjects renderer feature
// filtering on it has to be present or the water draws nothing. MMN/BeachPreview/Editor sets that
// up on the preview renderer.
Shader "MMN/Special/PlanarReflectionWater"
{
    Properties
    {
        [PerRendererData] _RaycastHarftoneClip ("射线半色调裁剪", Range(0, 1)) = 0
        _ScatterColor1 ("Scatter Color 1", Color) = (0.5,0.8,1,1)
        _ScatterColor2 ("Scatter Color 2", Color) = (0.06,0.2,0.4,1)
        _ScatterColor3 ("Scatter Color 3", Color) = (0,0.02,0.07,1)
        _ScatterDepth2 ("Depth for Scatter Color 2", Float) = 1
        _ScatterDepth3 ("Depth for Scatter Color 3", Float) = 1.6
        _Turbidity ("Turbidity", Range(0, 1)) = 0.5
        _DepthScale ("Depth Scale", Float) = 1
        _FresnelColor ("Fresnel Color", Color) = (0.576471,0.698039,0.8,1)
        _DistortionTexture ("DistortionTexture", 2D) = "black" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamOpacity ("Foam Opacity", Range(0, 1)) = 1
        _FoamOffset ("Foam Offset", Range(-1, 1)) = 0.1
        _FoamEdgeIntensity ("Foam Edge Intensity", Range(0, 2)) = 0
        _FlowSpeed ("Flow Speed", Float) = 1
        _DistortionAmount ("Distortion Amount", Range(0, 1)) = 1
        _BumpMap ("Normal Map ", 2D) = "bump" {}
        [HDR] _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        _SpecualrNormalMulti ("SpecularNormalMultiply", Range(1, 10)) = 1
        [PowerSlider(5.0)] _Glossiness ("Glossiness", Range(1, 256)) = 128
        [Header(Reflection Options)] [Space(10)] [Toggle] _LowOptionEnable ("低配选项（自动生效）", Float) = 0
        [NoScaleOffset] _PlanarReflectionTexture ("反射贴图（请勿修改）", 2D) = "Black" {}
        _ReflectionColor ("反射颜色", Color) = (1,1,1,1)
        _ReflectionPower ("反射距离", Range(1, 50)) = 10
        _ReflectionMipmapLevel ("反射 Mipmap 等级", Range(0, 10)) = 5.4
    }

    SubShader
    {
        LOD 300
        Tags
        {
            "Queue" = "Transparent-200"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "true"
            "PreviewType" = "Plane"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "Base"
            Tags { "LightMode" = "Water" }

            Blend SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            ZClip Off
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment WaterFragment

            #include "../Include/MMN_PlanarReflectionWater.hlsl"
            ENDHLSL
        }
    }

    SubShader
    {
        LOD 100
        Tags
        {
            "Queue" = "Transparent-200"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "true"
            "PreviewType" = "Plane"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "Base"
            Tags { "LightMode" = "Water" }

            Blend SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            ZClip Off
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex WaterVertex
            #pragma fragment WaterFragment

            #define MMN_WATER_LOW
            #include "../Include/MMN_PlanarReflectionWater.hlsl"
            ENDHLSL
        }
    }

    // The shipped shader points CustomEditor at MM.Client.Editor.ShaderGUI.MMN_Reflection_Water,
    // which is not part of the extracted data; left out so Unity does not error per material.
    FallBack Off
}
