using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace CloudWilderness.Editor
{
    public static class CloudWildernessPreviewSetup
    {
        static readonly string[] SkipWorldScale =
        {
            "terrain", "terrain_fine", "gpu_grass", "far_terrain", "skybox", "cliff_merge", "light", "decal"
        };

        static readonly string[] CategoryOrder =
        {
            "Vegetation", "Building", "Cliff", "Rock", "Prop", "Other"
        };

        [MenuItem("Tools/CloudWilderness/2. Build Overview Grid")]
        public static void BuildScene()
        {
            var grouped = new Dictionary<string, List<GameObject>>(StringComparer.OrdinalIgnoreCase);
            AddPrefabs("Assets/Worlds/CloudWilderness/Prefabs", grouped);

            int total = grouped.Sum(kv => kv.Value.Count);
            if (total == 0)
            {
                Debug.LogError("[CloudWilderness] no object prefabs");
                return;
            }
            foreach (var list in grouped.Values)
                list.Sort((a, b) => string.CompareOrdinal(a.name, b.name));

            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var lightGo = new GameObject("Directional Light");
            SceneManager.MoveGameObjectToScene(lightGo, scene);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(1f, 0.92f, 0.75f);
            light.intensity = 1.55f;
            light.shadows = LightShadows.Soft;
            lightGo.transform.rotation = Quaternion.Euler(42f, -20f, 0f);

            RenderSettings.fog = false;
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.86f, 0.80f, 0.68f);
            RenderSettings.ambientEquatorColor = new Color(0.62f, 0.54f, 0.42f);
            RenderSettings.ambientGroundColor = new Color(0.38f, 0.32f, 0.24f);

            var root = new GameObject("CloudWilderness_Objects");
            SceneManager.MoveGameObjectToScene(root, scene);

            float z = 0f;
            float maxX = 0f;
            int placed = 0;
            const float gap = 24f;

            foreach (var cat in CategoryOrder.Concat(grouped.Keys.Where(k =>
                         !CategoryOrder.Contains(k, StringComparer.OrdinalIgnoreCase))))
            {
                if (!grouped.TryGetValue(cat, out var list) || list.Count == 0) continue;

                var row = new GameObject(cat);
                row.transform.SetParent(root.transform, false);

                float x = 0f;
                float rowDepth = 0f;
                foreach (var p in list)
                {
                    var inst = (GameObject)PrefabUtility.InstantiatePrefab(p);
                    inst.transform.SetParent(row.transform, true);
                    var b = Encapsulate(inst);
                    float sx = Mathf.Max(4f, b.size.x) + gap;
                    float sz = Mathf.Max(4f, b.size.z) + gap;
                    inst.transform.position = new Vector3(
                        x + b.size.x * 0.5f - b.center.x,
                        -b.min.y,
                        z + b.size.z * 0.5f - b.center.z);
                    x += sx;
                    rowDepth = Mathf.Max(rowDepth, sz);
                    placed++;
                }

                maxX = Mathf.Max(maxX, x);
                z += rowDepth + gap;
            }

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            SceneManager.MoveGameObjectToScene(ground, scene);
            float span = Mathf.Max(maxX, z, 40f);
            ground.transform.position = new Vector3(maxX * 0.5f, -0.02f, z * 0.5f);
            ground.transform.localScale = new Vector3(Mathf.Max(8f, span / 10f), 1f, Mathf.Max(8f, span / 10f));
            var gmat = new Material(Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard"));
            gmat.color = new Color(0.72f, 0.62f, 0.42f);
            ground.GetComponent<MeshRenderer>().sharedMaterial = gmat;

            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.78f, 0.72f, 0.58f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 2000f;
            cam.fieldOfView = 50f;
            camGo.AddComponent<AudioListener>();
            camGo.transform.position = new Vector3(24f, 18f, -32f);
            camGo.transform.LookAt(new Vector3(24f, 4f, 12f));

            string scenePath = "Assets/Worlds/CloudWilderness/Scenes/CloudWilderness_Preview.unity";
            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError("[CloudWilderness] failed to save " + scenePath);
                return;
            }
            Debug.Log($"[CloudWilderness] overview grid {placed} objects -> {scenePath}");
        }

        static void AddPrefabs(string folder, Dictionary<string, List<GameObject>> grouped)
        {
            if (!AssetDatabase.IsValidFolder(folder)) return;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { folder }))
            {
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(AssetDatabase.GUIDToAssetPath(guid));
                if (prefab == null) continue;
                var renderers = prefab.GetComponentsInChildren<Renderer>(true);
                if (renderers.Length == 0) continue;
                bool textured = renderers.SelectMany(r => r.sharedMaterials)
                    .Any(m => m != null && m.HasProperty("_BaseMap") && m.GetTexture("_BaseMap") != null);
                if (!textured) continue;
                if (SkipWorldScale.Contains(prefab.name, StringComparer.OrdinalIgnoreCase)) continue;
                string cat = CategoryOf(prefab.name);
                if (!grouped.TryGetValue(cat, out var list))
                {
                    list = new List<GameObject>();
                    grouped[cat] = list;
                }
                if (list.Any(p => p.name == prefab.name)) continue;
                list.Add(prefab);
            }
        }

        static string CategoryOf(string name)
        {
            string n = name.ToLowerInvariant();
            if (n.Contains("flower") || n.Contains("grass") || n.Contains("tree") || n.Contains("bush"))
                return "Vegetation";
            if (n.Contains("tent") || n.Contains("cage") || n.Contains("landmark") || n.Contains("sign")
                || n.Contains("table"))
                return "Building";
            if (n.Contains("cliff") || n.Contains("mountain"))
                return "Cliff";
            if (n.Contains("rock") || n.Contains("stone") || n.Contains("stonepile"))
                return "Rock";
            if (n.Contains("rut") || n.Contains("decal") || n.Contains("light"))
                return "Prop";
            return "Other";
        }

        static Bounds Encapsulate(GameObject go)
        {
            var rs = go.GetComponentsInChildren<MeshRenderer>(true)
                .Where(r => r.GetComponent<ParticleSystem>() == null)
                .ToList();
            if (rs.Count == 0) return new Bounds(go.transform.position, Vector3.one * 4f);

            var centers = rs.Select(r => r.bounds.center).OrderBy(c => c.x + c.z).ToList();
            var mid = centers[centers.Count / 2];
            Bounds? b = null;
            foreach (var r in rs)
            {
                if ((r.bounds.center - mid).sqrMagnitude > 50f * 50f) continue;
                if (Mathf.Max(r.bounds.size.x, r.bounds.size.z) > 180f) continue;
                if (b == null) b = r.bounds;
                else
                {
                    var t = b.Value;
                    t.Encapsulate(r.bounds);
                    b = t;
                }
            }
            return b ?? rs[0].bounds;
        }
    }
}
