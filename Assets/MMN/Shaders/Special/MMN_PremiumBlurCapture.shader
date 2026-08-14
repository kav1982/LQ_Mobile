Shader "Hidden/MMN/PremiumBlurCapture"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZTest Always
        ZWrite Off
        Cull Off

        HLSLINCLUDE
        #pragma target 3.0
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

        float _BlurRadius;
        float _SampleSpacing;
        float _Sigma;

        half4 Blur(Varyings input, float2 direction)
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            float sigma = max(_Sigma, 0.001);
            float2 texelSize = rcp(max(_BlitTextureSize, 1.0));
            int radius = clamp((int)_BlurRadius, 1, 14);
            half4 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord);
            float totalWeight = 1.0;

            [unroll]
            for (int index = 1; index <= 14; index++)
            {
                if (index > radius) break;
                float weight = exp(-0.5 * index * index / (sigma * sigma));
                float2 offset = direction * texelSize * (_SampleSpacing * index);
                color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord + offset) * weight;
                color += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_LinearClamp, input.texcoord - offset) * weight;
                totalWeight += weight * 2.0;
            }

            return color / totalWeight;
        }

        half4 FragHorizontal(Varyings input) : SV_Target
        {
            return Blur(input, float2(1.0, 0.0));
        }

        half4 FragVertical(Varyings input) : SV_Target
        {
            return Blur(input, float2(0.0, 1.0));
        }
        ENDHLSL

        Pass
        {
            Name "Horizontal"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragHorizontal
            ENDHLSL
        }

        Pass
        {
            Name "Vertical"
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment FragVertical
            ENDHLSL
        }
    }
}
