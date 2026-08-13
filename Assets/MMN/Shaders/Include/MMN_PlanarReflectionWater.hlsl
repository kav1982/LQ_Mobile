#ifndef MMN_PLANAR_REFLECTION_WATER_INCLUDED
#define MMN_PLANAR_REFLECTION_WATER_INCLUDED

// Body of MMN/Special/PlanarReflectionWater. The shipped shader has two SubShaders (LOD 300 and
// LOD 100) that share one pass named "Base"; both include this file, the LOD 100 one with
// MMN_WATER_LOW defined.
//
// Reconstructed from the D3D11 ps_5_0 of SubShader 0 / Pass 0 (LOD 300). The perturbed normal
// is used only for cubemap/planar direction, the planar UV offset, and the specular lobe.
// Fresnel, foam grazing and alpha all use the interpolated geometric normal - that is why the
// game water reads as a flat sheet with occasional foam, not a normal-mapped surface.
//
// NOT-IMPLEMENTED: _Global_Sky*/_Global_Sun*/_Global_Night2Day/_Global_Raining and the
//                  MiniGBuffer cubemaps. URP's reflection probe stands in for the procedural
//                  sky; the rain-ripple add (gated by _Global_Raining) stays at zero.
// NOT-IMPLEMENTED: _FoamEdgeIntensity is a shipped property the program never loads.

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

TEXTURE2D(_DistortionTexture);       SAMPLER(sampler_DistortionTexture);
TEXTURE2D(_BumpMap);                 SAMPLER(sampler_BumpMap);
TEXTURE2D(_PlanarReflectionTexture); SAMPLER(sampler_PlanarReflectionTexture);

CBUFFER_START(UnityPerMaterial)
    float4 _DistortionTexture_ST;
    float4 _BumpMap_ST;
    half4 _ScatterColor1;
    half4 _ScatterColor2;
    half4 _ScatterColor3;
    half4 _FresnelColor;
    half4 _FoamColor;
    half4 _ReflectionColor;
    half4 _SpecColor;
    half _RaycastHarftoneClip;
    float _ScatterDepth2;
    float _ScatterDepth3;
    half _Turbidity;
    float _DepthScale;
    half _FoamOpacity;
    half _FoamOffset;
    half _FoamEdgeIntensity;
    float _FlowSpeed;
    half _DistortionAmount;
    half _SpecualrNormalMulti;
    float _Glossiness;
    half _LowOptionEnable;
    float _ReflectionPower;
    float _ReflectionMipmapLevel;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    float2 uv : TEXCOORD0;
    float4 color : COLOR;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    float4 screenPos : TEXCOORD4;
    float4 color : COLOR;
};

Varyings WaterVertex(Attributes v)
{
    Varyings o = (Varyings)0;
    VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
    VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS, v.tangentOS);

    o.positionCS = pos.positionCS;
    o.positionWS = pos.positionWS;
    o.normalWS = nrm.normalWS;
    o.tangentWS = float4(nrm.tangentWS, v.tangentOS.w);
    o.uv = v.uv;
    o.screenPos = ComputeScreenPos(pos.positionCS);
    o.color = v.color;
    return o;
}

// Dual-layer UVs from the shipped ps_5_0: one layer is UV*5 scrolling at Time.y*FlowSpeed/30,
// the other is UV scrolling at Time.y*FlowSpeed/42, both only on V.
void WaterFlowUVs(float2 uv, out float2 uvA, out float2 uvB)
{
    float t = _Time.y * _FlowSpeed;
    uvA = uv * 5.0 + float2(0.0, -t / 30.0);
    uvB = uv + float2(0.0, -t / 42.0);
}

half3 SampleFlowNormal(float2 uvA, float2 uvB, float strength)
{
    half3 n1 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(uvA, _BumpMap)));
    half3 n2 = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, TRANSFORM_TEX(uvB, _BumpMap)));
    half3 n = half3(n1.xy + n2.xy, n1.z * n2.z);
    n.xy *= strength;
    return normalize(n);
}

// Unity perceptual-roughness mip from the shipped program:
//   roughness = 1 - Glossiness/256
//   mip = roughness * (1.7 - 0.7*roughness) * 6
float SpecCubeMipFromGlossiness(float glossiness)
{
    float roughness = 1.0 - glossiness * 0.003906;
    return roughness * (1.7 - 0.7 * roughness) * 6.0;
}

half3 SampleProbeReflection(half3 normalWS, float3 viewDirWS)
{
    half3 reflectDir = reflect(-viewDirWS, normalWS);
    half4 probe = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDir,
                                         SpecCubeMipFromGlossiness(_Glossiness));
    return DecodeHDREnvironment(probe, unity_SpecCube0_HDR);
}

half4 WaterFragment(Varyings i) : SV_Target
{
    float2 screenUV = i.screenPos.xy / i.screenPos.w;

    float2 uvA, uvB;
    WaterFlowUVs(i.uv, uvA, uvB);

    // High-spec foam is a 3-tap of _DistortionTexture: tapA.R, tapB.G, tapA.yx.B.
    // The previous reconstruction swapped R/G, which broke the open-water speckles.
    float2 distA = TRANSFORM_TEX(uvA, _DistortionTexture);
    float2 distB = TRANSFORM_TEX(uvB, _DistortionTexture);
    half s1 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA).r;
    half s2 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distB).g;
    half s3 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA.yx).b;

    float3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
    half3 geomNormalWS = normalize(i.normalWS);

#if defined(MMN_WATER_LOW)
    half3 normalWS = geomNormalWS;
#else
    float sgn = i.tangentWS.w;
    float3 bitangent = sgn * cross(i.normalWS.xyz, i.tangentWS.xyz);
    half3x3 tangentToWorld = half3x3(i.tangentWS.xyz, bitangent, i.normalWS.xyz);
    half3 normalWS = normalize(TransformTangentToWorld(
        SampleFlowNormal(uvA, uvB, _DistortionAmount), tangentToWorld));
#endif

    // Eye-space thickness: scene LinearEyeDepth minus |view-space Z| of the water surface.
    // _DepthScale DIVIDES that thickness.
    float sceneDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
    float viewZ = TransformWorldToView(i.positionWS).z;
    float thickness = max(sceneDepth - abs(viewZ), 0.0);
    float depthScaled = unity_OrthoParams.w > 0.5 ? 5.0 : thickness / max(_DepthScale, 1e-4);

    half3 scatter = lerp(_ScatterColor1.rgb, _ScatterColor2.rgb,
                         saturate(depthScaled / max(_ScatterDepth2, 1e-4)));
    scatter = lerp(scatter, _ScatterColor3.rgb,
                   saturate((depthScaled - _ScatterDepth2) / max(_ScatterDepth3 - _ScatterDepth2, 1e-4)));

    // 1 - |Turbidity|^(thickness/DepthScale). Shore goes transparent so the sand shows through.
    half opacity = 1.0h - (half)exp(depthScaled * log(max(abs((float)_Turbidity), 1e-4)));

    half foamPat = (1.0h - (0.3h + 0.5h * s1 + 0.2h * s3)) / max(0.1h + 0.5h * s2, 1e-3h);
    half foamDepth = max(saturate(thickness + _FoamOffset), saturate(0.5 - 3.0 * thickness));
    half foam = 1.0h - pow(saturate(foamPat * foamDepth), 15.0h);
    foam *= saturate(_FoamOpacity - 0.005h * abs((half)viewZ));

    // Geometric N·V: this is what keeps the sheet looking flat. The perturbed normal is not
    // allowed to drive fresnel or the foam grazing term.
    half ndvGeom = saturate(dot(geomNormalWS, viewDirWS));
    half oneMinusNdv = 1.0h - ndvGeom;
    half fresnel6 = oneMinusNdv * oneMinusNdv;
    fresnel6 = fresnel6 * fresnel6 * (oneMinusNdv * oneMinusNdv);
    half fresnelPower = pow(oneMinusNdv, _ReflectionPower);
    half grazing = smoothstep(0.0h, 1.0h, saturate((oneMinusNdv - 0.2h) * 1.428571h));
    half foamMix = saturate(foam * grazing);

    Light mainLight = GetMainLight();

    half3 sky = saturate(SampleProbeReflection(normalWS, viewDirWS));
    half3 color = lerp(scatter, _FresnelColor.rgb * sky, fresnel6);

#if !defined(MMN_WATER_LOW)
    if (_LowOptionEnable < 0.5h)
    {
        // Planar UV offset is view-space perturbed-normal.x * 0.05, not
        // world.xz * DistortionAmount / ReflectionPower.
        float3 viewN = TransformWorldToViewDir(normalWS);
        float2 planarUV = (i.screenPos.xy / max(i.screenPos.w + 0.0001, 1e-4)) + float2(viewN.x * 0.05, 0.0);
        half ndvPerturbed = saturate(dot(normalWS, viewDirWS));
        half planarMip = pow(1.0h - ndvPerturbed, 8.0h) * _ReflectionMipmapLevel;
        half3 planarBlur = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                                planarUV, planarMip).rgb;
        half3 planarSharp = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                                 planarUV, 0.0).rgb;
        half blend127 = pow(oneMinusNdv, 12.7h);
        half3 planar = lerp(planarSharp, planarBlur, blend127) * _ReflectionColor.rgb;
        // The shipped program multiplies _ReflectionColor a second time here. The Colhen
        // material is (1,1,1) so it is a no-op; keep it so a tinted material matches.
        color = lerp(color, planar * _ReflectionColor.rgb, fresnelPower);
    }
#endif

    color = lerp(color, _FoamColor.rgb, foamMix);

    half3 lit = i.color.rgb * mainLight.color;
    color *= lit;

    half specLum = 0.0h;
    half opacitySq = opacity * opacity;
#if !defined(MMN_WATER_LOW)
    // Specular normal is the WORLD perturbed normal with XZ scaled by _SpecualrNormalMulti,
    // then renormalized. Exponent is Glossiness*50 (50.9 → ~2545), then * 0.5.
    // _SpecColor.a is never loaded. The lobe is then multiplied by opacity^2, so the shore
    // has no highlight and the open water only ever shows a pin-prick.
    half3 specNormalWS = normalize(normalWS * half3(_SpecualrNormalMulti, 1.0h, _SpecualrNormalMulti));
    half3 halfDir = normalize(mainLight.direction + viewDirWS);
    half spec = pow(saturate(dot(specNormalWS, halfDir)), _Glossiness * 50.0);
    half3 specCol = spec * 0.5h * mainLight.color * _SpecColor.rgb;
    specLum = dot(specCol, half3(0.212673h, 0.715152h, 0.072175h));
    color = color * 1.5h + specCol * opacitySq;
#else
    color *= 1.5h;
#endif

    half alpha = saturate(foam * grazing + opacity);
    alpha = saturate(alpha + specLum * opacitySq);
    alpha = saturate(alpha + (half)(abs(viewZ) * 0.003333));

    return half4(color, alpha);
}

#endif // MMN_PLANAR_REFLECTION_WATER_INCLUDED
