Shader "MMN/BG/SimpleLit" {
	Properties {
		[Toggle] _IsShadowDitheringPattern ("글로벌 디더링 패턴 그림자를 사용한다", Float) = 0
		_ContactShadowIntensity ("컨텍트 셰도우 강도", Range(0, 1)) = 1
		[Toggle] _NEARHALFTONECLIP ("니어 클립", Float) = 0
		[Toggle] _ALPHATEST ("알파테스트", Float) = 0
		[Enum(off, 0, front, 1, back, 2)] _Cull ("BackfaceCull", Float) = 2
		[Toggle] _BackFaceNormalturn ("백페이스 노말을 돌려서 뒷면도 노말을 앞으로 생성한다", Float) = 0
		[PerRendererData] _RaycastHarftoneClip ("레이케스트 하프톤 클립", Range(0, 1)) = 0
		_VertexColorWeight ("버텍스 칼라 영향력 가중치", Range(0, 1)) = 1
		[Toggle] _ShowVertexColor ("Show Vertex Color(확인용)", Float) = 0
		_BaseMap ("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
		_BaseColor ("Base Tint", Vector) = (1,1,1,1)
		_AlbedoTintStrength ("Albedo Tint Strength", Range(-1, 1)) = 0
		_ShadowDim ("ShadowDimming(그림자 영향력 조절)", Range(0, 1)) = 0
		_Cutoff ("Alpha Clipping", Range(0, 1)) = 0.5
		[HDR] _SpecColor ("Specular Color", Vector) = (0,0,0,0)
		_Smoothness ("Smoothness", Range(0, 1)) = 0
		_Gloss ("Glossiness", Range(0.01, 5)) = 1
		_SpecGlossMap ("Specular Map", 2D) = "white" {}
		_SmoothnessSource ("Smoothness Source", Float) = 0
		_SpecularHighlights ("Specular Highlights", Float) = 1
		[HDR] _EmissionColor ("Emission Color", Vector) = (0,0,0,1)
		[NoScaleOffset] _EmissionMap ("Emission Map", 2D) = "white" {}
		_EmissionIntensity ("Emission Intensity", Range(0, 10)) = 1
		[Enum(Always, 0, NightOnly, 1, DayOnly, 2)] _Night2DayEnum ("언제 Emission이 켜지게 할까요", Float) = 0
		[Enum(None, 0, Uniform, 1, Smooth, 2, Step, 3)] _EmissionFlickerMode ("이미션 깜빡이는 모드", Float) = 0
		_EmissionFlickerMin ("이미션 깜빡이는 최소 강도", Range(0, 1)) = 0.5
		_EmissionFlickerMax ("이미션 깜빡이는 최대 강도", Range(1, 10)) = 2
		_EmissionFlickerFrequency ("이미션 깜빡이는 주기(속도)", Float) = 6
		[NoScaleOffset] _EmissionFlickerNoise ("이미션 깜빡이는 노이즈", 2D) = "gray" {}
		[Enum(UV, 0, Position_XZ, 1, Position_XY, 2, Triplanar, 3)] _EmissionFlickerNoiseUV ("이미션 깜빡이는 노이즈 UV", Float) = 0
		_EmissionFlickerNoiseScale ("이미션 깜빡이는 노이즈의 스케일", Float) = 1
		_EmissionFlickerNoiseSpeed ("이미션 깜빡이는 노이즈의 속도(XY)", Vector) = (0.1,0.1,0,0)
		_EmissionFlickerNoiseCellCount ("이미션 깜빡이는 노이즈의 셀 수", Float) = 16
		[Toggle] _EmissionFlickerDEBUG ("이미션 깜빡이는 노이즈만 보기(확인용)", Float) = 0
		_halfLambertWeight ("halfLambertWeight", Range(0, 1)) = 0
		[Toggle] _BackfaceReceiveShadowOff ("백페이스 리시브 셰도우 끄기", Float) = 0
		_QueueOffset ("Queue offset", Float) = 0
		[HideInInspector] _MainTex ("BaseMap", 2D) = "white" {}
		[HideInInspector] _Color ("Base Color", Vector) = (1,1,1,1)
		[HideInInspector] _Shininess ("Smoothness", Float) = 0
		[HideInInspector] _GlossinessSource ("GlossinessSource", Float) = 0
		[HideInInspector] _SpecSource ("SpecularHighlights", Float) = 0
		[HideInInspector] [NoScaleOffset] unity_Lightmaps ("unity_Lightmaps", 2DArray) = "" {}
		[HideInInspector] [NoScaleOffset] unity_LightmapsInd ("unity_LightmapsInd", 2DArray) = "" {}
		[HideInInspector] [NoScaleOffset] unity_ShadowMasks ("unity_ShadowMasks", 2DArray) = "" {}
		[Toggle] _IsRaindrop ("빗방울이 떨어질까요?/ 눈이 쌓일까요?", Float) = 1
		[Toggle] _VertexAniOn ("버텍스 애니를 켠다", Float) = 1
		_WindMultiply ("Wind Multiply(바람 디테일)", Range(0, 20)) = 2
		_WindSpeedMultiply ("Wind Speed Multiply(바람 속도 가중치)", Range(0, 40)) = 7
		[Toggle] _ShowVertexAlpha ("Show Vertex Alpha(확인용)", Float) = 0
		[Toggle] _UseVertexAnimation ("버텍스 애니 기능 통채로 끄기", Float) = 0
		[Header(Stencil Options)] [Space] _StencilRef ("Stencil Ref", Float) = 0
		[MaterialEnum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comp", Float) = 0
		[MaterialEnum(UnityEngine.Rendering.StencilOp)] _StencilPass ("Stencil Pass", Float) = 0
		[Toggle] _IsSnowSparkling ("IsSnowSparkling", Float) = 0
		[NoScaleOffset] _SnowSparklingMap ("SnowSparklingMap", 2D) = "black" {}
		_SnowSparklingIntensity ("SnowSparkling Intensity", Range(0, 20)) = 5
		_SnowSparklingSpecularIntensity ("SnowSparkling Specular Intensity", Range(0, 5)) = 2
		_SnowSparklingTiling ("SnowSparkling Tiling", Vector) = (0.5,0.5,0.1,0.1)
		_SnowSparklingNormalStep ("SnowSparklingNormalStep", Range(0, 1)) = 0.5
	}
	//DummyShaderTextExporter
	SubShader{
		Tags { "RenderType"="Opaque" }
		LOD 200

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4x4 unity_ObjectToWorld;
			float4x4 unity_MatrixVP;
			float4 _MainTex_ST;

			struct Vertex_Stage_Input
			{
				float4 pos : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct Vertex_Stage_Output
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
			};

			Vertex_Stage_Output vert(Vertex_Stage_Input input)
			{
				Vertex_Stage_Output output;
				output.uv = (input.uv.xy * _MainTex_ST.xy) + _MainTex_ST.zw;
				output.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, input.pos));
				return output;
			}

			Texture2D<float4> _MainTex;
			SamplerState sampler_MainTex;
			float4 _Color;

			struct Fragment_Stage_Input
			{
				float2 uv : TEXCOORD0;
			};

			float4 frag(Fragment_Stage_Input input) : SV_TARGET
			{
				return _MainTex.Sample(sampler_MainTex, input.uv.xy) * _Color;
			}

			ENDHLSL
		}
	}
	//CustomEditor "MM.Client.Editor.ShaderGUI.MMN_SimpleLitGUI"
}