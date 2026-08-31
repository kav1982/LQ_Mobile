// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_01, the shader on
// FX_Waterfall_Line_01 / FX_Waterfall_Wave_02 (and many other dissolve cards).
//
// Properties, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_FX_FX_Dissolve_Div_01.contract.json: 46 properties, Unlit
// pass, Queue Transparent, Blend [_BlendSrc] [_BlendDst], ZWrite Off, ZTest [_ZTest],
// Cull [_CullMode]).
//
// The fragment maths is transcribed from the shipped D3D11 bytecode, disassembled into
// _re_work/shader_contracts/MMN_FX_FX_Dissolve_Div_01.asm.txt by _re_work/dump_shader_bytecode.py.
// Custom1.x is the dissolve threshold (TEXCOORD0.z).
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: the ShadowCaster pass (transparent particle, unused by these materials).
// NOT-IMPLEMENTED: _AlphaCutoff and _EmissionColor. Both are in the property block but no
//                  shipped Unlit variant reads them; the pass blends and never clips.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_01"
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
        [Header(Custom1.x     Dissolve)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Enum(UV,0,Polar,1)] _UVType ("UV Type", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 0
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 0
        _Twist ("Twist", Float) = 0
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (1,1,1,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
        [Header(Lerp Color)] [Space()] _LerpColor ("Lerp Color", Color) = (1,1,1,1)
        _LerpColor_Offset ("LerpColor_Offset", Float) = 0
        _LerpColor_Range ("LerpColor_Range", Float) = 0
        [Space()] _LerpColor_Intensity ("LerpColor_Intensity", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
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

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                half4 _EmissionColor;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _MainColor;
                half4 _SubColor;
                half4 _LerpColor;
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
                half _UVType;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                half _ColorGradation;
                float _Color_Offset;
                float _Color_Range;
                float _LerpColor_Offset;
                float _LerpColor_Range;
                half _LerpColor_Intensity;
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
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float time = MMN_FxTime();
                half dissolve = (half)i.uv0.z;

                float2 mainCart = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 mainUV = lerp(mainCart, MMN_PolarUV(i.uv0.xy, _MainTex_ST), _UVType);
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noiseCart = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseCart.y = noiseCart.x * _Twist + noiseCart.y;
                float2 noiseUV = lerp(noiseCart, MMN_PolarUV(i.uv0.xy, _NoiseTex_ST), _UVType);
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g;

                half mask = mainAlpha * noise - dissolve;
                half gradeSrc = lerp(mask, (half)mainUV.x, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 texColor = lerp(mainTex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                half3 color = texColor * (tint.rgb * _Intensity_Color);

                half lerpAmt = saturate((gradeSrc + _LerpColor_Offset) * _LerpColor_Range);
                color = lerp(color, _LerpColor.rgb * _LerpColor_Intensity, lerpAmt);

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
