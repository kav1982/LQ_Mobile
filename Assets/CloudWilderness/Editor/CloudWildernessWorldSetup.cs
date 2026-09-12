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
    public static class CloudWildernessWorldSetup
    {
        const string PrefabRoot = "Assets/CloudWilderness/Prefabs";
        const string ScenePath = "Assets/CloudWilderness/Scenes/CloudWilderness_World.unity";

        static readonly string[] WorldPrefabs =
        {
            "terrain_fine",
            "gpu_grass",
            "far_terrain",
            "cliff_merge",
            "light",
            "decal",
        };

        [MenuItem("Tools/CloudWilderness/3. Build World Scene")]
        public static void BuildScene()
        {
            var prefabs = new List<(string id, GameObject prefab)>();
            foreach (var id in WorldPrefabs)
            {
                string path = $"{PrefabRoot}/{id}.prefab";
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (prefab == null)
                {
                    Debug.LogWarning("[CloudWilderness] missing world prefab " + path);
                    continue;
                }
                prefabs.Add((id, prefab));
            }

            if (prefabs.Count == 0)
            {
                Debug.LogError("[CloudWilderness] no world prefabs - run Import Scene Assets first");
                return;
            }

            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var root = new GameObject("CloudWilderness_World");
            SceneManager.MoveGameObjectToScene(root, scene);

            foreach (var (id, prefab) in prefabs)
            {
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                inst.name = id;
                inst.transform.SetParent(root.transform, true);
            }

            SnapGpuGrassToFineTerrain();

            if (UnityEngine.Object.FindObjectOfType<Light>() == null)
            {
                var lightGo = new GameObject("Directional Light");
                SceneManager.MoveGameObjectToScene(lightGo, scene);
                var light = lightGo.AddComponent<Light>();
                light.type = LightType.Directional;
                light.color = new Color(1f, 0.91f, 0.72f);
                light.intensity = 1.45f;
                light.shadows = LightShadows.Soft;
                lightGo.transform.rotation = Quaternion.Euler(42f, -20f, 0f);
            }

            RenderSettings.fog = false;
            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.86f, 0.80f, 0.68f);
            RenderSettings.ambientEquatorColor = new Color(0.62f, 0.54f, 0.42f);
            RenderSettings.ambientGroundColor = new Color(0.38f, 0.32f, 0.24f);

            var bounds = EncapsulateScene(root);
            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.78f, 0.72f, 0.58f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.3f;
            cam.farClipPlane = 8000f;
            cam.fieldOfView = 50f;
            camGo.AddComponent<AudioListener>();

            var center = bounds.center;
            float radius = Mathf.Max(bounds.extents.x, bounds.extents.z, 40f);
            camGo.transform.position = center + new Vector3(-radius * 0.55f, Mathf.Clamp(radius * 0.35f, 40f, 280f), -radius * 0.55f);
            camGo.transform.LookAt(center);

            EnsureFolder("Assets/CloudWilderness/Scenes");
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
            {
                Debug.LogError("[CloudWilderness] failed to save " + ScenePath);
                return;
            }
            Debug.Log($"[CloudWilderness] world scene {prefabs.Count} roots, bounds={bounds.size} -> {ScenePath}");
        }

        [MenuItem("Tools/CloudWilderness/3b. Snap GPU Grass To Terrain")]
        public static void SnapGpuGrassToFineTerrain()
        {
            var grassGo = GameObject.Find("gpu_grass");
            var terrain = GameObject.Find("terrain_fine");
            if (grassGo == null || terrain == null)
            {
                Debug.LogWarning("[CloudWilderness] snap skipped — need gpu_grass and terrain_fine in the open scene");
                return;
            }
            var draw = grassGo.GetComponent<CloudWildernessGpuGrass>();
            if (draw == null || draw.batches == null)
            {
                Debug.LogWarning("[CloudWilderness] snap skipped — gpu_grass has no batches");
                return;
            }

            var added = new List<MeshCollider>();
            foreach (var mf in terrain.GetComponentsInChildren<MeshFilter>(true))
            {
                if (mf.sharedMesh == null) continue;
                var col = mf.GetComponent<MeshCollider>();
                if (col == null)
                {
                    col = mf.gameObject.AddComponent<MeshCollider>();
                    col.sharedMesh = mf.sharedMesh;
                    added.Add(col);
                }
            }
            Physics.SyncTransforms();

            const float threshold = 0.4f;
            int snapped = 0, tested = 0;
            foreach (var batch in draw.batches)
            {
                if (batch == null || batch.matrices == null) continue;
                var mats = batch.matrices;
                for (int i = 0; i < mats.Length; i++)
                {
                    var p = new Vector3(mats[i].m03, mats[i].m13, mats[i].m23);
                    tested++;
                    var hits = Physics.RaycastAll(p + Vector3.up * 80f, Vector3.down, 300f);
                    RaycastHit? best = null;
                    float bestY = float.MinValue;
                    foreach (var hit in hits)
                    {
                        if (!hit.transform.IsChildOf(terrain.transform) && hit.transform != terrain.transform)
                            continue;
                        if (hit.point.y > bestY)
                        {
                            bestY = hit.point.y;
                            best = hit;
                        }
                    }
                    if (!best.HasValue) continue;
                    float d = p.y - best.Value.point.y;
                    if (Mathf.Abs(d) <= threshold) continue;
                    var m = mats[i];
                    m.m13 = best.Value.point.y;
                    mats[i] = m;
                    snapped++;
                }
            }

            foreach (var col in added)
                UnityEngine.Object.DestroyImmediate(col);

            if (snapped > 0)
            {
                EditorUtility.SetDirty(draw);
                if (PrefabUtility.IsPartOfPrefabInstance(grassGo))
                    PrefabUtility.ApplyPrefabInstance(grassGo, InteractionMode.AutomatedAction);
            }
            Debug.Log($"[CloudWilderness] snapped {snapped}/{tested} grass instances (|ΔY|>{threshold})");
        }

        static Bounds EncapsulateScene(GameObject root)
        {
            var rs = root.GetComponentsInChildren<MeshRenderer>(true)
                .Where(r => r.GetComponent<ParticleSystem>() == null)
                .ToList();
            if (rs.Count == 0) return new Bounds(Vector3.zero, Vector3.one * 80f);
            var b = rs[0].bounds;
            foreach (var r in rs.Skip(1)) b.Encapsulate(r.bounds);
            return b;
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = System.IO.Path.GetDirectoryName(path).Replace("\\", "/");
            string leaf = System.IO.Path.GetFileName(path);
            if (!AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }
    }
}
