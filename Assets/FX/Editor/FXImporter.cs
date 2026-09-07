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

namespace FX.Editor
{
    /// <summary>
    /// Imports the environment FX pack produced by _re_work/extract_fx_environment.py.
    /// Shared textures/materials/meshes land under Assets/FX/0_resource; each prefab is
    /// written back to its original 1_effect/environment/... path.
    /// </summary>
    public static class FXImporter
    {
        const string PackRoot = "Assets/FX/_import_pack";
        const string OutRoot = "Assets/FX";
        const string TexRoot = OutRoot + "/0_resource/texture";
        const string MatRoot = OutRoot + "/0_resource/materials_new";
        const string MeshRoot = OutRoot + "/0_resource/mesh";

        static readonly HashSet<string> LinearSlots = new HashSet<string>
        {
            "_MaskMap", "_NoiseTex", "_NoiseTex2", "_DistortionTexture", "_SpecGlossMap"
        };

        static readonly HashSet<string> NormalSlots = new HashSet<string> { "_BumpMap" };

        static readonly string[] PreviewFxIds =
        {
            "1_effect/environment/actionprop/fx_tool_campfire_colhen_loop",
            "1_effect/environment/town/colhen/fx_colhen_shoreline_01",
            "1_effect/environment/prop/fx_campfire_colhen_loop",
        };

        [MenuItem("MMN/FX/1. Import Environment FX")]
        public static void ImportAll()
        {
            ImportPackages(null);
        }

        [MenuItem("MMN/FX/1b. Reimport Scene Preview FX")]
        public static void ImportPreviewFx()
        {
            ImportPackages(PreviewFxIds);
        }

        public static void ImportPackages(string[] onlyIds)
        {
            string catalogPath = PackRoot + "/catalog.json";
            if (!File.Exists(catalogPath))
            {
                Debug.LogError($"[FX] missing {catalogPath} - run extract_fx_environment.py first");
                return;
            }

            foreach (var sub in new[] { TexRoot, MatRoot, MeshRoot, OutRoot + "/1_effect/environment" })
                EnsureFolder(sub);

            var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
            var packages = Get<List<object>>(catalog, "packages") ?? new List<object>();
            var only = onlyIds == null
                ? null
                : new HashSet<string>(onlyIds, StringComparer.OrdinalIgnoreCase);

            var manifests = new List<(string id, string dir, string originalPath, Dictionary<string, object> man)>();
            foreach (var po in packages)
            {
                var pkg = po as Dictionary<string, object>;
                if (pkg == null) continue;
                string id = Get<string>(pkg, "id");
                if (only != null && (id == null || !only.Contains(id))) continue;
                string pkgDir = $"{PackRoot}/{Get<string>(pkg, "path")}";
                string manPath = pkgDir + "/package.json";
                if (!File.Exists(manPath))
                {
                    Debug.LogError($"[FX] missing {manPath}");
                    continue;
                }
                Dictionary<string, object> man;
                try
                {
                    man = MiniJson.Deserialize(File.ReadAllText(manPath, Encoding.UTF8)) as Dictionary<string, object>;
                }
                catch (Exception e)
                {
                    Debug.LogError($"[FX] failed to parse {manPath}: {e.Message}");
                    continue;
                }
                manifests.Add((
                    id,
                    pkgDir,
                    Get<string>(pkg, "originalPath") ?? (id + ".prefab"),
                    man));
            }

            if (manifests.Count == 0)
            {
                Debug.LogError("[FX] no packages matched the import filter");
                return;
            }

            var slotByTexture = new Dictionary<string, HashSet<string>>(StringComparer.OrdinalIgnoreCase);
            foreach (var (_, dir, _, man) in manifests)
                CollectTextureSlots(dir, man, slotByTexture);

            int totalMesh = 0, totalMat = 0, totalTex = 0, totalNodes = 0;
            var missingShaders = new SortedSet<string>();
            var matByKey = new Dictionary<string, Material>();
            var matByPathId = new Dictionary<long, Material>();
            var meshByKey = new Dictionary<string, Mesh>();
            var globalTex = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);

            try
            {
                foreach (var (_, dir, _, man) in manifests)
                {
                    var texMap = ImportTextures(dir, man, slotByTexture);
                    foreach (var kv in texMap) globalTex[kv.Key] = kv.Value;
                    totalTex += texMap.Count;
                }
                foreach (var (_, dir, _, man) in manifests)
                    totalMat += ImportMaterials(dir, man, globalTex, missingShaders, matByKey, matByPathId);

                foreach (var (id, dir, originalPath, man) in manifests)
                {
                    foreach (var kv in ImportMeshes(dir, man))
                    {
                        meshByKey[kv.Key] = kv.Value;
                        totalMesh++;
                    }
                    try
                    {
                        totalNodes += BuildPackagePrefab(id, originalPath, man, meshByKey, matByKey, matByPathId);
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"[FX] prefab {id}: {e.Message}");
                    }
                }
            }
            finally
            {
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }

            Debug.Log($"[FX] imported meshes={totalMesh} materials={totalMat} textures={totalTex} nodes={totalNodes}");
            if (missingShaders.Count > 0)
                Debug.LogWarning("[FX] shaders missing from the project (fell back to MMN/FX/Amplify shader/FX_Default or SimpleLit): "
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
            EnsureFolder(TexRoot);

            foreach (var srcPath in Directory.GetFiles(texDir, "*.png"))
            {
                string fn = Path.GetFileName(srcPath);
                string stem = Path.GetFileNameWithoutExtension(fn);
                string dst = $"{TexRoot}/{fn}";
                string dstOs = dst.Replace('/', Path.DirectorySeparatorChar);

                if (!File.Exists(dstOs) || new FileInfo(srcPath).LastWriteTimeUtc > new FileInfo(dstOs).LastWriteTimeUtc)
                    File.Copy(srcPath, dstOs, overwrite: true);
                AssetDatabase.ImportAsset(dst);

                slotByTexture.TryGetValue(stem, out var slots);
                bool isNormal = slots != null && slots.Any(NormalSlots.Contains);
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
            EnsureFolder(MatRoot);
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
                shader = Shader.Find("MMN/FX/Amplify shader/FX_Default")
                         ?? Shader.Find("MMN/BG/SimpleLit");
            }
            if (shader == null) return null;

            string path = $"{MatRoot}/{Sanitize(key)}.mat";
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
            EnsureFolder(MeshRoot);
            foreach (var o in Get<List<object>>(man, "meshes") ?? new List<object>())
            {
                var entry = o as Dictionary<string, object>;
                string key = Get<string>(entry, "key");
                string file = Get<string>(entry, "file");
                if (key == null || file == null) continue;
                string src = $"{pkgDir}/meshes/{file}";
                if (!File.Exists(src)) continue;

                string dst = $"{MeshRoot}/{Sanitize(key)}.asset";
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
                    Debug.LogError($"[FX] mesh {file}: {e.Message}");
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

        static int BuildPackagePrefab(string id, string originalPath, Dictionary<string, object> man,
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

                var light = Get<Dictionary<string, object>>(n, "light");
                if (light != null)
                    BuildLight(go, light);

                var particle = Get<Dictionary<string, object>>(n, "particle");
                if (particle != null)
                {
                    BuildParticleSystem(go, particle, meshByKey, matByKey, matByPathId);
                    continue;
                }

                var mats = ResolveMaterials(n, matByKey, matByPathId);
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
                while (mats.Count < mesh.subMeshCount && mats.Count > 0)
                    mats.Add(mats[mats.Count - 1]);
                if (mats.Count > 0) mr.sharedMaterials = mats.ToArray();
                if (mats.Exists(m => m != null && m.shader != null
                    && m.shader.name == "MMN/FX/ObjectDecalForCampFire")
                    && go.GetComponent<MMN_CampFireDecalBinder>() == null)
                    go.AddComponent<MMN_CampFireDecalBinder>();
            }

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
                root = new GameObject(Path.GetFileNameWithoutExtension(originalPath));
                foreach (var r in roots) r.transform.SetParent(root.transform, true);
            }

            string rel = originalPath.Replace("\\", "/");
            if (rel.StartsWith("assets/patchableassets/fx/", StringComparison.OrdinalIgnoreCase))
                rel = rel.Substring("assets/patchableassets/fx/".Length);
            if (!rel.EndsWith(".prefab", StringComparison.OrdinalIgnoreCase))
                rel += ".prefab";
            string prefabPath = $"{OutRoot}/{rel}";
            EnsureFolder(Path.GetDirectoryName(prefabPath).Replace("\\", "/"));
            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
            UnityEngine.Object.DestroyImmediate(root);
            return dicts.Count;
        }

        static void BuildLight(GameObject go, Dictionary<string, object> d)
        {
            var light = go.AddComponent<Light>();
            string type = Get<string>(d, "type") ?? "Point";
            light.type = type.Equals("Spot", StringComparison.OrdinalIgnoreCase) ? LightType.Spot
                : type.Equals("Directional", StringComparison.OrdinalIgnoreCase) ? LightType.Directional
                : LightType.Point;
            var color = ToColor(d.TryGetValue("color", out var c) ? c : null);
            if (color.HasValue) light.color = color.Value;
            light.intensity = ToF(d.TryGetValue("intensity", out var i) ? i : 1f);
            light.range = Mathf.Max(0.01f, ToF(d.TryGetValue("range", out var r) ? r : 10f));
            light.spotAngle = ToF(d.TryGetValue("spotAngle", out var sa) ? sa : 30f);
            light.bounceIntensity = ToF(d.TryGetValue("bounce", out var b) ? b : 1f);
            int shadows = (int)ToF(d.TryGetValue("shadows", out var sh) ? sh : 0f);
            light.shadows = shadows == 2 ? LightShadows.Soft : shadows == 1 ? LightShadows.Hard : LightShadows.None;
        }

        static List<Material> ResolveMaterials(Dictionary<string, object> n,
            Dictionary<string, Material> matByKey, Dictionary<long, Material> matByPathId)
        {
            var mats = new List<Material>();
            foreach (var k in Get<List<object>>(n, "materialKeys") ?? new List<object>())
                if (k is string ks && matByKey.TryGetValue(ks, out var m))
                    mats.Add(m);
            if (mats.Count == 0)
                foreach (var o in Get<List<object>>(n, "materialPathIDs") ?? new List<object>())
                {
                    long pid = ToL(o);
                    if (pid != 0 && matByPathId.TryGetValue(pid, out var m))
                        mats.Add(m);
                }
            if (mats.Count == 0)
                foreach (var k in Get<List<object>>(n, "materialNames") ?? new List<object>())
                    if (k is string ks && matByKey.TryGetValue(ks, out var m))
                        mats.Add(m);
            return mats;
        }

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
            main.scalingMode = ToF(p.TryGetValue("scalingMode", out var sm) ? sm : 1f) < 0.5f
                ? ParticleSystemScalingMode.Hierarchy : ParticleSystemScalingMode.Local;
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

            ApplyAxisModule(ps.velocityOverLifetime, Get<Dictionary<string, object>>(p, "velocityOverLifetime"));
            ApplyAxisModule(ps.forceOverLifetime, Get<Dictionary<string, object>>(p, "forceOverLifetime"));
            ApplyRotation(ps, Get<Dictionary<string, object>>(p, "rotationOverLifetime"));
            ApplyNoise(ps, Get<Dictionary<string, object>>(p, "noise"));
            ApplyTextureSheet(ps, Get<Dictionary<string, object>>(p, "textureSheet"));
            ApplyCustomData(ps, Get<Dictionary<string, object>>(p, "customData"));

            var rendererData = Get<Dictionary<string, object>>(p, "renderer");
            var pr = go.GetComponent<ParticleSystemRenderer>();
            if (rendererData != null && pr != null)
            {
                string mode = Get<string>(rendererData, "renderMode") ?? "Billboard";
                if (Enum.TryParse(mode, true, out ParticleSystemRenderMode parsedMode))
                    pr.renderMode = parsedMode;
                else
                    pr.renderMode = mode.Equals("Mesh", StringComparison.OrdinalIgnoreCase)
                        ? ParticleSystemRenderMode.Mesh
                        : mode.Equals("Stretch", StringComparison.OrdinalIgnoreCase)
                            ? ParticleSystemRenderMode.Stretch
                            : ParticleSystemRenderMode.Billboard;
                pr.lengthScale = ToF(rendererData.TryGetValue("lengthScale", out var ls) ? ls : 2f);
                pr.sortingFudge = ToF(rendererData.TryGetValue("sortingFudge", out var sf) ? sf : 0f);
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
                if (mats.Count > 0) pr.sharedMaterials = mats.ToArray();

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

        static void ApplyAxisModule(ParticleSystem.VelocityOverLifetimeModule vel, Dictionary<string, object> d)
        {
            if (d == null || !ToB(d, "enabled", false)) return;
            vel.enabled = true;
            vel.space = (int)ToF(d.TryGetValue("space", out var sp) ? sp : 0f) == 1
                ? ParticleSystemSimulationSpace.World : ParticleSystemSimulationSpace.Local;
            SameModeAxis(
                MinMax(Get<Dictionary<string, object>>(d, "x"), 0f),
                MinMax(Get<Dictionary<string, object>>(d, "y"), 0f),
                MinMax(Get<Dictionary<string, object>>(d, "z"), 0f),
                out var x, out var y, out var z);
            vel.x = x;
            vel.y = y;
            vel.z = z;
        }

        static void ApplyAxisModule(ParticleSystem.ForceOverLifetimeModule force, Dictionary<string, object> d)
        {
            if (d == null || !ToB(d, "enabled", false)) return;
            force.enabled = true;
            force.space = (int)ToF(d.TryGetValue("space", out var sp) ? sp : 0f) == 1
                ? ParticleSystemSimulationSpace.World : ParticleSystemSimulationSpace.Local;
            SameModeAxis(
                MinMax(Get<Dictionary<string, object>>(d, "x"), 0f),
                MinMax(Get<Dictionary<string, object>>(d, "y"), 0f),
                MinMax(Get<Dictionary<string, object>>(d, "z"), 0f),
                out var x, out var y, out var z);
            force.x = x;
            force.y = y;
            force.z = z;
        }

        static void SameModeAxis(
            ParticleSystem.MinMaxCurve x, ParticleSystem.MinMaxCurve y, ParticleSystem.MinMaxCurve z,
            out ParticleSystem.MinMaxCurve ox, out ParticleSystem.MinMaxCurve oy, out ParticleSystem.MinMaxCurve oz)
        {
            var mode = x.mode;
            if (ModeRank(y.mode) > ModeRank(mode)) mode = y.mode;
            if (ModeRank(z.mode) > ModeRank(mode)) mode = z.mode;
            ox = ForceMode(x, mode);
            oy = ForceMode(y, mode);
            oz = ForceMode(z, mode);
        }

        static int ModeRank(ParticleSystemCurveMode mode)
        {
            switch (mode)
            {
                case ParticleSystemCurveMode.TwoCurves: return 3;
                case ParticleSystemCurveMode.Curve: return 2;
                case ParticleSystemCurveMode.TwoConstants: return 1;
                default: return 0;
            }
        }

        static ParticleSystem.MinMaxCurve ForceMode(ParticleSystem.MinMaxCurve src, ParticleSystemCurveMode mode)
        {
            if (src.mode == mode) return src;
            float a = src.constantMin;
            float b = src.constantMax;
            if (src.mode == ParticleSystemCurveMode.Constant || src.mode == ParticleSystemCurveMode.TwoConstants)
            {
                a = src.mode == ParticleSystemCurveMode.Constant ? src.constant : src.constantMin;
                b = src.mode == ParticleSystemCurveMode.Constant ? src.constant : src.constantMax;
            }
            else
            {
                a = src.Evaluate(0f);
                b = src.Evaluate(1f);
            }

            if (mode == ParticleSystemCurveMode.TwoCurves)
                return new ParticleSystem.MinMaxCurve(1f, AnimationCurve.Constant(0f, 1f, a), AnimationCurve.Constant(0f, 1f, b));
            if (mode == ParticleSystemCurveMode.Curve)
                return new ParticleSystem.MinMaxCurve(b, AnimationCurve.Constant(0f, 1f, b));
            if (mode == ParticleSystemCurveMode.TwoConstants)
                return new ParticleSystem.MinMaxCurve(a, b);
            return new ParticleSystem.MinMaxCurve(b);
        }

        static void ApplyRotation(ParticleSystem ps, Dictionary<string, object> d)
        {
            if (d == null || !ToB(d, "enabled", false)) return;
            var rot = ps.rotationOverLifetime;
            rot.enabled = true;
            rot.separateAxes = ToB(d, "separateAxes", false);
            rot.x = Radians(Get<Dictionary<string, object>>(d, "x"));
            rot.y = Radians(Get<Dictionary<string, object>>(d, "y"));
            rot.z = Radians(Get<Dictionary<string, object>>(d, "z"));
        }

        static void ApplyNoise(ParticleSystem ps, Dictionary<string, object> d)
        {
            if (d == null || !ToB(d, "enabled", false)) return;
            var noise = ps.noise;
            noise.enabled = true;
            noise.strength = MinMax(Get<Dictionary<string, object>>(d, "strength"), 1f);
            noise.frequency = ToF(d.TryGetValue("frequency", out var fq) ? fq : 0.5f);
            noise.scrollSpeed = MinMax(Get<Dictionary<string, object>>(d, "scrollSpeed"), 0f);
            noise.damping = ToB(d, "damping", false);
            noise.octaveCount = Mathf.Clamp((int)ToF(d.TryGetValue("octaveCount", out var oc) ? oc : 1f), 1, 4);
            noise.quality = (ParticleSystemNoiseQuality)Mathf.Clamp(
                (int)ToF(d.TryGetValue("quality", out var q) ? q : 1f), 0, 2);
            noise.separateAxes = ToB(d, "separateAxes", false);
        }

        static void ApplyTextureSheet(ParticleSystem ps, Dictionary<string, object> d)
        {
            if (d == null || !ToB(d, "enabled", false)) return;
            var uv = ps.textureSheetAnimation;
            uv.enabled = true;
            uv.numTilesX = Mathf.Max(1, (int)ToF(d.TryGetValue("tilesX", out var tx) ? tx : 1f));
            uv.numTilesY = Mathf.Max(1, (int)ToF(d.TryGetValue("tilesY", out var ty) ? ty : 1f));
            uv.animation = (int)ToF(d.TryGetValue("animationType", out var at) ? at : 0f) == 1
                ? ParticleSystemAnimationType.SingleRow : ParticleSystemAnimationType.WholeSheet;
            uv.rowIndex = Mathf.Max(0, (int)ToF(d.TryGetValue("rowIndex", out var ri) ? ri : 0f));
            uv.cycleCount = Mathf.Max(1, (int)ToF(d.TryGetValue("cycles", out var cy) ? cy : 1f));
            uv.frameOverTime = MinMax(Get<Dictionary<string, object>>(d, "frameOverTime"), 0f);
            uv.startFrame = MinMax(Get<Dictionary<string, object>>(d, "startFrame"), 0f);
        }

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
            int mode = (int)ToF(d.TryGetValue("mode", out var mo) ? mo : 0f);
            var keys = Get<List<object>>(d, "keys");
            if ((mode == 1 || mode == 2) && keys != null && keys.Count > 1)
            {
                var keysMin = Get<List<object>>(d, "keysMin");
                return mode == 2 && keysMin != null && keysMin.Count > 1
                    ? new ParticleSystem.MinMaxCurve(max, KeysToCurve(keysMin), KeysToCurve(keys))
                    : new ParticleSystem.MinMaxCurve(max, KeysToCurve(keys));
            }
            if (mode == 3)
                return new ParticleSystem.MinMaxCurve(min, max);
            return new ParticleSystem.MinMaxCurve(max);
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
                alphaKeys.Add(new GradientAlphaKey(1f, 0f));
                alphaKeys.Add(new GradientAlphaKey(1f, 1f));
            }
            grad.SetKeys(colorKeys.ToArray(), alphaKeys.ToArray());
            return grad;
        }

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

        static ParticleSystem.MinMaxCurve Radians(Dictionary<string, object> d)
        {
            return MinMax(d, 0f);
        }

        static void EnsureFolder(string path)
        {
            if (string.IsNullOrEmpty(path) || AssetDatabase.IsValidFolder(path)) return;
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
