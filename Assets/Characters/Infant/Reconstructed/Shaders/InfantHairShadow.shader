Shader "Characters/Infant/Reconstructed/HairShadow"
{
    Properties
    {
        _Color ("Shadow Color", Color) = (0,0,0,0.2)
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp ("Blend Operation", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent-20" }
        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }
            Blend SrcAlpha OneMinusSrcAlpha
            BlendOp [_BlendOp]
            Cull Off
            ZWrite Off
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Attributes { float4 positionOS : POSITION; };
            struct Varyings { float4 positionHCS : SV_POSITION; };
            CBUFFER_START(UnityPerMaterial) half4 _Color; CBUFFER_END
            Varyings Vert(Attributes input) { Varyings output; output.positionHCS = TransformObjectToHClip(input.positionOS.xyz); return output; }
            half4 Frag(Varyings input) : SV_Target { return _Color; }
            ENDHLSL
        }
    }
}
