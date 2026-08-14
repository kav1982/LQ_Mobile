Shader "MMN/BG/Grass"
{
    // Same channel-packing rules as MMN/BG/TreeLeaves: base maps are white RGB +
    // alpha mask, and vertex colour holds displacement scalars, not colour.
                    Properties
    {
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _TopColor ("TopColor(VertexColor G)", Color) = (0,0,0,0)
        _ShadowDim ("ShadowDimming（阴影影响）", Range(0, 1)) = 0
        _GlobalTextureBlending ("GlobalTextureBlending", Range(0, 1)) = 0
        _TextureBlendingScroll ("TextureBlendingScroll（全局贴图滚动）", Range(0, 2)) = 0.1
        _TextureBlendingWeight ("TextureBlendingWeight（全局贴图权重）", Range(-1, 1)) = 0
        [Toggle] _ShowGlobalTexture ("显示全局贴图（调试）", Float) = 0
        _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        [PowerSlider(10)] _Glossiness ("Smoothness", Range(0.1, 1)) = 0.5
        _EmissionColor ("Emission Color", Color) = (0,0,0,1)
        _EmissionMap ("Emission Map", 2D) = "white" {}
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        _WindMultiply ("Wind Multiply（风细节）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速权重）", Range(0, 40)) = 7
        _GrassPushPower ("GrassPushPower（推力影响）", Float) = 1
        _Surface ("__surface", Float) = 0
        _Blend ("__blend", Float) = 0
        _AlphaClip ("__clip", Float) = 0
        _SrcBlend ("__src", Float) = 1
        _DstBlend ("__dst", Float) = 0
        _ZWrite ("__zw", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _Smoothness ("SMoothness", Float) = 0.5
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        _GrassVisualRange ("最大可见距离", Range(-10, 10)) = 0
        [Toggle] _GrassVisualActionToggle ("启用草出现/消失演出", Float) = 1
        _InstancingColor ("_Instancing Color", Color) = (1,1,1,1)
        // Legacy preview properties still consumed by current HLSL.
        _ShadingPow ("Shading Power", Range(0.1, 8)) = 1
        _GIStrength ("GI Strength", Range(0, 2)) = 1
        _NormalLerp ("Normal Lerp To Up", Range(0, 1)) = 0.5
        _ReceiveShadowStrength ("Receive Shadow Strength", Range(0, 1)) = 1
        [Toggle] _ReceiveShadows ("Receive Shadows", Float) = 1
        [HDR] _RimColor ("Rim Color", Color) = (0,0,0,1)
        _RimArea ("Rim Area", Range(0, 32)) = 10
        _RimRange ("Rim Range", Range(0, 32)) = 10
        [Toggle] _ShowVertexColor ("Show Vertex Color", Float) = 0
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

    
        // NOT-IMPLEMENTED: contract pass shell; original GPU program was not recoverable.
        Pass
        {
            Name "BaseSSAOMask"
            Tags { "LightMode" = "BaseSSAOMask" }
            ZWrite On
            HLSLPROGRAM
            #pragma vertex vertContractShell
            #pragma fragment fragContractShell
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct ContractAttributes { float4 positionOS : POSITION; };
            float4 vertContractShell(ContractAttributes input) : SV_POSITION
            { return TransformObjectToHClip(input.positionOS.xyz); }
            half4 fragContractShell() : SV_Target { return 0; }
            ENDHLSL
        }
}

    FallBack Off

}
