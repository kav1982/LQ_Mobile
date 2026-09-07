// Recreation of the shipped MMN/FX/Amplify shader/FX_CampFire_00.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_CampFire_00.contract.json).
//
// Fragment maths is transcribed from the shipped D3D11 bytecode, disassembled into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_CampFire_00.asm.txt.
//
// Particle streams pack:
//   TEXCOORD0.xy = mesh UV
//   TEXCOORD0.z  = Custom1.x = dissolve threshold  (Header: tcd0.z Dissolve)
//   TEXCOORD0.w  = Custom1.y = distortion scale
//   TEXCOORD1.x  = particle Center.x, used as a per-card scroll seed
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: CustomEditor MM.Client.Editor.ShaderGUI.MMN_FxBlendModeShaderGUI
//                  (the original editor script is not in this project).
Shader "MMN/FX/Amplify shader/FX_CampFire_00"
{
    Properties
    {
        [HideInInspector] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        [HideInInspector] _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
        [HideInInspector] _Mode ("Mode", Float) = -1
        [HideInInspector] _TransitionValue ("TransitionValue", Range(0, 1)) = 1
        [HideInInspector] _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        [HideInInspector] [PerRendererData] _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        [HideInInspector] _RaycastMinimumAlpha ("minimumAlpha", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 18)) = 0
        [HideInInspector] _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] [HideInInspector] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _LightReceive ("LightReceive", Range(0, 1)) = 0
        [HideInInspector] _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] [HideInInspector] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        [HideInInspector] _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        [HideInInspector] _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        [ToggleUI] [HideInInspector] _FogReceive ("FogReceive", Range(0, 1)) = 0
        [HideInInspector] _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle(_RAYCAST_ON)] [HideInInspector] _Raycast ("_Raycast", Float) = 1
        [HideInInspector] _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(tcd0.z     Dissolve)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Header(Color Texture)] [Space()] _ColorTex ("ColorTex", 2D) = "white" {}
        _Color_X_Speed ("Color_X_Speed", Float) = 0
        _Color_Y_Speed ("Color_Y_Speed", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = -0.5
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 1
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 1
        [Header(AddNoise Texture)] [Space()] _AddNoiseTex ("AddNoiseTex", 2D) = "white" {}
        _AddNoise_X_Speed ("AddNoise_X_Speed", Float) = 1
        _AddNoise_Y_Speed ("AddNoise_Y_Speed", Float) = 1
        [Header(Mask)] [Space()] _Noise_MaskRange ("Noise_MaskRange", Float) = 1
        _AddNoise_MaskRange ("AddNoise_MaskRange", Float) = 0
        [Header(Color)] [Space()] [HDR] _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HDR] _SubColor ("Sub Color", Color) = (1,1,1,1)
        _Color_Range ("Color_Range", Float) = 0
        _Color_Offset ("Color_Offset", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] [Header(Z Buffer)] [Space(10)] _CullMode ("Cull Mode", Float) = 0
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
            TEXTURE2D(_ColorTex); SAMPLER(sampler_ColorTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_AddNoiseTex); SAMPLER(sampler_AddNoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _ColorTex_ST;
                float4 _NoiseTex_ST;
                float4 _AddNoiseTex_ST;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _EmissionColor;
                half4 _MainColor;
                half4 _SubColor;
                half _AlphaCutoff;
                half _Mode;
                half _TransitionValue;
                half _SpawnTransition;
                half _RaycastHarftoneClip;
                half _RaycastMinimumAlpha;
                half _NearPlaneAlpha;
                half _NearPlaneInvertDistance;
                half _NearPlaneDirectionMode;
                half _NearPlaneDitherMode;
                half _LightReceive;
                half _LightRatio;
                half _SoftParticle;
                float _SoftParticleNearFadeDistance;
                float _SoftParticleFarFadeDistance;
                half _FogReceive;
                half _SoftParticleFadeOutRange;
                half _Raycast;
                half _Use_G_Channel_Alpha;
                float _Color_X_Speed;
                float _Color_Y_Speed;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Distortion_Offset;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _AddNoise_X_Speed;
                float _AddNoise_Y_Speed;
                float _Noise_MaskRange;
                float _AddNoise_MaskRange;
                float _Color_Range;
                float _Color_Offset;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _BlendSrc;
                half _BlendDst;
                half _CullMode;
                half _ZTest;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 color : COLOR;
            };

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
                float2 uv = i.uv0.xy;
                half dissolve = (half)i.uv0.z;
                float distortScale = i.uv0.w;
                float2 scroll = frac(float2(i.uv0.z + i.uv0.w, i.uv1.x + i.uv0.w));
                float time = MMN_FxTime();

                // Height grade: pow(|uv.y + Color_Range|, Color_Offset) lerps SubColor (base)
                // toward MainColor (tip). On the shipped campfire mats this is HDR orange -> red.
                half grade = (half)min(pow(abs(uv.y + _Color_Range), _Color_Offset), 1.0);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                float2 mainUV = uv * _MainTex_ST.xy + _MainTex_ST.zw;

                float2 noiseUV = uv * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV += scroll + time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g;
                float n = noise + _Distortion_Offset;
                float2 distort = float2(n * _Distortion_X_Power, n * _Distortion_Y_Power) * distortScale;

                // uv.x * (1-uv.x) * (1-uv.y) is largest at the card centre-bottom; the
                // shipped graph inverts it so the core stays put and the edges flicker.
                float edge = uv.x * (1.0 - uv.x) * (1.0 - uv.y);
                float noiseMask = saturate(1.0 - (pow(abs(edge * 4.0), 2.5) + _Noise_MaskRange));
                mainUV += distort * noiseMask;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half3 color = lerp(tint.rgb * mainTex.rgb, tint.rgb, _Use_G_Channel_Alpha);

                float2 colorUV = uv * _ColorTex_ST.xy + _ColorTex_ST.zw;
                colorUV += scroll + _Time.y * float2(_Color_X_Speed, _Color_Y_Speed);
                half3 colorTex = SAMPLE_TEXTURE2D(_ColorTex, sampler_ColorTex, colorUV).rgb;
                color *= _Intensity_Color * i.color.rgb * colorTex;

                float2 addUV = uv * _AddNoiseTex_ST.xy + _AddNoiseTex_ST.zw;
                addUV += scroll + time * float2(_AddNoise_X_Speed, _AddNoise_Y_Speed);
                half addNoise = SAMPLE_TEXTURE2D(_AddNoiseTex, sampler_AddNoiseTex, addUV).g;
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);
                half masked = addNoise * mainAlpha;

                half dissolveDiv = (half)max(1.0 - i.uv0.z, 1e-5);
                half alphaRaw = (masked - dissolve) / dissolveDiv;
                half coreBoost = (half)pow(abs(edge * 4.0 + _AddNoise_MaskRange), 2.5);
                half alpha = saturate(alphaRaw * _Intensity_Alpha + coreBoost) * tint.a * i.color.a;

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
