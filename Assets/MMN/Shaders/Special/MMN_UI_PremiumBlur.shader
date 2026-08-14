Shader "MMN/Repro/UI Premium Blur"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 1
        [PerRendererData] _MainTex ("Texture", 2D) = "white" {}
        _MaskTex ("Mask", 2D) = "white" {}
        [IntRange] _KernelSize ("KernelSize", Range(1, 28)) = 4
        _SampleSpacing ("SampleSpacing", Range(1, 16)) = 4
        _Sigma ("Sigma", Range(0.001, 10)) = 2
        _LevelFrom ("Level (From)", Range(0, 1)) = 0
        _LevelTo ("Level (To)", Range(0, 1)) = 0.5

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255
        _ColorMask ("Color Mask", Float) = 15
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
        Blend [_BlendSrc] [_BlendDst]
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"

            CGPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
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
            float4 _MainTex_TexelSize;
            sampler2D _MaskTex;
            sampler2D _MMNPremiumBlurTexture;
            sampler2D _MMNPremiumBlurMaskTexture;
            float4 _ClipRect;
            float _KernelSize;
            float _SampleSpacing;
            float _Sigma;
            float _LevelFrom;
            float _LevelTo;
            float _MMNPremiumBlurAvailable;
            float _MMNPremiumBlurUseMask;
            float _MMNPremiumBlurLevelFrom;
            float _MMNPremiumBlurLevelTo;

            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.worldPosition = input.vertex;
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.color = input.color;
                return output;
            }

            fixed4 Frag(Varyings input) : SV_Target
            {
                float sigma = max(_Sigma, 0.001);
                float2 spacing = _MainTex_TexelSize.xy * _SampleSpacing;
                int radius = clamp((int)ceil(_KernelSize * 0.5), 1, 14);
                float totalWeight = 1.0;
                fixed4 blurred = tex2D(_MainTex, input.uv);

                [unroll]
                for (int index = 1; index <= 14; index++)
                {
                    if (index > radius) break;
                    float weight = exp(-0.5 * index * index / (sigma * sigma));
                    float2 offsetX = float2(spacing.x * index, 0.0);
                    float2 offsetY = float2(0.0, spacing.y * index);
                    blurred += tex2D(_MainTex, input.uv + offsetX) * weight;
                    blurred += tex2D(_MainTex, input.uv - offsetX) * weight;
                    blurred += tex2D(_MainTex, input.uv + offsetY) * weight;
                    blurred += tex2D(_MainTex, input.uv - offsetY) * weight;
                    totalWeight += weight * 4.0;
                }

                fixed4 source = tex2D(_MainTex, input.uv);
                blurred /= totalWeight;

                float mask;
                float levelFrom;
                float levelTo;
                if (_MMNPremiumBlurAvailable > 0.5)
                {
                    blurred = tex2D(_MMNPremiumBlurTexture, input.uv);
                    mask = _MMNPremiumBlurUseMask > 0.5
                        ? tex2D(_MMNPremiumBlurMaskTexture, input.uv).r
                        : tex2D(_MaskTex, input.uv).r;
                    levelFrom = _MMNPremiumBlurLevelFrom;
                    levelTo = _MMNPremiumBlurLevelTo;
                }
                else
                {
                    mask = tex2D(_MaskTex, input.uv).r;
                    levelFrom = _LevelFrom;
                    levelTo = _LevelTo;
                }

                float upper = max(levelTo, levelFrom + 0.0001);
                float blendAmount = smoothstep(levelFrom, upper, mask);
                fixed4 color = lerp(source, blurred, blendAmount) * input.color;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(input.worldPosition.xy, _ClipRect);
                #endif

                return color;
            }
            ENDCG
        }
    }
}
