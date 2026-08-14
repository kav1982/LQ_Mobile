Shader "Characters/Infant/Reconstructed/EyeEmotion"
{
    Properties
    {
        _EyeballTexture ("Eye Emotion Atlas", 2D) = "white" {}
        _Alpha ("Alpha", Range(0,1)) = 1
        _EyeballTextureRowNum ("Rows", Float) = 1
        _EyeballTextureColNum ("Columns", Float) = 1
        _EyeballIndexFromOne ("Expression Index", Float) = 1
        _LeftEyeball_TS ("Left Eye Transform", Vector) = (0,0,1,1)
        _RightEyeball_TS ("Right Eye Transform", Vector) = (0,0,1,1)
        _EyePositionOffset ("Eye Position Offset", Vector) = (0,0,0,0)
        _EyeRotationOffset ("Eye Rotation", Float) = 0
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.02
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent+20" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; };
            struct Varyings { float4 positionHCS : SV_POSITION; float2 uv : TEXCOORD0; };
            TEXTURE2D(_EyeballTexture); SAMPLER(sampler_EyeballTexture);
            CBUFFER_START(UnityPerMaterial)
                float4 _EyeballTexture_ST;
                float4 _LeftEyeball_TS;
                float4 _RightEyeball_TS;
                float4 _EyePositionOffset;
                half _Alpha;
                half _EyeballTextureRowNum;
                half _EyeballTextureColNum;
                half _EyeballIndexFromOne;
                half _EyeRotationOffset;
                half _Cutoff;
            CBUFFER_END
            Varyings Vert(Attributes input) { Varyings output; output.positionHCS = TransformObjectToHClip(input.positionOS.xyz); output.uv = input.uv; return output; }
            half4 Frag(Varyings input) : SV_Target
            {
                float columns = max(_EyeballTextureColNum, 2.0h);
                float rows = max(_EyeballTextureRowNum, 1.0h);
                float pairsPerRow = max(columns * 0.5, 1.0);
                float pairIndex = max(_EyeballIndexFromOne - 1.0h, 0.0h);
                float pairColumn = fmod(pairIndex, pairsPerRow) * 2.0;
                float row = floor(pairIndex / pairsPerRow);
                float rightEye = step(0.5, input.uv.x);
                float2 localUV = float2(frac(input.uv.x * 2.0), input.uv.y);
                float4 eyeTransform = lerp(_LeftEyeball_TS, _RightEyeball_TS, rightEye);
                localUV = (localUV - 0.5) * eyeTransform.zw + 0.5 + eyeTransform.xy + _EyePositionOffset.xy;
                float2 atlasUV = (localUV + float2(pairColumn + rightEye, rows - 1.0 - row)) / float2(columns, rows);
                half4 color = SAMPLE_TEXTURE2D(_EyeballTexture, sampler_EyeballTexture, atlasUV);
                color.a *= _Alpha;
                clip(color.a - _Cutoff);
                return color;
            }
            ENDHLSL
        }
    }
}
