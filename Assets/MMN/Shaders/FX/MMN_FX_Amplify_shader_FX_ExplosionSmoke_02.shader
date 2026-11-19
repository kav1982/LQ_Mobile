// Transcribed from shipped D3D11 bytecode
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_ExplosionSmoke_02.asm.txt).
// tcd0.z dissolve, tcd0.w emissive dissolve, tcd1.x AlphaTexSub sensitivity.
Shader "MMN/FX/Amplify shader/FX_ExplosionSmoke_02"
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
        [Toggle(_RAYCAST_ON)] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(tcd0.z      Dissolve)] [Header(tcd0.w     Emissive Dissolve)] [Header(tcd1.x       AlpSub Sensitivity)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [ToggleUI] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Enum(MainTex,0,AlphaTex,1)] _EmissivDissolve ("Emissiv Dissolve", Float) = 0
        [Header(Alpha Texture)] [Space()] _AlphaTex ("AlphaTex", 2D) = "white" {}
        _AlphaTexSub ("AlphaTex Sub", 2D) = "white" {}
        [Header(Color)] [Space()] _FireColor ("Fire Color", Color) = (1,1,1,1)
        _Color_Range ("Color_Range", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrcA ("Blend Src Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        _EffectAlpha ("EffectAlpha", Float) = 1
        _texcoord ("_texcoord", 2D) = "white" {}
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
            TEXTURE2D(_AlphaTex); SAMPLER(sampler_AlphaTex);
            TEXTURE2D(_AlphaTexSub); SAMPLER(sampler_AlphaTexSub);
            TEXTURE2D(_texcoord); SAMPLER(sampler_texcoord);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _AlphaTex_ST;
                float4 _AlphaTexSub_ST;
                float4 _texcoord_ST;
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
                float _EmissivDissolve;
                float4 _FireColor;
                float _Color_Range;
                float _Intensity_Color;
                float _BlendSrc;
                float _BlendDst;
                float _BlendSrcA;
                float _CullMode;
                float _ZTest;
                float _Intensity_Alpha;
                float _EffectAlpha;
            CBUFFER_END

            struct Attributes { float4 positionOS : POSITION; float4 uv0 : TEXCOORD0; float4 uv1 : TEXCOORD1; float4 uv2 : TEXCOORD2; float4 color : COLOR; };
            struct Varyings { float4 positionCS : SV_POSITION; float4 uv0 : TEXCOORD0; float4 uv1 : TEXCOORD1; float4 uv2 : TEXCOORD2; float4 screenPos : TEXCOORD3; float3 positionWS : TEXCOORD4; float4 color : COLOR; };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 uv = i.uv0.xy;
                float2 mainUV = uv * _MainTex_ST.xy + _MainTex_ST.zw;
                half2 mainGA = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV).ga;
                float2 alphaUV = uv * _AlphaTex_ST.xy + _AlphaTex_ST.zw;
                half alphaG = SAMPLE_TEXTURE2D(_AlphaTex, sampler_AlphaTex, alphaUV).g;
                float2 subUV = uv * _AlphaTexSub_ST.xy + _AlphaTexSub_ST.zw;
                half subG = SAMPLE_TEXTURE2D(_AlphaTexSub, sampler_AlphaTexSub, subUV).g;
                half emissiveSrc = lerp(mainGA.x, alphaG, _EmissivDissolve) + subG * i.uv1.x;
                half grade = saturate(((1.0h - i.uv0.w) - emissiveSrc) * _Color_Range);
                half3 fire = half3(i.uv1.zw, i.uv2.x) * _FireColor.rgb;
                half3 baseCol = mainGA.y * i.color.rgb * _Intensity_Color;
                half3 color = lerp(baseCol, fire, grade);
                half texAlpha = lerp(mainGA.y, mainGA.x, _Use_G_Channel_Alpha);
                half dissolve = alphaG + i.uv0.z + subG * i.uv1.x;
                half mask = texAlpha * (1.0h - dissolve);
                half stepped = floor(mask * 10.0h);
                color *= saturate(stepped * 0.666667h);
                half alpha = saturate(stepped * _Intensity_Alpha * texAlpha * i.color.a) * saturate(_EffectAlpha);
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
