using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace TirChonaill
{
    /// <summary>
    /// Builds the lighting/backdrop rig for the preview scene. The importer only lays out
    /// prefabs, so without this the scene has no ground at all and everything below the
    /// horizon is the procedural skybox's flat grey lower hemisphere.
    /// </summary>
    public static class TirChonaillPreviewEnvironment
    {
        const string Root = "Assets/TirChonaill";
        const string EnvRootName = "Environment";
        const string ForeignRootName = "_Foreign_NonTirChonaill";

        static readonly string[] ForeignTokens = { "Dungeon_", "Fiodh_" };

        [MenuItem("Tools/TirChonaill/Setup Preview Environment")]
        public static void Setup()
        {
            EnsureFolder(Root + "/Settings");
            EnsureFolder(Root + "/Materials");

            var env = ResetEnvRoot();
            var bounds = MeasureContent();

            BuildGround(env, bounds);
            var sky = BuildSkyMaterial();
            ConfigureAmbient(sky);
            ConfigureSun(env);
            BuildPostFX(env);
            ConfigureCamera(bounds);
            EnableHdrColorGrading();

            EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
            EditorSceneManager.SaveOpenScenes();
            AssetDatabase.SaveAssets();

            Debug.Log($"[TirChonaill] Preview environment ready. content bounds={bounds.size}");
        }

        static GameObject ResetEnvRoot()
        {
            var existing = GameObject.Find(EnvRootName);
            if (existing != null) Object.DestroyImmediate(existing);
            return new GameObject(EnvRootName);
        }

        /// <summary>Bounds of the laid-out prefabs, ignoring the props we are about to hide.</summary>
        static Bounds MeasureContent()
        {
            bool any = false;
            var b = new Bounds(Vector3.zero, Vector3.zero);
            foreach (var mr in Object.FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None))
            {
                if (!mr.enabled || IsForeign(mr.transform)) continue;
                if (!any) { b = mr.bounds; any = true; }
                else b.Encapsulate(mr.bounds);
            }
            if (!any) b = new Bounds(Vector3.zero, new Vector3(100, 10, 100));
            return b;
        }

        static void BuildGround(GameObject env, Bounds content)
        {
            var mat = new Material(Shader.Find("MMN/BG/SimpleLit")) { name = "Preview_Ground" };
            float extent = Mathf.Max(content.size.x, content.size.z) * 1.8f + 60f;

            // Untextured on purpose. The preview grid spreads content over ~1200 units, so any
            // tileable ground texture repeats hundreds of times and the grid becomes the most
            // eye-catching thing on screen. A muted field keeps attention on the assets.
            mat.SetTexture("_BaseMap", Texture2D.whiteTexture);
            mat.SetTextureScale("_BaseMap", Vector2.one);
            mat.SetColor("_BaseColor", new Color(0.45f, 0.50f, 0.36f, 1f));
            // The ground is the largest surface on screen, so it needs a lit-side rolloff and a
            // floor value in shadow, otherwise it reads as either blown out or flat ambient.
            mat.SetFloat("_halfLambertWeight", 0.35f);
            mat.SetFloat("_ShadowDim", 0.28f);
            mat.SetFloat("_SpecularHighlights", 0f);
            SaveMaterial(mat, Root + "/Materials/Preview_Ground.mat");

            var go = GameObject.CreatePrimitive(PrimitiveType.Plane);
            go.name = "Ground";
            go.transform.SetParent(env.transform);
            go.transform.position = new Vector3(content.center.x, -0.02f, content.center.z);
            go.transform.localScale = Vector3.one * (extent / 10f);
            go.GetComponent<MeshRenderer>().sharedMaterial =
                AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Preview_Ground.mat");
            var col = go.GetComponent<MeshCollider>();
            if (col != null) Object.DestroyImmediate(col);
        }

        static Material BuildSkyMaterial()
        {
            var mat = new Material(Shader.Find("Skybox/Procedural")) { name = "Preview_Sky" };
            mat.SetFloat("_SunDisk", 2f);
            mat.SetFloat("_SunSize", 0.035f);
            mat.SetFloat("_SunSizeConvergence", 6f);
            mat.SetFloat("_AtmosphereThickness", 0.85f);
            mat.SetColor("_SkyTint", new Color(0.48f, 0.62f, 0.82f));
            // Matches the lit ground plane so the horizon seam does not read as a grey band.
            mat.SetColor("_GroundColor", new Color(0.38f, 0.42f, 0.30f));
            mat.SetFloat("_Exposure", 1.15f);
            SaveMaterial(mat, Root + "/Materials/Preview_Sky.mat");

            var saved = AssetDatabase.LoadAssetAtPath<Material>(Root + "/Materials/Preview_Sky.mat");
            RenderSettings.skybox = saved;
            return saved;
        }

        static void ConfigureAmbient(Material sky)
        {
            // Explicit gradient instead of skybox-baked SH: the procedural sky bakes a cold
            // blue-grey probe (measured luma 0.14-0.27) that desaturates every warm surface.
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.40f, 0.45f, 0.54f);
            RenderSettings.ambientEquatorColor = new Color(0.34f, 0.33f, 0.29f);
            RenderSettings.ambientGroundColor = new Color(0.18f, 0.17f, 0.14f);
            RenderSettings.ambientIntensity = 1f;
            RenderSettings.reflectionIntensity = 0.7f;
            RenderSettings.fog = false;
            DynamicGI.UpdateEnvironment();
        }

        static void ConfigureSun(GameObject env)
        {
            var go = GameObject.Find("Directional Light");
            if (go == null)
            {
                go = new GameObject("Directional Light");
                go.AddComponent<Light>().type = LightType.Directional;
            }
            go.transform.SetParent(env.transform, true);
            go.transform.rotation = Quaternion.Euler(48f, 320f, 0f);

            var l = go.GetComponent<Light>();
            l.type = LightType.Directional;
            // 1.0 instead of 1.2: most materials author _ShadowDim=0 and _halfLambertWeight=0,
            // so lit faces land on sunIntensity + ambient with nothing to soften the top end.
            l.intensity = 1.0f;
            l.color = new Color(1f, 0.957f, 0.878f);
            l.shadows = LightShadows.Soft;
            l.shadowStrength = 0.72f;
            l.bounceIntensity = 0f;
            RenderSettings.sun = l;
        }

        static void BuildPostFX(GameObject env)
        {
            const string path = Root + "/Settings/Preview_PostFX.asset";
            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(path);
            if (profile == null)
            {
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                AssetDatabase.CreateAsset(profile, path);
            }
            for (int i = profile.components.Count - 1; i >= 0; i--)
                Object.DestroyImmediate(profile.components[i], true);
            profile.components.Clear();

            var tone = profile.Add<Tonemapping>(true);
            tone.mode.overrideState = true;
            tone.mode.value = TonemappingMode.Neutral;

            var grade = profile.Add<ColorAdjustments>(true);
            grade.postExposure.overrideState = true;
            grade.postExposure.value = 0.1f;
            grade.contrast.overrideState = true;
            grade.contrast.value = 10f;
            grade.saturation.overrideState = true;
            grade.saturation.value = 8f;

            var bloom = profile.Add<Bloom>(true);
            bloom.threshold.overrideState = true;
            bloom.threshold.value = 1.05f;
            bloom.intensity.overrideState = true;
            bloom.intensity.value = 0.12f;

            EditorUtility.SetDirty(profile);
            AssetDatabase.SaveAssets();

            var go = new GameObject("Global Volume");
            go.transform.SetParent(env.transform);
            var vol = go.AddComponent<Volume>();
            vol.isGlobal = true;
            vol.priority = 0f;
            vol.weight = 1f;
            vol.sharedProfile = profile;
        }

        static void ConfigureCamera(Bounds content)
        {
            var cam = Camera.main;
            if (cam == null) return;
            var data = cam.GetComponent<UniversalAdditionalCameraData>();
            if (data == null) data = cam.gameObject.AddComponent<UniversalAdditionalCameraData>();
            data.renderPostProcessing = true;
            data.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            data.antialiasingQuality = AntialiasingQuality.High;
            cam.allowHDR = true;
            cam.farClipPlane = Mathf.Max(cam.farClipPlane, content.size.magnitude * 3f);
        }

        /// <summary>
        /// Groups the Emain/Fiodh dungeon rocks and cliffs the foliage curation dragged in, and
        /// slides them clear of the village. They stay active and keep their prefab links; this
        /// is a layout change, not a cull.
        /// </summary>
        [MenuItem("Tools/TirChonaill/Group Foreign Region Props")]
        public static void GroupForeignProps()
        {
            var previewRoot = GameObject.Find("TirChonaill_Preview");
            if (previewRoot == null) { Debug.LogWarning("[TirChonaill] No TirChonaill_Preview root."); return; }

            var holder = previewRoot.transform.Find(ForeignRootName);
            if (holder == null)
            {
                var go = new GameObject(ForeignRootName);
                go.transform.SetParent(previewRoot.transform);
                holder = go.transform;
            }
            holder.gameObject.SetActive(true);

            var moving = new List<Transform>();
            foreach (var mr in Object.FindObjectsByType<MeshRenderer>(FindObjectsSortMode.None))
            {
                var t = TopmostForeignAncestor(mr.transform);
                if (t != null && t.parent != holder && !moving.Contains(t)) moving.Add(t);
            }
            foreach (var t in moving) t.SetParent(holder, true);
            holder.localPosition = new Vector3(-320f, 0f, 0f);

            EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
            Debug.Log($"[TirChonaill] Grouped {moving.Count} foreign-region props under {ForeignRootName} (still active).");
        }

        static Transform TopmostForeignAncestor(Transform t)
        {
            Transform hit = null;
            for (var c = t; c != null; c = c.parent)
                if (HasForeignPrefix(c.name)) hit = c;
            return hit;
        }

        static bool IsForeign(Transform t)
        {
            for (var c = t; c != null; c = c.parent)
                if (HasForeignPrefix(c.name)) return true;
            return false;
        }

        /// <summary>
        /// Anchored at the start of the name, not a substring search. Village foliage such as
        /// Flower_Fiodh_00 and Grass_Fiodh_01 legitimately reuses Fiodh-region art and must stay.
        /// </summary>
        static bool HasForeignPrefix(string name)
        {
            // Strip the viewport prefix the curation pass adds, e.g. "VP1_Dungeon_...".
            int cut = 0;
            if (name.Length > 2 && name[0] == 'V' && name[1] == 'P')
            {
                int i = 2;
                while (i < name.Length && char.IsDigit(name[i])) i++;
                if (i > 2 && i < name.Length && name[i] == '_') cut = i + 1;
            }
            foreach (var t in ForeignTokens)
                if (string.CompareOrdinal(name, cut, t, 0, t.Length) == 0) return true;
            return false;
        }

        /// <summary>
        /// URP clips to [0,1] before building the grading LUT in LDR mode, which would throw
        /// away exactly the over-range highlights the tonemapper is meant to roll off.
        /// </summary>
        static void EnableHdrColorGrading()
        {
            var rp = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            if (rp == null) return;
            var so = new SerializedObject(rp);
            var prop = so.FindProperty("m_ColorGradingMode");
            if (prop == null) return;
            if (prop.intValue == (int)ColorGradingMode.HighDynamicRange) return;
            prop.intValue = (int)ColorGradingMode.HighDynamicRange;
            so.ApplyModifiedProperties();
            EditorUtility.SetDirty(rp);
            Debug.Log($"[TirChonaill] Switched {rp.name} color grading to HighDynamicRange.");
        }

        static void SaveMaterial(Material mat, string path)
        {
            var existing = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (existing == null) AssetDatabase.CreateAsset(mat, path);
            else { existing.shader = mat.shader; existing.CopyPropertiesFromMaterial(mat); EditorUtility.SetDirty(existing); }
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            var parent = System.IO.Path.GetDirectoryName(path).Replace('\\', '/');
            var leaf = System.IO.Path.GetFileName(path);
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }
    }
}
