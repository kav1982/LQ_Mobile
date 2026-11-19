// Transcribed from shipped D3D11 bytecode
// (_re_work/shader_contracts/MMN_FX_Amplify_shader_FX_ParticleDecal.asm.txt).
// Depth reconstruct + Y-rot box; tcd0.z dissolve, tcd0.w distortion.
Shader "MMN/FX/Amplify shader/FX_ParticleDecal"
{
    Properties
    {
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
        _worldScaleAndRotY ("worldScaleAndRotY", Vector) = (1,1,1,0)
        _Mode ("Mode", Float) = -1
        _TransitionValue ("TransitionValue", Range(0, 1)) = 1
        _SpawnTransition ("SpawnTransition", Range(0, 1)) = 0
        _RaycastHarftoneClip ("raycastHarftoneClip", Range(0, 1)) = 0
        _RaycastMinimumAlpha ("minimumAlpha", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneAlpha ("nearPlaneAlpha", Range(0, 18)) = 0
        _NearPlaneAlphaEdge ("nearPlaneAlphaEdge", Vector) = (0.1,1,2,4)
        [ToggleUI] _NearPlaneInvertDistance ("nearPlaneInvertDistance", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDirectionMode ("nearPlaneDirectionMode", Range(0, 1)) = 0
        [ToggleUI] _NearPlaneDitherMode ("nearPlaneDither", Range(0, 1)) = 0
        [ToggleUI] _LightReceive ("LightReceive", Range(0, 1)) = 0
        _LightRatio ("lightRatio", Range(0, 1)) = 1
        [ToggleUI] _SoftParticle ("SoftParticle", Range(0, 1)) = 0
        _SoftParticleNearFadeDistance ("Soft Particle Near Fade", Float) = 0
        _SoftParticleFarFadeDistance ("Soft Particle Far Fade", Float) = 1
        [ToggleUI] _FogReceive ("FogReceive", Range(0, 1)) = 0
        _SoftParticleFadeOutRange ("SoftParticleFadeOutRange", Range(0, 10)) = 1
        [Toggle( _RAYCAST_ON )] _Raycast ("_Raycast", Float) = 1
        _NearPlaneDirectionValue ("nearPlaneDirectionValue", Vector) = (0,0.5,0,0)
        [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        _MainTex_ST ("MainTex_ST", Vector) = (1,1,0,0)
        [ToggleUI] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [ToggleUI] [Enum(Noraml,0,Polar,1)] _Type ("Type", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _NoiseTex_ST ("NoiseTex_ST", Vector) = (1,1,0,0)
        _Noise_X_Speed ("Noise_X_Speed", Float) = 0
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 0
        _Noise_Twist ("Noise_Twist", Float) = 0
        [Header(Distortion)] [Space()] _Distortion_X_Power ("Distortion_X_Power", Float) = 0
        _Distortion_Y_Power ("Distortion_Y_Power", Float) = 0
        [Space(10)] _Distortion_Offset ("Distortion_Offset", Float) = 0
        [Header(AddNoise Texture)] [Space()] _AddNoiseTex ("AddNoiseTex", 2D) = "white" {}
        _AddNoiseTex_ST ("AddNoiseTex_ST", Vector) = (1,1,0,0)
        _AddNoise_X_Speed ("AddNoise_X_Speed", Float) = 0
        _AddNoise_Y_Speed ("AddNoise_Y_Speed", Float) = 0
        _AddNoise_Twist ("AddNoise_Twist", Float) = 0
        [Enum(Alpha,0,UV,1,Crack,2)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        [Space()] _MainColor ("Main Color", Color) = (1,1,1,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Space()] _ParallaxScale ("Parallax Scale", Range(-0.5, 0)) = 0
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        _EffectAlpha ("EffectAlpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("Z Test", Float) = 4
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
            Name "Unlit"
            Blend [_BlendSrc] [_BlendDst]
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

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_AddNoiseTex); SAMPLER(sampler_AddNoiseTex);

            float _DimmingFactor;
            float _IsControlPlayer;

            CBUFFER_START(UnityPerMaterial)
                float4 _EmissionColor;
                float _AlphaCutoff;
                float4 _worldScaleAndRotY;
                float _Mode;
                float _TransitionValue;
                float _SpawnTransition;
                float _RaycastHarftoneClip;
                float _RaycastMinimumAlpha;
                float _NearPlaneAlpha;
                float4 _NearPlaneAlphaEdge;
                float _NearPlaneInvertDistance;
                float _NearPlaneDirectionMode;
                float _NearPlaneDitherMode;
                float _LightReceive;
                float _LightRatio;
                float _SoftParticle;
                float _SoftParticleNearFadeDistance;
                float _SoftParticleFarFadeDistance;
                float _FogReceive;
                float _SoftParticleFadeOutRange;
                float _Raycast;
                float4 _NearPlaneDirectionValue;
                float4 _MainTex_ST;
                float _Use_G_Channel_Alpha;
                float _Type;
                float4 _NoiseTex_ST;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Noise_Twist;
                float _Distortion_X_Power;
                float _Distortion_Y_Power;
                float _Distortion_Offset;
                float4 _AddNoiseTex_ST;
                float _AddNoise_X_Speed;
                float _AddNoise_Y_Speed;
                float _AddNoise_Twist;
                float _ColorGradation;
                float4 _MainColor;
                float4 _SubColor;
                float _Color_Offset;
                float _Color_Range;
                float _ParallaxScale;
                float _Intensity_Color;
                float _Intensity_Alpha;
                float _EffectAlpha;
                float _BlendSrc;
                float _BlendDst;
                float _CullMode;
                float _ZTest;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
                float4 uv3 : TEXCOORD3;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 uv2 : TEXCOORD2;
                float4 uv3 : TEXCOORD3;
                float4 screenPos : TEXCOORD4;
                float3 positionWS : TEXCOORD5;
                float4 color : COLOR;
            };

            float2 MMN_RotateY(float2 xz, float rotY)
            {
                float s, c;
                sincos(rotY, s, c);
                return float2(c * xz.x - s * xz.y, s * xz.x + c * xz.y);
            }

            float2 MMN_DecalUV(float2 boxXY, float4 st, float twist, float radius, float angle, float t, float2 scroll)
            {
                float2 cart = boxXY + 0.5;
                float2 cartUV = cart * st.xy + st.zw + t * scroll;
                float2 polarUV;
                polarUV.x = radius * st.x + st.z;
                polarUV.y = twist * polarUV.x + angle * st.y + st.w;
                polarUV += t * scroll;
                return lerp(cartUV, polarUV, _Type);
            }

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.screenPos = p.positionNDC;
                o.uv0 = v.uv0;
                o.uv1 = v.uv1;
                o.uv2 = v.uv2;
                o.uv3 = v.uv3;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = i.screenPos.xy / i.screenPos.w;
                float deviceDepth = SampleSceneDepth(screenUV);
                float3 worldPos = ComputeWorldSpacePosition(screenUV, deviceDepth, UNITY_MATRIX_I_VP);

                float3 center = float3(i.uv1.z, i.uv2.x, i.uv1.w);
                float3 scale = i.uv3.xzy * _worldScaleAndRotY.xzy;
                float rotY = _worldScaleAndRotY.w * 0.017453 + i.uv2.z;

                float3 delta = worldPos.xzy - center.xzy;
                float3 local = mul(UNITY_MATRIX_I_M, float4(delta, 1.0)).xyz;
                float3 box = float3(MMN_RotateY(local.xy, rotY), local.z) / scale;
                half boxMask = (box.x >= -0.5 && box.x < 0.5 &&
                                box.y >= -0.5 && box.y < 0.5 &&
                                box.z >= -0.5 && box.z < 0.5) ? 1.0h : 0.0h;

                float radius = length(box.xy) * 2.0;
                float angle = atan2(box.y, box.x) * 0.159155;
                float t = MMN_FxTime();
                float2 cartUV = (box.xy + 0.5) * _MainTex_ST.xy + _MainTex_ST.zw;
                float2 polarUV = float2(radius * _MainTex_ST.x, angle * _MainTex_ST.y) + _MainTex_ST.zw;
                float2 mainUV = lerp(cartUV, polarUV, _Type);

                float2 noiseUV = MMN_DecalUV(box.xy, _NoiseTex_ST, _Noise_Twist, radius, angle, t,
                                             float2(_Noise_X_Speed, _Noise_Y_Speed));
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).g + _Distortion_Offset;
                float2 distort = noise * float2(_Distortion_X_Power, _Distortion_Y_Power) * i.uv0.w;
                mainUV += distort;

                half4 main = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half texAlpha = lerp(main.a, main.g, _Use_G_Channel_Alpha);

                float2 addST = i.uv1.xy + _AddNoiseTex_ST.zw;
                float2 addCart = (box.xy + 0.5) * _AddNoiseTex_ST.xy + addST + t * float2(_AddNoise_X_Speed, _AddNoise_Y_Speed);
                float2 addPolar;
                addPolar.x = radius * _AddNoiseTex_ST.x + addST.x;
                addPolar.y = _AddNoise_Twist * addPolar.x + angle * _AddNoiseTex_ST.y + addST.y;
                addPolar += t * float2(_AddNoise_X_Speed, _AddNoise_Y_Speed);
                float2 addUV = lerp(addCart, addPolar, _Type);
                half addNoise = SAMPLE_TEXTURE2D(_AddNoiseTex, sampler_AddNoiseTex, addUV).g;

                half alphaMask = texAlpha * addNoise - i.uv0.z;
                half crackU = lerp(cartUV.x, radius * _MainTex_ST.x, _Type);
                half grade = lerp(alphaMask, crackU, _ColorGradation);

                float3 viewWS = normalize(_WorldSpaceCameraPos - i.positionWS);
                float3 viewOS = TransformWorldToObjectDir(viewWS);
                float2 viewRot = MMN_RotateY(viewOS.xz, rotY);
                float2 parallaxUV = mainUV - distort + _ParallaxScale * viewRot + distort;
                half parallaxG = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, parallaxUV).g;
                grade = lerp(grade, parallaxG, saturate(_ColorGradation - 1.0h));
                grade = saturate((grade + _Color_Offset) * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 texTint = lerp(main.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha);
                half3 color = texTint * tint.rgb * _Intensity_Color;
                color *= 1.0h + _DimmingFactor * _IsControlPlayer;

                half alpha = saturate(alphaMask / max(1.0001h - i.uv0.z, 1e-5h) * _Intensity_Alpha);
                alpha = saturate(tint.a * alpha * i.color.a * boxMask) * saturate(_EffectAlpha);
                alpha *= MMN_NearPlaneFade(worldPos, i.screenPos, _NearPlaneAlpha,
                                           _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                           _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                           _RaycastMinimumAlpha, _NearPlaneDitherMode);
                color = MMN_LightReceive(color, _LightReceive, _LightRatio);
                alpha *= MMN_SoftParticleFade(i.screenPos, _SoftParticle,
                                              _SoftParticleNearFadeDistance,
                                              _SoftParticleFarFadeDistance,
                                              _SoftParticleFadeOutRange);
                MMN_ApplyModeTransition(color, alpha, _Mode, _TransitionValue, _SpawnTransition);
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
