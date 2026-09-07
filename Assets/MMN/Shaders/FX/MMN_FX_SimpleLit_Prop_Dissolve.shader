// NOT-IMPLEMENTED: playable environment-FX shell for MMN/FX/SimpleLit_Prop_Dissolve.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/FX/SimpleLit_Prop_Dissolve"
{
    Properties
    {
        [Toggle] _ALPHATEST ("알파테스트", Float) = 0
        [Toggle] _BackFaceNormalturn ("백페이스 노말을 돌려서 뒷면도 노말을 앞으로 생성한다", Float) = 0
        _RaycastHarftoneClip ("레이케스트 하프톤 클립", Range(0, 1)) = 0
        _VertexColorWeight ("버텍스 칼라 영향력 가중치", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("Show Vertex Color(확인용)", Float) = 0
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _RampY ("RampY", Range(0, 1)) = 0.5
        [ToggleUI] _ReceiveShadows ("Receive Shadows", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        [Header(Stencil Options)] [Space] _StencilRef ("Stencil Ref", Float) = 0
        [MaterialEnum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Float) = 0
        [MaterialEnum(UnityEngine.Rendering.StencilOp)] _StencilPass ("Stencil Pass", Float) = 0
        [Header(Dissolve Options)] _DissolveAmount ("디졸브 진행도", Range(-30, 30)) = 0
        _DissolveDirection ("디졸브 진행방향", Vector) = (0,-1,0,0)
        [Toggle(_CUSTOMDATA_ON)] _Customdata ("커스텀 데이터 적용", Float) = 0
        _NoiseTex ("디졸브 텍스쳐", 2D) = "white" {}
        _NoiseTexScale ("디졸브 텍스쳐의 크기", Range(0.1, 10)) = 4
        [Toggle] _NoiseCutoff ("디졸브 컷오프를 켤까요?", Float) = 1
        _NoiseCutoffSmoothness ("컷오프의 부드러움", Range(0, 0.5)) = 0.1
        _DissolveColor ("디졸브 색상", Color) = (0,0,0,0)
        _DissolveWidth ("디졸브 두께", Range(0, 5)) = 1
        _DissolveEdgeColor ("디졸브 경계의 색상", Color) = (1,1,1,1)
        _DissolveEdgeWidth ("디졸브 경계의 두께", Range(0, 0.5)) = 0.2
        _VertexAniOn ("버텍스 애니를 켠다", Float) = 1
        _WindMultiply ("_WindMultiply", Float) = 0
        _WindSpeedMultiply ("_WindSpeedMultiply", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardLit"
            Blend 1 0
            BlendOp Add
            ZWrite On
            ZTest 4
            Cull 2

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _NoiseTex_ST;
                float _ALPHATEST;
                float _BackFaceNormalturn;
                float _RaycastHarftoneClip;
                float _VertexColorWeight;
                float _ShowVertexColor;
                float4 _BaseColor;
                float _AlbedoTintStrength;
                float _Cutoff;
                float _RampY;
                float _ReceiveShadows;
                float _QueueOffset;
                float _StencilRef;
                float _StencilComp;
                float _StencilPass;
                float _DissolveAmount;
                float4 _DissolveDirection;
                float _Customdata;
                float _NoiseTexScale;
                float _NoiseCutoff;
                float _NoiseCutoffSmoothness;
                float4 _DissolveColor;
                float _DissolveWidth;
                float4 _DissolveEdgeColor;
                float _DissolveEdgeWidth;
                float _VertexAniOn;
                float _WindMultiply;
                float _WindSpeedMultiply;
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
                o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half texAlpha = tex.a;
                half3 color = tex.rgb * i.color.rgb;
                half alpha = saturate(texAlpha * i.color.a);
                return half4(color, 1);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
