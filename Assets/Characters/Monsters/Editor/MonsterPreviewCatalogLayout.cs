using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace Characters.Monsters.Editor
{
    public static class MonsterPreviewCatalogLayout
    {
        const int Columns = 7;
        const float PadX = 0.16f;
        const float PadY = 0.18f;
        const float MinCellX = 1.55f;
        const float MinCellY = 2.15f;
        const float GroupGap = 0.45f;
        const string RendererPath = "Assets/Settings/URP-HighFidelity-Renderer.asset";
        const string ShotFolder = "Assets/MonsterShot";
        const int ShotSize = 8000;

        static readonly string[] Remaining =
        {
            "Slime", "Earthen", "Mud", "Spider", "Rat", "Digger",
            "Golem", "Gnoll", "Kobold", "Skeleton", "Ratman", "GhostArmor"
        };

        static readonly string[] AllFamilies =
        {
            "Goblin", "Slime", "Earthen", "Mud", "Spider", "Rat", "Digger",
            "Golem", "Gnoll", "Kobold", "Skeleton", "Ratman", "GhostArmor"
        };

        [MenuItem("Tools/Characters/Monsters/Catalog Remaining Previews + 4096")]
        public static void RunRemaining()
        {
            Debug.Log(Run(Remaining));
        }

        [MenuItem("Tools/Characters/Monsters/Recapture All Previews 8000")]
        public static void RecaptureAll8000Menu()
        {
            Debug.Log(Recapture(AllFamilies, ShotSize));
        }

        public static string Recapture(string[] names, int size)
        {
            Directory.CreateDirectory(ToAbs(ShotFolder));
            var report = new System.Text.StringBuilder();
            try
            {
                SetMmnPost(false, false);
                for (int i = 0; i < names.Length; i++)
                    report.AppendLine(CaptureOne(names[i], size));
            }
            finally
            {
                SetMmnPost(true, true);
                AssetDatabase.SaveAssets();
            }
            return report.ToString();
        }

        static string CaptureOne(string family, int size)
        {
            string scenePath = "Assets/Characters/Monsters/" + family + "/Scenes/" + family + "_Preview.unity";
            if (!File.Exists(ToAbs(scenePath)))
                return family + ": MISSING " + scenePath;

            EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
            Camera cam = Camera.main;
            if (cam == null)
            {
                var cams = UnityEngine.Object.FindObjectsOfType<Camera>();
                if (cams.Length > 0) cam = cams[0];
            }
            if (cam == null)
                return family + ": no camera";

            string fileName = family + "_Preview_8000.png";
            string rel = CaptureSquare(cam, size, fileName);
            return family + ": " + rel;
        }

        public static string Run(string[] names)
        {
            var report = new System.Text.StringBuilder();
            try
            {
                SetMmnPost(false, false);
                for (int i = 0; i < names.Length; i++)
                {
                    report.AppendLine(ProcessOne(names[i]));
                }
            }
            finally
            {
                SetMmnPost(true, true);
                AssetDatabase.SaveAssets();
            }
            return report.ToString();
        }

        static string ProcessOne(string family)
        {
            string scenePath = "Assets/Characters/Monsters/" + family + "/Scenes/" + family + "_Preview.unity";
            if (!File.Exists(ToAbs(scenePath)))
                return family + ": MISSING " + scenePath;

            var scene = EditorSceneManager.OpenScene(scenePath, OpenSceneMode.Single);
            var roots = scene.GetRootGameObjects();
            var groups = new List<Transform>();
            Camera cam = null;
            GameObject ground = null;

            for (int i = 0; i < roots.Length; i++)
            {
                var go = roots[i];
                if (go.GetComponent<Camera>() != null)
                {
                    cam = go.GetComponent<Camera>();
                    continue;
                }
                if (go.GetComponent<Light>() != null)
                    continue;
                if (go.name.IndexOf("Ground", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    ground = go;
                    continue;
                }
                if (CountPreviewChildren(go.transform) > 0)
                    groups.Add(go.transform);
            }

            if (groups.Count == 0)
                return family + ": no preview groups";
            if (cam == null)
                return family + ": no camera";

            var ordered = new List<Transform>();
            if (groups.Count >= 2)
            {
                ordered.Add(groups[groups.Count - 1]);
                for (int i = 0; i < groups.Count - 1; i++)
                    ordered.Add(groups[i]);
            }
            else
            {
                ordered.Add(groups[0]);
            }

            var groupKids = new List<Transform>[ordered.Count];
            float maxW = 0f;
            float maxH = 0f;
            int total = 0;
            for (int g = 0; g < ordered.Count; g++)
            {
                groupKids[g] = CollectPreviewChildren(ordered[g]);
                total += groupKids[g].Count;
                for (int i = 0; i < groupKids[g].Count; i++)
                    AccSize(groupKids[g][i], ref maxW, ref maxH);
            }

            int cols = Mathf.Min(Columns, Mathf.Max(1, MaxCount(groupKids)));
            float cellX = Mathf.Max(MinCellX, maxW + PadX);
            float cellY = Mathf.Max(MinCellY, maxH + PadY);

            var tops = new float[ordered.Count];
            float y = 0f;
            for (int g = ordered.Count - 1; g >= 0; g--)
            {
                int rows = Mathf.Max(1, (groupKids[g].Count + cols - 1) / cols);
                float top = y + (rows - 1) * cellY;
                tops[g] = top;
                y = top + cellY + GroupGap;
            }

            Undo.IncrementCurrentGroup();
            int undo = Undo.GetCurrentGroup();
            Undo.SetCurrentGroupName("Catalog " + family);

            for (int g = 0; g < ordered.Count; g++)
            {
                string baseName = StripIndexPrefix(ordered[g].name);
                string titled = (g + 1).ToString("00") + ". " + baseName;
                Undo.RecordObject(ordered[g].gameObject, "rename");
                ordered[g].gameObject.name = titled;

                for (int i = 0; i < groupKids[g].Count; i++)
                {
                    int row = i / cols;
                    int col = i % cols;
                    int visualCol = (cols - 1) - col;
                    var t = groupKids[g][i];
                    Undo.RecordObject(t, "layout");
                    t.localPosition = new Vector3(visualCol * cellX, tops[g] - row * cellY, 0f);
                    t.localRotation = Quaternion.identity;
                    EditorUtility.SetDirty(t);
                }

                UpsertGroupLabel(ordered[g], titled, (cols - 1) * cellX + 3.35f, tops[g] + Mathf.Min(1.15f, maxH * 0.45f));
            }

            if (ground != null)
            {
                Undo.RecordObject(ground, "hide ground");
                ground.SetActive(false);
                EditorUtility.SetDirty(ground);
            }

            Bounds catalog = EncapsulateCatalog(ordered);
            if (catalog.size.sqrMagnitude > 0.001f)
                catalog.Expand(0.45f);
            Vector3 center = catalog.center;
            float ortho = Mathf.Max(catalog.extents.y, catalog.extents.x) + 0.35f;

            Undo.RecordObject(cam.transform, "cam");
            Undo.RecordObject(cam, "cam lens");
            cam.orthographic = true;
            cam.orthographicSize = ortho;
            cam.nearClipPlane = 0.1f;
            cam.farClipPlane = Mathf.Max(80f, catalog.size.magnitude * 4f);
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.18f, 0.18f, 0.18f, 1f);
            cam.transform.rotation = Quaternion.Euler(0f, 180f, 0f);
            cam.transform.position = new Vector3(center.x, center.y, catalog.max.z + 18f);
            EditorUtility.SetDirty(cam);

            var sceneView = SceneView.lastActiveSceneView;
            if (sceneView != null)
            {
                sceneView.orthographic = true;
                sceneView.LookAtDirect(new Vector3(center.x, center.y, 0f), Quaternion.Euler(0f, 180f, 0f),
                    Mathf.Max(catalog.size.y * 0.51f, catalog.size.x * 0.58f));
                sceneView.sceneViewState.showSkybox = false;
                sceneView.Repaint();
            }

            EditorSceneManager.MarkSceneDirty(scene);
            EditorSceneManager.SaveScene(scene);
            Undo.CollapseUndoOperations(undo);

            string shotPath = CaptureSquare(cam, 4096, family + "_Preview_4096.png");
            return family + ": n=" + total + " groups=" + ordered.Count +
                   " cell=" + cellX.ToString("F2") + "x" + cellY.ToString("F2") +
                   " catalog=" + catalog.size.ToString("F1") +
                   " shot=" + shotPath;
        }

        static int MaxCount(List<Transform>[] groups)
        {
            int max = 1;
            for (int i = 0; i < groups.Length; i++)
            {
                if (groups[i].Count > max)
                    max = groups[i].Count;
            }
            return max;
        }

        static string StripIndexPrefix(string name)
        {
            if (name.Length >= 4 && char.IsDigit(name[0]) && char.IsDigit(name[1]) && name[2] == '.' && name[3] == ' ')
                return name.Substring(4);
            return name;
        }

        static int CountPreviewChildren(Transform parent)
        {
            return CollectPreviewChildren(parent).Count;
        }

        static List<Transform> CollectPreviewChildren(Transform parent)
        {
            var list = new List<Transform>();
            for (int i = 0; i < parent.childCount; i++)
            {
                var c = parent.GetChild(i);
                if (c.name == "Label" || c.name == "GroupLabel")
                    continue;
                if (c.GetComponent<TextMesh>() != null)
                    continue;
                list.Add(c);
            }
            return list;
        }

        static void AccSize(Transform t, ref float maxW, ref float maxH)
        {
            var rends = t.GetComponentsInChildren<Renderer>(true);
            bool has = false;
            Bounds b = new Bounds();
            for (int i = 0; i < rends.Length; i++)
            {
                if (rends[i] is ParticleSystemRenderer) continue;
                if (rends[i].GetComponent<TextMesh>() != null) continue;
                if (!rends[i].enabled) continue;
                if (!has)
                {
                    b = rends[i].bounds;
                    has = true;
                }
                else b.Encapsulate(rends[i].bounds);
            }
            if (!has) return;
            if (b.size.x > maxW) maxW = b.size.x;
            if (b.size.y > maxH) maxH = b.size.y;
        }

        static void UpsertGroupLabel(Transform parent, string text, float x, float y)
        {
            Transform existing = parent.Find("GroupLabel");
            if (existing == null)
                existing = parent.Find("Label");
            GameObject labelGo;
            if (existing != null && (existing.GetComponent<TextMesh>() != null || existing.childCount == 0))
            {
                labelGo = existing.gameObject;
                labelGo.name = "GroupLabel";
            }
            else
            {
                labelGo = new GameObject("GroupLabel");
                Undo.RegisterCreatedObjectUndo(labelGo, "group label");
                labelGo.transform.SetParent(parent, false);
            }

            var tm = labelGo.GetComponent<TextMesh>();
            if (tm == null)
                tm = labelGo.AddComponent<TextMesh>();
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            if (font != null)
                tm.font = font;
            tm.text = text;
            tm.fontSize = 64;
            tm.characterSize = 0.055f;
            tm.anchor = TextAnchor.MiddleLeft;
            tm.alignment = TextAlignment.Left;
            tm.color = new Color(0.92f, 0.92f, 0.92f, 1f);
            var mr = labelGo.GetComponent<MeshRenderer>();
            if (mr != null)
            {
                mr.shadowCastingMode = ShadowCastingMode.Off;
                mr.receiveShadows = false;
                if (font != null && font.material != null)
                    mr.sharedMaterial = font.material;
            }

            labelGo.transform.localPosition = new Vector3(x, y, 0.05f);
            labelGo.transform.localRotation = Quaternion.Euler(0f, 180f, 0f);
            labelGo.transform.localScale = Vector3.one;
            EditorUtility.SetDirty(labelGo);
        }

        static Bounds EncapsulateCatalog(List<Transform> groups)
        {
            bool has = false;
            Bounds b = new Bounds();
            for (int g = 0; g < groups.Count; g++)
            {
                var rends = groups[g].GetComponentsInChildren<Renderer>(true);
                for (int i = 0; i < rends.Length; i++)
                {
                    if (rends[i].GetComponent<TextMesh>() != null)
                    {
                        if (rends[i].transform.name == "GroupLabel")
                            b = EncapsulatePoint(b, ref has, rends[i].transform.position + new Vector3(0.3f, 0.3f, 0f));
                        continue;
                    }
                    if (!rends[i].enabled || !rends[i].gameObject.activeInHierarchy) continue;
                    if (rends[i] is ParticleSystemRenderer) continue;
                    if (!has)
                    {
                        b = rends[i].bounds;
                        has = true;
                    }
                    else b.Encapsulate(rends[i].bounds);
                }
            }
            return b;
        }

        static Bounds EncapsulatePoint(Bounds b, ref bool has, Vector3 p)
        {
            if (!has)
            {
                b = new Bounds(p, Vector3.zero);
                has = true;
            }
            else b.Encapsulate(p);
            return b;
        }

        static string CaptureSquare(Camera cam, int size, string fileName)
        {
            int maxSize = SystemInfo.maxTextureSize;
            if (size > maxSize)
                throw new InvalidOperationException("size " + size + " exceeds maxTextureSize " + maxSize);

            var rt = new RenderTexture(size, size, 24, RenderTextureFormat.ARGB32, RenderTextureReadWrite.sRGB);
            rt.antiAliasing = size >= 8000 ? 1 : 4;
            rt.Create();
            var oldTarget = cam.targetTexture;
            var oldActive = RenderTexture.active;
            cam.targetTexture = rt;
            cam.Render();
            RenderTexture.active = rt;
            var tex = new Texture2D(size, size, TextureFormat.RGB24, false);
            tex.ReadPixels(new Rect(0, 0, size, size), 0, 0);
            tex.Apply();
            cam.targetTexture = oldTarget;
            RenderTexture.active = oldActive;

            string rel = ShotFolder + "/" + fileName;
            string abs = ToAbs(rel);
            Directory.CreateDirectory(Path.GetDirectoryName(abs));
            File.WriteAllBytes(abs, tex.EncodeToPNG());
            UnityEngine.Object.DestroyImmediate(tex);
            rt.Release();
            UnityEngine.Object.DestroyImmediate(rt);
            AssetDatabase.ImportAsset(rel, ImportAssetOptions.ForceUpdate);
            var importer = AssetImporter.GetAtPath(rel) as TextureImporter;
            if (importer != null)
            {
                importer.maxTextureSize = 8192;
                importer.npotScale = TextureImporterNPOTScale.None;
                importer.textureCompression = TextureImporterCompression.Uncompressed;
                importer.SaveAndReimport();
            }
            return rel;
        }

        static void SetMmnPost(bool active, bool vignette)
        {
            var rendererObj = AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(RendererPath);
            if (rendererObj == null) return;
            var rso = new SerializedObject(rendererObj);
            var features = rso.FindProperty("m_RendererFeatures");
            if (features == null) return;
            for (int i = 0; i < features.arraySize; i++)
            {
                var feat = features.GetArrayElementAtIndex(i).objectReferenceValue;
                if (feat == null || feat.name.IndexOf("Post Processing", StringComparison.Ordinal) < 0)
                    continue;
                var featureSo = new SerializedObject(feat);
                var activeProp = featureSo.FindProperty("m_Active");
                var vigProp = featureSo.FindProperty("volumeStack.vignette.enabled");
                if (activeProp != null) activeProp.boolValue = active;
                if (vigProp != null) vigProp.boolValue = vignette;
                featureSo.ApplyModifiedPropertiesWithoutUndo();
                var pipe = GraphicsSettings.renderPipelineAsset;
                GraphicsSettings.renderPipelineAsset = null;
                GraphicsSettings.renderPipelineAsset = pipe;
                return;
            }
        }

        static string ToAbs(string assetsPath)
        {
            return Path.Combine(Application.dataPath, assetsPath.Substring("Assets/".Length).Replace('/', Path.DirectorySeparatorChar));
        }
    }
}
