using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Characters.Infant;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Characters.Infant.Editor
{
    public static class InfantCharacterBuilder
    {
        const string Root = "Assets/Characters/Infant";
        const string SourceRoot = Root + "/Source";
        const string GeneratedRoot = Root + "/Generated";
        const string CatalogPath = GeneratedRoot + "/InfantCharacterCatalog.asset";
        const string PreviewShaderPath = Root + "/Shaders/InfantPreview.shader";
        const string PreviewPrefabPath = GeneratedRoot + "/Prefabs/Infant_Cute_01.prefab";
        const string PreviewScenePath = GeneratedRoot + "/Scenes/InfantCharacterOverview.unity";

        static readonly Dictionary<Material, Material> PreviewMaterialCache =
            new Dictionary<Material, Material>();

        [MenuItem("Tools/Characters/Infant/Build Catalog And Preview")]
        public static void BuildAll()
        {
            EnsureFolder(GeneratedRoot);
            EnsureFolder(GeneratedRoot + "/Materials");
            EnsureFolder(GeneratedRoot + "/Prefabs");
            EnsureFolder(GeneratedRoot + "/Scenes");

            var catalog = BuildCatalog();
            var prefab = BuildPreviewPrefab();
            BuildPreviewScene(catalog, prefab);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[InfantCharacter] build complete: {catalog.entries.Count} catalog entries, " +
                      $"prefab {PreviewPrefabPath}, scene {PreviewScenePath}");
        }

        static InfantCharacterCatalog BuildCatalog()
        {
            var catalog = AssetDatabase.LoadAssetAtPath<InfantCharacterCatalog>(CatalogPath);
            if (catalog == null)
            {
                catalog = ScriptableObject.CreateInstance<InfantCharacterCatalog>();
                AssetDatabase.CreateAsset(catalog, CatalogPath);
            }

            var entries = new List<InfantCharacterEntry>();
            foreach (string guid in AssetDatabase.FindAssets("t:Prefab", new[] { SourceRoot }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!TryClassifyPrefab(path, out var category)) continue;
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                if (prefab == null) continue;
                entries.Add(NewEntry(prefab.name, category, path, prefab: prefab));
            }

            foreach (string guid in AssetDatabase.FindAssets("t:AnimationClip", new[] { SourceRoot }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!path.Replace('\\', '/').ToLowerInvariant().Contains("/animation/player/human/infant/") ||
                    !Path.GetFileNameWithoutExtension(path).ToLowerInvariant().Contains("_facial")) continue;
                var clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(path);
                if (clip == null) continue;
                entries.Add(NewEntry(clip.name, InfantCharacterCategory.FacialAnimation, path, animation: clip));
            }

            foreach (string guid in AssetDatabase.FindAssets("t:Texture2D", new[] { SourceRoot }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (!TryClassifyFaceTexture(path, out var category)) continue;
                var texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                if (texture == null) continue;
                entries.Add(NewEntry(texture.name, category, path, texture: texture));
            }

            catalog.entries = entries
                .OrderBy(entry => entry.category)
                .ThenBy(entry => entry.displayName, StringComparer.OrdinalIgnoreCase)
                .ToList();
            EditorUtility.SetDirty(catalog);

            string counts = string.Join(", ", catalog.entries
                .GroupBy(entry => entry.category)
                .Select(group => group.Key + "=" + group.Count()));
            Debug.Log("[InfantCharacter] catalog: " + counts);
            return catalog;
        }

        static InfantCharacterEntry NewEntry(
            string displayName,
            InfantCharacterCategory category,
            string path,
            GameObject prefab = null,
            AnimationClip animation = null,
            Texture2D texture = null)
        {
            return new InfantCharacterEntry
            {
                displayName = displayName,
                category = category,
                sourcePath = path,
                prefab = prefab,
                animation = animation,
                texture = texture,
            };
        }

        static bool TryClassifyPrefab(string path, out InfantCharacterCategory category)
        {
            string normalized = path.Replace('\\', '/').ToLowerInvariant();
            string file = Path.GetFileNameWithoutExtension(normalized);
            category = default;

            if (normalized.Contains("/character/player/human/fbx/") &&
                !normalized.Contains("/fbx/human/") &&
                (file.StartsWith("infant_body_") || file.StartsWith("infantmale_body_")))
            {
                category = InfantCharacterCategory.Body;
                return true;
            }

            if (normalized.Contains("/facial/customize/infant/head/"))
                category = InfantCharacterCategory.Head;
            else if (normalized.Contains("/facial/customize/infant/eye/"))
                category = InfantCharacterCategory.Eye;
            else if (normalized.Contains("/facial/customize/infant/") ||
                     (normalized.Contains("/facial/customize/") && file.StartsWith("infant_")))
                category = InfantCharacterCategory.FaceAccessory;
            else if (normalized.Contains("/character/player/human/infant/hair/"))
                category = InfantCharacterCategory.Hair;
            else if (normalized.Contains("/character/player/human/infant/top/"))
                category = InfantCharacterCategory.Top;
            else if (normalized.Contains("/character/player/human/infant/bottom/"))
                category = InfantCharacterCategory.Bottom;
            else if (normalized.Contains("/character/player/human/infant/onepiece/"))
                category = InfantCharacterCategory.OnePiece;
            else if (normalized.Contains("/character/player/human/infant/shoes/"))
                category = InfantCharacterCategory.Shoes;
            else if (normalized.Contains("/character/player/human/infant/gloves/"))
                category = InfantCharacterCategory.Gloves;
            else if (normalized.Contains("/character/player/human/infant/helmet/"))
                category = InfantCharacterCategory.Helmet;
            else if (normalized.Contains("/character/player/human/infant/robe/"))
                category = InfantCharacterCategory.Robe;
            else if (normalized.Contains("/character/player/human/infant/etc/"))
                category = InfantCharacterCategory.Etc;
            else
                return false;
            return true;
        }

        static bool TryClassifyFaceTexture(string path, out InfantCharacterCategory category)
        {
            string normalized = path.Replace('\\', '/').ToLowerInvariant();
            category = default;
            if (normalized.Contains("/facial/customize/infant/mouth/"))
            {
                category = InfantCharacterCategory.MouthTexture;
                return true;
            }
            if (normalized.Contains("/facial/customize/tattoo/infant_"))
            {
                category = InfantCharacterCategory.FaceDecal;
                return true;
            }
            return false;
        }

        static GameObject BuildPreviewPrefab()
        {
            PreviewMaterialCache.Clear();
            var root = new GameObject("Infant_Cute_01");
            try
            {
                AddPersistentPart(root.transform, "Body", Source("character/player/human/fbx/Infant_Body_00.prefab"));
                AddPersistentPart(root.transform, "Head", Source("character/player/human/facial/customize/infant/head/Infant_Head_F_Default_00.prefab"));
                AddPersistentPart(root.transform, "Eye", Source("character/player/human/facial/customize/infant/eye/Infant_Eye_08.prefab"));
                AddPersistentPart(root.transform, "Hair", Source("character/player/human/fbx/human/infant/hair/Infant_Hair_Twintail_03.prefab"));
                AddPersistentPart(root.transform, "OnePiece", Source("character/player/human/fbx/human/infant/onepiece/Infant_Kindergarten_F_OnePiece_00.prefab"));
                AddPersistentPart(root.transform, "Shoes", Source("character/player/human/fbx/human/infant/shoes/Infant_Kindergarten_Shoes_00.prefab"));

                return PrefabUtility.SaveAsPrefabAsset(root, PreviewPrefabPath);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(root);
            }
        }

        static void AddPersistentPart(Transform parent, string label, string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null)
            {
                Debug.LogWarning("[InfantCharacter] preview part not found: " + path);
                return;
            }

            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            instance.name = label + " - " + prefab.name;
            instance.transform.SetParent(parent, false);
            foreach (var animator in instance.GetComponentsInChildren<Animator>(true))
                animator.enabled = false;
            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
                renderer.sharedMaterials = renderer.sharedMaterials.Select(GetOrCreatePreviewMaterial).ToArray();
        }

        static Material GetOrCreatePreviewMaterial(Material source)
        {
            if (source == null) return null;
            if (PreviewMaterialCache.TryGetValue(source, out var cached)) return cached;

            var shader = AssetDatabase.LoadAssetAtPath<Shader>(PreviewShaderPath);
            if (shader == null) throw new InvalidOperationException("Preview shader is missing: " + PreviewShaderPath);

            string sourcePath = AssetDatabase.GetAssetPath(source);
            string guid = AssetDatabase.AssetPathToGUID(sourcePath);
            string safeName = string.Concat(source.name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
            string materialPath = $"{GeneratedRoot}/Materials/{safeName}_{guid.Substring(0, 8)}.mat";
            var preview = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (preview == null)
            {
                preview = new Material(shader) { name = source.name + " (Preview)" };
                AssetDatabase.CreateAsset(preview, materialPath);
            }

            InfantPreviewMaterialUtility.CopyProperties(source, preview);
            EditorUtility.SetDirty(preview);
            PreviewMaterialCache[source] = preview;
            return preview;
        }

        static void BuildPreviewScene(InfantCharacterCatalog catalog, GameObject previewPrefab)
        {
            var previous = SceneManager.GetActiveScene();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);

            var controllerObject = new GameObject("Infant Character Catalog Preview");
            var controller = controllerObject.AddComponent<InfantCharacterPreviewController>();
            controller.catalog = catalog;
            controller.previewShader = AssetDatabase.LoadAssetAtPath<Shader>(PreviewShaderPath);
            controller.body = LoadPreviewPart("character/player/human/fbx/Infant_Body_00.prefab");
            controller.head = LoadPreviewPart("character/player/human/facial/customize/infant/head/Infant_Head_F_Default_00.prefab");
            controller.eye = LoadPreviewPart("character/player/human/facial/customize/infant/eye/Infant_Eye_08.prefab");
            controller.hair = LoadPreviewPart("character/player/human/fbx/human/infant/hair/Infant_Hair_Twintail_03.prefab");
            controller.onePiece = LoadPreviewPart("character/player/human/fbx/human/infant/onepiece/Infant_Kindergarten_F_OnePiece_00.prefab");
            controller.shoes = LoadPreviewPart("character/player/human/fbx/human/infant/shoes/Infant_Kindergarten_Shoes_00.prefab");
            controller.Rebuild();

            BuildCamera(controllerObject.transform);
            BuildLighting();
            BuildGround();

            EditorSceneManager.SaveScene(scene, PreviewScenePath);
            EditorSceneManager.CloseScene(scene, true);
            if (previous.IsValid()) SceneManager.SetActiveScene(previous);
        }

        static GameObject LoadPreviewPart(string relative)
        {
            return AssetDatabase.LoadAssetAtPath<GameObject>(Source(relative));
        }

        static void BuildCamera(Transform target)
        {
            var go = new GameObject("Main Camera") { tag = "MainCamera" };
            go.transform.position = new Vector3(0f, 0.75f, 2.1f);
            go.transform.LookAt(new Vector3(0f, 0.65f, 0f));
            var camera = go.AddComponent<Camera>();
            camera.fieldOfView = 30f;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = 50f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.12f, 0.16f, 0.22f, 1f);
        }

        static void BuildLighting()
        {
            var key = new GameObject("Key Light");
            key.transform.rotation = Quaternion.Euler(35f, 145f, 0f);
            var keyLight = key.AddComponent<Light>();
            keyLight.type = LightType.Directional;
            keyLight.intensity = 1.3f;
            keyLight.color = new Color(1f, 0.9f, 0.82f);
            keyLight.shadows = LightShadows.Soft;

            var fill = new GameObject("Fill Light");
            fill.transform.position = new Vector3(-1.5f, 1.2f, 1.2f);
            var fillLight = fill.AddComponent<Light>();
            fillLight.type = LightType.Point;
            fillLight.range = 5f;
            fillLight.intensity = 2f;
            fillLight.color = new Color(0.6f, 0.75f, 1f);

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.35f, 0.4f, 0.5f);
            RenderSettings.ambientEquatorColor = new Color(0.18f, 0.2f, 0.25f);
            RenderSettings.ambientGroundColor = new Color(0.08f, 0.08f, 0.1f);
        }

        static void BuildGround()
        {
            var ground = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            ground.name = "Preview Pedestal";
            ground.transform.position = new Vector3(0f, -0.04f, 0f);
            ground.transform.localScale = new Vector3(0.65f, 0.04f, 0.65f);
            var material = new Material(Shader.Find("Universal Render Pipeline/Lit"))
            {
                name = "Preview Pedestal",
                color = new Color(0.18f, 0.22f, 0.3f),
            };
            ground.GetComponent<Renderer>().sharedMaterial = material;
        }

        static string Source(string relative)
        {
            return SourceRoot + "/patchableassets/" + relative;
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }
    }
}
