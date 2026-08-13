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

// Remaps one splat channel through the layer's Vector1/Vector2 window. On the Colhen material the
// windows are narrow (0.23..1.05, 0.45..1.9, 0.52..1.9), which is what keeps the painted layers
// from washing into each other over the whole gradient of the splat map.
half T2M_LayerWeight(half w, half v1, half v2)
{
    return saturate((w - v1) / max(v2 - v1, 1e-4h));
}

// "交界颜色相乘" (originally 경계면 칼라 멀티플라이): the seam between two layers is darkened by
// the layer's EdgeColor, which is what hides the linear look of a straight lerp between tilings.
half3 T2M_EdgeTint(half3 color, half weight, half3 edgeColor)
{
    half band = saturate(weight * (1.0h - weight) * 4.0h);
    return color * lerp(half3(1.0h, 1.0h, 1.0h), edgeColor, band);
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
    // UV0 spans the whole baked terrain, so the splat map is read straight from it while every
    // detail layer multiplies it up by its own uvScale (50 / 150 / 200 / 100 on Colhen).
    half4 splat = SAMPLE_TEXTURE2D(_T2M_SplatMap_0, sampler_T2M_SplatMap_0, i.uv);

    half3 layer0 = SAMPLE_TEXTURE2D(_T2M_Layer_0_Diffuse, sampler_T2M_Layer_0_Diffuse,
                                    i.uv * _V_T2M_Splat1_uvScale).rgb;
    half3 layer1 = SAMPLE_TEXTURE2D(_T2M_Layer_1_Diffuse, sampler_T2M_Layer_1_Diffuse,
                                    i.uv * _V_T2M_Splat2_uvScale).rgb;
    half3 layer2 = SAMPLE_TEXTURE2D(_T2M_Layer_2_Diffuse, sampler_T2M_Layer_2_Diffuse,
                                    i.uv * _V_T2M_Splat3_uvScale).rgb;
    half3 layer3 = SAMPLE_TEXTURE2D(_T2M_Layer_3_Diffuse, sampler_T2M_Layer_3_Diffuse,
                                    i.uv * _V_T2M_Splat4_uvScale).rgb;

    half w1 = T2M_LayerWeight(splat.g, _V_T2M_Splat2_Vector1, _V_T2M_Splat2_Vector2);
    half w2 = T2M_LayerWeight(splat.b, _V_T2M_Splat3_Vector1, _V_T2M_Splat3_Vector2);
    half w3 = T2M_LayerWeight(splat.a, _V_T2M_Splat4_Vector1, _V_T2M_Splat4_Vector2);

    // Layer 0 (splat R) is the base the others are painted over, in channel order.
    half3 albedo = layer0;
    albedo = lerp(albedo, T2M_EdgeTint(layer1, w1, _V_T2M_Splat2_EdgeColor.rgb), w1);
    albedo = lerp(albedo, T2M_EdgeTint(layer2, w2, _V_T2M_Splat3_EdgeColor.rgb), w2);
    albedo = lerp(albedo, T2M_EdgeTint(layer3, w3, _V_T2M_Splat4_EdgeColor.rgb), w3);
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
