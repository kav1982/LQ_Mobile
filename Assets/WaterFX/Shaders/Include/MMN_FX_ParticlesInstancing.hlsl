#ifndef MMN_FX_PARTICLES_INSTANCING_INCLUDED
#define MMN_FX_PARTICLES_INSTANCING_INCLUDED

// Mesh particles in this project ship Position, Normal, Color, UV, Custom1XYZW.
// Color and Custom1XYZW are INSTANCED; UV/Normal stay on the source mesh.
// No texture-sheet stream, so no animFrame. Custom1 is four tightly packed
// floats — a float4 member would 16-byte-align and skip the real values.
#define UNITY_PARTICLE_INSTANCE_DATA MMNParticleInstanceData
#define UNITY_PARTICLE_INSTANCE_DATA_NO_ANIM_FRAME

struct MMNParticleInstanceData
{
    float3x4 transform;
    uint color;
    float custom1x;
    float custom1y;
    float custom1z;
    float custom1w;
};

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"

void MMN_ApplyParticleInstance(inout float4 uv0, inout float4 color)
{
#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
    color = lerp(half4(1.0h, 1.0h, 1.0h, 1.0h), color, unity_ParticleUseMeshColors);
    color *= half4(UnpackFromR8G8B8A8(data.color));
    uv0.zw = float2(data.custom1x, data.custom1y);
#endif
}

void MMN_ApplyParticleInstance(inout float4 uv0, inout float4 uv1, inout float4 color)
{
    MMN_ApplyParticleInstance(uv0, color);
#if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
    UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
    uv1.x = data.custom1z;
    uv1.y = data.custom1w;
#endif
}

#endif
