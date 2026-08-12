Shader "MMN/BG/Grass"
{
    // Same channel-packing rules as MMN/BG/TreeLeaves: base maps are white RGB +
    // alpha mask, and vertex colour holds displacement scalars, not colour.
    Properties
    {
        [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 0

        [Header(Shading)]
        _ShadingPow ("Shading Power", Range(0.1, 8)) = 1
        _GIStrength ("GI Strength", Range(0, 2)) = 1
        _NormalLerp ("Normal Lerp To Up", Range(0, 1)) = 0.5
        _ReceiveShadowStrength ("Receive Shadow Strength", Range(0, 1)) = 1
        [Toggle] _ReceiveShadows ("Receive Shadows", Float) = 1

        [Header(Rim)]
        [HDR] _RimColor ("Rim Color", Color) = (0,0,0,1)
        _RimArea ("Rim Area", Range(0, 32)) = 10
        _RimRange ("Rim Range", Range(0, 32)) = 10

        [Header(Wind)]
        _WindMultiply ("Wind Multiply", Range(0, 32)) = 5
        _WindSpeedMultiply ("Wind Speed", Range(0, 32)) = 8
        _GrassPushPower ("Grass Push Power", Range(0, 8)) = 2

        [Header(Debug)]
        [Toggle] _ShowVertexColor ("Show Vertex Color", Float) = 0

        [HideInInspector] _MainTex ("Legacy MainTex", 2D) = "white" {}
        [HideInInspector] _Color ("Legacy Color", Color) = (1,1,1,1)
        [HideInInspector] _AlphaClip ("Alpha Clip", Float) = 1
        [HideInInspector] _ALPHATEST ("Alpha Test", Float) = 1
        [HideInInspector] _AlbedoTintStrength ("Albedo Tint Strength", Float) = 0
        [HideInInspector] _IsRaindrop ("Raindrop / Snow", Float) = 1
        [HideInInspector] _QueueOffset ("Queue Offset", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="TransparentCutout" "Queue"="AlphaTest" "RenderPipeline"="UniversalPipeline" "IgnoreProjector"="True" }
        LOD 200
        Cull [_Cull]

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            half4 _BaseColor;
            half4 _RimColor;
            half4 _Color;
            half _Cutoff;
            half _Cull;
            half _ShadingPow;
            half _GIStrength;
            half _NormalLerp;
            half _ReceiveShadowStrength;
            half _ReceiveShadows;
            half _RimArea;
            half _RimRange;
            half _WindMultiply;
            half _WindSpeedMultiply;
            half _GrassPushPower;
            half _ShowVertexColor;
            half _AlphaClip;
            half _ALPHATEST;
            half _AlbedoTintStrength;
            half _IsRaindrop;
            half _QueueOffset;
        CBUFFER_END

        // Vertex colour A is the blade-tip weight, so the sway pivots at the root.
        float3 ApplyWind(float3 positionOS, float4 vcol)
        {
            float amp = 0.006 * _WindMultiply;
            float speed = 0.2 * _WindSpeedMultiply;
            float phase = _Time.y * speed + positionOS.x * 0.9 + positionOS.z * 0.7;
            float sway = sin(phase) * vcol.a;
            positionOS.x += sway * amp;
            positionOS.z += sway * amp * 0.6;
            return positionOS;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);

            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float4 color:COLOR; float2 uv:TEXCOORD0; };
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

                // No two-sided flip: the normal is already biased toward up, and negating it would
                // make blade shading depend on which side the camera happens to see.
                half3 n = normalize(i.normalWS);

                Light L = GetMainLight(TransformWorldToShadowCoord(i.positionWS));
                half shadow = lerp(1.0h, L.shadowAttenuation, _ReceiveShadows * _ReceiveShadowStrength);
                half ndl = pow(saturate(dot(n, L.direction) * 0.5h + 0.5h), _ShadingPow);

                // _GIStrength boosts on top of base ambient rather than scaling it.
                half3 col = albedo * (L.color * ndl * shadow + SampleSH(n) * (1.0h + _GIStrength));

                half3 view = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half rim = pow(saturate(1 - saturate(dot(n, view))), max(_RimRange, 0.01h)) * saturate(_RimArea / 32.0h);
                col += _RimColor.rgb * rim;

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
    }
    FallBack Off
}
