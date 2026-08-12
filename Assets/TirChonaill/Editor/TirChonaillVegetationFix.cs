#if UNITY_EDITOR
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace TirChonaill.Editor
{
    public static class TirChonaillVegetationFix
    {
        [MenuItem("TirChonaill/Fix Vegetation Preview")]
        public static void FixMenu()
        {
            Fix();
        }

        public static string Fix()
        {
            var report = new System.Text.StringBuilder();
            var allTex = new List<Texture2D>();
            foreach (var g in AssetDatabase.FindAssets("t:Texture2D", new[] { "Assets/TirChonaill" }))
            {
                var t = AssetDatabase.LoadAssetAtPath<Texture2D>(AssetDatabase.GUIDToAssetPath(g));
                if (t != null) allTex.Add(t);
            }

            int texFixed = 0;
            foreach (var t in allTex)
            {
                string p = AssetDatabase.GetAssetPath(t).ToLowerInvariant();
                bool foliage = p.Contains("albedoalpha") || p.Contains("leaf") || p.Contains("leaves") ||
                               p.Contains("grass") || p.Contains("vine") || p.Contains("flower") ||
                               p.Contains("bush") || p.Contains("impostor");
                if (!foliage) continue;
                var imp = AssetImporter.GetAtPath(AssetDatabase.GetAssetPath(t)) as TextureImporter;
                if (imp == null) continue;
                bool ch = false;
                if (!imp.alphaIsTransparency) { imp.alphaIsTransparency = true; ch = true; }
                if (imp.textureType != TextureImporterType.Default) { imp.textureType = TextureImporterType.Default; ch = true; }
                if (p.Contains("normaldepth"))
                {
                    if (imp.sRGBTexture) { imp.sRGBTexture = false; ch = true; }
                }
                else if (!imp.sRGBTexture) { imp.sRGBTexture = true; ch = true; }
                if (ch) { imp.SaveAndReimport(); texFixed++; }
            }
            report.AppendLine("texImportFixed=" + texFixed);

            int matFixed = 0;
            int stillMiss = 0;
            foreach (var g in AssetDatabase.FindAssets("t:Material", new[] { "Assets/TirChonaill/Vegetation" }))
            {
                var m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(g));
                if (m == null) continue;

                bool has = false;
                if (m.HasProperty("_BaseMap") && m.GetTexture("_BaseMap") != null) has = true;
                if (m.HasProperty("_MainTex") && m.GetTexture("_MainTex") != null) has = true;
                if (m.HasProperty("_Albedo") && m.GetTexture("_Albedo") != null) has = true;
                if (has) continue;

                var tex = FindFoliageTex(m.name, allTex);
                if (tex == null)
                {
                    stillMiss++;
                    report.AppendLine("MISS " + m.name + " | " + m.shader.name);
                    continue;
                }

                if (m.HasProperty("_BaseMap")) m.SetTexture("_BaseMap", tex);
                if (m.HasProperty("_MainTex")) m.SetTexture("_MainTex", tex);
                if (m.HasProperty("_Albedo")) m.SetTexture("_Albedo", tex);
                if (m.HasProperty("_Cutoff") && m.GetFloat("_Cutoff") > 0.55f) m.SetFloat("_Cutoff", 0.35f);
                if (m.HasProperty("_ALPHATEST")) m.SetFloat("_ALPHATEST", 1f);
                m.EnableKeyword("_ALPHATEST_ON");
                EditorUtility.SetDirty(m);
                matFixed++;
                report.AppendLine("BOUND " + m.name + " <= " + tex.name);
            }

            // Fix bad material assignments in Vegetation scene objects / prefabs:
            // hide non-vegetation junk that leaked from shared bundles.
            int hidden = 0;
            var vegRoot = GameObject.Find("Vegetation");
            if (vegRoot != null)
            {
                foreach (var tr in vegRoot.GetComponentsInChildren<Transform>(true))
                {
                    if (tr == vegRoot.transform) continue;
                    string n = tr.name;
                    // Only hide obvious non-foliage props under vegetation clusters
                    bool junk =
                        n.StartsWith("TirChonaill_School") ||
                        n.StartsWith("TirChonaill_Inn") ||
                        n.StartsWith("TirChonaill_Church") ||
                        n.StartsWith("TirChonaill_Interior") ||
                        n.StartsWith("FloorStone") ||
                        n.StartsWith("Bucket_") ||
                        n.StartsWith("Mud_Box") ||
                        n.StartsWith("Pot_") ||
                        n.StartsWith("Box_") ||
                        n.StartsWith("WaterBucket") ||
                        n.StartsWith("SchoolBell") ||
                        n.Contains("Housing") ||
                        n.Contains("GodLay");
                    if (!junk) continue;
                    if (tr.gameObject.activeSelf)
                    {
                        tr.gameObject.SetActive(false);
                        hidden++;
                    }
                }
            }

            // Rebind renderers that still use Grass fallback on non-grass meshes
            int rebound = 0;
            if (vegRoot != null)
            {
                var leafMats = new List<Material>();
                foreach (var g in AssetDatabase.FindAssets("t:Material", new[] { "Assets/TirChonaill/Vegetation" }))
                {
                    var m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(g));
                    if (m != null && m.shader != null && m.shader.name.Contains("TreeLeaves"))
                        leafMats.Add(m);
                }

                foreach (var mr in vegRoot.GetComponentsInChildren<MeshRenderer>(true))
                {
                    if (!mr.gameObject.activeInHierarchy) continue;
                    var mats = mr.sharedMaterials;
                    bool changed = false;
                    for (int i = 0; i < mats.Length; i++)
                    {
                        var mat = mats[i];
                        if (mat == null) continue;
                        bool isGrassFallback = mat.name.Contains("Grass_TirChonaill");
                        bool meshLooksLeaf =
                            mr.name.Contains("Leaf") || mr.name.Contains("Leaves") ||
                            mr.name.Contains("Tree") || mr.name.Contains("Bush") ||
                            mr.name.Contains("Vine") || mr.name.Contains("Swing") ||
                            mr.name.Contains("Maple") || mr.name.Contains("Impostor");
                        if (isGrassFallback && meshLooksLeaf && !mr.name.Contains("Grass"))
                        {
                            Material best = null;
                            string mn = mr.name.ToLowerInvariant();
                            int bestScore = -1;
                            foreach (var lm in leafMats)
                            {
                                string ln = lm.name.ToLowerInvariant();
                                int score = 0;
                                if (mn.Contains("swing") && ln.Contains("swing")) score = 100;
                                else if (mn.Contains("maple") && ln.Contains("maple")) score = 100;
                                else if (mn.Contains("tree_07") && ln.Contains("tree_07")) score = 100;
                                else if (mn.Contains("thick") && ln.Contains("thick")) score = 100;
                                else if (mn.Contains("bush") && (ln.Contains("bush") || ln.Contains("leaves"))) score = 80;
                                else if (mn.Contains("vine") && ln.Contains("vine")) score = 100;
                                else if (mn.Contains("impostor") && ln.Contains("impostor") == false && lm.HasProperty("_BaseMap") && lm.GetTexture("_BaseMap") != null) score = 10;
                                if (score > bestScore) { bestScore = score; best = lm; }
                            }
                            if (best != null && bestScore >= 80)
                            {
                                mats[i] = best;
                                changed = true;
                            }
                        }
                    }
                    if (changed)
                    {
                        mr.sharedMaterials = mats;
                        rebound++;
                        EditorUtility.SetDirty(mr);
                    }
                }
            }

            // Prefer textured grass mat on grass meshes
            if (vegRoot != null)
            {
                Material grassGood = null;
                Material swingLeaf = null, mapleLeaf = null, tree07 = null, thick = null, bush = null;
                foreach (var g in AssetDatabase.FindAssets("t:Material", new[] { "Assets/TirChonaill/Vegetation" }))
                {
                    var m = AssetDatabase.LoadAssetAtPath<Material>(AssetDatabase.GUIDToAssetPath(g));
                    if (m == null) continue;
                    if (m.name == "TirChonaill_Grass_00") grassGood = m;
                    if (m.name == "Tree_Swing_00_Leaves") swingLeaf = m;
                    if (m.name == "Maple_Tree_00_Leaves") mapleLeaf = m;
                    if (m.name == "Tree_07_Leaves") tree07 = m;
                    if (m.name == "Tree_Thick_00_Leaves") thick = m;
                    if (m.name.Contains("Tree_Leaves_00_23")) bush = m;
                }
                foreach (var mr in vegRoot.GetComponentsInChildren<MeshRenderer>(true))
                {
                    if (!mr.gameObject.activeInHierarchy) continue;
                    string n = mr.name.ToLowerInvariant();
                    Material want = null;
                    if (n.Contains("grass") && grassGood != null) want = grassGood;
                    else if (n.Contains("swing") && (n.Contains("leaf") || n.Contains("impostor"))) want = swingLeaf;
                    else if (n.Contains("maple") && (n.Contains("leaf") || n.Contains("vine") || n.Contains("impostor"))) want = mapleLeaf;
                    else if (n.Contains("tree_07")) want = tree07;
                    else if (n.Contains("thick")) want = thick;
                    else if (n.Contains("bush")) want = bush;
                    if (want == null) continue;
                    var mats = mr.sharedMaterials;
                    bool ch = false;
                    for (int i = 0; i < mats.Length; i++)
                    {
                        if (mats[i] == want) continue;
                        bool bad = mats[i] == null ||
                                   (mats[i].shader != null && mats[i].shader.name.Contains("Grass") && !n.Contains("grass")) ||
                                   ((mats[i].HasProperty("_BaseMap") ? mats[i].GetTexture("_BaseMap") : null) == null &&
                                    (mats[i].HasProperty("_Albedo") ? mats[i].GetTexture("_Albedo") : null) == null);
                        if (bad) { mats[i] = want; ch = true; }
                    }
                    if (ch) { mr.sharedMaterials = mats; rebound++; EditorUtility.SetDirty(mr); }
                }
            }

            if (vegRoot != null)
            {
                UnityEditor.SceneManagement.EditorSceneManager.MarkSceneDirty(
                    UnityEngine.SceneManagement.SceneManager.GetActiveScene());
                UnityEditor.SceneManagement.EditorSceneManager.SaveOpenScenes();
            }

            AssetDatabase.SaveAssets();
            report.AppendLine("matFixed=" + matFixed + " stillMiss=" + stillMiss + " hiddenJunk=" + hidden + " rebound=" + rebound);
            Debug.Log("[TirChonaill] Vegetation Fix\n" + report);
            return report.ToString();
        }

        static Texture2D FindFoliageTex(string matName, List<Texture2D> allTex)
        {
            string mn = matName.ToLowerInvariant().Replace("_lod", "");
            Texture2D best = null;
            int bestScore = -1;
            foreach (var t in allTex)
            {
                string tn = t.name.ToLowerInvariant();
                int score = -1;
                if (tn.Contains("albedoalpha"))
                {
                    if (mn.Contains("swing") && tn.Contains("swing")) score = 500;
                    else if (mn.Contains("maple") && tn.Contains("maple")) score = 500;
                    else if (mn.Contains("tree_07") && tn.Contains("tree_07") && !tn.Contains("fiodh") && !tn.Contains("tree_07_1")) score = 500;
                    else if (mn.Contains("thick") && tn.Contains("thick")) score = 480;
                    else if ((mn.Contains("bush") || mn.Contains("leaves_00_23")) && tn.Contains("bush_00_10")) score = 470;
                    else if (mn.Contains("glan") && tn.Contains("glan")) score = 470;
                }
                if (mn.Contains("grass"))
                {
                    if (tn.Contains("tirchonaill_grass") || tn.Contains("global_grass")) score = Mathf.Max(score, 450);
                }
                if (mn.Contains("vine") && tn.Contains("vine_leaves")) score = Mathf.Max(score, 450);
                if (mn.Contains("flower") && tn.Contains("flower")) score = Mathf.Max(score, 420);
                if (score > bestScore) { bestScore = score; best = t; }
            }
            return bestScore >= 200 ? best : null;
        }
    }
}
#endif
