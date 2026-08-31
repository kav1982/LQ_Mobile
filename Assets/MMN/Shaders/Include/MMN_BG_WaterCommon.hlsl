#ifndef MMN_BG_WATER_COMMON_INCLUDED
#define MMN_BG_WATER_COMMON_INCLUDED

// Shared helpers for MMN/BG/Water and MMN/BG/Waterfall, transcribed from
// _re_work/shader_contracts/MMN_BG_Water.asm.txt and MMN_BG_Waterfall.asm.txt.
//
// NOT-IMPLEMENTED: MiniGBuffer cubemap sky / sun-disk / clouds. URP reflection
//                  probe stands in, same as PlanarReflectionWater.
// NOT-IMPLEMENTED: FOG_LINEAR, additional lights, DEBUG_DISPLAY.
// NOT-IMPLEMENTED: _IsRaindrop rain ripples (gated by _Global_Raining, which is 0 here).
// NOT-IMPLEMENTED: _FoamEdgeIntensity — the shipped Water ps_5_0 never loads it;
//                  shore foam comes from scene-depth thickness + _FoamOffset.

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_DistortionTexture); SAMPLER(sampler_DistortionTexture);
TEXTURE2D(_BumpMap);           SAMPLER(sampler_BumpMap);

void MMN_WaterFlowUVs(float2 uv, float flowSpeed, out float2 uvA, out float2 uvB)
{
    float t = _Time.y * flowSpeed;
    uvA = uv * 5.0 + float2(0.0, -t / 30.0);
    uvB = uv + float2(0.0, -t / 42.0);
}

half3 MMN_UnpackRG(half4 packed)
{
    return UnpackNormal(packed);
}

half3 MMN_SampleFlowNormalTS(float2 uvA, float2 uvB, float4 bumpST, half distortionAmount)
{
    half3 n1 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvA * bumpST.xy + bumpST.zw));
    half3 n2 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvB * bumpST.xy + bumpST.zw));
    half3 n = half3(n1.xy + n2.xy, n1.z * n2.z);
    n.xy *= distortionAmount;
    return normalize(n);
}

float MMN_WaterThickness(float3 positionWS, float4 screenPos)
{
    float2 screenUV = screenPos.xy / screenPos.w;
    float sceneEye = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
    float viewZ = TransformWorldToView(positionWS).z;
    return max(sceneEye - abs(viewZ), 0.0);
}

half3 MMN_SampleProbe(half3 reflectDir)
{
    half4 probe = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDir, 0);
    half3 sky = saturate((half3)DecodeHDREnvironment(probe, unity_SpecCube0_HDR));
    // MiniGBuffer sky is not in this project; an empty probe turns fresnel into black
    // blotches that follow the distortion texture. Treat missing env as white so
    // _FresnelColor is the reflection tint.
    return (dot(sky, 1.0h) < 0.02h) ? half3(1.0h, 1.0h, 1.0h) : sky;
}

// Sid_Water_01 stores 10 discrete tangent directions (one per pie slice). Using those
// in the TBN turns the flow normal into radial sector stripes. A continuous
// world-aligned frame keeps the disc smooth; UV0 (V = radius) still drives concentric flow.
void MMN_WorldTBN(half3 normalWS, out half3 tangentWS, out half3 bitangentWS)
{
    half3 n = normalize(normalWS);
    half3 t = (abs(n.y) > 0.7h) ? half3(1.0h, 0.0h, 0.0h) : half3(0.0h, 1.0h, 0.0h);
    t = normalize(t - n * dot(n, t));
    tangentWS = t;
    bitangentWS = cross(n, t);
}

half MMN_CustomFresnel(half3 normalWS, half3 viewDirWS, half distTerm)
{
    half sinLenSq = saturate(1.0h - pow(saturate(dot(normalWS, viewDirWS)), 2.0h));
    half oneMinusCos = 1.0h - sqrt(1.0h - sinLenSq);
    half x = distTerm * 0.142857h + oneMinusCos;
    half x2 = x * x;
    half x5 = x2 * x2 * x;
    return saturate(x5 * 0.983h + 0.017h);
}

#endif
