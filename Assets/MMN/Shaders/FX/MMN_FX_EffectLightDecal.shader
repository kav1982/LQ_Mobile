// Transcribed from shipped D3D11 bytecode
// (_re_work/shader_contracts/MMN_FX_EffectLightDecal.asm.txt).
// Depth reconstruct + Y-rot box; point-light falloff with HSV value clamp.
Shader "MMN/FX/EffectLightDecal"
{
    Properties
    {
        _EffectLightColor ("EffectLightColor", Color) = (1,1,1,1)
        _EffectLightIntensity ("EffectLightIntensity", Float) = 1
        _BrightnessLimit ("BrightnessLimit", Float) = 1
        [Toggle] _IsParticle ("IsParticle", Float) = 1
        _worldPosition ("worldPosition", Vector) = (0,0,0,0)
        _worldScaleAndRotY ("worldScaleAndRotY", Vector) = (1,1,1,0)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Base"
            Blend One One
            BlendOp Add
            ZWrite Off
            ZTest Always
            Cull Front

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #define MMN_FX_USE_DEPTH
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"


            float4 _Global_pos;

            CBUFFER_START(UnityPerMaterial)
                float4 _EffectLightColor;
                float _EffectLightIntensity;
                float _BrightnessLimit;
                float _IsParticle;
                float4 _worldPosition;
                float4 _worldScaleAndRotY;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
                float4 uv3 : TEXCOORD3;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 color : COLOR;
                float4 uv1 : TEXCOORD0;
                float4 uv2 : TEXCOORD1;
                float4 uv3 : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
            };

            half MMN_IntensityToSRGB(half x)
            {
                if (x <= 0.0h)
                    return 0.0h;
                half a = x * 12.92h;
                half b = 1.055h * pow(abs(x), 0.416667h) - 0.055h;
                half c = (x == 1.0h) ? 1.0h : pow(abs(x), 0.454545h);
                half mid = (x < 1.0h) ? b : c;
                return (x < 0.003131h) ? a : mid;
            }

            half3 MMN_ClampValueHSV(half3 c, half maxV)
            {
                half4 k = half4(0.0h, -1.0h / 3.0h, 2.0h / 3.0h, -1.0h);
                half4 p = lerp(half4(c.bg, k.wz), half4(c.gb, k.xy), step(c.b, c.g));
                half4 q = lerp(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));
                half d = q.x - min(q.w, q.y);
                half e = 0.0001h;
                half3 hsv = half3(abs(q.z + (q.w - q.y) / (6.0h * d + e)), d / (q.x + e), q.x);
                hsv.z = min(hsv.z, max(maxV, 0.0h));
                half3 t = abs(frac(hsv.xxx + half3(1.0h, 2.0h / 3.0h, 1.0h / 3.0h)) * 6.0h - 3.0h);
                return hsv.z * lerp(1.0h, saturate(abs(t) - 1.0h), hsv.y);
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.screenPos = p.positionNDC;
                o.color = v.color;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.uv3 = v.uv3;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float deviceDepth = SampleSceneDepth(screenUV);
                float3 worldPos = ComputeWorldSpacePosition(screenUV, deviceDepth, UNITY_MATRIX_I_VP);

                float3 lightPos;
                half boxMask;
                float halfRange;
                if (_IsParticle > 0.5)
                {
                    lightPos = float3(i.uv1.z, i.uv2.x, i.uv1.w);
                    float3 scale = i.uv3.xzy * _worldScaleAndRotY.xzy;
                    halfRange = scale.x * 0.5;
                    float rotY = _worldScaleAndRotY.w * 0.017453 + i.uv2.z;
                    float3 delta = worldPos.xzy - lightPos.xzy;
                    float3 local = mul(UNITY_MATRIX_I_M, float4(delta, 1.0)).xyz;
                    float s, c;
                    sincos(rotY, s, c);
                    float3 box = float3(c * local.x - s * local.y, s * local.x + c * local.y, local.z) / scale;
                    boxMask = (box.x >= -0.5 && box.x < 0.5 &&
                               box.y >= -0.5 && box.y < 0.5 &&
                               box.z >= -0.5 && box.z < 0.5) ? 1.0h : 0.0h;
                }
                else
                {
                    float3 axisX = float3(UNITY_MATRIX_M._m00, UNITY_MATRIX_M._m10, UNITY_MATRIX_M._m20);
                    halfRange = length(axisX) * 0.5;
                    float3 osPos = mul(UNITY_MATRIX_I_M, float4(worldPos, 1.0)).xyz;
                    boxMask = (osPos.x >= -0.5 && osPos.x < 0.5 &&
                               osPos.y >= -0.5 && osPos.y < 0.5 &&
                               osPos.z >= -0.5 && osPos.z < 0.5) ? 1.0h : 0.0h;
                    lightPos = _worldPosition.xyz;
                }

                if (boxMask < 0.5h)
                    discard;

                float3 n = normalize(i.normalWS);
                half3 lit = i.color.rgb * i.color.a * _EffectLightColor.a * boxMask * _EffectLightColor.rgb;

                float invR2 = rcp(halfRange * halfRange * -0.75);
                float3 toLight = lightPos - worldPos;
                float dist2 = max(dot(toLight, toLight), 0.000061);
                float3 lightDir = toLight * rsqrt(dist2);
                float tAtt = invR2 * dist2;
                float att = max(1.0 - tAtt * tAtt, 0.0);
                att = att * att * rcp(dist2);

                float fadeDist = length(_Global_pos - float4(lightPos, _worldPosition.w));
                half fade = saturate(1.0h - (half)(fadeDist - 20.0) * 0.025h);
                half intensity = MMN_IntensityToSRGB(fade * _EffectLightIntensity);

                half3 color = lit * intensity * att;
                color = saturate(dot(-n, lightDir)) * color.yzx;
                color = MMN_ClampValueHSV(color, _BrightnessLimit);
                return half4(color, att);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
