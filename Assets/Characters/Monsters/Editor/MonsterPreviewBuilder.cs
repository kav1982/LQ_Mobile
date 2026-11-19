using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace Characters.Monsters.Editor
{
    public static class MonsterPreviewBuilder
    {
        const string PreviewShaderPath = "Assets/Characters/Infant/Reconstructed/Shaders/InfantStandard.shader";
        const string FxShaderPath = "Assets/MMN/Shaders/FX/MMN_FX_Amplify_shader_FX_Dissolve_Div_Distortion_Offset.shader";
        const string HandSocket = "_HandtoolR";
        const string ShieldSocket = "_HandtoolL";
        const float Cell = 2.4f;
        const int Columns = 7;

        sealed class FamilySpec
        {
            public string Name;
            public string Root;
            public string BodyKey;
            public string AnimFolder;
            public string ClipRoot;
            public string ItemNeedle;
            public string[] ItemExclude;
            public float Spacing = Cell;
            public FamilySpec Companion;
        }

        static FamilySpec Spec(string name, string bodyKey, string animFolder, FamilySpec companion = null)
        {
            string root = "Assets/Characters/Monsters/" + name;
            return new FamilySpec
            {
                Name = name,
                Root = root,
                BodyKey = bodyKey,
                AnimFolder = animFolder,
                ClipRoot = root,
                ItemNeedle = bodyKey,
                Companion = companion
            };
        }

        static FamilySpec CombatGnoll()
        {
            var archer = Spec("GnollArcher", "gnollarcher", "gnoll");
            archer.ClipRoot = "Assets/Characters/Monsters/Gnoll";
            archer.ItemNeedle = "gnollarcher";
            return Spec("Gnoll", "gnoll", "gnoll", archer);
        }

        static FamilySpec[] CombatBatch()
        {
            return new[]
            {
                CombatGnoll(),
                Spec("GhostArmor", "ghostarmor", "ghostarmor"),
                Spec("Ratman", "ratman", "ratman"),
                Spec("Skeleton", "skeleton", "skeleton"),
                GolemSpec(),
                Spec("Kobold", "kobold", "kobold")
            };
        }

        static readonly string[] SkinSuffixes =
        {
            "_asparagus_gatheringdungeon",
            "_woodworker_gatheringdungeon",
            "_tomato_gatheringdungeon",
            "_greenpeas_gatheringdungeon",
            "_gatheringdungeon",
            "_abysss3",
            "_abysss2",
            "_abyss",
            "_deep",
            "_shade",
            "_quest",
            "_renewal"
        };

        [MenuItem("Tools/Characters/Monsters/Build Combat Batch Previews")]
        public static void BuildCombatBatch()
        {
            foreach (var family in CombatBatch())
                BuildFamily(family);
        }

        [MenuItem("Tools/Characters/Monsters/Build Gnoll Preview")]
        public static void BuildGnoll() => BuildFamily(CombatGnoll());

        [MenuItem("Tools/Characters/Monsters/Build GhostArmor Preview")]
        public static void BuildGhostArmor() => BuildFamily(Spec("GhostArmor", "ghostarmor", "ghostarmor"));

        [MenuItem("Tools/Characters/Monsters/Build Ratman Preview")]
        public static void BuildRatman() => BuildFamily(Spec("Ratman", "ratman", "ratman"));

        [MenuItem("Tools/Characters/Monsters/Build Skeleton Preview")]
        public static void BuildSkeleton() => BuildFamily(Spec("Skeleton", "skeleton", "skeleton"));

        static FamilySpec GolemSpec()
        {
            var spec = Spec("Golem", "golem", "golem");
            spec.Spacing = 8f;
            return spec;
        }

        [MenuItem("Tools/Characters/Monsters/Build Golem Preview")]
        public static void BuildGolem() => BuildFamily(GolemSpec());

        [MenuItem("Tools/Characters/Monsters/Build Kobold Preview")]
        public static void BuildKobold() => BuildFamily(Spec("Kobold", "kobold", "kobold"));

        static FamilySpec CountSpider()
        {
            var ling = Spec("Spiderling", "spiderling", "spider");
            ling.ClipRoot = "Assets/Characters/Monsters/Spider";
            var spider = Spec("Spider", "spider", "spider", ling);
            spider.Spacing = 4f;
            return spider;
        }

        static FamilySpec CountMud()
        {
            var mud = Spec("Mud", "mud", "mud");
            mud.ItemExclude = new[] { "mountainmud", "skeleton_mud" };
            return mud;
        }

        static FamilySpec CountDigger()
        {
            var spec = Spec("Digger", "digger", "digger");
            spec.Spacing = 5f;
            return spec;
        }

        static FamilySpec CountEarthen()
        {
            var spec = Spec("Earthen", "earthen", "earthen");
            spec.Spacing = 5f;
            return spec;
        }

        static FamilySpec CountSlime()
        {
            var spec = Spec("Slime", "slime", "slime");
            spec.Spacing = 5f;
            return spec;
        }

        static FamilySpec[] CountBatch()
        {
            return new[]
            {
                CountMud(),
                CountEarthen(),
                CountDigger(),
                CountSlime(),
                Spec("Rat", "rat", "rat"),
                CountSpider()
            };
        }

        [MenuItem("Tools/Characters/Monsters/Build Count Batch Previews")]
        public static void BuildCountBatch()
        {
            foreach (var family in CountBatch())
                BuildFamily(family);
        }

        [MenuItem("Tools/Characters/Monsters/Build Mud Preview")]
        public static void BuildMud() => BuildFamily(CountMud());

        [MenuItem("Tools/Characters/Monsters/Build Earthen Preview")]
        public static void BuildEarthen() => BuildFamily(CountEarthen());

        [MenuItem("Tools/Characters/Monsters/Build Digger Preview")]
        public static void BuildDigger() => BuildFamily(CountDigger());

        [MenuItem("Tools/Characters/Monsters/Build Slime Preview")]
        public static void BuildSlime() => BuildFamily(CountSlime());

        [MenuItem("Tools/Characters/Monsters/Build Rat Preview")]
        public static void BuildRat() => BuildFamily(Spec("Rat", "rat", "rat"));

        [MenuItem("Tools/Characters/Monsters/Build Spider Preview")]
        public static void BuildSpider() => BuildFamily(CountSpider());

        static void BuildFamily(FamilySpec family)
        {
            EnsureGenerated(family);
            if (family.Companion != null)
                EnsureGenerated(family.Companion);

            var mainClips = LoadClips(AnimPath(family));
            var companionClips = family.Companion != null ? LoadClips(AnimPath(family.Companion)) : new AnimationClip[0];
            if (companionClips.Length == 0 && family.Companion != null)
                companionClips = mainClips;

            var prefixes = ClipPrefixes(mainClips.Concat(companionClips));
            var items = LoadItems(family);
            if (family.Companion != null)
                items = items.Concat(LoadItems(family.Companion)).ToArray();

            var bodies = LoadBodies(family.Root, family.BodyKey);
            var companions = family.Companion != null
                ? LoadBodies(family.Companion.Root, family.Companion.BodyKey)
                : new GameObject[0];
            if (bodies.Length == 0)
                throw new InvalidOperationException("No body prefabs under " + family.Root + "/Source.");

            var controllers = new Dictionary<string, AnimatorController>(StringComparer.OrdinalIgnoreCase);
            var previews = new List<GameObject>();
            var report = new List<string>();

            void BuildOne(GameObject body, bool companion)
            {
                var spec = companion ? family.Companion : family;
                var clips = companion ? companionClips : mainClips;
                string prefix = PickClipPrefix(body.name, prefixes, spec.AnimFolder);
                if (!controllers.TryGetValue(prefix ?? "", out var controller) && prefix != null)
                {
                    controller = BuildController(spec.Root, prefix, clips.Length > 0 ? clips : mainClips);
                    controllers[prefix] = controller;
                }

                var weapon = PickWeapon(body.name, items);
                var shield = PickShield(body.name, items, weapon);
                var preview = BuildPreviewPrefab(body, weapon, shield, controller, spec.Root);
                previews.Add(preview);
                report.Add($"{body.name} clip={prefix ?? "-"} weapon={(weapon != null ? weapon.name : "-")} shield={(shield != null ? shield.name : "-")}");
            }

            foreach (var body in bodies)
                BuildOne(body, false);
            foreach (var body in companions)
                BuildOne(body, true);

            string scenePath = family.Root + "/Scenes/" + family.Name + "_Preview.unity";
            BuildPreviewScene(
                previews.ToArray(),
                bodies.Length,
                scenePath,
                family.Name,
                family.Companion != null ? family.Companion.Name : null,
                family.Spacing);
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[{family.Name}Preview] {previews.Count} prefabs, {controllers.Count} controllers, scene {scenePath}\n" + string.Join("\n", report));
        }

        static void EnsureGenerated(FamilySpec family)
        {
            EnsureFolder(family.Root + "/Generated/Prefabs");
            EnsureFolder(family.Root + "/Generated/Materials");
            EnsureFolder(family.Root + "/Generated/Animators");
            EnsureFolder(family.Root + "/Scenes");
        }

        static string AnimPath(FamilySpec family)
        {
            string clipRoot = string.IsNullOrEmpty(family.ClipRoot) ? family.Root : family.ClipRoot;
            return clipRoot + "/Source/patchableassets/animation/monster/" + family.AnimFolder;
        }

        static GameObject[] LoadBodies(string root, string bodyKey)
        {
            string folder = root + "/Source/patchableassets/character/monster";
            if (!AssetDatabase.IsValidFolder(folder)) return new GameObject[0];
            string prefix = "monster_" + bodyKey;
            return AssetDatabase.FindAssets("t:Prefab", new[] { folder })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(path =>
                {
                    string unix = path.Replace('\\', '/').ToLowerInvariant();
                    if (unix.Contains("/item/") || unix.Contains("/fbx/")) return false;
                    string name = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
                    return name == prefix || name.StartsWith(prefix + "_");
                })
                .Select(AssetDatabase.LoadAssetAtPath<GameObject>)
                .Where(prefab => prefab != null)
                .OrderBy(prefab => prefab.name)
                .ToArray();
        }

        static GameObject[] LoadItems(FamilySpec family)
        {
            string folder = family.Root + "/Source/patchableassets/character/monster/item";
            if (!AssetDatabase.IsValidFolder(folder)) return new GameObject[0];
            return AssetDatabase.FindAssets("t:Prefab", new[] { folder })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(path =>
                {
                    string name = Path.GetFileName(path).ToLowerInvariant();
                    if (!name.Contains(family.ItemNeedle)) return false;
                    if (family.ItemExclude == null) return true;
                    foreach (var excluded in family.ItemExclude)
                    {
                        if (name.Contains(excluded)) return false;
                    }
                    return true;
                })
                .Select(AssetDatabase.LoadAssetAtPath<GameObject>)
                .Where(prefab => prefab != null)
                .ToArray();
        }

        static AnimationClip[] LoadClips(string folder)
        {
            if (!AssetDatabase.IsValidFolder(folder)) return new AnimationClip[0];
            return AssetDatabase.FindAssets("t:AnimationClip", new[] { folder })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Select(AssetDatabase.LoadAssetAtPath<AnimationClip>)
                .Where(clip => clip != null)
                .OrderBy(clip => clip.name)
                .ToArray();
        }

        static HashSet<string> ClipPrefixes(IEnumerable<AnimationClip> clips)
        {
            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var clip in clips)
            {
                string name = Normalize(clip.name.ToLowerInvariant());
                int at = name.IndexOf('@');
                if (at > 0) set.Add(name.Substring(0, at));
            }
            return set;
        }

        static string Normalize(string value)
        {
            return value
                .Replace("cheiftain", "chieftain")
                .Replace("defualt", "default")
                .Replace("quaterstaff", "quarterstaff")
                .Replace("gnall_", "gnoll_")
                .Replace("blacksacr", "blackscar")
                .Replace("worrior", "warrior")
                .Replace("ghostarmorbody", "ghostarmor")
                .Replace("metalskeleton", "skeleton_metal")
                .Replace("ratmandefaultsword", "ratman_default_sword")
                .Replace("ratmantrident", "ratman_trident")
                .Replace("skeletone", "skeleton");
        }

        static string StripMonster(string stem)
        {
            string key = stem.ToLowerInvariant();
            if (key.StartsWith("monster_")) key = key.Substring("monster_".Length);
            return Normalize(key);
        }

        static string StripSkin(string key)
        {
            foreach (var suffix in SkinSuffixes)
            {
                if (key.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                    return key.Substring(0, key.Length - suffix.Length);
            }
            return key;
        }

        static string PickClipPrefix(string stem, HashSet<string> prefixes, string clipKey)
        {
            if (prefixes.Count == 0) return null;
            string key = StripMonster(stem);
            string stripped = StripSkin(key);
            string twice = StripSkin(stripped);
            string best = null;
            int bestScore = -1;
            foreach (var prefix in prefixes)
            {
                int score = ScorePrefix(key, stripped, twice, prefix, clipKey);
                if (score > bestScore)
                {
                    bestScore = score;
                    best = prefix;
                }
            }
            return bestScore > 0 ? best : prefixes.First();
        }

        static int ScorePrefix(string key, string stripped, string twice, string prefix, string clipKey)
        {
            if (prefix == key || prefix == stripped || prefix == twice) return 10000 + prefix.Length;
            if (StartsWithToken(key, prefix) || StartsWithToken(stripped, prefix) || StartsWithToken(twice, prefix))
                return 8000 + prefix.Length;
            if (StartsWithToken(prefix, stripped) || StartsWithToken(prefix, twice))
                return 6000 + stripped.Length;

            var bodyTokens = Tokens(twice);
            var prefixTokens = Tokens(prefix);
            int overlap = bodyTokens.Intersect(prefixTokens).Count();
            if (overlap >= 2) return 3000 + overlap * 80 + Math.Min(prefix.Length, twice.Length);
            if (overlap == 1 && prefixTokens.Contains(clipKey))
                return 400 + twice.Length;

            if (prefix == clipKey + "_default" || prefix == clipKey) return 80;
            if (twice.Contains("small") && prefix.Contains("small")) return 120;
            if (twice.Contains("mystic") && prefix.Contains("mystic")) return 700;
            if (twice.Contains("giant") && prefix.Contains("giant")) return 700;
            if (twice.Contains("runda") && prefix.Contains("runda")) return 700;
            if (twice.Contains("long") && prefix.Contains("long")) return 700;
            if (twice.Contains("drass") && prefix.Contains("drass")) return 700;
            if (twice.Contains("duelist") && prefix.Contains("duelist")) return 700;
            return 0;
        }

        static bool StartsWithToken(string value, string prefix)
        {
            return value == prefix || value.StartsWith(prefix + "_", StringComparison.Ordinal);
        }

        static IEnumerable<string> SplitNameParts(string value)
        {
            foreach (var raw in value.Split('_'))
            {
                if (string.IsNullOrEmpty(raw)) continue;
                bool camel = false;
                for (int i = 1; i < raw.Length; i++)
                {
                    if (char.IsUpper(raw[i]))
                    {
                        camel = true;
                        break;
                    }
                }
                if (!camel)
                {
                    yield return raw.ToLowerInvariant();
                    continue;
                }

                var buffer = new System.Text.StringBuilder();
                foreach (char c in raw)
                {
                    if (char.IsUpper(c) && buffer.Length > 0)
                    {
                        yield return buffer.ToString().ToLowerInvariant();
                        buffer.Clear();
                    }
                    buffer.Append(c);
                }
                if (buffer.Length > 0)
                    yield return buffer.ToString().ToLowerInvariant();
            }
        }

        static HashSet<string> Tokens(string value)
        {
            var skip = new HashSet<string>
            {
                "monster", "tool", "default", "00", "01", "02", "03", "04",
                "deep", "abyss", "abysss2", "abysss3", "shade", "quest", "renewal"
            };
            var set = new HashSet<string>();
            foreach (var token in SplitNameParts(value))
            {
                if (token.Length > 1 && !skip.Contains(token))
                    set.Add(token);
            }
            if (set.Contains("gnollarcher"))
            {
                set.Add("gnoll");
                set.Add("archer");
            }
            if (set.Contains("spiderling"))
                set.Add("spider");
            if (set.Contains("giantrat"))
            {
                set.Add("giant");
                set.Add("rat");
            }
            if (set.Contains("dragonhood"))
            {
                set.Add("dragon");
                set.Add("hood");
            }
            var extra = new List<string>();
            foreach (var token in set)
            {
                if (token.StartsWith("high") && token.Length > 5)
                    extra.Add(token.Substring(4));
            }
            foreach (var token in extra)
                set.Add(token);
            return set;
        }

        static GameObject PickWeapon(string stem, GameObject[] items)
        {
            string key = StripMonster(stem);
            GameObject best = null;
            int bestScore = 0;
            foreach (var item in items)
            {
                if (IsShield(item.name)) continue;
                int score = ScoreWeapon(key, item.name);
                if (score > bestScore)
                {
                    bestScore = score;
                    best = item;
                }
            }
            return bestScore >= 200 ? best : null;
        }

        static GameObject PickShield(string stem, GameObject[] items, GameObject weapon)
        {
            if (weapon != null && IsShield(weapon.name)) return null;
            string key = StripMonster(stem);
            GameObject best = null;
            int bestScore = 0;
            foreach (var item in items)
            {
                if (!IsShield(item.name)) continue;
                int score = ScoreWeapon(key, item.name);
                if (score > bestScore)
                {
                    bestScore = score;
                    best = item;
                }
            }
            return bestScore >= 200 ? best : null;
        }

        static bool IsShield(string name)
        {
            string lower = name.ToLowerInvariant();
            return lower.Contains("sheild") || lower.Contains("shield");
        }

        static int ScoreWeapon(string bodyKey, string itemName)
        {
            string body = StripSkin(bodyKey);
            string item = Normalize(itemName.ToLowerInvariant());
            if (item.Contains(bodyKey.ToLowerInvariant())) return 1000 + bodyKey.Length;
            if (body != bodyKey && item.Contains(body)) return 800 + body.Length;

            var bodyTokens = Tokens(body);
            var itemTokens = Tokens(itemName);
            bool archerBody = body.Contains("archer") || bodyTokens.Contains("archer") || bodyTokens.Contains("sharpshooter");
            if (archerBody && !item.Contains("bow") && !item.Contains("archer"))
                return 0;
            int overlap = bodyTokens.Intersect(itemTokens).Count();
            var species = new HashSet<string>
            {
                "gnoll", "ghostarmor", "ratman", "skeleton", "golem", "kobold",
                "mud", "earthen", "digger", "slime", "rat", "spider", "warrior", "default"
            };
            int specific = bodyTokens.Intersect(itemTokens).Count(token => !species.Contains(token));
            int extra = itemTokens.Except(bodyTokens).Count(token => !species.Contains(token));
            if (overlap >= 2) return 400 + overlap * 80 + specific * 200 + Math.Min(body.Length, item.Length) - extra * 80;
            if (body.Contains("archer") && item.Contains("bow")) return 220;
            if (body.Contains("sharpshooter") && item.Contains("bow")) return 220;
            if (body.Contains("priest") && (item.Contains("wand") || item.Contains("lamp"))) return 220;
            if (body.Contains("bard") && item.Contains("lute")) return 220;
            if (body.Contains("healer") && item.Contains("wand")) return 220;
            if (body.Contains("hammer") && item.Contains("hammer")) return 700;
            if (body.Contains("mace") && item.Contains("mace")) return 700;
            if (body.Contains("captain") && item.Contains("cutlass")) return 700;
            if (body.Contains("tamer") && item.Contains("whip")) return 700;
            if (body.Contains("theft") && item.Contains("shovel")) return 220;
            if (body.Contains("grenadier") && item.Contains("pipe")) return 180;
            if (body.Contains("destroyer") && item.Contains("greatsword")) return 700;
            if ((body.Contains("shaman") || body.Contains("sorcerer")) && item.Contains("wand")) return 220;
            if (body.Contains("assassin") && item.Contains("sword") && !item.Contains("greatsword")) return 220;
            if (body.Contains("gigant") && item.Contains("blunt")) return 700;
            if (overlap == 1 && (body.Contains("sword") && item.Contains("sword"))) return 220;
            return 0;
        }

        static AnimatorController BuildController(string speciesRoot, string prefix, AnimationClip[] clips)
        {
            var matched = clips.Where(clip =>
            {
                string name = Normalize(clip.name.ToLowerInvariant());
                return name == prefix || name.StartsWith(prefix + "@");
            }).ToArray();
            var idle = FindIdle(matched) ?? FindIdle(clips) ?? matched.FirstOrDefault() ?? clips.FirstOrDefault();
            if (idle == null)
                throw new InvalidOperationException("No animation clips for " + prefix);

            string path = $"{speciesRoot}/Generated/Animators/{prefix}.controller";
            if (AssetDatabase.LoadAssetAtPath<AnimatorController>(path) != null)
                AssetDatabase.DeleteAsset(path);
            var controller = AnimatorController.CreateAnimatorControllerAtPath(path);
            var root = controller.layers[0].stateMachine;
            var idleState = root.AddState(idle.name);
            idleState.motion = idle;
            root.defaultState = idleState;
            return controller;
        }

        static AnimationClip FindIdle(AnimationClip[] clips)
        {
            string[] marks = { "@idle_01", "@idle", "@stand_offensive", "@stand", "@combat_idle", "@wait" };
            foreach (var mark in marks)
            {
                var hit = clips.FirstOrDefault(clip => clip.name.ToLowerInvariant().Contains(mark));
                if (hit != null) return hit;
            }
            return null;
        }

        static GameObject BuildPreviewPrefab(
            GameObject body, GameObject weapon, GameObject shield, AnimatorController controller, string speciesRoot)
        {
            string path = $"{speciesRoot}/Generated/Prefabs/{body.name}_Preview.prefab";
            var root = (GameObject)PrefabUtility.InstantiatePrefab(body);
            if (PrefabUtility.IsPartOfPrefabInstance(root))
                PrefabUtility.UnpackPrefabInstance(root, PrefabUnpackMode.Completely, InteractionMode.AutomatedAction);
            foreach (var transform in root.GetComponentsInChildren<Transform>(true))
                GameObjectUtility.RemoveMonoBehavioursWithMissingScript(transform.gameObject);
            root.name = body.name + "_Preview";

            var animator = root.GetComponent<Animator>() ?? root.GetComponentInChildren<Animator>(true);
            if (animator == null) animator = root.AddComponent<Animator>();
            animator.runtimeAnimatorController = controller;
            animator.applyRootMotion = false;

            RemapRenderers(root, speciesRoot);
            AttachItem(root, weapon, speciesRoot, false);
            AttachItem(root, shield, speciesRoot, true);
            HideFx(root);

            var saved = PrefabUtility.SaveAsPrefabAsset(root, path);
            UnityEngine.Object.DestroyImmediate(root);
            if (saved == null)
                saved = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (saved == null)
                throw new InvalidOperationException("Failed to save preview prefab: " + path);
            return saved;
        }

        static void AttachItem(GameObject root, GameObject item, string speciesRoot, bool shield)
        {
            if (item == null) return;
            string socketName = shield || IsShield(item.name) ? ShieldSocket : HandSocket;
            var socket = FindDeep(root.transform, socketName)
                         ?? (!shield ? FindDeep(root.transform, "_Weapon") : null)
                         ?? FindDeep(root.transform, shield ? "_L Hand" : "_R Hand")
                         ?? FindDeep(root.transform, HandSocket)
                         ?? root.transform;
            var instance = (GameObject)PrefabUtility.InstantiatePrefab(item);
            instance.name = item.name;
            instance.transform.SetParent(socket, false);
            instance.transform.localPosition = Vector3.zero;
            instance.transform.localRotation = Quaternion.identity;
            instance.transform.localScale = Vector3.one;
            foreach (var nested in instance.GetComponentsInChildren<Animator>(true))
                nested.enabled = false;
            RemapRenderers(instance, speciesRoot);
        }

        static void RemapRenderers(GameObject root, string speciesRoot)
        {
            foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                renderer.sharedMaterials = renderer.sharedMaterials
                    .Select(source => GetOrCreatePreviewMaterial(source, speciesRoot))
                    .ToArray();
            }
        }

        internal static Material GetOrCreatePreviewMaterial(Material source, string speciesRoot)
        {
            if (source == null) return null;
            var shader = AssetDatabase.LoadAssetAtPath<Shader>(PreviewShaderPath);
            if (shader == null)
                throw new FileNotFoundException(PreviewShaderPath);

            string sourcePath = AssetDatabase.GetAssetPath(source);
            string guid = AssetDatabase.AssetPathToGUID(sourcePath);
            string safe = string.Concat(source.name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
            string materialPath = $"{speciesRoot}/Generated/Materials/{safe}_{guid.Substring(0, 8)}.mat";
            var preview = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (preview == null)
            {
                preview = new Material(shader) { name = source.name + " (Preview)" };
                AssetDatabase.CreateAsset(preview, materialPath);
            }

            float blend;
            if (FindSerializedFloat(source, "_BlendSrc", out blend) && FindSerializedFloat(source, "_BlendDst", out blend))
            {
                var fx = AssetDatabase.LoadAssetAtPath<Shader>(FxShaderPath);
                if (fx == null)
                    throw new FileNotFoundException(FxShaderPath);
                string previewName = preview.name;
                EditorUtility.CopySerialized(source, preview);
                preview.name = previewName;
                preview.shader = fx;
                EditorUtility.SetDirty(preview);
                return preview;
            }
            if (preview.shader != shader)
                preview.shader = shader;

            bool fromMain = CopyPreviewMaps(source, preview);
            if (preview.HasProperty("_IsDyable")) preview.SetFloat("_IsDyable", 0f);
            if (source.HasProperty("_CullType") && preview.HasProperty("_CullType"))
                preview.SetFloat("_CullType", source.GetFloat("_CullType"));

            float alpha = 1f;
            if (source.HasProperty("_AlphaOverride"))
                alpha = source.GetFloat("_AlphaOverride");
            bool jelly = alpha < 0.99f;
            if (preview.HasProperty("_AlphaOverride"))
                preview.SetFloat("_AlphaOverride", jelly ? 1f : alpha);
            if (preview.HasProperty("_UseBaseMapAlpha"))
                preview.SetFloat("_UseBaseMapAlpha", (jelly || fromMain) ? 0f : 1f);
            if (!jelly && source.HasProperty("_Cutoff") && preview.HasProperty("_Cutoff"))
                preview.SetFloat("_Cutoff", source.GetFloat("_Cutoff"));
            EditorUtility.SetDirty(preview);
            return preview;
        }

        static bool CopyPreviewMaps(Material source, Material preview)
        {
            var albedo = FindSerializedTexture(source, "_BaseMap");
            bool fromMain = false;
            if (albedo.texture == null)
            {
                albedo = FindSerializedTexture(source, "_MainTex");
                fromMain = albedo.texture != null;
            }

            if (preview.HasProperty("_BaseMap"))
            {
                preview.SetTexture("_BaseMap", albedo.texture);
                preview.SetTextureScale("_BaseMap", albedo.scale);
                preview.SetTextureOffset("_BaseMap", albedo.offset);
            }

            Color tint = FindSerializedColor(source, "_TintColor");
            if (fromMain && FindSerializedColorExists(source, "_MainColor"))
                tint = FindSerializedColor(source, "_MainColor");
            if (preview.HasProperty("_TintColor"))
                preview.SetColor("_TintColor", tint);
            return fromMain;
        }

        struct SerializedTex
        {
            public Texture texture;
            public Vector2 scale;
            public Vector2 offset;
        }

        static SerializedTex FindSerializedTexture(Material material, string property)
        {
            var result = new SerializedTex { scale = Vector2.one, offset = Vector2.zero };
            if (material.HasProperty(property))
            {
                result.texture = material.GetTexture(property);
                result.scale = material.GetTextureScale(property);
                result.offset = material.GetTextureOffset(property);
                if (result.texture != null) return result;
            }

            var so = new SerializedObject(material);
            var texEnvs = so.FindProperty("m_SavedProperties.m_TexEnvs");
            if (texEnvs == null || !texEnvs.isArray) return result;
            for (int i = 0; i < texEnvs.arraySize; i++)
            {
                var entry = texEnvs.GetArrayElementAtIndex(i);
                var first = entry.FindPropertyRelative("first");
                if (first == null || first.stringValue != property) continue;
                var second = entry.FindPropertyRelative("second");
                if (second == null) continue;
                var texProp = second.FindPropertyRelative("m_Texture");
                var scaleProp = second.FindPropertyRelative("m_Scale");
                var offsetProp = second.FindPropertyRelative("m_Offset");
                result.texture = texProp != null ? texProp.objectReferenceValue as Texture : null;
                if (scaleProp != null) result.scale = scaleProp.vector2Value;
                if (offsetProp != null) result.offset = offsetProp.vector2Value;
                return result;
            }
            return result;
        }

        static bool FindSerializedFloat(Material material, string property, out float value)
        {
            value = 0f;
            var so = new SerializedObject(material);
            var floats = so.FindProperty("m_SavedProperties.m_Floats");
            if (floats == null || !floats.isArray) return false;
            for (int i = 0; i < floats.arraySize; i++)
            {
                var entry = floats.GetArrayElementAtIndex(i);
                var first = entry.FindPropertyRelative("first");
                if (first == null || first.stringValue != property) continue;
                var second = entry.FindPropertyRelative("second");
                if (second == null) return false;
                value = second.floatValue;
                return true;
            }
            return false;
        }

        static bool FindSerializedColorExists(Material material, string property)
        {
            var so = new SerializedObject(material);
            var colors = so.FindProperty("m_SavedProperties.m_Colors");
            if (colors == null || !colors.isArray) return false;
            for (int i = 0; i < colors.arraySize; i++)
            {
                var first = colors.GetArrayElementAtIndex(i).FindPropertyRelative("first");
                if (first != null && first.stringValue == property) return true;
            }
            return false;
        }

        static Color FindSerializedColor(Material material, string property)
        {
            if (material.HasProperty(property))
                return material.GetColor(property);

            var so = new SerializedObject(material);
            var colors = so.FindProperty("m_SavedProperties.m_Colors");
            if (colors == null || !colors.isArray) return Color.white;
            for (int i = 0; i < colors.arraySize; i++)
            {
                var entry = colors.GetArrayElementAtIndex(i);
                var first = entry.FindPropertyRelative("first");
                if (first == null || first.stringValue != property) continue;
                var second = entry.FindPropertyRelative("second");
                return second != null ? second.colorValue : Color.white;
            }
            return Color.white;
        }

        static void HideFx(GameObject root)
        {
            foreach (var transform in root.GetComponentsInChildren<Transform>(true))
            {
                string name = transform.name.ToLowerInvariant();
                if (name.StartsWith("fx_") || name.Contains("particle") || name.Contains("paticle"))
                    transform.gameObject.SetActive(false);
            }
            foreach (var ps in root.GetComponentsInChildren<ParticleSystem>(true))
                ps.gameObject.SetActive(false);
        }

        static Transform FindDeep(Transform root, string name)
        {
            if (root.name == name) return root;
            foreach (Transform child in root)
            {
                var hit = FindDeep(child, name);
                if (hit != null) return hit;
            }
            return null;
        }

        static void BuildPreviewScene(
            GameObject[] previews, int mainCount, string scenePath, string mainName, string companionName, float spacing)
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var mainParent = new GameObject(mainName);
            var companionParent = companionName != null ? new GameObject(companionName) : null;
            for (int i = 0; i < previews.Length; i++)
            {
                bool companion = i >= mainCount;
                int local = companion ? i - mainCount : i;
                int col = local % Columns;
                int row = local / Columns;
                float z = companion ? -spacing * (3 + row) : spacing * row;
                if (previews[i] == null) continue;
                var parent = companion ? companionParent.transform : mainParent.transform;
                var instance = (GameObject)PrefabUtility.InstantiatePrefab(previews[i], parent);
                if (instance == null)
                    throw new InvalidOperationException("Failed to instantiate " + previews[i].name);
                instance.transform.SetParent(parent, false);
                instance.transform.position = new Vector3(col * spacing, 0f, z);
                AddLabel(instance, previews[i].name.Replace("_Preview", "").Replace("monster_", ""));
            }

            int mainRows = Math.Max(1, (mainCount + Columns - 1) / Columns);
            int companionRows = companionName != null
                ? Math.Max(1, (previews.Length - mainCount + Columns - 1) / Columns)
                : 0;
            float width = (Columns - 1) * spacing;
            float depth = mainRows * spacing + (companionName != null ? 3f * spacing + companionRows * spacing : 0f);
            var camera = new GameObject("Main Camera") { tag = "MainCamera" };
            var cam = camera.AddComponent<Camera>();
            cam.fieldOfView = 55f;
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = 80f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.12f, 0.16f, 0.22f, 1f);
            FrameCamera(cam, mainParent.transform, companionParent != null ? companionParent.transform : null);

            var key = new GameObject("Key Light");
            key.transform.rotation = Quaternion.Euler(40f, 160f, 0f);
            var keyLight = key.AddComponent<Light>();
            keyLight.type = LightType.Directional;
            keyLight.intensity = 1.3f;
            keyLight.color = new Color(1f, 0.9f, 0.82f);
            keyLight.shadows = LightShadows.Soft;

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.35f, 0.4f, 0.5f);
            RenderSettings.ambientEquatorColor = new Color(0.18f, 0.2f, 0.25f);
            RenderSettings.ambientGroundColor = new Color(0.08f, 0.08f, 0.1f);

            var ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
            ground.name = "Preview Ground";
            ground.transform.position = new Vector3(width * 0.5f, -0.06f, companionName != null ? -spacing : mainRows * spacing * 0.5f);
            ground.transform.localScale = new Vector3(width + 4f, 0.08f, depth + 4f);

            EditorSceneManager.SaveScene(scene, scenePath);
            EditorSceneManager.CloseScene(scene, true);
            EditorSceneManager.OpenScene(scenePath);
        }

        static void FrameCamera(Camera cam, Transform mainRoot, Transform companionRoot)
        {
            bool has = false;
            var bounds = new Bounds(Vector3.zero, Vector3.zero);
            void Encapsulate(Transform root)
            {
                if (root == null) return;
                foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
                {
                    if (!renderer.enabled || renderer.GetComponent<TextMesh>() != null) continue;
                    if (!has)
                    {
                        bounds = renderer.bounds;
                        has = true;
                    }
                    else bounds.Encapsulate(renderer.bounds);
                }
            }

            Encapsulate(mainRoot);
            Encapsulate(companionRoot);
            if (!has)
            {
                cam.transform.position = new Vector3(0f, 16f, -24f);
                cam.transform.LookAt(Vector3.zero);
                return;
            }

            var center = bounds.center;
            float radius = Mathf.Max(bounds.extents.magnitude, 4f);
            cam.transform.position = center + new Vector3(0f, radius * 0.85f, -radius * 1.35f);
            cam.transform.LookAt(center + Vector3.up * Mathf.Min(1.2f, radius * 0.05f));
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = Mathf.Max(80f, radius * 6f);
        }

        static void AddLabel(GameObject instance, string text)
        {
            var label = new GameObject("Label");
            label.transform.SetParent(instance.transform, true);
            PlaceLabel(instance, label.transform);
            var mesh = label.AddComponent<TextMesh>();
            mesh.text = text;
            mesh.fontSize = 24;
            mesh.characterSize = 0.022f;
            mesh.anchor = TextAnchor.UpperCenter;
            mesh.alignment = TextAlignment.Center;
            mesh.color = new Color(0.55f, 0.58f, 0.62f, 0.45f);
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf")
                       ?? Resources.GetBuiltinResource<Font>("Arial.ttf");
            if (font != null) mesh.font = font;
        }

        static void PlaceLabel(GameObject instance, Transform label)
        {
            var renderers = instance.GetComponentsInChildren<Renderer>(true);
            bool has = false;
            var bounds = new Bounds(instance.transform.position, Vector3.zero);
            foreach (var renderer in renderers)
            {
                if (!renderer.enabled || renderer.GetComponent<TextMesh>() != null) continue;
                if (!has)
                {
                    bounds = renderer.bounds;
                    has = true;
                }
                else bounds.Encapsulate(renderer.bounds);
            }

            float front = has ? bounds.min.z - 0.75f : instance.transform.position.z - 1.4f;
            label.position = new Vector3(instance.transform.position.x, 0.02f, front);
            label.rotation = Quaternion.Euler(18f, 180f, 0f);
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace('\\', '/');
            if (!AssetDatabase.IsValidFolder(parent)) EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }
    }
}
