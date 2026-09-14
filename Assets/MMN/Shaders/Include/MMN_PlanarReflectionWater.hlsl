#ifndef MMN_PLANAR_REFLECTION_WATER_INCLUDED
#define MMN_PLANAR_REFLECTION_WATER_INCLUDED

// Body of MMN/Special/PlanarReflectionWater. The shipped shader has two SubShaders (LOD 300 and
// LOD 100) that share one pass named "Base"; both include this file, the LOD 100 one with
// MMN_WATER_LOW defined.
//
// Reconstructed from the D3D11 ps_5_0 in
// _re_work/shader_contracts/MMN_Special_PlanarReflectionWater.asm.txt:
//   SubShader 0 / Pass 0 / variant 0 (LOD 300)  -> default path
//   SubShader 1 / Pass 0 / variant 0 (LOD 100)  -> MMN_WATER_LOW
// The perturbed normal is used only for cubemap/planar direction, the planar UV offset, and the
// specular lobe. Fresnel, foam grazing and alpha all use the interpolated geometric normal - that
// is why the game water reads as a flat sheet with occasional foam, not a normal-mapped surface.
//
// NOT-IMPLEMENTED: the three _Global_MiniGBuffer* cubemaps (Albedo/Emission/Transparent) are not
//                  in the extracted data. The MiniGBuffer sky path below is evaluated as it is when
//                  they read black: coverage 0, no emission, no cloud term. What remains is the
//                  sky gradient + sun disk/glow + light luminance, driven by the _Global_* uniforms
//                  (set by ColhenBeach.MmnGlobalUniforms in the preview).
// NOT-IMPLEMENTED: the FOG_LINEAR variant (linear + height + dim fog) and the _Global_Raining
//                  ripple add (zero when not raining).

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
    float _ScatterDepth2;
    float _ScatterDepth3;
    half _Turbidity;
    float _DepthScale;
    half _FoamOpacity;
    half _FoamOffset;
    float _FlowSpeed;
    half _DistortionAmount;
    half _SpecualrNormalMulti;
    float _Glossiness;
    half _LowOptionEnable;
    float _ReflectionPower;
    float _ReflectionMipmapLevel;
CBUFFER_END

// Game-side globals ($Globals in the shipped program). Not material properties.
half4 _Global_GILightMulti;
half4 _Global_SkyColorTop;
half4 _Global_SkyColorMiddle;
half4 _Global_SkyColorBottom;
float _Global_SkyPosition1;
float _Global_SkyPosition2;
float _Global_SkyPosition3;
float _Global_SkyPosition4;
float _Global_SunDisk;
float _Global_SunGlowDisk;
half4 _Global_SunGlowColor;
float _Global_Night2Day;
float4 _Global_MiniGBuffer_BoxMin;
float4 _Global_MiniGBuffer_BoxMax;
float _Global_MiniGBuffer_Effective_Weight;

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

// Box-projection style weight: distance to the nearest face over the blend distance.
float BoxWeight(float3 positionWS, float3 boxMin, float3 boxMax, float blend)
{
    float3 d = min(positionWS - boxMin, boxMax - positionWS) / max(blend, 1e-5);
    return saturate(min(d.x, min(d.y, d.z)));
}

// Reflection environment (asm SubShader 0 lines 532-650). Two boxes compete: the URP reflection
// probe (unity_SpecCube0_Box*) and the game's MiniGBuffer box (_Global_MiniGBuffer_Box*). Their
// weights are normalised, but if the MiniGBuffer weight clears 0.01 its result REPLACES the probe
// result outright rather than blending with it.
half3 SampleSky(half3 reflectDir, float3 positionWS)
{
    float w0 = BoxWeight(positionWS, unity_SpecCube0_BoxMin.xyz, unity_SpecCube0_BoxMax.xyz,
                         unity_SpecCube0_BoxMax.w);
    float w1 = BoxWeight(positionWS, _Global_MiniGBuffer_BoxMin.xyz, _Global_MiniGBuffer_BoxMax.xyz,
                         _Global_MiniGBuffer_BoxMax.w);
    float sum = max(w0 + w1, 1e-5);
    w0 /= sum;
    w1 /= sum;
    float mip = SpecCubeMipFromGlossiness(_Glossiness);

    half3 sky = 0.0h;
    if (w0 > 0.01)
    {
        half4 probe = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectDir, mip);
        sky = DecodeHDREnvironment(probe, unity_SpecCube0_HDR) * _Global_GILightMulti.rgb;
    }
    if (w1 > 0.01)
    {
        // Sky gradient by reflected Y: Bottom -> Middle over [Pos1,Pos2], Middle -> Top over
        // [Pos3,Pos4]. Both ramps are smoothstepped; the upper one is additionally squared.
        float t = saturate((reflectDir.y - _Global_SkyPosition3) / (_Global_SkyPosition4 - _Global_SkyPosition3));
        float s = saturate((reflectDir.y - _Global_SkyPosition1) / (_Global_SkyPosition2 - _Global_SkyPosition1));
        t = t * t * (3.0 - 2.0 * t);
        s = s * s * (3.0 - 2.0 * s);
        half3 grad = lerp(_Global_SkyColorMiddle.rgb, _Global_SkyColorTop.rgb, t * t);
        grad = lerp(_Global_SkyColorBottom.rgb, grad, s);

        // Sun disk and glow: distance between the reflected direction and the light direction,
        // scaled by each disk radius, inverted smoothstep, then pow 20 / pow 10.
        float3 L = normalize(_MainLightPosition.xyz);
        float d = length(L - normalize(reflectDir));
        float a = saturate(d / _Global_SunDisk);
        float b = saturate(d / _Global_SunGlowDisk);
        a = max(1.0 - a * a * (3.0 - 2.0 * a), 0.0);
        b = max(1.0 - b * b * (3.0 - 2.0 * b), 0.0);
        float sun = pow(a, 20.0) + 0.1 * pow(b, 10.0);
        half3 col = sun * _MainLightColor.rgb * _Global_SunGlowColor.rgb * 10.0 + grad;

        // Over-unity main light lifts the whole sky, more so by day.
        half lum = dot(_MainLightColor.rgb - 1.0h, half3(0.212673h, 0.715152h, 0.072175h)) * 5.0h;
        lum = max(lum * (_Global_Night2Day * 0.6h + 0.2h), 0.0h);
        col += lum;

        // NOT-IMPLEMENTED: + transparentCube * GILightMulti * CloudColor * 0.35, and
        // lerp(col, litAlbedo, coverage) - both zero without the MiniGBuffer cubemaps.
        sky = col * _Global_MiniGBuffer_Effective_Weight;
    }
    return saturate(sky);
}

half4 WaterFragment(Varyings i) : SV_Target
{
    float2 screenUV = i.screenPos.xy / i.screenPos.w;

    float2 uvA, uvB;
    WaterFlowUVs(i.uv, uvA, uvB);

    // High-spec foam is a 3-tap of _DistortionTexture: tapA.R, tapB.G, tapA.yx.B (the swap is
    // applied to the raw UV before the ST transform). Low-spec samples RGB once at tapA.
    float2 distA = TRANSFORM_TEX(uvA, _DistortionTexture);
#if defined(MMN_WATER_LOW)
    half3 foamSample = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA).rgb;
    half s1 = foamSample.r;
    half s2 = foamSample.g;
    half s3 = foamSample.b;
#else
    float2 distB = TRANSFORM_TEX(uvB, _DistortionTexture);
    float2 distA_swapped = TRANSFORM_TEX(uvA.yx, _DistortionTexture);
    half s1 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA).r;
    half s2 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distB).g;
    half s3 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA_swapped).b;
#endif

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
    float depthScaled = unity_OrthoParams.w > 0.5 ? 5.0 : thickness / _DepthScale;

    // 1 - |Turbidity|^(thickness/DepthScale). Shore goes transparent so the sand shows through.
    half opacity = 1.0h - (half)exp(depthScaled * log(abs((float)_Turbidity)));

    half foamPat = (1.0h - (0.3h + 0.5h * s1 + 0.2h * s3)) / (0.1h + 0.5h * s2);
    half foamDepth = saturate(max(thickness + _FoamOffset, 0.5 - 3.0 * thickness));
    half foam = 1.0h - pow(saturate(foamPat * foamDepth), 15.0h);
    foam *= saturate(_FoamOpacity - 0.005h * abs((half)viewZ));

    // Geometric N.V: this is what keeps the sheet looking flat. The perturbed normal is not
    // allowed to drive fresnel or the foam grazing term. The shipped program dots the
    // interpolated (un-renormalised) normal here.
    half ndvGeom = dot((half3)i.normalWS, (half3)viewDirWS);
    half oneMinusNdv = saturate(1.0h - ndvGeom);
    half fresnel6 = oneMinusNdv * oneMinusNdv;
    fresnel6 = fresnel6 * fresnel6 * (oneMinusNdv * oneMinusNdv);

    Light mainLight = GetMainLight();
    half3 sky = SampleSky(reflect(-viewDirWS, normalWS), i.positionWS);

#if defined(MMN_WATER_LOW)
    // ---- LOD 100 (asm SubShader 1): no depth scatter ramp, no perturbed normal, no specular.
    half fresnelPower = pow(oneMinusNdv, _ReflectionPower * 2.0);
    half3 color = lerp(_ScatterColor3.rgb, _FresnelColor.rgb * sky, fresnel6);

    if (_LowOptionEnable < 0.5h)
    {
        float3 viewN = normalize(mul((float3x3)UNITY_MATRIX_MV, (float3)geomNormalWS));
        float2 planarUV = i.screenPos.xy / (i.screenPos.w + 0.0001) + float2(viewN.x * 0.05, 0.0);
        // (1 - Glossiness) * 8: negative for any Glossiness > 1, so this clamps to mip 0.
        float planarMip = (1.0 - _Glossiness) * 8.0;
        half3 planar = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                            planarUV, planarMip).rgb * _ReflectionColor.rgb;
        color = lerp(color, planar * _ReflectionColor.rgb, fresnelPower);
    }

    // Foam is applied straight, without the grazing term the high path uses.
    color = lerp(color, _FoamColor.rgb, foam);
    color *= i.color.rgb * mainLight.color;
    color *= 1.5h;

    half alpha = saturate(foam + opacity);
    alpha = min(alpha + (half)(abs(viewZ) * 0.005), 1.0h);
#else
    // ---- LOD 300 (asm SubShader 0).
    half fresnelPower = pow(oneMinusNdv, _ReflectionPower);
    half grazing = smoothstep(0.0h, 1.0h, saturate((oneMinusNdv - 0.2h) * 1.428571h));
    half foamMix = foam * grazing;

    half3 scatter = lerp(_ScatterColor1.rgb, _ScatterColor2.rgb, saturate(depthScaled / _ScatterDepth2));
    scatter = lerp(scatter, _ScatterColor3.rgb,
                   saturate((depthScaled - _ScatterDepth2) / (_ScatterDepth3 - _ScatterDepth2)));

    half3 color = lerp(scatter, _FresnelColor.rgb * sky, fresnel6);

    if (_LowOptionEnable < 0.5h)
    {
        // Planar UV offset is x of the perturbed WORLD normal pushed through UNITY_MATRIX_MV
        // (the shipped program really does apply the model matrix to a world-space vector),
        // times 0.05. Matters when the water transform carries a rotation.
        float3 viewN = normalize(mul((float3x3)UNITY_MATRIX_MV, (float3)normalWS));
        float2 planarUV = i.screenPos.xy / (i.screenPos.w + 0.0001) + float2(viewN.x * 0.05, 0.0);
        half ndvPerturbed = saturate(dot(normalWS, viewDirWS));
        half planarMip = pow(1.0h - ndvPerturbed, 8.0h) * _ReflectionMipmapLevel;
        half3 planarBlur = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                                planarUV, planarMip).rgb;
        half3 planarSharp = SAMPLE_TEXTURE2D_LOD(_PlanarReflectionTexture, sampler_PlanarReflectionTexture,
                                                 planarUV, 0.0).rgb;
        half blend127 = pow(1.0h - saturate(ndvGeom), 12.7h);
        half3 planar = lerp(planarSharp, planarBlur, blend127) * _ReflectionColor.rgb;
        // The shipped program multiplies _ReflectionColor a second time here. The Colhen
        // material is (1,1,1) so it is a no-op; keep it so a tinted material matches.
        color = lerp(color, planar * _ReflectionColor.rgb, fresnelPower);
    }

    color = lerp(color, _FoamColor.rgb, min(foamMix, 1.0h));
    color *= i.color.rgb * mainLight.color;

    // Specular normal is the WORLD perturbed normal with XZ scaled by _SpecualrNormalMulti,
    // then renormalized. Exponent is Glossiness*50 (50.9 -> ~2545), then * 0.5.
    // _SpecColor.a is never loaded. The lobe is then multiplied by opacity^2, so the shore
    // has no highlight and the open water only ever shows a pin-prick.
    half opacitySq = opacity * opacity;
    half3 specNormalWS = normalize(normalWS * half3(_SpecualrNormalMulti, 1.0h, _SpecualrNormalMulti));
    half3 halfDir = normalize(mainLight.direction + viewDirWS);
    half spec = pow(saturate(dot(specNormalWS, halfDir)), _Glossiness * 50.0);
    half3 specCol = spec * 0.5h * mainLight.color * mainLight.distanceAttenuation * _SpecColor.rgb;
    half specLum = dot(specCol, half3(0.212673h, 0.715152h, 0.072175h));
    color = color * 1.5h + specCol * opacitySq;

    half alpha = saturate(foamMix + opacity);
    alpha = saturate(alpha + specLum * opacitySq);
    // Unconditional distance term: at 150 m the water is +0.5 alpha regardless of thickness,
    // which is what makes the far bay read as solid colour.
    alpha = min(alpha + (half)(abs(viewZ) * 0.003333), 1.0h);
#endif

    return half4(color, alpha);
}

#endif // MMN_PLANAR_REFLECTION_WATER_INCLUDED
