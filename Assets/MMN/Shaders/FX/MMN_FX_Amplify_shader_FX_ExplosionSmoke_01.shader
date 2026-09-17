// Transcribed from shipped D3D11 bytecode
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_ExplosionSmoke_01.asm.txt).
// TEXCOORD0.z = dissolve, TEXCOORD0.w = fire-color offset.
Shader "MMN/FX/Amplify shader/FX_ExplosionSmoke_01"
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
        [Toggle(_RAYCAST_ON)] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(tcd0.z     Dissolve)] [Header(tcd0.w     FireColor Offset)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        [Header(Color)] [Space()] _FireColor ("Fire Color", Color) = (0.501961,0.501961,0.501961,1)
        _Color_Range ("Color_Range", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrcA ("Blend Src Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
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
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_AlphaTex); SAMPLER(sampler_AlphaTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _AlphaTex_ST;
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
                float _Use_G_Channel_Alpha;
                float4 _FireColor;
                float _Color_Range;
                float _Intensity_Color;
                float _Intensity_Alpha;
                float _BlendSrc;
                float _BlendDst;
                float _BlendSrcA;
                float _CullMode;
                float _ZTest;
                float _EffectAlpha;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float4 uv0 : TEXCOORD0; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float4 uv0 : TEXCOORD0; float4 screenPos : TEXCOORD1; float3 positionWS : TEXCOORD2; float4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv0 = v.uv0;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                half2 mainGA = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV).ga;
                half4 tint = mainGA.y * i.color;
                half grade = saturate((mainGA.x + i.uv0.w) * _Color_Range);
                tint = lerp(tint, _FireColor, grade);
                half texAlpha = lerp(mainGA.y, mainGA.x, _Use_G_Channel_Alpha);
                float2 alphaUV = i.uv0.xy * _AlphaTex_ST.xy + _AlphaTex_ST.zw;
                half dissolve = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).r + i.uv0.z;
                half mask = saturate(texAlpha * (1.0h - dissolve));
                mask = mask * mask * (3.0h - 2.0h * mask);
                half3 color = tint.rgb * _Intensity_Color;
                half alpha = saturate(mask * _Intensity_Alpha) * tint.a * i.color.a * saturate(_EffectAlpha);
                alpha *= MMN_NearPlaneFade(i.positionWS, i.screenPos, _NearPlaneAlpha,
                                           _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                           _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                           _RaycastMinimumAlpha, _NearPlaneDitherMode);
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
