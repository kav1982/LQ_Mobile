// Recreation of the shipped MMN/FX/ObjectDecalForCampFire.
//
// Properties and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_ObjectDecalForCampFire.contract.json).
// Fragment maths is transcribed from the shipped D3D11 bytecode, disassembled into
// _re_work/shader_contracts/MMN_FX_ObjectDecalForCampFire.asm.txt.
//
// Original LightMode is Decal (a client compositor that masks by alpha). This project
// has no Decal renderer feature, so the pass is UniversalForward. RGB is multiplied by
// the object-space unit-box mask so SrcColor One cannot paint the inverted sphere as a
// solid disc — the original compositor used alpha for that clip.
//
// _Global_pos is a client player-position global. Unset it stays at the origin; the
// 20–60 m fade then uses distance to the light instead of the player.
//
// NOT-IMPLEMENTED: STEREO_* / _LIGHT_LAYERS / _ADDITIONAL_LIGHTS keyword variants
// (the campfire math is identical across the dumped variants).
Shader "MMN/FX/ObjectDecalForCampFire"
{
    Properties
    {
        _CampFireLightPositionWS ("_CampFireLightPositionWS", Vector) = (0,0,0,0)
        _CampFireLightColor ("_CampFireLightColor", Color) = (1,1,1,1)
        _CampFireLightIntensity ("_CampFireLightIntensity", Float) = 1
        _CampFireLightRange ("_CampFireLightRange", Float) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }
        LOD 100

        Pass
        {
            Name "Base"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcColor One
            BlendOp Add
            ZWrite Off
            ZTest Always
            Cull Front

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            float4 _Global_pos;

            CBUFFER_START(UnityPerMaterial)
                float4 _CampFireLightPositionWS;
                half4 _CampFireLightColor;
                half _CampFireLightIntensity;
                float _CampFireLightRange;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            half MMN_CampFireIntensityToSRGB(half x)
            {
                half a = x * 12.92h;
                half b = 1.055h * pow(abs(x), 0.416667h) - 0.055h;
                half c = (x == 1.0h) ? 1.0h : pow(abs(x), 0.454545h);
                half mid = (x < 1.0h) ? b : c;
                return (x < 0.003131h) ? a : mid;
            }

            Varyings vert(Attributes v)
            {
                Varyings o;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.screenPos = p.positionNDC;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float3 lightPos = _CampFireLightPositionWS.xyz;
                if (dot(lightPos, lightPos) < 1e-8)
                    lightPos = mul(GetObjectToWorldMatrix(), float4(0, 0, 0, 1)).xyz;

                float fadeDist = length(_Global_pos.xyz - lightPos);
                half fade = saturate(1.0h - (half)(fadeDist - 20.0) * 0.025h);
                half intensity = fade * _CampFireLightIntensity;
                half3 color = MMN_CampFireIntensityToSRGB(intensity) * _CampFireLightColor.rgb;

                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float2 ndc = screenUV * 2.0 - 1.0;
                float rawDepth = SampleSceneDepth(screenUV);
                float4 wsH = mul(UNITY_MATRIX_I_VP, float4(ndc, rawDepth, 1.0));
                float3 wsPos = wsH.xyz / max(wsH.w, 1e-6);

                float3 toLight = lightPos - wsPos;
                float dist2 = max(dot(toLight, toLight), 0.000061);
                float range2 = _CampFireLightRange * _CampFireLightRange;
                float k = rcp(range2 * -0.36);
                float t = k * dist2;
                float atten = max(1.0 - t * t, 0.0);
                atten = atten * atten * rcp(dist2);

                float3 n = normalize(i.normalWS);
                float3 l = toLight * rsqrt(dist2);
                color *= (half)atten * saturate(dot(-n, l));
                if (intensity <= 0.0h)
                    color = 0;

                float3 osPos = mul(GetWorldToObjectMatrix(), float4(wsPos, 1.0)).xyz;
                bool inside = osPos.x >= -0.5 && osPos.x < 0.5
                           && osPos.y >= -0.5 && osPos.y < 0.5
                           && osPos.z >= -0.5 && osPos.z < 0.5;
                half mask = inside ? 1.0h : 0.0h;
                color *= mask;
                half alpha = mask * (half)atten;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
