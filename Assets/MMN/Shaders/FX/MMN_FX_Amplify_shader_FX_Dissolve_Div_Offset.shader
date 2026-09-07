// Playable approximation of MMN/FX/Amplify shader/FX_Dissolve_Div_Offset.
// Properties and render states follow the extracted original contract.
//
// Fragment keeps AlphaTex + Custom1.yz offset. Noise is a small UV warp, not an alpha
// multiply — multiplying Worley noise scrolled the texture seam as a stripe on wind cards.
//
// Custom vertex streams (fx_wind_01: UV + Custom1XYZ) pack as
//   TEXCOORD0.xy = mesh UV
//   TEXCOORD0.z  = Custom1.x dissolve
//   TEXCOORD0.w  = Custom1.y AlphaTex offset X
//   TEXCOORD1.x  = Custom1.z AlphaTex offset Y
//
// NOT-IMPLEMENTED: original DXBC dissolve / offset / twist maths (no 1:1 transcription).
// NOT-IMPLEMENTED: FOG_LINEAR, DEBUG_DISPLAY, ShadowCaster, _AlphaCutoff, _EmissionColor.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Offset"
{
    Properties
    {
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
        _Mode ("Mode", Float) = -1
        _TransitionValue ("TransitionValue", Range(0, 1)) = 1
        _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        _RaycastMinimumAlpha ("minimumAlpha", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 18)) = 0
        _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] _LightReceive ("LightReceive", Range(0, 1)) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        [ToggleUI] _FogReceive ("FogReceive", Range(0, 1)) = 0
        _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle( _RAYCAST_ON )] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(Custom.1.x     Dissolve)] [Header(Custom.1.y     AlphaTex Offset X )] [Header(Custom.1.z     AlphaTex Offset Y )] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        _MainTex_ST ("MainTex_ST", Vector) = (1,1,0,0)
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Toggle] _Use_Offset_Power ("Use_Offset_Power", Float) = 0
        [Enum(UV,0,Polar,1)] _UVType ("UV Type", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _NoiseTex_ST ("NoiseTex_ST", Vector) = (1,1,0,0)
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        _AlphaTex_ST ("AlphaTex_ST", Vector) = (1,1,0,0)
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (1,1,1,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Lerp Color)] [Space()] _LerpColor ("Lerp Color", Color) = (1,1,1,1)
        _LerpColor_Offset ("LerpColor_Offset", Float) = 0
        _LerpColor_Range ("LerpColor_Range", Float) = 0
        [Space()] _LerpColor_Intensity ("LerpColor_Intensity", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        _EffectAlpha ("EffectAlpha", Float) = 1
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
            Name "Unlit"
            Blend [_BlendSrc] [_BlendDst]
            BlendOp Add
            ZWrite Off
            ZTest [_ZTest]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _RAYCAST_ON

            #define MMN_FX_USE_DEPTH

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_AlphaTex); SAMPLER(sampler_AlphaTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _EmissionColor;
                float _AlphaCutoff;
                float _Mode;
                float _TransitionValue;
                float _SpawnTransition;
                float _RaycastHarftoneClip;
                float _RaycastMinimumAlpha;
                float _NearPlaneAlpha;
                float4 _NearPlaneAlphaEdge;
                float _NearPlaneInvertDistance;
                float _NearPlaneDirectionMode;
                float _NearPlaneDitherMode;
                float _LightReceive;
                float _LightRatio;
                float _SoftParticle;
                float _SoftParticleNearFadeDistance;
                float _SoftParticleFarFadeDistance;
                float _FogReceive;
                float _SoftParticleFadeOutRange;
                float _Raycast;
                float4 _NearPlaneDirectionValue;
                float4 _MainTex_ST;
                float _Use_G_Channel_Alpha;
                float _Use_Offset_Power;
                float _UVType;
                float4 _NoiseTex_ST;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                float4 _AlphaTex_ST;
                float _ColorGradation;
                float4 _MainColor;
                float4 _SubColor;
                float _Color_Offset;
                float _Color_Range;
                float4 _LerpColor;
                float _LerpColor_Offset;
                float _LerpColor_Range;
                float _LerpColor_Intensity;
                float _Intensity_Color;
                float _Intensity_Alpha;
                float _BlendSrc;
                float _BlendDst;
                float _ZTest;
                float _CullMode;
                float _EffectAlpha;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 color : COLOR;
            };

            float2 MMN_PolarUV(float2 uv, float4 st)
            {
                float2 centered = uv - 0.5;
                float radius = length(centered);
                float angle = atan2(centered.y, centered.x) * 0.159155;
                return float2(st.x * radius + st.z, angle * st.y + st.w);
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs positions = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float time = MMN_FxTime();
                half dissolve = (half)i.uv0.z;
                float2 alphaOffset = float2(i.uv0.w, i.uv1.x);
                // _Use_Offset_Power is unused on FX_Wind_01 (0). Kept as a no-op scale so
                // materials that turn it on do not lose the Custom1 offset entirely.
                alphaOffset *= lerp(1.0, abs(alphaOffset) + 1.0, _Use_Offset_Power);

                float2 noiseCart = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseCart.y = noiseCart.x * _Twist + noiseCart.y;
                float2 noiseUV = lerp(noiseCart, MMN_PolarUV(i.uv0.xy, _NoiseTex_ST), _UVType);
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half2 noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).rg;
                // Verify path: do not multiply noise into alpha (that punched Worley holes /
                // scrolled the noise-texture seam as a stripe). Use it as a small UV warp.
                float warpScale = lerp(0.06, 0.15, _Use_Offset_Power);
                float2 warp = (noise - 0.5) * warpScale;

                float2 mainCart = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw + warp;
                float2 mainUV = lerp(mainCart, MMN_PolarUV(i.uv0.xy + warp, _MainTex_ST), _UVType);
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 alphaCart = i.uv0.xy * _AlphaTex_ST.xy + _AlphaTex_ST.zw + alphaOffset;
                float2 alphaUV = lerp(alphaCart, MMN_PolarUV(i.uv0.xy + alphaOffset, _AlphaTex_ST), _UVType);
                // Gradation cards are imported Clamp on U; Custom1.y travels 1 → -1, which
                // would otherwise stick on the black edge. Wrap so the soft band can slide.
                alphaUV = frac(alphaUV);
                half alphaTex = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).g;

                half mask = mainAlpha * alphaTex - dissolve;
                half gradeSrc = lerp(mask, (half)mainUV.x, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 texColor = lerp(mainTex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                half3 color = texColor * (tint.rgb * _Intensity_Color);

                half lerpAmt = saturate((gradeSrc + _LerpColor_Offset) * _LerpColor_Range);
                color = lerp(color, _LerpColor.rgb * _LerpColor_Intensity, lerpAmt);

                // _Intensity_Alpha is 20 on wind cards and turns a 1-texel bilinear
                // falloff into a hard step. AA the raw value so fishbone stairs soften.
                half rawAlpha = mask / max(1.0h - dissolve, 1e-3h) * _Intensity_Alpha;
                half aa = max(fwidth(rawAlpha), 0.25h);
                half alpha = saturate(smoothstep(0.0h, aa * 2.0h, rawAlpha))
                           * (tint.a * i.color.a) * saturate(_EffectAlpha);

                alpha *= MMN_NearPlaneFade(i.positionWS, i.screenPos, _NearPlaneAlpha,
                                           _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                           _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                           _RaycastMinimumAlpha, _NearPlaneDitherMode);
                #ifdef _RAYCAST_ON
                    alpha *= saturate(max(1.0h - _RaycastHarftoneClip, _RaycastMinimumAlpha));
                #endif

                color = MMN_LightReceive(color, _LightReceive, _LightRatio);
                alpha *= MMN_SoftParticleFade(i.screenPos, _SoftParticle,
                                              _SoftParticleNearFadeDistance,
                                              _SoftParticleFarFadeDistance,
                                              _SoftParticleFadeOutRange);

                MMN_ApplyModeTransition(color, alpha, _Mode, _TransitionValue, _SpawnTransition);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
