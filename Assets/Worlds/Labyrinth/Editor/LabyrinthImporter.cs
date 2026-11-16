using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using TirChonaill.Editor;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace Labyrinth.Editor
{
    /// <summary>
    /// Imports the Labyrinth Field 1 pack (亡靈之塔) from extract_labyrinth.py.
    ///
    /// Phase 1: geometry, materials, textures and the authored point lights. The pack also
    /// carries the brazier particle systems, but those are left for the FX phase - the
    /// emitter GameObjects are still created so phase 2 only has to add components.
    ///
    /// Every module was shipped statically batched, so its nodes all sit at the origin with
    /// the placement baked into the mesh vertices. That means the modules of one plaza area
    /// reassemble exactly by dropping them in at identity, and it also means a module's LOD0
    /// and LOD1 nodes occupy the same space - they are paired into a LODGroup here rather
    /// than left to z-fight.
    /// </summary>
    public static class LabyrinthImporter
    {
        const string PackRoot = "Assets/Worlds/Labyrinth/_import_pack";
        const string OutRoot = "Assets/Worlds/Labyrinth";

        // Slots whose texture is data rather than colour. Only consulted when the pack has
        // no shipped import settings for that file; the shipped colour space wins.
        static readonly HashSet<string> LinearSlots = new HashSet<string>
        {
            "_T2M_SplatMap_0", "_NoiseTex", "_AddNoiseTex", "_DistortionTexture", "_MaskMap"
        };

        static readonly HashSet<string> NormalSlots = new HashSet<string> { "_BumpMap" };

        [MenuItem("Tools/Labyrinth/1. Import Scene Assets")]
        public static void ImportAll()
        {
            string catalogPath = PackRoot + "/catalog.json";
            if (!File.Exists(catalogPath))
            {
                Debug.LogError($"[Labyrinth] missing {catalogPath} - run extract_labyrinth.py first");
                return;
            }

            foreach (var sub in new[] { "Textures", "Materials", "Meshes", "Prefabs", "Scenes" })
                EnsureFolder(OutRoot + "/" + sub);

            var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
            var packages = Get<List<object>>(catalog, "packages") ?? new List<object>();

            var manifests = new List<(string id, string dir, Dictionary<string, object> man)>();
            foreach (var po in packages)
            {
                var pkg = po as Dictionary<string, object>;
                if (pkg == null) continue;
                string pkgDir = $"{PackRoot}/{Get<string>(pkg, "path")}";
                string manPath = pkgDir + "/package.json";
                if (!File.Exists(manPath))
                {
                    Debug.LogError($"[Labyrinth] missing {manPath}");
                    continue;
                }
                manifests.Add((Get<string>(pkg, "id"), pkgDir,
                    MiniJson.Deserialize(File.ReadAllText(manPath, Encoding.UTF8)) as Dictionary<string, object>));
            }

            // The slot a PNG is used in decides how it is imported, so every material is read
            // before any texture is touched.
            var slotByTexture = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var (_, dir, man) in manifests)
                CollectTextureSlots(dir, man, slotByTexture);

            int totalMesh = 0, totalMat = 0, totalTex = 0, totalNodes = 0, totalLights = 0, deferredFx = 0;
            var missingShaders = new SortedSet<string>();
            var matByKey = new Dictionary<string, Material>();
            var matByPathId = new Dictionary<long, Material>();
            var meshByKey = new Dictionary<string, Mesh>();
            var globalTex = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);

            try
            {
                foreach (var (_, dir, man) in manifests)
                {
                    var texMap = ImportTextures(dir, man, slotByTexture);
                    foreach (var kv in texMap) globalTex[kv.Key] = kv.Value;
                    totalTex += texMap.Count;
                }
                foreach (var (_, dir, man) in manifests)
                    totalMat += ImportMaterials(dir, man, globalTex, missingShaders, matByKey, matByPathId);

                foreach (var (id, dir, man) in manifests)
                {
                    foreach (var kv in ImportMeshes(dir, man))
                    {
                        meshByKey[kv.Key] = kv.Value;
                        totalMesh++;
                    }
                    var r = BuildPackagePrefab(id, man, meshByKey, matByKey, matByPathId);
                    totalNodes += r.nodes;
                    totalLights += r.lights;
                    deferredFx += r.fx;
                }
            }
            finally
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }

            Debug.Log($"[Labyrinth] imported meshes={totalMesh} materials={totalMat} textures={totalTex} "
                      + $"nodes={totalNodes} lights={totalLights}; {deferredFx} FX emitter(s) left for phase 2");
            if (missingShaders.Count > 0)
                Debug.LogWarning("[Labyrinth] shaders missing from the project (fell back to MMN/BG/SimpleLit): "
                                 + string.Join(", ", missingShaders));
        }

        static void CollectTextureSlots(string pkgDir, Dictionary<string, object> man,
            Dictionary<string, HashSet<string>> slotByTexture)
        {
            foreach (var o in Get<List<object>>(man, "materials") ?? new List<object>())
            {
                var entry = o as Dictionary<string, object>;
                string file = Get<string>(entry, "file");
                if (file == null) continue;
                string jsonPath = $"{pkgDir}/materials/{file}";
                if (!File.Exists(jsonPath)) continue;
                var d = MiniJson.Deserialize(File.ReadAllText(jsonPath, Encoding.UTF8)) as Dictionary<string, object>;
                var texenvs = Get<Dictionary<string, object>>(d, "texenvs");
                if (texenvs == null) continue;
                foreach (var kv in texenvs)
                {
                    var te = kv.Value as Dictionary<string, object>;
                    string png = Get<string>(te, "png");
                    if (string.IsNullOrEmpty(png)) continue;
                    string stem = Path.GetFileNameWithoutExtension(png);
                    if (!slotByTexture.TryGetValue(stem, out var set))
                        slotByTexture[stem] = set = new HashSet<string>();
                    set.Add(kv.Key);
                }
            }
        }

        static Dictionary<string, Texture2D> ImportTextures(string pkgDir, Dictionary<string, object> man,
            Dictionary<string, HashSet<string>> slotByTexture)
        {
            var map = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);
            string texDir = Path.Combine(pkgDir, "textures");
            if (!Directory.Exists(texDir)) return map;

            var settings = Get<Dictionary<string, object>>(man, "textureSettings");

            foreach (var srcPath in Directory.GetFiles(texDir, "*.png"))
            {
                string fn = Path.GetFileName(srcPath);
                string stem = Path.GetFileNameWithoutExtension(fn);
                string dst = $"{OutRoot}/Textures/{fn}";
                string dstOs = dst.Replace('/', Path.DirectorySeparatorChar);

                bool fresh = !File.Exists(dstOs);
                if (fresh || new FileInfo(srcPath).LastWriteTimeUtc > new FileInfo(dstOs).LastWriteTimeUtc)
                    File.Copy(srcPath, dstOs, overwrite: true);
                else if (map.ContainsKey(stem))
                    continue;
                AssetDatabase.ImportAsset(dst);

                slotByTexture.TryGetValue(stem, out var slots);
                bool isNormal = slots != null && slots.Any(NormalSlots.Contains);
                // The shipped Texture2D carries the settings the original project imported it
                // with; the slot names are only a fallback for textures the extract predates.
                var shipped = Get<Dictionary<string, object>>(settings, fn);
                bool isLinear = shipped != null
                    ? ToF(shipped.TryGetValue("colorSpace", out var cs) ? cs : 1f) < 0.5f
                    : slots != null && slots.Any(LinearSlots.Contains);

                var ti = AssetImporter.GetAtPath(dst) as TextureImporter;
                if (ti != null)
                {
                    ti.textureType = isNormal ? TextureImporterType.NormalMap : TextureImporterType.Default;
                    ti.sRGBTexture = !isNormal && !isLinear;
                    ti.alphaSource = TextureImporterAlphaSource.FromInput;
                    ti.alphaIsTransparency = !isNormal && !isLinear;
                    ti.mipmapEnabled = shipped == null
                        || ToF(shipped.TryGetValue("mipCount", out var mc) ? mc : 1f) > 1.5f;
                    ti.filterMode = FilterMode.Bilinear;

                    if (shipped != null)
                    {
                        var wrapU = ToWrap(shipped, "wrapU");
                        var wrapV = ToWrap(shipped, "wrapV");
                        ti.wrapMode = wrapU;
                        if (wrapU != wrapV)
                        {
                            ti.wrapModeU = wrapU;
                            ti.wrapModeV = wrapV;
                        }
                    }
                    else
                    {
                        // The splat map maps 1:1 onto its floor mesh; a repeat wrap bleeds the
                        // far edge back over the near one along the border.
                        ti.wrapMode = (slots != null && slots.Contains("_T2M_SplatMap_0"))
                            ? TextureWrapMode.Clamp : TextureWrapMode.Repeat;
                    }
                    ti.SaveAndReimport();
                }

                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(dst);
                if (tex != null) map[stem] = tex;
            }
            return map;
        }

        static int ImportMaterials(string pkgDir, Dictionary<string, object> man,
            Dictionary<string, Texture2D> texMap, SortedSet<string> missingShaders,
            Dictionary<string, Material> byKey, Dictionary<long, Material> byPathId)
        {
            int count = 0;
            foreach (var o in Get<List<object>>(man, "materials") ?? new List<object>())
            {
                var entry = o as Dictionary<string, object>;
                string key = Get<string>(entry, "key");
                string file = Get<string>(entry, "file");
                if (key == null || file == null) continue;
                long pid = ToL(entry.TryGetValue("pathID", out var p) ? p : null);
                if (byKey.ContainsKey(key))
                {
                    // The same material ships inside several module packages; the later copies
                    // still need their pathID wired up or those renderers lose their binding.
                    if (pid != 0 && !byPathId.ContainsKey(pid)) byPathId[pid] = byKey[key];
                    continue;
                }

                string jsonPath = $"{pkgDir}/materials/{file}";
                if (!File.Exists(jsonPath)) continue;

                var mat = CreateMaterial(jsonPath, texMap, missingShaders);
                if (mat == null) continue;
                byKey[key] = mat;
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

            // Shader.Find("MMN/BG/SimpleLit") also hits the AssetRipper dummy under
            // Characters/Infant/Source, which is an unlit stub. Prefer the reconstructed
            // shader living under Assets/MMN/Shaders.
            Shader shader = ResolveMmnShader(wanted);
            if (shader == null)
            {
                if (!string.IsNullOrEmpty(wanted)) missingShaders.Add(wanted);
                shader = ResolveMmnShader("MMN/BG/SimpleLit");
            }
            if (shader == null) return null;

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

            // The shipped property blocks keep leftovers from older versions of the same
            // shader, so a value is only applied when this shader declares that name.
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
                    if (!c.HasValue) continue;
                    if (pt == ShaderPropertyType.Vector) mat.SetVector(kv.Key, c.Value);
                    else mat.SetColor(kv.Key, c.Value);
                }

            if (Get<Dictionary<string, object>>(d, "texenvs") is Dictionary<string, object> texenvs)
                foreach (var kv in texenvs)
                {
                    var te = kv.Value as Dictionary<string, object>;
                    if (te == null) continue;
                    if (!types.TryGetValue(kv.Key, out var pt) || pt != ShaderPropertyType.Texture) continue;

                    string png = Get<string>(te, "png");
                    if (!string.IsNullOrEmpty(png)
                        && texMap.TryGetValue(Path.GetFileNameWithoutExtension(png), out var tex))
                        mat.SetTexture(kv.Key, tex);

                    var scale = ToVector2(Get<List<object>>(te, "scale"));
                    var offset = ToVector2(Get<List<object>>(te, "offset"));
                    if (scale.HasValue && scale.Value != Vector2.zero) mat.SetTextureScale(kv.Key, scale.Value);
                    if (offset.HasValue) mat.SetTextureOffset(kv.Key, offset.Value);
                }

            if (mat.HasProperty("_MainTex") && mat.GetTexture("_MainTex") == null
                && mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") != null)
                mat.SetTexture("_MainTex", mat.GetTexture("_BaseMap"));

            if (mat.HasProperty("_QueueOffset"))
                mat.renderQueue = shader.renderQueue + Mathf.RoundToInt(mat.GetFloat("_QueueOffset"));

            EditorUtility.SetDirty(mat);
            return mat;
        }

        /// <summary>
        /// Resolves an MMN shader from Assets/MMN/Shaders first so AssetRipper
        /// dummies that reuse the same Shader.Find name do not win.
        /// </summary>
        internal static Shader ResolveMmnShader(string shaderName)
        {
            if (string.IsNullOrEmpty(shaderName)) return null;
            foreach (var guid in AssetDatabase.FindAssets("t:Shader", new[] { "Assets/MMN/Shaders" }))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                var s = AssetDatabase.LoadAssetAtPath<Shader>(path);
                if (s != null && s.name == shaderName) return s;
            }
            foreach (var guid in AssetDatabase.FindAssets("t:Shader"))
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                if (path.Contains("/Infant/Source/") || path.Contains("DummyShader")) continue;
                var s = AssetDatabase.LoadAssetAtPath<Shader>(path);
                if (s != null && s.name == shaderName) return s;
            }
            return Shader.Find(shaderName);
        }

        static Dictionary<string, ShaderPropertyType> PropertyTypes(Shader shader)
        {
            var map = new Dictionary<string, ShaderPropertyType>();
            int n = shader.GetPropertyCount();
            for (int i = 0; i < n; i++)
                map[shader.GetPropertyName(i)] = shader.GetPropertyType(i);
            return map;
        }

        static Dictionary<string, Mesh> ImportMeshes(string pkgDir, Dictionary<string, object> man)
        {
            var map = new Dictionary<string, Mesh>();
            foreach (var o in Get<List<object>>(man, "meshes") ?? new List<object>())
            {
                var entry = o as Dictionary<string, object>;
                string key = Get<string>(entry, "key");
                string file = Get<string>(entry, "file");
                if (key == null || file == null) continue;
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
                    Debug.LogError($"[Labyrinth] mesh {file}: {e.Message}");
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

                // Colour has to end up as a 32-bit channel: a Float32x4 channel reaches these
                // shaders as garbage and the vertex tint comes out wrong.
                Color32[] colors = null;
                if ((flags & 2) != 0)
                {
                    colors = new Color32[vc];
                    for (int i = 0; i < vc; i++)
                        colors[i] = (Color32)new Color(br.ReadSingle(), br.ReadSingle(),
                                                      br.ReadSingle(), br.ReadSingle());
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

        static (int nodes, int lights, int fx) BuildPackagePrefab(string id, Dictionary<string, object> man,
            Dictionary<string, Mesh> meshByKey, Dictionary<string, Material> matByKey,
            Dictionary<long, Material> matByPathId)
        {
            var dicts = (Get<List<object>>(man, "hierarchy") ?? new List<object>())
                .OfType<Dictionary<string, object>>().ToList();
            if (dicts.Count == 0) return (0, 0, 0);

            var goByPid = new Dictionary<long, GameObject>();
            foreach (var n in dicts)
                goByPid[ToL(n["pathID"])] = new GameObject(Get<string>(n, "name") ?? "node");

            int fx = 0;
            var renderers = new Dictionary<long, Renderer>();

            foreach (var n in dicts)
            {
                long pid = ToL(n["pathID"]);
                var go = goByPid[pid];

                object parentRaw = n.TryGetValue("parent", out var pr) ? pr : null;
                if (parentRaw != null && goByPid.TryGetValue(ToL(parentRaw), out var parentGo))
                    go.transform.SetParent(parentGo.transform, false);

                go.transform.localPosition = ToVector3(Get<List<object>>(n, "localPosition")) ?? Vector3.zero;
                go.transform.localRotation = ToQuaternion(Get<List<object>>(n, "localRotation")) ?? Quaternion.identity;
                go.transform.localScale = ToVector3(Get<List<object>>(n, "localScale")) ?? Vector3.one;
                if (n.TryGetValue("active", out var act) && act is bool ab)
                    go.SetActive(ab);

                // Phase 2 territory: the transform is kept so the FX pass only adds components.
                if (Get<Dictionary<string, object>>(n, "particle") != null)
                {
                    fx++;
                    continue;
                }

                string meshKey = Get<string>(n, "meshKey");
                if (string.IsNullOrEmpty(meshKey)
                    && string.Equals(Get<string>(n, "meshBinding"), "builtin", StringComparison.OrdinalIgnoreCase))
                    meshKey = Get<string>(n, "meshName");
                Mesh mesh = null;
                if (!string.IsNullOrEmpty(meshKey))
                {
                    if (meshKey.StartsWith("builtin:", StringComparison.OrdinalIgnoreCase))
                        mesh = BuiltinMesh(meshKey);
                    else
                        meshByKey.TryGetValue(meshKey, out mesh);
                }
                if (mesh == null) continue;

                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                var mr = go.AddComponent<MeshRenderer>();
                var mats = ResolveMaterials(n, matByKey, matByPathId);
                while (mats.Count < mesh.subMeshCount && mats.Count > 0)
                    mats.Add(mats[mats.Count - 1]);
                if (mats.Count > 0) mr.sharedMaterials = mats.ToArray();
                renderers[pid] = mr;
            }

            int lights = ApplyLights(man, goByPid);
            PairLodGroups(dicts, goByPid, renderers);

            var roots = dicts
                .Where(n => !(n.TryGetValue("parent", out var pr) && pr != null && goByPid.ContainsKey(ToL(pr))))
                .Select(n => goByPid[ToL(n["pathID"])])
                .ToList();

            GameObject root;
            if (roots.Count == 1)
            {
                root = roots[0];
            }
            else
            {
                root = new GameObject(id);
                foreach (var r in roots) r.transform.SetParent(root.transform, true);
            }

            HideLodSuffixObjects(root);

            string prefabPath = $"{OutRoot}/Prefabs/{Sanitize(id)}.prefab";
            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
            UnityEngine.Object.DestroyImmediate(root);
            return (dicts.Count, lights, fx);
        }

        static int ApplyLights(Dictionary<string, object> man, Dictionary<long, GameObject> goByPid)
        {
            int n = 0;
            foreach (var o in Get<List<object>>(man, "authoredLights") ?? new List<object>())
            {
                var d = o as Dictionary<string, object>;
                if (d == null) continue;
                if (!goByPid.TryGetValue(ToL(d.TryGetValue("node", out var nd) ? nd : null), out var go))
                    continue;
                var light = go.AddComponent<Light>();
                // Unity's LightType numbering: 0 spot, 1 directional, 2 point.
                int t = (int)ToF(d.TryGetValue("type", out var tv) ? tv : 2f);
                light.type = t == 0 ? LightType.Spot : t == 1 ? LightType.Directional : LightType.Point;
                var c = ToColor(d.TryGetValue("color", out var cv) ? cv : null);
                if (c.HasValue) light.color = c.Value;
                light.intensity = ToF(d.TryGetValue("intensity", out var iv) ? iv : 1f);
                light.range = ToF(d.TryGetValue("range", out var rv) ? rv : 10f);
                light.spotAngle = Mathf.Clamp(ToF(d.TryGetValue("spotAngle", out var sa) ? sa : 30f), 1f, 179f);
                light.innerSpotAngle = Mathf.Clamp(ToF(d.TryGetValue("innerSpotAngle", out var ia) ? ia : 0f), 0f, 179f);
                light.shadows = (int)ToF(d.TryGetValue("shadows", out var sh) ? sh : 0f) > 0
                    ? LightShadows.Soft : LightShadows.None;
                light.bounceIntensity = ToF(d.TryGetValue("bounceIntensity", out var bi) ? bi : 1f);
                n++;
            }
            return n;
        }

        /// <summary>
        /// Joins each &lt;name&gt; / &lt;name&gt;_LOD1 pair under a LODGroup.
        ///
        /// Both nodes sit at the same origin holding the same silhouette at different
        /// densities, so without this every module renders twice and the two shells z-fight
        /// across the whole plaza.
        /// </summary>
        static void PairLodGroups(List<Dictionary<string, object>> dicts,
            Dictionary<long, GameObject> goByPid, Dictionary<long, Renderer> renderers)
        {
            var byName = new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
            foreach (var n in dicts)
            {
                long pid = ToL(n["pathID"]);
                if (!renderers.ContainsKey(pid)) continue;
                string nm = Get<string>(n, "name");
                if (string.IsNullOrEmpty(nm) || IsLod1(nm)) continue;
                if (!byName.ContainsKey(nm)) byName[nm] = pid;
            }

            foreach (var n in dicts)
            {
                long lodPid = ToL(n["pathID"]);
                if (!renderers.TryGetValue(lodPid, out var lodRenderer)) continue;
                string nm = Get<string>(n, "name");
                if (string.IsNullOrEmpty(nm) || !IsLod1(nm)) continue;

                string baseName = nm.Substring(0, nm.Length - 5);
                if (!byName.TryGetValue(baseName, out var basePid)) continue;
                var baseRenderer = renderers[basePid];
                var baseGo = goByPid[basePid];
                var lodGo = goByPid[lodPid];
                if (baseGo.transform.parent != lodGo.transform.parent) continue;

                var group = new GameObject(baseName + "_LODGroup");
                group.transform.SetParent(baseGo.transform.parent, false);
                group.transform.localPosition = baseGo.transform.localPosition;
                baseGo.transform.SetParent(group.transform, true);
                lodGo.transform.SetParent(group.transform, true);

                var lg = group.AddComponent<LODGroup>();
                lg.SetLODs(new[]
                {
                    new LOD(0.25f, new[] { baseRenderer }),
                    new LOD(0.02f, new[] { lodRenderer }),
                });
                lg.RecalculateBounds();
            }
        }

        static bool IsLod1(string name)
        {
            return name.Length > 5
                   && name.EndsWith("_LOD1", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// LOD1 meshes occupy the same world space as LOD0. About half of them never
        /// make it into a LODGroup (they ship as children of the high mesh, not siblings),
        /// so both draw and z-fight. Hide every *_LOD* node except the wrapper we create.
        /// </summary>
        internal static int HideLodSuffixObjects(GameObject root)
        {
            if (root == null) return 0;
            int n = 0;
            foreach (var t in root.GetComponentsInChildren<Transform>(true))
            {
                if (t == root.transform) continue;
                if (!IsLodSuffixName(t.name)) continue;
                if (!t.gameObject.activeSelf) continue;
                t.gameObject.SetActive(false);
                n++;
            }
            return n;
        }

        static bool IsLodSuffixName(string name)
        {
            if (name.IndexOf("_LODGroup", StringComparison.OrdinalIgnoreCase) >= 0) return false;
            return name.IndexOf("_LOD", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        [MenuItem("Tools/Labyrinth/Hide LOD Suffix Meshes")]
        public static void HideLodSuffixMeshesInScene()
        {
            var roots = UnityEngine.SceneManagement.SceneManager.GetActiveScene().GetRootGameObjects();
            int n = 0;
            foreach (var r in roots) n += HideLodSuffixObjects(r);
            if (n > 0) UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(
                UnityEngine.SceneManagement.SceneManager.GetActiveScene());
            Debug.Log($"[Labyrinth] hid {n} _LOD suffix object(s)");
        }

        static List<Material> ResolveMaterials(Dictionary<string, object> n,
            Dictionary<string, Material> matByKey, Dictionary<long, Material> matByPathId)
        {
            var mats = new List<Material>();
            foreach (var o in Get<List<object>>(n, "materialPathIDs") ?? new List<object>())
                if (matByPathId.TryGetValue(ToL(o), out var m))
                    mats.Add(m);
            if (mats.Count == 0)
                foreach (var k in Get<List<object>>(n, "materialKeys") ?? new List<object>())
                    if (k is string ks && matByKey.TryGetValue(ks, out var m))
                        mats.Add(m);
            if (mats.Count == 0)
                foreach (var k in Get<List<object>>(n, "materialNames") ?? new List<object>())
                    if (k is string ks && matByKey.TryGetValue(ks, out var m))
                        mats.Add(m);
            return mats;
        }

        /// <summary>Meshes the extractor records as "builtin:&lt;name&gt;" instead of copying.</summary>
        static Mesh BuiltinMesh(string spec)
        {
            string name = spec.Substring("builtin:".Length);
            var probe = GameObject.CreatePrimitive(
                name.Equals("Sphere", StringComparison.OrdinalIgnoreCase) ? PrimitiveType.Sphere :
                name.Equals("Plane", StringComparison.OrdinalIgnoreCase) ? PrimitiveType.Plane :
                name.Equals("Quad", StringComparison.OrdinalIgnoreCase) ? PrimitiveType.Quad :
                name.Equals("Cylinder", StringComparison.OrdinalIgnoreCase) ? PrimitiveType.Cylinder :
                name.Equals("Capsule", StringComparison.OrdinalIgnoreCase) ? PrimitiveType.Capsule :
                PrimitiveType.Cube);
            var mesh = probe.GetComponent<MeshFilter>().sharedMesh;
            UnityEngine.Object.DestroyImmediate(probe);
            return mesh;
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

        internal static T Get<T>(Dictionary<string, object> d, string key) where T : class
        {
            if (d == null || !d.TryGetValue(key, out var v)) return null;
            return v as T;
        }

        static TextureWrapMode ToWrap(Dictionary<string, object> d, string key)
        {
            switch ((int)ToF(d.TryGetValue(key, out var v) ? v : 0f))
            {
                case 1: return TextureWrapMode.Clamp;
                case 2: return TextureWrapMode.Mirror;
                case 3: return TextureWrapMode.MirrorOnce;
                default: return TextureWrapMode.Repeat;
            }
        }

        internal static float ToF(object o)
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
            return new Quaternion(ToF(l[0]), ToF(l[1]), ToF(l[2]), ToF(l[3])).normalized;
        }

        internal static Color? ToColor(object o)
        {
            if (!(o is List<object> l) || l.Count < 3) return null;
            return new Color(ToF(l[0]), ToF(l[1]), ToF(l[2]), l.Count > 3 ? ToF(l[3]) : 1f);
        }
    }
}
