// NOT-IMPLEMENTED: playable environment-FX shell for MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_01.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_01"
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
        [Toggle( _RAYCAST_ON )] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(Custom.1.x     Dissolve)] [Header(Custom.1.y     Distortion Power)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Toggle] _Use_Dissolve_Alpha ("Use_Dissolve_Alpha", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        [Header(Mask Texture)] [Space()] _MaskTex ("MaskTex", 2D) = "white" {}
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 1
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 1
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = -0.5
        [Toggle] [Space(10)] _Use_Distort_To_Center ("Use_Distort_To_Center", Float) = 0
        _Distortion_Power ("Distortion_Power", Float) = 1
        [Header(Vertex Texture)] [Space()] _VertexTex ("VertexTex", 2D) = "black" {}
        _Vertex_X_Speed ("Vertex_X_Speed", Float) = 1
        _Vertex_Y_Speed ("Vertex_Y_Speed", Float) = 1
        _VertexTwist ("Vertex Twist", Float) = 0
        _VertexPower ("VertexPower", Vector) = (1,1,1,0)
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
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
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);
            TEXTURE2D(_VertexTex); SAMPLER(sampler_VertexTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _MaskTex_ST;
                float4 _VertexTex_ST;
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
                float _Use_Dissolve_Alpha;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _Distortion_Offset;
                float _Use_Distort_To_Center;
                float _Distortion_Power;
                float _Vertex_X_Speed;
                float _Vertex_Y_Speed;
                float _VertexTwist;
                float4 _VertexPower;
                float _ColorGradation;
                float4 _MainColor;
                float4 _SubColor;
                float _Color_Offset;
                float _Color_Range;
                float _ZTest;
                float _BlendSrc;
                float _Intensity_Color;
                float _Intensity_Alpha;
                float _BlendDst;
                float _CullMode;
                float _EffectAlpha;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float2 uv : TEXCOORD0; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float2 uv : TEXCOORD0; float4 screenPos : TEXCOORD1; float3 positionWS : TEXCOORD2; float4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                half texAlpha = lerp(tex.a, tex.g, _Use_G_Channel_Alpha);
                half3 color = lerp(tex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                color *= _Intensity_Color;
                color *= _MainColor.rgb;
                half alpha = saturate(texAlpha * i.color.a * _Intensity_Alpha * saturate(_EffectAlpha));
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
