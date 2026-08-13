#ifndef MMN_FX_COMMON_INCLUDED
#define MMN_FX_COMMON_INCLUDED

// Shared framework block of the MMN/FX/Amplify shader family: near-plane fade, light receive,
// soft particles and the blend-mode driven transition/spawn scaling. Every FX shader in the
// shipped game carries this block ahead of its own effect properties.
//
// Transcribed instruction for instruction from the shipped D3D11 bytecode, disassembled by
// _re_work/dump_shader_bytecode.py into _re_work/shader_contracts/*.asm.txt. Constants and the
// order of operations follow the original rather than approximating it.
//
// Requires Core.hlsl, and DeclareDepthTexture.hlsl when MMN_FX_USE_DEPTH is defined.

// Client global that scales ambient contribution per area. Unset outside the real game, and
// zero leaves the light term at the main light colour alone.
float4 _Global_GILightMulti;

// n/17 ordered dither, the immediate constant buffer the shipped programs embed verbatim.
static const float MMN_Bayer4x4[16] =
{
    0.058, 0.529, 0.176, 0.647,
    0.764, 0.294, 0.882, 0.411,
    0.235, 0.705, 0.117, 0.588,
    0.941, 0.470, 0.823, 0.352
};

// Every scroll in this shader family runs off a 1000 second saw instead of raw time, which
// keeps the UV offsets from losing float precision over a long session.
float MMN_FxTime()
{
    return frac(_TimeParameters.x * 0.001) * 1000.0;
}

// Fades the effect out as the camera closes in, so a particle never fills the frame. edge is
// (nearStart, nearEnd, farStart, farEnd). Discards through an ordered dither when
// ditherMode is on, which is how the shipped effects stay readable instead of ghosting.
half MMN_NearPlaneFade(float3 positionWS, float4 screenPos, half enabled, float4 edge,
                       half invertDistance, half directionMode, float4 directionValue,
                       half minimumAlpha, half ditherMode)
{
    if (enabled == 0.0h)
        return 1.0h;

    float dist = length(_WorldSpaceCameraPos - positionWS);
    float nearFade = saturate((dist - edge.x) / (edge.y - edge.x));
    float farFade = saturate((edge.w - dist) / (edge.w - edge.z));
    float fade = min(lerp(1.0, farFade, invertDistance), nearFade);

    // _m21 of the view matrix is the world-up component of the camera's backward axis, i.e. how
    // steeply the camera looks down; the direction mode fades the effect out over that instead
    // of over distance.
    float pitch = saturate((1.0 - max(unity_MatrixV._m21, 0.0) - directionValue.x)
                           / max(directionValue.y - directionValue.x, 1e-5));
    fade = min(fade, directionMode >= 0.5h ? pitch : 1.0);
    fade = max(fade, minimumAlpha);
    fade = lerp(fade, 1.0, unity_OrthoParams.w);

    if (ditherMode > 0.5h)
    {
        uint2 pixel = (uint2)(screenPos.xy / screenPos.w * _ScaledScreenParams.xy);
        fade -= MMN_Bayer4x4[((pixel.x & 3) << 2) | (pixel.y & 3)];
        clip(fade);
    }
    return (half)saturate(fade);
}

// _LightReceive tints an otherwise unlit effect by the main light plus the area's GI multiplier;
// _LightRatio blends between untinted and fully tinted. No normal is involved.
half3 MMN_LightReceive(half3 color, half receive, half ratio)
{
    if (receive <= 0.5h)
        return color;

    half3 light = saturate(_MainLightColor.rgb + (half3)_Global_GILightMulti.rgb);
    return color * (ratio * (light - 1.0h) + 1.0h);
}

#if defined(MMN_FX_USE_DEPTH)
// Softens the seam where a particle cuts into opaque geometry. fadeOutRange and farFade
// multiply into a single slope; neither is a distance on its own.
half MMN_SoftParticleFade(float4 screenPos, half enabled,
                          float nearFade, float farFade, float fadeOutRange)
{
    if (enabled <= 0.5h)
        return 1.0h;

    float2 uv = screenPos.xy / screenPos.w;
    float sceneEye = LinearEyeDepth(SampleSceneDepth(uv), _ZBufferParams);
    float ownEye = LinearEyeDepth(screenPos.z / screenPos.w, _ZBufferParams);
    return (half)saturate((sceneEye - nearFade - ownEye) * (fadeOutRange * farFade));
}
#endif

// _Mode is the blend mode the material editor picked. Modes 1 and 2 are the additive ones, where
// fading has to scale the colour because alpha does not attenuate the source; every other mode
// blends on alpha, so fading scales alpha instead.
void MMN_ApplyModeTransition(inout half3 color, inout half alpha,
                             half mode, half transitionValue, half spawnTransition)
{
    bool additive = mode >= 1.0h && mode <= 2.0h;

    half transition = saturate(transitionValue);
    half spawn = min(abs(1.0h - spawnTransition), 1.0h);
    spawn = lerp(spawn, 1.0h, (half)unity_OrthoParams.w);

    half scale = transition * spawn;
    color = additive ? color * scale : color;
    alpha = additive ? alpha : alpha * scale;
}

#endif // MMN_FX_COMMON_INCLUDED
