#ifndef MMN_BG_SIMPLELIT_INPUT_INCLUDED
#define MMN_BG_SIMPLELIT_INPUT_INCLUDED

// Per-property uniforms (no UnityPerMaterial). A generated CBUFFER never
// matched this Properties block, so _ShadowDim / _ShowVertexColor read the
// wrong slots and lighting collapsed to a constant.

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_SpecGlossMap); SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);
TEXTURE2D(_EmissionFlickerNoise); SAMPLER(sampler_EmissionFlickerNoise);
TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
TEXTURE2D(_SnowSparklingMap); SAMPLER(sampler_SnowSparklingMap);

float _IsShadowDitheringPattern;
float _ContactShadowIntensity;
float _NEARHALFTONECLIP;
float _ALPHATEST;
float _Cull;
float _BackFaceNormalturn;
float _RaycastHarftoneClip;
float _VertexColorWeight;
float _ShowVertexColor;
float4 _BaseMap_ST;
float4 _BaseColor;
float _AlbedoTintStrength;
float _ShadowDim;
float _Cutoff;
float4 _SpecColor;
float _Smoothness;
float _Gloss;
float4 _SpecGlossMap_ST;
float _SmoothnessSource;
float _SpecularHighlights;
float4 _EmissionColor;
float4 _EmissionMap_ST;
float _EmissionIntensity;
float _Night2DayEnum;
float _EmissionFlickerMode;
float _EmissionFlickerMin;
float _EmissionFlickerMax;
float _EmissionFlickerFrequency;
float4 _EmissionFlickerNoise_ST;
float _EmissionFlickerNoiseUV;
float _EmissionFlickerNoiseScale;
float4 _EmissionFlickerNoiseSpeed;
float _EmissionFlickerNoiseCellCount;
float _EmissionFlickerDEBUG;
float _halfLambertWeight;
float _BackfaceReceiveShadowOff;
float _QueueOffset;
float4 _MainTex_ST;
float4 _Color;
float _Shininess;
float _GlossinessSource;
float _SpecSource;
float _IsRaindrop;
float _VertexAniOn;
float _WindMultiply;
float _WindSpeedMultiply;
float _ShowVertexAlpha;
float _UseVertexAnimation;
float _StencilRef;
float _StencilComp;
float _StencilPass;
float _IsSnowSparkling;
float4 _SnowSparklingMap_ST;
float _SnowSparklingIntensity;
float _SnowSparklingSpecularIntensity;
float4 _SnowSparklingTiling;
float _SnowSparklingNormalStep;

#endif
