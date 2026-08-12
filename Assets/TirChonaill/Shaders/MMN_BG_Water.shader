Shader "MMN/BG/Water"
{
    // Preview stand-in for the shipped MMN water. Real water uses depth/foam/SSR; here we
    // approximate with scrolled normals, distortion UV, scatter colours and fresnel so Runda
    // pools read as water instead of opaque white SimpleLit.
    Properties
    {
        _ScatterColor1 ("Scatter Color 1", Color) = (0.8, 1, 0.85, 1)
        _ScatterColor2 ("Scatter Color 2", Color) = (0.4, 0.63, 0.64, 1)
        _ScatterColor3 ("Scatter Color 3", Color) = (0.25, 0.49, 0.5, 1)
        _ScatterDepth2 ("Depth for Scatter Color 2", Float) = 0.5
        _ScatterDepth3 ("Depth for Scatter Color 3", Float) = 3.0
        _Turbidity ("Turbidity", Range(0, 1)) = 0.68
        _DepthScale ("Depth Scale", Float) = 2.5
        _FresnelColor ("Fresnel Color", Color) = (0.87, 0.76, 0.59, 0.35)
        _DistortionTexture ("Distortion Texture", 2D) = "bump" {}
        _FoamColor ("Foam Color", Color) = (0.93, 0.99, 1, 1)
        _FoamOpacity ("Foam Opacity", Range(0, 1)) = 0.25
        _FoamOffset ("Foam Offset", Range(0, 1)) = 0.07
        _FoamEdgeIntensity ("Foam Edge Intensity", Range(0, 2)) = 0
        _FlowSpeed ("Flow Speed", Float) = 1
        _DistortionAmount ("Distortion Amount", Range(0, 0.2)) = 0.04
        _BumpMap ("Normal Map", 2D) = "bump" {}
        [Toggle] _IsRaindrop ("Raindrop", Float) = 1
        [HDR] _SpecColor ("Specular Color", Color) = (1, 1, 1, 0.5)
        _SpecualrNormalMulti ("Specular Normal Multiply", Float) = 7
        _Glossiness ("Glossiness", Float) = 256
        [HideInInspector] _RaycastHarftoneClip ("Raycast Halftone Clip", Float) = 0
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
        Blend SrcAlpha OneMinusSrcAlpha
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
            #pragma multi_compile_fog
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);
            TEXTURE2D(_DistortionTexture); SAMPLER(sampler_DistortionTexture);

            CBUFFER_START(UnityPerMaterial)
                float4 _BumpMap_ST;
                float4 _DistortionTexture_ST;
                half4 _ScatterColor1;
                half4 _ScatterColor2;
                half4 _ScatterColor3;
                half _ScatterDepth2;
                half _ScatterDepth3;
                half _Turbidity;
                half _DepthScale;
                half4 _FresnelColor;
                half4 _FoamColor;
                half _FoamOpacity;
                half _FoamOffset;
                half _FoamEdgeIntensity;
                half _FlowSpeed;
                half _DistortionAmount;
                half4 _SpecColor;
                half _SpecualrNormalMulti;
                half _Glossiness;
            CBUFFER_END

            struct Attr
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Var
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float fog : TEXCOORD5;
            };

            Var vert(Attr v)
            {
                Var o;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs n = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.normalWS = n.normalWS;
                o.tangentWS = n.tangentWS;
                o.bitangentWS = n.bitangentWS;
                o.uv = TRANSFORM_TEX(v.uv, _BumpMap);
                o.fog = ComputeFogFactor(p.positionCS.z);
                return o;
            }

            half3 UnpackPreviewNormal(half4 packed)
            {
                // Exported PNG normals are often plain RGB; accept either AG-packed or RGB.
                half3 n;
                n.xy = packed.wy * 2.0h - 1.0h;
                if (dot(n.xy, n.xy) < 0.01h)
                    n.xy = packed.xy * 2.0h - 1.0h;
                n.z = sqrt(saturate(1.0h - dot(n.xy, n.xy)));
                return n;
            }

            half4 frag(Var i) : SV_Target
            {
                float t = _Time.y * _FlowSpeed * 0.05;
                float2 uvA = i.uv + float2(t, t * 0.7);
                float2 uvB = i.uv * 1.3 + float2(-t * 0.8, t * 0.5);

                half2 dist = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture,
                    TRANSFORM_TEX(i.uv, _DistortionTexture) + t).rg;
                dist = (dist * 2.0h - 1.0h) * _DistortionAmount;
                uvA += dist;
                uvB += dist * 0.6h;

                half3 nTS = normalize(
                    UnpackPreviewNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvA))
                    + UnpackPreviewNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, uvB)));
                float3x3 tbn = float3x3(normalize(i.tangentWS), normalize(i.bitangentWS), normalize(i.normalWS));
                half3 nWS = normalize(mul(nTS, tbn));

                float3 view = GetWorldSpaceNormalizeViewDir(i.positionWS);
                half ndv = saturate(dot(nWS, view));
                half fresnel = pow(1.0h - ndv, 3.0h);

                // Fake depth from view angle: looking down → shallow (color1), grazing → deep.
                half depth01 = saturate((1.0h - ndv) * _DepthScale * 0.35h + _Turbidity * 0.25h);
                half4 scatter = _ScatterColor1;
                scatter = lerp(scatter, _ScatterColor2, saturate(depth01 / max(_ScatterDepth2, 0.001h)));
                scatter = lerp(scatter, _ScatterColor3, saturate(depth01 / max(_ScatterDepth3, 0.001h)));

                half3 albedo = scatter.rgb;
                albedo = lerp(albedo, _FresnelColor.rgb, fresnel * _FresnelColor.a);
                // Soft foam near grazing edges.
                half foam = saturate(fresnel - _FoamOffset) * _FoamOpacity;
                albedo = lerp(albedo, _FoamColor.rgb, foam);

                Light L = GetMainLight();
                half3 h = normalize(L.direction + view);
                half nh = saturate(dot(normalize(nWS + nTS * (_SpecualrNormalMulti * 0.02h)), h));
                half gloss = max(_Glossiness, 8.0h);
                half3 spec = _SpecColor.rgb * pow(nh, gloss) * L.color * L.shadowAttenuation;

                half alpha = saturate(0.35h + _Turbidity * 0.45h + fresnel * 0.35h + foam);
                half3 col = albedo * (SampleSH(nWS) * 0.35h + L.color * (0.4h + 0.6h * saturate(dot(nWS, L.direction)))) + spec;
                col = MixFog(col, i.fog);
                return half4(col, alpha);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
