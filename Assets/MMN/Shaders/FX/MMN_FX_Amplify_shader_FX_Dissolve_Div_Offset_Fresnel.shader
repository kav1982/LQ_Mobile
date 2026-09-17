// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Offset_Fresnel.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Offset_Fresnel.contract.json).
// Maths are transcribed from the D3D11 bytecode dumped from
// AssetPackages/Starter/0017.blob chunk 1179 into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Offset_Fresnel.asm.txt.
//
// TEXCOORD0.z = Custom1.x dissolve. TEXCOORD0.w = Custom1.y MainTex UV.x offset.
// Mesh + GPU instancing reads Custom1 from the particle instance buffer.
// Noise and AlphaTex are sampled in R. Fresnel is a smoothstep NdotV rim.
//
// NOT-IMPLEMENTED: FOG_LINEAR (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: DEBUG_DISPLAY. ShadowCaster / extra passes unused by these cards.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Offset_Fresnel"
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
        [Header(Custom1.x     Dissolve)] [Header(Custom1.y     MainTex Offset X)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Toggle] _Fresnel_OneMinus ("Fresnel_One Minus", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _DefaultValues ("Default Values", Float) = 0
        [Header(Fresnel)] [Space(5)] _RimMin ("RimMin", Range(0, 1)) = 0
        _RimMax ("RimMax", Range(0, 1)) = 1
        _Twist ("Twist", Float) = 0
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (1,1,1,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        _Color_Range ("Color_Range", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
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
            TEXTURE2D(_AlphaTex); SAMPLER(sampler_AlphaTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _AlphaTex_ST;
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
                half _SoftParticleFadeOutRange;
                half _Use_G_Channel_Alpha;
                half _Fresnel_OneMinus;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                half _DefaultValues;
                half _RimMin;
                half _RimMax;
                float _Twist;
                half _ColorGradation;
                half _Color_Offset;
                half _Color_Range;
                half _BlendSrc;
                half _BlendDst;
                half _CullMode;
                half _ZTest;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _EffectAlpha;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 uv0 : TEXCOORD0;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(v);
                float4 uv0 = v.uv0;
                float4 color = v.color;
                MMN_ApplyParticleInstance(uv0, color);
                VertexPositionInputs positions = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.uv0 = uv0;
                o.color = color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float time = MMN_FxTime();
                half dissolve = saturate((half)i.uv0.z + _DefaultValues);

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                mainUV.x += i.uv0.w;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half3 texColor = lerp(mainTex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noiseUV = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).r;

                float2 alphaUV = i.uv0.xy * _AlphaTex_ST.xy + _AlphaTex_ST.zw;
                half alphaTex = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).r;

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.positionWS);
                half ndotv = dot(i.normalWS, viewDir);
                half fresnel = smoothstep(_RimMin, _RimMax, ndotv);
                fresnel = lerp(fresnel, 1.0h - 2.0h * fresnel, _Fresnel_OneMinus);

                half mask = mainAlpha * noise * alphaTex * fresnel - dissolve;
                half gradeSrc = lerp(mask, (half)i.uv0.x, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 color = texColor * _Intensity_Color * tint.rgb;
                half alpha = saturate(mask / (1.0001h - dissolve) * _Intensity_Alpha)
                           * i.color.a * tint.a * saturate(_EffectAlpha);

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
