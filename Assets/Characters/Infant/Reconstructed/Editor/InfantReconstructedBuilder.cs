using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Characters.Infant.Editor
{
    public static class InfantReconstructedBuilder
    {
        const string Root = "Assets/Characters/Infant";
        const string SourceRoot = Root + "/Source/patchableassets";
        const string ReconstructedRoot = Root + "/Reconstructed";
        const string MaterialsRoot = ReconstructedRoot + "/Materials";
        const string PrefabPath = ReconstructedRoot + "/Prefabs/Infant_Cute_01_Reconstructed.prefab";
        const string ScenePath = ReconstructedRoot + "/Scenes/InfantCharacterReconstructed.unity";
        const string DefaultInfantMouthPath = SourceRoot + "/character/player/human/facial/customize/infant/mouth/Infant_Lips_00.png";

        static readonly Dictionary<string, string> ShaderMap = new Dictionary<string, string>
        {
            { "MMN/CH/Standard", "Characters/Infant/Reconstructed/Standard" },
            { "MMN/CH/Skin_Body", "Characters/Infant/Reconstructed/SkinBody" },
            { "MMN/CH/Skin_Face", "Characters/Infant/Reconstructed/SkinFace" },
            { "MMN/CH/Eye_Pupil", "Characters/Infant/Reconstructed/EyePupil" },
            { "MMN/CH/Eye_Base", "Characters/Infant/Reconstructed/EyeBase" },
            { "MMN/CH/Eye_Emotion", "Characters/Infant/Reconstructed/EyeEmotion" },
            { "MMN/CH/Eye_Shade_Highlight", "Characters/Infant/Reconstructed/EyeShadeHighlight" },
            { "MMN/CH/Hair_Shadow", "Characters/Infant/Reconstructed/HairShadow" },
            { "MMN/BG/SimpleLit", "Characters/Infant/Reconstructed/SimpleLit" },
        };

        static readonly Dictionary<Material, Material> MaterialCache = new Dictionary<Material, Material>();

        [MenuItem("Tools/Characters/Infant/Build Reconstructed Sample")]
        public static void BuildSample()
        {
            EnsureFolder(MaterialsRoot);
            EnsureFolder(ReconstructedRoot + "/Prefabs");
            EnsureFolder(ReconstructedRoot + "/Scenes");
            EnsureFolder(ReconstructedRoot + "/Previews");

            var prefab = BuildPrefab();
            BuildScene(prefab);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[InfantReconstructed] build complete: " + PrefabPath + ", " + ScenePath);
        }

        static GameObject BuildPrefab()
        {
            MaterialCache.Clear();
            var root = new GameObject("Infant_Cute_01_Reconstructed");
            try
            {
                AddPart(root.transform, "Body", Source("character/player/human/fbx/Infant_Body_00.prefab"));
                AddPart(root.transform, "Head", Source("character/player/human/facial/customize/infant/head/Infant_Head_F_Default_00.prefab"));
                AddPart(root.transform, "Eye", Source("character/player/human/facial/customize/infant/eye/Infant_Eye_08.prefab"));
                AddPart(root.transform, "Hair", Source("character/player/human/fbx/human/infant/hair/Infant_Hair_Twintail_03.prefab"));
                AddPart(root.transform, "OnePiece", Source("character/player/human/fbx/human/infant/onepiece/Infant_Kindergarten_F_OnePiece_00.prefab"));
                AddPart(root.transform, "Shoes", Source("character/player/human/fbx/human/infant/shoes/Infant_Kindergarten_Shoes_00.prefab"));
                return PrefabUtility.SaveAsPrefabAsset(root, PrefabPath);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(root);
            }
        }

        static void AddPart(Transform parent, string label, string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null) throw new InvalidOperationException("Source prefab is missing: " + path);

            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            instance.name = label + " - " + prefab.name;
            instance.transform.SetParent(parent, false);

            foreach (var animator in instance.GetComponentsInChildren<Animator>(true))
                animator.enabled = false;

            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
            {
                renderer.sharedMaterials = renderer.sharedMaterials.Select(GetOrCreateMaterial).ToArray();
                if (ShouldHideInNormalPreview(renderer.name))
                {
                    renderer.gameObject.SetActive(false);
                }
            }
        }

        static bool ShouldHideInNormalPreview(string objectName)
        {
            return objectName == "Mesh_EyeBasePlane" ||
                   objectName.StartsWith("Mesh_BP_", StringComparison.Ordinal) ||
                   objectName.StartsWith("Mesh_SP_", StringComparison.Ordinal);
        }

        static Material GetOrCreateMaterial(Material source)
        {
            if (source == null) return null;
            if (MaterialCache.TryGetValue(source, out var cached)) return cached;

            string sourceShaderName = source.shader != null ? source.shader.name : string.Empty;
            if (!ShaderMap.TryGetValue(sourceShaderName, out string targetShaderName))
                throw new InvalidOperationException("No reconstructed shader mapping for: " + sourceShaderName);

            var targetShader = Shader.Find(targetShaderName);
            if (targetShader == null) throw new InvalidOperationException("Reconstructed shader is missing: " + targetShaderName);

            string sourcePath = AssetDatabase.GetAssetPath(source);
            string guid = AssetDatabase.AssetPathToGUID(sourcePath);
            string safeName = string.Concat(source.name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
            string materialPath = $"{MaterialsRoot}/{safeName}_{guid.Substring(0, 8)}.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (material == null)
            {
                material = new Material(targetShader) { name = source.name + " (Reconstructed)" };
                AssetDatabase.CreateAsset(material, materialPath);
            }
            else
            {
                material.shader = targetShader;
            }

            CopyMatchingProperties(source, material);
            if (targetShaderName == "Characters/Infant/Reconstructed/SkinFace" &&
                source.name == "Infant_HeadA_00" &&
                material.GetTexture("_MouthMap") == null)
            {
                var defaultMouth = AssetDatabase.LoadAssetAtPath<Texture2D>(DefaultInfantMouthPath);
                material.SetTexture("_MouthMap", defaultMouth);
                material.SetTextureScale("_MouthMap", Vector2.one);
                material.SetTextureOffset("_MouthMap", Vector2.zero);
                material.SetFloat("_MouthShowType", 0f);
            }
            if (material.HasProperty("_HasBaseMap"))
                material.SetFloat("_HasBaseMap", source.HasProperty("_BaseMap") && source.GetTexture("_BaseMap") != null ? 1f : 0f);
            material.renderQueue = -1;
            EditorUtility.SetDirty(material);
            MaterialCache[source] = material;
            return material;
        }

        static void CopyMatchingProperties(Material source, Material destination)
        {
            Shader shader = destination.shader;
            int propertyCount = ShaderUtil.GetPropertyCount(shader);
            for (int i = 0; i < propertyCount; i++)
            {
                string propertyName = ShaderUtil.GetPropertyName(shader, i);
                if (!source.HasProperty(propertyName)) continue;

                switch (ShaderUtil.GetPropertyType(shader, i))
                {
                    case ShaderUtil.ShaderPropertyType.Color:
                        destination.SetColor(propertyName, source.GetColor(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.Vector:
                        destination.SetVector(propertyName, source.GetVector(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.Float:
                    case ShaderUtil.ShaderPropertyType.Range:
                        destination.SetFloat(propertyName, source.GetFloat(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.TexEnv:
                        destination.SetTexture(propertyName, source.GetTexture(propertyName));
                        destination.SetTextureScale(propertyName, source.GetTextureScale(propertyName));
                        destination.SetTextureOffset(propertyName, source.GetTextureOffset(propertyName));
                        break;
                }
            }
        }

        static void BuildScene(GameObject prefab)
        {
            if (prefab == null) throw new InvalidOperationException("Reconstructed prefab was not created.");

            Scene previous = SceneManager.GetActiveScene();
            Scene scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);
            try
            {
                var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                instance.transform.SetPositionAndRotation(Vector3.zero, Quaternion.identity);
                BuildCamera();
                BuildLighting();
                BuildGround();
                EditorSceneManager.SaveScene(scene, ScenePath);
            }
            finally
            {
                EditorSceneManager.CloseScene(scene, true);
                if (previous.IsValid()) SceneManager.SetActiveScene(previous);
            }
        }

        static void BuildCamera()
        {
            var cameraObject = new GameObject("Main Camera") { tag = "MainCamera" };
            cameraObject.transform.position = new Vector3(0f, 0.75f, 2.1f);
            cameraObject.transform.LookAt(new Vector3(0f, 0.65f, 0f));
            var camera = cameraObject.AddComponent<Camera>();
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
            UnityEngine.Object.DestroyImmediate(ground.GetComponent<Collider>());

            var material = new Material(Shader.Find("Universal Render Pipeline/Lit"))
            {
                name = "Preview Pedestal",
                color = new Color(0.18f, 0.22f, 0.3f),
            };
            ground.GetComponent<Renderer>().sharedMaterial = material;
        }

        static string Source(string relative)
        {
            return SourceRoot + "/" + relative;
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
