Shader "MMN/CH/Hair_Shadow" {
	Properties {
		[Header(Base)] [Space(10)] _Color ("색상", Vector) = (0,0,0,1)
		[Enum(Default, 0, Min, 3)] _BlendOp ("최종 블렌드 연산 방식", Float) = 0
		[Header(Dissolve)] [Space(10)] [Toggle(_DISSOLVE_FEATURE)] _IsDissolve ("디졸브 켜기", Float) = 0
		_DissolveAmount ("진행도", Range(0, 2)) = 0
		_DissolveRange ("범위(xyz: 범위, w: 두께)", Vector) = (1,1,1,6)
		[Toggle] _NotUseDirection ("방향 없이 디졸브 할까요?", Float) = 0
		_DissolveDirection ("진행 방향 벡터", Vector) = (0,-1,0,0)
		_DissolvePanningSpeed ("패닝 속도", Range(-1, 1)) = 0
		_DissolveMap ("디졸브 텍스쳐", 2D) = "white" {}
		[Toggle] _DissolveCutoff ("디졸브 컷오프를 켤까요?", Float) = 1
		[HDR] _DissolveColor ("디졸브 색상", Vector) = (0,0,0,0)
		_DissolveWidth ("디졸브 두께", Range(0, 1)) = 0.3
		[HDR] _DissolveEdgeColor ("디졸브 경계의 색상", Vector) = (1,1,1,1)
		_DissolveEdgeWidth ("디졸브 경계의 두께", Range(0, 1)) = 0.05
		[HideInInspector] _RenderMode ("렌더링 모드", Float) = 0
		[HideInInspector] _StencilValue ("_StencilValue", Float) = 0
		[HideInInspector] _CharacterPositionAndHeadHeight ("xyz: position, w: head height", Vector) = (0,0,0,0)
		[HideInInspector] _CharacterHeadDirection ("xyz: direction, w: reserved", Vector) = (0,0,1,1)
		[HideInInspector] _CharacterHeadPosition ("xyz: head world position, w: reserved", Vector) = (0,0,0,0)
		[HideInInspector] _CharacterReceiveShadow ("x: top, y: bottom", Vector) = (0,0,0,0)
		[HideInInspector] _HalftoneClip ("_HalftoneClip", Float) = 0
		[HideInInspector] _CustomLightMode ("_CustomLightMode", Float) = 0
		[HideInInspector] _CustomLightDirection ("_CustomLightDirection", Vector) = (0,0,-1,0)
		[HideInInspector] _CustomLightColor ("_CustomLightColor", Vector) = (1,1,1,1)
		[HideInInspector] _CustomGIColor ("_CustomGIColor", Vector) = (0.768,0.827,0.854,1)
		[HideInInspector] _EffectTint ("_EffectTint", Vector) = (0,0,0,0)
		[HideInInspector] _InnerGlow ("_InnerGlow", Float) = 0
		[HideInInspector] _InnerGlowPower ("_InnerGlowPower", Float) = 0
		[HideInInspector] _InnerGlowColor ("_InnerGlowColor", Vector) = (0,0,0,0)
		[HideInInspector] _EffectAlphaValue ("_EffectAlphaValue", Float) = 1
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

			struct Vertex_Stage_Input
			{
				float4 pos : POSITION;
			};

			struct Vertex_Stage_Output
			{
				float4 pos : SV_POSITION;
			};

			Vertex_Stage_Output vert(Vertex_Stage_Input input)
			{
				Vertex_Stage_Output output;
				output.pos = mul(unity_MatrixVP, mul(unity_ObjectToWorld, input.pos));
				return output;
			}

			float4 _Color;

			float4 frag(Vertex_Stage_Output input) : SV_TARGET
			{
				return _Color; // RGBA
			}

			ENDHLSL
		}
	}
	//CustomEditor "MM.Client.Editor.ShaderGUI.CharacterCommonShaderGUI"
}