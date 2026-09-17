// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Offset.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Offset.contract.json).
// Maths are transcribed from the D3D11 bytecode dumped from
// AssetPackages/Starter/0017.blob chunk 1178 into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Offset.asm.txt.
//
// TEXCOORD0.z = Custom1.x dissolve.
// TEXCOORD0.w = Custom1.y MainTex U offset (and |U|^Custom1.y when _Use_Offset_Power).
// TEXCOORD1.x = Custom1.z MainTex V offset.
// Noise R multiplies dissolve. AlphaTex R has no Custom1 offset.
// Polar U is Amplify radius*2. Twist shears noise V after scroll.
//
// NOT-IMPLEMENTED: FOG_LINEAR. DEBUG_DISPLAY. ShadowCaster.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Offset"
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
        [Header(Custom1.x     Dissolve)] [Header(Custom1.y     MainTex Offset X)] [Header(Custom1.z     MainTex Offset Y)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [HideInInspector] _MainTex_ST ("MainTex_ST", Vector) = (1,1,0,0)
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Toggle] _Use_Offset_Power ("Use_Offset_Power", Float) = 0
        [Enum(UV,0,Polar,1)] _UVType ("UV Type", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        [HideInInspector] _NoiseTex_ST ("NoiseTex_ST", Vector) = (1,1,0,0)
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        [HideInInspector] _AlphaTex_ST ("AlphaTex_ST", Vector) = (1,1,0,0)
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
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _EmissionColor;
                half4 _MainColor;
                half4 _SubColor;
                half4 _LerpColor;
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
                half _Use_Offset_Power;
                half _UVType;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                half _ColorGradation;
                half _Color_Offset;
                half _Color_Range;
                half _LerpColor_Offset;
                half _LerpColor_Range;
                half _LerpColor_Intensity;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _ZTest;
                half _BlendSrc;
                half _BlendDst;
                half _CullMode;
                half _EffectAlpha;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
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

            float2 MMN_SelectUV(float2 uv, float4 st, out float radius)
            {
                float2 planar = uv * st.xy + st.zw;
                float2 centered = uv - 0.5;
                radius = length(centered);
                float angle01 = atan2(centered.y, centered.x) * (0.5 / 3.14159265);
                float2 polar = float2(st.x * (radius * 2.0) + st.z, angle01 * st.y + st.w);
                return lerp(planar, polar, _UVType);
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
                float time = MMN_FxTime();
                half dissolveCustom = (half)i.uv0.z;
                float2 customOffset = float2(i.uv0.w, i.uv1.x);

                float radius;
                float2 selected = MMN_SelectUV(i.uv0.xy, _MainTex_ST, radius);
                float2 offsetUV = selected + customOffset;
                // Both lerp sides evaluate; log(0) would NaN the unused power path.
                float poweredU = selected.x;
                if (_Use_Offset_Power > 0.5h)
                    poweredU = exp(log(max(abs(selected.x), 1e-8)) * i.uv0.w);
                float2 mainUV = lerp(offsetUV, float2(poweredU, selected.y), _Use_Offset_Power);

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half3 texRgb = lerp(mainTex.rgb * i.color.rgb, i.color.rgb * (1.0h - mainTex.rgb), _Use_G_Channel_Alpha);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noiseUV = MMN_SelectUV(i.uv0.xy, _NoiseTex_ST, radius);
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                half noiseR = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).r;

                float2 alphaUV = MMN_SelectUV(i.uv0.xy, _AlphaTex_ST, radius);
                half alphaTex = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).r;

                half dissolved = mainAlpha * noiseR * alphaTex - dissolveCustom;

                half gradeU = (half)lerp(i.uv0.x, radius * 2.0 - i.uv0.x, _UVType);
                half gradeSrc = lerp(dissolved, gradeU, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 color = texRgb * _Intensity_Color * tint.rgb;
                half lerpAmt = saturate((gradeSrc + _LerpColor_Offset) * _LerpColor_Range);
                color = lerp(color, _LerpColor.rgb * _LerpColor_Intensity, lerpAmt);

                half alpha = saturate(dissolved / (1.0h - dissolveCustom) * _Intensity_Alpha)
                           * i.color.a * tint.a * saturate(_EffectAlpha);

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
