using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using TirChonaill.Editor;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace SkySanctum.Editor
{
    /// <summary>
    /// Imports the SkySanctum (星穹) dungeon pack produced by _re_work/extract_skysanctum.py.
    /// Unlike the TirChonaill import, each room ships a Transform hierarchy, so the room is
    /// rebuilt as a single prefab that keeps its authored layout.
    /// </summary>
    public static class SkySanctumImporter
    {
        const string PackRoot = "Assets/SkySanctum/_import_pack";
        const string OutRoot = "Assets/SkySanctum";

        [MenuItem("Tools/SkySanctum/1. Import Room Assets")]
        public static void ImportAll()
        {
            string catalogPath = PackRoot + "/catalog.json";
            if (!File.Exists(catalogPath))
            {
                Debug.LogError($"[SkySanctum] missing {catalogPath} - run extract_skysanctum.py first");
                return;
            }

            foreach (var sub in new[] { "Textures", "Materials", "Meshes", "Prefabs", "Scenes" })
                EnsureFolder(OutRoot + "/" + sub);

            var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
            var packages = Get<List<object>>(catalog, "packages") ?? new List<object>();

            int totalMesh = 0, totalMat = 0, totalTex = 0, totalNodes = 0;
            var missingShaders = new SortedSet<string>();

            // Rooms share materials (CampFire_Room_00 reuses all of Room_00's), so materials are
            // imported for every package first and then resolved by pathID when building prefabs.
            var manifests = new List<(string id, string dir, Dictionary<string, object> man)>();
            foreach (var po in packages)
            {
                var pkg = po as Dictionary<string, object>;
                if (pkg == null) continue;
                string pkgDir = $"{PackRoot}/{Get<string>(pkg, "path")}";
                string manPath = pkgDir + "/package.json";
                if (!File.Exists(manPath))
                {
                    Debug.LogError($"[SkySanctum] missing {manPath}");
                    continue;
                }
                manifests.Add((Get<string>(pkg, "id"), pkgDir,
                    MiniJson.Deserialize(File.ReadAllText(manPath, Encoding.UTF8)) as Dictionary<string, object>));
            }

            // Deliberately not wrapped in StartAssetEditing: copied textures must be loadable
            // within this same call so materials can bind them.
            try
            {
                var matByKey = new Dictionary<string, Material>();
                var matByPathId = new Dictionary<long, Material>();
                foreach (var (_, dir, man) in manifests)
                {
                    var texMap = ImportTextures(dir, man);
                    totalTex += texMap.Count;
                    totalMat += ImportMaterials(dir, man, texMap, missingShaders, matByKey, matByPathId);
                }

                foreach (var (id, dir, man) in manifests)
                {
                    var meshByKey = ImportMeshes(dir, man);
                    totalMesh += meshByKey.Count;
                    totalNodes += BuildRoomPrefab(id, man, meshByKey, matByKey, matByPathId);
                }
            }
            finally
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }

            Debug.Log($"[SkySanctum] imported meshes={totalMesh} materials={totalMat} textures={totalTex} nodes={totalNodes}");
            if (missingShaders.Count > 0)
                Debug.LogWarning("[SkySanctum] shaders not present in project (mapped to MMN/BG/SimpleLit): "
                                 + string.Join(", ", missingShaders));
            else
                Debug.Log("[SkySanctum] every material resolved to a shader that exists in the project");
        }

        static Dictionary<string, Texture2D> ImportTextures(string pkgDir, Dictionary<string, object> man)
        {
            var map = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);
            var list = Get<List<object>>(man, "textures") ?? new List<object>();
            foreach (var o in list)
            {
                string fn = o as string;
                if (string.IsNullOrEmpty(fn)) continue;
                string src = $"{pkgDir}/textures/{fn}";
                string dst = $"{OutRoot}/Textures/{fn}";
                if (!File.Exists(src)) continue;
                if (!File.Exists(dst))
                    AssetDatabase.CopyAsset(src, dst);

                var ti = AssetImporter.GetAtPath(dst) as TextureImporter;
                if (ti != null)
                {
                    ti.textureType = TextureImporterType.Default;
                    ti.sRGBTexture = true;
                    ti.alphaSource = TextureImporterAlphaSource.FromInput;
                    ti.alphaIsTransparency = true;
                    ti.mipmapEnabled = true;
                    ti.wrapMode = TextureWrapMode.Repeat;
                    ti.filterMode = FilterMode.Bilinear;
                    ti.SaveAndReimport();
                }

                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(dst);
                if (tex != null) map[Path.GetFileNameWithoutExtension(fn)] = tex;
            }
            return map;
        }

        static int ImportMaterials(string pkgDir, Dictionary<string, object> man,
            Dictionary<string, Texture2D> texMap, SortedSet<string> missingShaders,
            Dictionary<string, Material> byKey, Dictionary<long, Material> byPathId)
        {
            int count = 0;
            var list = Get<List<object>>(man, "materials") ?? new List<object>();
            foreach (var o in list)
            {
                var entry = o as Dictionary<string, object>;
                if (entry == null) continue;
                string key = Get<string>(entry, "key");
                string file = Get<string>(entry, "file");
                string jsonPath = $"{pkgDir}/materials/{file}";
                if (!File.Exists(jsonPath)) continue;

                var mat = CreateMaterial(jsonPath, texMap, missingShaders);
                if (mat == null) continue;
                byKey[key] = mat;
                long pid = ToL(entry.TryGetValue("pathID", out var p) ? p : null);
                if (pid != 0) byPathId[pid] = mat;
                count++;
            }
            return count;
        }

        static Material CreateMaterial(string jsonPath, Dictionary<string, Texture2D> texMap,
            SortedSet<string> missingShaders)
        {
            var d = MiniJson.Deserialize(File.ReadAllText(jsonPath, Encoding.UTF8)) as Dictionary<string, object>;
            if (d == null) return null;

            string name = Get<string>(d, "name") ?? "material";
            string key = Get<string>(d, "key") ?? name;
            string wanted = Get<string>(d, "shader");

            Shader shader = string.IsNullOrEmpty(wanted) ? null : Shader.Find(wanted);
            if (shader == null)
            {
                if (!string.IsNullOrEmpty(wanted)) missingShaders.Add(wanted);
                shader = Shader.Find("MMN/BG/SimpleLit");
            }
            if (shader == null)
            {
                Debug.LogError($"[SkySanctum] no usable shader for {name}");
                return null;
            }

            string path = $"{OutRoot}/Materials/{Sanitize(key)}.mat";
            var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (mat == null)
            {
                mat = new Material(shader) { name = name };
                AssetDatabase.CreateAsset(mat, path);
            }
            else
            {
                mat.shader = shader;
            }

            // The dumped property blocks carry leftovers from other shaders, so each value is only
            // applied when this shader declares that name with a compatible type.
            var types = PropertyTypes(shader);

            if (Get<Dictionary<string, object>>(d, "floats") is Dictionary<string, object> floats)
                foreach (var kv in floats)
                    if (types.TryGetValue(kv.Key, out var pt)
                        && (pt == ShaderPropertyType.Float || pt == ShaderPropertyType.Range || pt == ShaderPropertyType.Int))
                        mat.SetFloat(kv.Key, ToF(kv.Value));

            if (Get<Dictionary<string, object>>(d, "colors") is Dictionary<string, object> colors)
                foreach (var kv in colors)
                {
                    if (!types.TryGetValue(kv.Key, out var pt)) continue;
                    if (pt != ShaderPropertyType.Color && pt != ShaderPropertyType.Vector) continue;
                    var c = ToColor(kv.Value);
                    if (c.HasValue) mat.SetColor(kv.Key, c.Value);
                }

            if (Get<Dictionary<string, object>>(d, "texenvs") is Dictionary<string, object> texenvs)
                foreach (var kv in texenvs)
                {
                    string prop = kv.Key;
                    var te = kv.Value as Dictionary<string, object>;
                    if (te == null) continue;
                    if (!types.TryGetValue(prop, out var pt) || pt != ShaderPropertyType.Texture) continue;

                    var tex = ResolveTexture(te, texMap);
                    if (tex != null) mat.SetTexture(prop, tex);

                    var scale = ToVector2(Get<List<object>>(te, "scale"));
                    var offset = ToVector2(Get<List<object>>(te, "offset"));
                    if (scale.HasValue && scale.Value != Vector2.zero) mat.SetTextureScale(prop, scale.Value);
                    if (offset.HasValue) mat.SetTextureOffset(prop, offset.Value);
                }

            // The MMN shaders gate clipping on a float, but URP still needs the keyword + queue.
            if (mat.HasProperty("_ALPHATEST") && mat.GetFloat("_ALPHATEST") > 0.5f)
            {
                mat.EnableKeyword("_ALPHATEST_ON");
                mat.SetOverrideTag("RenderType", "TransparentCutout");
                mat.renderQueue = (int)RenderQueue.AlphaTest;
                if (mat.HasProperty("_Cutoff") && mat.GetFloat("_Cutoff") <= 0f)
                    mat.SetFloat("_Cutoff", 0.5f);
            }
            else
            {
                mat.DisableKeyword("_ALPHATEST_ON");
            }

            mat.doubleSidedGI = mat.HasProperty("_Cull") && mat.GetFloat("_Cull") < 0.5f;
            EditorUtility.SetDirty(mat);
            return mat;
        }

        static Dictionary<string, ShaderPropertyType> PropertyTypes(Shader shader)
        {
            var map = new Dictionary<string, ShaderPropertyType>();
            int n = shader.GetPropertyCount();
            for (int i = 0; i < n; i++)
                map[shader.GetPropertyName(i)] = shader.GetPropertyType(i);
            return map;
        }

        static Texture2D ResolveTexture(Dictionary<string, object> te, Dictionary<string, Texture2D> texMap)
        {
            string png = Get<string>(te, "png");
            if (!string.IsNullOrEmpty(png))
            {
                string stem = Path.GetFileNameWithoutExtension(png);
                if (texMap.TryGetValue(stem, out var t)) return t;
            }
            string tname = Get<string>(te, "texture");
            if (!string.IsNullOrEmpty(tname) && texMap.TryGetValue(tname, out var t2)) return t2;
            return null;
        }

        static Dictionary<string, Mesh> ImportMeshes(string pkgDir, Dictionary<string, object> man)
        {
            var map = new Dictionary<string, Mesh>();
            var list = Get<List<object>>(man, "meshes") ?? new List<object>();
            foreach (var o in list)
            {
                var entry = o as Dictionary<string, object>;
                if (entry == null) continue;
                string key = Get<string>(entry, "key");
                string file = Get<string>(entry, "file");
                string src = $"{pkgDir}/meshes/{file}";
                if (!File.Exists(src)) continue;

                string dst = $"{OutRoot}/Meshes/{Sanitize(key)}.asset";
                var existing = AssetDatabase.LoadAssetAtPath<Mesh>(dst);
                if (existing != null)
                {
                    map[key] = existing;
                    continue;
                }
                try
                {
                    map[key] = ImportMMesh(src, dst);
                }
                catch (Exception e)
                {
                    Debug.LogError($"[SkySanctum] mesh {file}: {e.Message}");
                }
            }
            return map;
        }

        static Mesh ImportMMesh(string path, string assetPath)
        {
            using (var fs = File.OpenRead(path))
            using (var br = new BinaryReader(fs))
            {
                var magic = br.ReadBytes(4);
                if (magic[0] != 'M' || magic[1] != 'M' || magic[2] != 'S' || magic[3] != 'H')
                    throw new Exception("bad mmesh magic");
                uint ver = br.ReadUInt32();
                if (ver != 1) throw new Exception("unsupported mmesh version " + ver);
                int nameLen = br.ReadInt32();
                string name = Encoding.UTF8.GetString(br.ReadBytes(nameLen));
                int vc = br.ReadInt32();
                int sc = br.ReadInt32();
                int flags = br.ReadInt32();

                var vertices = new Vector3[vc];
                for (int i = 0; i < vc; i++)
                    vertices[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());

                Vector3[] normals = null;
                if ((flags & 1) != 0)
                {
                    normals = new Vector3[vc];
                    for (int i = 0; i < vc; i++)
                        normals[i] = new Vector3(br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                }

                Color[] colors = null;
                if ((flags & 2) != 0)
                {
                    colors = new Color[vc];
                    for (int i = 0; i < vc; i++)
                        colors[i] = new Color(br.ReadSingle(), br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                }

                Vector2[] uv0 = null;
                if ((flags & 4) != 0)
                {
                    uv0 = new Vector2[vc];
                    for (int i = 0; i < vc; i++)
                        uv0[i] = new Vector2(br.ReadSingle(), br.ReadSingle());
                }

                Vector2[] uv1 = null;
                if ((flags & 8) != 0)
                {
                    uv1 = new Vector2[vc];
                    for (int i = 0; i < vc; i++)
                        uv1[i] = new Vector2(br.ReadSingle(), br.ReadSingle());
                }

                Vector4[] tangents = null;
                if ((flags & 16) != 0)
                {
                    tangents = new Vector4[vc];
                    for (int i = 0; i < vc; i++)
                        tangents[i] = new Vector4(br.ReadSingle(), br.ReadSingle(), br.ReadSingle(), br.ReadSingle());
                }

                var subIndices = new List<int[]>();
                for (int s = 0; s < sc; s++)
                {
                    int ic = br.ReadInt32();
                    var idx = new int[ic];
                    for (int i = 0; i < ic; i++) idx[i] = br.ReadInt32();
                    subIndices.Add(idx);
                }

                var mesh = new Mesh { name = name };
                mesh.indexFormat = vc > 65535 ? IndexFormat.UInt32 : IndexFormat.UInt16;
                mesh.SetVertices(vertices);
                if (normals != null) mesh.SetNormals(normals);
                if (colors != null) mesh.SetColors(colors);
                if (uv0 != null) mesh.SetUVs(0, uv0);
                if (uv1 != null) mesh.SetUVs(1, uv1);
                if (tangents != null) mesh.SetTangents(tangents);
                mesh.subMeshCount = subIndices.Count;
                for (int s = 0; s < subIndices.Count; s++)
                    mesh.SetTriangles(subIndices[s], s, true);
                if (normals == null) mesh.RecalculateNormals();
                if (tangents == null) mesh.RecalculateTangents();
                mesh.RecalculateBounds();

                AssetDatabase.CreateAsset(mesh, assetPath);
                return AssetDatabase.LoadAssetAtPath<Mesh>(assetPath);
            }
        }

        static int BuildRoomPrefab(string id, Dictionary<string, object> man,
            Dictionary<string, Mesh> meshByKey, Dictionary<string, Material> matByKey,
            Dictionary<long, Material> matByPathId)
        {
            var nodes = Get<List<object>>(man, "hierarchy") ?? new List<object>();
            if (nodes.Count == 0) return 0;

            var dicts = nodes.OfType<Dictionary<string, object>>().ToList();
            var goByPid = new Dictionary<long, GameObject>();

            foreach (var n in dicts)
            {
                long pid = ToL(n.TryGetValue("pathID", out var p) ? p : null);
                var go = new GameObject(Get<string>(n, "name") ?? "node");
                goByPid[pid] = go;
            }

            foreach (var n in dicts)
            {
                long pid = ToL(n.TryGetValue("pathID", out var p) ? p : null);
                if (!goByPid.TryGetValue(pid, out var go)) continue;

                object parentRaw = n.TryGetValue("parent", out var pr) ? pr : null;
                if (parentRaw != null && goByPid.TryGetValue(ToL(parentRaw), out var parentGo))
                    go.transform.SetParent(parentGo.transform, false);

                var pos = ToVector3(Get<List<object>>(n, "localPosition")) ?? Vector3.zero;
                var scl = ToVector3(Get<List<object>>(n, "localScale")) ?? Vector3.one;
                var rot = ToQuaternion(Get<List<object>>(n, "localRotation")) ?? Quaternion.identity;
                go.transform.localPosition = pos;
                go.transform.localRotation = rot;
                go.transform.localScale = scl;

                string meshKey = Get<string>(n, "meshKey");
                if (string.IsNullOrEmpty(meshKey) || !meshByKey.TryGetValue(meshKey, out var mesh))
                    continue;

                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                var mr = go.AddComponent<MeshRenderer>();

                // pathIDs are the authoritative link, since a room may reference another room's
                // materials and therefore carry no key of its own for them.
                var mats = new List<Material>();
                var pids = Get<List<object>>(n, "materialPathIDs");
                if (pids != null && pids.Count > 0)
                {
                    foreach (var o in pids)
                        if (matByPathId.TryGetValue(ToL(o), out var m))
                            mats.Add(m);
                }
                if (mats.Count == 0)
                {
                    foreach (var k in Get<List<object>>(n, "materialKeys") ?? new List<object>())
                        if (k is string ks && matByKey.TryGetValue(ks, out var m))
                            mats.Add(m);
                }
                // A submesh without its own material still needs a slot, or Unity renders it pink.
                while (mats.Count < mesh.subMeshCount && mats.Count > 0)
                    mats.Add(mats[mats.Count - 1]);
                if (mats.Count > 0) mr.sharedMaterials = mats.ToArray();

                if (n.TryGetValue("enabled", out var en) && en is bool eb)
                    mr.enabled = eb;
            }

            var roots = dicts
                .Where(n => !(n.TryGetValue("parent", out var pr) && pr != null && goByPid.ContainsKey(ToL(pr))))
                .Select(n => goByPid[ToL(n["pathID"])])
                .ToList();

            GameObject root;
            bool wrapped = false;
            if (roots.Count == 1)
            {
                root = roots[0];
            }
            else
            {
                root = new GameObject(id);
                wrapped = true;
                foreach (var r in roots) r.transform.SetParent(root.transform, true);
            }

            // The brazier VFX subtrees are not reproduced, but their anchor nodes are kept so the
            // scene builder can light the room from the right spots.
            foreach (var o in Get<List<object>>(man, "campfireAnchors") ?? new List<object>())
            {
                var a = o as Dictionary<string, object>;
                if (a == null) continue;
                var pos = ToVector3(Get<List<object>>(a, "position"));
                if (!pos.HasValue) continue;
                var marker = new GameObject(Get<string>(a, "name") ?? "FX_Fire_Small_01");
                marker.transform.SetParent(root.transform, false);
                marker.transform.localPosition = pos.Value;
            }

            string prefabPath = $"{OutRoot}/Prefabs/{Sanitize(root.name)}.prefab";
            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
            UnityEngine.Object.DestroyImmediate(root);
            if (!wrapped)
                foreach (var r in roots.Skip(1))
                    if (r != null) UnityEngine.Object.DestroyImmediate(r);

            Debug.Log($"[SkySanctum] prefab {prefabPath} ({dicts.Count} nodes)");
            return dicts.Count;
        }

        [MenuItem("Tools/SkySanctum/2. Build Dungeon Scene")]
        public static void BuildScene()
        {
            var prefabs = AssetDatabase.FindAssets("t:Prefab", new[] { OutRoot + "/Prefabs" })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Select(AssetDatabase.LoadAssetAtPath<GameObject>)
                .Where(p => p != null)
                .ToList();
            if (prefabs.Count == 0)
            {
                Debug.LogError("[SkySanctum] no prefabs - run 'Import Room Assets' first");
                return;
            }

            string scenePath = $"{OutRoot}/Scenes/SkySanctum_Preview.unity";

            // Single mode rather than additive: an untitled scene in the setup makes additive
            // NewScene throw, and a previously opened preview cannot be saved over itself.
            if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
            {
                Debug.Log("[SkySanctum] scene build cancelled - unsaved scenes were kept");
                return;
            }
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            // Modules are all authored around the origin, so they get spread along X to sit side
            // by side. Room_00 is put first because the camera frames whichever comes first.
            var ordered = prefabs
                .OrderByDescending(p => p.name.IndexOf("Room_00", StringComparison.OrdinalIgnoreCase) >= 0
                                        && p.name.IndexOf("CampFire", StringComparison.OrdinalIgnoreCase) < 0)
                .ThenBy(p => p.name, StringComparer.OrdinalIgnoreCase)
                .ToList();

            var first = new Bounds();
            bool haveFirst = false;
            float firstFloorTop = float.NaN;
            float x = 0f;
            int lights = 0;

            foreach (var p in ordered)
            {
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(p);
                inst.transform.position = new Vector3(x, 0f, 0f);

                var b = new Bounds();
                bool have = false;
                float floorTop = float.NaN;
                foreach (var r in inst.GetComponentsInChildren<Renderer>())
                {
                    if (!have) { b = r.bounds; have = true; }
                    else b.Encapsulate(r.bounds);

                    // Underwall dips well below the walkable surface, so min.y is not the floor.
                    // Matching on "loor" rather than "Floor" because Passage_01 ships its floors
                    // misspelled as Flloor_00/Flloor_01, and missing them silently falls back to
                    // the foundation 3.5 units lower.
                    if (r.name.IndexOf("loor", StringComparison.OrdinalIgnoreCase) >= 0
                        && r.name.IndexOf("Underwall", StringComparison.OrdinalIgnoreCase) < 0)
                        floorTop = float.IsNaN(floorTop) ? r.bounds.max.y : Mathf.Max(floorTop, r.bounds.max.y);
                }
                if (float.IsNaN(floorTop) && have) floorTop = b.min.y;

                lights += AddBrazierLights(inst, floorTop);

                if (!haveFirst && have)
                {
                    first = b;
                    firstFloorTop = floorTop;
                    haveFirst = true;
                }
                x += 120f;
            }
            if (float.IsNaN(firstFloorTop)) firstFloorTop = first.min.y;

            ApplyInteriorEnvironment(scene, first, haveFirst, firstFloorTop);

            if (!EditorSceneManager.SaveScene(scene, scenePath))
            {
                Debug.LogError($"[SkySanctum] failed to save scene to {scenePath}");
                return;
            }
            Debug.Log($"[SkySanctum] scene saved to {scenePath}; {prefabs.Count} room(s), {lights} brazier light(s)");
        }

        /// <summary>
        /// Bounds only stand in for solid stone on compact meshes. An arch's box is 1.8 thick but
        /// 15 by 16 tall and deep, nearly all of it the opening, so a light in mid-air counts as
        /// inside it and would be shoved around forever. Pillars, sconces and props are the pieces
        /// a brazier actually mounts to, and their boxes are tight.
        /// </summary>
        static bool IsSolidProxy(Renderer r)
        {
            var s = r.bounds.size;
            return Mathf.Max(s.x, Mathf.Max(s.y, s.z)) <= 8f;
        }

        /// <summary>
        /// Nudges a brazier light out of any mesh it starts inside. The standing braziers in the
        /// halls anchor at the top of a tall stand, so a light just above them sits in open air,
        /// but the passage sconces anchor against the stone they are mounted on and a light left
        /// buried there burns a saturated patch straight through the pillar. The push is
        /// horizontal so the flame stays at its authored height.
        /// </summary>
        static Vector3 PushOutOfGeometry(Vector3 p, Renderer[] renderers)
        {
            const float margin = 0.35f;
            // Clearing one mesh can drop the light into a neighbouring one, so repeat a few times.
            for (int pass = 0; pass < 4; pass++)
            {
                Bounds? hit = null;
                foreach (var r in renderers)
                {
                    if (IsSolidProxy(r) && r.bounds.Contains(p)) { hit = r.bounds; break; }
                }
                if (hit == null) return p;

                var b = hit.Value;
                var dir = new Vector3(p.x - b.center.x, 0f, p.z - b.center.z);
                if (dir.sqrMagnitude < 1e-4f) dir = Vector3.forward;
                dir.Normalize();

                // Slab exit distance along dir for a point already inside the box.
                float exit = float.MaxValue;
                var offset = p - b.center;
                for (int axis = 0; axis < 3; axis += 2)
                {
                    float d = dir[axis];
                    if (Mathf.Abs(d) < 1e-5f) continue;
                    float t = ((d > 0f ? b.extents[axis] : -b.extents[axis]) - offset[axis]) / d;
                    if (t > 0f) exit = Mathf.Min(exit, t);
                }
                if (exit == float.MaxValue) return p;
                p += dir * (exit + margin);
            }
            return p;
        }

        /// <summary>
        /// Stands in for the fire particle systems at the anchors kept during extraction: a warm
        /// point light per brazier, which is what actually reads as light in a preview scene.
        /// Intensity is derived from how high the flame sits rather than fixed, because these
        /// anchors range from bowls atop 6 unit stands in the halls down to sconces a few units
        /// off the floor in the passages. A constant that pools nicely under a hall brazier blows
        /// out a passage tile, and inverse-square falloff means holding the lit floor at a steady
        /// brightness takes intensity proportional to the square of that height.
        /// </summary>
        static int AddBrazierLights(GameObject instance, float floorTop)
        {
            const float floorBrightness = 0.5f;
            int n = 0;
            var renderers = instance.GetComponentsInChildren<Renderer>();
            foreach (var t in instance.GetComponentsInChildren<Transform>())
            {
                if (t.name.IndexOf("FX_Fire", StringComparison.OrdinalIgnoreCase) < 0) continue;

                var go = new GameObject("Light_" + t.name);
                go.transform.SetParent(t, false);
                go.transform.localPosition = new Vector3(0f, 0.8f, 0f);
                go.transform.position = PushOutOfGeometry(go.transform.position, renderers);

                float height = float.IsNaN(floorTop) ? 5f : go.transform.position.y - floorTop;
                // The lower bound matters for the door frame, where bowls hang on chains less than
                // a unit above a raised plinth but well out in front of it, so the raw height
                // under-drives them into invisibility. No brazier should read dimmer than a
                // passage sconce.
                height = Mathf.Clamp(height, 3.5f, 10f);

                var l = go.AddComponent<Light>();
                l.type = LightType.Point;
                l.color = new Color(1f, 0.62f, 0.28f);
                l.intensity = floorBrightness * height * height;
                l.range = Mathf.Max(8f, height * 2.5f);
                // MMN/BG/SimpleLit now samples additional light shadows, but 18 braziers casting
                // them costs a shadowmap each; turn them on per light when a shot needs it.
                l.shadows = LightShadows.None;
                n++;
            }
            return n;
        }

        /// <summary>
        /// Fog comes verbatim from the shipped PlayScene RenderSettings. Ambient does not:
        /// Room_00 ships AmbientMode.Flat with pure white, and MMN/BG/SimpleLit adds SampleSH(n)
        /// straight on top of the main light, so that value alone would flatten the room. These
        /// colours keep the shipped hue ratios (cool sky/equator, warm ground) but are scaled down
        /// far enough that the brazier point lights, which carry the mood in the shipped dungeon,
        /// actually read against the pale stone instead of being swamped by fill.
        /// </summary>
        static void ApplyInteriorEnvironment(Scene scene, Bounds bounds, bool haveBounds, float floorTop)
        {
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.660f, 0.726f, 0.774f, 1f);
            RenderSettings.fogDensity = 0.01f;

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.204f, 0.218f, 0.248f);
            RenderSettings.ambientEquatorColor = new Color(0.110f, 0.120f, 0.128f);
            RenderSettings.ambientGroundColor = new Color(0.045f, 0.041f, 0.034f);
            RenderSettings.ambientIntensity = 1f;
            RenderSettings.subtractiveShadowColor = new Color(0.420f, 0.478f, 0.627f);
            RenderSettings.skybox = null;

            var lightGo = new GameObject("Directional Light");
            SceneManager.MoveGameObjectToScene(lightGo, scene);
            var light = lightGo.AddComponent<Light>();
            light.type = LightType.Directional;
            light.color = new Color(0.82f, 0.87f, 1f);
            light.intensity = 0.28f;
            light.shadows = LightShadows.Soft;
            light.shadowStrength = 0.8f;
            light.bounceIntensity = 0f;
            lightGo.transform.rotation = Quaternion.Euler(52f, 205f, 0f);
            RenderSettings.sun = light;

            var camGo = new GameObject("Main Camera");
            SceneManager.MoveGameObjectToScene(camGo, scene);
            camGo.tag = "MainCamera";
            var cam = camGo.AddComponent<Camera>();
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.02f, 0.03f, 0.05f);
            cam.allowHDR = true;
            cam.nearClipPlane = 0.1f;
            cam.farClipPlane = 800f;
            camGo.AddComponent<AudioListener>();

            if (haveBounds)
            {
                // Room_00 is an enclosed shell, so an exterior framing would only show back faces.
                camGo.transform.position = new Vector3(bounds.center.x + bounds.size.x * 0.34f,
                                                      floorTop + 4f, bounds.max.z - 4f);
                camGo.transform.LookAt(new Vector3(bounds.center.x - bounds.size.x * 0.1f,
                                                   floorTop + 4f, bounds.min.z + 6f));
            }
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace("\\", "/");
            string leaf = Path.GetFileName(path);
            if (!AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, leaf);
        }

        static string Sanitize(string s)
        {
            if (string.IsNullOrEmpty(s)) return "unnamed";
            foreach (char c in Path.GetInvalidFileNameChars()) s = s.Replace(c, '_');
            return s;
        }

        static T Get<T>(Dictionary<string, object> d, string key) where T : class
        {
            if (d == null || !d.TryGetValue(key, out var v)) return null;
            return v as T;
        }

        static float ToF(object o)
        {
            switch (o)
            {
                case double d: return (float)d;
                case long l: return l;
                case int i: return i;
                case bool b: return b ? 1f : 0f;
                case string s when float.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out var f): return f;
                default: return 0f;
            }
        }

        static long ToL(object o)
        {
            switch (o)
            {
                case long l: return l;
                case double d: return (long)d;
                case int i: return i;
                default: return 0L;
            }
        }

        static Vector2? ToVector2(List<object> l)
        {
            if (l == null || l.Count < 2) return null;
            return new Vector2(ToF(l[0]), ToF(l[1]));
        }

        static Vector3? ToVector3(List<object> l)
        {
            if (l == null || l.Count < 3) return null;
            return new Vector3(ToF(l[0]), ToF(l[1]), ToF(l[2]));
        }

        static Quaternion? ToQuaternion(List<object> l)
        {
            if (l == null || l.Count < 4) return null;
            var q = new Quaternion(ToF(l[0]), ToF(l[1]), ToF(l[2]), ToF(l[3]));
            return q.normalized;
        }

        static Color? ToColor(object o)
        {
            if (!(o is List<object> l) || l.Count < 3) return null;
            return new Color(ToF(l[0]), ToF(l[1]), ToF(l[2]), l.Count > 3 ? ToF(l[3]) : 1f);
        }
    }
}
