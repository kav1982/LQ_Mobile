// Recreation of the shipped MMN/BG/Sky_Lit, the shader on Colhen_FarTerrain_00 - the distant
// headland and cliffs that close off the Colhen bay.
//
// Property list, tags and render states are 1:1 with the extracted contract
// (_re_work/shader_contracts/MMN_BG_Sky_Lit.contract.json): 8 properties, one SubShader at LOD
// 300, a single pass "SkyLit" tagged LightMode "SkyLit", Queue Transparent-399, RenderType
// Transparent, UniversalMaterialType SimpleLit, Blend One Zero, ZWrite Off, ZClip Off, Cull Back.
//
// Queue Transparent-399 with ZWrite Off is how the game draws its far scenery: it goes down after
// the opaque world, behind everything, as a backdrop that never writes depth. LightMode "SkyLit"
// is the game's own tag, so a RenderObjects renderer feature filtering on it has to exist or the
// far terrain will not draw at all. MMN/BeachPreview/Editor sets that up.
//
// NOT-IMPLEMENTED: _Global_SkyColorTop and _Global_GILightMulti - the game's sky tint and GI
//                  multiplier globals, which this shader mixes into the ambient term.
Shader "MMN/BG/Sky_Lit"
{
    Properties
    {
        [MainTexture] _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor] _BaseColor ("Base Tint", Color) = (1,1,1,1)
        _AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
        [HideInInspector] _BumpScale ("Scale", Float) = 1
        [NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
        [HideInInspector] [NoScaleOffset] unity_Lightmaps ("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector] [NoScaleOffset] unity_LightmapsInd ("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector] [NoScaleOffset] unity_ShadowMasks ("unity_ShadowMasks", 2DArray) = "" {}
    }

    SubShader
    {
        LOD 300
        Tags
        {
            "Queue" = "Transparent-399"
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "true"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "SkyLit"
            Tags { "LightMode" = "SkyLit" }

            Blend One Zero
            ZWrite Off
            ZTest LEqual
            ZClip Off
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap); SAMPLER(sampler_BumpMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half _AlbedoTintStrength;
                half _BumpScale;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float4 tangentWS : TEXCOORD2;
                float3 positionWS : TEXCOORD3;
                float fogFactor : TEXCOORD4;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
            };

            Varyings vert(Attributes v)
            {
                Varyings o = (Varyings)0;
                VertexPositionInputs pos = GetVertexPositionInputs(v.positionOS.xyz);
                VertexNormalInputs nrm = GetVertexNormalInputs(v.normalOS, v.tangentOS);
                o.positionCS = pos.positionCS;
                o.positionWS = pos.positionWS;
                o.normalWS = nrm.normalWS;
                o.tangentWS = float4(nrm.tangentWS, v.tangentOS.w);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.fogFactor = ComputeFogFactor(pos.positionCS.z);
                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                half3 albedo = baseMap.rgb * _BaseColor.rgb;
                // Positive strength pushes the tint, negative pulls back toward the raw map.
                albedo = lerp(albedo, albedo * (1.0h + _AlbedoTintStrength), saturate(abs(_AlbedoTintStrength)));

                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv), _BumpScale);
                float sgn = i.tangentWS.w;
                float3 bitangent = sgn * cross(i.normalWS.xyz, i.tangentWS.xyz);
                half3 n = normalize(TransformTangentToWorld(normalTS,
                                    half3x3(i.tangentWS.xyz, bitangent, i.normalWS.xyz)));

                half3 gi = SAMPLE_GI(i.lightmapUV, i.vertexSH, n);
                Light mainLight = GetMainLight();
                half ndl = saturate(dot(n, mainLight.direction)) * 0.5h + 0.5h;

                half3 color = albedo * (gi + mainLight.color * ndl);
                color = MixFog(color, i.fogFactor);
                return half4(color, 1.0h);
            }
            ENDHLSL
        }
    }

    FallBack Off
}
