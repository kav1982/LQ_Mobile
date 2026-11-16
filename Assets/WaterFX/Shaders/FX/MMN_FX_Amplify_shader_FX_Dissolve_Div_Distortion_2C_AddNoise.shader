// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_2C_AddNoise.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Distortion_2C_AddNoise.contract.json).
//
// Fragment maths is transcribed from the shipped D3D11 bytecode, disassembled into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Distortion_2C_AddNoise.asm.txt.
//
// Particle streams pack:
//   TEXCOORD0.xy = mesh UV (texture-sheet tiles already applied)
//   TEXCOORD0.z  = Custom1.x = dissolve threshold
//   TEXCOORD0.w  = Custom1.y = distortion power
//   TEXCOORD1.x  = optional Add_Offset seed (unused when _Add_Offset is 0)
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: CustomEditor MM.Client.Editor.ShaderGUI.MMN_FxBlendModeShaderGUI
//                  (the original editor script is not in this project).
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_2C_AddNoise"
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
        [Header(Custom.1.x     Dissolve)] [Header(Custom.1.y     Distortion Power)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        _SequenceX ("Sequence X", Float) = 1
        _SequenceY ("Sequence Y", Float) = 1
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = -0.5
        [Toggle] _Add_Offset ("Add_Offset", Float) = 0
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 1
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 1
        [Header(AddNoise Texture)] [Space()] _AddNoiseTex ("AddNoiseTex", 2D) = "white" {}
        _AddNoise_X_Speed ("AddNoise_X_Speed", Float) = 1
        _AddNoise_Y_Speed ("AddNoise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        _DefaultValues ("Default Values", Float) = 0
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Lerp Color)] [Space()] _LerpColor ("Lerp Color", Color) = (1,1,1,1)
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        _LerpColor_Offset ("LerpColor_Offset", Float) = 0
        _LerpColor_Range ("LerpColor_Range", Float) = 0
        [Space()] _LerpColor_Intensity ("LerpColor_Intensity", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        _EffectAlpha ("EffectAlpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
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
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ParticleInstancingSetup

            #define MMN_FX_USE_DEPTH

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"
            #include "../Include/MMN_FX_ParticlesInstancing.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_AddNoiseTex); SAMPLER(sampler_AddNoiseTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _AddNoiseTex_ST;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _EmissionColor;
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
                float _SequenceX;
                float _SequenceY;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Distortion_Offset;
                half _Add_Offset;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _AddNoise_X_Speed;
                float _AddNoise_Y_Speed;
                float _Twist;
                half _DefaultValues;
                half _ColorGradation;
                float _Color_Offset;
                float _Color_Range;
                float _LerpColor_Offset;
                float _LerpColor_Range;
                half _LerpColor_Intensity;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _EffectAlpha;
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
                UNITY_VERTEX_INPUT_INSTANCE_ID
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

            float2 MMN_SeqUV(float2 uv, float4 st)
            {
                float2 p = uv * st.xy + st.zw;
                p.y = p.x * _Twist + p.y;
                p.x *= _SequenceX;
                p.y *= _SequenceY;
                return p;
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(v);
                float4 uv0 = v.uv0;
                float4 uv1 = v.uv1;
                float4 color = v.color;
                MMN_ApplyParticleInstance(uv0, uv1, color);
                VertexPositionInputs positions = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv0 = uv0;
                o.uv1 = uv1;
                o.color = color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv0.xy;
                half dissolve = saturate((half)i.uv0.z + _DefaultValues);
                half distortPower = saturate((half)i.uv0.w);
                float time = MMN_FxTime();

                float2 addUV = frac(MMN_SeqUV(uv, _AddNoiseTex_ST));
                addUV += time * float2(_AddNoise_X_Speed, _AddNoise_Y_Speed);
                half addNoise = SAMPLE_TEXTURE2D(_AddNoiseTex, sampler_AddNoiseTex, addUV).g;

                float2 noiseUV = frac(MMN_SeqUV(uv, _NoiseTex_ST));
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).r;

                float2 mainUV = uv * _MainTex_ST.xy + _MainTex_ST.zw;
                float n = noise + _Add_Offset * i.uv1.x + _Distortion_Offset;
                mainUV += n * float2(_Distortion_X_Power, _Distortion_Y_Power) * distortPower;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half masked = addNoise * lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);
                half mask = masked - dissolve;

                half gradeSrc = lerp(mask, (half)frac(uv.x * _SequenceX), _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 color = lerp(tint.rgb * mainTex.rgb, tint.rgb, _Use_G_Channel_Alpha);
                color *= _Intensity_Color * i.color.rgb;

                half lerpAmt = saturate((gradeSrc + _LerpColor_Offset) * _LerpColor_Range);
                color = lerp(color, _LerpColor.rgb * _LerpColor_Intensity, lerpAmt);

                half alpha = saturate(mask / max(1.0001h - dissolve, 1e-5h) * _Intensity_Alpha);
                alpha *= tint.a * i.color.a * saturate(_EffectAlpha);

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
