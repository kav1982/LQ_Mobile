// NOT-IMPLEMENTED: playable environment-FX shell for MMN/CutScene/Prop_Portal.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/CutScene/Prop_Portal"
{
    Properties
    {
        [Header(Stencil Options)] [Space] _StencilRef ("Stencil Ref", Float) = 1
        [MaterialEnum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Float) = 8
        [MaterialEnum(UnityEngine.Rendering.StencilOp)] _StencilPass ("Stencil Pass", Float) = 2
        [Header(Rendering Options)] [Space] [MaterialEnum(Off, 0, On, 1)] _ZWrite ("ZWrite", Float) = 0
        [MaterialEnum(Off, 0, Front, 1, Back, 2)] _Cull ("Cull", Float) = 2
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry+1"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Base"
            Blend 5 10
            BlendOp Add
            ZWrite [_ZWrite]
            ZTest 4
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"


            CBUFFER_START(UnityPerMaterial)
                float _StencilRef;
                float _StencilComp;
                float _StencilPass;
                float _ZWrite;
                float _Cull;
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
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = half4(1,1,1,1);
                half texAlpha = tex.a;
                half3 color = tex.rgb * i.color.rgb;
                half alpha = saturate(texAlpha * i.color.a);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
