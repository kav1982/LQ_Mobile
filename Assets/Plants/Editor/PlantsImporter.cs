using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using DungeonImport.Editor;
using TirChonaill.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace Plants.Editor
{
    public static class PlantsImporter
    {
        const string Dungeon = "Plants";
        const string PackRoot = "Assets/Plants/_import_pack";
        const string OutRoot = "Assets/Plants";

        static readonly string[] CategoryOrder =
        {
            "tree", "bush", "grass", "flower", "vine", "mushroom", "wood", "plant", "other"
        };

        static readonly Dictionary<string, float> CellSize = new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase)
        {
            { "tree", 9f },
            { "bush", 4.5f },
            { "grass", 3.5f },
            { "flower", 3.5f },
            { "vine", 4.5f },
            { "mushroom", 3f },
            { "wood", 7f },
            { "plant", 4.5f },
            { "other", 4.5f },
        };

        [MenuItem("Tools/Plants/1. Import Plant Assets")]
        public static void ImportAll()
        {
            DungeonPackImporter.ImportAll(Dungeon);
            FixLodStacking();
            BindMissingTextures();
        }

        [MenuItem("Tools/Plants/3. Fix LOD Stacking And Textures")]
        public static void FixLodAndTextures()
        {
            int sh = RebindMmnShaders();
            int lod = FixLodStacking();
            int tex = BindMissingTextures();
            EditorSceneManager.MarkSceneDirty(SceneManager.GetActiveScene());
            EditorSceneManager.SaveOpenScenes();
            Debug.Log($"[Plants] mmnShaders={sh} disabled {lod} stacked impostors, rebound {tex} textures");
        }

        static int RebindMmnShaders()
        {
            int n = 0;
            var byName = new Dictionary<string, Shader>();
            foreach (var guid in AssetDatabase.FindAssets("t:Shader", new[] { "Assets/MMN" }))
            {
                var s = AssetDatabase.LoadAssetAtPath<Shader>(AssetDatabase.GUIDToAssetPath(guid));
                if (s != null && !byName.ContainsKey(s.name)) byName[s.name] = s;
            }
            foreach (var guid in AssetDatabase.FindAssets("t:Material", new[] { OutRoot + "/Materials" }))
            {
                var mat = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if (mat == null || mat.shader == null) continue;
                if (!byName.TryGetValue(mat.shader.name, out var good) || mat.shader == good) continue;
                var tex = mat.HasProperty("_BaseMap") ? mat.GetTexture("_BaseMap") : null;
                var col = mat.HasProperty("_BaseColor") ? mat.GetColor("_BaseColor") : Color.white;
                mat.shader = good;
                if (tex != null)
                {
                    if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", tex);
                    if (mat.HasProperty("_MainTex")) mat.SetTexture("_MainTex", tex);
                }
                if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", col);
                if (mat.HasProperty("_EmissionIntensity") && mat.GetTexture("_EmissionMap") == null)
                    mat.SetFloat("_EmissionIntensity", 0f);
                EditorUtility.SetDirty(mat);
                n++;
            }
            return n;
        }

        static bool IsImpostor(Renderer r)
        {
            if (r == null) return false;
            if (r.name.IndexOf("Impostor", StringComparison.OrdinalIgnoreCase) >= 0) return true;
            var mf = r.GetComponent<MeshFilter>();
            return mf != null && mf.sharedMesh != null
                && mf.sharedMesh.name.IndexOf("Impostor", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        static int FixLodStacking()
        {
            int n = 0;
            var simple = Shader.Find("MMN/BG/SimpleLit");
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { OutRoot + "/Prefabs" }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var root = PrefabUtility.LoadPrefabContents(path);
                try
                {
                    var renderers = root.GetComponentsInChildren<MeshRenderer>(true);
                    var near = new List<MeshRenderer>();
                    var imp = new List<MeshRenderer>();
                    foreach (var r in renderers)
                        (IsImpostor(r) ? imp : near).Add(r);
                    if (imp.Count == 0) continue;
                    if (near.Count > 0)
                    {
                        foreach (var r in imp)
                        {
                            if (!r.enabled) continue;
                            r.enabled = false;
                            n++;
                        }
                    }
                    else if (simple != null)
                    {
                        foreach (var r in imp)
                        {
                            var mats = r.sharedMaterials;
                            bool dirty = false;
                            for (int i = 0; i < mats.Length; i++)
                            {
                                var m = mats[i];
                                if (m == null || m.shader == null) continue;
                                if (m.shader.name.IndexOf("Impostor", StringComparison.OrdinalIgnoreCase) < 0)
                                    continue;
                                var albedo = m.HasProperty("_Albedo") ? m.GetTexture("_Albedo") : null;
                                m.shader = simple;
                                if (albedo != null)
                                {
                                    if (m.HasProperty("_BaseMap")) m.SetTexture("_BaseMap", albedo);
                                    if (m.HasProperty("_MainTex")) m.SetTexture("_MainTex", albedo);
                                }
                                if (m.HasProperty("_ALPHATEST")) m.SetFloat("_ALPHATEST", 1f);
                                if (m.HasProperty("_Cutoff") && m.GetFloat("_Cutoff") <= 0f)
                                    m.SetFloat("_Cutoff", 0.5f);
                                m.EnableKeyword("_ALPHATEST_ON");
                                m.SetOverrideTag("RenderType", "TransparentCutout");
                                m.renderQueue = (int)RenderQueue.AlphaTest;
                                EditorUtility.SetDirty(m);
                                dirty = true;
                            }
                            if (dirty) r.sharedMaterials = mats;
                        }
                    }
                    PrefabUtility.SaveAsPrefabAsset(root, path);
                }
                finally
                {
                    PrefabUtility.UnloadPrefabContents(root);
                }
            }

            foreach (var r in UnityEngine.Object.FindObjectsByType<MeshRenderer>(FindObjectsInactive.Include, FindObjectsSortMode.None))
            {
                if (!r.gameObject.scene.IsValid()) continue;
                if (!IsImpostor(r) || !r.enabled) continue;
                bool hasNear = false;
                var prefabRoot = r.transform.root;
                foreach (var o in prefabRoot.GetComponentsInChildren<MeshRenderer>(true))
                    if (!IsImpostor(o) && o.GetComponent<MeshFilter>() != null
                        && o.GetComponent<MeshFilter>().sharedMesh != null)
                    { hasNear = true; break; }
                if (hasNear) { r.enabled = false; n++; }
            }
            return n;
        }

        static int BindMissingTextures()
        {
            var texByName = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);
            foreach (var guid in AssetDatabase.FindAssets("t:Texture2D", new[] { OutRoot + "/Textures" }))
            {
                string p = AssetDatabase.GUIDToAssetPath(guid);
                var t = AssetDatabase.LoadAssetAtPath<Texture2D>(p);
                if (t != null) texByName[t.name] = t;
            }
            int n = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Material", new[] { OutRoot + "/Materials" }))
            {
                string p = AssetDatabase.GUIDToAssetPath(guid);
                var m = AssetDatabase.LoadAssetAtPath<Material>(p);
                if (m == null) continue;
                bool has = (m.HasProperty("_BaseMap") && m.GetTexture("_BaseMap") != null)
                    || (m.HasProperty("_MainTex") && m.GetTexture("_MainTex") != null)
                    || (m.HasProperty("_Albedo") && m.GetTexture("_Albedo") != null);
                if (has) continue;
                Texture2D tex = null;
                if (!texByName.TryGetValue(m.name, out tex))
                {
                    string alt = m.name.Replace("_Flower", "").Replace("_Grass", "");
                    texByName.TryGetValue(alt, out tex);
                    if (tex == null && m.name.StartsWith("Flower_", StringComparison.OrdinalIgnoreCase))
                        texByName.TryGetValue("Flower_Alpha_" + m.name.Substring("Flower_".Length), out tex);
                }
                if (tex == null) continue;
                if (m.HasProperty("_BaseMap")) m.SetTexture("_BaseMap", tex);
                if (m.HasProperty("_MainTex")) m.SetTexture("_MainTex", tex);
                EditorUtility.SetDirty(m);
                n++;
            }
            return n;
        }

        [MenuItem("Tools/Plants/2. Build Overview Grid")]
        public static void BuildOverviewGrid()
        {
            string prefabDir = OutRoot + "/Prefabs";
            if (!AssetDatabase.IsValidFolder(prefabDir))
            {
                Debug.LogError("[Plants] no prefabs - run Tools/Plants/1. Import Plant Assets first");
                return;
            }

            var catById = LoadCategories();
            var grouped = new Dictionary<string, List<GameObject>>(StringComparer.OrdinalIgnoreCase);
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { prefabDir }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (prefab == null) continue;
                if (prefab.GetComponentsInChildren<Renderer>(true).Length == 0) continue;
                string id = prefab.name;
                string cat = catById.TryGetValue(id, out var c) ? c : InferCategory(id);
                if (!grouped.TryGetValue(cat, out var list))
                {
                    list = new List<GameObject>();
                    grouped[cat] = list;
                }
                list.Add(prefab);
            }

            if (grouped.Count == 0)
            {
                Debug.LogError("[Plants] no plant prefabs found");
                return;
            }

            foreach (var list in grouped.Values)
                list.Sort((a, b) => string.CompareOrdinal(a.name, b.name));

            EnsureFolder(OutRoot + "/Scenes");
            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var lightGo = new GameObject("Directional Light");
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.97f, 0.9f);
            light.intensity = 2.2f;
            light.shadows = LightShadows.Soft;
            lightGo.transform.rotation = Quaternion.Euler(45f, -35f, 0f);

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.55f, 0.62f, 0.7f);
            RenderSettings.ambientEquatorColor = new Color(0.4f, 0.42f, 0.32f);
            RenderSettings.ambientGroundColor = new Color(0.22f, 0.2f, 0.16f);
            RenderSettings.fog = false;

            var root = new GameObject("PlantCollection");
            float z = 0f;
            float maxX = 0f;
            int placed = 0;

            foreach (var cat in CategoryOrder.Concat(grouped.Keys.Where(k => !CategoryOrder.Contains(k, StringComparer.OrdinalIgnoreCase))))
            {
                if (!grouped.TryGetValue(cat, out var list) || list.Count == 0) continue;
                float cell = CellSize.TryGetValue(cat, out var cs) ? cs : 8f;
                int cols = Mathf.Max(10, Mathf.CeilToInt(Mathf.Sqrt(list.Count * 2.2f)));
                var row = new GameObject(cat);
                row.transform.SetParent(root.transform, false);
                row.transform.position = new Vector3(0f, 0f, z);

                for (int i = 0; i < list.Count; i++)
                {
                    int cx = i % cols;
                    int cz = i / cols;
                    var inst = (GameObject)PrefabUtility.InstantiatePrefab(list[i]);
                    inst.transform.SetParent(row.transform, false);
                    float gx = row.transform.position.x + cx * cell;
                    float gz = row.transform.position.z + cz * cell;
                    inst.transform.position = new Vector3(gx, 0f, gz);
                    var b = Encapsulate(inst);
                    if (b.size.sqrMagnitude > 0.0001f)
                        inst.transform.position += new Vector3(gx - b.center.x, -b.min.y, gz - b.center.z);
                    placed++;
                }

                int rows = Mathf.CeilToInt(list.Count / (float)cols);
                maxX = Mathf.Max(maxX, cols * cell);
                z += rows * cell + cell * 0.35f;
            }

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            float span = Mathf.Max(maxX, z);
            ground.transform.position = new Vector3(maxX * 0.5f, -0.02f, z * 0.5f);
            ground.transform.localScale = new Vector3(Mathf.Max(10f, span / 8f), 1f, Mathf.Max(10f, span / 8f));
            var gmat = new Material(Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard"));
            gmat.color = new Color(0.42f, 0.48f, 0.32f);
            ground.GetComponent<MeshRenderer>().sharedMaterial = gmat;

            var camGo = new GameObject("Main Camera");
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.62f, 0.72f, 0.82f);
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 2000f;
            cam.fieldOfView = 50f;
            camGo.AddComponent<UniversalAdditionalCameraData>();
            camGo.AddComponent<AudioListener>();
            camGo.transform.position = new Vector3(40f, 16f, -48f);
            camGo.transform.LookAt(new Vector3(40f, 6f, 12f));

            FixLodStacking();
            BindMissingTextures();

            string scenePath = OutRoot + "/Scenes/Plants_Overview.unity";
            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError("[Plants] failed to save " + scenePath);
                return;
            }
            Debug.Log($"[Plants] overview grid {placed} plants -> {scenePath}");
        }

        static Dictionary<string, string> LoadCategories()
        {
            var map = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            string catalogPath = PackRoot + "/catalog.json";
            if (!File.Exists(catalogPath)) return map;
            var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
            var packages = catalog != null && catalog.TryGetValue("packages", out var p) ? p as List<object> : null;
            if (packages == null) return map;
            foreach (var o in packages)
            {
                var pkg = o as Dictionary<string, object>;
                if (pkg == null) continue;
                string id = pkg.TryGetValue("id", out var iv) ? Convert.ToString(iv) : null;
                string cat = pkg.TryGetValue("category", out var cv) ? Convert.ToString(cv) : null;
                if (!string.IsNullOrEmpty(id) && !string.IsNullOrEmpty(cat))
                    map[id] = cat;
            }
            return map;
        }

        static string InferCategory(string name)
        {
            string n = name.ToLowerInvariant();
            if (n.Contains("mushroom")) return "mushroom";
            if (n.Contains("stump") || n.StartsWith("log") || n.Contains("tree_dry") || n.Contains("bush_dry")) return "wood";
            if (n.StartsWith("tree") || n.Contains("swing") || n.Contains("maple")) return "tree";
            if (n.StartsWith("bush")) return "bush";
            if (n.StartsWith("grass") || n.Contains("wheat") || n.Contains("reed") || n.Contains("lavender")) return "grass";
            if (n.Contains("flower") || n.Contains("lotus") || n.Contains("bouquet")) return "flower";
            if (n.Contains("vine") || n.Contains("ivy")) return "vine";
            if (n.Contains("bracken") || n.Contains("agave")) return "plant";
            return "other";
        }

        static Bounds Encapsulate(GameObject go)
        {
            var b = new Bounds();
            bool have = false;
            foreach (var r in go.GetComponentsInChildren<Renderer>())
            {
                if (!have) { b = r.bounds; have = true; }
                else b.Encapsulate(r.bounds);
            }
            return b;
        }

        static void EnsureFolder(string assetPath)
        {
            if (AssetDatabase.IsValidFolder(assetPath)) return;
            string parent = Path.GetDirectoryName(assetPath).Replace("\\", "/");
            string name = Path.GetFileName(assetPath);
            if (!AssetDatabase.IsValidFolder(parent))
                EnsureFolder(parent);
            if (!AssetDatabase.IsValidFolder(assetPath))
                AssetDatabase.CreateFolder(parent, name);
        }
    }
}
