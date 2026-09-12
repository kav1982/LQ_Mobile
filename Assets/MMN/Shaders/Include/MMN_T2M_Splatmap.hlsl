#ifndef MMN_T2M_SPLATMAP_INCLUDED
#define MMN_T2M_SPLATMAP_INCLUDED

// Body of "Amazing Assets/Terrain To Mesh/Splatmap". See the .shader file for what the shipped
// contract says and what is left out.

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

TEXTURE2D(_T2M_SplatMap_0);      SAMPLER(sampler_T2M_SplatMap_0);
TEXTURE2D(_T2M_Layer_0_Diffuse); SAMPLER(sampler_T2M_Layer_0_Diffuse);
TEXTURE2D(_T2M_Layer_1_Diffuse); SAMPLER(sampler_T2M_Layer_1_Diffuse);
TEXTURE2D(_T2M_Layer_2_Diffuse); SAMPLER(sampler_T2M_Layer_2_Diffuse);
TEXTURE2D(_T2M_Layer_3_Diffuse); SAMPLER(sampler_T2M_Layer_3_Diffuse);

// Game area GI / sky. Unset in the editor (zero), which is what the dry-path bytecode falls
// back to: wrap Lambert from the main light only, no SH and no Blinn-Phong.
float4 _Global_GILightMulti;
float4 _Global_SkyColorTop;

CBUFFER_START(UnityPerMaterial)
    float4 _BaseMap_ST;
    float4 _T2M_SplatMap_0_ST;
    half4 _BaseColor;
    half4 _SpecColor;
    half4 _V_T2M_Splat2_EdgeColor;
    half4 _V_T2M_Splat3_EdgeColor;
    half4 _V_T2M_Splat4_EdgeColor;
    half4 _SnowSparklingTiling;
    float _V_T2M_Splat1_uvScale;
    float _V_T2M_Splat2_uvScale;
    float _V_T2M_Splat3_uvScale;
    float _V_T2M_Splat4_uvScale;
    half _V_T2M_Splat2_Vector1;
    half _V_T2M_Splat2_Vector2;
    half _V_T2M_Splat3_Vector1;
    half _V_T2M_Splat3_Vector2;
    half _V_T2M_Splat4_Vector1;
    half _V_T2M_Splat4_Vector2;
    half _SnowMask_R;
    half _SnowMask_G;
    half _SnowMask_B;
    half _SnowMask_A;
    half _IsSnowSparkling;
    half _SnowSparklingIntensity;
    half _SnowSparklingSpecularIntensity;
    half _SnowSparklingNormalStep;
    half _Cutoff;
    half _Glossiness;
    half _SmoothnessSource;
    half _SpecularHighlights;
    half _BumpScale;
    half _Surface;
    half _Blend;
    half _AlphaClip;
    half _SrcBlend;
    half _DstBlend;
    half _ZWrite;
    half _Cull;
    half _ReceiveShadows;
    half _QueueOffset;
    half _Smoothness;
CBUFFER_END

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float3 positionWS : TEXCOORD2;
    float fogFactor : TEXCOORD3;
};

// Official ForwardLit: EdgeColor is a layer tint, not a seam darken.
// packed as layer.rgb + 0.2 * (edge * 4.2 - 1).
half3 T2M_EdgeTint(half3 layerRgb, half3 edgeColor)
{
    return layerRgb + 0.2h * (edgeColor * 4.2h - 1.0h);
}

half T2M_Ge(half height, half threshold)
{
    return step(threshold, height);
}

Varyings SplatmapVertex(Attributes v)
{
    Varyings o = (Varyings)0;
    VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
    VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS);
    o.positionCS = pos.positionCS;
    o.positionWS = pos.positionWS;
    o.normalWS = nrm.normalWS;
    o.uv = v.uv;
    o.fogFactor = ComputeFogFactor(pos.positionCS.z);
    return o;
}

half4 SplatmapFragment(Varyings i) : SV_Target
{
    // Splat uses atlas UV0. Detail layers use world XZ * 0.0025 * uvScale (shipped ps_5_0).
    // Layer RGB is a flat tint; layer A is the height/debris mask used below.
    half4 splat = saturate(SAMPLE_TEXTURE2D(_T2M_SplatMap_0, sampler_T2M_SplatMap_0, i.uv));

    float2 worldUv = i.positionWS.xz * 0.0025;
    half3 layer0 = SAMPLE_TEXTURE2D(_T2M_Layer_0_Diffuse, sampler_T2M_Layer_0_Diffuse,
                                    worldUv * _V_T2M_Splat1_uvScale).rgb;
    half4 layer1 = SAMPLE_TEXTURE2D(_T2M_Layer_1_Diffuse, sampler_T2M_Layer_1_Diffuse,
                                    worldUv * _V_T2M_Splat2_uvScale);
    half4 layer2 = SAMPLE_TEXTURE2D(_T2M_Layer_2_Diffuse, sampler_T2M_Layer_2_Diffuse,
                                    worldUv * _V_T2M_Splat3_uvScale);
    half4 layer3 = SAMPLE_TEXTURE2D(_T2M_Layer_3_Diffuse, sampler_T2M_Layer_3_Diffuse,
                                    worldUv * _V_T2M_Splat4_uvScale);

    half3 splat5 = splat.xzw * splat.xzw;
    splat5 *= splat5;
    splat5 *= splat.xzw;
    half h1 = splat.r * layer1.a + splat5.x;
    half h2 = splat.b * layer2.a + splat5.y;
    half h3 = splat.a * layer3.a + splat5.z;

    half m1a = T2M_Ge(h1, _V_T2M_Splat2_Vector1 * 0.5h);
    half m1b = T2M_Ge(h1, _V_T2M_Splat2_Vector2 * 0.5h);
    half m2a = T2M_Ge(h2, (2.0h - _V_T2M_Splat3_Vector1) * 0.5h);
    half m2b = T2M_Ge(h2, (2.0h - _V_T2M_Splat3_Vector2) * 0.5h);
    half m3a = T2M_Ge(h3, (2.0h - _V_T2M_Splat4_Vector2) * 0.5h);
    half m3b = T2M_Ge(h3, (2.0h - _V_T2M_Splat4_Vector1) * 0.5h);

    half3 albedo = layer1.rgb;
    half3 tmp = lerp(T2M_EdgeTint(layer1.rgb, _V_T2M_Splat2_EdgeColor.rgb), layer0, m1b);
    albedo = lerp(layer1.rgb, tmp, m1a);
    albedo = lerp(albedo, T2M_EdgeTint(layer2.rgb, _V_T2M_Splat3_EdgeColor.rgb), m2b);
    albedo = lerp(albedo, layer2.rgb, m2a);
    albedo = lerp(albedo, T2M_EdgeTint(layer3.rgb, _V_T2M_Splat4_EdgeColor.rgb), m3a);
    albedo = lerp(albedo, layer3.rgb, m3b);
    albedo *= _BaseColor.rgb;

    half3 n = normalize(i.normalWS);

    // Dry-path lighting from the shipped D3D11 ps_5_0 (ForwardLit, _LIGHT_LAYERS). The program
    // never loads _Glossiness / _SpecColor / _SpecularHighlights — those are SimpleLit leftovers.
    // Cubemap IBL is mixed in only when _Global_Raining is up (NOT-IMPLEMENTED). SampleSH plus
    // Blinn-Phong was our earlier stand-in and is what made the sand look oily.
    Light mainLight = GetMainLight();
    half ndl = dot(n, mainLight.direction);
    half lambert = saturate(ndl);
    half wrapped = saturate(ndl * 0.5h + 0.5h);
    half wrapMix = lerp(lambert, wrapped, 0.5h);

    half3 gi = (half3)_Global_GILightMulti.rgb * 0.88h;
    half3 color = albedo * gi;

    float3 viewDirWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
    half lookDown = saturate(1.0h - (half)viewDirWS.y);
    half3 skyTop = (half3)_Global_SkyColorTop.rgb;
    half3 skyBoost = saturate(color * saturate(lookDown * skyTop) * skyTop * skyTop * skyTop);
    color += skyBoost;
    color += albedo * mainLight.color * wrapMix;

    color = MixFog(color, i.fogFactor);
    return half4(color, 1.0h);
}

float4 SplatmapDepthVertex(Attributes v) : SV_POSITION
{
    return TransformObjectToHClip(v.positionOS.xyz);
}

half4 SplatmapDepthFragment() : SV_Target
{
    return 0;
}

struct DepthNormalsVaryings
{
    float4 positionCS : SV_POSITION;
    float3 normalWS : TEXCOORD0;
};

DepthNormalsVaryings SplatmapDepthNormalsVertex(Attributes v)
{
    DepthNormalsVaryings o;
    o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
    o.normalWS = TransformObjectToWorldNormal(v.normalOS);
    return o;
}

half4 SplatmapDepthNormalsFragment(DepthNormalsVaryings i) : SV_Target
{
    half3 n = normalize(i.normalWS);
#if defined(MMN_URP_DEPTH_NORMALS)
    // URP's DepthNormals prepass stores signed world normals; packing to 0..1 is the game's
    // SSAODepthOnly format and would make SSAO reconstruct the wrong hemisphere.
    return half4(n, 0.0h);
#else
    return half4(n * 0.5h + 0.5h, 0.0h);
#endif
}

#endif // MMN_T2M_SPLATMAP_INCLUDED
