using MMN.PostProcessing;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

namespace MMN.Editor
{
    public static class MMNPostProcessingReproScene
    {
        const string Root = "Assets/MMN/PostProcessing";
        const string ScenePath = Root + "/Scenes/MMN_PostProcessing_Repro.unity";

        [MenuItem("Tools/MMN/Post Processing/Create Reproduction Scene")]
        public static void Create()
        {
            EnsureFolder(Root + "/Scenes");
            EnsureFolder(Root + "/Materials");

            var previous = SceneManager.GetActiveScene();
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);

            BuildCamera();
            BuildLighting();
            BuildTestObjects();

            EditorSceneManager.SaveScene(scene, ScenePath);
            AssetDatabase.SaveAssets();
            EditorSceneManager.CloseScene(scene, true);
            if (previous.IsValid()) SceneManager.SetActiveScene(previous);

            Debug.Log($"[MMN PostProcessing] Reproduction scene created: {ScenePath}");
        }

        static void BuildCamera()
        {
            var go = new GameObject("Main Camera") { tag = "MainCamera" };
            go.transform.position = new Vector3(0f, 3f, -12f);
            go.transform.rotation = Quaternion.Euler(8f, 0f, 0f);

            var camera = go.AddComponent<Camera>();
            camera.allowHDR = true;
            camera.fieldOfView = 45f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.025f, 0.035f, 0.055f, 1f);

            var cameraData = go.AddComponent<UniversalAdditionalCameraData>();
            cameraData.renderPostProcessing = true;
            cameraData.antialiasing = AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            cameraData.antialiasingQuality = AntialiasingQuality.High;

        }

        static void BuildLighting()
        {
            var go = new GameObject("Directional Light");
            go.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
            var light = go.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.2f;
            light.color = new Color(1f, 0.92f, 0.82f);
            light.shadows = LightShadows.Soft;

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.18f, 0.25f, 0.38f);
            RenderSettings.ambientEquatorColor = new Color(0.09f, 0.11f, 0.16f);
            RenderSettings.ambientGroundColor = new Color(0.025f, 0.03f, 0.04f);
        }

        static void BuildTestObjects()
        {
            var neutral = CreateMaterial("Neutral", new Color(0.45f, 0.55f, 0.68f), Color.black);
            var warm = CreateMaterial("WarmEmission", new Color(0.5f, 0.18f, 0.05f), new Color(8f, 1.6f, 0.25f));
            var cool = CreateMaterial("CoolEmission", new Color(0.03f, 0.25f, 0.45f), new Color(0.2f, 3f, 8f));

            var ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
            ground.name = "Ground";
            ground.transform.localScale = new Vector3(3f, 1f, 3f);
            ground.GetComponent<Renderer>().sharedMaterial = neutral;

            CreatePrimitive(PrimitiveType.Sphere, "Bloom Warm", new Vector3(-3f, 1.2f, 0f), Vector3.one * 1.8f, warm);
            CreatePrimitive(PrimitiveType.Sphere, "Bloom Cool", new Vector3(3f, 1.2f, 0f), Vector3.one * 1.8f, cool);
            CreatePrimitive(PrimitiveType.Cube, "Midtone Reference", new Vector3(0f, 1f, 2f), new Vector3(2f, 2f, 2f), neutral);

            for (int i = 0; i < 9; i++)
            {
                float x = (i % 3 - 1) * 2.5f;
                float y = i / 3 * 1.3f + 0.5f;
                float z = 5.5f;
                CreatePrimitive(PrimitiveType.Cube, "Depth Marker " + (i + 1), new Vector3(x, y, z), Vector3.one * 0.7f, neutral);
            }
        }

        static void CreatePrimitive(PrimitiveType type, string name, Vector3 position, Vector3 scale, Material material)
        {
            var go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.position = position;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = material;
        }

        static Material CreateMaterial(string name, Color baseColor, Color emission)
        {
            string path = $"{Root}/Materials/{name}.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (material == null)
            {
                material = new Material(Shader.Find("Universal Render Pipeline/Lit")) { name = name };
                AssetDatabase.CreateAsset(material, path);
            }

            material.SetColor("_BaseColor", baseColor);
            material.SetColor("_EmissionColor", emission);
            if (emission.maxColorComponent > 0f) material.EnableKeyword("_EMISSION");
            else material.DisableKeyword("_EMISSION");
            EditorUtility.SetDirty(material);
            return material;
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = System.IO.Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, System.IO.Path.GetFileName(path));
        }
    }
}
