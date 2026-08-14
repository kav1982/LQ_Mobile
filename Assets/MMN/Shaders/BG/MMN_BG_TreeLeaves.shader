Shader "MMN/BG/TreeLeaves"
{
    // NOT-IMPLEMENTED: original grass push, AO debug, snow and rain controls are
    // retained for material compatibility; their original-specific math is pending.
    // Leaf base maps are pure white RGB + an alpha shape mask; all colour comes
    // from _BaseColor. Vertex colour carries scalars only (G and B are always 0
    // across every MMN foliage mesh), so it must never tint albedo.
                    Properties
    {
        _BaseMap ("Base Map (RGB)  / Alpha (A)", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        [Toggle] _AlphaTest ("Alpha Test", Float) = 1
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _Surface ("__surface", Float) = 0
        _Blend ("__blend", Float) = 0
        _AlphaClip ("__clip", Float) = 0
        _SrcBlend ("__src", Float) = 1
        _DstBlend ("__dst", Float) = 0
        _ZWrite ("__zw", Float) = 1
        _Cull ("__cull", Float) = 2
        [ToggleOff] _ReceiveShadows ("Receive Shadows", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _Smoothness ("Smoothness", Float) = 0.5
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        unity_Lightmaps ("unity_Lightmaps", 2D) = "white" {}
        unity_LightmapsInd ("unity_LightmapsInd", 2D) = "white" {}
        unity_ShadowMasks ("unity_ShadowMasks", 2D) = "white" {}
        _CenterPointHeight ("Center Position Height（中心高度）", Float) = 0
        [Toggle] _ShowCenterPosition ("显示中心位置（调试）", Float) = 0
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        [Toggle] _IsBush ("IsBush（仅 Impostor 烘焙）", Float) = 0
        [Toggle] _IsSnow ("IsSnow（仅 Impostor 烘焙）", Float) = 0
        _WindMultiply ("Wind Multiply（风摆幅度）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速倍率）", Range(0, 40)) = 7
        _GrassPushPower ("GrassPushPower（草丛被推开）", Float) = 1
        _ReceiveShadowStrength ("_ReceiveShadowStrength", Range(0, 1)) = 0.5
        _AOarea ("AOarea", Range(0, 10)) = 2
        _AOintensity ("AOintensity", Float) = 3
        _AOVertical ("AO Aspect ratio（宽高比）", Range(0.01, 3)) = 1
        [Toggle] _ShowAO ("显示内部 AO（调试）", Float) = 0
        _NormalLerp ("NormalLerp", Range(0, 1)) = 1
        _ShadingPow ("ShadingPow", Range(0, 3)) = 0.2
        _TopLightColor ("Ambient TopLight Color", Color) = (0.1,0.3,0.1,1)
        _TopLightThickness ("Ambient TopLight Thickness", Range(0.1, 40)) = 4
        _RimArea ("RimArea", Range(0, 20)) = 7
        _RimRange ("RimRange", Float) = 8
        [Toggle] _TOPLIGHT ("显示顶部光（调试）", Float) = 0
        _GIStrength ("GIStrength（暗部亮度权重）", Range(0, 1)) = 0
        [Toggle] _IsRaindrop ("是否下雨/积雪", Float) = 1
        _RimColor ("RimColor", Color) = (0.1,0.3,0.1,1)
        [Toggle] _RimPreview ("Rim 预览（调试）", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
        LOD 250
        Cull [_Cull]

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _RimColor;
            half4 _TopLightColor;
            half4 _Color;
            half _Cutoff;
            half _Cull;
            half _RaycastHarftoneClip;
            half _AlphaTest;
            half _Surface;
            half _Blend;
            half _ShadingPow;
            half _GIStrength;
            half _NormalLerp;
            half _ReceiveShadowStrength;
            half _ReceiveShadows;
            half _RimArea;
            half _RimRange;
            half _TopLightThickness;
            half _WindMultiply;
            half _WindSpeedMultiply;
            half _IsBush;
            half _CenterPointHeight;
            half _ShowVertexColor;
            half _AlphaClip;
            half _AOintensity;
            half _AOarea;
            half _AOVertical;
            half _IsRaindrop;
            half _QueueOffset;
            half _SrcBlend;
            half _DstBlend;
            half _ZWrite;
            half _Smoothness;
            half _Shininess;
            half _GlossinessSource;
            half _SpecSource;
            half _ShowCenterPosition;
            half _IsSnow;
            half _GrassPushPower;
            half _ShowAO;
            half _TOPLIGHT;
            half _RimPreview;
        CBUFFER_END

        // Vertex colour A is the per-leaf flutter weight, R the per-branch bend
        // weight. Both are displacement scalars, not shading data.
        float3 ApplyWind(float3 positionOS, float4 vcol)
        {
            float amp = 0.004 * _WindMultiply;
            float speed = 0.12 * _WindSpeedMultiply;
            float phase = _Time.y * speed + positionOS.x * 0.7 + positionOS.z * 0.5;
            float flutter = sin(phase) * vcol.a;
            float bend = sin(phase * 0.45) * vcol.r;
            positionOS.x += (flutter + bend * 0.5) * amp;
            positionOS.z += (flutter * 0.5 + bend) * amp;
            positionOS.y += flutter * amp * 0.25;
            return positionOS;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="BG" }
            Cull Off
            ZWrite [_ZWrite]
            Blend [_SrcBlend] [_DstBlend]
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attr
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
            };
            struct Var
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
                float4 color : TEXCOORD3;
                float fog : TEXCOORD4;
            };

            Var vert(Attr v)
            {
                Var o;
                float3 pos = ApplyWind(v.positionOS.xyz, v.color);
                VertexPositionInputs p = GetVertexPositionInputs(pos);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;

                float3 nWS = GetVertexNormalInputs(v.normalOS).normalWS;
                // Foliage cards read better with normals biased toward up.
                o.normalWS = normalize(lerp(nWS, float3(0, 1, 0), _NormalLerp));

                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.color = v.color;
                o.fog = ComputeFogFactor(p.positionCS.z);
                return o;
            }

            half4 frag(Var i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half alpha = tex.a * _BaseColor.a;
                clip(alpha - _Cutoff);

                if (_ShowVertexColor > 0.5h)
                    return half4(i.color.rgb, 1);

                half3 albedo = tex.rgb * _BaseColor.rgb;

                // No two-sided flip here: the normal is already biased toward up, so negating it
                // would point back-facing cards downward, zeroing the top-light term below and
                // making the canopy swing in brightness as the camera orbits. The wrapped diffuse
                // is what keeps the unlit side from going black.
                half3 n = normalize(i.normalWS);

                Light L = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half shadow = lerp(1.0h, L.shadowAttenuation, _ReceiveShadows * _ReceiveShadowStrength);

                // Wrapped diffuse: leaf cards are double sided, so keep the dark side lit.
                half ndl = pow(saturate(dot(n, L.direction) * 0.5h + 0.5h), _ShadingPow);
                half3 direct = L.color * ndl * shadow;
                // _GIStrength boosts on top of base ambient: shipped materials use 0.0 to mean "no boost".
                half3 ambient = SampleSH(n) * (1.0h + _GIStrength);

                half3 col = albedo * (direct + ambient);

                half3 view = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half rim = pow(saturate(1 - saturate(dot(n, view))), max(_RimRange, 0.01h)) * saturate(_RimArea / 32.0h);
                col += _RimColor.rgb * rim;

                half top = saturate(n.y) * saturate(_TopLightThickness / 64.0h);
                col += _TopLightColor.rgb * top;

                return half4(MixFog(col, i.fog), 1);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // Shadows.hlsl calls LerpWhiteTo, which only the core material library declares.
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };

            Var vert(Attr v)
            {
                Var o;
                float3 pos = ApplyWind(v.positionOS.xyz, v.color);
                float3 positionWS = TransformObjectToWorld(pos);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _MainLightPosition.xyz));
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            half4 frag(Var i) : SV_Target
            {
                clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ZWrite On
            ColorMask 0
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attr { float4 positionOS:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };

            Var vert(Attr v)
            {
                Var o;
                float3 pos = ApplyWind(v.positionOS.xyz, v.color);
                o.positionCS = TransformWorldToHClip(TransformObjectToWorld(pos));
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            half4 frag(Var i) : SV_Target
            {
                clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "BaseSSAOMask"
            Tags { "LightMode"="BaseSSAOMask" }
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attr { float4 positionOS:POSITION; float4 color:COLOR; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; };

            Var vert(Attr v)
            {
                Var o;
                float3 pos = ApplyWind(v.positionOS.xyz, v.color);
                o.positionCS = TransformWorldToHClip(TransformObjectToWorld(pos));
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            half4 frag(Var i) : SV_Target
            {
                clip(SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv).a * _BaseColor.a - _Cutoff);
                return 0;
            }
            ENDHLSL
        }
    }
    FallBack Off
}
