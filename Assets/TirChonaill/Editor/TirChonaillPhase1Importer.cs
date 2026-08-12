#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace TirChonaill.Editor
{
    public static class TirChonaillPhase1Importer
    {
        const string PackRoot = "Assets/TirChonaill/_import_pack";
        const string OutRoot = "Assets/TirChonaill";
        const uint MeshMagic = 0x48534D4D; // 'MMSH' little-endian as uint read LE -> actually check bytes

        /// <summary>
        /// Re-import materials/textures recovered by resolve_materials_from_blobs.py and
        /// rebind existing Prefabs without rebuilding the overview scene.
        /// </summary>
        [MenuItem("TirChonaill/Patch Resolved Materials")]
        public static void PatchResolvedMaterials()
        {
            try
            {
                UnresolvedSlots = 0;
                var texIndex = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                var catalogPath = PackRoot + "/catalog.json";
                if (File.Exists(catalogPath))
                {
                    var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
                    if (catalog != null && catalog.TryGetValue("textureIndex", out var tiObj) && tiObj is Dictionary<string, object> ti)
                        foreach (var kv in ti) texIndex[kv.Key] = Convert.ToString(kv.Value);
                }

                // Force-copy so newly recovered PNGs replace any empty/stale shared files.
                string srcTex = PackRoot + "/_resolved/textures";
                string dstTex = OutRoot + "/Shared/Textures";
                EnsureFolder(OutRoot + "/Shared");
                EnsureFolder(dstTex);
                int copied = 0;
                if (Directory.Exists(srcTex))
                {
                    foreach (var file in Directory.GetFiles(srcTex, "*.png"))
                    {
                        File.Copy(file, dstTex + "/" + Path.GetFileName(file), true);
                        copied++;
                    }
                }
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);
                ConfigureTextures();

                var sharedTexMap = ImportSharedResolvedTextures();
                var sharedMatMap = CreateSharedResolvedMaterials(sharedTexMap, texIndex);

                int prefabsPatched = 0, slotsPatched = 0, sceneFixed = 0;
                foreach (var pj in Directory.GetFiles(PackRoot, "package.json", SearchOption.AllDirectories))
                {
                    var pkg = MiniJson.Deserialize(File.ReadAllText(pj, Encoding.UTF8)) as Dictionary<string, object>;
                    if (pkg == null || !pkg.ContainsKey("bindings")) continue;
                    var bindings = pkg["bindings"] as List<object>;
                    if (bindings == null) continue;

                    string packPkg = Path.GetDirectoryName(pj).Replace("\\", "/");
                    int aIdx = packPkg.IndexOf("Assets/");
                    if (aIdx >= 0) packPkg = packPkg.Substring(aIdx);
                    string outPkg = packPkg.Replace("/_import_pack", "");
                    string prefabDir = outPkg + "/Prefabs";
                    if (!AssetDatabase.IsValidFolder(prefabDir)) continue;

                    // Merge package-local materials so already-resolved slots still resolve.
                    var matMap = new Dictionary<string, Material>(sharedMatMap, StringComparer.OrdinalIgnoreCase);
                    string localMatDir = outPkg + "/Materials";
                    if (AssetDatabase.IsValidFolder(localMatDir))
                    {
                        foreach (var g in AssetDatabase.FindAssets("t:Material", new[] { localMatDir }))
                        {
                            var p = AssetDatabase.GUIDToAssetPath(g);
                            var m = AssetDatabase.LoadAssetAtPath<Material>(p);
                            if (m == null) continue;
                            matMap[Path.GetFileNameWithoutExtension(p)] = m;
                            if (!matMap.ContainsKey(m.name)) matMap[m.name] = m;
                        }
                    }

                    foreach (var bObj in bindings)
                    {
                        var b = bObj as Dictionary<string, object>;
                        if (b == null) continue;
                        string meshName = b.ContainsKey("meshName") ? Convert.ToString(b["meshName"]) : null;
                        if (string.IsNullOrEmpty(meshName) && b.ContainsKey("name"))
                            meshName = Convert.ToString(b["name"]);
                        if (string.IsNullOrEmpty(meshName)) continue;
                        var matKeys = b.ContainsKey("materialKeys") ? b["materialKeys"] as List<object> : null;
                        var matNames = b.ContainsKey("materialNames") ? b["materialNames"] as List<object> : null;
                        if (matKeys == null) continue;

                        string goName = SanitizeFileName(meshName);
                        string prefabPath = null;
                        foreach (var g in AssetDatabase.FindAssets(goName + " t:Prefab", new[] { prefabDir }))
                        {
                            var p = AssetDatabase.GUIDToAssetPath(g);
                            var fn = Path.GetFileNameWithoutExtension(p);
                            if (fn == goName || fn.StartsWith(goName + " ", StringComparison.Ordinal))
                            {
                                prefabPath = p;
                                break;
                            }
                        }
                        if (prefabPath == null) continue;

                        var root = PrefabUtility.LoadPrefabContents(prefabPath);
                        try
                        {
                            var mr = root.GetComponent<MeshRenderer>() ?? root.GetComponentInChildren<MeshRenderer>();
                            var mf = root.GetComponent<MeshFilter>() ?? root.GetComponentInChildren<MeshFilter>();
                            if (mr == null || mf == null || mf.sharedMesh == null) continue;
                            var mats = ResolveMaterials(mf.sharedMesh, matKeys, matNames, matMap);
                            bool dirty = false;
                            var cur = mr.sharedMaterials;
                            if (cur.Length != mats.Length) dirty = true;
                            else
                            {
                                for (int i = 0; i < mats.Length; i++)
                                    if (cur[i] != mats[i]) { dirty = true; break; }
                            }
                            if (!dirty) continue;
                            mr.sharedMaterials = mats;
                            PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
                            prefabsPatched++;
                            slotsPatched += mats.Length;
                        }
                        finally
                        {
                            PrefabUtility.UnloadPrefabContents(root);
                        }
                    }
                }

                // Pull updated materials into live scene instances.
                foreach (var mr in UnityEngine.Object.FindObjectsByType<MeshRenderer>(FindObjectsInactive.Include, FindObjectsSortMode.None))
                {
                    if (!mr.gameObject.scene.IsValid()) continue;
                    var src = PrefabUtility.GetCorrespondingObjectFromSource(mr);
                    if (src == null) continue;
                    bool needs = false;
                    foreach (var m in mr.sharedMaterials)
                        if (m == null || m.name.StartsWith("_Unresolved")) { needs = true; break; }
                    if (!needs)
                    {
                        // Also refresh if prefab materials differ.
                        var srcMats = src.sharedMaterials;
                        var cur = mr.sharedMaterials;
                        if (srcMats.Length != cur.Length) needs = true;
                        else for (int i = 0; i < cur.Length; i++) if (cur[i] != srcMats[i]) { needs = true; break; }
                    }
                    if (!needs) continue;
                    mr.sharedMaterials = src.sharedMaterials;
                    sceneFixed++;
                }

                EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
                EditorSceneManager.SaveOpenScenes();
                AssetDatabase.SaveAssets();
                Debug.Log($"[TirChonaill] Patch Resolved Materials: texturesCopied={copied}, " +
                          $"sharedMats={sharedMatMap.Count}, prefabsPatched={prefabsPatched}, " +
                          $"slots={slotsPatched}, sceneFixed={sceneFixed}, unresolvedSlots={UnresolvedSlots}");
            }
            catch (Exception ex)
            {
                Debug.LogError("[TirChonaill] PatchResolvedMaterials failed: " + ex);
            }
            finally
            {
                EditorUtility.ClearProgressBar();
            }
        }

        [MenuItem("TirChonaill/Force Rebind Foreign Meshes")]
        public static void ForceRebindForeignMeshes()
        {
            RepairPrefabMaterials(PackRoot + "/_resolved/rebind_manifest.json", foreignOnly: true);
        }

        /// <summary>
        /// Rebuild every Prefab whose material slots went Missing after Shared materials
        /// were recreated (GUID break). Uses package.json keys from the full manifest.
        /// </summary>
        [MenuItem("TirChonaill/Repair All Prefab Materials")]
        public static void RepairAllPrefabMaterials()
        {
            string full = PackRoot + "/_resolved/rebind_all_manifest.json";
            if (!File.Exists(full))
                full = PackRoot + "/_resolved/rebind_manifest.json";
            RepairPrefabMaterials(full, foreignOnly: false);
        }

        static void RepairPrefabMaterials(string manifestPath, bool foreignOnly)
        {
            if (!File.Exists(manifestPath))
            {
                Debug.LogError("[TirChonaill] Missing " + manifestPath);
                return;
            }
            var list = MiniJson.Deserialize(File.ReadAllText(manifestPath, Encoding.UTF8)) as List<object>;
            if (list == null) { Debug.LogError("[TirChonaill] rebind manifest parse failed"); return; }

            var matByKey = new Dictionary<string, Material>(StringComparer.OrdinalIgnoreCase);
            foreach (var g in AssetDatabase.FindAssets("t:Material", new[] { OutRoot }))
            {
                string p = AssetDatabase.GUIDToAssetPath(g);
                if (p.Contains("/_import_pack/")) continue;
                var m = AssetDatabase.LoadAssetAtPath<Material>(p);
                if (m == null) continue;
                matByKey[Path.GetFileNameWithoutExtension(p)] = m;
                if (!matByKey.ContainsKey(m.name)) matByKey[m.name] = m;
            }

            int prefabs = 0, slots = 0, missing = 0, skippedOk = 0, scene = 0;
            var rebuiltPaths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var itemObj in list)
            {
                var item = itemObj as Dictionary<string, object>;
                if (item == null) continue;
                string meshName = Convert.ToString(item["meshName"]);
                if (foreignOnly &&
                    !(meshName.Contains("Dungeon_") || meshName.Contains("Fiodh_") || meshName.Contains("VP1@")))
                    continue;

                var keys = item.ContainsKey("materialKeys") ? item["materialKeys"] as List<object> : null;
                if (keys == null) continue;
                string goName = SanitizeFileName(meshName);
                string pkg = item.ContainsKey("package") ? Convert.ToString(item["package"]).Replace("\\", "/") : null;
                // Prefer the Prefab under the package that owns this binding when duplicates exist
                // (school meshes were also curated into Vegetation packages).
                string preferredDir = null;
                if (!string.IsNullOrEmpty(pkg))
                    preferredDir = (OutRoot + "/" + pkg + "/Prefabs").Replace("\\", "/");

                var candidates = new List<string>();
                foreach (var g in AssetDatabase.FindAssets(goName + " t:Prefab", new[] { OutRoot }))
                {
                    string p = AssetDatabase.GUIDToAssetPath(g);
                    string fn = Path.GetFileNameWithoutExtension(p);
                    if (fn == goName || fn.StartsWith(goName + " ", StringComparison.Ordinal))
                        candidates.Add(p);
                }
                if (candidates.Count == 0) { missing++; continue; }

                // Sort preferred package first, then Buildings over Vegetation.
                candidates.Sort((a, b) =>
                {
                    int sa = ScorePrefabPath(a, preferredDir);
                    int sb = ScorePrefabPath(b, preferredDir);
                    return sa.CompareTo(sb);
                });

                var mats = ResolveMatsFromKeys(keys, matByKey, ref slots);

                foreach (var prefabPath in candidates)
                {
                    if (!rebuiltPaths.Add(prefabPath)) continue;
                    var existing = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
                    if (existing == null) continue;
                    var srcMf = existing.GetComponent<MeshFilter>() ?? existing.GetComponentInChildren<MeshFilter>();
                    var srcMr = existing.GetComponent<MeshRenderer>() ?? existing.GetComponentInChildren<MeshRenderer>();
                    if (srcMf == null || srcMf.sharedMesh == null) continue;

                    bool needs = srcMr == null;
                    if (!needs)
                        foreach (var m in srcMr.sharedMaterials)
                            if (m == null) { needs = true; break; }
                    // Always rebuild preferred-package / previously-null prefabs; skip healthy ones
                    // unless they are the only candidate for a broken scene instance later.
                    if (!needs && preferredDir != null &&
                        !prefabPath.Replace("\\", "/").StartsWith(preferredDir, StringComparison.OrdinalIgnoreCase))
                    {
                        skippedOk++;
                        continue;
                    }
                    if (!needs) { skippedOk++; continue; }

                    bool rendererWasEnabled = srcMr == null || srcMr.enabled;
                    var go = new GameObject(Path.GetFileNameWithoutExtension(prefabPath));
                    go.AddComponent<MeshFilter>().sharedMesh = srcMf.sharedMesh;
                    var mr = go.AddComponent<MeshRenderer>();
                    mr.sharedMaterials = mats;
                    mr.enabled = rendererWasEnabled;
                    AssetDatabase.DeleteAsset(prefabPath);
                    PrefabUtility.SaveAsPrefabAsset(go, prefabPath);
                    UnityEngine.Object.DestroyImmediate(go);
                    prefabs++;
                }
            }

            // Replace any scene instance that still has null materials.
            var toReplace = new List<(Transform t, string prefabPath)>();
            foreach (var mr in UnityEngine.Object.FindObjectsByType<MeshRenderer>(FindObjectsInactive.Include, FindObjectsSortMode.None))
            {
                if (!mr.gameObject.scene.IsValid()) continue;
                bool hasNull = false;
                foreach (var m in mr.sharedMaterials) if (m == null) { hasNull = true; break; }
                if (!hasNull) continue;

                string n = mr.gameObject.name;
                string goName = SanitizeFileName(n);
                string prefabPath = null;
                int best = int.MaxValue;
                foreach (var g in AssetDatabase.FindAssets(goName + " t:Prefab", new[] { OutRoot }))
                {
                    string p = AssetDatabase.GUIDToAssetPath(g);
                    string fn = Path.GetFileNameWithoutExtension(p);
                    if (!(fn == goName || fn.StartsWith(goName + " ", StringComparison.Ordinal))) continue;
                    // Prefer a Prefab that actually has materials.
                    var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(p);
                    var pmr = prefab != null ? (prefab.GetComponent<MeshRenderer>() ?? prefab.GetComponentInChildren<MeshRenderer>()) : null;
                    bool ok = pmr != null;
                    if (ok) foreach (var m in pmr.sharedMaterials) if (m == null) { ok = false; break; }
                    int score = ScorePrefabPath(p, null) + (ok ? 0 : 1000);
                    if (score < best) { best = score; prefabPath = p; }
                }
                if (prefabPath != null) toReplace.Add((mr.transform, prefabPath));
            }
            foreach (var (t, prefabPath) in toReplace)
            {
                var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
                if (prefab == null) continue;
                var parent = t.parent;
                var pos = t.localPosition;
                var rot = t.localRotation;
                var scale = t.localScale;
                var name = t.gameObject.name;
                bool active = t.gameObject.activeSelf;
                UnityEngine.Object.DestroyImmediate(t.gameObject);
                var inst = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                inst.name = name;
                inst.transform.SetParent(parent, false);
                inst.transform.localPosition = pos;
                inst.transform.localRotation = rot;
                inst.transform.localScale = scale;
                inst.SetActive(active);
                scene++;
            }

            EditorSceneManager.MarkSceneDirty(EditorSceneManager.GetActiveScene());
            EditorSceneManager.SaveOpenScenes();
            AssetDatabase.SaveAssets();
            Debug.Log($"[TirChonaill] Repair Prefab Materials: rebuilt={prefabs} slots={slots} " +
                      $"skippedOk={skippedOk} missing={missing} sceneReplaced={scene}");
        }

        static int ScorePrefabPath(string path, string preferredDir)
        {
            string p = path.Replace("\\", "/");
            if (!string.IsNullOrEmpty(preferredDir) &&
                p.StartsWith(preferredDir, StringComparison.OrdinalIgnoreCase)) return 0;
            if (p.Contains("/Buildings/")) return 1;
            if (p.Contains("/Vegetation/")) return 3;
            return 2;
        }

        static Material[] ResolveMatsFromKeys(List<object> keys, Dictionary<string, Material> matByKey, ref int slots)
        {
            var mats = new Material[keys.Count];
            for (int i = 0; i < keys.Count; i++)
            {
                string k = Convert.ToString(keys[i]);
                Material m = null;
                if (!string.IsNullOrEmpty(k))
                {
                    matByKey.TryGetValue(k, out m);
                    if (m == null)
                    {
                        int u = k.LastIndexOf("__", StringComparison.Ordinal);
                        if (u > 0) matByKey.TryGetValue(k.Substring(0, u), out m);
                    }
                }
                mats[i] = m ?? GetUnresolvedPlaceholder();
                if (m != null) slots++;
            }
            return mats;
        }

        [MenuItem("TirChonaill/Phase1 Import All")]
        public static void ImportAll()
        {
            try
            {
                if (!Directory.Exists(PackRoot))
                {
                    Debug.LogError("[TirChonaill] Missing import pack: " + PackRoot);
                    return;
                }

                UnresolvedSlots = 0;
                EnsureFolders();
                AssetDatabase.StartAssetEditing();
                try
                {
                    // Let Unity see textures/shaders already on disk
                }
                finally
                {
                    AssetDatabase.StopAssetEditing();
                }
                AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

                var catalogPath = PackRoot + "/catalog.json";
                var catalog = MiniJson.Deserialize(File.ReadAllText(catalogPath, Encoding.UTF8)) as Dictionary<string, object>;
                if (catalog == null) throw new Exception("catalog.json parse failed");

                var texIndex = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                if (catalog.TryGetValue("textureIndex", out var tiObj) && tiObj is Dictionary<string, object> ti)
                {
                    foreach (var kv in ti)
                        texIndex[kv.Key] = Convert.ToString(kv.Value);
                }

                // Materials whose PPtr pointed outside the package's own bundles were
                // recovered by resolve_missing_materials.py into a shared pool.
                var sharedTexMap = ImportSharedResolvedTextures();

                // Configure texture importers for cutout leaves etc.
                ConfigureTextures();

                var sharedMatMap = CreateSharedResolvedMaterials(sharedTexMap, texIndex);

                var packages = catalog["packages"] as List<object>;
                int meshCount = 0, matCount = 0, prefabCount = 0, proxyCount = 0;
                var allPrefabPaths = new List<(string category, string packageId, string path, Bounds bounds)>();

                int pkgIndex = 0;
                foreach (var pkgObj in packages)
                {
                    pkgIndex++;
                    var pkg = pkgObj as Dictionary<string, object>;
                    string category = Convert.ToString(pkg["category"]);
                    string id = Convert.ToString(pkg["id"]);
                    EditorUtility.DisplayProgressBar("TirChonaill Import", $"{category}/{id}", (float)pkgIndex / packages.Count);

                    string packPkg = $"{PackRoot}/{category}/{id}";
                    string outPkg = $"{OutRoot}/{category}/{id}";
                    EnsureFolder(outPkg);
                    EnsureFolder(outPkg + "/Meshes");
                    EnsureFolder(outPkg + "/Materials");
                    EnsureFolder(outPkg + "/Textures");
                    EnsureFolder(outPkg + "/Prefabs");

                    // Copy textures into package Textures folder (or reference pack textures)
                    var texMap = ImportPackageTextures(packPkg, outPkg);
                    foreach (var kv in sharedTexMap)
                        if (!texMap.ContainsKey(kv.Key)) texMap[kv.Key] = kv.Value;

                    // Materials
                    var matMap = new Dictionary<string, Material>(StringComparer.OrdinalIgnoreCase);
                    string matDir = packPkg + "/materials";
                    if (Directory.Exists(matDir))
                    {
                        foreach (var matFile in Directory.GetFiles(matDir, "*.json"))
                        {
                            var mat = CreateMaterialFromJson(matFile, outPkg, texMap, texIndex);
                            if (mat == null) continue;
                            string key = Path.GetFileNameWithoutExtension(matFile);
                            matMap[key] = mat;
                            matMap[mat.name] = mat;
                            matCount++;
                        }
                    }

                    // Package-local materials win; the shared pool only fills the gaps.
                    foreach (var kv in sharedMatMap)
                        if (!matMap.ContainsKey(kv.Key)) matMap[kv.Key] = kv.Value;

                    // Meshes
                    var meshMap = new Dictionary<string, Mesh>(StringComparer.OrdinalIgnoreCase);
                    string meshDir = packPkg + "/meshes";
                    if (Directory.Exists(meshDir))
                    {
                        foreach (var meshFile in Directory.GetFiles(meshDir, "*.mmesh"))
                        {
                            var mesh = ImportMMesh(meshFile, outPkg + "/Meshes");
                            if (mesh == null) continue;
                            string key = Path.GetFileNameWithoutExtension(meshFile);
                            meshMap[key] = mesh;
                            meshMap[mesh.name] = mesh;
                            meshCount++;
                        }
                    }

                    // Bindings -> prefabs (3B: one prefab per mesh binding)
                    var packageJson = MiniJson.Deserialize(File.ReadAllText(packPkg + "/package.json", Encoding.UTF8)) as Dictionary<string, object>;
                    var bindings = packageJson["bindings"] as List<object>;
                    var usedMeshKeys = new HashSet<string>();

                    foreach (var bObj in bindings)
                    {
                        var b = bObj as Dictionary<string, object>;
                        string meshKey = b.ContainsKey("meshKey") ? Convert.ToString(b["meshKey"]) : null;
                        string meshName = b.ContainsKey("meshName") ? Convert.ToString(b["meshName"]) : null;
                        if (string.IsNullOrEmpty(meshKey) && string.IsNullOrEmpty(meshName)) continue;

                        Mesh mesh = null;
                        if (!string.IsNullOrEmpty(meshKey) && meshMap.TryGetValue(meshKey, out mesh)) { }
                        else if (!string.IsNullOrEmpty(meshName) && meshMap.TryGetValue(meshName, out mesh)) { }
                        if (mesh == null) continue;

                        // Patch/variant bundles ship the same mesh under a second pathID, so
                        // key on identity rather than pathID to avoid twin prefabs.
                        string dedupe = $"{meshName ?? mesh.name}|{mesh.vertexCount}|{mesh.subMeshCount}";
                        if (!usedMeshKeys.Add(dedupe)) continue; // one prefab per unique mesh

                        var matKeys = b.ContainsKey("materialKeys") ? b["materialKeys"] as List<object> : null;
                        var matNames = b.ContainsKey("materialNames") ? b["materialNames"] as List<object> : null;
                        // The original GameObject carried a MeshFilter but no renderer at
                        // all: a height/collision proxy that was never drawn.
                        bool noMaterials = b.ContainsKey("noMaterials") && b["noMaterials"] is bool nm && nm;
                        // Use the source name: duplicated mesh assets get a " 1" suffix.
                        bool isProxy = noMaterials || IsHeightProxy(!string.IsNullOrEmpty(meshName) ? meshName : mesh.name);
                        var mats = isProxy ? new Material[0] : ResolveMaterials(mesh, matKeys, matNames, matMap);

                        string goName = SanitizeFileName(!string.IsNullOrEmpty(meshName) ? meshName : mesh.name);
                        var go = new GameObject(goName);
                        var mf = go.AddComponent<MeshFilter>();
                        mf.sharedMesh = mesh;
                        var mr = go.AddComponent<MeshRenderer>();
                        mr.sharedMaterials = mats;
                        if (isProxy)
                        {
                            mr.enabled = false;
                            proxyCount++;
                        }

                        string prefabPath = $"{outPkg}/Prefabs/{goName}.prefab";
                        prefabPath = AssetDatabase.GenerateUniqueAssetPath(prefabPath);
                        var prefab = PrefabUtility.SaveAsPrefabAsset(go, prefabPath);
                        UnityEngine.Object.DestroyImmediate(go);
                        prefabCount++;

                        if (prefab != null)
                        {
                            var bounds = mesh.bounds;
                            allPrefabPaths.Add((category, id, prefabPath, bounds));
                        }
                    }
                }

                EditorUtility.DisplayProgressBar("TirChonaill Import", "Building overview scene...", 0.98f);
                BuildOverviewScene(allPrefabPaths);
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();

                EditorUtility.ClearProgressBar();
                // A modal dialog here would block the editor when the import is driven
                // from automation rather than the menu.
                Debug.Log($"[TirChonaill] Phase1 import done. Meshes: {meshCount}, Materials: {matCount}, Prefabs: {prefabCount}, " +
                          $"unresolved submesh slots: {UnresolvedSlots}, disabled proxies: {proxyCount}. " +
                          "Scene: Assets/TirChonaill/Scenes/TirChonaill_Preview.unity");
            }
            catch (Exception ex)
            {
                EditorUtility.ClearProgressBar();
                Debug.LogError("[TirChonaill] Phase1 import failed: " + ex.Message);
                Debug.LogException(ex);
            }
        }

        // Every building ships a "_Height" companion mesh for MMN's height-query
        // system. It keeps the building's atlas material, but its UVs are placeholder
        // full-atlas quads (a couple of dozen unique UVs spanning 0..1) rather than
        // atlas sub-rects, so drawing it smears the whole atlas over an oversized flat
        // plane that sticks out around the building.
        static bool IsHeightProxy(string sourceMeshName)
        {
            return !string.IsNullOrEmpty(sourceMeshName) && sourceMeshName.EndsWith("_Height");
        }

        static Material[] ResolveMaterials(Mesh mesh, List<object> matKeys, List<object> matNames, Dictionary<string, Material> matMap)
        {
            int subCount = Mathf.Max(1, mesh.subMeshCount);
            var mats = new Material[subCount];
            // Never fall back to an arbitrary material from the package: a flower atlas
            // landing on tree-leaf cards renders as opaque colour blocks.
            Material fallback = PickFallbackByMeshName(mesh.name, matMap);

            for (int i = 0; i < subCount; i++)
            {
                Material found = null;
                if (matKeys != null && i < matKeys.Count)
                {
                    var k = Convert.ToString(matKeys[i]);
                    matMap.TryGetValue(k, out found);
                }
                if (found == null && matNames != null && i < matNames.Count)
                {
                    var n = Convert.ToString(matNames[i]);
                    matMap.TryGetValue(n, out found);
                    if (found == null)
                    {
                        foreach (var kv in matMap)
                        {
                            if (kv.Value != null && kv.Value.name == n) { found = kv.Value; break; }
                        }
                    }
                }
                // Deliberately no "clamp to the last key" fallback here. materialKeys is
                // index-aligned with the submeshes, and reusing the last entry for an
                // unresolved slot turns a visible gap into a plausible-looking wrong
                // assignment (an interior notice-board atlas stretched over a roof).
                if (found == null) UnresolvedSlots++;
                mats[i] = found != null ? found : fallback;
            }
            return mats;
        }

        static int UnresolvedSlots;

        // Foliage must not inherit an opaque material, so unresolved slots pick the
        // closest cutout material by mesh name and only then a neutral placeholder.
        static Material PickFallbackByMeshName(string meshName, Dictionary<string, Material> matMap)
        {
            string n = (meshName ?? string.Empty).ToLowerInvariant();
            string[] wanted = null;
            if (n.Contains("leaves") || n.Contains("leaf") || n.Contains("bush") ||
                n.Contains("vine") || n.Contains("plants") || n.Contains("ivy"))
                wanted = new[] { "MMN/BG/TreeLeaves" };
            else if (n.Contains("grass") || n.Contains("flower"))
                wanted = new[] { "MMN/BG/Grass", "MMN/BG/TreeLeaves" };

            if (wanted != null)
            {
                foreach (var shaderName in wanted)
                {
                    foreach (var m in matMap.Values)
                    {
                        if (m == null || m.shader == null) continue;
                        if (m.shader.name != shaderName) continue;
                        if (m.HasProperty("_BaseMap") && m.GetTexture("_BaseMap") != null)
                            return m;
                    }
                }
            }
            return GetUnresolvedPlaceholder();
        }

        static Material _unresolvedPlaceholder;

        static Material GetUnresolvedPlaceholder()
        {
            if (_unresolvedPlaceholder != null) return _unresolvedPlaceholder;

            string path = OutRoot + "/Materials/_Unresolved.mat";
            _unresolvedPlaceholder = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (_unresolvedPlaceholder != null) return _unresolvedPlaceholder;

            EnsureFolder(OutRoot + "/Materials");
            var sh = Shader.Find("MMN/BG/SimpleLit") ?? Shader.Find("Universal Render Pipeline/Lit");
            var mat = new Material(sh) { name = "_Unresolved" };
            if (mat.HasProperty("_BaseColor")) mat.SetColor("_BaseColor", new Color(0.7f, 0.7f, 0.7f, 1f));
            AssetDatabase.CreateAsset(mat, path);
            _unresolvedPlaceholder = AssetDatabase.LoadAssetAtPath<Material>(path);
            return _unresolvedPlaceholder;
        }

        static Dictionary<string, Texture2D> ImportSharedResolvedTextures()
        {
            var map = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);
            string src = PackRoot + "/_resolved/textures";
            if (!Directory.Exists(src)) return map;

            string dst = OutRoot + "/Shared/Textures";
            EnsureFolder(OutRoot + "/Shared");
            EnsureFolder(dst);

            foreach (var file in Directory.GetFiles(src, "*.png"))
            {
                string destAsset = dst + "/" + Path.GetFileName(file);
                if (!File.Exists(destAsset)) File.Copy(file, destAsset, true);
            }
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

            foreach (var file in Directory.GetFiles(dst, "*.png"))
            {
                string assetPath = file.Replace("\\", "/");
                int idx = assetPath.IndexOf("Assets/");
                if (idx > 0) assetPath = assetPath.Substring(idx);
                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
                if (tex == null) continue;
                map[tex.name] = tex;
                map[Path.GetFileNameWithoutExtension(file)] = tex;
            }
            return map;
        }

        static Dictionary<string, Material> CreateSharedResolvedMaterials(
            Dictionary<string, Texture2D> texMap, Dictionary<string, string> texIndex)
        {
            var map = new Dictionary<string, Material>(StringComparer.OrdinalIgnoreCase);
            string src = PackRoot + "/_resolved/materials";
            if (!Directory.Exists(src)) return map;

            string outDir = OutRoot + "/Shared";
            EnsureFolder(outDir);
            EnsureFolder(outDir + "/Materials");

            foreach (var matFile in Directory.GetFiles(src, "*.json"))
            {
                string key = Path.GetFileNameWithoutExtension(matFile);
                string keyPath = $"{outDir}/Materials/{SanitizeFileName(key)}.mat";
                // Prefer updating the existing asset in place so Prefab material slots keep
                // their GUID. Deleting + recreating leaves Missing references everywhere.
                var existing = AssetDatabase.LoadAssetAtPath<Material>(keyPath);
                if (existing != null)
                {
                    ApplyMaterialJsonOnto(existing, matFile, texMap, texIndex);
                    EditorUtility.SetDirty(existing);
                    map[key] = existing;
                    if (!map.ContainsKey(existing.name)) map[existing.name] = existing;
                    continue;
                }

                var mat = CreateMaterialFromJson(matFile, outDir, texMap, texIndex);
                if (mat == null) continue;
                string written = AssetDatabase.GetAssetPath(mat);
                if (!string.IsNullOrEmpty(written) && written != keyPath)
                {
                    string err = AssetDatabase.MoveAsset(written, keyPath);
                    if (string.IsNullOrEmpty(err))
                        mat = AssetDatabase.LoadAssetAtPath<Material>(keyPath);
                }
                map[key] = mat;
                if (!map.ContainsKey(mat.name)) map[mat.name] = mat;
            }
            return map;
        }

        /// <summary>Copy JSON properties onto an existing Material without changing its GUID.</summary>
        static void ApplyMaterialJsonOnto(Material mat, string jsonPath,
            Dictionary<string, Texture2D> texMap, Dictionary<string, string> texIndex)
        {
            var data = MiniJson.Deserialize(File.ReadAllText(jsonPath, Encoding.UTF8)) as Dictionary<string, object>;
            if (data == null) return;
            string shaderName = data.ContainsKey("shader") ? Convert.ToString(data["shader"]) : null;
            if (string.IsNullOrEmpty(shaderName) || shaderName == "null")
                shaderName = data.ContainsKey("shaderInferred") ? Convert.ToString(data["shaderInferred"]) : null;
            if (string.IsNullOrEmpty(shaderName) || shaderName == "null")
                shaderName = "MMN/BG/SimpleLit";
            var shader = Shader.Find(shaderName) ?? Shader.Find("MMN/BG/SimpleLit");
            if (shader != null) mat.shader = shader;
            if (data.ContainsKey("name")) mat.name = Convert.ToString(data["name"]);

            if (data.TryGetValue("floats", out var fObj) && fObj is Dictionary<string, object> floats)
                foreach (var kv in floats)
                    if (mat.HasProperty(kv.Key) && mat.HasFloat(kv.Key))
                        mat.SetFloat(kv.Key, Convert.ToSingle(kv.Value));
            if (data.TryGetValue("colors", out var cObj) && cObj is Dictionary<string, object> colors)
                foreach (var kv in colors)
                {
                    if (!mat.HasProperty(kv.Key) || !mat.HasColor(kv.Key)) continue;
                    var arr = kv.Value as List<object>;
                    if (arr == null || arr.Count < 4) continue;
                    mat.SetColor(kv.Key, new Color(Convert.ToSingle(arr[0]), Convert.ToSingle(arr[1]), Convert.ToSingle(arr[2]), Convert.ToSingle(arr[3])));
                }
            if (data.TryGetValue("texenvs", out var tObj) && tObj is Dictionary<string, object> texenvs)
                foreach (var kv in texenvs)
                {
                    if (!mat.HasProperty(kv.Key)) continue;
                    var te = kv.Value as Dictionary<string, object>;
                    if (te == null) continue;
                    string tname = te.ContainsKey("texture") ? Convert.ToString(te["texture"]) : null;
                    var tex = ResolveTexture(tname, texMap, texIndex);
                    if (tex != null) mat.SetTexture(kv.Key, tex);
                }
            if (mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") == null)
            {
                foreach (var cand in TextureNameCandidates(mat.name))
                {
                    var byName = ResolveTexture(cand, texMap, texIndex);
                    if (byName == null) continue;
                    mat.SetTexture("_BaseMap", byName);
                    break;
                }
            }
        }

        static Dictionary<string, Texture2D> ImportPackageTextures(string packPkg, string outPkg)
        {
            var map = new Dictionary<string, Texture2D>(StringComparer.OrdinalIgnoreCase);
            string src = packPkg + "/textures";
            string dst = outPkg + "/Textures";
            if (!Directory.Exists(src)) return map;

            foreach (var file in Directory.GetFiles(src, "*.png"))
            {
                string name = Path.GetFileName(file);
                string destAsset = dst + "/" + name;
                if (!File.Exists(destAsset))
                    File.Copy(file, destAsset, true);
            }
            AssetDatabase.Refresh(ImportAssetOptions.ForceSynchronousImport);

            foreach (var file in Directory.GetFiles(dst, "*.png"))
            {
                string assetPath = file.Replace("\\", "/");
                if (!assetPath.StartsWith("Assets"))
                {
                    int idx = assetPath.IndexOf("Assets/");
                    if (idx >= 0) assetPath = assetPath.Substring(idx);
                }
                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(assetPath);
                if (tex == null) continue;
                map[tex.name] = tex;
                map[Path.GetFileNameWithoutExtension(file)] = tex;
            }
            return map;
        }

        static void ConfigureTextures()
        {
            string[] guids = AssetDatabase.FindAssets("t:Texture2D", new[] { OutRoot, PackRoot });
            foreach (var g in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(g);
                var importer = AssetImporter.GetAtPath(path) as TextureImporter;
                if (importer == null) continue;
                string lower = path.ToLowerInvariant();
                bool isNormalDepth = lower.Contains("normal") || lower.Contains("normaldepth");
                bool isLeafOrGrass = lower.Contains("leaf") || lower.Contains("leaves") || lower.Contains("grass") ||
                                     lower.Contains("bush") || lower.Contains("flower") || lower.Contains("vine") ||
                                     lower.Contains("impostor");
                bool changed = false;
                if (isNormalDepth)
                {
                    if (importer.sRGBTexture) { importer.sRGBTexture = false; changed = true; }
                    if (importer.textureType != TextureImporterType.Default) { importer.textureType = TextureImporterType.Default; changed = true; }
                }
                if (isLeafOrGrass && !isNormalDepth)
                {
                    // DXT1 has no alpha channel, which silently kills the cutout mask, and
                    // these masks are small enough that uncompressed costs nothing.
                    if (importer.alphaSource != TextureImporterAlphaSource.FromInput) { importer.alphaSource = TextureImporterAlphaSource.FromInput; changed = true; }
                    if (!importer.alphaIsTransparency) { importer.alphaIsTransparency = true; changed = true; }
                    if (importer.textureCompression != TextureImporterCompression.Uncompressed) { importer.textureCompression = TextureImporterCompression.Uncompressed; changed = true; }
                }
                if (changed) importer.SaveAndReimport();
            }
        }

        static Material CreateMaterialFromJson(string jsonPath, string outPkg, Dictionary<string, Texture2D> texMap, Dictionary<string, string> texIndex)
        {
            var data = MiniJson.Deserialize(File.ReadAllText(jsonPath, Encoding.UTF8)) as Dictionary<string, object>;
            if (data == null) return null;
            string matName = data.ContainsKey("name") ? Convert.ToString(data["name"]) : Path.GetFileNameWithoutExtension(jsonPath);
            string shaderName = data.ContainsKey("shader") ? Convert.ToString(data["shader"]) : null;
            if (string.IsNullOrEmpty(shaderName) || shaderName == "null")
                shaderName = data.ContainsKey("shaderInferred") ? Convert.ToString(data["shaderInferred"]) : null;
            if (string.IsNullOrEmpty(shaderName) || shaderName == "null")
                shaderName = "MMN/BG/SimpleLit";

            var shader = Shader.Find(shaderName);
            if (shader == null)
            {
                // fallback map
                if (shaderName.Contains("TreeLeaves")) shader = Shader.Find("MMN/BG/TreeLeaves");
                else if (shaderName.Contains("Grass")) shader = Shader.Find("MMN/BG/Grass");
                else if (shaderName.Contains("WindowGlassAlphablend")) shader = Shader.Find("MMN/BG/WindowGlassAlphablend");
                else if (shaderName.Contains("WindowGlass")) shader = Shader.Find("MMN/BG/WindowGlass");
                else if (shaderName.Contains("AlphaBlend")) shader = Shader.Find("MMN/BG/SimpleLitAlphaBlend");
                else if (shaderName.Contains("Impostor")) shader = Shader.Find("Amplify Impostors/MM_Horizontal Impostor URP");
                else if (shaderName.Contains("ObjectDecalLight_StreetLamp")) shader = Shader.Find("MMN/FX/ObjectDecalLight_StreetLamp_BG");
                else if (shaderName.Contains("ObjectDecalLight")) shader = Shader.Find("MMN/FX/ObjectDecalLight");
                else if (shaderName.Contains("GodLay")) shader = Shader.Find("MMN/FX/Amplify shader/Environment/Additive_GodLay");
                else if (shaderName.Contains("Waterfall")) shader = Shader.Find("MMN/BG/Waterfall");
                else if (shaderName.Contains("SimpleLitLOD")) shader = Shader.Find("MMN/BG/SimpleLitLOD");
                else shader = Shader.Find("MMN/BG/SimpleLit") ?? Shader.Find("Universal Render Pipeline/Lit");
            }
            if (shader == null) return null;

            var mat = new Material(shader) { name = matName };

            if (data.TryGetValue("floats", out var fObj) && fObj is Dictionary<string, object> floats)
            {
                foreach (var kv in floats)
                {
                    if (!mat.HasProperty(kv.Key)) continue;
                    // Shipped materials sometimes store a float under a name that our
                    // reconstructed shader declares as Color/Vector — skip those.
                    if (mat.HasFloat(kv.Key))
                        mat.SetFloat(kv.Key, Convert.ToSingle(kv.Value));
                }
            }
            if (data.TryGetValue("colors", out var cObj) && cObj is Dictionary<string, object> colors)
            {
                foreach (var kv in colors)
                {
                    if (!mat.HasProperty(kv.Key) || !mat.HasColor(kv.Key)) continue;
                    var arr = kv.Value as List<object>;
                    if (arr == null || arr.Count < 4) continue;
                    mat.SetColor(kv.Key, new Color(Convert.ToSingle(arr[0]), Convert.ToSingle(arr[1]), Convert.ToSingle(arr[2]), Convert.ToSingle(arr[3])));
                }
            }
            if (data.TryGetValue("texenvs", out var tObj) && tObj is Dictionary<string, object> texenvs)
            {
                foreach (var kv in texenvs)
                {
                    if (!mat.HasProperty(kv.Key)) continue;
                    var te = kv.Value as Dictionary<string, object>;
                    if (te == null) continue;
                    string tname = te.ContainsKey("texture") ? Convert.ToString(te["texture"]) : null;
                    Texture2D tex = ResolveTexture(tname, texMap, texIndex);
                    if (tex != null)
                        mat.SetTexture(kv.Key, tex);

                    if (te.TryGetValue("scale", out var sc) && sc is List<object> scale && scale.Count >= 2 &&
                        te.TryGetValue("offset", out var of) && of is List<object> offset && offset.Count >= 2)
                    {
                        mat.SetTextureScale(kv.Key, new Vector2(Convert.ToSingle(scale[0]), Convert.ToSingle(scale[1])));
                        mat.SetTextureOffset(kv.Key, new Vector2(Convert.ToSingle(offset[0]), Convert.ToSingle(offset[1])));
                    }
                }
            }

            // Convenience aliases
            if (mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") == null && mat.HasProperty("_MainTex") && mat.GetTexture("_MainTex") != null)
                mat.SetTexture("_BaseMap", mat.GetTexture("_MainTex"));
            if (mat.HasProperty("_Albedo") && mat.GetTexture("_Albedo") == null && mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") != null)
                mat.SetTexture("_Albedo", mat.GetTexture("_BaseMap"));
            if (mat.HasProperty("_MainTex") && mat.GetTexture("_MainTex") == null && mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") != null)
                mat.SetTexture("_MainTex", mat.GetTexture("_BaseMap"));

            // MMN names a material after its albedo texture, so a slot left empty by an
            // unresolvable pointer can still be recovered from the material name.
            if (mat.HasProperty("_BaseMap") && mat.GetTexture("_BaseMap") == null)
            {
                foreach (var cand in TextureNameCandidates(matName))
                {
                    var byName = ResolveTexture(cand, texMap, texIndex);
                    if (byName == null) continue;
                    mat.SetTexture("_BaseMap", byName);
                    if (mat.HasProperty("_MainTex") && mat.GetTexture("_MainTex") == null)
                        mat.SetTexture("_MainTex", byName);
                    break;
                }
            }

            // Alpha test keyword for leaves etc.
            if (mat.HasProperty("_ALPHATEST") && mat.GetFloat("_ALPHATEST") > 0.5f)
                mat.EnableKeyword("_ALPHATEST_ON");
            if (shaderName.Contains("TreeLeaves") || shaderName.Contains("Grass") || shaderName.Contains("Impostor"))
            {
                mat.EnableKeyword("_ALPHATEST_ON");
                mat.renderQueue = -1;
                // A zero cutoff would keep the fully transparent atlas padding visible.
                if (mat.HasProperty("_Cutoff") && mat.GetFloat("_Cutoff") <= 0.001f)
                    mat.SetFloat("_Cutoff", 0.5f);
                // Tiling of (0,0) collapses every UV to a single texel.
                if (mat.HasProperty("_BaseMap"))
                {
                    var s = mat.GetTextureScale("_BaseMap");
                    if (s.x == 0f || s.y == 0f) mat.SetTextureScale("_BaseMap", Vector2.one);
                }
            }

            string assetPath = $"{outPkg}/Materials/{SanitizeFileName(matName)}.mat";
            assetPath = AssetDatabase.GenerateUniqueAssetPath(assetPath);
            AssetDatabase.CreateAsset(mat, assetPath);
            return AssetDatabase.LoadAssetAtPath<Material>(assetPath);
        }

        // Material variants append a region or batching suffix to the shared texture name
        // (Vine_Leaves_00_EmainUnder, Flower_Fiodh_01_Tint_00_SRPB, Tree_Trunk_00_1).
        static IEnumerable<string> TextureNameCandidates(string matName)
        {
            if (string.IsNullOrEmpty(matName)) yield break;
            yield return matName;

            string[] suffixes = { "_SRPB", "_Tint_00", "_Tint_01", "_Fiodh", "_EmainUnder", "_Glan", "_Outside" };
            string n = matName;
            for (int guard = 0; guard < suffixes.Length; guard++)
            {
                string before = n;
                foreach (var s in suffixes)
                {
                    if (n.Length > s.Length && n.EndsWith(s, StringComparison.OrdinalIgnoreCase))
                        n = n.Substring(0, n.Length - s.Length);
                }
                if (n == before) break;
                yield return n;
            }

            var m = System.Text.RegularExpressions.Regex.Match(n, @"^(.+?)_\d+$");
            if (m.Success) yield return m.Groups[1].Value;
        }

        static Texture2D ResolveTexture(string tname, Dictionary<string, Texture2D> texMap, Dictionary<string, string> texIndex)
        {
            if (string.IsNullOrEmpty(tname) || tname == "null") return null;
            if (texMap.TryGetValue(tname, out var t)) return t;

            // Exported files are prefixed with their source bundle ("<bundle>__<name>"),
            // so only accept a match on the full name after that separator. A loose
            // "contains" match here is what bound flower atlases onto leaf cards.
            foreach (var kv in texMap)
            {
                if (kv.Key.EndsWith("__" + tname, StringComparison.OrdinalIgnoreCase))
                    return kv.Value;
            }

            if (texIndex.TryGetValue(tname.ToLowerInvariant(), out var rel))
            {
                string path = PackRoot + "/" + rel.Replace("\\", "/");
                // Prefer copied package texture if present nearby; else load from pack
                var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
                if (tex != null) return tex;
            }
            return null;
        }

        static Mesh ImportMMesh(string path, string outMeshFolder)
        {
            using (var fs = File.OpenRead(path))
            using (var br = new BinaryReader(fs))
            {
                var magic = br.ReadBytes(4);
                if (magic[0] != 'M' || magic[1] != 'M' || magic[2] != 'S' || magic[3] != 'H')
                    throw new Exception("Bad mmesh magic: " + path);
                uint ver = br.ReadUInt32();
                if (ver != 1) throw new Exception("Unsupported mmesh version " + ver);
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

                var mesh = new Mesh();
                mesh.name = name;
                mesh.indexFormat = vc > 65535 ? UnityEngine.Rendering.IndexFormat.UInt32 : UnityEngine.Rendering.IndexFormat.UInt16;
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

                string assetPath = $"{outMeshFolder}/{SanitizeFileName(name)}.asset";
                assetPath = AssetDatabase.GenerateUniqueAssetPath(assetPath);
                AssetDatabase.CreateAsset(mesh, assetPath);
                return AssetDatabase.LoadAssetAtPath<Mesh>(assetPath);
            }
        }

        static void BuildOverviewScene(List<(string category, string packageId, string path, Bounds bounds)> prefabs)
        {
            EnsureFolder(OutRoot + "/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

            // Lighting tweak
            var light = GameObject.Find("Directional Light");
            if (light != null)
            {
                light.transform.rotation = Quaternion.Euler(50f, -30f, 0f);
                var l = light.GetComponent<Light>();
                if (l != null) { l.intensity = 1.2f; l.color = new Color(1f, 0.96f, 0.9f); }
            }

            var root = new GameObject("TirChonaill_Preview");
            var buildings = new GameObject("Buildings");
            buildings.transform.SetParent(root.transform);
            var vegetation = new GameObject("Vegetation");
            vegetation.transform.SetParent(root.transform);

            // Group by package, place package clusters on a grid
            var byPkg = new Dictionary<string, List<(string path, Bounds bounds)>>();
            foreach (var p in prefabs)
            {
                string key = p.category + "/" + p.packageId;
                if (!byPkg.TryGetValue(key, out var list))
                {
                    list = new List<(string, Bounds)>();
                    byPkg[key] = list;
                }
                list.Add((p.path, p.bounds));
            }

            float x = 0;
            float zBuild = 0;
            float zVeg = 0;
            const float packageGap = 25f;

            foreach (var kv in byPkg)
            {
                bool isBuilding = kv.Key.StartsWith("Buildings");
                var parent = isBuilding ? buildings.transform : vegetation.transform;
                var cluster = new GameObject(kv.Key.Replace("/", "_"));
                cluster.transform.SetParent(parent);

                float cursorX = 0f;
                float rowZ = 0f;
                float rowHeight = 0f;
                const float cellGap = 2f;
                const float rowWidth = 40f;

                foreach (var item in kv.Value)
                {
                    var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(item.path);
                    if (prefab == null) continue;
                    var inst = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
                    inst.transform.SetParent(cluster.transform);

                    var size = item.bounds.size;
                    float footprint = Mathf.Max(1f, Mathf.Max(size.x, size.z));
                    if (cursorX + footprint > rowWidth)
                    {
                        cursorX = 0;
                        rowZ += rowHeight + cellGap;
                        rowHeight = 0;
                    }
                    // place so mesh pivot sits on ground-ish: shift by -bounds.min.y
                    float yOffset = -item.bounds.min.y;
                    inst.transform.localPosition = new Vector3(cursorX + footprint * 0.5f - item.bounds.center.x, yOffset, rowZ - item.bounds.center.z);
                    cursorX += footprint + cellGap;
                    rowHeight = Mathf.Max(rowHeight, footprint);
                }

                float placeZ = isBuilding ? zBuild : zVeg;
                cluster.transform.position = new Vector3(isBuilding ? x : x, 0, placeZ);
                if (isBuilding) zBuild += packageGap;
                else zVeg += packageGap;
                x += isBuilding ? 0 : 0; // keep columns separate
            }

            // Separate columns
            buildings.transform.position = new Vector3(0, 0, 0);
            vegetation.transform.position = new Vector3(80, 0, 0);

            var cam = Camera.main;
            if (cam != null)
            {
                cam.transform.position = new Vector3(40, 30, -40);
                cam.transform.rotation = Quaternion.Euler(25, -20, 0);
            }

            string scenePath = OutRoot + "/Scenes/TirChonaill_Preview.unity";
            EditorSceneManager.SaveScene(scene, scenePath);
        }

        static void EnsureFolders()
        {
            EnsureFolder(OutRoot);
            EnsureFolder(OutRoot + "/Buildings");
            EnsureFolder(OutRoot + "/Vegetation");
            EnsureFolder(OutRoot + "/Shaders");
            EnsureFolder(OutRoot + "/Scenes");
            EnsureFolder(OutRoot + "/Editor");
        }

        static void EnsureFolder(string assetPath)
        {
            if (AssetDatabase.IsValidFolder(assetPath)) return;
            string parent = Path.GetDirectoryName(assetPath).Replace("\\", "/");
            string name = Path.GetFileName(assetPath);
            if (!AssetDatabase.IsValidFolder(parent))
                EnsureFolder(parent);
            if (!AssetDatabase.IsValidFolder(assetPath))
                AssetDatabase.CreateFolder(parent, name);
        }

        static string SanitizeFileName(string name)
        {
            if (string.IsNullOrEmpty(name)) return "unnamed";
            foreach (var c in Path.GetInvalidFileNameChars())
                name = name.Replace(c, '_');
            name = name.Replace('@', '_');
            return name;
        }
    }

    /// <summary>Minimal JSON parser sufficient for our import pack.</summary>
    static class MiniJson
    {
        public static object Deserialize(string json)
        {
            return new Parser(json).ParseValue();
        }

        class Parser
        {
            readonly string _json;
            int _i;
            public Parser(string json) { _json = json; _i = 0; }

            public object ParseValue()
            {
                Skip();
                if (_i >= _json.Length) return null;
                char c = _json[_i];
                if (c == '{') return ParseObject();
                if (c == '[') return ParseArray();
                if (c == '"') return ParseString();
                if (c == 't' || c == 'f') return ParseBool();
                if (c == 'n') { _i += 4; return null; }
                return ParseNumber();
            }

            Dictionary<string, object> ParseObject()
            {
                var dict = new Dictionary<string, object>();
                _i++; // {
                while (true)
                {
                    Skip();
                    if (_json[_i] == '}') { _i++; break; }
                    string key = ParseString();
                    Skip();
                    _i++; // :
                    object val = ParseValue();
                    dict[key] = val;
                    Skip();
                    if (_json[_i] == ',') { _i++; continue; }
                    if (_json[_i] == '}') { _i++; break; }
                }
                return dict;
            }

            List<object> ParseArray()
            {
                var list = new List<object>();
                _i++; // [
                while (true)
                {
                    Skip();
                    if (_json[_i] == ']') { _i++; break; }
                    list.Add(ParseValue());
                    Skip();
                    if (_json[_i] == ',') { _i++; continue; }
                    if (_json[_i] == ']') { _i++; break; }
                }
                return list;
            }

            string ParseString()
            {
                var sb = new StringBuilder();
                _i++; // "
                while (_i < _json.Length)
                {
                    char c = _json[_i++];
                    if (c == '"') break;
                    if (c == '\\')
                    {
                        char e = _json[_i++];
                        switch (e)
                        {
                            case '"': sb.Append('"'); break;
                            case '\\': sb.Append('\\'); break;
                            case '/': sb.Append('/'); break;
                            case 'b': sb.Append('\b'); break;
                            case 'f': sb.Append('\f'); break;
                            case 'n': sb.Append('\n'); break;
                            case 'r': sb.Append('\r'); break;
                            case 't': sb.Append('\t'); break;
                            case 'u':
                                string hex = _json.Substring(_i, 4); _i += 4;
                                sb.Append((char)Convert.ToInt32(hex, 16));
                                break;
                            default: sb.Append(e); break;
                        }
                    }
                    else sb.Append(c);
                }
                return sb.ToString();
            }

            object ParseNumber()
            {
                int start = _i;
                while (_i < _json.Length && "0123456789+-.eE".IndexOf(_json[_i]) >= 0) _i++;
                string s = _json.Substring(start, _i - start);
                if (s.IndexOfAny(new[] { '.', 'e', 'E' }) >= 0)
                    return double.Parse(s, System.Globalization.CultureInfo.InvariantCulture);
                if (long.TryParse(s, out long l)) return l;
                return double.Parse(s, System.Globalization.CultureInfo.InvariantCulture);
            }

            object ParseBool()
            {
                if (_json[_i] == 't') { _i += 4; return true; }
                _i += 5; return false;
            }

            void Skip()
            {
                while (_i < _json.Length && char.IsWhiteSpace(_json[_i])) _i++;
            }
        }
    }
}
#endif
