using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using TirChonaill.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Labyrinth.Editor
{
    /// <summary>
    /// Builds the Labyrinth Field 1 preview scene.
    ///
    /// The play scene that placed the plaza roots does not ship. Within one area the large
    /// modules were statically batched, so they reassemble at identity. Across A/B/C each
    /// room was batched in its own origin; the world-baked <c>a_floor</c> / <c>c_floor</c>
    /// meshes sit at the real terrace positions, so their center minus the matching
    /// <c>*_floor_00</c> center is the area-root translation. B is the origin plaza.
    /// Floor-block kits with no instance list stay on a contact sheet off to the side.
    /// </summary>
    public static class LabyrinthPreviewSetup
    {
        const string PackRoot = "Assets/Worlds/Labyrinth/_import_pack";
        const string PrefabRoot = "Assets/Worlds/Labyrinth/Prefabs";
        const string ScenePath = "Assets/Worlds/Labyrinth/Scenes/Labyrinth_Preview.unity";

        // Below this XZ extent a module is a single prop rather than a batched area chunk.
        const float AreaExtentThreshold = 25f;

        // World-baked terraces that duplicate *_floor_00 once the area root is applied.
        static readonly string[] SkipWorldBakedDuplicates =
        {
            "labyrinth_field_1_a_floor",
            "labyrinth_field_1_c_floor",
        };

        static readonly (string area, string[] prefixes)[] AreaRules =
        {
            ("Area_A", new[] { "labyrinth_field_1_a_", "labyrinth_field_1_stair_a" }),
            ("Area_B", new[] { "labyrinth_field_1_b_", "labyrinth_field_1_stair_b" }),
            ("Area_C", new[] { "labyrinth_field_1_c_" }),
            ("Entrance", new[] { "labyrinth_field_1_entrance", "labyrinth_field_1_entbex",
                                 "labyrinth_field_1_stair_entbex", "labyrinth_entrance_00" }),
            ("Exit", new[] { "labyrinth_exit_00" }),
            ("Terrain", new[] { "labyrinth_field_1_terrain" }),
            ("FarView", new[] { "labyrinth_field_1_farterrain", "labyrinth_field_1_farbuilding",
                                "labyrinth_field_1_water" }),
        };

        [MenuItem("Tools/Labyrinth/2. Build Preview Scene")]
        public static void BuildScene()
        {
            var prefabs = LoadPrefabs();
            if (prefabs.Count == 0)
            {
                Debug.LogError("[Labyrinth] no prefabs - run 'Tools/Labyrinth/1. Import Scene Assets' first");
                return;
            }

            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var settings = ApplyEnvironment();

            var root = new GameObject("Labyrinth_Field_1");
            SceneManager.MoveGameObjectToScene(root, scene);

            var props = new List<GameObject>();
            var areaGroups = new Dictionary<string, Transform>();
            int placedAreas = 0;
            var areaRoots = ComputeAreaRoots(prefabs);

            foreach (var prefab in prefabs)
            {
                if (IsWorldBakedDuplicate(prefab.name))
                    continue;
                string area = AreaOf(prefab.name);
                if (area == null || IsKitPiece(prefab.name)
                    || (XZExtent(prefab) < AreaExtentThreshold && !IsStructural(prefab.name)))
                {
                    props.Add(prefab);
                    continue;
                }
                if (!areaGroups.TryGetValue(area, out var group))
                {
                    var go = new GameObject(area);
                    go.transform.SetParent(root.transform, false);
                    areaGroups[area] = group = go.transform;
                }
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                inst.transform.SetParent(group, false);
                // Terrain tiles keep the authored root offset (-129,-45,-156).
                // Stone modules are already identity, so this is a no-op for them.
                placedAreas++;
            }

            ApplyAreaRoots(areaGroups, areaRoots);
            // stair_ac was batched in the origin frame (72m tall). Applying the A-terrace
            // root turns it into a column of floating stone from y=-2 to y=70. Leave it
            // at world identity; aent/aex stay on the terrace.
            KeepWorldIdentity(areaGroups, "labyrinth_field_1_stair_ac");
            int placedProps = BuildPropGrid(root.transform, props, areaGroups);

            AddSunAndCamera(scene, settings, areaGroups);

            EnsureFolder("Assets/Worlds/Labyrinth/Scenes");
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
            {
                Debug.LogError("[Labyrinth] failed to save " + ScenePath);
                return;
            }
            Debug.Log($"[Labyrinth] preview: {placedAreas} area module(s) in {areaGroups.Count} group(s), "
                      + $"{placedProps} prop(s) on the grid -> {ScenePath}");
        }

        static List<GameObject> LoadPrefabs()
        {
            var list = new List<GameObject>();
            if (!AssetDatabase.IsValidFolder(PrefabRoot)) return list;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { PrefabRoot }))
            {
                var p = AssetDatabase.LoadAssetAtPath<GameObject>(AssetDatabase.GUIDToAssetPath(guid));
                if (p != null && p.GetComponentsInChildren<Renderer>(true).Length > 0)
                    list.Add(p);
            }
            list.Sort((a, b) => string.CompareOrdinal(a.name, b.name));
            return list;
        }

        static string AreaOf(string name)
        {
            string n = name.ToLowerInvariant();
            foreach (var (area, prefixes) in AreaRules)
                if (prefixes.Any(p => n.StartsWith(p, StringComparison.Ordinal)))
                    return area;
            return null;
        }

        static bool IsWorldBakedDuplicate(string name)
        {
            string n = name.ToLowerInvariant();
            return SkipWorldBakedDuplicates.Any(s => n.Equals(s, StringComparison.Ordinal));
        }

        static bool IsKitPiece(string name)
        {
            string n = name.ToLowerInvariant();
            return n.Contains("floor_block") || n.Contains("floor_stones")
                || n.Contains("wall_01_stone")
                // A-side pillars are unique kits at local origin; parenting them to
                // Area_A piles all three on the terrace root as a 20-38m clump.
                || n.Contains("_a_pillar_");
        }

        static bool IsStructural(string name)
        {
            string n = name.ToLowerInvariant();
            return n.Contains("_floor") || n.Contains("floorwall") || n.Contains("_stair")
                || n.Contains("entrance") || n.Contains("exit") || n.Contains("farterrain")
                || n.Contains("field_1_terrain") || n.Contains("farbuilding")
                || n.Contains("_water") || n.Contains("_building_");
        }

        static float XZExtent(GameObject prefab)
        {
            var b = PrefabBounds(prefab);
            return b.HasValue ? Mathf.Max(b.Value.size.x, b.Value.size.z) : 0f;
        }

        static Bounds? PrefabBounds(GameObject prefab)
        {
            Bounds? b = null;
            foreach (var mf in prefab.GetComponentsInChildren<MeshFilter>(true))
            {
                var mesh = mf.sharedMesh;
                if (mesh == null) continue;
                var world = TransformBounds(mf.transform.localToWorldMatrix, mesh.bounds);
                if (b == null) b = world;
                else
                {
                    var t = b.Value;
                    t.Encapsulate(world);
                    b = t;
                }
            }
            return b;
        }

        static Bounds TransformBounds(Matrix4x4 m, Bounds local)
        {
            var c = local.center;
            var e = local.extents;
            var world = new Bounds(m.MultiplyPoint3x4(c), Vector3.zero);
            for (int i = 0; i < 8; i++)
            {
                var p = c + new Vector3(
                    (i & 1) == 0 ? e.x : -e.x,
                    (i & 2) == 0 ? e.y : -e.y,
                    (i & 4) == 0 ? e.z : -e.z);
                world.Encapsulate(m.MultiplyPoint3x4(p));
            }
            return world;
        }

        /// <summary>
        /// Area-root translations from the world-baked terrace minus its local-origin twin.
        /// B has no world-baked floor, so it stays at the origin.
        /// </summary>
        static Dictionary<string, Vector3> ComputeAreaRoots(List<GameObject> prefabs)
        {
            var byName = new Dictionary<string, GameObject>(StringComparer.OrdinalIgnoreCase);
            foreach (var p in prefabs)
                byName[p.name] = p;

            var roots = new Dictionary<string, Vector3>(StringComparer.Ordinal);
            if (TryFloorOffset(byName, "labyrinth_field_1_a_floor",
                    "labyrinth_field_1_a_floor_00", out var a))
                roots["Area_A"] = a;
            if (TryFloorOffset(byName, "labyrinth_field_1_c_floor",
                    "labyrinth_field_1_c_floor_00", out var c))
                roots["Area_C"] = c;
            return roots;
        }

        static bool TryFloorOffset(Dictionary<string, GameObject> byName,
            string worldName, string localName, out Vector3 offset)
        {
            offset = Vector3.zero;
            if (!byName.TryGetValue(worldName, out var world)
                || !byName.TryGetValue(localName, out var local))
                return false;
            var wb = PrefabBounds(world);
            var lb = PrefabBounds(local);
            if (!wb.HasValue || !lb.HasValue) return false;
            offset = wb.Value.center - lb.Value.center;
            return true;
        }

        static void ApplyAreaRoots(Dictionary<string, Transform> groups,
            Dictionary<string, Vector3> roots)
        {
            foreach (var kv in groups)
            {
                var pos = roots.TryGetValue(kv.Key, out var p) ? p : Vector3.zero;
                kv.Value.position = pos;
                Debug.Log($"[Labyrinth] {kv.Key} root {pos}");
            }
        }

        static void KeepWorldIdentity(Dictionary<string, Transform> groups, string childName)
        {
            foreach (var group in groups.Values)
            {
                var t = group.Find(childName);
                if (t == null) continue;
                t.position = Vector3.zero;
                Debug.Log($"[Labyrinth] {childName} kept at world identity (was under {group.name})");
                return;
            }
        }

        static Bounds? GroupBounds(Transform group)
        {
            Bounds? b = null;
            foreach (var r in group.GetComponentsInChildren<MeshRenderer>(true))
            {
                if (b == null) b = r.bounds;
                else
                {
                    var t = b.Value;
                    t.Encapsulate(r.bounds);
                    b = t;
                }
            }
            return b;
        }

        static int BuildPropGrid(Transform root, List<GameObject> props,
            Dictionary<string, Transform> areaGroups)
        {
            if (props.Count == 0) return 0;

            // Park the sheet well clear of the areas on X. Offsetting it on Z instead leaves it
            // sitting in the distance of every north-facing area shot.
            float areaEast = 0f;
            foreach (var g in areaGroups.Values)
            {
                var b = GroupBounds(g);
                if (b.HasValue) areaEast = Mathf.Max(areaEast, b.Value.max.x);
            }

            var grid = new GameObject("Props_ContactSheet");
            grid.transform.SetParent(root, false);
            grid.transform.position = new Vector3(areaEast + 500f, 0f, 0f);

            const float gap = 6f;
            const float rowWidth = 220f;
            float x = 0f, z = 0f, rowDepth = 0f;
            int placed = 0;

            foreach (var prefab in props)
            {
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                inst.transform.SetParent(grid.transform, false);
                var b = PrefabBounds(prefab) ?? new Bounds(Vector3.zero, Vector3.one * 2f);

                if (x > 0f && x + b.size.x > rowWidth)
                {
                    x = 0f;
                    z += rowDepth + gap;
                    rowDepth = 0f;
                }
                inst.transform.localPosition = new Vector3(
                    x + b.size.x * 0.5f - b.center.x, -b.min.y, z + b.size.z * 0.5f - b.center.z);
                x += b.size.x + gap;
                rowDepth = Mathf.Max(rowDepth, b.size.z);
                placed++;
            }
            return placed;
        }

        // Stand-ins for the day/night rig the package does not contain, dialled against the
        // reference screenshot: enough ambient that shadowed crevices stay readable without
        // washing out the pale stone, and a hazy grey fog rather than the authored night navy.
        static readonly Color DaylightAmbient = new Color(0.26f, 0.26f, 0.29f, 1f);
        static readonly Color DaylightFog = new Color(0.78f, 0.79f, 0.80f, 1f);

        /// <summary>
        /// Applies the fog and ambient the shipped scene authored. Without them the plaza
        /// renders as a flat, evenly lit model instead of the pale haze the game shows.
        /// </summary>
        static Dictionary<string, object> ApplyEnvironment()
        {
            string path = PackRoot + "/scene.json";
            Dictionary<string, object> d = null;
            if (File.Exists(path))
                d = MiniJson.Deserialize(File.ReadAllText(path, Encoding.UTF8)) as Dictionary<string, object>;

            if (d == null)
            {
                Debug.LogWarning("[Labyrinth] no scene.json - using neutral lighting");
                RenderSettings.fog = false;
                RenderSettings.ambientMode = AmbientMode.Trilight;
                return null;
            }

            RenderSettings.fog = LabyrinthImporter.ToF(d.TryGetValue("fog", out var f) ? f : false) > 0.5f;
            // Unity FogMode: 1 Linear, 2 Exponential, 3 ExponentialSquared.
            int fm = (int)LabyrinthImporter.ToF(d.TryGetValue("fogMode", out var fmv) ? fmv : 3f);
            RenderSettings.fogMode = fm == 1 ? FogMode.Linear
                : fm == 2 ? FogMode.Exponential : FogMode.ExponentialSquared;
            var fc = LabyrinthImporter.ToColor(d.TryGetValue("fogColor", out var fcv) ? fcv : null);
            if (fc.HasValue) RenderSettings.fogColor = fc.Value;
            RenderSettings.fogDensity = LabyrinthImporter.ToF(d.TryGetValue("fogDensity", out var fd) ? fd : 0.01f);
            RenderSettings.fogStartDistance = LabyrinthImporter.ToF(d.TryGetValue("linearFogStart", out var fs) ? fs : 0f);
            RenderSettings.fogEndDistance = LabyrinthImporter.ToF(d.TryGetValue("linearFogEnd", out var fe) ? fe : 300f);

            // Unity AmbientMode: 0 Skybox, 1 Trilight, 3 Flat, 4 Custom.
            int am = (int)LabyrinthImporter.ToF(d.TryGetValue("ambientMode", out var amv) ? amv : 3f);
            RenderSettings.ambientMode = am == 0 ? AmbientMode.Skybox
                : am == 1 ? AmbientMode.Trilight
                : am == 4 ? AmbientMode.Custom : AmbientMode.Flat;
            var sky = LabyrinthImporter.ToColor(d.TryGetValue("ambientSkyColor", out var sk) ? sk : null);
            var eq = LabyrinthImporter.ToColor(d.TryGetValue("ambientEquatorColor", out var eqv) ? eqv : null);
            var gr = LabyrinthImporter.ToColor(d.TryGetValue("ambientGroundColor", out var grv) ? grv : null);
            if (sky.HasValue) RenderSettings.ambientSkyColor = sky.Value;
            if (eq.HasValue) RenderSettings.ambientEquatorColor = eq.Value;
            if (gr.HasValue) RenderSettings.ambientGroundColor = gr.Value;
            RenderSettings.ambientIntensity = LabyrinthImporter.ToF(d.TryGetValue("ambientIntensity", out var ai) ? ai : 1f);

            // The scene asset stores flat white at full intensity, which is a placeholder: the
            // running game swaps ambient in from a day/night rig that ships elsewhere. Applied
            // literally it adds a full unit of white to every surface, and this dungeon's stone
            // is already near-white in albedo, so every mesh flattens to featureless paper.
            // Detect that placeholder and substitute a daylight ambient instead.
            if (RenderSettings.ambientMode == AmbientMode.Flat)
            {
                var a = RenderSettings.ambientSkyColor;
                if (Mathf.Min(a.r, Mathf.Min(a.g, a.b)) * RenderSettings.ambientIntensity > 0.9f)
                {
                    RenderSettings.ambientSkyColor = DaylightAmbient;
                    RenderSettings.ambientLight = DaylightAmbient;
                    RenderSettings.ambientIntensity = 1f;
                    // The authored navy is the night profile; the reference shot is hazy daylight.
                    RenderSettings.fogColor = DaylightFog;
                    // The authored ramp starts behind the near plane and saturates by 150m,
                    // which suits the game's tight chase camera but erases the stonework in
                    // wide preview shots. Push the onset out so the plaza itself stays legible
                    // and haze only builds on the far arcade, as in the reference.
                    RenderSettings.fogStartDistance = 40f;
                    RenderSettings.fogEndDistance = 320f;
                    Debug.Log("[Labyrinth] authored ambient was placeholder white - " +
                        "substituted daylight ambient/fog to match the reference screenshot");
                }
            }
            RenderSettings.reflectionIntensity = LabyrinthImporter.ToF(
                d.TryGetValue("reflectionIntensity", out var ri) ? ri : 1f);
            RenderSettings.skybox = null;

            var scol = LabyrinthImporter.ToColor(d.TryGetValue("subtractiveShadowColor", out var sc) ? sc : null);
            if (scol.HasValue) RenderSettings.subtractiveShadowColor = scol.Value;
            return d;
        }

        static void AddSunAndCamera(Scene scene, Dictionary<string, object> settings,
            Dictionary<string, Transform> areaGroups)
        {
            var lightGo = new GameObject("Directional Light");
            SceneManager.MoveGameObjectToScene(lightGo, scene);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            // The scene ships no directional light of its own - the sun lived in the play
            // scene that is not in the package - so this is a stand-in matched to the
            // overcast, near-shadowless look of the screenshot.
            light.color = new Color(1f, 0.96f, 0.89f);
            // The BG shaders wrap the main light as ndl*0.5+0.5, so half of this lands even on
            // back faces; combined with ambient anything near 1.0 clips the pale stone to white.
            light.intensity = 0.85f;
            light.shadows = LightShadows.Soft;
            light.shadowStrength = 0.7f;
            lightGo.transform.rotation = Quaternion.Euler(38f, 145f, 0f);
            RenderSettings.sun = light;

            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = RenderSettings.fog ? RenderSettings.fogColor : new Color(0.6f, 0.65f, 0.7f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 3000f;
            cam.fieldOfView = 45f;
            camGo.AddComponent<AudioListener>();

            // Behind and above the plaza looking in, which is roughly the game's chase camera.
            var target = areaGroups.TryGetValue("Area_B", out var b) ? b
                : areaGroups.Values.FirstOrDefault();
            var bounds = target != null ? GroupBounds(target) : null;
            var focus = bounds?.center ?? Vector3.zero;
            float span = bounds.HasValue ? Mathf.Max(bounds.Value.size.x, bounds.Value.size.z) : 60f;
            camGo.transform.position = focus + new Vector3(0f, span * 0.35f, -span * 0.75f);
            camGo.transform.LookAt(focus + Vector3.up * span * 0.05f);
        }

        /// <summary>
        /// Stills for review: one eye-level shot per area plus a top-down of each. The render
        /// target is sRGB because the project renders linear and ReadPixels does no
        /// conversion - straight off an HDR target every capture comes out about a stop dark.
        /// </summary>
        [MenuItem("Tools/Labyrinth/3. Capture Preview Screenshots")]
        public static void CaptureScreenshots()
        {
            var root = GameObject.Find("Labyrinth_Field_1");
            if (root == null)
            {
                Debug.LogError("[Labyrinth] no preview scene open - run step 2 first");
                return;
            }
            var cam = Camera.main;
            if (cam == null)
            {
                Debug.LogError("[Labyrinth] preview scene has no main camera");
                return;
            }

            string outDir = Path.Combine(
                Directory.GetParent(Application.dataPath).FullName, "LabyrinthPreview");
            Directory.CreateDirectory(outDir);

            // These shots frame a whole area at once, which is far enough out that every
            // LODGroup would otherwise pick its LOD1 mesh and the stone detail disappears.
            var lodGroups = root.GetComponentsInChildren<LODGroup>(true);
            foreach (var lg in lodGroups) lg.ForceLOD(0);

            int shots = 0;
            foreach (Transform group in root.transform)
            {
                var b = GroupBounds(group);
                if (!b.HasValue) continue;
                var bounds = b.Value;
                float span = Mathf.Max(bounds.size.x, bounds.size.z, 8f);

                cam.transform.position = bounds.center + new Vector3(0f, span * 0.30f, -span * 0.80f);
                cam.transform.LookAt(bounds.center + Vector3.up * span * 0.05f);
                Shot(cam, Path.Combine(outDir, $"{group.name}_eye.png"));

                cam.transform.position = bounds.center + new Vector3(0f, span * 1.15f, -span * 0.35f);
                cam.transform.LookAt(bounds.center);
                Shot(cam, Path.Combine(outDir, $"{group.name}_top.png"));
                shots += 2;
            }

            // One shot framed like the reference screenshot: standing on the plaza floor at the
            // near rim, looking across the ring at the brazier circle, for side-by-side compare.
            var plaza = root.transform.Find("Area_B");
            // Frame off the floor slab, not the whole group: the perimeter wall drops ~13m
            // below the plaza and would put the camera underground looking up at the arcade.
            var deck = plaza == null ? null : plaza.Cast<Transform>().FirstOrDefault(
                t => t.name.Contains("_floor_") && !t.name.Contains("floorwall"));
            var pb = deck != null ? GroupBounds(deck) : plaza != null ? GroupBounds(plaza) : null;
            if (pb.HasValue)
            {
                var c = pb.Value.center;
                float eye = pb.Value.max.y + 2.4f;
                cam.transform.position = new Vector3(c.x, eye, c.z - pb.Value.size.z * 0.44f);
                cam.transform.LookAt(new Vector3(c.x, eye + 1.5f, c.z + pb.Value.size.z * 0.3f));
                Shot(cam, Path.Combine(outDir, "Compare_eye.png"));
                shots++;
            }

            foreach (var lg in lodGroups) lg.ForceLOD(-1);
            Debug.Log($"[Labyrinth] {shots} screenshot(s) written to {outDir}");
        }

        static void Shot(Camera cam, string path)
        {
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
            File.WriteAllBytes(path, tex.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(tex);
            rt.Release();
            UnityEngine.Object.DestroyImmediate(rt);
        }

        /// <summary>Entry point for -batchmode -executeMethod: import, build, capture.</summary>
        public static void BatchBuildAndCapture()
        {
            LabyrinthImporter.ImportAll();
            BuildScene();
            CaptureScreenshots();
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace("\\", "/");
            string leaf = Path.GetFileName(path);
            if (!AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }
    }
}
