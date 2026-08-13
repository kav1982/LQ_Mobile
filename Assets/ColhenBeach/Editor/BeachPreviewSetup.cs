using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

using ColhenBeach;

namespace ColhenBeach.Editor
{
    /// <summary>
    /// Wires URP up for the beach and builds the preview scene.
    ///
    /// The MMN shaders keep the game's own LightMode tags ("BG", "Water", "Decal", "SkyLit")
    /// rather than URP's UniversalForward, because those tags are part of the extracted contract.
    /// URP has no idea what they mean, so each one needs a RenderObjects feature or the object
    /// silently draws nothing. The order below is what the queues imply: the terrain with the
    /// opaques, then the far terrain backdrop, the caustics decal and the water after the skybox,
    /// and finally the shoreline wave FX in URP's own transparent pass (they carry no LightMode,
    /// so they land in SRPDefaultUnlit, which URP already draws).
    /// </summary>
    public static class BeachPreviewSetup
    {
        struct FeatureSpec
        {
            public string Name;
            public string LightMode;
            public RenderPassEvent Event;
            public RenderQueueType Queue;
        }

        static readonly FeatureSpec[] Features =
        {
            new FeatureSpec { Name = "MMN BG", LightMode = "BG",
                Event = RenderPassEvent.BeforeRenderingOpaques, Queue = RenderQueueType.Opaque },
            new FeatureSpec { Name = "MMN SkyLit", LightMode = "SkyLit",
                Event = RenderPassEvent.AfterRenderingSkybox, Queue = RenderQueueType.Transparent },
            new FeatureSpec { Name = "MMN Decal", LightMode = "Decal",
                Event = RenderPassEvent.AfterRenderingSkybox, Queue = RenderQueueType.Transparent },
            new FeatureSpec { Name = "MMN Water", LightMode = "Water",
                Event = RenderPassEvent.AfterRenderingSkybox, Queue = RenderQueueType.Transparent },
        };

        // The ocean package and the terrain do not share a world frame. The terrain's placement is
        // real data (root -199.3/-17.9/-196.6, and its splatmap UVs confirm a 370x500 map ending at
        // world x 170.7), but colhen_water_00's prefab root is identity, so the shipped ocean
        // coordinates carry no placement at all - as instantiated, the shoreline ribbons sit ~90 m
        // out to sea, past the east edge of the heightmap.
        //
        // Fitting the four static shoreline ribbons against the terrain's own waterline (vertices
        // within 0.35 of sea level) over every quarter turn and a +/-400 m translation gives yaw 180
        // with this offset: 1.4 m mean error, against 5.6 m for yaw 0 and 15-32 m for the rest. It
        // puts the three Shoreline pivots and the caustic decal exactly on the waterline, leaves the
        // four breakers 40-70 m offshore, and turns their travel direction shoreward.
        //
        // NOT-IMPLEMENTED: the real placement, which lives in the town's scene/region data rather
        // than in either prefab. far_ocean is left where it ships; it is a coarse sunken backdrop
        // with no geometry near sea level, so nothing was measurable to align it against.
        static readonly Vector3 OceanFramePosition = new Vector3(310f, 0f, -1f);
        static readonly Quaternion OceanFrameRotation = Quaternion.Euler(0f, 180f, 0f);

        [MenuItem("MMN/Colhen Beach/2. Configure URP For MMN Light Modes")]
        public static void ConfigureUrp()
        {
            var urp = GraphicsSettings.currentRenderPipeline as UniversalRenderPipelineAsset;
            if (urp == null)
            {
                Debug.LogError("[ColhenBeach] no UniversalRenderPipelineAsset is active");
                return;
            }

            // The water reads scene depth for its scatter/foam ramp and the caustics decal
            // reconstructs world position from it, so both have to be on.
            var urpSo = new SerializedObject(urp);
            urpSo.FindProperty("m_RequireDepthTexture").boolValue = true;
            urpSo.FindProperty("m_RequireOpaqueTexture").boolValue = true;
            urpSo.ApplyModifiedProperties();

            foreach (var data in RendererDataList(urp))
                ConfigureRenderer(data);

            AssetDatabase.SaveAssets();
            Debug.Log("[ColhenBeach] URP configured: depth+opaque textures on, MMN light mode passes present");
        }

        static IEnumerable<ScriptableRendererData> RendererDataList(UniversalRenderPipelineAsset urp)
        {
            var so = new SerializedObject(urp);
            var list = so.FindProperty("m_RendererDataList");
            for (int i = 0; i < list.arraySize; i++)
                if (list.GetArrayElementAtIndex(i).objectReferenceValue is ScriptableRendererData d)
                    yield return d;
        }

        static void ConfigureRenderer(ScriptableRendererData data)
        {
            foreach (var spec in Features)
            {
                if (data.rendererFeatures.Any(f => f != null && f.name == spec.Name)) continue;

                var feature = ScriptableObject.CreateInstance<RenderObjects>();
                feature.name = spec.Name;
                feature.settings.passTag = spec.LightMode;
                feature.settings.Event = spec.Event;
                feature.settings.filterSettings.RenderQueueType = spec.Queue;
                feature.settings.filterSettings.LayerMask = -1;
                feature.settings.filterSettings.PassNames = new[] { spec.LightMode };

                AssetDatabase.AddObjectToAsset(feature, data);
                AssetDatabase.SaveAssets();

                // m_RendererFeatureMap holds the local file id of each feature; URP rebuilds its
                // pass list from it, so a feature added without the map entry is ignored.
                var so = new SerializedObject(data);
                var features = so.FindProperty("m_RendererFeatures");
                var map = so.FindProperty("m_RendererFeatureMap");
                int index = features.arraySize;
                features.InsertArrayElementAtIndex(index);
                features.GetArrayElementAtIndex(index).objectReferenceValue = feature;
                map.InsertArrayElementAtIndex(index);
                AssetDatabase.TryGetGUIDAndLocalFileIdentifier(feature, out _, out long localId);
                map.GetArrayElementAtIndex(index).longValue = localId;
                so.ApplyModifiedProperties();

                EditorUtility.SetDirty(data);
                Debug.Log($"[ColhenBeach] added '{spec.Name}' (LightMode {spec.LightMode}) to {data.name}");
            }
        }

        [MenuItem("MMN/Colhen Beach/3. Build Preview Scene")]
        public static void BuildScene()
        {
            const string outRoot = "Assets/ColhenBeach";
            var prefabs = AssetDatabase.FindAssets("t:Prefab", new[] { outRoot + "/Prefabs" })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Select(AssetDatabase.LoadAssetAtPath<GameObject>)
                .Where(p => p != null)
                .ToList();
            if (prefabs.Count == 0)
            {
                Debug.LogError("[ColhenBeach] no prefabs - run 'Import Beach Assets' first");
                return;
            }

            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            // Every package keeps the town's own world space, and the root transform is part of
            // that: the terrain root carries a (-199.3, -17.9, -196.6) offset that puts its
            // tile-local mesh coordinates on the water, so the instances go in untouched.
            //
            // shoreline_fx is skipped: the water prefab's dependency closure already pulled the
            // same six emitters in, so instantiating both would double every wave.
            var instances = new List<GameObject>();
            foreach (var p in prefabs)
            {
                if (p.name == "shoreline_fx") continue;
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(p);
                if (p.name == "ocean")
                {
                    inst.transform.SetPositionAndRotation(OceanFramePosition, OceanFrameRotation);
                }
                instances.Add(inst);
            }

            SinkOceanDepths(instances);
            AttachParticlePreview(instances);

            Renderer water = null;
            foreach (var inst in instances)
            foreach (var r in inst.GetComponentsInChildren<Renderer>())
                if (r.sharedMaterial != null && r.sharedMaterial.shader != null
                    && r.sharedMaterial.shader.name == "MMN/Special/PlanarReflectionWater")
                    water = r;

            if (water != null)
            {
                var pr = water.gameObject.AddComponent<PlanarReflections>();
                pr.meshRenderers = new List<Renderer> { water };
                pr.planeHeight = water.bounds.center.y;
                pr.clipPlaneOffset = 0.55f;
                pr.resolutionDivider = 2;
                // Reflecting the water back into itself would recurse; everything else is fair game.
                pr.reflectLayers = ~0;
            }
            else
            {
                Debug.LogWarning("[ColhenBeach] no PlanarReflectionWater renderer found; reflections will stay black");
            }

            ApplyBeachEnvironment(scene, water, instances);

            string scenePath = outRoot + "/Scenes/ColhenBeach_Preview.unity";
            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError("[ColhenBeach] failed to save " + scenePath);
                return;
            }
            Debug.Log($"[ColhenBeach] scene saved to {scenePath} with {instances.Count} package(s)");
        }

        /// <summary>
        /// Scene view will not tick particles unless the Particle overlay's Simulate Layers is set,
        /// which this preview cannot assume. The helper drives Simulate in edit mode so the
        /// shoreline cards are visible without entering Play.
        /// </summary>
        static void AttachParticlePreview(List<GameObject> instances)
        {
            foreach (var inst in instances)
            {
                if (inst.GetComponentInChildren<ParticleSystem>(true) == null) continue;
                if (inst.GetComponent<ParticleEditorPreview>() == null)
                    inst.AddComponent<ParticleEditorPreview>();
            }

            // Scene view otherwise freezes _Time (shader panning) and does not repaint, so the
            // shoreline cards look like a still even while Simulate is advancing them.
            var sv = SceneView.lastActiveSceneView;
            if (sv != null)
            {
                var state = sv.sceneViewState;
                state.alwaysRefresh = true;
                state.alwaysRefresh = true;
                state.fxEnabled = true;
                sv.sceneViewState = state;
            }
        }

        /// <summary>
        /// The deep-water colour band ships as a flat plane whose authored height lives in the town
        /// scene, not in the prefab: the prefab alone puts it at y=102, a ceiling over the whole bay.
        /// Only the scene knows the real offset, so the plane is dropped to just under the water
        /// plane here, which is the one position that makes it read as the sea floor it stands in for.
        /// </summary>
        static void SinkOceanDepths(List<GameObject> instances)
        {
            const float waterPlane = 0.588f;
            foreach (var inst in instances)
            foreach (var r in inst.GetComponentsInChildren<Renderer>())
            {
                if (!r.name.Contains("OceanDepths")) continue;
                var t = r.transform;
                t.position += Vector3.up * (waterPlane - 1.5f - r.bounds.center.y);
            }
        }

        /// <summary>
        /// Midday coastal lighting. There is no extracted lighting setup for Colhen - the game
        /// drives sky and sun through its _Global_* uniforms, which are not part of the shipped
        /// material data - so this is matched by eye to the reference capture: a high sun from the
        /// south-west, a bright sky ambient, and light haze to keep the far headland from reading
        /// as flat cardboard.
        /// </summary>
        static void ApplyBeachEnvironment(Scene scene, Renderer water, List<GameObject> instances)
        {
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.74f, 0.83f, 0.89f);
            // Dense enough to haze out the backdrop meshes a few hundred metres away: they are built
            // to be seen from inside the playable area only, so their far edges are otherwise visible
            // as hard seams against the sky.
            RenderSettings.fogDensity = 0.0022f;

            // The water is mostly sky: at grazing angles its own colour is replaced by _FresnelColor
            // (a near-black navy on this material) and what brings it back up is the reflection term.
            // Without a skybox both the planar mirror and unity_SpecCube0 hand back black and the sea
            // renders as tar, so the preview needs a real environment, not just a clear colour.
            RenderSettings.skybox = BeachSkyMaterial();
            RenderSettings.ambientMode = AmbientMode.Skybox;
            // Brighter than physical: the game drives these shaders with its own _Global_Sun/_Global_Sky
            // uniforms and then tonemaps, neither of which was extracted, so sun and ambient are set
            // to land the sand and the water at the levels the reference capture shows.
            RenderSettings.ambientIntensity = 1.35f;
            RenderSettings.defaultReflectionMode = DefaultReflectionMode.Skybox;
            RenderSettings.defaultReflectionResolution = 256;
            RenderSettings.reflectionIntensity = 1f;

            var lightGo = new GameObject("Directional Light");
            SceneManager.MoveGameObjectToScene(lightGo, scene);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.95f, 0.86f);
            light.intensity = 1.7f;
            light.shadows = LightShadows.Soft;
            light.shadowStrength = 0.55f;
            lightGo.transform.rotation = Quaternion.Euler(55f, 210f, 0f);
            RenderSettings.sun = light;
            DynamicGI.UpdateEnvironment();

            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.Skybox;
            cam.backgroundColor = new Color(0.55f, 0.72f, 0.85f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 3000f;
            cam.fieldOfView = 45f;
            camGo.AddComponent<AudioListener>();

            FrameShoreline(camGo.transform, instances, water != null ? water.bounds.center.y : 0.59f);
        }

        /// <summary>
        /// Stills the scene renders for review. Particles have to be stepped by hand: edit mode does
        /// not tick them, so an unsimulated capture shows the water with no waves on it at all. The
        /// target is an sRGB render texture because the project renders linear and ReadPixels does no
        /// conversion - straight off an HDR target every capture comes out about a stop too dark.
        /// </summary>
        [MenuItem("MMN/Colhen Beach/4. Capture Preview Screenshot")]
        public static void CaptureScreenshot()
        {
            var cam = Camera.main;
            if (cam == null)
            {
                Debug.LogError("[ColhenBeach] no main camera - build the preview scene first");
                return;
            }

            // Only roots: Simulate(withChildren) already steps the whole hierarchy, so stepping
            // every system in the scene would advance a child twice and age the one-shot
            // shoreline ribbons (5s duration, 5.5s lifetime) past the end of their life.
            foreach (var ps in UnityEngine.Object.FindObjectsOfType<ParticleSystem>())
            {
                var parent = ps.transform.parent;
                if (parent != null && parent.GetComponentInParent<ParticleSystem>() != null) continue;
                ps.Simulate(4f, true, true, false);
            }

            const int w = 1600, h = 900;
            var rt = new RenderTexture(w, h, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
            rt.Create();
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            var tex = new Texture2D(w, h, TextureFormat.RGBA32, false, false);
            tex.ReadPixels(new Rect(0, 0, w, h), 0, 0);
            tex.Apply();
            RenderTexture.active = null;
            cam.targetTexture = null;

            string path = System.IO.Path.Combine(
                System.IO.Directory.GetParent(Application.dataPath).FullName, "ColhenBeach_Preview.png");
            System.IO.File.WriteAllBytes(path, tex.EncodeToPNG());

            UnityEngine.Object.DestroyImmediate(tex);
            rt.Release();
            UnityEngine.Object.DestroyImmediate(rt);
            Debug.Log("[ColhenBeach] screenshot written to " + path);
        }

        /// <summary>
        /// The town's own sky is drawn by game systems that were not extracted, so the preview uses
        /// Unity's procedural sky tuned to the reference capture: a hazy midday coastal blue.
        /// </summary>
        static Material BeachSkyMaterial()
        {
            const string path = "Assets/ColhenBeach/Materials/BeachSky.mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            bool created = mat == null;
            if (created) mat = new Material(Shader.Find("Skybox/Procedural"));

            mat.SetFloat("_SunSize", 0.035f);
            mat.SetFloat("_SunSizeConvergence", 6f);
            // A neutral tint with a full-thickness atmosphere: tinting the sky blue and thinning the
            // atmosphere turns the horizon band green, since the procedural sky's Rayleigh term is
            // what carries the tint and it dominates at grazing angles.
            mat.SetColor("_SkyTint", new Color(0.5f, 0.5f, 0.5f));
            mat.SetFloat("_AtmosphereThickness", 1f);
            mat.SetColor("_GroundColor", new Color(0.42f, 0.42f, 0.40f));
            mat.SetFloat("_Exposure", 1.3f);

            if (created)
            {
                System.IO.Directory.CreateDirectory("Assets/ColhenBeach/Materials");
                AssetDatabase.CreateAsset(mat, path);
            }
            else
            {
                EditorUtility.SetDirty(mat);
            }
            AssetDatabase.SaveAssets();
            return mat;
        }

        /// <summary>
        /// Frames the shot the way the reference capture does: standing on the sand a little above
        /// head height, looking seaward across the waterline so the wet-sand wash, the breakers and
        /// the deep water band all read in one frame.
        ///
        /// Nothing here is hand-placed. The waterline comes from the wave emitters, which the
        /// artists put along it, and the camera stands on the flattest terrain tile near sea level
        /// closest to them - that is the beach, as opposed to the cliffs further inland.
        /// </summary>
        static void FrameShoreline(Transform cam, List<GameObject> instances, float waterLevel)
        {
            var emitters = instances
                .SelectMany(i => i.GetComponentsInChildren<ParticleSystem>())
                .Select(p => p.transform.position)
                .Where(p => p.sqrMagnitude > 1f) // the FX root sits at the origin, not on the shore
                .ToList();
            var terrain = instances
                .SelectMany(i => i.GetComponentsInChildren<Renderer>())
                .Where(r => r.sharedMaterial != null && r.sharedMaterial.shader != null
                            && r.sharedMaterial.shader.name.EndsWith("Splatmap"))
                .ToList();
            if (emitters.Count == 0 || terrain.Count == 0)
            {
                cam.position = new Vector3(60f, 12f, -60f);
                cam.LookAt(new Vector3(180f, waterLevel, -40f));
                return;
            }

            // Dry sand only: half the tiles of this slice are the submerged sea floor, and the rest
            // climb into the cliffs behind the bay. What is left is the flat strip the waves run up.
            var beach = terrain
                .Where(r => r.bounds.max.y > waterLevel + 0.5f && r.bounds.max.y < waterLevel + 8f)
                .ToList();
            if (beach.Count == 0) beach = terrain;

            // Aim at an actual breaker rather than at the average of all of them: the emitters trace
            // a curved bay, so their centroid sits out in open water with no beach anywhere near it.
            var tile = beach
                .OrderBy(r => emitters.Min(e => Vector2.Distance(
                    new Vector2(r.bounds.center.x, r.bounds.center.z), new Vector2(e.x, e.z))))
                .First();
            var stand = tile.bounds.center;
            var target = emitters
                .OrderBy(e => Vector2.Distance(new Vector2(stand.x, stand.z), new Vector2(e.x, e.z)))
                .First();

            var seaward = new Vector3(target.x - stand.x, 0f, target.z - stand.z).normalized;
            if (seaward.sqrMagnitude < 0.5f) seaward = Vector3.right;

            var eye = stand - seaward * 35f;
            // Eye height scales with the distance to the wave rather than being fixed, so the shot
            // works out on whatever beach the data puts the emitters near. The wave cards are flat
            // sheets lying on the water: too low and they are seen edge-on and all but vanish, too
            // high and the horizon leaves the frame.
            float run = Vector2.Distance(new Vector2(eye.x, eye.z), new Vector2(target.x, target.z));
            eye.y = Mathf.Max(tile.bounds.max.y, waterLevel) + Mathf.Clamp(run * 0.35f, 10f, 40f);
            cam.position = eye;
            // Aiming past the breaker rather than at it keeps the horizon in the upper third.
            cam.LookAt(new Vector3(target.x, waterLevel, target.z) + seaward * 60f);
        }
    }
}
