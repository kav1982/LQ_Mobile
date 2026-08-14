Shader "MMN/BG/WindowGlass"
{
                    Properties
    {
        [Toggle] _IsShadowDitheringPattern ("使用全局抖动图案阴影", Float) = 0
        [Toggle] _ALPHATEST ("Alpha Test", Float) = 0
        [Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
        _RaycastHarftoneClip ("Raycast 半调裁剪", Range(0, 1)) = 0
        _VertexColorWeight ("顶点色影响权重", Range(0, 1)) = 1
        [Toggle] _ShowVertexColor ("显示顶点色（调试）", Float) = 0
        _BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (0.5,0.5,0.5,1)
        _Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
        _SpecColor ("Specular Color", Color) = (10,10,10,1)
        _Smoothness ("SMoothness", Float) = 0.5
        _Gloss ("Glossiness", Range(0, 5)) = 1
        [Enum(outside, 0, inside, 1)] _OutsideInside ("室外/室内", Float) = 0
        _EmissionColorDark ("暗玻璃颜色", Color) = (0,0,0,1)
        _EmissionColorBright ("亮玻璃颜色", Color) = (15,14,4,1)
        _TempNight2DaySwitchTest ("夜→昼转换测试", Range(0, 1)) = 1
        _EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
        _Surface ("__surface", Float) = 0
        _Blend ("__blend", Float) = 0
        _AlphaClip ("__clip", Float) = 0
        _SrcBlend ("__src", Float) = 1
        _DstBlend ("__dst", Float) = 0
        _ZWrite ("__zw", Float) = 1
        [ToogleOff] _ReceiveShadows ("Receive Shadows", Float) = 1
        _QueueOffset ("Queue offset", Float) = 0
        _MainTex ("BaseMap", 2D) = "white" {}
        _Color ("Base Color", Color) = (1,1,1,1)
        _Shininess ("Smoothness", Float) = 0.01
        _GlossinessSource ("GlossinessSource", Float) = 0
        _SpecSource ("SpecularHighlights", Float) = 0
        unity_Lightmaps ("unity_Lightmaps", 2D) = "white" {}
        unity_LightmapsInd ("unity_LightmapsInd", 2D) = "white" {}
        unity_ShadowMasks ("unity_ShadowMasks", 2D) = "white" {}
        _WindMultiply ("Wind Multiply（风细节）", Range(0, 20)) = 2
        _WindSpeedMultiply ("Wind Speed Multiply（风速权重）", Range(0, 40)) = 7
        [Toggle] _ShowVertexAlpha ("显示顶点 Alpha（调试）", Float) = 0
        [Toggle] _VertexAniOn ("开启顶点动画", Float) = 0
        [Toggle] _UseVertexAnimation ("完全关闭顶点动画", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        LOD 200
        Cull [_Cull]
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            TEXTURE2D(_BaseMap); SAMPLER(sampler_BaseMap);
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST; half4 _BaseColor; half _Smoothness; half4 _EmissionColor; half _EmissionIntensity;
            CBUFFER_END
            struct Attr { float4 positionOS:POSITION; float3 normalOS:NORMAL; float2 uv:TEXCOORD0; };
            struct Var { float4 positionCS:SV_POSITION; float2 uv:TEXCOORD0; float3 normalWS:TEXCOORD1; float3 positionWS:TEXCOORD2; };
            Var vert(Attr v){
                Var o; VertexPositionInputs p=GetVertexPositionInputs(v.positionOS.xyz);
                o.positionCS=p.positionCS; o.positionWS=p.positionWS;
                o.normalWS=GetVertexNormalInputs(v.normalOS).normalWS;
                o.uv=TRANSFORM_TEX(v.uv,_BaseMap); return o;
            }
            half4 frag(Var i):SV_Target{
                half4 albedo=SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv)*_BaseColor;
                half3 n=normalize(i.normalWS);
                half3 v=GetWorldSpaceNormalizeViewDir(i.positionWS);
                half fresnel=pow(1-saturate(dot(n,v)), 3);
                Light L=GetMainLight();
                half3 col=albedo.rgb*(SampleSH(n)+L.color*0.3)+_EmissionColor.rgb*_EmissionIntensity;
                col+=fresnel*_Smoothness;
                return half4(col, saturate(albedo.a+fresnel*0.2));
            }
            ENDHLSL
        }
}

    FallBack Off

}
