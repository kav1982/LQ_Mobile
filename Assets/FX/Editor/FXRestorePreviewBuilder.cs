using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace FX.Editor
{
    /// <summary>
    /// Builds Assets/FX/Scene/FX_TestEnvironmentRestored.unity: the 114 environment FX
    /// restored after the September pack, laid out in one band per source folder.
    /// Particle systems only animate in Play mode; Scene view previews a selected object.
    /// </summary>
    public static class FXRestorePreviewBuilder
    {
        const string ScenePath = "Assets/FX/Scene/FX_TestEnvironmentRestored.unity";
        const string EnvRoot = "Assets/FX/1_effect/environment";
        const string ExtractRoot = @"D:/MabinogiMobile_TW/appdata/_re_work";
        const string MissingJson = ExtractRoot + "/fx_env_missing.json";

        static readonly string[] BandOrder =
        {
            "area_border", "actionprop", "aquariumtank", "dungeon", "prop", "housing", "town",
        };

        [MenuItem("MMN/FX/8. Build Restored FX Preview Scene")]
        public static void Build()
        {
            var ids = new List<string>();
            ids.AddRange(Collect("aquariumtank", "fx_aquariumtank_*.prefab"));
            ids.AddRange(Collect("area_border", "fx_abyss_pathblocker_deactivate_*.prefab"));
            ids.AddRange(Collect("actionprop", "fx_quest_button*.prefab"));
            ids.AddRange(Collect("actionprop", "fx_wedding_common_startzone_*.prefab"));
            ids.AddRange(ReadMissing());
            ids = ids.Distinct().OrderBy(i => i, StringComparer.Ordinal).ToList();
            if (ids.Count == 0)
            {
                Debug.LogError("[FX] no restored prefabs found");
                return;
            }

            EditorSceneManager.SaveOpenScenes();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var camGo = new GameObject("PreviewCamera");
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.04f, 0.05f, 0.07f, 1f);
            cam.fieldOfView = 55f;
            cam.nearClipPlane = 0.1f;
            cam.farClipPlane = 2000f;
            camGo.AddComponent<AudioListener>();

            var lightGo = new GameObject("PreviewLight");
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.6f;
            lightGo.transform.rotation = Quaternion.Euler(50f, 145f, 0f);

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.28f, 0.30f, 0.34f);

            var root = new GameObject("RestoredFX").transform;
            float z = 0f;
            int placed = 0, skipped = 0;
            float minX = float.MaxValue, maxX = float.MinValue, maxZ = float.MinValue;

            foreach (var folder in BandOrder)
            {
                var group = ids.Where(i => FolderOf(i) == folder).ToList();
                if (group.Count == 0) continue;

                int cols = group.Count <= 4 ? group.Count : group.Count <= 16 ? 4 : group.Count <= 30 ? 6 : 10;
                float spacing = folder == "area_border" || folder == "town" ? 16f : 8f;
                int rows = (group.Count + cols - 1) / cols;

                var band = new GameObject($"{folder} ({group.Count})");
                band.transform.SetParent(root, false);
                band.transform.localPosition = new Vector3(0f, 0f, z);

                for (int i = 0; i < group.Count; i++)
                {
                    string path = "Assets/FX/" + group[i] + ".prefab";
                    var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                    if (prefab == null)
                    {
                        Debug.LogWarning("[FX] preview missing " + path);
                        skipped++;
                        continue;
                    }
                    var go = (GameObject)PrefabUtility.InstantiatePrefab(prefab, band.transform);
                    go.transform.localPosition = new Vector3((i % cols) * spacing, 0f, (i / cols) * spacing);
                    placed++;
                }

                float bandWidth = (cols - 1) * spacing;
                float bandDepth = (rows - 1) * spacing;
                minX = Mathf.Min(minX, -bandWidth * 0.5f);
                maxX = Mathf.Max(maxX, bandWidth * 0.5f);
                maxZ = Mathf.Max(maxZ, z + bandDepth);
                z += bandDepth + 14f;
            }

            var center = new Vector3((minX + maxX) * 0.5f, 0f, maxZ * 0.5f);
            float span = Mathf.Max(maxX - minX, maxZ);
            camGo.transform.position = center + new Vector3(0f, span * 0.85f, -span * 0.95f);
            camGo.transform.rotation = Quaternion.LookRotation(center - camGo.transform.position, Vector3.up);

            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
            {
                Debug.LogError("[FX] failed to save " + ScenePath);
                return;
            }
            Debug.Log($"[FX] preview scene {ScenePath} placed={placed} skipped={skipped} bands={BandOrder.Length}");
        }

        static string FolderOf(string id)
        {
            var parts = id.Split('/');
            return parts.Length > 2 ? parts[2] : "";
        }

        static IEnumerable<string> Collect(string folder, string pattern)
        {
            string dir = EnvRoot + "/" + folder;
            if (!AssetDatabase.IsValidFolder(dir)) return Array.Empty<string>();
            return Directory.GetFiles(dir, pattern)
                .Select(Path.GetFileNameWithoutExtension)
                .Select(n => $"1_effect/environment/{folder}/{n}")
                .OrderBy(n => n, StringComparer.Ordinal)
                .ToList();
        }

        static IEnumerable<string> ReadMissing()
        {
            if (!File.Exists(MissingJson))
            {
                Debug.LogWarning("[FX] " + MissingJson + " not found; restoring the first batch only");
                return Array.Empty<string>();
            }
            return Regex.Matches(File.ReadAllText(MissingJson), "\"id\"\\s*:\\s*\"([^\"]+)\"")
                .Select(m => m.Groups[1].Value)
                .ToList();
        }
    }
}
