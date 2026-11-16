using System;
using System.Collections.Generic;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace SidheSneachta.Editor
{
    public static class SidheSneachtaPreviewSetup
    {
        static readonly string[] SkipWorldScale =
        {
            "terrain", "far_terrain", "skybox", "fx_waterfall_00"
        };

        static readonly string[] CategoryOrder =
        {
            "Vegetation", "Cliff", "Building", "Cave", "Other"
        };

        [MenuItem("Tools/SidheSneachta/2. Build Overview Grid")]
        public static void BuildScene()
        {
            var grouped = new Dictionary<string, List<GameObject>>(StringComparer.OrdinalIgnoreCase);
            AddPrefabs("Assets/Worlds/SidheSneachta/Prefabs", grouped, fromPlants: false);
            AddPrefabs("Assets/Props/Plants/Prefabs", grouped, fromPlants: true);

            int total = grouped.Sum(kv => kv.Value.Count);
            if (total == 0)
            {
                Debug.LogError("[SidheSneachta] no object prefabs");
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
            light.color = new Color(0.95f, 0.97f, 1f);
            light.intensity = 1.6f;
            light.shadows = LightShadows.Soft;
            lightGo.transform.rotation = Quaternion.Euler(45f, -35f, 0f);

            RenderSettings.fog = false;
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.72f, 0.82f, 0.92f);
            RenderSettings.ambientEquatorColor = new Color(0.55f, 0.60f, 0.66f);
            RenderSettings.ambientGroundColor = new Color(0.40f, 0.42f, 0.45f);

            var root = new GameObject("SidheSneachta_Objects");
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
                    HideLodAndBlockers(inst);
                    if (p.name.IndexOf("icewell", StringComparison.OrdinalIgnoreCase) >= 0)
                        AttachWaterfallFx(inst);
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
            gmat.color = new Color(0.78f, 0.82f, 0.86f);
            ground.GetComponent<MeshRenderer>().sharedMaterial = gmat;

            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.62f, 0.72f, 0.82f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 2000f;
            cam.fieldOfView = 50f;
            camGo.AddComponent<AudioListener>();
            camGo.transform.position = new Vector3(24f, 18f, -32f);
            camGo.transform.LookAt(new Vector3(24f, 4f, 12f));

            string scenePath = "Assets/Worlds/SidheSneachta/Scenes/SidheSneachta_Preview.unity";
            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError("[SidheSneachta] failed to save " + scenePath);
                return;
            }
            Debug.Log($"[SidheSneachta] overview grid {placed} objects -> {scenePath}");
        }

        static void AddPrefabs(string folder, Dictionary<string, List<GameObject>> grouped, bool fromPlants)
        {
            if (!AssetDatabase.IsValidFolder(folder)) return;
            foreach (var guid in AssetDatabase.FindAssets("t:Prefab", new[] { folder }))
            {
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(AssetDatabase.GUIDToAssetPath(guid));
                if (prefab == null) continue;
                if (prefab.GetComponentsInChildren<Renderer>(true).Length == 0) continue;
                if (SkipWorldScale.Contains(prefab.name, StringComparer.OrdinalIgnoreCase)) continue;
                if (fromPlants && !IsSidhePlant(prefab.name)) continue;
                string cat = fromPlants ? "Vegetation" : CategoryOf(prefab.name);
                if (!grouped.TryGetValue(cat, out var list))
                {
                    list = new List<GameObject>();
                    grouped[cat] = list;
                }
                if (list.Any(p => p.name == prefab.name)) continue;
                list.Add(prefab);
            }
        }

        static void AttachWaterfallFx(GameObject icewell)
        {
            var fx = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Worlds/SidheSneachta/Prefabs/fx_waterfall_00.prefab");
            if (fx == null) return;
            var inst = (GameObject)PrefabUtility.InstantiatePrefab(fx);
            inst.name = "FX_Waterfall_00";
            inst.transform.SetParent(icewell.transform, false);
            var water = icewell.transform.Find("Sid_Water_01");
            inst.transform.position = water != null
                ? water.position
                : icewell.transform.position;
            inst.transform.localScale = Vector3.one;
            foreach (var t in inst.GetComponentsInChildren<Transform>(true))
            {
                if (t.name == "Wave_02" || t.name == "Line_01")
                    t.gameObject.SetActive(false);
            }
            foreach (var ps in inst.GetComponentsInChildren<ParticleSystem>(true))
            {
                var main = ps.main;
                main.loop = true;
                var pr = ps.GetComponent<ParticleSystemRenderer>();
                if (pr != null && pr.maxParticleSize > 1f)
                    pr.maxParticleSize = 0.5f;
                ps.Play(true);
            }
        }

        static void HideLodAndBlockers(GameObject inst)
        {
            foreach (var t in inst.GetComponentsInChildren<Transform>(true))
            {
                string n = t.name;
                if (n.IndexOf("LOD1", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("LOD2", StringComparison.OrdinalIgnoreCase) >= 0
                    || n.IndexOf("CameraBlocking", StringComparison.OrdinalIgnoreCase) >= 0)
                    t.gameObject.SetActive(false);
            }
        }

        static bool IsSidhePlant(string name)
        {
            string n = name.ToLowerInvariant();
            return n.Contains("sidhesneachta");
        }

        static string CategoryOf(string name)
        {
            string n = name.ToLowerInvariant();
            if (n.Contains("tree") || n.Contains("bush") || n.Contains("plane") || n.Contains("branch"))
                return "Vegetation";
            if (n.Contains("cliff"))
                return "Cliff";
            if (n.Contains("altar") || n.Contains("signboard") || n.Contains("icewell") || n.Contains("broken"))
                return "Building";
            if (n.Contains("cave") || n.Contains("tarlach"))
                return "Cave";
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
