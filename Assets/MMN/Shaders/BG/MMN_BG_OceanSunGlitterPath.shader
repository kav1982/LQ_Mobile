// Recreation of the shipped MMN/BG/OceanSunGlitterPath, the shader on
// fx_sunglitterpath_01 (ocean sun-glitter ribbon).
//
// Properties, tags and render states are 1:1 with
// Assets/MMN/Shaders/Contracts/Original/MMN_BG_OceanSunGlitterPath.contract.json:
// 19 properties, LOD 300 + LOD 100, pass "ForwardLit", LightMode UniversalForward,
// Queue Transparent, Blend SrcAlpha One, ZWrite Off, ZTest LEqual, Cull Back.
//
// The shipped GPU programs were not in the contract, so the path / sparkle maths
// below is reconstructed from the property block (timeline, world-space sun,
// width spread, noise sparkles) rather than transcribed bytecode.
Shader "MMN/BG/OceanSunGlitterPath"
{
    Properties
    {
        [Header(Base Settings)]
        _NoiseTex ("노이즈 텍스처", 2D) = "white" {}
        [HDR] _TintColor ("틴트 컬러", Color) = (1, 0.8, 0.4, 1)
        _SunProgress ("진행도 (Time)", Range(0, 1)) = 0
        _SunPositionWS ("해의 위치 (World Space)", Vector) = (866, 0, 470, 0)

        [Space(10)]
        [Header(Timeline Controls)]
        _ReachThreshold ("도달 완료 타이밍 (0~1)", Range(0.01, 1)) = 0.3
        _SpreadThreshold ("퍼짐 시작 타이밍 (0~1)", Range(0, 1)) = 0.5
        _FadeThreshold ("페이드아웃 시작 타이밍 (0~1)", Range(0, 1)) = 0.8

        [Space(10)]
        [Header(Shape Settings)]
        _GlitterWidth ("기본 폭 (값 클수록 넓어짐)", Float) = 1
        _SpreadWidth ("퍼질 때 폭 (값 클수록 넓어짐)", Float) = 5
        _InitialIntensity ("초기 밝기 (퍼지기 전)", Float) = 1
        _SpreadIntensity ("퍼질 때 가장자리 밝기", Float) = 1
        _SpreadDuration ("퍼지는 데 걸리는 시간", Float) = 0.25
        _SpreadDimPower ("퍼질 때 감광 가속도 (낮을수록 빠름)", Range(0.01, 2)) = 0.3

        [Space(10)]
        [Header(Sparkle Settings)]
        _SparkleScale ("반짝임 입자 크기", Float) = 5
        _SparkleDensity ("반짝임 밀도 (낮을수록 꽉 참)", Range(0, 1)) = 0.4
        _SparkleSpeed ("반짝임 속도", Float) = 0.2

        [Space(10)]
        [Header(Highlight Movement)]
        _PeakStartRatio ("이동 시작 비율 (Reach 기준)", Float) = 0.35
        _PeakEndRatio ("이동 종료 비율 (Reach 기준)", Float) = 1.3
        _PeakTargetPos ("최종 도달 위치 (0~1)", Range(0, 1)) = 0.5
    }

    SubShader
    {
        LOD 300
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "true"
            "PreviewType" = "Plane"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One, SrcAlpha One
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #include "MMN_BG_OceanSunGlitterPath.hlsl"
            ENDHLSL
        }
    }

    SubShader
    {
        LOD 100
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "true"
            "PreviewType" = "Plane"
            "ShaderModel" = "2.0"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha One, SrcAlpha One
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex vert
            #pragma fragment frag
            #include "MMN_BG_OceanSunGlitterPath.hlsl"
            ENDHLSL
        }
    }
}
