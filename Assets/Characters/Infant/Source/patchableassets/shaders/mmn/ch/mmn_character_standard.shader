Shader "MMN/CH/Standard" {
	Properties {
		[Enum(Standard, 0, Monster, 1, Deep, 2)] _ShadingType ("셰딩 타입", Float) = 0
		[Enum(BackCull, 2, FrontCull, 1, TwoSide, 0)] _CullType ("컬링 타입", Float) = 2
		[Toggle] _ZWrite ("깊이 정보 쓰기(TA팀 문의 필요)", Float) = 1
		[Header(Texture)] [Space(10)] _BaseMap ("베이스 맵", 2D) = "white" {}
		_TintColor ("틴트 색상", Vector) = (1,1,1,1)
		_AlphaOverride ("투명도", Range(0, 1)) = 1
		_AlphaScaleMin ("투명도 Min", Range(0, 1)) = 0
		_AlphaScaleMax ("투명도 Max", Range(0, 1)) = 1
		[Toggle] _IsGradientAlpha ("그라데이션 알파 모드", Float) = 0
		_GradientAlphaHeight ("그라데이션 알파 높이(0이면 자동)", Range(0, 10)) = 1.4
		_BackFaceDarkenAmount ("(TwoSide일 때) 뒷면의 밝기", Range(0, 1)) = 0.5
		[Toggle] _IsDyable ("염색 마스크 포함?", Float) = 0
		[Header(Accessory)] [Space(10)] [NoScaleOffset] _AccessoryMap1 ("액세서리 맵1", 2D) = "black" {}
		[NoScaleOffset] _AccessoryMap2 ("액세서리 맵2", 2D) = "black" {}
		[Toggle(_ACCESSORY_MAP_PREVIEW)] _AccessoryMapPreview ("액세서리 맵 영역 설정 (확인용)", Float) = 0
		_AccessoryMapTransform1 ("맵1 xy: 오프셋, z: 종횡비 w: 스케일", Vector) = (0,0,1,1)
		_AccessoryMapTransform2 ("맵2 xy: 오프셋, z: 종횡비 w: 스케일", Vector) = (0,0,1,1)
		[Header(Dye Color)] [Space(10)] _DyeColor1 ("염색 슬롯 1", Vector) = (1,1,1,1)
		_DyeColor2 ("염색 슬롯 2", Vector) = (1,1,1,1)
		_DyeColor3 ("염색 슬롯 3", Vector) = (1,1,1,1)
		[Header(Shading)] [Space(10)] _FlatShadingAmountTop ("플랫함 정도 (상단) 0=볼륨, 1=플랫", Range(0, 1)) = 1
		_FlatShadingAmountBottom ("플랫함 정도 (하단) 0=볼륨, 1=플랫", Range(0, 1)) = 0
		_ReceiveShadowStrength ("실시간 그림자 강도", Range(0, 1)) = 1
		[Header(LowerGradientColor)] [Space(10)] _LowerGradientColor ("하단 그라데이션 색상", Vector) = (1,1,1,1)
		_LowerGradientHeight ("하단 그라데이션 높이", Range(0.01, 3)) = 1
		_LowerGradientPower ("하단 그라데이션 파워", Range(1, 10)) = 2
		_LowerGradientOffset ("하단 그라데이션 오프셋", Range(-5, 5)) = 0
		[Header(Silhouette)] [Space(10)] [Toggle] _SilhouetteOff ("실루엣 끄기", Float) = 0
		_SilhouetteTintColor ("실루엣 틴트", Vector) = (1,1,1,1)
		[Header(Outline)] [Space(10)] [Toggle] _OutlineOff ("아웃라인 끄기", Float) = 0
		_OutlineColor ("아웃라인 색상", Vector) = (1,1,1,1)
		[Enum(Multiply, 0, Override, 1)] _OutlineColorMode ("아웃라인 색상 적용 방식", Float) = 0
		[Header(Metal or Leather)] [Space(10)] [Toggle(_MASK_CHANNEL_PREVIEW)] _MaskChannelPreview ("메탈/가죽 마스킹 채널(A) 보기 (확인용)", Float) = 0
		[Space(10)] [Toggle(_METAL_FEATURE)] _IsMetal ("메탈 재질?", Float) = 0
		_Smoothness ("매끈한 정도", Range(0.01, 1)) = 1
		[Space(10)] [Toggle(_LEATHER_FEATURE)] _IsLeather ("가죽 재질?", Float) = 0
		_LeatherSmoothness ("매끈한 정도", Range(0, 1)) = 0.5
		[Header(Gem)] [Space(10)] [Toggle(_GEM_FEATURE)] _IsGem ("보석 재질?", Float) = 0
		[NoScaleOffset] _GemInclusionMap ("균열 맵", 2D) = "white" {}
		_GemInclusionMapTilingX ("균열 맵 타일링 X", Float) = 1
		_GemInclusionMapTilingY ("균열 맵 타일링 Y", Float) = 1
		[Space(10)] _GemBaseColorStrength ("베이스(염색) 밝기", Range(0, 2)) = 0.5
		_GemReflectionGloss ("반사맵 흐림 정도", Range(0, 1)) = 0
		[HideInInspector] _GemDarkColorReflection ("어두운 색의 반사 강도", Range(0, 1)) = 0.2
		[HideInInspector] _GemBrightColorReflection ("밝은 색의 반사 강도", Range(0, 1)) = 0.4
		[Space(10)] [NoScaleOffset] _GemMatCapMap ("MatCap 반사 맵", 2D) = "white" {}
		_GemMatCapScale ("MatCap 타일링", Range(1, 10)) = 1
		_GemMatCapIntensity ("MatCap 강도", Float) = 1
		[Space(10)] _GemMatCapBlend ("반사 블렌드 (0=반사만, 1=MatCap만)", Range(0, 1)) = 0.5
		[Header(Emission)] [Space(10)] [NoScaleOffset] _EmissionMap ("이미션 맵", 2D) = "black" {}
		[Header(Emission R Channel)] [HDR] _EmissionColor ("이미션 컬러 (R)", Vector) = (0,0,0,1)
		_EmissionIntensity ("이미션 강도 (R)", Range(0, 10)) = 1
		[Toggle] _IsApplyFogToEmission ("안개에 영향을 받나?", Float) = 1
		_ApplyFogToEmissionFactor ("안개에 영향을 받을 정도", Range(0, 1)) = 1
		[Toggle] _IsEnableEmissionAtNight ("밤에만 활성화?", Float) = 0
		[Toggle] _IsBreathingEmissionMode ("숨쉬기 모드 활성화?", Float) = 0
		_BreathingEmissionMinBright ("숨쉬기 모드 시 최소 밝기", Range(0, 1)) = 0.16
		_BreathingEmissionModePeriod ("전체가 깜빡이는 시간 (0 이면 안깜빡임)", Float) = 0
		_EmissionNoiseSpeed ("숨쉬기 노이즈 맵이 흐르는 속도", Range(-3, 3)) = -0.18
		_EmissionNoiseMap ("숨쉬기 노이즈 맵", 2D) = "white" {}
		[Header(Emission G Channel)] [HDR] _EmissionColorG ("이미션 컬러 (G - 연출 전용)", Vector) = (0,0,0,1)
		[Header(Emission B Channel)] [HDR] _EmissionColorB ("이미션 컬러 (B - 연출 전용)", Vector) = (0,0,0,1)
		[Header(Override Color)] [Space(10)] [HDR] _OverrideColor ("오버라이드 컬러", Vector) = (0,0,0,1)
		_OverrideColorRatio ("오버라이드 비율", Range(0, 1)) = 0
		[Header(Fresnel)] [Space(10)] _FresnelColor ("프레넬 컬러", Vector) = (0,0,0,1)
		[PowerSlider(2)] _FresnelRange ("프레넬 범위", Range(0, 10)) = 2
		[PowerSlider(2)] _FresnelPower ("프레넬 파워", Range(0, 20)) = 10
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
		[Header(Clone Effect)] [Space(10)] [Toggle(_CLONE_EFFECT_FEATURE)] _UseCloneEffect ("분신 효과 적용", Float) = 0
		_CloneEffectColor ("분신 효과 색상", Vector) = (0.249984,0.4522104,0.504,1)
		_WobbleStrength ("분신 일렁임 강도", Range(0, 0.5)) = 0.2
		_WobbleSpeed ("분신 일렁임 속도", Range(0, 5)) = 2
		[Header(VertexColor)] [Space(10)] _VertexColorAmount ("버텍스 칼라 강도", Range(0, 1)) = 0
		[Header(Side Clip)] [Space(10)] [Enum(None, 0, Left, 1, Right, 2)] _SideClipHide ("숨길 방향", Float) = 0
		[HideInInspector] _RenderMode ("렌더링 모드", Float) = 0
		[HideInInspector] _StencilValue ("_StencilValue", Float) = 0
		[HideInInspector] _DepthColorMask ("_DepthColorMask", Float) = 15
		[HideInInspector] _ClothWetProgress ("Cloth Wet Progress", Range(0, 1)) = 0
		[HideInInspector] _LegsWetProgress ("Legs Wet Progress", Range(0, 1)) = 0
		[HideInInspector] _ObjectMotionBlurTopPositionWS ("_ObjectMotionBlurTopPositionWS", Vector) = (0,0,0,0)
		[HideInInspector] _ObjectMotionBlurTopVelocityWS ("_ObjectMotionBlurTopVelocityWS", Vector) = (0,0,0,0)
		[HideInInspector] _ObjectMotionBlurPivotPositionWS ("_ObjectMotionBlurPivotPositionWS", Vector) = (0,0,0,0)
		[HideInInspector] _ObjectMotionBlurLengthFactors ("_ObjectMotionBlurLengthFactors", Vector) = (0,0,0,0)
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
		Tags { "RenderType" = "Opaque" }
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

			float4 frag(Vertex_Stage_Output input) : SV_TARGET
			{
				return float4(1.0, 1.0, 1.0, 1.0); // RGBA
			}

			ENDHLSL
		}
	}
	//CustomEditor "MM.Client.Editor.ShaderGUI.CharacterCommonShaderGUI"
}