// Playable reconstruction of MMN/FX/FX_MMCustomParticle from the extracted contract.
// Original GPU bytecode was not recovered; vertex particle sim, flipbook UVs, colour/size
// over life and billboarding follow the material property names and the stacked-quad mesh
// (N unit quads at the origin, vertex colour.r = per-particle seed).
//
// NOT-IMPLEMENTED: FOG_LINEAR (client fog globals). DEBUG_DISPLAY.
// NOT-IMPLEMENTED: true scene raycast-to-ground. _RAYCAST_ON uses the same harftone clip
//                  as the rest of the FX family.
Shader "MMN/FX/FX_MMCustomParticle"
{
    Properties
    {
        _RamdomSeed ("不是高达种子，是随机种子", Float) = 0
        [ToggleUI] _Billboard ("广告牌开启", Float) = 1
        _EmitterDimention ("发射器尺寸", Vector) = (0.1,0.1,0.1,1)
        _FlowConstant ("流动常数（0为Burst）", Range(0, 1)) = 1
        _StartSize ("粒子起始大小", Float) = 0.5
        _EndSize ("粒子结束大小", Float) = 0.5
        _SizeRandom ("粒子大小随机", Range(0, 1)) = 0
        _Scale ("粒子缩放", Vector) = (1,1,1,1)
        _SizeWave ("粒子大小波动", Range(0, 1)) = 0
        _SizeWaveTimeSpeed ("粒子大小波动速度", Float) = 30
        _ParticleSpeed ("粒子速度", Float) = 0.3
        _ParticleSpread ("粒子扩散角度", Range(0, 360)) = 60
        _ParticleVelocityStart ("起始速度", Float) = 3
        _ParticleVelocityEnd ("结束速度", Float) = 3
        _ParticleDirection ("粒子方向", Vector) = (0,1,0,0)
        _OrbitalSpeedMin ("Orbital Min (xyz)", Vector) = (0,0,0,0)
        _OrbitalSpeedMax ("Orbital Max (xyz)", Vector) = (0,0,0,0)
        _Wind ("风", Vector) = (0,0,0,0)
        _Gravity ("重力", Vector) = (0,0,0,0)
        [ToggleUI] _IfRandomRotation ("旋转方向随机？", Float) = 0
        [ToggleUI] _IfRandomRotationStart ("起始旋转角度随机？", Float) = 0
        _RotationSpeed ("旋转速度", Float) = 0
        _Rotation ("初始旋转角度", Float) = 0
        _BaseMap ("基础贴图", 2D) = "white" {}
        _Flipbook ("序列帧 XY", Vector) = (1,1,0,0)
        _FlipbookSpeed ("序列帧速度", Float) = 1
        [ToggleUI] _MatchParticleLife ("与粒子生命周期匹配？", Float) = 0
        _StartColor ("粒子起始颜色", Color) = (1,1,1,1)
        _EndColor ("粒子结束颜色", Color) = (1,1,1,1)
        _StartAlpha ("粒子起始透明度", Range(0.1, 10)) = 0.1
        _EndAlpha ("粒子结束透明度", Range(0.1, 10)) = 0.1
        [Toggle(_DISSOLVE_FEATURE)] _IsDissolve ("开启溶解", Float) = 0
        _DissolveMap ("溶解贴图", 2D) = "gray" {}
        _DissolveAmount ("溶解进度", Range(0, 1)) = 1
        [ToggleUI] _DissolveCutoff ("开启溶解裁剪？", Float) = 1
        _DissolveEdgeColor ("溶解边缘颜色", Color) = (0,0,0,0)
        _DissolveEdgeWidth ("溶解边缘宽度", Range(0, 1)) = 0.5
        [KeywordEnum(Default, OnlyDay, OnlyNight)] _Day_Alpha ("昼夜可见性", Float) = 0
        [ToggleUI] _IsDebugTime ("使用手动时间", Float) = 0
        _ManualTime ("手动时间控制", Range(0, 1)) = 0
        [ToggleUI] _DebugColor ("使用调试颜色", Float) = 0
        [ToggleUI] _LightReceive ("接收光照？", Float) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] _FogReceive ("接收雾效？", Float) = 0
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
            "PreviewType" = "Plane"
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
            #pragma shader_feature_local _RAYCAST_ON
            #pragma shader_feature_local _DISSOLVE_FEATURE
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_DissolveMap); SAMPLER(sampler_DissolveMap);

            float _Global_Night2Day;

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

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : COLOR;
                float life : TEXCOORD3;
            };

            float MMN_Hash11(float p)
            {
                p = frac(p * 0.1031);
                p *= p + 33.33;
                p *= p + p;
                return frac(p);
            }

            float MMN_ParticleHash(float seed, float salt)
            {
                return MMN_Hash11(seed * 17.13 + _RamdomSeed * 0.013 + salt);
            }

            float3 MMN_ConeDir(float3 baseDir, float spreadDeg, float seed)
            {
                float3 dir = baseDir;
                float len = length(dir);
                dir = len > 1e-5 ? dir / len : float3(0.0, 1.0, 0.0);

                float spread = radians(max(spreadDeg, 0.0)) * 0.5;
                float a = MMN_ParticleHash(seed, 1.1) * 6.2831853;
                float z = lerp(cos(spread), 1.0, MMN_ParticleHash(seed, 2.3));
                float r = sqrt(max(1.0 - z * z, 0.0));
                float3 local = float3(cos(a) * r, sin(a) * r, z);

                float3 up = abs(dir.y) < 0.999 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
                float3 t = normalize(cross(up, dir));
                float3 b = cross(dir, t);
                return normalize(t * local.x + b * local.y + dir * local.z);
            }

            float3 MMN_RotateAxis(float3 v, float3 axis, float angle)
            {
                float s, c;
                sincos(angle, s, c);
                return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
            }

            float2 MMN_FlipbookUV(float2 uv, float2 tiles, float frame, float loop)
            {
                tiles = max(tiles, float2(1.0, 1.0));
                float2 tileSize = 1.0 / tiles;
                float count = tiles.x * tiles.y;
                float f = loop > 0.5
                    ? floor(fmod(max(frame, 0.0), count))
                    : floor(clamp(frame, 0.0, count - 0.001));
                float col = fmod(f, tiles.x);
                float row = floor(f / tiles.x);
                // PNG frame 0 is top-left; Unity UV y=0 is bottom, so invert the row.
                float2 cell = float2(col, tiles.y - 1.0 - row);
                float2 inset = tileSize * 0.02;
                return uv * (tileSize - 2.0 * inset) + cell * tileSize + inset;
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;

                float seed = v.color.r;
                float fxTime = MMN_FxTime();
                float life = frac(fxTime * max(_ParticleSpeed, 1e-4) + seed * _FlowConstant);
                life = _IsDebugTime > 0.5 ? saturate(_ManualTime) : life;

                float3 spawnOS = (float3(
                    MMN_ParticleHash(seed, 3.7),
                    MMN_ParticleHash(seed, 4.9),
                    MMN_ParticleHash(seed, 6.1)) * 2.0 - 1.0) * _EmitterDimention.xyz * 0.5;

                float3 dirOS = MMN_ConeDir(_ParticleDirection.xyz, _ParticleSpread, seed);
                float speed = lerp(_ParticleVelocityStart, _ParticleVelocityEnd, life);
                float3 posOS = spawnOS + dirOS * (speed * life);

                float3 posWS = TransformObjectToWorld(posOS);
                float3 emitterWS = TransformObjectToWorld(float3(0.0, 0.0, 0.0));
                posWS += _Gravity.xyz * (0.5 * life * life) + _Wind.xyz * life;

                float3 orb = lerp(_OrbitalSpeedMin.xyz, _OrbitalSpeedMax.xyz,
                                  MMN_ParticleHash(seed, 7.3));
                float3 rel = posWS - emitterWS;
                rel = MMN_RotateAxis(rel, float3(1, 0, 0), orb.x * life);
                rel = MMN_RotateAxis(rel, float3(0, 1, 0), orb.y * life);
                rel = MMN_RotateAxis(rel, float3(0, 0, 1), orb.z * life);
                posWS = emitterWS + rel;

                float size = lerp(_StartSize, _EndSize, life);
                float sizeRand = lerp(1.0 - _SizeRandom, 1.0 + _SizeRandom, MMN_ParticleHash(seed, 8.5));
                size *= sizeRand;
                size *= 1.0 + sin(fxTime * _SizeWaveTimeSpeed + seed * 6.2831853) * _SizeWave;
                float2 quadScale = _Scale.xy * size;

                // _Rotation is degrees. _RotationSpeed is radians over the particle's life
                // (waterfall=1 ≈ 57°, leaves=3..5 ≈ a three-quarter tumble). Multiplying by
                // 2π treated speed 1 as a full revolution and spun the flipbook with the quad.
                float rot = radians(_Rotation);
                rot += _IfRandomRotationStart > 0.5 ? MMN_ParticleHash(seed, 9.7) * 6.2831853 : 0.0;
                float rotSign = 1.0;
                if (_IfRandomRotation > 0.5)
                    rotSign = MMN_ParticleHash(seed, 10.9) > 0.5 ? 1.0 : -1.0;
                rot += _RotationSpeed * life * rotSign;

                float3 axisRight, axisUp;
                if (_Billboard > 0.5)
                {
                    axisRight = UNITY_MATRIX_I_V._m00_m10_m20;
                    axisUp = UNITY_MATRIX_I_V._m01_m11_m21;
                }
                else
                {
                    axisRight = TransformObjectToWorldDir(float3(1.0, 0.0, 0.0), false);
                    axisUp = TransformObjectToWorldDir(float3(0.0, 1.0, 0.0), false);
                }

                float s, c;
                sincos(rot, s, c);
                float2 corner = v.positionOS.xy;
                float2 rcorner = float2(corner.x * c - corner.y * s, corner.x * s + corner.y * c);
                posWS += axisRight * (rcorner.x * quadScale.x) + axisUp * (rcorner.y * quadScale.y);

                o.positionWS = posWS;
                o.positionCS = TransformWorldToHClip(posWS);
                o.screenPos = ComputeScreenPos(o.positionCS);

                float2 uv = v.uv * _BaseMap_ST.xy + _BaseMap_ST.zw;
                float2 tiles = max(_Flipbook.xy, float2(1.0, 1.0));
                float frameCount = tiles.x * tiles.y;
                float frame = _MatchParticleLife > 0.5
                    ? life * frameCount * max(_FlipbookSpeed, 0.0)
                    : (fxTime * _FlipbookSpeed + seed) * frameCount;
                o.uv = MMN_FlipbookUV(uv, tiles, frame, _MatchParticleLife > 0.5 ? 0.0 : 1.0);

                float4 particleCol = lerp(_StartColor, _EndColor, life);
                particleCol.a = lerp(_StartAlpha, _EndAlpha, life);
                o.color = _DebugColor > 0.5 ? float4(seed, seed, seed, 1.0) : particleCol;
                o.life = life;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half texAlpha = tex.a;
                half3 color = tex.rgb * i.color.rgb;
                half alpha = texAlpha * i.color.a;

                half daylight = saturate(_Global_Night2Day);
                half timeOfDay = lerp(1.0h, daylight, saturate(_Day_Alpha));
                timeOfDay += saturate(_Day_Alpha - 1.0h) * (1.0h - 2.0h * timeOfDay);
                alpha *= timeOfDay;

                #if defined(_DISSOLVE_FEATURE)
                if (_IsDissolve > 0.5)
                {
                    half dissolve = SAMPLE_TEXTURE2D(_DissolveMap, sampler_DissolveMap,
                        i.uv * _DissolveMap_ST.xy + _DissolveMap_ST.zw).r;
                    half threshold = lerp(1.0h - (half)_DissolveAmount, 1.0h, (half)i.life);
                    half edge = (half)_DissolveEdgeWidth;
                    if (_DissolveCutoff > 0.5)
                    {
                        half clipV = dissolve - threshold;
                        color += _DissolveEdgeColor.rgb * (half)_DissolveEdgeColor.a *
                                 saturate(1.0h - abs(clipV) / max(edge, 1e-4h));
                        clip(clipV);
                    }
                    else
                    {
                        alpha *= saturate((dissolve - threshold + edge) / max(edge, 1e-4h));
                    }
                }
                #endif

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
                MMN_ApplyModeTransition(color, alpha, _BlendMode, _TransitionValue, _SpawnTransition);
                return half4(color, saturate(alpha));
            }
            ENDHLSL
        }
    }
    FallBack Off
}
