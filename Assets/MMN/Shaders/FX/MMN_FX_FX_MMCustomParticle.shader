// NOT-IMPLEMENTED: playable environment-FX shell for MMN/FX/FX_MMCustomParticle.
// Properties and render states follow the extracted original contract.
// Fragment approximates FX_Default (main texture * vertex colour * intensity).
// Dissolve / distortion / vertex-offset / stencil maths are not transcribed.
Shader "MMN/FX/FX_MMCustomParticle"
{
    Properties
    {
        _RamdomSeed ("건담시드 아니고 랜덤시드", Float) = 0
        [Toggle] _Billboard ("빌보드 On", Float) = 1
        _EmitterDimention ("이미터 사이즈", Vector) = (0.1,0.1,0.1,1)
        _FlowConstant ("플로우 상수(0이면 Burst)", Range(0, 1)) = 1
        _StartSize ("파티클 시작 크기", Float) = 0.5
        _EndSize ("파티클 끝 크기", Float) = 0.5
        _SizeRandom ("파티클 입자 크기 랜덤", Range(0, 1)) = 0
        _Scale ("파티클 입자 스케일", Vector) = (1,1,1,1)
        _SizeWave ("파티클 입자 크기 웨이브", Range(0, 1)) = 0
        _SizeWaveTimeSpeed ("파티클 입자 크기 웨이브 스피드", Float) = 30
        _ParticleSpeed ("파티클 스피드", Float) = 0.3
        _ParticleSpread ("파티클 스프레드", Range(0, 360)) = 60
        _ParticleVelocityStart ("시작 벨로시티", Float) = 3
        _ParticleVelocityEnd ("종료 벨로시티", Float) = 3
        _ParticleDirection ("파티클 디렉션", Vector) = (0,1,0,0)
        _OrbitalSpeedMin ("Orbital Min (xyz)", Vector) = (0,0,0,0)
        _OrbitalSpeedMax ("Orbital Max (xyz)", Vector) = (0,0,0,0)
        _Wind ("바람", Vector) = (0,0,0,0)
        _Gravity ("중력", Vector) = (0,0,0,0)
        [Toggle] _IfRandomRotation ("회전을 랜덤방향으로 할까요?", Float) = 0
        [Toggle] _IfRandomRotationStart ("회전 시작 각도를 랜덤으로 할까요?", Float) = 0
        _RotationSpeed ("회전속도", Float) = 0
        _Rotation ("초기 회전 각도", Float) = 0
        _BaseMap ("베이스맵", 2D) = "white" {}
        _Flipbook ("플립북 XY", Vector) = (1,1,0,0)
        _FlipbookSpeed ("플립북 속도", Float) = 1
        [Toggle] _MatchParticleLife ("파티클 라이프와 매칭할까요?", Float) = 0
        _StartColor ("파티클 시작 칼라", Color) = (1,1,1,1)
        _EndColor ("파티클 끝 칼라", Color) = (1,1,1,1)
        _StartAlpha ("파티클 시작 알파", Range(0.1, 10)) = 0.1
        _EndAlpha ("파티클 끝 알파", Range(0.1, 10)) = 0.1
        [Toggle(_DISSOLVE_FEATURE)] _IsDissolve ("디졸브 켜기", Float) = 0
        _DissolveMap ("Dissolve 맵", 2D) = "gray" {}
        _DissolveAmount ("Dissolve 진행도", Range(0, 1)) = 1
        [Toggle] _DissolveCutoff ("디졸브 컷오프를 켤까요?", Float) = 1
        _DissolveEdgeColor ("디졸브 경계의 색상", Color) = (0,0,0,0)
        _DissolveEdgeWidth ("디졸브 경계의 두께", Range(0, 1)) = 0.5
        [KeywordEnum(Default, OnlyDay, OnlyNight)] _Day_Alpha ("낮/밤 보이기", Float) = 0
        [Toggle] _IsDebugTime ("메뉴얼 시간 사용", Float) = 0
        _ManualTime ("메뉴얼 시간 제어", Range(0, 1)) = 0
        [Toggle] _DebugColor ("디버그 칼라 사용", Float) = 0
        [Toggle] _LightReceive ("라이트가 적용될까요?", Float) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [Toggle] _FogReceive ("포그가 적용될까요?", Float) = 0
        [ToggleUI] _NearPlaneAlpha ("NearPlaneAlpha", Range(0, 18)) = 0
        _NearPlaneAlphaEdge ("NearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] _NearPlaneInvertDistance ("NearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDitherMode ("NearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDirectionMode ("NearPlaneDirectionMode", Range(0, 1)) = 0
        _NearPlaneDirectionValue ("NearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [ToggleUI] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle(_RAYCAST_ON)] _Raycast ("Raycast", Float) = 1
        _RaycastHarftoneClip ("RaycastHarftoneClip", Range(0, 1)) = 0
        _RaycastMinimumAlpha ("RaycastMinimumAlpha", Range(0, 1)) = 0
        _TransitionValue ("TransitionValue", Float) = 1
        _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        _BlendMode ("Blend Mode", Float) = -1
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
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

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_DissolveMap); SAMPLER(sampler_DissolveMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _DissolveMap_ST;
                float _RamdomSeed;
                float _Billboard;
                float4 _EmitterDimention;
                float _FlowConstant;
                float _StartSize;
                float _EndSize;
                float _SizeRandom;
                float4 _Scale;
                float _SizeWave;
                float _SizeWaveTimeSpeed;
                float _ParticleSpeed;
                float _ParticleSpread;
                float _ParticleVelocityStart;
                float _ParticleVelocityEnd;
                float4 _ParticleDirection;
                float4 _OrbitalSpeedMin;
                float4 _OrbitalSpeedMax;
                float4 _Wind;
                float4 _Gravity;
                float _IfRandomRotation;
                float _IfRandomRotationStart;
                float _RotationSpeed;
                float _Rotation;
                float4 _Flipbook;
                float _FlipbookSpeed;
                float _MatchParticleLife;
                float4 _StartColor;
                float4 _EndColor;
                float _StartAlpha;
                float _EndAlpha;
                float _IsDissolve;
                float _DissolveAmount;
                float _DissolveCutoff;
                float4 _DissolveEdgeColor;
                float _DissolveEdgeWidth;
                float _Day_Alpha;
                float _IsDebugTime;
                float _ManualTime;
                float _DebugColor;
                float _LightReceive;
                float _LightRatio;
                float _FogReceive;
                float _NearPlaneAlpha;
                float4 _NearPlaneAlphaEdge;
                float _NearPlaneInvertDistance;
                float _NearPlaneDitherMode;
                float _NearPlaneDirectionMode;
                float4 _NearPlaneDirectionValue;
                float _SoftParticle;
                float _SoftParticleNearFadeDistance;
                float _SoftParticleFarFadeDistance;
                float _SoftParticleFadeOutRange;
                float _Raycast;
                float _RaycastHarftoneClip;
                float _RaycastMinimumAlpha;
                float _TransitionValue;
                float _SpawnTransition;
                float _BlendMode;
                float _CullMode;
                float _ZTest;
                float _BlendSrc;
                float _BlendDst;
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
                o.uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half texAlpha = tex.a;
                half3 color = tex.rgb * i.color.rgb;
                half alpha = saturate(texAlpha * i.color.a);
                alpha *= MMN_NearPlaneFade(i.positionWS, i.screenPos, _NearPlaneAlpha,
                                           _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                           _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                           _RaycastMinimumAlpha, _NearPlaneDitherMode);
                color = MMN_LightReceive(color, _LightReceive, _LightRatio);
                alpha *= MMN_SoftParticleFade(i.screenPos, _SoftParticle,
                                              _SoftParticleNearFadeDistance,
                                              _SoftParticleFarFadeDistance,
                                              _SoftParticleFadeOutRange);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
