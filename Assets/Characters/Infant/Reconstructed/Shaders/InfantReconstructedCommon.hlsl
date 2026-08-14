#ifndef INFANT_RECONSTRUCTED_COMMON_INCLUDED
#define INFANT_RECONSTRUCTED_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half3 DecodeInfantDyeMap(half3 sourceLinear, half3 dye1, half3 dye2, half3 dye3)
{
    half3 encoded = LinearToSRGB(saturate(sourceLinear));
    const half marker = 128.0h / 255.0h;
    const half tolerance = 10.0h / 255.0h;

    half slot1 = saturate(1.0h - max(abs(encoded.g - marker), abs(encoded.b - marker)) / tolerance);
    half slot2 = saturate(1.0h - max(abs(encoded.r - marker), abs(encoded.b - marker)) / tolerance);
    half slot3 = saturate(1.0h - max(abs(encoded.r - marker), abs(encoded.g - marker)) / tolerance);
    slot1 *= step(encoded.r + 1.0h / 255.0h, min(encoded.g, encoded.b));
    slot2 *= step(encoded.g + 1.0h / 255.0h, min(encoded.r, encoded.b));
    slot3 *= step(encoded.b + 1.0h / 255.0h, min(encoded.r, encoded.g));

    half3 dyed1 = dye1 * (0.5h + encoded.r * 2.0h);
    half3 dyed2 = dye2 * (0.5h + encoded.g * 2.0h);
    half3 dyed3 = dye3 * (0.5h + encoded.b * 2.0h);
    half dyeWeight = max(slot1, max(slot2, slot3));
    half3 dyed = slot1 >= slot2 && slot1 >= slot3 ? dyed1 : slot2 >= slot3 ? dyed2 : dyed3;
    return lerp(sourceLinear, dyed, dyeWeight);
}

float2 GetAtlasUV(float2 uv, float4 atlasSize)
{
    float2 grid = max(atlasSize.xy, float2(1.0, 1.0));
    float index = max(atlasSize.z - 1.0, 0.0);
    float column = fmod(index, grid.x);
    float row = floor(index / grid.x);
    float2 atlasOffset = float2(column, grid.y - 1.0 - row);
    return (saturate(uv) + atlasOffset) / grid;
}

half3 GetInfantLighting(half3 normalWS, float4 shadowCoord)
{
    normalWS = normalize(normalWS);
    Light mainLight = GetMainLight(shadowCoord);
    half NoL = saturate(dot(normalWS, mainLight.direction));
    half3 ambient = max(SampleSH(normalWS), half3(0.28h, 0.28h, 0.28h));
    half3 direct = mainLight.color * (0.25h + NoL * 0.55h) *
                   mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    return min(ambient + direct, half3(1.25h, 1.25h, 1.25h));
}

#endif
