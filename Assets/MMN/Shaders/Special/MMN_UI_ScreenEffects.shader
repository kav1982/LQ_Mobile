Shader "MMN/Repro/UI Screen Effects"
{
    Properties
    {
        [PerRendererData] _MainTex ("Texture", 2D) = "white" {}
        [Enum(Circular, 0, Wave, 1, Wipe, 2, Blackout, 3, Vignetting, 4)] _EffectMode ("Effect Mode", Float) = 0
        _TransitionProgress ("Transition Progress", Range(0, 1)) = 0
        _Inverse ("Inverse", Range(-1, 1)) = 1
        _Color ("Effect Color", Color) = (0, 0, 0, 1)
        _Softness ("Edge Softness", Range(0.001, 0.2)) = 0.02
        _WaveAmplitude ("Wave Amplitude", Range(0, 0.25)) = 0.04
        _WaveFrequency ("Wave Frequency", Range(1, 32)) = 12
        _VignettingRange ("Vignetting Range", Range(0, 1)) = 0.567
        _VignettingSmooth ("Vignetting Smooth", Range(0.001, 1)) = 0.18

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"

            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP
            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            struct Attributes
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _Color;
            float4 _ClipRect;
            float _EffectMode;
            float _TransitionProgress;
            float _Inverse;
            float _Softness;
            float _WaveAmplitude;
            float _WaveFrequency;
            float _VignettingRange;
            float _VignettingSmooth;

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.worldPosition = input.vertex;
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = input.color;
                return output;
            }

            float TransitionMask(float2 uv)
            {
                float progress = saturate(_TransitionProgress);
                float softness = max(_Softness, 0.001);

                if (_EffectMode < 0.5)
                {
                    float aspect = _ScreenParams.x / max(_ScreenParams.y, 1.0);
                    float2 centered = uv - 0.5;
                    centered.x *= aspect;
                    float maximumRadius = length(float2(0.5 * aspect, 0.5));
                    float radius = lerp(-softness, maximumRadius + softness, progress);
                    return 1.0 - smoothstep(radius - softness, radius + softness, length(centered));
                }

                float directionUv = _Inverse < 0.0 ? 1.0 - uv.x : uv.x;
                if (_EffectMode < 1.5)
                {
                    if (progress <= 0.0) return 0.0;
                    if (progress >= 1.0) return 1.0;
                    float boundary = progress + sin(uv.y * _WaveFrequency * 6.2831853) * _WaveAmplitude;
                    return 1.0 - smoothstep(boundary - softness, boundary + softness, directionUv);
                }

                if (_EffectMode < 2.5)
                    return 1.0 - smoothstep(progress - softness, progress + softness, directionUv);

                if (_EffectMode < 3.5)
                    return progress;

                float2 centered = uv * 2.0 - 1.0;
                return smoothstep(
                    saturate(_VignettingRange),
                    saturate(_VignettingRange + max(_VignettingSmooth, 0.001)),
                    length(centered)) * progress;
            }

            fixed4 Frag(Varyings input) : SV_Target
            {
                fixed4 source = tex2D(_MainTex, input.uv) * input.color;
                fixed4 color = fixed4(_Color.rgb * source.rgb, _Color.a * source.a * TransitionMask(input.uv));

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(input.worldPosition.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip(color.a - 0.001);
                #endif

                return color;
            }
            ENDCG
        }
    }
}
