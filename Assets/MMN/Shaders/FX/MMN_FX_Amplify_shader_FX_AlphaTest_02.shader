// Recreation of the shipped MMN/FX/Amplify shader/FX_AlphaTest_02.
//
// Properties, tags and render states follow the extracted contract
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_AlphaTest_02.contract.json).
// Maths are transcribed from the D3D11 bytecode dumped from
// AssetPackages/Starter/0017.blob chunk 1163 into
// _re_work/shader_contracts/MMN_FX_Amplify_shader_FX_AlphaTest_02.asm.txt.
//
// TEXCOORD0.z = Custom1.x dissolve. TEXCOORD0.w = Custom1.y distortion amount.
// TEXCOORD1.x = Custom1.z MainTex UV.x offset. TEXCOORD1.yzw = Custom2.rgb.
// Noise / AddNoise / Mask are sampled in R. Cutout clips dissolve < 0.
//
// Mesh particles on this card stream Custom1XYZ + Custom2XYZW, so the instance
// struct is three Custom1 floats then four Custom2 floats (not the 4-float
// Custom1 layout used by Offset_Fresnel).
//
// NOT-IMPLEMENTED: FOG_LINEAR (client fog globals divide by zero when unset).
// NOT-IMPLEMENTED: DEBUG_DISPLAY. BaseSSAOMask pass.
Shader "MMN/FX/Amplify shader/FX_AlphaTest_02"
{
    Properties
    {
        [HideInInspector] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        [HideInInspector] _Mode ("Mode", Float) = -1
        [HideInInspector] _TransitionValue ("TransitionValue", Range(0, 1)) = 1
        [HideInInspector] _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        [HideInInspector] [PerRendererData] _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        [HideInInspector] _RaycastMinimumAlpha ("minimumAlpha", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 18)) = 0
        [HideInInspector] _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] [HideInInspector] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] [HideInInspector] _LightReceive ("LightReceive", Range(0, 1)) = 0
        [HideInInspector] _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] [HideInInspector] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        [HideInInspector] _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        [HideInInspector] _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        [ToggleUI] [HideInInspector] _FogReceive ("FogReceive", Range(0, 1)) = 0
        [HideInInspector] _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle(_RAYCAST_ON)] [HideInInspector] _Raycast ("_Raycast", Float) = 1
        [HideInInspector] _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(Custom1.x     Dissolve)] [Header(Custom1.y     Distortion)] [Header(Custom1.z     MainTex Offset X)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        _Main_X_Speed ("Main_X_Speed", Float) = 0
        _Main_Y_Speed ("Main_Y_Speed", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex1 ("NoiseTex", 2D) = "white" {}
        _Noise_X_Speed1 ("Noise_X_Speed", Float) = 0
        _Noise_Y_Speed1 ("Noise_Y_Speed", Float) = 0
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = 0
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 0
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 0
        [Header(AddNoise Texture)] [Space()] _NoiseTex ("AddNoiseTex", 2D) = "white" {}
        _AddNoise_X_Speed ("AddNoise_X_Speed", Float) = 0
        _AddNoise_Y_Speed ("AddNoise_Y_Speed", Float) = 0
        _Twist1 ("Twist", Float) = 0
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
        [Header(Mask Texture)] [Space()] _MaskTex ("MaskTex", 2D) = "white" {}
        _DefaultValues ("Default Values", Float) = 0
        [Enum(Alpha,0,UV,1)] [Header(Front Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _FrontMainColor ("Front Main Color", Color) = (1,1,1,1)
        _FrontSubColor ("Front Sub Color", Color) = (1,1,1,1)
        [Space(5)] _FrontColorOffset ("Front Color Offset", Float) = 0
        _FrontColorRange ("Front Color Range", Float) = 1
        [Header(Back Color)] [Space()] _BackMainColor ("Back Main Color", Color) = (1,1,1,1)
        _BackSubColor ("Back Sub Color", Color) = (1,1,1,1)
        [Space(5)] _BackColorOffset ("Back Color Offset", Float) = 0
        _BackColorRange ("Back Color Range", Float) = 1
        [Toggle] [Space()] _UseCustomDataColor ("Use Custom Data Color", Float) = 0
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        [HideInInspector] _texcoord ("_texcoord", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "RenderType" = "TransparentCutout"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Unlit"
            Blend One Zero
            BlendOp Add
            ZWrite On
            ZTest [_ZTest]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma instancing_options procedural:ParticleInstancingSetup

            #define MMN_FX_USE_DEPTH

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            #define UNITY_PARTICLE_INSTANCE_DATA MMNAlphaTestParticleData
            #define UNITY_PARTICLE_INSTANCE_DATA_NO_ANIM_FRAME
            struct MMNAlphaTestParticleData
            {
                float3x4 transform;
                uint color;
                float custom1x;
                float custom1y;
                float custom1z;
                float custom2x;
                float custom2y;
                float custom2z;
                float custom2w;
            };
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ParticlesInstancing.hlsl"

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex1); SAMPLER(sampler_NoiseTex1);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex1_ST;
                float4 _NoiseTex_ST;
                float4 _MaskTex_ST;
                float4 _texcoord_ST;
                half4 _EmissionColor;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half4 _FrontMainColor;
                half4 _FrontSubColor;
                half4 _BackMainColor;
                half4 _BackSubColor;
                half _Mode;
                half _TransitionValue;
                half _SpawnTransition;
                half _RaycastHarftoneClip;
                half _RaycastMinimumAlpha;
                half _NearPlaneAlpha;
                half _NearPlaneInvertDistance;
                half _NearPlaneDirectionMode;
                half _NearPlaneDitherMode;
                half _LightReceive;
                half _LightRatio;
                half _SoftParticle;
                float _SoftParticleNearFadeDistance;
                float _SoftParticleFarFadeDistance;
                half _SoftParticleFadeOutRange;
                half _Use_G_Channel_Alpha;
                float _Main_X_Speed;
                float _Main_Y_Speed;
                float _Noise_X_Speed1;
                float _Noise_Y_Speed1;
                float _Distortion_Offset;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _AddNoise_X_Speed;
                float _AddNoise_Y_Speed;
                float _Twist1;
                half _CullMode;
                half _ZTest;
                half _EffectAlpha;
                half _DefaultValues;
                half _ColorGradation;
                half _FrontColorOffset;
                half _FrontColorRange;
                half _BackColorOffset;
                half _BackColorRange;
                half _UseCustomDataColor;
                half _Intensity_Color;
            CBUFFER_END

            // icb[].x from the shipped Unlit fragment, used as alpha-test dither.
            static const float MMN_AlphaTestDither[16] =
            {
                1.0, 9.0, 3.0, 11.0,
                13.0, 5.0, 15.0, 7.0,
                4.0, 12.0, 2.0, 10.0,
                16.0, 8.0, 14.0, 6.0
            };

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 screenPos : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float4 color : COLOR;
            };

            void MMN_ApplyAlphaTestInstance(inout float4 uv0, inout float4 uv1, inout float4 color)
            {
            #if defined(UNITY_PARTICLE_INSTANCING_ENABLED)
                UNITY_PARTICLE_INSTANCE_DATA data = unity_ParticleInstanceData[unity_InstanceID];
                color = lerp(half4(1.0h, 1.0h, 1.0h, 1.0h), color, unity_ParticleUseMeshColors);
                color *= half4(UnpackFromR8G8B8A8(data.color));
                uv0.zw = float2(data.custom1x, data.custom1y);
                uv1 = float4(data.custom1z, data.custom2x, data.custom2y, data.custom2z);
            #endif
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(v);
                float4 uv0 = v.uv0;
                float4 uv1 = v.uv1;
                float4 color = v.color;
                MMN_ApplyAlphaTestInstance(uv0, uv1, color);
                VertexPositionInputs positions = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv0 = uv0;
                o.uv1 = uv1;
                o.color = color;
                return o;
            }

            void MMN_AlphaTestDitherClip(float4 screenPos, half value)
            {
                float2 pixel = screenPos.xy / max(screenPos.w, 1e-6) * _ScaledScreenParams.xy;
                if (_ProjectionParams.x < 0.0)
                    pixel.y = _ScaledScreenParams.y - pixel.y;
                float colF = pixel.x * 0.25;
                colF = (colF >= 0.0 ? frac(colF) : -frac(abs(colF))) * 4.0;
                float rowF = pixel.y * 0.25;
                rowF = (rowF >= 0.0 ? frac(rowF) : -frac(abs(rowF))) * 4.0;
                uint index = min(((uint)rowF << 2) + (uint)colF, 15u);
                float threshold = MMN_AlphaTestDither[index] * 0.0625;
                clip(value - threshold);
            }

            half4 frag(Varyings i, bool isFront : SV_IsFrontFace) : SV_Target
            {
                float time = MMN_FxTime();
                half3 customMul = lerp(1.0h, (half3)i.uv1.yzw, _UseCustomDataColor);

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                mainUV.x += i.uv1.x;
                mainUV += time * float2(_Main_X_Speed, _Main_Y_Speed);

                float2 noise1UV = i.uv0.xy * _NoiseTex1_ST.xy + _NoiseTex1_ST.zw;
                noise1UV.y = noise1UV.x * _Twist1 + noise1UV.y;
                noise1UV += time * float2(_Noise_X_Speed1, _Noise_Y_Speed1);
                half noise1 = SAMPLE_TEXTURE2D(_NoiseTex1, sampler_NoiseTex1, noise1UV).r;
                half distortAmt = saturate((half)i.uv0.w + 0.0001h);
                mainUV += (noise1 + _Distortion_Offset)
                    * float2(_Distortion_X_Power, _Distortion_Y_Power) * distortAmt;

                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 addNoiseUV = i.uv0.xy * _NoiseTex_ST.xy + _NoiseTex_ST.zw;
                addNoiseUV.y = addNoiseUV.x * _Twist1 + addNoiseUV.y;
                addNoiseUV += time * float2(_AddNoise_X_Speed, _AddNoise_Y_Speed);
                half addNoise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, addNoiseUV).r;

                float2 maskUV = i.uv0.xy * _MaskTex_ST.xy + _MaskTex_ST.zw;
                half mask = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, maskUV).r;

                half dissolved = mainAlpha * addNoise * mask - ((half)i.uv0.z + _DefaultValues);
                half gradeSrc = lerp(dissolved, (half)i.uv0.x, _ColorGradation);

                half backT = saturate((gradeSrc + _BackColorOffset) * _BackColorRange);
                half3 backColor = lerp(customMul * _BackSubColor.rgb,
                                       customMul * _BackMainColor.rgb, backT);
                backColor *= lerp(i.color.rgb, 1.0h - i.color.rgb, _UseCustomDataColor);

                half frontT = saturate((gradeSrc + _FrontColorOffset) * _FrontColorRange);
                half3 frontColor = lerp(_FrontSubColor.rgb, _FrontMainColor.rgb, frontT) * i.color.rgb;
                half3 tint = lerp(backColor, frontColor, isFront ? 1.0h : 0.0h);

                half3 texRgb = lerp(mainTex.rgb, 1.0h - mainTex.rgb, _Use_G_Channel_Alpha);

                MMN_AlphaTestDitherClip(i.screenPos, saturate(i.color.a * 1.00001h));
                MMN_AlphaTestDitherClip(i.screenPos, min(saturate(_EffectAlpha) * 1.00001h, 1.0h));
                clip(dissolved);

                half3 color = tint * _Intensity_Color * texRgb;

                half fade = MMN_NearPlaneFade(i.positionWS, i.screenPos, _NearPlaneAlpha,
                                              _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                              _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                              _RaycastMinimumAlpha, _NearPlaneDitherMode);
                color = MMN_LightReceive(color, _LightReceive, _LightRatio);
                fade *= MMN_SoftParticleFade(i.screenPos, _SoftParticle,
                                             _SoftParticleNearFadeDistance,
                                             _SoftParticleFarFadeDistance,
                                             _SoftParticleFadeOutRange);

                half transition = saturate(_TransitionValue);
                bool additive = _Mode >= 1.0h && _Mode <= 2.0h;
                half spawn = min(abs(1.0h - _SpawnTransition), 1.0h);
                spawn = lerp(spawn, 1.0h, (half)unity_OrthoParams.w);
                half alpha = fade * transition;
                color = additive ? color * transition * spawn : color;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
