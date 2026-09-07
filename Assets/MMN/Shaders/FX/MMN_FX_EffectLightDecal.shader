// NOT-IMPLEMENTED: playable environment-FX shell for MMN/FX/EffectLightDecal.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/FX/EffectLightDecal"
{
    Properties
    {
        _EffectLightColor ("EffectLightColor", Color) = (1,1,1,1)
        _EffectLightIntensity ("EffectLightIntensity", Float) = 1
        _BrightnessLimit ("BrightnessLimit", Float) = 1
        [Toggle] _IsParticle ("IsParticle", Float) = 1
        _worldPosition ("worldPosition", Vector) = (0,0,0,0)
        _worldScaleAndRotY ("worldScaleAndRotY", Vector) = (1,1,1,0)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Base"
            Blend 1 1
            BlendOp Add
            ZWrite Off
            ZTest 8
            Cull 1

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
                float4 _EffectLightColor;
                float _EffectLightIntensity;
                float _BrightnessLimit;
                float _IsParticle;
                float4 _worldPosition;
                float4 _worldScaleAndRotY;
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
