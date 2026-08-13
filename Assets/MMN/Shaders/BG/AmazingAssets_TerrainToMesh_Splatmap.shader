// Recreation of the shipped "Amazing Assets/Terrain To Mesh/Splatmap", the shader on
// Colhen_Land_Terrain_00_Splatmap - the sand/cliff terrain of the Colhen beach after the terrain
// was baked down to mesh tiles.
//
// Property list, SubShader/pass structure, tags and render states are 1:1 with the extracted
// contract (_re_work/shader_contracts/AmazingAssets_TerrainToMesh_Splatmap.contract.json): 48
// properties, two SubShaders (LOD 300 / LOD 100) with four shipped passes each - ForwardLit
// (LightMode "BG"), DepthOnly, SSAODepthOnly, ImpactFramePrePass - plus a URP-only DepthNormals
// pass (see below). RenderType Opaque, UniversalMaterialType SimpleLit, Blend [_SrcBlend]
// [_DstBlend], ZWrite [_ZWrite], Cull [_Cull]. Note there is no ShadowCaster pass in the shipped
// shader, so the terrain does not cast shadows; that is kept.
//
// The extra DepthNormals pass is not in the shipped shader. URP's SSAO (Source = DepthNormals)
// and Scene-view depth copy both draw LightMode "DepthNormals" / "DepthNormalsOnly" into
// _CameraDepthTexture. The game used "SSAODepthOnly" for the same job; without the URP tag the
// beach is missing from the depth texture and PlanarReflectionWater's shore foam / scatter ramp
// sees infinite depth, which is the hard waterline.
//
// Two things the shipped uniform table / D3D11 program settle, which is why the code below looks
// the way it does:
//  - _BaseMap / _BumpMap / _SpecGlossMap are never sampled (only _BaseMap_ST and _BaseColor show
//    up as uniforms). They are leftovers of the SimpleLit template the shader was built from. All
//    of the terrain colour comes from the four _T2M_Layer_*_Diffuse layers and _T2M_SplatMap_0,
//    even though the Colhen material does assign a baked basemap to _BaseMap.
//  - _Glossiness / _SpecColor / _SpecularHighlights are also leftovers: the dry-path pixel shader
//    never loads them. Direct spec is wrap Lambert (lerp(NdotL, half-Lambert, 0.5)); cubemap IBL
//    only mixes in under _Global_Raining. No shadow map; contact areas are dimmed by
//    _Global_ContactShadowStrength instead.
//
// LightMode "BG" is the game's own opaque tag, not one of URP's, so a RenderObjects renderer
// feature filtering on "BG" has to exist or nothing draws. MMN/BeachPreview/Editor sets that up.
//
// NOT-IMPLEMENTED: the _Global_Sky*/_Global_Sun*/_Global_Cloud*/_Global_Night2Day/_Global_Raining/
//                  _Global_Snow/_Global_Wind*/_Global_MiniGBuffer*/_Global_ContactShadowStrength
//                  uniforms - the game's time-of-day, weather and ambient systems.
// NOT-IMPLEMENTED: the snow layer (_SnowMask_R/G/B/A pick which splat channels take snow) and the
//                  snow sparkling set; they need _Global_Snow to be driven.
// NOT-IMPLEMENTED: _ImpactFrameFocusWorldPosition and the ImpactFramePrePass body (a game-specific
//                  hit-frame effect); the pass exists so the pass table matches, but writes depth
//                  only.
//
// Two oddities below are the shipped shader's own and are kept verbatim: [PowerSlider] on
// _Glossiness carries no argument, so Unity logs "Failed to create material drawer PowerSlider",
// and _ReceiveShadows is tagged [ToogleOff] - a typo for ToggleOff that Unity silently ignores.
Shader "Amazing Assets/Terrain To Mesh/Splatmap"
{
    Properties
    {
        [Space] [NoScaleOffset] _T2M_SplatMap_0 ("Splat Map #10 (RGBA)", 2D) = "black" {}
        [NoScaleOffset] _T2M_Layer_0_Diffuse ("Paint Map 1 (R)", 2D) = "white" {}
        [NoScaleOffset] _T2M_Layer_1_Diffuse ("Paint Map 1 (R)", 2D) = "white" {}
        [NoScaleOffset] _T2M_Layer_2_Diffuse ("Paint Map 2 (G)", 2D) = "white" {}
        [NoScaleOffset] _T2M_Layer_3_Diffuse ("Paint Map 3 (B)", 2D) = "white" {}
        [HideInInspector] [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)
        _V_T2M_Splat1_uvScale ("Layer 1 UV Scale", Float) = 1
        _V_T2M_Splat2_uvScale ("Layer 2 UV Scale", Float) = 1
        _V_T2M_Splat2_Vector1 ("Float", Range(-0.9, 2.9)) = 1
        _V_T2M_Splat2_Vector2 ("Float", Range(-0.9, 2.9)) = 1
        [Gamma] _V_T2M_Splat2_EdgeColor ("交界颜色相乘", Color) = (0.45,0.45,0.45,1)
        _V_T2M_Splat3_uvScale ("Layer 3 UV Scale", Float) = 1
        _V_T2M_Splat3_Vector1 ("Float", Range(-1.9, 1.9)) = 1
        _V_T2M_Splat3_Vector2 ("Float", Range(-1.9, 1.9)) = 1
        [Gamma] _V_T2M_Splat3_EdgeColor ("交界颜色相乘", Color) = (0.45,0.45,0.45,1)
        _V_T2M_Splat4_uvScale ("Layer 4 UV Scale", Float) = 1
        _V_T2M_Splat4_Vector1 ("Float", Range(-2, 1.9)) = 1
        _V_T2M_Splat4_Vector2 ("Float", Range(-2, 1.9)) = 1
        [Gamma] _V_T2M_Splat4_EdgeColor ("交界颜色相乘", Color) = (0.45,0.45,0.45,1)
        [Toggle] _SnowMask_R ("SnowMask_R", Float) = 0
        [Toggle] _SnowMask_G ("SnowMask_G", Float) = 0
        [Toggle] _SnowMask_B ("SnowMask_B", Float) = 0
        [Toggle] _SnowMask_A ("SnowMask_A", Float) = 0
        [Toggle] _IsSnowSparkling ("IsSnowSparkling", Float) = 0
        [NoScaleOffset] _SnowSparklingMap ("SnowSparklingMap", 2D) = "black" {}
        _SnowSparklingIntensity ("SnowSparkling Intensity", Range(0, 20)) = 5
        _SnowSparklingSpecularIntensity ("SnowSparkling Specular Intensity", Range(0, 5)) = 2
        _SnowSparklingTiling ("SnowSparkling Tiling", Vector) = (0.5,0.5,0.1,0.1)
        _SnowSparklingNormalStep ("SnowSparklingNormalStep", Range(0, 1)) = 0.5
        [HideInInspector] _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [HideInInspector] _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        [HDR] _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
        [PowerSlider] _Glossiness ("Smoothness", Range(0.01, 1)) = 0.5
        [HideInInspector] _SpecGlossMap ("Specular Map", 2D) = "white" {}
        [Enum(Specular Alpha, 0, Albedo Alpha, 1)] [HideInInspector] _SmoothnessSource ("Smoothness Source", Float) = 0
        [ToggleOff] [HideInInspector] _SpecularHighlights ("Specular Highlights", Float) = 1
        [HideInInspector] _BumpScale ("Scale", Float) = 1
        [HideInInspector] [NoScaleOffset] _BumpMap ("Normal Map", 2D) = "bump" {}
        [HideInInspector] _Surface ("__surface", Float) = 0
        [HideInInspector] _Blend ("__blend", Float) = 0
        [HideInInspector] _AlphaClip ("__clip", Float) = 0
        [HideInInspector] _SrcBlend ("__src", Float) = 1
        [HideInInspector] _DstBlend ("__dst", Float) = 0
        [HideInInspector] _ZWrite ("__zw", Float) = 1
        [HideInInspector] _Cull ("__cull", Float) = 2
        [ToogleOff] [HideInInspector] _ReceiveShadows ("Receive Shadows", Float) = 1
        [HideInInspector] _QueueOffset ("Queue offset", Float) = 0
        [HideInInspector] _Smoothness ("SMoothness", Float) = 0.5
    }

    SubShader
    {
        LOD 300
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "true"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "BG" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapVertex
            #pragma fragment SplatmapFragment
            #pragma multi_compile_fog
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthVertex
            #pragma fragment SplatmapDepthFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SSAODepthOnly"
            Tags { "LightMode" = "SSAODepthOnly" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthNormalsVertex
            #pragma fragment SplatmapDepthNormalsFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        // URP equivalent of SSAODepthOnly. Kept as a separate pass so the shipped LightMode table
        // stays intact while _CameraDepthTexture still contains the beach.
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthNormalsVertex
            #pragma fragment SplatmapDepthNormalsFragment
            #define MMN_URP_DEPTH_NORMALS
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ImpactFramePrePass"
            Tags { "LightMode" = "ImpactFramePrePass" }

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthVertex
            #pragma fragment SplatmapDepthFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }
    }

    SubShader
    {
        LOD 100
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "SimpleLit"
            "IgnoreProjector" = "true"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "BG" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapVertex
            #pragma fragment SplatmapFragment
            #pragma multi_compile_fog
            #define MMN_T2M_LOW
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthVertex
            #pragma fragment SplatmapDepthFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SSAODepthOnly"
            Tags { "LightMode" = "SSAODepthOnly" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthNormalsVertex
            #pragma fragment SplatmapDepthNormalsFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        // URP equivalent of SSAODepthOnly. Kept as a separate pass so the shipped LightMode table
        // stays intact while _CameraDepthTexture still contains the beach.
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            ZTest LEqual
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthNormalsVertex
            #pragma fragment SplatmapDepthNormalsFragment
            #define MMN_URP_DEPTH_NORMALS
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "ImpactFramePrePass"
            Tags { "LightMode" = "ImpactFramePrePass" }

            ZWrite On
            ZTest LEqual
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex SplatmapDepthVertex
            #pragma fragment SplatmapDepthFragment
            #include "../Include/MMN_T2M_Splatmap.hlsl"
            ENDHLSL
        }
    }

    // The shipped shader points CustomEditor at MM.Client.Editor.ShaderGUI.MMN_TerrainMeshGUI,
    // which is not part of the extracted data; left out so Unity does not error per material.
    FallBack Off
}
