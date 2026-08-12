Shader "MMN/BG/Caustic"
{
    // Preview stand-in for shipped MMN caustics. Dual scrolled pattern layers, mask, and
    // additive-style brightness so underwater floors shimmer instead of falling back to SimpleLit.
    Properties
    {
        [MainTexture] _BaseMap ("Caustics Map", 2D) = "white" {}
        _MaskMap ("Mask Map", 2D) = "white" {}

        [HDR] _CausticsColor ("Caustics Color", Color) = (0.06, 0.14, 0.14, 1)
        [HDR] _CausticsColor1 ("Caustics Color 1", Color) = (0.89, 0.97, 1, 1)
        [HDR] _CausticsColor2 ("Caustics Color 2", Color) = (1, 1, 1, 1)
        _CausticsDirection ("Caustics Direction (xy/zw layers)", Vector) = (0.6, 0.3, -0.5, -0.5)
        _CausticsDirection1 ("Caustics Direction 1", Vector) = (0.6, 0.3, 0, 0)
        _CausticsDirection2 ("Caustics Direction 2", Vector) = (-0.5, -0.5, 0, 0)
        _DistortionTile ("Distortion Tile", Vector) = (20, 20, 0, 0)

        _AlphaAdd ("Alpha Add", Range(0, 1)) = 0.3
        _AlphaWaveLength ("Alpha Wave Length", Float) = 0
        _AlphaWaveSpeed ("Alpha Wave Speed", Float) = 0
        _AmbientIllumination ("Ambient Illumination", Range(0, 2)) = 1
        _Brightness1 ("Brightness 1", Range(0, 2)) = 0.3
        _Brightness2 ("Brightness 2", Range(0, 2)) = 0.3
        _CausticsBrightness ("Caustics Brightness", Float) = 50
        _CausticsBrightness1 ("Caustics Brightness 1", Range(0, 2)) = 0.4
        _CausticsBrightness2 ("Caustics Brightness 2", Range(0, 2)) = 0.4
        _CausticsIntensity ("Caustics Intensity", Range(0, 4)) = 1.2
        _CausticsPower ("Caustics Power", Range(0, 4)) = 1
        _CausticsSize1 ("Caustics Size 1", Float) = 0.2
        _CausticsSize2 ("Caustics Size 2", Float) = 0.2
        _CausticsSpeed ("Caustics Speed", Float) = 1.5
        _CausticsSpeed1 ("Caustics Speed 1", Float) = 0.3
        _CausticsSpeed2 ("Caustics Speed 2", Float) = 0.5
        _CausticsTextureRotation ("Caustics Texture Rotation", Float) = 90
        _CausticsTile ("Caustics Tile", Float) = 0.2
        _CausticsTile1 ("Caustics Tile 1", Float) = 0.2
        _CausticsTile2 ("Caustics Tile 2", Float) = 0.15
        _CausticsWaveLength ("Caustics Wave Length", Float) = 0.01
        _CausticsWaveLength1 ("Caustics Wave Length 1", Float) = 0.07
        _CausticsWaveLength2 ("Caustics Wave Length 2", Float) = 0.05
        _CausticsWaveSpeed ("Caustics Wave Speed", Float) = 2
        _CausticsWaveSpeed1 ("Caustics Wave Speed 1", Float) = 0.9
        _CausticsWaveSpeed2 ("Caustics Wave Speed 2", Float) = 1
        _ColorIntensity ("Color Intensity", Range(0, 4)) = 1.2
        _DistortionFactor ("Distortion Factor", Float) = 1
        _DistortionPower ("Distortion Power", Range(0, 1)) = 0.3
        _DistortionScale ("Distortion Scale", Float) = 0.3
        _DistortionScale1 ("Distortion Scale 1", Float) = 0.32
        _DistortionScale2 ("Distortion Scale 2", Float) = 0.3
        _DistortionSpeed ("Distortion Speed", Float) = 0.1
        [Toggle] _ReceiveLight ("Receive Light", Float) = 1
        [Toggle] _UseCaustics2 ("Use Caustics 2", Float) = 1
        _WaveLength ("Wave Length", Float) = 0.01
        _WaveSpeed ("Wave Speed", Float) = 2

        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "True"
        }
        // Soft additive so caustic bars light the floor without hiding the stone albedo.
        Blend One One
        ZWrite Off
        Cull Off

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _MaskMap_ST;
                half4 _CausticsColor;
                half4 _CausticsColor1;
                half4 _CausticsColor2;
                float4 _CausticsDirection;
                float4 _CausticsDirection1;
                float4 _CausticsDirection2;
                float4 _DistortionTile;
                half _AlphaAdd;
                half _AmbientIllumination;
                half _Brightness1;
                half _Brightness2;
                half _CausticsBrightness;
                half _CausticsBrightness1;
                half _CausticsBrightness2;
                half _CausticsIntensity;
                half _CausticsPower;
                half _CausticsSpeed;
                half _CausticsSpeed1;
                half _CausticsSpeed2;
                half _CausticsTextureRotation;
                half _CausticsTile;
                half _CausticsTile1;
                half _CausticsTile2;
                half _CausticsWaveLength1;
                half _CausticsWaveLength2;
                half _CausticsWaveSpeed1;
                half _CausticsWaveSpeed2;
                half _ColorIntensity;
                half _DistortionPower;
                half _DistortionScale1;
                half _DistortionScale2;
                half _DistortionSpeed;
                half _ReceiveLight;
                half _UseCaustics2;
            CBUFFER_END

            struct Attr
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Var
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            float2 RotateUV(float2 uv, float degrees)
            {
                float r = radians(degrees);
                float s = sin(r);
                float c = cos(r);
                uv -= 0.5;
                return float2(c * uv.x - s * uv.y, s * uv.x + c * uv.y) + 0.5;
            }

            float2 CausticUV(float2 uv, float2 dir, float tile, float speed, float waveLen, float waveSpeed, float distScale)
            {
                float t = _Time.y;
                float2 flow = dir * (t * speed * 0.1);
                float2 warp = float2(
                    sin((uv.y + t * waveSpeed) * (6.283185h / max(waveLen, 1e-4h))),
                    cos((uv.x + t * waveSpeed * 0.8) * (6.283185h / max(waveLen, 1e-4h)))) * distScale * _DistortionPower * 0.05;
                float2 p = uv * max(tile, 0.01h) * max(_DistortionTile.xy, 0.01) + flow + warp;
                p += float2(t, -t) * _DistortionSpeed * 0.05;
                return RotateUV(frac(p), _CausticsTextureRotation);
            }

            Var vert(Attr v)
            {
                Var o;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.uv = v.uv;
                return o;
            }

            half4 frag(Var i) : SV_Target
            {
                half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, TRANSFORM_TEX(i.uv, _MaskMap)).r;
                mask = saturate(mask + _AlphaAdd * 0.25h);

                float2 baseUV = TRANSFORM_TEX(i.uv, _BaseMap);
                float2 uv1 = CausticUV(baseUV, _CausticsDirection1.xy, _CausticsTile1 * _BaseMap_ST.x * 0.05,
                    _CausticsSpeed1 * _CausticsSpeed, _CausticsWaveLength1, _CausticsWaveSpeed1, _DistortionScale1);
                float2 uv2 = CausticUV(baseUV, _CausticsDirection2.xy, _CausticsTile2 * _BaseMap_ST.y * 0.05,
                    _CausticsSpeed2 * _CausticsSpeed, _CausticsWaveLength2, _CausticsWaveSpeed2, _DistortionScale2);

                half c1 = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv1).r;
                half c2 = _UseCaustics2 > 0.5h ? SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv2).r : 0.0h;

                // Shipped brightness goes to ~50 (HDR). Compress for a readable preview glow.
                half gain = saturate(_CausticsBrightness * 0.02h) * _CausticsIntensity * _ColorIntensity;
                half3 layer1 = _CausticsColor1.rgb * c1 * _CausticsBrightness1 * _Brightness1;
                half3 layer2 = _CausticsColor2.rgb * c2 * _CausticsBrightness2 * _Brightness2;
                half3 pattern = pow(saturate(layer1 + layer2), max(_CausticsPower, 0.01h));
                half3 col = pattern * _CausticsColor.rgb * gain;

                if (_ReceiveLight > 0.5h)
                {
                    Light L = GetMainLight();
                    half ndl = saturate(dot(normalize(i.normalWS), L.direction));
                    col *= (SampleSH(normalize(i.normalWS)) * _AmbientIllumination * 0.35h + L.color * (0.35h + 0.65h * ndl));
                }
                else
                {
                    col *= _AmbientIllumination;
                }

                col *= mask;
                return half4(col, 1);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
