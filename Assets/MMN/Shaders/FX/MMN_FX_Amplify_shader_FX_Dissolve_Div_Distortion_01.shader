// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_01.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Distortion_01.contract.json).
// Fragment / vertex maths are transcribed from the D3D11 bytecode dumped from
// AssetPackages/Starter/0017.blob chunk 1172 into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_Dissolve_Div_Distortion_01.asm.txt.
//
// TEXCOORD0.z = Custom1.x dissolve. TEXCOORD0.w = Custom1.y distortion power.
// TEXCOORD1.x = Custom1.z vertex-offset scale. Noise is sampled in R, Mask in G.
//
// NOT-IMPLEMENTED: FOG_LINEAR (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: DEBUG_DISPLAY (URP rendering debugger only).
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Distortion_01"
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
        [Header(Custom1.x     Dissolve)] [Header(Custom1.y     Distortion Power)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [ToggleUI] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [ToggleUI] _Use_Dissolve_Alpha ("Use_Dissolve_Alpha", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        _Twist ("Twist", Float) = 0
        [Header(Mask Texture)] [Space()] _MaskTex ("MaskTex", 2D) = "white" {}
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 1
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 1
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = -0.5
        [ToggleUI] [Space(10)] _Use_Distort_To_Center ("Use_Distort_To_Center", Float) = 0
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
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
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
            TEXTURE2D(_VertexTex); SAMPLER(sampler_VertexTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex_ST;
                float4 _MaskTex_ST;
                float4 _VertexTex_ST;
                half4 _EmissionColor;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _MainColor;
                half4 _SubColor;
                float4 _VertexPower;
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
                half _Use_Dissolve_Alpha;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Twist;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _Distortion_Offset;
                half _Use_Distort_To_Center;
                float _Distortion_Power;
                float _Vertex_X_Speed;
                float _Vertex_Y_Speed;
                float _VertexTwist;
                half _ColorGradation;
                half _Color_Offset;
                half _Color_Range;
                half _ZTest;
                half _BlendSrc;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _BlendDst;
                half _CullMode;
                half _EffectAlpha;
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
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                float time = MMN_FxTime();
                float2 vertexUV = v.uv0.xy * _VertexTex_ST.xy + _VertexTex_ST.zw;
                vertexUV.y = vertexUV.x * _VertexTwist + vertexUV.y;
                vertexUV += time * float2(_Vertex_X_Speed, _Vertex_Y_Speed);
                half vtx = SAMPLE_TEXTURE2D_LOD(_VertexTex, sampler_VertexTex, vertexUV, 0).g;
                float3 positionOS = v.positionOS.xyz
                    + v.normalOS * (vtx * v.uv0.x * v.uv1.x) * _VertexPower.xyz;

                Varyings o = (Varyings)0;
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
                half dissolveCustom = (half)i.uv0.z;
                half distortAmt = (half)i.uv0.w;

                float2 noiseUV = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                noiseUV.y = noiseUV.x * _Twist + noiseUV.y;
                noiseUV += time * float2(_Noise_X_Speed, _Noise_Y_Speed);
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).r;

                float2 planar = (noise + _Distortion_Offset)
                    * float2(_Distortion_X_Power, _Distortion_Y_Power) * distortAmt;
                float2 centered = (noise * 2.0h - 1.0h) * distortAmt * _Distortion_Power;
                float2 distort = lerp(planar, centered, _Use_Distort_To_Center);

                float2 maskUV = i.uv0.xy * _MaskTex_ST.xy + _MaskTex_ST.zw;
                half mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV).g;

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                mainUV += distort * mask;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                half dissolve = lerp(dissolveCustom, 1.0h - i.color.a, _Use_Dissolve_Alpha);
                half dissolved = mainAlpha - dissolve;
                half gradeSrc = lerp(dissolved, (half)i.uv0.x, _ColorGradation);
                half grade = saturate((gradeSrc + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 color = lerp(tint.rgb * mainTex.rgb, tint.rgb, _Use_G_Channel_Alpha);
                color *= _Intensity_Color * i.color.rgb;

                half tintA = lerp(i.color.a, 1.0h - i.color.a, _Use_Dissolve_Alpha);
                half alpha = saturate(dissolved / (1.0h - dissolve) * _Intensity_Alpha)
                           * tint.a * tintA * saturate(_EffectAlpha);

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
