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

namespace TreasureBox.Editor
{
    public static class TreasureBoxImporter
    {
        const string Dungeon = "TreasureBox";
        const string PackRoot = "Assets/Props/TreasureBox/_import_pack";
        const string OutRoot = "Assets/Props/TreasureBox";

        static readonly string[] CategoryOrder =
        {
            "dungeon", "size", "special", "smash", "contents", "mimic"
        };

        static readonly Dictionary<string, float> CellSize = new Dictionary<string, float>(StringComparer.OrdinalIgnoreCase)
        {
            { "dungeon", 3.2f },
            { "size", 3.4f },
            { "special", 3.4f },
            { "smash", 3.0f },
            { "contents", 2.2f },
            { "mimic", 4.8f },
        };

        [MenuItem("Tools/TreasureBox/1. Import Treasure Box Assets")]
        public static void ImportAll()
        {
            DungeonPackImporter.ImportAll(Dungeon);
            RemapPreviewShaders();
            HideGoldOverlays();
        }

        static bool ShouldRemapShader(string name)
        {
            return name == "MMN/CH/Standard" || name == "MMN/FX/SimpleLit_Prop_Dissolve";
        }

        static bool IsGoldOverlay(string name)
        {
            if (string.IsNullOrEmpty(name)) return false;
            if (name.IndexOf("goldcoin", StringComparison.OrdinalIgnoreCase) >= 0) return false;
            return name.IndexOf("_Gold", StringComparison.OrdinalIgnoreCase) >= 0
                || name.EndsWith("Gold", StringComparison.OrdinalIgnoreCase);
        }

        static int RemapPreviewShaders()
        {
            var simple = Shader.Find("MMN/BG/SimpleLit");
            if (simple == null) return 0;
            int n = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Material", new[] { OutRoot + "/Materials" }))
            {
                var mat = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(guid));
                if (mat == null || mat.shader == null) continue;
                if (!ShouldRemapShader(mat.shader.name)) continue;
                var tex = mat.HasProperty("_BaseMap") ? mat.GetTexture("_BaseMap") : null;
                if (tex == null && mat.HasProperty("_MainTex")) tex = mat.GetTexture("_MainTex");
                var col = mat.HasProperty("_BaseColor") ? mat.GetColor("_BaseColor") : Color.white;
                mat.shader = simple;
                if (tex != null)
                {
                    if (mat.HasProperty("_BaseMap")) mat.SetTexture("_BaseMap", tex);
                    if (mat.HasProperty("_MainTex")) mat.SetTexture("_MainTex", tex);
                }
                if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", col);
                if (mat.HasProperty("_EmissionIntensity")) mat.SetFloat("_EmissionIntensity", 0f);
                EditorUtility.SetDirty(mat);
                n++;
            }
            if (n > 0) AssetDatabase.SaveAssets();
            return n;
        }

        static int HideGoldOverlays()
        {
            int n = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { OutRoot + "/Prefabs" }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var root = PrefabUtility.LoadPrefabContents(path);
                try
                {
                    bool dirty = false;
                    foreach (var r in root.GetComponentsInChildren<Renderer>(true))
                    {
                        if (!IsGoldOverlay(r.name) || !r.enabled) continue;
                        r.enabled = false;
                        dirty = true;
                        n++;
                    }
                    if (dirty) PrefabUtility.SaveAsPrefabAsset(root, path);
                }
                finally
                {
                    PrefabUtility.UnloadPrefabContents(root);
                }
            }
            return n;
        }

        [MenuItem("Tools/TreasureBox/2. Build Showcase Scene")]
        public static void BuildShowcase()
        {
            string prefabDir = OutRoot + "/Prefabs";
            if (!AssetDatabase.IsValidFolder(prefabDir))
            {
                Debug.LogError("[TreasureBox] no prefabs - run Tools/TreasureBox/1. Import Treasure Box Assets first");
                return;
            }

            var catById = LoadCategories();
            var grouped = new Dictionary<string, List<GameObject>>(StringComparer.OrdinalIgnoreCase);
            int skipped = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { prefabDir }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (prefab == null) continue;
                if (prefab.GetComponentsInChildren<Renderer>(true).Length == 0)
                {
                    skipped++;
                    continue;
                }
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
                Debug.LogError("[TreasureBox] no treasure-box prefabs with renderers");
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
            light.color = new Color(1f, 0.96f, 0.88f);
            light.intensity = 1.8f;
            light.shadows = LightShadows.Soft;
            lightGo.transform.rotation = Quaternion.Euler(42f, -30f, 0f);

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.48f, 0.52f, 0.6f);
            RenderSettings.ambientEquatorColor = new Color(0.36f, 0.34f, 0.3f);
            RenderSettings.ambientGroundColor = new Color(0.18f, 0.16f, 0.14f);
            RenderSettings.fog = false;

            var root = new GameObject("TreasureBoxCollection");
            float z = 0f;
            float maxX = 0f;
            int placed = 0;

            foreach (var cat in CategoryOrder.Concat(grouped.Keys.Where(k => !CategoryOrder.Contains(k, StringComparer.OrdinalIgnoreCase))))
            {
                if (!grouped.TryGetValue(cat, out var list) || list.Count == 0) continue;
                float cell = CellSize.TryGetValue(cat, out var cs) ? cs : 4f;
                int cols = Mathf.Clamp(list.Count, 1, cat == "mimic" ? 6 : 8);
                var row = new GameObject(cat);
                row.transform.SetParent(root.transform, false);
                row.transform.position = new Vector3(0f, 0f, z);

                int rowCount = 1;
                for (int i = 0; i < list.Count; i++)
                {
                    int cx = i % cols;
                    int cz = i / cols;
                    rowCount = cz + 1;
                    float gx = cx * cell;
                    float gz = z + cz * cell;
                    var inst = (GameObject)PrefabUtility.InstantiatePrefab(list[i]);
                    inst.transform.SetParent(row.transform, false);
                    inst.transform.position = new Vector3(gx, 0f, gz);
                    var b = Encapsulate(inst);
                    if (b.size.sqrMagnitude > 0.0001f)
                        inst.transform.position += new Vector3(gx - b.center.x, -b.min.y, gz - b.center.z);
                    placed++;
                }

                maxX = Mathf.Max(maxX, cols * cell);
                z += rowCount * cell + cell * 0.7f;
            }

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            float spanX = Mathf.Max(12f, maxX + 6f);
            float spanZ = Mathf.Max(12f, z + 4f);
            ground.transform.position = new Vector3(maxX * 0.5f - 1f, -0.02f, z * 0.5f);
            ground.transform.localScale = new Vector3(spanX / 10f, 1f, spanZ / 10f);
            var gmat = new Material(Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard"));
            gmat.color = new Color(0.22f, 0.22f, 0.24f);
            ground.GetComponent<MeshRenderer>().sharedMaterial = gmat;

            var camGo = new GameObject("Main Camera");
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.16f, 0.17f, 0.2f);
            cam.nearClipPlane = 0.2f;
            cam.farClipPlane = 2000f;
            cam.fieldOfView = 35f;
            camGo.AddComponent<UniversalAdditionalCameraData>();
            camGo.AddComponent<AudioListener>();
            camGo.transform.position = new Vector3(maxX * 0.45f, Mathf.Max(18f, z * 0.55f), -Mathf.Max(16f, z * 0.35f));
            camGo.transform.LookAt(new Vector3(maxX * 0.45f, 0.4f, z * 0.42f));

            HideGoldOverlays();
            RemapPreviewShaders();

            string scenePath = OutRoot + "/Scenes/TreasureBox_Showcase.unity";
            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError("[TreasureBox] failed to save " + scenePath);
                return;
            }
            Debug.Log($"[TreasureBox] showcase {placed} items (skipped {skipped} empty) -> {scenePath}");
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
            if (n.StartsWith("monster_mimic_")) return "mimic";
            if (n.StartsWith("monster_treasurebox_")) return "smash";
            if (n == "goldcoin_00" || n.StartsWith("treasure_0")) return "contents";
            if (n.Contains("alby") || n.Contains("ciar") || n.Contains("math") || n.Contains("rabbie")) return "dungeon";
            if (n.Contains("battle") || n.Contains("blackportal") || n.Contains("fieldboss")
                || n.Contains("raid") || n.Contains("catalyst") || n.StartsWith("treasure_box"))
                return "special";
            return "size";
        }

        static Bounds Encapsulate(GameObject go)
        {
            var b = new Bounds();
            bool have = false;
            foreach (var r in go.GetComponentsInChildren<Renderer>())
            {
                if (r is MeshRenderer == false && r is SkinnedMeshRenderer == false) continue;
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
