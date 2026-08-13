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

namespace ColhenBeach.Editor
{
    /// <summary>
    /// Imports the Colhen beach pack produced by _re_work/extract_colhen_beach.py: the water
    /// plane, the shoreline wave particle emitters, the far terrain and the sand terrain tiles.
    ///
    /// It differs from DungeonPackImporter in three ways that the beach needs: textures are
    /// imported with the colour space their slot requires (splat maps and noise are data, not
    /// colour), nodes may carry a particle system instead of a mesh renderer, and a mesh may be
    /// one of Unity's built-ins (the caustics decal box).
    /// </summary>
    public static class ColhenBeachImporter
    {
        const string PackRoot = "Assets/ColhenBeach/_import_pack";
        const string OutRoot = "Assets/ColhenBeach";

        // Slots whose texture is data rather than colour, so sRGB has to be off or the values the
        // shader compares against (splat weights, noise thresholds) come out gamma-warped.
        static readonly HashSet<string> LinearSlots = new HashSet<string>
        {
            "_T2M_SplatMap_0", "_MaskMap", "_NoiseTex", "_NoiseTex2", "_VertexTex",
            "_DistortionTexture", "_SnowSparklingMap", "_SpecGlossMap"
        };

        static readonly HashSet<string> NormalSlots = new HashSet<string> { "_BumpMap" };

        [MenuItem("MMN/Colhen Beach/1. Import Beach Assets")]
        public static void ImportAll()
        {
            string catalogPath = PackRoot + "/catalog.json";
            if (!File.Exists(catalogPath))
            {
                Debug.LogError($"[ColhenBeach] missing {catalogPath} - run extract_colhen_beach.py and copy the pack in");
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
                    Debug.LogError($"[ColhenBeach] missing {manPath}");
                    continue;
                }
                manifests.Add((Get<string>(pkg, "id"), pkgDir,
                    MiniJson.Deserialize(File.ReadAllText(manPath, Encoding.UTF8)) as Dictionary<string, object>));
            }

            // Which slot a PNG is used in decides how it is imported, so every material is read
            // before any texture is touched.
            var slotByTexture = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var (_, dir, man) in manifests)
                CollectTextureSlots(dir, man, slotByTexture);

            int totalMesh = 0, totalMat = 0, totalTex = 0, totalNodes = 0;
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
                    totalNodes += BuildPackagePrefab(id, man, meshByKey, matByKey, matByPathId);
                }
            }
            finally
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }

            Debug.Log($"[ColhenBeach] imported meshes={totalMesh} materials={totalMat} textures={totalTex} nodes={totalNodes}");
            if (missingShaders.Count > 0)
                Debug.LogWarning("[ColhenBeach] shaders missing from the project (fell back to MMN/BG/SimpleLit): "
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

                if (!File.Exists(dstOs) || new FileInfo(srcPath).LastWriteTimeUtc > new FileInfo(dstOs).LastWriteTimeUtc)
                    File.Copy(srcPath, dstOs, overwrite: true);
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
                        // U and V can differ - FX_Mask_47 repeats vertically (each particle picks
                        // a band of the atlas) but clamps horizontally so the wave mask holds its
                        // edge instead of tiling back over itself.
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
                        // The splat map has to stay clamped: it maps 1:1 onto the terrain, and a
                        // repeat wrap bleeds the far edge back over the near one on the border tiles.
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
                if (byKey.ContainsKey(key)) continue;

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

            // The shipped property blocks carry leftovers from older versions of the same shader
            // (Colhen_Water_Caustic still holds ~15 properties the current MMN/BG/Caustic dropped),
            // so a value is only applied when this shader actually declares that name.
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

            // The FX shaders drive their own blend from _BlendSrc/_BlendDst, so the queue has to
            // follow the material rather than the shader default, or the shoreline waves sort
            // behind the water they sit on.
            if (mat.HasProperty("_QueueOffset"))
                mat.renderQueue = shader.renderQueue + Mathf.RoundToInt(mat.GetFloat("_QueueOffset"));

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
                    Debug.LogError($"[ColhenBeach] mesh {file}: {e.Message}");
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

                // Colour has to end up as a 32-bit channel (Color32, not Color): the mesh-particle
                // geometry builder assumes packed colours, and a Float32x4 channel reaches the shader
                // as garbage - the wave foam then reads that as its tint and comes out blue.
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

        /// <summary>
        /// The caustics decal is drawn on Unity's built-in cube, which the extractor records as
        /// "builtin:Cube" instead of writing a copy of it into the pack.
        /// </summary>
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

        static int BuildPackagePrefab(string id, Dictionary<string, object> man,
            Dictionary<string, Mesh> meshByKey, Dictionary<string, Material> matByKey,
            Dictionary<long, Material> matByPathId)
        {
            var dicts = (Get<List<object>>(man, "hierarchy") ?? new List<object>())
                .OfType<Dictionary<string, object>>().ToList();
            if (dicts.Count == 0) return 0;

            var goByPid = new Dictionary<long, GameObject>();
            foreach (var n in dicts)
                goByPid[ToL(n["pathID"])] = new GameObject(Get<string>(n, "name") ?? "node");

            foreach (var n in dicts)
            {
                var go = goByPid[ToL(n["pathID"])];

                object parentRaw = n.TryGetValue("parent", out var pr) ? pr : null;
                if (parentRaw != null && goByPid.TryGetValue(ToL(parentRaw), out var parentGo))
                    go.transform.SetParent(parentGo.transform, false);

                go.transform.localPosition = ToVector3(Get<List<object>>(n, "localPosition")) ?? Vector3.zero;
                go.transform.localRotation = ToQuaternion(Get<List<object>>(n, "localRotation")) ?? Quaternion.identity;
                go.transform.localScale = ToVector3(Get<List<object>>(n, "localScale")) ?? Vector3.one;
                if (n.TryGetValue("active", out var act) && act is bool ab)
                    go.SetActive(ab);

                var particle = Get<Dictionary<string, object>>(n, "particle");
                if (particle != null)
                {
                    BuildParticleSystem(go, particle, meshByKey, matByKey, matByPathId);
                    continue;
                }

                var mats = ResolveMaterials(n, matByKey, matByPathId);
                string meshKey = Get<string>(n, "meshKey");
                // A built-in mesh has no pack file, so the extractor leaves meshKey empty and
                // records "builtin:<name>" in meshName instead.
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
                while (mats.Count < mesh.subMeshCount && mats.Count > 0)
                    mats.Add(mats[mats.Count - 1]);
                if (mats.Count > 0) mr.sharedMaterials = mats.ToArray();
            }

            var roots = dicts
                .Where(n => !(n.TryGetValue("parent", out var pr) && pr != null && goByPid.ContainsKey(ToL(pr))))
                .Select(n => goByPid[ToL(n["pathID"])])
                .ToList();

            GameObject root;
            bool wrapped = roots.Count != 1;
            if (!wrapped)
            {
                root = roots[0];
            }
            else
            {
                root = new GameObject(id);
                foreach (var r in roots) r.transform.SetParent(root.transform, true);
            }

            string prefabPath = $"{OutRoot}/Prefabs/{Sanitize(id)}.prefab";
            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
            UnityEngine.Object.DestroyImmediate(root);
            Debug.Log($"[ColhenBeach] prefab {prefabPath} ({dicts.Count} nodes)");
            return dicts.Count;
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

        /// <summary>
        /// Rebuilds a shoreline emitter from the shipped ParticleSystem fields: lifetime, speed, the
        /// non-uniform start size and start rotation, emission, shape, the size and colour curves,
        /// and the renderer's mesh, material, alignment and pivot.
        ///
        /// NOT-IMPLEMENTED: the velocity, noise, rotation-over-lifetime and UV modules. None of the
        /// nine beach emitters enables them, so nothing is lost here, but a different FX would need
        /// them extracted before it looked right. CustomData Color mode is also unused on this set.
        /// </summary>
        static void BuildParticleSystem(GameObject go, Dictionary<string, object> p,
            Dictionary<string, Mesh> meshByKey, Dictionary<string, Material> matByKey,
            Dictionary<long, Material> matByPathId)
        {
            var ps = go.AddComponent<ParticleSystem>();
            var main = ps.main;
            main.duration = ToF(p.TryGetValue("duration", out var du) ? du : 3f);
            main.loop = ToB(p, "looping", true);
            main.prewarm = ToB(p, "prewarm", false);
            main.simulationSpeed = Mathf.Max(0.01f, ToF(p.TryGetValue("simulationSpeed", out var ss) ? ss : 1f));
            main.maxParticles = Mathf.Max(1, (int)ToF(p.TryGetValue("maxParticles", out var mp) ? mp : 10f));
            main.startLifetime = MinMax(Get<Dictionary<string, object>>(p, "startLifetime"), 3f);
            main.startSpeed = MinMax(Get<Dictionary<string, object>>(p, "startSpeed"), 1f);
            main.startSize = MinMax(Get<Dictionary<string, object>>(p, "startSize"), 1f);
            // The wave cards are long strips: 15..25 across by 40..45 along the shore. Uniform size
            // squashes them into slivers, which is what made the shoreline read as vertical combs.
            if (ToB(p, "size3D", false))
            {
                main.startSize3D = true;
                main.startSizeX = MinMax(Get<Dictionary<string, object>>(p, "startSize"), 1f);
                main.startSizeY = MinMax(Get<Dictionary<string, object>>(p, "startSizeY"), 1f);
                main.startSizeZ = MinMax(Get<Dictionary<string, object>>(p, "startSizeZ"), 1f);
            }
            if (ToB(p, "rotation3D", false))
            {
                main.startRotation3D = true;
                main.startRotationX = Radians(Get<Dictionary<string, object>>(p, "startRotationX"));
                main.startRotationY = Radians(Get<Dictionary<string, object>>(p, "startRotationY"));
                main.startRotationZ = Radians(Get<Dictionary<string, object>>(p, "startRotationZ"));
            }
            else
            {
                main.startRotation = Radians(Get<Dictionary<string, object>>(p, "startRotationZ"));
            }
            main.gravityModifier = MinMax(Get<Dictionary<string, object>>(p, "gravityModifier"), 0f);
            var startColor = ToColor(p.TryGetValue("startColor", out var sc) ? sc : null);
            if (startColor.HasValue) main.startColor = startColor.Value;
            // scalingMode 1 is Local: emitter scale drives the particles, not the whole hierarchy.
            main.scalingMode = ToF(p.TryGetValue("scalingMode", out var sm) ? sm : 1f) < 0.5f
                ? ParticleSystemScalingMode.Hierarchy : ParticleSystemScalingMode.Local;
            // moveWithTransform 0/1/2 = Local/World/Custom. Defaulting to World would drag the
            // already-authored world positions around with the parent and park the cards in the bay.
            int sim = (int)ToF(p.TryGetValue("simulationSpace", out var simo) ? simo : 0f);
            main.simulationSpace = sim == 1 ? ParticleSystemSimulationSpace.World
                : sim == 2 ? ParticleSystemSimulationSpace.Custom
                : ParticleSystemSimulationSpace.Local;
            main.playOnAwake = ToB(p, "playOnAwake", true);

            var emission = ps.emission;
            var rate = Get<Dictionary<string, object>>(p, "emissionRate");
            emission.enabled = ToB(p, "emissionEnabled", true);
            emission.rateOverTime = MinMax(rate, 1f);
            var bursts = Get<List<object>>(p, "bursts");
            if (bursts != null && bursts.Count > 0)
            {
                var list = new List<ParticleSystem.Burst>();
                foreach (var bo in bursts)
                {
                    var b = bo as Dictionary<string, object>;
                    if (b == null) continue;
                    list.Add(new ParticleSystem.Burst(
                        ToF(b.TryGetValue("time", out var t) ? t : 0f),
                        (short)ToF(b.TryGetValue("countMin", out var cm) ? cm : 1f),
                        (short)ToF(b.TryGetValue("countMax", out var cx) ? cx : 1f)));
                }
                if (list.Count > 0) emission.SetBursts(list.ToArray());
            }

            var shapeData = Get<Dictionary<string, object>>(p, "shape");
            var shape = ps.shape;
            if (shapeData != null)
            {
                shape.enabled = ToB(shapeData, "enabled", true);
                // The extractor writes the enum name, so the whole set round-trips: the breakers use
                // a flat Box spread along the shore, the wash uses a SingleSidedEdge.
                string type = Get<string>(shapeData, "type") ?? "Box";
                shape.shapeType = Enum.TryParse(type, true, out ParticleSystemShapeType parsed)
                    ? parsed : ParticleSystemShapeType.Box;
                var sscale = ToVector3(Get<List<object>>(shapeData, "scale"));
                if (sscale.HasValue) shape.scale = sscale.Value;
                var srot = ToVector3(Get<List<object>>(shapeData, "rotation"));
                if (srot.HasValue) shape.rotation = srot.Value;
                var spos = ToVector3(Get<List<object>>(shapeData, "position"));
                if (spos.HasValue) shape.position = spos.Value;
                shape.radius = Mathf.Max(0.01f, ToF(shapeData.TryGetValue("radius", out var rr) ? rr : 1f));
                shape.radiusThickness = ToF(shapeData.TryGetValue("radiusThickness", out var rth) ? rth : 1f);
                shape.angle = ToF(shapeData.TryGetValue("angle", out var an) ? an : 25f);
                shape.arc = ToF(shapeData.TryGetValue("arc", out var ar) ? ar : 360f);
                shape.alignToDirection = ToB(shapeData, "alignToDirection", false);
                shape.randomDirectionAmount = ToF(shapeData.TryGetValue("randomDirection", out var rd) ? rd : 0f);
            }
            else
            {
                shape.enabled = false;
            }

            if (ToB(p, "colorOverLifetime", false))
            {
                var col = ps.colorOverLifetime;
                col.enabled = true;
                col.color = new ParticleSystem.MinMaxGradient(
                    BuildGradient(Get<Dictionary<string, object>>(p, "colorGradient")));
            }

            if (ToB(p, "sizeOverLifetime", false))
            {
                var size = ps.sizeOverLifetime;
                size.enabled = true;
                size.size = MinMax(Get<Dictionary<string, object>>(p, "sizeCurve"), 1f);
            }

            ApplyCustomData(ps, Get<Dictionary<string, object>>(p, "customData"));

            var rendererData = Get<Dictionary<string, object>>(p, "renderer");
            var pr = go.GetComponent<ParticleSystemRenderer>();
            if (rendererData != null && pr != null)
            {
                string mode = Get<string>(rendererData, "renderMode") ?? "Billboard";
                pr.renderMode = mode.Equals("Mesh", StringComparison.OrdinalIgnoreCase)
                    ? ParticleSystemRenderMode.Mesh
                    : mode.Equals("Stretch", StringComparison.OrdinalIgnoreCase)
                        ? ParticleSystemRenderMode.Stretch
                        : ParticleSystemRenderMode.Billboard;
                pr.lengthScale = ToF(rendererData.TryGetValue("lengthScale", out var ls) ? ls : 2f);
                pr.sortingFudge = ToF(rendererData.TryGetValue("sortingFudge", out var sf) ? sf : 0f);
                // The breakers ship as Velocity (4) so each card turns to face the way it is running
                // up the sand; the wash cards are Local (2) and take the emitter's own orientation.
                int alignment = (int)ToF(rendererData.TryGetValue("alignment", out var al) ? al : 0f);
                pr.alignment = alignment >= 0 && alignment <= 4
                    ? (ParticleSystemRenderSpace)alignment : ParticleSystemRenderSpace.View;
                int sortMode = (int)ToF(rendererData.TryGetValue("sortMode", out var sortm) ? sortm : 0f);
                if (sortMode >= 0 && sortMode <= 4) pr.sortMode = (ParticleSystemSortMode)sortMode;
                var pivot = ToVector3(Get<List<object>>(rendererData, "pivot"));
                if (pivot.HasValue) pr.pivot = pivot.Value;
                var flip = ToVector3(Get<List<object>>(rendererData, "flip"));
                if (flip.HasValue) pr.flip = flip.Value;
                pr.normalDirection = ToF(rendererData.TryGetValue("normalDirection", out var nd) ? nd : 1f);
                pr.minParticleSize = ToF(rendererData.TryGetValue("minParticleSize", out var mn) ? mn : 0f);
                pr.maxParticleSize = ToF(rendererData.TryGetValue("maxParticleSize", out var mx) ? mx : 0.5f);
                pr.enableGPUInstancing = ToB(rendererData, "enableGPUInstancing", true);

                string meshKey = Get<string>(rendererData, "meshKey");
                if (!string.IsNullOrEmpty(meshKey) && meshByKey.TryGetValue(meshKey, out var m))
                    pr.mesh = m;

                var mats = ResolveMaterials(rendererData, matByKey, matByPathId);
                if (mats.Count > 0) pr.sharedMaterial = mats[0];

                // Must come after mesh/material: Unity rewrites the stream list when those change.
                // The shipped layout is Position, Normal, Color, UV, Custom1XYZW, Custom2XYZW so
                // TEXCOORD0.zw carries dissolve and vertex-offset power into the FX shader.
                var streamObjs = Get<List<object>>(rendererData, "vertexStreams");
                if (ToB(rendererData, "useCustomVertexStreams", false)
                    && streamObjs != null && streamObjs.Count > 0)
                {
                    var streams = new List<ParticleSystemVertexStream>(streamObjs.Count);
                    foreach (var s in streamObjs)
                        streams.Add((ParticleSystemVertexStream)(int)ToF(s));
                    pr.SetActiveVertexStreams(streams);
                }
            }
        }

        /// <summary>
        /// Custom1.xy land in TEXCOORD0.zw of the dissolve shader. Without this module the shader
        /// falls back to dissolve=1 / offset=1, so the cards never thin out or lift off the water.
        /// </summary>
        static void ApplyCustomData(ParticleSystem ps, Dictionary<string, object> data)
        {
            if (data == null || !ToB(data, "enabled", false)) return;
            var cd = ps.customData;
            cd.enabled = true;
            ApplyCustomSlot(cd, ParticleSystemCustomData.Custom1, data, "mode0", "count0", "vector0");
            ApplyCustomSlot(cd, ParticleSystemCustomData.Custom2, data, "mode1", "count1", "vector1");
        }

        static void ApplyCustomSlot(ParticleSystem.CustomDataModule cd, ParticleSystemCustomData slot,
            Dictionary<string, object> data, string modeKey, string countKey, string vectorKey)
        {
            int mode = (int)ToF(data.TryGetValue(modeKey, out var mo) ? mo : 0f);
            cd.SetMode(slot, mode == 2 ? ParticleSystemCustomDataMode.Color
                : mode == 1 ? ParticleSystemCustomDataMode.Vector
                : ParticleSystemCustomDataMode.Disabled);
            if (mode != 1) return;
            int count = Mathf.Clamp((int)ToF(data.TryGetValue(countKey, out var c) ? c : 4f), 1, 4);
            cd.SetVectorComponentCount(slot, count);
            var vecs = Get<List<object>>(data, vectorKey);
            if (vecs == null) return;
            for (int i = 0; i < count && i < vecs.Count; i++)
                cd.SetVector(slot, i, MinMax(vecs[i] as Dictionary<string, object>, 0f));
        }

        static ParticleSystem.MinMaxCurve MinMax(Dictionary<string, object> d, float fallback)
        {
            if (d == null) return new ParticleSystem.MinMaxCurve(fallback);
            float min = ToF(d.TryGetValue("min", out var a) ? a : fallback);
            float max = ToF(d.TryGetValue("max", out var b) ? b : min);
            // mode mirrors Unity's MinMaxState: 1/2 are curves, 3 is a constant range, 0 a constant.
            int mode = (int)ToF(d.TryGetValue("mode", out var mo) ? mo : 0f);
            var keys = Get<List<object>>(d, "keys");
            if ((mode == 1 || mode == 2) && keys != null && keys.Count > 1)
            {
                var keysMin = Get<List<object>>(d, "keysMin");
                return mode == 2 && keysMin != null && keysMin.Count > 1
                    ? new ParticleSystem.MinMaxCurve(max, KeysToCurve(keysMin), KeysToCurve(keys))
                    : new ParticleSystem.MinMaxCurve(max, KeysToCurve(keys));
            }
            return mode == 3 && !Mathf.Approximately(min, max)
                ? new ParticleSystem.MinMaxCurve(min, max)
                : new ParticleSystem.MinMaxCurve(max);
        }

        static Gradient BuildGradient(Dictionary<string, object> d)
        {
            var grad = new Gradient();
            var colorKeys = new List<GradientColorKey>();
            var alphaKeys = new List<GradientAlphaKey>();
            foreach (var ko in Get<List<object>>(d, "colorKeys") ?? new List<object>())
                if (ko is List<object> k && k.Count >= 4)
                    colorKeys.Add(new GradientColorKey(
                        new Color(ToF(k[1]), ToF(k[2]), ToF(k[3])), ToF(k[0])));
            foreach (var ko in Get<List<object>>(d, "alphaKeys") ?? new List<object>())
                if (ko is List<object> k && k.Count >= 2)
                    alphaKeys.Add(new GradientAlphaKey(ToF(k[1]), ToF(k[0])));

            if (colorKeys.Count == 0)
                colorKeys.Add(new GradientColorKey(Color.white, 0f));
            if (alphaKeys.Count == 0)
            {
                alphaKeys.Add(new GradientAlphaKey(0f, 0f));
                alphaKeys.Add(new GradientAlphaKey(1f, 0.3f));
                alphaKeys.Add(new GradientAlphaKey(0f, 1f));
            }
            grad.SetKeys(colorKeys.ToArray(), alphaKeys.ToArray());
            return grad;
        }

        /// <summary>
        /// Keys arrive as [time, value, inSlope, outSlope, inWeight, outWeight, weightedMode] and
        /// the tangents are used as extracted. Re-deriving them with SmoothTangents overshoots
        /// badly at peaks and troughs - on the wave dissolve curve it drives the value negative
        /// between keys, which inverts the foam mask.
        /// </summary>
        static AnimationCurve KeysToCurve(List<object> keys)
        {
            var frames = new List<Keyframe>();
            bool haveTangents = false;
            foreach (var ko in keys)
            {
                if (!(ko is List<object> k) || k.Count < 2) continue;
                var f = k.Count >= 4
                    ? new Keyframe(ToF(k[0]), ToF(k[1]), ToF(k[2]), ToF(k[3]))
                    : new Keyframe(ToF(k[0]), ToF(k[1]));
                if (k.Count >= 7)
                {
                    f.inWeight = ToF(k[4]);
                    f.outWeight = ToF(k[5]);
                    f.weightedMode = (WeightedMode)(int)ToF(k[6]);
                }
                haveTangents |= k.Count >= 4;
                frames.Add(f);
            }

            var curve = new AnimationCurve(frames.ToArray());
            if (!haveTangents)
                for (int i = 0; i < curve.length; i++)
                    curve.SmoothTangents(i, 0f);
            return curve;
        }

        /// <summary>
        /// Start rotation passes through untouched. The inspector shows degrees, but both the
        /// serialised field and MainModule.startRotation* are radians, so converting turns the
        /// shipped 4.712 (a quarter turn, which lays the wave card flat on the water) into 15469,
        /// i.e. 43 spins landing back at vertical.
        /// </summary>
        static ParticleSystem.MinMaxCurve Radians(Dictionary<string, object> d)
        {
            return MinMax(d, 0f);
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

        // UnityEngine.Rendering.TextureWrapMode as stored in the shipped Texture2D.
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

        static bool ToB(Dictionary<string, object> d, string key, bool fallback)
        {
            if (d == null || !d.TryGetValue(key, out var v)) return fallback;
            if (v is bool b) return b;
            return ToF(v) > 0.5f;
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
            return new Quaternion(ToF(l[0]), ToF(l[1]), ToF(l[2]), ToF(l[3])).normalized;
        }

        static Color? ToColor(object o)
        {
            if (!(o is List<object> l) || l.Count < 3) return null;
            return new Color(ToF(l[0]), ToF(l[1]), ToF(l[2]), l.Count > 3 ? ToF(l[3]) : 1f);
        }
    }
}
