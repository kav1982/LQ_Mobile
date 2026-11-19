// Transcribed from shipped D3D11 bytecode
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_ExplosionSmoke_03.asm.txt).
// tcd0.z dissolve, tcd0.w emissive dissolve, tcd1.x distortion.
Shader "MMN/FX/Amplify shader/FX_ExplosionSmoke_03"
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
        [Header(tcd0.z      Dissolve)] [Header(tcd0.w     Emissive Dissolve)] [Header(tcd1.x       AlpSub Sensitivity)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [ToggleUI] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [ToggleUI] _Use_Polar_UV ("Use_Polar_UV", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        _Polar_Radial ("Polar_Radial", Float) = 1
        _Polar_Lengh ("Polar_Lengh", Float) = 1
        [Space()] _Alp_X_Speed ("Alp_ X_Speed", Float) = 0
        _Alp_Y_Speed ("Alp_Y_Speed", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = -0.5
        [Space()] _Noise_X_Speed ("Noise_X_Speed", Float) = 0
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        _Pivot ("Pivot", Float) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
        [Header(Emissiv Color)] [Space()] _Emissiv_MainColor ("Emissiv_Main Color", Color) = (1,1,1,1)
        _Emissiv_SubColor ("Emissiv_Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Smoke Color)] [Space()] _Smoke_MainColor ("Smoke_Main Color", Color) = (1,1,1,1)
        _Smoke_SubColor ("Smoke_Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset2 ("Color_Offset2", Float) = 0
        _Color_Range2 ("Color_Range2", Float) = 1
        [Header(Intensity)] [Space()] _Emissiv_Color ("Emissiv_Color", Float) = 1
        _Emissiv_Alpha ("Emissiv_Alpha", Float) = 1
        [Space()] _Smoke_Alpha ("Smoke_Alpha", Float) = 1
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
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _AlphaTex_ST;
                float4 _NoiseTex_ST;
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
                float _Use_Polar_UV;
                float _Polar_Radial;
                float _Polar_Lengh;
                float _Alp_X_Speed;
                float _Alp_Y_Speed;
                float _Distortion_Offset;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _BlendSrc;
                float _BlendDst;
                float _Pivot;
                float _CullMode;
                float _ZTest;
                float4 _Emissiv_MainColor;
                float4 _Emissiv_SubColor;
                float _Color_Offset;
                float _Color_Range;
                float4 _Smoke_MainColor;
                float4 _Smoke_SubColor;
                float _Color_Offset2;
                float _Color_Range2;
                float _Emissiv_Color;
                float _Emissiv_Alpha;
                float _Smoke_Alpha;
                float _EffectAlpha;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float4 uv0 : TEXCOORD0; float4 uv1 : TEXCOORD1; float4 uv2 : TEXCOORD2; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float4 uv0 : TEXCOORD0; float4 uv1 : TEXCOORD1; float4 uv2 : TEXCOORD2; float4 screenPos : TEXCOORD3; float3 positionWS : TEXCOORD4; float4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv0.xy;
                float2 centered = uv - 0.5;
                float radius = length(centered);
                float polarScale = 1.0 + _Use_Polar_UV * (min(pow(max(radius, 1e-5), _Pivot), 1.0) - 1.0);
                float2 time = _Time.y * float2(_Alp_X_Speed, _Alp_Y_Speed);
                float2 noiseTime = _Time.y * float2(_Noise_X_Speed, _Noise_Y_Speed);
                float2 alphaCart = uv * _AlphaTex_ST.xy + _AlphaTex_ST.zw + time;
                float2 polar = float2(radius * _Polar_Radial, atan2(centered.y, centered.x) * _Polar_Lengh * 0.159155) + time;
                float2 alphaUV = lerp(alphaCart, polar, _Use_Polar_UV);
                float2 noiseUV = uv * _NoiseTex_ST.xy + _NoiseTex_ST.zw + noiseTime;
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g + _Distortion_Offset;
                alphaUV += noise * i.uv1.x;
                half alphaTex = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).g;
                half2 dissolved = polarScale * alphaTex - i.uv0.wz;
                half smokeGrade = saturate((dissolved.x + _Color_Offset2) * _Color_Range2);
                half4 smoke = lerp(_Smoke_SubColor, _Smoke_MainColor, smokeGrade);
                half emissiveMask = saturate(dissolved.y * _Emissiv_Alpha);
                half emissiveGrade = saturate((dissolved.y + _Color_Offset) * _Color_Range);
                half4 emissive = lerp(_Emissiv_SubColor, _Emissiv_MainColor, emissiveGrade);
                smoke.rgb *= i.color.rgb;
                half3 emissiveMul = half3(i.uv1.zw, i.uv2.x) * _Emissiv_Color;
                half3 color = lerp(smoke.rgb, emissiveMul * emissive.rgb, emissiveMask);
                float2 mainUV = uv * _MainTex_ST.xy + _MainTex_ST.zw;
                half2 mainGA = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV).ga;
                half texAlpha = lerp(mainGA.y, mainGA.x, _Use_G_Channel_Alpha);
                half tintA = lerp(smoke.a, emissive.a, emissiveMask);
                half alpha = saturate(dissolved.x) * texAlpha * tintA * _Smoke_Alpha * i.color.a;
                alpha = saturate(alpha) * saturate(_EffectAlpha);
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
