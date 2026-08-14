// Recreation of the shipped MMN/BG/Caustic, the shader on Colhen_Water_Caustic (the caustics that
// play over the sea floor inside the Colhen bay).
//
// Property list, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_BG_Caustic.contract.json): 23 properties, one SubShader with a
// single pass "Base" tagged LightMode "Decal", Queue Transparent-300, RenderType Transparent,
// Blend SrcAlpha One, ZWrite Off, ZTest LEqual, Cull Back.
//
// This replaces the earlier preview stand-in that lived in Assets/TirChonaill/Shaders. That
// version had ~40 invented properties (a union of several caustics variants seen in materials) and
// rendered as a lit UniversalForward surface. The shipped shader is neither: the pass is a
// projected box decal. Its uniform table binds unity_MatrixInvVP, _ZBufferParams and
// _ProjectionParams and the material is drawn on a unit cube, so the fragment reconstructs the
// world position of whatever the box covers from the depth buffer and projects the caustics onto
// it. Blend SrcAlpha One then adds it over the floor, i.e. the pattern lives in alpha.
//
// NOT-IMPLEMENTED: _Global_Night2Day - the game's day/night blend, which fades caustics at night.
Shader "MMN/BG/Caustic"
{
                    Properties
    {
        _BaseMap ("BaseMap", 2D) = "white" {}
        _MaskMap ("MaskMap", 2D) = "white" {}
        _CausticsColor ("CausticsColor", Color) = (1,1,1,1)
        _AlphaAdd ("AlphaAdd", Range(0, 1)) = 0.2
        _AlphaWaveLength ("AlphaWaveLength", Range(0, 1)) = 0.1
        _AlphaWaveSpeed ("AlphaWaveSpeed", Range(0, 3)) = 1
        _DistortionSpeed ("DistortionSpeed", Range(0, 1)) = 0.1
        _DistortionPower ("DistortionPower", Range(0, 1)) = 0.3
        _DistortionTile ("DistortionTile", Vector) = (20,20,0,0)
        _CausticsPower ("CausticsPower", Range(0, 3)) = 1.2
        _CausticsBrightness1 ("CausticsBrightness1", Range(0, 1)) = 0.3
        _CausticsBrightness2 ("CausticsBrightness2", Range(0, 1)) = 0.3
        _CausticsDirection ("CausticsDirection", Vector) = (0.6,0.3,-0.6,-0.3)
        _CausticsTile1 ("CausticsTile1", Range(0, 1)) = 0.2
        _CausticsTile2 ("CausticsTile2", Range(0, 1)) = 0.2
        _CausticsSpeed1 ("CausticsSpeed1", Float) = 0.2
        _CausticsSpeed2 ("CausticsSpeed2", Float) = 0.2
        _UseCaustics2 ("UseCaustics2", Float) = 0
        _CausticsWaveLength1 ("CausticsWaveLength1", Range(0, 0.5)) = 0.05
        _CausticsWaveLength2 ("CausticsWaveLength2", Range(0, 0.5)) = 0.05
        _CausticsWaveSpeed1 ("CausticsWaveSpeed1", Range(0, 3)) = 1
        _CausticsWaveSpeed2 ("CausticsWaveSpeed2", Range(0, 3)) = 1
        _ReceiveLight ("ReceiveLight", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent-300"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "Base"
            Tags { "LightMode" = "Decal" }

            Blend SrcAlpha One
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_MaskMap); SAMPLER(sampler_MaskMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _CausticsColor;
                float4 _DistortionTile;
                float4 _CausticsDirection;
                half _AlphaAdd;
                half _AlphaWaveLength;
                half _AlphaWaveSpeed;
                half _DistortionSpeed;
                half _DistortionPower;
                half _CausticsPower;
                half _CausticsBrightness1;
                half _CausticsBrightness2;
                half _CausticsTile1;
                half _CausticsTile2;
                float _CausticsSpeed1;
                float _CausticsSpeed2;
                half _UseCaustics2;
                half _CausticsWaveLength1;
                half _CausticsWaveLength2;
                half _CausticsWaveSpeed1;
                half _CausticsWaveSpeed2;
                half _ReceiveLight;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                return o;
            }

            // One caustics layer: tile the decal UV, drift it along its direction and warp it with
            // a cross sine so the cells wobble instead of sliding as a rigid sheet.
            half SampleCaustics(float2 decalUV, float tile, float2 dir, float speed,
                                half waveLength, half waveSpeed)
            {
                float t = _Time.y;
                float2 uv = decalUV * max(tile, 1e-3h) + dir * (t * speed);
                float2 warp = float2(sin((uv.y + t * waveSpeed) / max(waveLength, 1e-3h)),
                                     cos((uv.x + t * waveSpeed) / max(waveLength, 1e-3h)));
                uv += warp * _DistortionPower * 0.02h;
                uv += float2(t, -t) * _DistortionSpeed * 0.05h;
                return SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv).r;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 screenUV = GetNormalizedScreenSpaceUV(i.positionCS);

                // Reconstruct what the box is covering, then move it into the box's own space so
                // the projection follows the decal volume rather than the screen.
                float rawDepth = SampleSceneDepth(screenUV);
                float3 positionWS = ComputeWorldSpacePosition(screenUV, rawDepth, UNITY_MATRIX_I_VP);
                float3 positionOS = TransformWorldToObject(positionWS);
                clip(0.5 - max(max(abs(positionOS.x), abs(positionOS.y)), abs(positionOS.z)));

                float2 decalUV = (positionOS.xz + 0.5) * _DistortionTile.xy;

                half c1 = SampleCaustics(decalUV, _CausticsTile1, _CausticsDirection.xy,
                                         _CausticsSpeed1, _CausticsWaveLength1, _CausticsWaveSpeed1);
                half c2 = _UseCaustics2 > 0.5h
                            ? SampleCaustics(decalUV, _CausticsTile2, _CausticsDirection.zw,
                                             _CausticsSpeed2, _CausticsWaveLength2, _CausticsWaveSpeed2)
                            : 0.0h;

                half pattern = c1 * _CausticsBrightness1 + c2 * _CausticsBrightness2;
                pattern = pow(saturate(pattern), max(_CausticsPower, 1e-3h));

                half mask = SAMPLE_TEXTURE2D(_MaskMap, sampler_MaskMap, positionOS.xz + 0.5).r;

                // Slow breathing of the whole sheet, as if the surface above were swelling.
                half wave = 1.0h + sin((positionOS.x + positionOS.z) / max(_AlphaWaveLength, 1e-3h)
                                       + _Time.y * _AlphaWaveSpeed) * 0.5h;

                half alpha = saturate((pattern * wave + _AlphaAdd * pattern) * mask);

                if (_ReceiveLight > 0.5h)
                {
                    // Only _MainLightPosition is bound, not its colour, so the light can only gate
                    // the intensity: caustics fade out as the sun drops to the horizon.
                    alpha *= saturate(_MainLightPosition.y);
                }

                return half4(_CausticsColor.rgb, alpha);
            }
            ENDHLSL
        }
    }

    // The shipped shader points CustomEditor at MM.Client.Editor.ShaderGUI.MMN_CausticGUI, which
    // is not part of the extracted data; left out so Unity does not error per material.
    FallBack Off
}
