Shader "MMN/FX/FX_MMCustomParticle"
{
    // NOT-IMPLEMENTED: generated compatibility shell; original HLSL unavailable.
                Properties
    {
        _RamdomSeed ("随机种子（不是高达种子）", Float) = 0
        [Toggle] _Billboard ("Billboard 开", Float) = 1
        _EmitterDimention ("Emitter 尺寸", Vector) = (0.1,0.1,0.1,1)
        _FlowConstant ("流动常数（0 为 Burst）", Range(0, 1)) = 1
        _StartSize ("粒子起始大小", Float) = 0.5
        _EndSize ("粒子结束大小", Float) = 0.5
        _SizeRandom ("粒子大小随机", Range(0, 1)) = 0
        _Scale ("粒子缩放", Vector) = (1,1,1,1)
        _SizeWave ("粒子大小波动", Range(0, 1)) = 0
        _SizeWaveTimeSpeed ("粒子大小波动速度", Float) = 30
        _ParticleSpeed ("粒子速度", Float) = 0.3
        _ParticleSpread ("粒子扩散", Range(0, 360)) = 60
        _ParticleVelocityStart ("起始速度", Float) = 3
        _ParticleVelocityEnd ("结束速度", Float) = 3
        _ParticleDirection ("粒子方向", Vector) = (0,1,0,0)
        _OrbitalSpeedMin ("Orbital Min (xyz)", Vector) = (0,0,0,0)
        _OrbitalSpeedMax ("Orbital Max (xyz)", Vector) = (0,0,0,0)
        _Wind ("风", Vector) = (0,0,0,0)
        _Gravity ("重力", Vector) = (0,0,0,0)
        [Toggle] _IfRandomRotation ("旋转方向是否随机", Float) = 0
        [Toggle] _IfRandomRotationStart ("起始旋转角是否随机", Float) = 0
        _RotationSpeed ("旋转速度", Float) = 0
        _Rotation ("初始旋转角", Float) = 0
        _BaseMap ("基础贴图", 2D) = "white" {}
        _Flipbook ("Flipbook XY", Vector) = (1,1,0,0)
        _FlipbookSpeed ("Flipbook 速度", Float) = 1
        [Toggle] _MatchParticleLife ("是否匹配粒子生命周期", Float) = 0
        _StartColor ("粒子起始颜色", Color) = (1,1,1,1)
        _EndColor ("粒子结束颜色", Color) = (1,1,1,1)
        _StartAlpha ("粒子起始 Alpha", Range(0.1, 10)) = 0.1
        _EndAlpha ("粒子结束 Alpha", Range(0.1, 10)) = 0.1
        [Toggle(_DISSOLVE_FEATURE)] _IsDissolve ("开启 Dissolve", Float) = 0
        _DissolveMap ("Dissolve 贴图", 2D) = "gray" {}
        _DissolveAmount ("Dissolve 进度", Range(0, 1)) = 1
        [Toggle] _DissolveCutoff ("是否开启 Dissolve 裁剪", Float) = 1
        _DissolveEdgeColor ("Dissolve 边缘颜色", Color) = (0,0,0,0)
        _DissolveEdgeWidth ("Dissolve 边缘宽度", Range(0, 1)) = 0.5
        [KeywordEnum(Default, OnlyDay, OnlyNight)] _Day_Alpha ("昼/夜可见", Float) = 0
        [Toggle] _IsDebugTime ("使用手动时间", Float) = 0
        _ManualTime ("手动时间控制", Range(0, 1)) = 0
        [Toggle] _DebugColor ("使用调试颜色", Float) = 0
        [Toggle] _LightReceive ("是否接受光照", Float) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [Toggle] _FogReceive ("是否接受雾", Float) = 0
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
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" }
        LOD 100
        Pass
        {
            Name ""
            Tags { "LightMode" = "" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct A { float4 positionOS : POSITION; };
            float4 vert(A v) : SV_POSITION { return TransformObjectToHClip(v.positionOS.xyz); }
            half4 frag() : SV_Target { return 0; }
            ENDHLSL
        }
 
   }
    FallBack Off
}
