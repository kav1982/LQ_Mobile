// Recreation of the shipped MMN/BG/Waterfall (Sid_Water_00 icewell fall sheet).
//
// Properties, tags and render states are 1:1 with
// _re_work/shader_contracts/MMN_BG_Waterfall.contract.json: 17 properties, pass "Base",
// LightMode "Water", Queue Transparent-200.
//
// Vertex displacement and fragment maths transcribed from
// _re_work/shader_contracts/MMN_BG_Waterfall.asm.txt.
Shader "MMN/BG/Waterfall"
{
    Properties
    {
        [PerRendererData] _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        _ScatterColor2 ("Scatter Color 2", Color) = (0.06,0.2,0.4,1)
        _Turbidity ("Turbidity", Range(0, 1)) = 0.5
        _FresnelColor ("Fresnel Color", Color) = (0.576471,0.698039,0.8,1)
        _VertexFlowSpeed ("顶点流动速度", Float) = 3
        _VertexFlowCrmpled ("顶点流动褶皱", Range(0, 1)) = 0.3
        _DistortionTexture ("DistortionTexture", 2D) = "black" {}
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _FoamOpacity ("Foam Opacity", Range(0, 1)) = 1
        _FoamOffset ("Foam Offset", Range(-1, 1)) = 0.1
        _FlowSpeed ("Flow Speed", Float) = 1
        _BumpMap ("Normal Map ", 2D) = "bump" {}
        _DistortionAmount ("Distortion Amount", Range(0, 1)) = 1
        [HDR] _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        [PowerSlider(5.0)] _Glossiness ("Glossiness", Range(1, 256)) = 128
    }

    SubShader
    {
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
            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _SHOWVERTEXCOLOR_ON
            #pragma shader_feature_local _SHOWVERTEXALPHA_ON

            #include "../Include/MMN_BG_WaterCommon.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _DistortionTexture_ST;
                float4 _BumpMap_ST;
                half4 _ScatterColor2;
                half4 _FresnelColor;
                half4 _FoamColor;
                half4 _SpecColor;
                half _Turbidity;
                half _FoamOpacity;
                half _FoamOffset;
                float _FlowSpeed;
                half _DistortionAmount;
                float _Glossiness;
                float _VertexFlowSpeed;
                half _VertexFlowCrmpled;
                half _ShowVertexColor;
                half _ShowVertexAlpha;
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
                float2 flowUV = v.uv * 5.0 + float2(0.0, -_Time.z * _VertexFlowSpeed);
                flowUV = flowUV * _BumpMap_ST.xy + _BumpMap_ST.zw;
                half3 nTS = MMN_UnpackRG(SAMPLE_TEXTURE2D_LOD(_BumpMap, sampler_BumpMap, flowUV, 0));
                float3 posWS = TransformObjectToWorld(v.positionOS.xyz);
                posWS.xz += nTS.xy * _VertexFlowCrmpled * (1.0h - v.color.r);

                float3 viewWS = _WorldSpaceCameraPos - posWS;
                if (unity_OrthoParams.w != 0.0)
                    viewWS = float3(unity_MatrixV[0].z, unity_MatrixV[1].z, unity_MatrixV[2].z);

                VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.positionCS = TransformWorldToHClip(posWS);
                o.positionWS = posWS;
                o.normalWS = float4(nrm.normalWS, viewWS.x);
                o.tangentWS = float4(nrm.tangentWS, viewWS.y);
                o.bitangentWS = float4(nrm.bitangentWS, viewWS.z);
                o.uv = v.uv;
                o.screenPos = ComputeScreenPos(o.positionCS);
                o.color = v.color;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                if (_ShowVertexColor > 0.5h) return half4(i.color.rgb, 1);
                if (_ShowVertexAlpha > 0.5h) return half4(i.color.aaa, 1);

                float2 uvA, uvB;
                MMN_WaterFlowUVs(i.uv, _FlowSpeed, uvA, uvB);

                float2 distA = uvA * _DistortionTexture_ST.xy + _DistortionTexture_ST.zw;
                float2 distB = uvB * _DistortionTexture_ST.xy + _DistortionTexture_ST.zw;
                half2 tapA = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distA).rb;
                half tapB = SAMPLE_TEXTURE2D(_DistortionTexture, sampler_DistortionTexture, distB).g;
                half s1 = tapA.x;
                half s2 = tapA.y;
                half s3 = tapB;
                half distTerm = (s1 + 0.4h * s3) * _DistortionAmount;

                half3 nTS = MMN_SampleFlowNormalTS(uvA, uvB, _BumpMap_ST, _DistortionAmount);
                half3 normalWS = normalize(
                    nTS.x * i.tangentWS.xyz + nTS.y * i.bitangentWS.xyz + nTS.z * i.normalWS.xyz);
                half3 viewDirWS = normalize(half3(i.normalWS.w, i.tangentWS.w, i.bitangentWS.w));
                half fresnel = MMN_CustomFresnel(normalWS, viewDirWS, distTerm);

                Light mainLight = GetMainLight();
                half3 halfDir = normalize(viewDirWS + mainLight.direction);
                half spec = pow(saturate(dot(normalWS, halfDir)), _Glossiness * 50.0) * 0.5h;
                half3 specCol = spec * mainLight.color * _SpecColor.rgb;

                half3 reflectDir = reflect(-viewDirWS, normalWS);
                half3 sky = MMN_SampleProbe(reflectDir);

                float thickness = MMN_WaterThickness(i.positionWS, i.screenPos);
                float depthForTurbid = unity_OrthoParams.w > 0.5 ? 5.0 : thickness;
                half opacity = 1.0h - (half)exp(depthForTurbid * log(max(abs((float)_Turbidity), 1e-4)));
                half foamDepth = max(saturate(thickness + _FoamOffset), saturate(0.5h - 3.0h * thickness));
                half foamPat = (1.0h - (0.3h + 0.5h * s1 + 0.2h * s2)) / max(s3 + 0.1h, 1e-3h);
                half foam = 1.0h - pow(saturate(foamPat * foamDepth * i.color.g), 15.0h);
                half foamMix = saturate(foam * _FoamOpacity);

                half3 color = lerp(_ScatterColor2.rgb, _FresnelColor.rgb * sky, fresnel);
                color = lerp(color, _FoamColor.rgb, foamMix);
                color = color * (i.color.a * mainLight.color) + specCol;

                half specLum = dot(specCol, half3(0.212673h, 0.715152h, 0.072175h));
                half alpha = saturate(foamMix + opacity + specLum) * i.color.b;
                return half4(color, alpha);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
