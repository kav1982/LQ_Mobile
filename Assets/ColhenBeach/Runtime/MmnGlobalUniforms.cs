using UnityEngine;

namespace ColhenBeach
{
    /// <summary>
    /// Feeds the _Global_* uniforms that MMN/Special/PlanarReflectionWater reads for its MiniGBuffer
    /// sky path (sky gradient, sun disk/glow, light luminance). In the game these come from the
    /// town's time-of-day system, which was not extracted; the values here are matched by eye to
    /// the reference capture (hazy midday, sun high in the south-west) and are meant to be tuned
    /// in the Inspector.
    ///
    /// Unset shader globals read as zero, which would make the sky term black and the MiniGBuffer
    /// box weight zero (falling through to the URP probe path), so this has to be present in any
    /// scene that draws the water.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class MmnGlobalUniforms : MonoBehaviour
    {
        [Header("Ambient")]
        public Color giLightMulti = Color.white;

        [Header("Sky gradient (by reflected Y)")]
        public Color skyColorTop = new Color(0.35f, 0.55f, 0.85f);
        public Color skyColorMiddle = new Color(0.60f, 0.75f, 0.90f);
        public Color skyColorBottom = new Color(0.80f, 0.85f, 0.90f);
        [Tooltip("Bottom -> Middle ramp over reflected Y in [Position1, Position2].")]
        public float skyPosition1 = -0.05f;
        public float skyPosition2 = 0.15f;
        [Tooltip("Middle -> Top ramp over reflected Y in [Position3, Position4].")]
        public float skyPosition3 = 0.15f;
        public float skyPosition4 = 0.70f;

        [Header("Sun")]
        public float sunDisk = 0.05f;
        public float sunGlowDisk = 0.5f;
        public Color sunGlowColor = new Color(1f, 0.9f, 0.7f);
        [Range(0f, 1f)] public float night2Day = 1f;

        [Header("MiniGBuffer box")]
        [Tooltip("World-space box inside which the procedural sky replaces the reflection probe.")]
        public Vector3 boxMin = new Vector3(-2000f, -500f, -2000f);
        public Vector3 boxMax = new Vector3(2000f, 500f, 2000f);
        public float boxBlendDistance = 50f;
        [Range(0f, 1f)] public float effectiveWeight = 1f;

        void OnEnable() { Apply(); }
        void OnValidate() { Apply(); }
        void Update() { Apply(); }

        void Apply()
        {
            Shader.SetGlobalColor("_Global_GILightMulti", giLightMulti);
            Shader.SetGlobalColor("_Global_SkyColorTop", skyColorTop);
            Shader.SetGlobalColor("_Global_SkyColorMiddle", skyColorMiddle);
            Shader.SetGlobalColor("_Global_SkyColorBottom", skyColorBottom);
            Shader.SetGlobalFloat("_Global_SkyPosition1", skyPosition1);
            Shader.SetGlobalFloat("_Global_SkyPosition2", skyPosition2);
            Shader.SetGlobalFloat("_Global_SkyPosition3", skyPosition3);
            Shader.SetGlobalFloat("_Global_SkyPosition4", skyPosition4);
            Shader.SetGlobalFloat("_Global_SunDisk", sunDisk);
            Shader.SetGlobalFloat("_Global_SunGlowDisk", sunGlowDisk);
            Shader.SetGlobalColor("_Global_SunGlowColor", sunGlowColor);
            Shader.SetGlobalFloat("_Global_Night2Day", night2Day);
            Shader.SetGlobalVector("_Global_MiniGBuffer_BoxMin", boxMin);
            Shader.SetGlobalVector("_Global_MiniGBuffer_BoxMax",
                new Vector4(boxMax.x, boxMax.y, boxMax.z, boxBlendDistance));
            Shader.SetGlobalFloat("_Global_MiniGBuffer_Effective_Weight", effectiveWeight);
        }
    }
}
