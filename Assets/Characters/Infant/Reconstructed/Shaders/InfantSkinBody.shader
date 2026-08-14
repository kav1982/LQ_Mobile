Shader "Characters/Infant/Reconstructed/SkinBody"
{
    Properties
    {
        [Header(Skin Texture)] _BaseMap ("Skin Dye Map", 2D) = "white" {}
        _TintColor ("Skin Tint", Color) = (1,1,1,1)
        _AlphaOverride ("Alpha", Range(0,1)) = 1
        [Toggle] _IsDyable ("Decode Skin Dye Map", Float) = 1
        [Header(Skin Colors)] _DyeColor1 ("Primary Skin Color", Color) = (1,1,1,1)
        _DyeColor2 ("Secondary Skin Color", Color) = (1,1,1,1)
        _DyeColor3 ("Detail Skin Color", Color) = (1,1,1,1)
        [Header(Tattoo)] _TattooMap ("Tattoo / Scar", 2D) = "black" {}
        _TattooMapScalePosition ("Tattoo Scale Position", Vector) = (1,1,0,0)
        [Header(Shading)] _FlatShadingAmountTop ("Top Flat Shading", Range(0,1)) = 1
        _FlatShadingAmountBottom ("Bottom Flat Shading", Range(0,1)) = 0
        _ReceiveShadowStrength ("Receive Shadow", Range(0,1)) = 1
        [HideInInspector] _CullType ("Cull", Float) = 2
        [HideInInspector] _ZWrite ("Z Write", Float) = 1
        [HideInInspector] _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.01
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" }
        UsePass "Characters/Infant/Reconstructed/Standard/Forward"
    }
}
