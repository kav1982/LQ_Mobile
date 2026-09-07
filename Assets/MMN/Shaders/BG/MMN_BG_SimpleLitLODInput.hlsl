#ifndef MMN_BG_SIMPLELITLOD_INPUT_INCLUDED
#define MMN_BG_SIMPLELITLOD_INPUT_INCLUDED

TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
TEXTURE2D(_EmissionMap); SAMPLER(sampler_EmissionMap);

float _IsShadowDitheringPattern;
float _ALPHATEST;
float _Cutoff;
float _Cull;
float _VertexColorWeight;
float _ShowVertexColor;
float _ShowVertexAlpha;
float4 _BaseMap_ST;
float4 _BaseColor;
float _AlbedoTintStrength;
float4 _EmissionColor;
float4 _EmissionMap_ST;
float _EmissionIntensity;
float _Night2DayEnum;
float _IsRaindrop;

#endif
