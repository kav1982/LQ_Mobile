using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Characters.Monsters.Editor;
using UnityEditor;
using UnityEditor.Animations;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;

namespace Characters.Monsters.Goblin.Editor
{
    public static class GoblinPreviewBuilder
    {
        const string GoblinRoot = "Assets/Characters/Monsters/Goblin";
        const string PigRoot = "Assets/Characters/Monsters/GoblinPig";
        const string ScenePath = GoblinRoot + "/Scenes/Goblin_Preview.unity";
        const string OldScenePath = GoblinRoot + "/Scenes/Goblin_Default_Warrior_Preview.unity";
        const string HandSocket = "_HandtoolR";
        const string ShieldSocket = "_HandtoolL";
        const float Cell = 2.4f;
        const int Columns = 7;

        [MenuItem("Tools/Characters/Monsters/Build Goblin Preview")]
        public static void BuildAll()
        {
            EnsureFolder(GoblinRoot + "/Generated/Prefabs");
            EnsureFolder(GoblinRoot + "/Generated/Materials");
            EnsureFolder(GoblinRoot + "/Generated/Animators");
            EnsureFolder(GoblinRoot + "/Scenes");
            EnsureFolder(PigRoot + "/Generated/Prefabs");
            EnsureFolder(PigRoot + "/Generated/Materials");
            EnsureFolder(PigRoot + "/Generated/Animators");

            var goblinClips = LoadClips(GoblinRoot + "/Source/patchableassets/animation/monster/goblin");
            var pigClips = LoadClips(PigRoot + "/Source/patchableassets/animation/monster/pig");
            var prefixes = ClipPrefixes(goblinClips.Concat(pigClips));
            var items = LoadItems();
            var goblins = LoadBodies(GoblinRoot + "/Source/patchableassets/character/monster", "monster_goblin", excludePig: true);
            var pigs = LoadBodies(PigRoot + "/Source/patchableassets/character/monster", "monster_goblinpig", excludePig: false);
            if (goblins.Length == 0)
                throw new InvalidOperationException("No goblin body prefabs under Goblin/Source.");

            var controllers = new Dictionary<string, AnimatorController>(StringComparer.OrdinalIgnoreCase);
            var previews = new List<GameObject>();
            var report = new List<string>();

            foreach (var body in goblins.Concat(pigs))
            {
                string stem = body.name;
                bool isPig = stem.ToLowerInvariant().Contains("goblinpig");
                string prefix = PickClipPrefix(stem, prefixes);
                var clips = isPig ? pigClips : goblinClips;
                if (!controllers.TryGetValue(prefix ?? "", out var controller) && prefix != null)
                {
                    string root = isPig ? PigRoot : GoblinRoot;
                    controller = BuildController(root, prefix, clips);
                    controllers[prefix] = controller;
                }

                var weapon = isPig ? null : PickWeapon(stem, items);
                var preview = BuildPreviewPrefab(body, weapon, controller, isPig ? PigRoot : GoblinRoot);
                previews.Add(preview);
                report.Add($"{stem} clip={prefix ?? "-"} weapon={(weapon != null ? weapon.name : "-")}");
            }

            BuildPreviewScene(previews.ToArray(), goblins.Length);
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(OldScenePath) != null)
                AssetDatabase.DeleteAsset(OldScenePath);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log($"[GoblinPreview] {previews.Count} prefabs, {controllers.Count} controllers, scene {ScenePath}\n" + string.Join("\n", report));
        }

        static GameObject[] LoadBodies(string folder, string prefix, bool excludePig)
        {
            if (!AssetDatabase.IsValidFolder(folder)) return new GameObject[0];
            return AssetDatabase.FindAssets("t:Prefab", new[] { folder })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(path =>
                {
                    string unix = path.Replace('\\', '/').ToLowerInvariant();
                    if (unix.Contains("/item/") || unix.Contains("/fbx/")) return false;
                    string name = Path.GetFileNameWithoutExtension(path).ToLowerInvariant();
                    if (!name.StartsWith(prefix)) return false;
                    if (excludePig && name.Contains("goblinpig")) return false;
                    return true;
                })
                .Select(AssetDatabase.LoadAssetAtPath<GameObject>)
                .Where(prefab => prefab != null)
                .OrderBy(prefab => prefab.name)
                .ToArray();
        }

        static GameObject[] LoadItems()
        {
            string folder = GoblinRoot + "/Source/patchableassets/character/monster/item";
            if (!AssetDatabase.IsValidFolder(folder)) return new GameObject[0];
            return AssetDatabase.FindAssets("t:Prefab", new[] { folder })
                .Select(AssetDatabase.GUIDToAssetPath)
                .Where(path => Path.GetFileName(path).ToLowerInvariant().Contains("goblin"))
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
                string name = clip.name.ToLowerInvariant();
                int at = name.IndexOf('@');
                if (at > 0) set.Add(name.Substring(0, at));
            }
            return set;
        }

        static string StripSkin(string key)
        {
            string[] suffixes =
            {
                "_asparagus_gatheringdungeon",
                "_woodworker_gatheringdungeon",
                "_gatheringdungeon",
                "_deep",
                "_abyss",
                "_shade"
            };
            foreach (var suffix in suffixes)
            {
                if (key.EndsWith(suffix, StringComparison.OrdinalIgnoreCase))
                    return key.Substring(0, key.Length - suffix.Length);
            }
            return key;
        }

        static string PickClipPrefix(string stem, HashSet<string> prefixes)
        {
            string key = stem.ToLowerInvariant();
            if (key.StartsWith("monster_")) key = key.Substring("monster_".Length);
            var candidates = new List<string>();
            void Add(string value)
            {
                if (!string.IsNullOrEmpty(value) && !candidates.Contains(value))
                    candidates.Add(value);
            }

            if (key.StartsWith("goblinpig"))
            {
                if (key.Contains("giant"))
                {
                    Add("goblinpig_default_giant");
                    Add("goblinpig_giant");
                }
                Add("goblinpig_default");
                Add("goblinpig_giant");
            }
            else
            {
                string stripped = StripSkin(key);
                Add(stripped);
                Add(key);
                if (stripped.Contains("warriorboss")) Add("goblin_boss_warrior");
                if (stripped.Contains("archerboss")) Add("goblin_boss_archer");
                if (stripped.StartsWith("goblin_archer")) Add("goblin_default_archer");
                if (stripped.Contains("loggercaptain")) Add("goblin_default_captain");
                if (stripped.StartsWith("goblin_warrior")) Add("goblin_default_warrior");
                if (stripped.Contains("desert_archer") || stripped.Contains("frozen_archer") || stripped.Contains("swamp_archer"))
                    Add("goblin_default_archer");
                if (stripped.Contains("desert_warrior") || stripped.Contains("frozen_warrior") || stripped.Contains("swamp_warrior"))
                    Add("goblin_default_warrior");
                if (stripped.Contains("frozen_rider")) Add("goblin_default_rider");
                if (stripped.Contains("elitearcher")) Add("goblin_default_archer");
                if (stripped.Contains("scout") || stripped.Contains("tamer") || stripped.Contains("treasure"))
                    Add("goblin_default_warrior");
                if (stripped.Contains("thrower")) Add("goblin_thrower");
                if (stripped.Contains("chef")) Add("goblin_default_chef");
                if (stripped.Contains("armored")) Add("goblin_default_armored");
                if (stripped.Contains("captain")) Add("goblin_default_captain");
                if (stripped.Contains("rider")) Add("goblin_default_rider");
                if (stripped.Contains("naozone")) Add("goblin_naozone_warrior");
                if (stripped.Contains("archer")) Add("goblin_default_archer");
                if (stripped.Contains("warrior")) Add("goblin_default_warrior");
                Add("goblin_default");
            }

            foreach (var candidate in candidates)
            {
                if (prefixes.Contains(candidate)) return candidate;
            }
            return prefixes.Count > 0 ? prefixes.First() : null;
        }

        static GameObject PickWeapon(string stem, GameObject[] items)
        {
            string key = stem.ToLowerInvariant();
            if (key.StartsWith("monster_")) key = key.Substring("monster_".Length);
            if (key.Contains("thrower")) return null;

            GameObject best = null;
            int bestScore = 0;
            foreach (var item in items)
            {
                int score = ScoreWeapon(key, item.name.ToLowerInvariant());
                if (score > bestScore)
                {
                    bestScore = score;
                    best = item;
                }
            }
            return bestScore >= 80 ? best : null;
        }

        static int ScoreWeapon(string bodyKey, string itemName)
        {
            string body = StripSkin(bodyKey);
            if (itemName.Contains(bodyKey)) return 1000 + bodyKey.Length;
            if (body != bodyKey && itemName.Contains(body)) return 800 + body.Length;
            if (body.Contains("warriorboss") && itemName.Contains("warriorboss"))
                return body.Contains("abyss") == itemName.Contains("abyss") ? 700 : 580;
            if (body.Contains("archerboss") && itemName.Contains("archerboss")) return 700;
            if (body.Contains("loggercaptain") && itemName.Contains("loggercaptain")) return 700;
            if (body.Contains("warrior_logger") && itemName.Contains("warrior_logger") && !itemName.Contains("captain"))
                return 700;
            if (body.Contains("archer_logger") && itemName.Contains("archer_logger")) return 700;
            if (body.Contains("masked") && itemName.Contains("masked")) return 700;
            if (body.Contains("wilderness") && itemName.Contains("wilderness")) return 700;
            if (body.Contains("demention_black") && itemName.Contains("demention_black")) return 700;
            if (body.Contains("demention_red") && itemName.Contains("demention_red")) return 700;
            if (body.Contains("naozone") && itemName.Contains("naozone")) return 700;
            if (body.Contains("unskill") && itemName.Contains("unskill")) return 700;
            if (body.Contains("chef") && itemName.Contains("chef"))
                return body.Contains("asparagus") == itemName.Contains("asparagus") ? 700 : 580;
            if (body.Contains("tamer") && itemName.Contains("tamer")) return 700;
            if (body.Contains("scout") && itemName.Contains("scout")) return 700;
            if (body.Contains("rider") && itemName.Contains("rider"))
                return body.Contains("frozen") == itemName.Contains("frozen") ? 700 : 580;
            if (body.Contains("desert_warrior") && itemName.Contains("desert_warrior")) return 700;
            if (body.Contains("desert_archer") && itemName.Contains("desert_archer")) return 700;
            if (body.Contains("swamp_warrior") && itemName.Contains("swamp_warrior")) return 700;
            if (body.Contains("swamp_archer") && itemName.Contains("swamp_archer")) return 700;
            if (body.Contains("frozen_archer") && itemName.Contains("frozen_archer")) return 700;
            if (body.Contains("frozen_warrior") && itemName.Contains("frozen_warrior")) return 700;
            if (body.Contains("armored") && (itemName.Contains("sheild") || itemName.Contains("shield"))) return 650;
            if (body.Contains("captain") && !body.Contains("logger") && itemName.Contains("goblincaptain")) return 650;
            bool boss = body.Contains("boss");
            if (!boss && body.Contains("archer") && itemName.Contains("goblinbow_00")) return 120;
            if (!boss && body.Contains("warrior") && !body.Contains("logger") && itemName.Contains("goblinclub_00"))
                return 100;
            if (body.Contains("elite") && !body.Contains("archer") && itemName.Contains("goblinclub_00")) return 100;
            if (body.Contains("treasure") && itemName.Contains("goblinclub_00")) return 80;
            return 0;
        }

        static AnimatorController BuildController(string speciesRoot, string prefix, AnimationClip[] clips)
        {
            var matched = clips.Where(clip =>
            {
                string name = clip.name.ToLowerInvariant();
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

        static GameObject BuildPreviewPrefab(GameObject body, GameObject weapon, AnimatorController controller, string speciesRoot)
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

            if (weapon != null)
            {
                bool shield = weapon.name.ToLowerInvariant().Contains("sheild") || weapon.name.ToLowerInvariant().Contains("shield");
                string socketName = shield ? ShieldSocket : HandSocket;
                var socket = FindDeep(root.transform, socketName) ?? FindDeep(root.transform, HandSocket) ?? root.transform;
                var instance = (GameObject)PrefabUtility.InstantiatePrefab(weapon);
                instance.name = weapon.name;
                instance.transform.SetParent(socket, false);
                instance.transform.localPosition = Vector3.zero;
                instance.transform.localRotation = Quaternion.identity;
                instance.transform.localScale = Vector3.one;
                foreach (var nested in instance.GetComponentsInChildren<Animator>(true))
                    nested.enabled = false;
                RemapRenderers(instance, speciesRoot);
            }

            HideFx(root);

            var saved = PrefabUtility.SaveAsPrefabAsset(root, path);
            UnityEngine.Object.DestroyImmediate(root);
            if (saved == null)
                saved = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (saved == null)
                throw new InvalidOperationException("Failed to save preview prefab: " + path);
            return saved;
        }

        static void RemapRenderers(GameObject root, string speciesRoot)
        {
            foreach (var renderer in root.GetComponentsInChildren<Renderer>(true))
            {
                renderer.sharedMaterials = renderer.sharedMaterials
                    .Select(source => MonsterPreviewBuilder.GetOrCreatePreviewMaterial(source, speciesRoot))
                    .ToArray();
            }
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

        static void BuildPreviewScene(GameObject[] previews, int goblinCount)
        {
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);

            var goblinParent = new GameObject("Goblins");
            var pigParent = new GameObject("GoblinPigs");
            for (int i = 0; i < previews.Length; i++)
            {
                bool pig = i >= goblinCount;
                int local = pig ? i - goblinCount : i;
                int col = local % Columns;
                int row = local / Columns;
                float z = pig ? -Cell * (3 + row) : Cell * row;
                if (previews[i] == null) continue;
                var instance = (GameObject)PrefabUtility.InstantiatePrefab(previews[i], pig ? pigParent.transform : goblinParent.transform);
                if (instance == null)
                    throw new InvalidOperationException("Failed to instantiate " + previews[i].name);
                instance.transform.SetParent(pig ? pigParent.transform : goblinParent.transform, false);
                instance.transform.position = new Vector3(col * Cell, 0f, z);
                AddLabel(instance, previews[i].name.Replace("_Preview", "").Replace("monster_", ""));
            }

            int goblinRows = Math.Max(1, (goblinCount + Columns - 1) / Columns);
            int pigRows = Math.Max(1, (previews.Length - goblinCount + Columns - 1) / Columns);
            float width = (Columns - 1) * Cell;
            float depth = goblinRows * Cell + 3f * Cell + pigRows * Cell;
            var camera = new GameObject("Main Camera") { tag = "MainCamera" };
            camera.transform.position = new Vector3(width * 0.5f, 16f, -24f);
            camera.transform.LookAt(new Vector3(width * 0.5f, 0.3f, Cell));
            var cam = camera.AddComponent<Camera>();
            cam.fieldOfView = 55f;
            cam.nearClipPlane = 0.05f;
            cam.farClipPlane = 80f;
            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = new Color(0.12f, 0.16f, 0.22f, 1f);

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
            ground.transform.position = new Vector3(width * 0.5f, -0.06f, -Cell);
            ground.transform.localScale = new Vector3(width + 4f, 0.08f, depth + 4f);

            EditorSceneManager.SaveScene(scene, ScenePath);
            EditorSceneManager.CloseScene(scene, true);
            EditorSceneManager.OpenScene(ScenePath);
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
            var font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf") ?? Resources.GetBuiltinResource<Font>("Arial.ttf");
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
