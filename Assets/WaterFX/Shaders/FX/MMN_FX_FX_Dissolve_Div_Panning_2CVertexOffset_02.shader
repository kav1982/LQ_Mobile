// Recreation of the shipped MMN/FX/Amplify shader/FX_Dissolve_Div_Panning_2CVertexOffset_02,
// the shader on the Colhen shoreline wave materials (FX_Shoreline_Wave_01/02/03).
//
// Properties, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_FX_FX_Dissolve_Div_Panning_2CVertexOffset_02.contract.json:
// 51 properties, one Unlit pass, LOD 100, Queue Transparent, Blend [_BlendSrc] [_BlendDst],
// ZWrite Off, ZTest [_ZTest], Cull [_CullMode]).
//
// The vertex and fragment maths is transcribed from the shipped D3D11 bytecode, disassembled
// into _re_work/shader_contracts/<same name>.asm.txt by _re_work/dump_shader_bytecode.py, so it
// is the original graph rather than an approximation of it.
//
// The particle renderer must feed the custom vertex streams the shipped prefab configures --
// Position, Normal, Color, UV, Custom1XYZW, Custom2XYZW -- which arrive as:
//   TEXCOORD0.zw = Custom1.xy = dissolve, vertex offset power  (the two [Header] lines below)
//   TEXCOORD1.xy = Custom1.zw = crest displacement scale, sine swell scale
//   TEXCOORD1.zw = Custom2.xy = foam/wash blend, per-particle UV and phase offset
//
// NOT-IMPLEMENTED: the FOG_LINEAR variant. It runs the client's own height/distance fog off
//                  _Global_DimFog_* / _Global_FogHeight* globals that only the game sets; with
//                  them at zero the shipped maths divides by zero, so fog is left off here.
// NOT-IMPLEMENTED: the DEBUG_DISPLAY variant (URP rendering debugger only).
// NOT-IMPLEMENTED: _AlphaCutoff and _EmissionColor. Both are in the property block but no
//                  shipped variant reads them; the pass blends and never clips.
Shader "MMN/FX/Amplify shader/FX_Dissolve_Div_Panning_2CVertexOffset_02"
{
    Properties
    {
        [HideInInspector] _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        [HideInInspector] _AlphaCutoff ("Alpha Cutoff ", Range(0, 1)) = 0.5
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
        [Header(tcd0.z     Dissolve)] [Header(tcd0.w     VertexOffset Power)] [Header(Main Texture)] [Space()] _MainTex ("MainTex", 2D) = "white" {}
        _Main_X_Speed ("Main_X_Speed", Float) = 1
        _Main_Y_Speed ("Main_Y_Speed", Float) = 1
        [Toggle] _Use_G_Channel_Alpha ("Use_G_Channel_Alpha", Float) = 0
        [Header(Noise Texture)] [Space()] _NoiseTex ("NoiseTex", 2D) = "white" {}
        _NoiseTex_WolrdTilling ("NoiseTex_WolrdTilling", Float) = 0.2
        _Noise_X_Speed ("Noise_X_Speed", Float) = 1
        _Noise_Y_Speed ("Noise_Y_Speed", Float) = 1
        [Header(Noise Texture)] [Space()] _NoiseTex2 ("NoiseTex2", 2D) = "white" {}
        _Noise_X_Speed2 ("Noise_X_Speed2", Float) = 1
        _Noise_Y_Speed2 ("Noise_Y_Speed2", Float) = 1
        [Header(Vertex Texture)] [Space()] _VertexTex ("VertexTex", 2D) = "white" {}
        _VertexPower ("VertexPower", Float) = 1
        _Vertex_X_Speed ("Vertex_X_Speed", Float) = 1
        _Vertex_Y_Speed ("Vertex_Y_Speed", Float) = 1
        [Enum(Alpha,0,UV,1)] [Header(Color)] [Space()] _ColorGradation ("Color Gradation", Float) = 0
        _MainColor ("Main Color", Color) = (0.501961,0.501961,0.501961,1)
        _SubColor ("Sub Color", Color) = (1,1,1,1)
        [Space(5)] _Color_Offset ("Color_Offset", Float) = 0
        _Color_Range ("Color_Range", Float) = 1
        [Header(Vertex Sin Wave)] [Space()] _WaveLength ("WaveLength", Float) = 5
        _WaveSpeed ("WaveSpeed", Float) = 5
        _WavePower ("WavePower", Float) = 1
        [Header(Intensity)] [Space()] _Intensity_Color ("Intensity_Color", Float) = 1
        _Intensity_Alpha ("Intensity_Alpha", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] [Header(Rendering Options)] [Space()] [HideInInspector] _BlendSrc ("Blend Src", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] [HideInInspector] _BlendDst ("Blend Dst", Float) = 10
        [Enum(UnityEngine.Rendering.CullMode)] [HideInInspector] _CullMode ("Cull Mode", Float) = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] [HideInInspector] _ZTest ("Z Test", Float) = 4
        [HideInInspector] _EffectAlpha ("EffectAlpha", Float) = 1
    }

    SubShader
    {
        LOD 100
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            // No LightMode tag in the shipped pass, so URP draws it as SRPDefaultUnlit.
            Name "Unlit"

            Blend [_BlendSrc] [_BlendDst]
            BlendOp Add
            ZWrite Off
            ZTest [_ZTest]
            Cull [_CullMode]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local_fragment _RAYCAST_ON

            #define MMN_FX_USE_DEPTH

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "../Include/MMN_FX_Common.hlsl"

            TEXTURE2D(_MainTex);   SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex);  SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_NoiseTex2); SAMPLER(sampler_NoiseTex2);
            TEXTURE2D(_VertexTex); SAMPLER(sampler_VertexTex);

            // _NoiseTex_ST is deliberately absent: the shipped program tiles that layer by world
            // position instead, so the constant never made it into UnityPerMaterial.
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NoiseTex2_ST;
                float4 _VertexTex_ST;
                half4 _EmissionColor;
                half4 _MainColor;
                half4 _SubColor;
                float4 _NearPlaneAlphaEdge;
                float4 _NearPlaneDirectionValue;
                half _AlphaCutoff;
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
                half _FogReceive;
                half _SoftParticleFadeOutRange;
                half _Raycast;
                float _Main_X_Speed;
                float _Main_Y_Speed;
                half _Use_G_Channel_Alpha;
                float _NoiseTex_WolrdTilling;
                float _Noise_X_Speed;
                float _Noise_Y_Speed;
                float _Noise_X_Speed2;
                float _Noise_Y_Speed2;
                float _VertexPower;
                float _Vertex_X_Speed;
                float _Vertex_Y_Speed;
                half _ColorGradation;
                float _Color_Offset;
                float _Color_Range;
                float _WaveLength;
                float _WaveSpeed;
                float _WavePower;
                half _Intensity_Color;
                half _Intensity_Alpha;
                half _BlendSrc;
                half _BlendDst;
                half _CullMode;
                half _ZTest;
                half _EffectAlpha;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 uv0 : TEXCOORD0;
                float4 uv1 : TEXCOORD1;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv0 : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float2 custom2 : TEXCOORD3;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                float time = MMN_FxTime();

                // Sine swell, one hump across V and zero at both edges of the card, pushed
                // sideways along the card rather than along its normal.
                float span = 4.0 * (1.0 - v.uv0.y) * v.uv0.y;
                float swell = sin(v.uv0.y * _WaveLength + time * _WaveSpeed + v.uv1.w) * span;
                float3 sideways = float3(v.normalOS.y, -v.normalOS.x, 0.0); // cross(normal, +Z)
                float3 swellOffset = sideways * swell * v.uv0.w * v.uv1.y * _WavePower;

                // Crest: the scrolling vertex texture lifts the middle of the card along its
                // normal, which is what turns a flat quad into a breaking wave.
                float2 vertexUV = v.uv0.xy * _VertexTex_ST.xy + _VertexTex_ST.zw;
                float crestSpan = 4.0 * (1.0 - vertexUV.x) * vertexUV.x;
                float3 crest = v.normalOS * crestSpan * _VertexPower * v.uv1.x;
                float2 heightUV = float2(vertexUV.x, vertexUV.y + v.uv1.w)
                                + float2(_Vertex_X_Speed, _Vertex_Y_Speed) * time;
                float height = SAMPLE_TEXTURE2D_LOD(_VertexTex, sampler_VertexTex, heightUV, 0).g;

                float3 positionOS = v.positionOS.xyz + crest * height + swellOffset;

                VertexPositionInputs positions = GetVertexPositionInputs(positionOS);
                o.positionCS = positions.positionCS;
                o.positionWS = positions.positionWS;
                o.screenPos = positions.positionNDC;
                o.uv0 = v.uv0;
                o.custom2 = v.uv1.zw;
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float time = MMN_FxTime();
                half dissolve = (half)i.uv0.z;
                float slide = i.custom2.y;   // per-particle offset, keeps emitters out of phase

                float2 mainUV = i.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw;
                mainUV.y += slide;
                mainUV += float2(_Main_X_Speed, _Main_Y_Speed) * time;
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, mainUV);
                half mainAlpha = lerp(mainTex.a, mainTex.g, _Use_G_Channel_Alpha);

                float2 noise2UV = i.uv0.xy * _NoiseTex2_ST.xy + _NoiseTex2_ST.zw + slide
                                + float2(_Noise_X_Speed2, _Noise_Y_Speed2) * time;
                half noise2 = SAMPLE_TEXTURE2D(_NoiseTex2, sampler_NoiseTex2, noise2UV).g;

                // The first noise layer is tiled by world position, so neighbouring emitters
                // read as one continuous sheet of foam instead of each repeating its own card.
                float2 noiseUV = i.positionWS.xz * _NoiseTex_WolrdTilling + slide
                               + float2(_Noise_X_Speed, _Noise_Y_Speed) * time;
                half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, noiseUV).b;

                // U runs from the water line outwards, so 1-U weights everything towards the lip.
                half lip = (half)saturate(1.0 - i.uv0.x);
                half edge = (lip + (half)i.uv0.w) * i.color.a;

                half foam = saturate(mainAlpha + edge * noise2);
                half lip4 = lip * lip;
                lip4 = lip4 * lip4;
                half wash = saturate(lip4 * dissolve + noise * noise2 * noise2 * edge);
                half mask = lerp(foam, wash, (half)i.custom2.x) - dissolve;

                half grade = saturate((lerp(mask, (half)i.uv0.x, _ColorGradation) + _Color_Offset)
                                      * _Color_Range);
                half4 tint = lerp(_SubColor, _MainColor, grade);

                half3 color = lerp(mainTex.rgb * i.color.rgb, i.color.rgb, _Use_G_Channel_Alpha)
                            * (tint.rgb * _Intensity_Color);

                // Renormalising by 1-dissolve keeps the wave at full opacity while the dissolve
                // eats into it, so it thins out from the edges instead of fading as a whole.
                half alpha = saturate(mask / (1.0h - dissolve) * _Intensity_Alpha)
                           * (tint.a * i.color.a) * saturate(_EffectAlpha);

                alpha *= MMN_NearPlaneFade(i.positionWS, i.screenPos, _NearPlaneAlpha,
                                           _NearPlaneAlphaEdge, _NearPlaneInvertDistance,
                                           _NearPlaneDirectionMode, _NearPlaneDirectionValue,
                                           _RaycastMinimumAlpha, _NearPlaneDitherMode);
                #ifdef _RAYCAST_ON
                    alpha *= saturate(max(1.0h - _RaycastHarftoneClip, _RaycastMinimumAlpha));
                #endif

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

    // The shipped shader points CustomEditor at
    // MM.Client.Editor.ShaderGUI.MMN_FxBlendModeShaderGUI, which is not part of the extracted
    // data; it is left out so Unity does not error per material.
    FallBack Off
}
