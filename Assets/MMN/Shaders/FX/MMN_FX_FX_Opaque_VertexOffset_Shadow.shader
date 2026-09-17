// NOT-IMPLEMENTED: playable environment-FX shell for MMN/FX/FX_Opaque_VertexOffset_Shadow.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/FX/FX_Opaque_VertexOffset_Shadow"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] [Header(Z Buffer)] [Space(10)] _CullMode ("Cull Mode", Float) = 0
        [ToggleUI] [Space(10)] _LightReceive ("LightReceive", Range(0, 1)) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] _FogReceive ("FogReceive", Range(0, 1)) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 0
        [Enum(ParticleSystem, 0, Generic, 1)] _OffsetMode ("오프셋 모드 설정", Float) = 0
        [Header(Base Color Settings)] [Space()] _MainTex (" 메인 텍스처 (RGB : 색상 / A : 알파 컷오프)", 2D) = "white" {}
        _Color ("기본 컬러", Color) = (1,1,1,1)
        _Intensity_Color ("기본 컬러 강도", Float) = 1
        _AlphaCutoff ("알파 컷오프 (메인 텍스처 A 채널 사용)", Range(0, 1)) = 0.5
        [Header(Fresnel)] [Space(10)] _FresnelColor ("프레넬 컬러", Color) = (0,0,0,1)
        [PowerSlider(2)] _FresnelRange ("프레넬 범위", Range(0, 10)) = 2
        [PowerSlider(2)] _FresnelPower ("프레넬 파워", Range(0, 20)) = 10
        [Space(10)] [Header(Vertex Movment Settings)] [Space()] _Sphereofinfluence ("움직임 영향력 범위", Range(0, 0.9)) = 0.9
        _VelocityVector ("움직일 방향 축 설정", Vector) = (0,1,0,0)
        _TimeSpeed ("움직임 속도", Float) = 1
        _Threshold ("움직임 강도", Float) = 10
        _SinScope ("움직임 노이즈 조절", Float) = 20
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Base"
            Blend One Zero
            BlendOp Add
            ZWrite On
            ZTest [_ZTest]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _CullMode;
                float _LightReceive;
                float _LightRatio;
                float _FogReceive;
                float _ZTest;
                float _OffsetMode;
                float4 _Color;
                float _Intensity_Color;
                float _AlphaCutoff;
                float4 _FresnelColor;
                float _FresnelRange;
                float _FresnelPower;
                float _Sphereofinfluence;
                float4 _VelocityVector;
                float _TimeSpeed;
                float _Threshold;
                float _SinScope;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float4 screenPos : TEXCOORD1; float3 positionWS : TEXCOORD2; float4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half texAlpha = tex.a;
                half3 color = tex.rgb * i.color.rgb;
                color *= _Intensity_Color;
                color *= _Color.rgb;
                half alpha = saturate(texAlpha * i.color.a * _Color.a);
                color = MMN_LightReceive(color, _LightReceive, _LightRatio);
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
