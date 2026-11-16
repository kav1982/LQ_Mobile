#ifndef MMN_BG_OCEAN_SUN_GLITTER_PATH_INCLUDED
#define MMN_BG_OCEAN_SUN_GLITTER_PATH_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

TEXTURE2D(_NoiseTex);
SAMPLER(sampler_NoiseTex);

CBUFFER_START(UnityPerMaterial)
    float4 _NoiseTex_ST;
    half4 _TintColor;
    float _SunProgress;
    float4 _SunPositionWS;
    float _ReachThreshold;
    float _SpreadThreshold;
    float _FadeThreshold;
    float _GlitterWidth;
    float _SpreadWidth;
    float _InitialIntensity;
    float _SpreadIntensity;
    float _SpreadDuration;
    float _SpreadDimPower;
    float _SparkleScale;
    float _SparkleDensity;
    float _SparkleSpeed;
    float _PeakStartRatio;
    float _PeakEndRatio;
    float _PeakTargetPos;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
};

Varyings vert(Attributes v)
{
    Varyings o;
    VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
    o.positionCS = pos.positionCS;
    o.positionWS = pos.positionWS;
    o.uv = TRANSFORM_TEX(v.uv, _NoiseTex);
    return o;
}

float Timeline(float progress)
{
    // Contract labels _SunProgress as "진행도 (Time)". When the slider sits at 0
    // (no Animator driving it) the ribbon still loops so the imported prefab is
    // visible; authored values in (0,1] stay as a frozen timeline.
    if (progress > 0.0001)
        return saturate(progress);
    return frac(_Time.y * 0.08);
}

half4 frag(Varyings i) : SV_Target
{
    float3 originWS = float3(UNITY_MATRIX_M._m03, UNITY_MATRIX_M._m13, UNITY_MATRIX_M._m23);
    float2 origin = originWS.xz;
    float2 sun = _SunPositionWS.xz;
    float2 toSun = sun - origin;
    float pathLen = max(length(toSun), 1.0);
    float2 axis = toSun / pathLen;
    float2 perp = float2(-axis.y, axis.x);

    float2 p = i.positionWS.xz - origin;
    float along = dot(p, axis);
    float across = dot(p, perp);
    float u = saturate(along / pathLen);

    float t = Timeline(_SunProgress);
    float reachT = saturate(t / max(_ReachThreshold, 0.01));
    float head = reachT * pathLen;

    float spreadT = saturate((t - _SpreadThreshold) / max(_SpreadDuration, 0.0001));
    float width = lerp(max(_GlitterWidth, 0.01), max(_SpreadWidth, 0.01), spreadT);

    float fade = 1.0 - saturate((t - _FadeThreshold) / max(1.0 - _FadeThreshold, 0.0001));

    float alongMask = saturate((head - along) * (8.0 / pathLen));
    alongMask *= saturate(along * (8.0 / pathLen));
    float acrossMask = saturate(1.0 - abs(across) / width);
    acrossMask *= acrossMask;

    float peakSpan = max(_PeakEndRatio - _PeakStartRatio, 0.0001);
    float peakT = saturate((reachT - _PeakStartRatio) / peakSpan);
    float peakPos = lerp(0.0, _PeakTargetPos, peakT);
    float peak = saturate(1.0 - abs(u - peakPos) * 6.0);
    peak *= peak;

    float dim = pow(max(1.0 - spreadT, 0.0001), max(_SpreadDimPower, 0.01));
    float intensity = lerp(_InitialIntensity, _SpreadIntensity, spreadT) * dim;
    intensity = lerp(intensity, intensity * 1.8, peak);

    float2 sparkUV = i.uv * max(_SparkleScale, 0.01) + float2(_Time.y * _SparkleSpeed, _Time.y * _SparkleSpeed * 0.37);
    float n = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, sparkUV).r;
    float sparkle = saturate((n - _SparkleDensity) / max(1.0 - _SparkleDensity, 0.0001));
    sparkle = sparkle * sparkle * (0.35 + 0.65 * n);

    float mask = alongMask * acrossMask * fade;
    half3 col = _TintColor.rgb * (intensity * (0.25 + sparkle));
    half alpha = mask * _TintColor.a * sparkle;
    return half4(col * alpha, alpha);
}

#endif
