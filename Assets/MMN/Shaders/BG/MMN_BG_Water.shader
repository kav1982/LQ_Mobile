// Recreation of the shipped MMN/BG/Water (Sid_Water_01 icewell pool, and other BG water).
//
// Properties, tags and render states are 1:1 with
// _re_work/shader_contracts/MMN_BG_Water.contract.json: 21 properties, LOD 200 + LOD 100,
// pass "Base", LightMode "Water", Queue Transparent-200, Blend SrcAlpha OneMinusSrcAlpha,
// ZWrite Off, Cull Back.
//
// Fragment maths transcribed from SubShader 0 / Pass 0 ps_5_0
// (_re_work/shader_contracts/MMN_BG_Water.asm.txt).
//
// Contract LightMode is "Water". This project renderer has no Water feature, so the
// pass is tagged UniversalForward; otherwise the pool draws nothing.
Shader "MMN/BG/Water"
{
    Properties
    {
        [PerRendererData] _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _ScatterColor1 ("Scatter Color 1", Color) = (0.5,0.8,1,1)
        _ScatterColor2 ("Scatter Color 2", Color) = (0.06,0.2,0.4,1)
        _ScatterColor3 ("Scatter Color 3", Color) = (0,0.02,0.07,1)
        _ScatterDepth2 ("Depth for Scatter Color 2", Float) = 1
        _ScatterDepth3 ("Depth for Scatter Color 3", Float) = 1.6
        _Turbidity ("Turbidity", Range(0, 1)) = 0.5
        _DepthScale ("Depth Scale", Float) = 1
        _FresnelColor ("Fresnel Color", Color) = (0.576471,0.698039,0.8,1)
        _DistortionTexture ("DistortionTexture", 2D) = "black" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamOpacity ("Foam Opacity", Range(0, 1)) = 1
        _FoamOffset ("Foam Offset", Range(-1, 1)) = 0.1
        _FoamEdgeIntensity ("Foam Edge Intensity", Range(0, 2)) = 0
        _FlowSpeed ("Flow Speed", Float) = 1
        _DistortionAmount ("Distortion Amount", Range(0, 1)) = 1
        _BumpMap ("Normal Map ", 2D) = "bump" {}
        [Toggle] _IsRaindrop ("是否下雨", Float) = 1
        [HDR] _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        _SpecualrNormalMulti ("SpecularNormalMultiply", Range(1, 10)) = 1
        [PowerSlider(5.0)] _Glossiness ("Glossiness", Range(1, 256)) = 128
    }

    SubShader
    {
        LOD 200
        Tags
        {
            "Queue" = "Transparent-200"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "IgnoreProjector" = "true"
            "PreviewType" = "Plane"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "Base"
            Tags { "LightMode" = "UniversalForward" }

            Blend SrcAlpha OneMinusSrcAlpha, SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag

            #include "../Include/MMN_BG_WaterCommon.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _DistortionTexture_ST;
                float4 _BumpMap_ST;
                half4 _ScatterColor1;
                half4 _ScatterColor2;
                half4 _ScatterColor3;
                half4 _FresnelColor;
                half4 _FoamColor;
                half4 _SpecColor;
                float _ScatterDepth2;
                float _ScatterDepth3;
                half _Turbidity;
                float _DepthScale;
                half _FoamOpacity;
                half _FoamOffset;
                half _FoamEdgeIntensity;
                float _FlowSpeed;
                half _DistortionAmount;
                half _IsRaindrop;
                half _SpecualrNormalMulti;
                float _Glossiness;
                half _RaycastHarftoneClip;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float4 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float4 bitangentWS : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                float4 color : COLOR;
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                float3 viewWS = _WorldSpaceCameraPos - pos.positionWS;
                if (unity_OrthoParams.w != 0.0)
                    viewWS = float3(unity_MatrixV[0].z, unity_MatrixV[1].z, unity_MatrixV[2].z);

                o.positionCS = pos.positionCS;
                o.positionWS = pos.positionWS;
                o.normalWS = float4(nrm.normalWS, viewWS.x);
                o.tangentWS = float4(nrm.tangentWS, viewWS.y);
                o.bitangentWS = float4(nrm.bitangentWS, viewWS.z);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(pos.positionCS);
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                float2 uvA, uvB;
                MMN_WaterFlowUVs(i.uv, _FlowSpeed, uvA, uvB);

                float2 distA = uvA * _DistortionTexture_ST.xy + _DistortionTexture_ST.zw;
                float2 distB = uvB * _DistortionTexture_ST.xy + _DistortionTexture_ST.zw;
                half s1 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA).r;
                half s2 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distB).g;
                half s3 = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA.yx).b;
                half distTerm = (s1 + 0.4h * s2) * _DistortionAmount;

                half3 nTS = MMN_SampleFlowNormalTS(uvA, uvB, _BumpMap_ST, _DistortionAmount);
                half3 tangentWS, bitangentWS;
                MMN_WorldTBN(i.normalWS.xyz, tangentWS, bitangentWS);
                half3 normalWS = normalize(nTS.x * tangentWS + nTS.y * bitangentWS + nTS.z * normalize(i.normalWS.xyz));
                half3 viewDirWS = normalize(half3(i.normalWS.w, i.tangentWS.w, i.bitangentWS.w));

                half fresnel = MMN_CustomFresnel(normalWS, viewDirWS, distTerm);

                Light mainLight = GetMainLight();
                half3 specN = normalize(normalWS * half3(_SpecualrNormalMulti, 1.0h, _SpecualrNormalMulti));
                half3 halfDir = normalize(viewDirWS + mainLight.direction);
                half spec = pow(saturate(dot(specN, halfDir)), _Glossiness * 50.0) * 0.5h;
                half3 specCol = spec * mainLight.color * _SpecColor.rgb;

                half3 reflectDir = reflect(-viewDirWS, normalWS);
                half3 sky = MMN_SampleProbe(reflectDir);

                float thickness = MMN_WaterThickness(i.positionWS, i.screenPos);
                float depthScaled = unity_OrthoParams.w > 0.5 ? 5.0 : thickness / max(_DepthScale, 1e-4);
                half foamOpacity = unity_OrthoParams.w > 0.5 ? 0.0h : _FoamOpacity;

                half opacity = 1.0h - (half)exp(depthScaled * log(max(abs((float)_Turbidity), 1e-4)));
                // 1-pow(x,15): x≈1 → no foam, x≈0 → full Foam Color. Deep water must keep
                // foamDepth≈1 so the distortion mask can sit near 1 and cancel foam.
                half foamDepth = max(saturate(thickness + _FoamOffset), saturate(0.3h - 3.0h * thickness));
                half foamPat = (1.0h - (0.3h + 0.5h * s1 + 0.2h * s3)) / max(0.1h + 0.5h * s2, 1e-3h);
                half foam = 1.0h - pow(saturate(foamPat * foamDepth), 15.0h);
                half foamMix = saturate(foam * foamOpacity);

                half3 scatter = lerp(_ScatterColor1.rgb, _ScatterColor2.rgb,
                    saturate(depthScaled / max(_ScatterDepth2, 1e-4)));
                scatter = lerp(scatter, _ScatterColor3.rgb,
                    saturate((depthScaled - _ScatterDepth2) / max(_ScatterDepth3 - _ScatterDepth2, 1e-4)));

                half3 color = lerp(scatter, _FresnelColor.rgb * sky, fresnel);
                color = lerp(color, _FoamColor.rgb, foamMix);
                color *= i.color.rgb * mainLight.color;
                color = color * 1.5h + specCol;

                half specLum = dot(specCol, half3(0.212673h, 0.715152h, 0.072175h));
                half alpha = saturate(foamMix + opacity) + specLum;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
