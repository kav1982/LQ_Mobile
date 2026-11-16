// Recreation of the shipped MMN/FX/Amplify shader/FX_Default, the shader on the shoreline
// ParticlesUnlit material and most simple MMN effects.
//
// Properties, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_FX_FX_Default.contract.json, 33 properties, one Unlit pass,
// Queue Transparent, Blend [_BlendSrc] [_BlendDst], ZWrite Off, ZTest [_ZTest], Cull [_CullMode]).
//
// The fragment maths is transcribed from the shipped D3D11 bytecode, disassembled into
// _re_work/shader_contracts/MMN_FX_FX_Default.asm.txt by _re_work/dump_shader_bytecode.py.
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant. It runs the client's own height/distance fog off
//                  _Global_DimFog_* / _Global_FogHeight* globals that only the game sets; with
//                  them at zero the shipped maths divides by zero, so fog is left off here.
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: _AlphaCutoff and _EmissionColor. Both are in the property block but no
//                  shipped variant reads them; the pass blends and never clips.
Shader "MMN/FX/Amplify shader/FX_Default"
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
        [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [HideInInspector] _Color ("Color", Color) = (1,1,1,1)
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(Default,0,Only Day,1,Only Night,2)] [Space()] _Day_Alpha ("Day_Alpha", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
        [HideInInspector] _texcoord ("", 2D) = "white" {}
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
            // The shipped pass carries no LightMode tag, so URP draws it through SRPDefaultUnlit.
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

            // Client time-of-day blend, 0 at night and 1 at noon. Unset outside the game, which
            // only matters for materials that set _Day_Alpha to Only Day / Only Night.
            float _Global_Night2Day;

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _EmissionColor;
                half4 _Color;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
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
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _Day_Alpha;
                half _BlendSrc;
                half _BlendDst;
                half _CullMode;
                half _ZTest;
                half _EffectAlpha;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs positions = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv = v.uv;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                             i.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                // Several MMN FX atlases keep the shape in G rather than in the alpha channel.
                half texAlpha = lerp(tex.a, tex.g, _Use_G_Channel_Alpha);

                half3 color = lerp(tex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha)
                            * _Intensity_Color;

                // _Day_Alpha: 0 always on, 1 only during the day, 2 only at night.
                half daylight = saturate(_Global_Night2Day);
                half timeOfDay = lerp(1.0h, daylight, saturate(_Day_Alpha));
                timeOfDay += saturate(_Day_Alpha - 1.0h) * (1.0h - 2.0h * timeOfDay);

                half alpha = saturate(texAlpha * _Intensity_Alpha * i.color.a * timeOfDay * _Color.a)
                           * saturate(_EffectAlpha);

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

    // The shipped shader declares
    // CustomEditor "MM.Client.Editor.ShaderGUI.MMN_FxBlendModeShaderGUI". That editor class is
    // not part of the extracted data, and pointing at a missing class makes Unity log an error
    // for every material, so it is left out and the framework properties stay visible instead.
    FallBack Off
}
