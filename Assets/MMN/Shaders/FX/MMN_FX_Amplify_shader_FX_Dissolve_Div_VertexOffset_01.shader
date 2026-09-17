// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_VertexOffset_01.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_VertexOffset_01.contract.json).
// Maths are transcribed from the D3D11 bytecode dumped from
// AssetPackages/Starter/0017.blob chunk 1182 into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_VertexOffset_01.asm.txt.
//
// TEXCOORD0.z = Custom1.x dissolve. TEXCOORD0.w = Custom1.y vertex-offset power.
// TEXCOORD1.x = Custom1.z wavelength scale. TEXCOORD1.y = Custom1.w MainTex U offset.
// TEXCOORD1.z = Custom2.x wave phase offset (unused when Custom2 is disabled).
// Noise dissolve is sampled in G. Main alpha uses G when _Use_G_Channel_Alpha is on.
// _MaskTex defaults to white; _MASKTEX is on only when a real map is bound.
//
// NOT-IMPLEMENTED: FOG_LINEAR. DEBUG_DISPLAY. ShadowCaster pass.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_VertexOffset_01"
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
        [Header(Custom1.x     Dissolve)] [Header(Custom1.y     VertexOffset Power)] [Header(Custom1.z      WaveLength Power)] [Header(Custom1.w     MainTex U OffSet)] [Header(Custom2.x     Wave OffSet)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        _Main_X_Speed ("Main_X_Speed", Float) = 0
        _Main_Y_Speed ("Main_Y_Speed", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        [Header(Mask Texture)] [Space()] _MaskTex ("MaskTex", 2D) = "white" {}
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Lerp Color)] [Space()] _LerpColor ("Lerp Color", Color) = (1,1,1,1)
        _LerpColor_Offset ("LerpColor_Offset", Float) = 0
        _LerpColor_Range ("LerpColor_Range", Float) = 1
        [Space()] _LerpColor_Intensity ("LerpColor_Intensity", Float) = 1
        [Header(Vertex Sin Wave)] [Space()] _WaveLength ("WaveLength", Float) = 5
        _WaveSpeed ("WaveSpeed", Float) = 5
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
        [HideInInspector] _texcoord ("_texcoord", 2D) = "white" {}
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
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ParticleInstancingSetup
            #pragma shader_feature_local_fragment _MASKTEX

            #define MMN_FX_USE_DEPTH

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"
            #include "../Include/MMN_FX_ParticlesInstancing.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _MaskTex_ST;
                float4 _texcoord_ST;
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
                half _SoftParticleFadeOutRange;
                half _Use_G_Channel_Alpha;
                float _Main_X_Speed;
                float _Main_Y_Speed;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                half _ColorGradation;
                half _Color_Offset;
                half _Color_Range;
                half _LerpColor_Offset;
                half _LerpColor_Range;
                half _LerpColor_Intensity;
                float _WaveLength;
                float _WaveSpeed;
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

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(v);
                float4 uv0 = v.uv0;
                float4 uv1 = v.uv1;
                float4 color = v.color;
                MMN_ApplyParticleInstance(uv0, uv1, color);

                float env = uv0.x * (1.0 - uv0.x);
                float phase = MMN_FxTime() * _WaveSpeed
                    + uv0.x * _WaveLength * uv1.x
                    + uv1.z;
                float s = sin(phase);
                float3 wave = float3(s, s, v.normalOS.z) * float3(env * 4.0, env * 4.0, env);
                wave *= float3(v.normalOS.xy, uv0.w);
                float3 positionOS = v.positionOS.xyz + wave * float3(uv0.w, uv0.w, 0.0);

                VertexPositionInputs positions = GetVertexPositionInputs(positionOS);
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
                float time = MMN_FxTime();
                half dissolveCustom = (half)i.uv0.z;

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                mainUV.x += i.uv1.y;
                mainUV += time * float2(_Main_X_Speed, _Main_Y_Speed);
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noiseUV = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g;

                half dissolved = mainAlpha * noise - dissolveCustom;
                half gradeSrc = lerp(dissolved, (half)i.uv0.x, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                // G-channel invert is RGB only. Imported ramps store A=1; using A in the
                // invert (DXBC half4) makes texInv.a=0 and wipes the pillar.
                half3 texRgb = lerp(mainTex.rgb * i.color.rgb, i.color.rgb * (1.0h - mainTex.rgb), _Use_G_Channel_Alpha);
                half3 color = texRgb * tint.rgb * _Intensity_Color;

                half lerpT = saturate((gradeSrc + _LerpColor_Offset) * _LerpColor_Range);
                color = lerp(color, _LerpColor.rgb * _LerpColor_Intensity, lerpT);

                half alpha = saturate(dissolved / (1.0h - dissolveCustom) * _Intensity_Alpha)
                           * tint.a * i.color.a;
                // Shader default is "white" {}. An unbound slot samples as 0 and wipes the pillar.
                #ifdef _MASKTEX
                float2 maskUV = i.uv0.xy * _MaskTex_ST.xy + _MaskTex_ST.zw;
                half mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV).r;
                #else
                half mask = 1.0h;
                #endif
                alpha = saturate(alpha * mask) * saturate(_EffectAlpha);

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
