// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Panning_2CVertexOffset,
// the shader on FX_Waterfall_Wave_01. Distinct from the _02 shoreline-wave variant.
//
// Properties, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_FX_FX_Dissolve_Div_Panning_2CVertexOffset.contract.json:
// 40 properties, one Unlit pass, Queue Transparent, Blend [_BlendSrc] [_BlendDst],
// ZWrite Off, ZTest [_ZTest], Cull [_CullMode]).
//
// Vertex and fragment maths are transcribed from the shipped D3D11 bytecode, disassembled
// into _re_work/shader_contracts/MMN_FX_FX_Dissolve_Div_Panning_2CVertexOffset.asm.txt.
// Custom1.x = dissolve (TEXCOORD0.z), Custom1.y = vertex offset power (TEXCOORD0.w).
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: _AlphaCutoff and _EmissionColor. Both are in the property block but no
//                  shipped Unlit variant reads them; the pass blends and never clips.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Panning_2CVertexOffset"
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
        [Header(Custom.1.x    Dissolve)] [Header(Custom.1.y    VertexOffset Power)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Twist ("Twist", Float) = 0
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        [Header(Mask Texture)] [Space()] _MaskTex ("MaskTex", 2D) = "white" {}
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
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
            TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _MaskTex_ST;
                half4 _EmissionColor;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
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
                float _Twist;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                half _ColorGradation;
                float _Color_Offset;
                float _Color_Range;
                half _Intensity_Color;
                half _Intensity_Alpha;
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
                float4 uv0 : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                float time = MMN_FxTime();

                float2 noiseUV = v.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                float noise = SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, noiseUV, 0).g;

                float2 mainUV = v.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float4 mainTex = SAMPLE_TEXTURE2D_LOD(_MainTex, sampler_MainTex, mainUV, 0);
                float mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 maskUV = v.uv0.xy * _MaskTex_ST.xy + _MaskTex_ST.zw;
                float mask = SAMPLE_TEXTURE2D_LOD(_MaskTex, sampler_MaskTex, maskUV, 0).g;

                float3 positionOS = v.positionOS.xyz
                    + v.normalOS * (noise * mainAlpha * v.uv0.w * mask);

                VertexPositionInputs positions = GetVertexPositionInputs(positionOS);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv0 = v.uv0;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float time = MMN_FxTime();
                half dissolve = (half)i.uv0.z;

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noiseUV = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g;

                half mask = mainAlpha * noise - dissolve;
                half grade = saturate((lerp(mask, (half)i.uv0.x, _ColorGradation) + _Color_Offset)
                                      * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 texColor = lerp(mainTex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                half3 color = texColor * (tint.rgb * _Intensity_Color);

                half alpha = saturate(mask / (1.0h - dissolve) * _Intensity_Alpha)
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
