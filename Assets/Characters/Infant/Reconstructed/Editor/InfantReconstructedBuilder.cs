using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Characters.Infant.Editor
{
    public static class InfantReconstructedBuilder
    {
        const string Root = "Assets/Characters/Infant";
        const string SourceRoot = Root + "/Source/patchableassets";
        const string ReconstructedRoot = Root + "/Reconstructed";
        const string DefaultInfantMouthPath = SourceRoot + "/character/player/human/facial/customize/infant/mouth/Infant_Lips_00.png";
        const string MaleEyeBallPath = SourceRoot + "/character/player/human/facial/customize/infant/textures/Infant_EyeBall_M_00_DyeMap.png";
        const string PiratesEpicAShoesMaterialName = "Male_PiratesEpicA_Shoes_00";
        const string PiratesEpicAOnePieceMaterialName = "Male_PiratesEpicA_OnePiece_00";

        static readonly Dictionary<string, string> ShaderMap = new Dictionary<string, string>
        {
            { "MMN/CH/Standard", "Characters/Infant/Reconstructed/Standard" },
            { "MMN/CH/Skin_Body", "Characters/Infant/Reconstructed/SkinBody" },
            { "MMN/CH/Skin_Face", "Characters/Infant/Reconstructed/SkinFace" },
            { "MMN/CH/Eye_Pupil", "Characters/Infant/Reconstructed/EyePupil" },
            { "MMN/CH/Eye_Base", "Characters/Infant/Reconstructed/EyeBase" },
            { "MMN/CH/Eye_Emotion", "Characters/Infant/Reconstructed/EyeEmotion" },
            { "MMN/CH/Eye_Shade_Highlight", "Characters/Infant/Reconstructed/EyeShadeHighlight" },
            { "MMN/CH/Hair_Shadow", "Characters/Infant/Reconstructed/HairShadow" },
            { "MMN/BG/SimpleLit", "Characters/Infant/Reconstructed/SimpleLit" },
        };

        sealed class SampleDefinition
        {
            public string Id;
            public string OutputRoot;
            public string MaterialsRoot;
            public string PrefabPath;
            public string ScenePath;
            public string RootName;
            public bool IsMale;
            public string BodyPath;
            public string HeadPath;
            public string EyePath;
            public string HairPath;
            public string OutfitPath;
            public string ShoesPath;
            public bool UseSourceBodyCuttingGuides;
        }

        sealed class OutfitVariantDefinition
        {
            public string Id;
            public string OutfitPath;
            public string HeadPath;
            public string EyePath;
            public string HairPath;
            public string ShoesPath;
        }

        enum BodySegment
        {
            None,
            LeftArm,
            RightArm,
            LeftLeg,
            RightLeg,
        }

        readonly struct BodyCutGuide
        {
            public readonly Vector3 Point;
            public readonly Vector3 KeepDirection;

            public BodyCutGuide(Vector3 point, Vector3 keepDirection)
            {
                Point = point;
                KeepDirection = keepDirection;
            }

            public bool Keeps(Vector3 point)
            {
                return Vector3.Dot(point - Point, KeepDirection) >= 0f;
            }
        }

        static readonly Dictionary<Material, Material> MaterialCache = new Dictionary<Material, Material>();

        [MenuItem("Tools/Characters/Infant/Build Reconstructed Sample")]
        public static void BuildSample()
        {
            var female = CreateFemaleDefinition(ReconstructedRoot + "/Female");
            var male = CreateMaleDefinition(ReconstructedRoot + "/Male");
            var legacyFemale = CreateFemaleDefinition(ReconstructedRoot);
            legacyFemale.Id = "LegacyFemale";
            legacyFemale.RootName = "Infant_Cute_01_Reconstructed";
            legacyFemale.PrefabPath = ReconstructedRoot + "/Prefabs/Infant_Cute_01_Reconstructed.prefab";
            legacyFemale.ScenePath = ReconstructedRoot + "/Scenes/InfantCharacterReconstructed.unity";

            BuildSample(female);
            BuildMaleSample(male);
            BuildSample(legacyFemale);

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[InfantReconstructed] build complete: Female, Male and legacy compatibility assets");
        }

        [MenuItem("Tools/Characters/Infant/Build Male Reconstructed Outfits")]
        public static void BuildMaleOutfits()
        {
            BuildMaleOutfitGallery(CreateMaleDefinition(ReconstructedRoot + "/Male"));
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[InfantReconstructed] Male outfit gallery build complete");
        }

        [MenuItem("Tools/Characters/Infant/Build Male PiratesEpicA Outfit")]
        public static void BuildMalePiratesEpicAOutfit()
        {
            var male = CreateMaleDefinition(ReconstructedRoot + "/Male");
            var variant = GetMaleOutfitVariants().Single(item => item.Id == "PiratesEpicA");
            BuildPrefab(CreateMaleVariantDefinition(male, variant));
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            Debug.Log("[InfantReconstructed] Male PiratesEpicA outfit build complete");
        }

        static SampleDefinition CreateFemaleDefinition(string outputRoot)
        {
            return new SampleDefinition
            {
                Id = "Female",
                OutputRoot = outputRoot,
                MaterialsRoot = outputRoot + "/Materials",
                PrefabPath = outputRoot + "/Prefabs/Infant_Cute_01_Female_Reconstructed.prefab",
                ScenePath = outputRoot + "/Scenes/InfantFemaleReconstructed.unity",
                RootName = "Infant_Cute_01_Female_Reconstructed",
                BodyPath = Source("character/player/human/fbx/Infant_Body_00.prefab"),
                HeadPath = Source("character/player/human/facial/customize/infant/head/Infant_Head_F_Default_00.prefab"),
                EyePath = Source("character/player/human/facial/customize/infant/eye/Infant_Eye_08.prefab"),
                HairPath = Source("character/player/human/fbx/human/infant/hair/Infant_Hair_Twintail_03.prefab"),
                OutfitPath = Source("character/player/human/fbx/human/infant/onepiece/Infant_Kindergarten_F_OnePiece_00.prefab"),
                ShoesPath = Source("character/player/human/fbx/human/infant/shoes/Infant_Kindergarten_Shoes_00.prefab"),
            };
        }

        static SampleDefinition CreateMaleDefinition(string outputRoot)
        {
            return new SampleDefinition
            {
                Id = "Male",
                OutputRoot = outputRoot,
                MaterialsRoot = outputRoot + "/Materials",
                PrefabPath = outputRoot + "/Prefabs/Infant_Cute_01_Male_Reconstructed.prefab",
                ScenePath = outputRoot + "/Scenes/InfantMaleReconstructed.unity",
                RootName = "Infant_Cute_01_Male_Reconstructed",
                IsMale = true,
                BodyPath = Source("character/player/human/fbx/InfantMale_Body_00.prefab"),
                HeadPath = Source("character/player/human/facial/customize/infant/head/Infant_Head_Default_00.prefab"),
                EyePath = Source("character/player/human/facial/customize/infant/eye/Infant_Eye_Default_00.prefab"),
                HairPath = Source("character/player/human/fbx/human/infant/hair/Infant_Hair_Dandy_00.prefab"),
                OutfitPath = Source("character/player/human/fbx/human/infant/onepiece/Infant_Kindergarten_M_OnePiece_00.prefab"),
                ShoesPath = Source("character/player/human/fbx/human/infant/shoes/Infant_Kindergarten_Shoes_00.prefab"),
            };
        }

        static void BuildSample(SampleDefinition definition)
        {
            EnsureFolder(definition.MaterialsRoot);
            EnsureFolder(definition.OutputRoot + "/Prefabs");
            EnsureFolder(definition.OutputRoot + "/Scenes");
            EnsureFolder(definition.OutputRoot + "/Previews");

            var prefab = BuildPrefab(definition);
            BuildScene(definition, prefab);
        }

        static void BuildMaleSample(SampleDefinition definition)
        {
            EnsureFolder(definition.MaterialsRoot);
            EnsureFolder(definition.OutputRoot + "/Prefabs");
            EnsureFolder(definition.OutputRoot + "/Prefabs/Outfits");
            EnsureFolder(definition.OutputRoot + "/Scenes");
            EnsureFolder(definition.OutputRoot + "/Previews");

            BuildPrefab(definition);
            BuildMaleOutfitGallery(definition);
        }

        static void BuildMaleOutfitGallery(SampleDefinition definition)
        {
            EnsureFolder(definition.MaterialsRoot);
            EnsureFolder(definition.OutputRoot + "/Prefabs");
            EnsureFolder(definition.OutputRoot + "/Prefabs/Outfits");
            EnsureFolder(definition.OutputRoot + "/Scenes");
            EnsureFolder(definition.OutputRoot + "/Previews");

            var prefabs = new List<GameObject>();
            foreach (var variant in GetMaleOutfitVariants())
            {
                var variantDefinition = CreateMaleVariantDefinition(definition, variant);
                prefabs.Add(BuildPrefab(variantDefinition));
            }

            BuildScene(definition, prefabs);
        }

        static OutfitVariantDefinition[] GetMaleOutfitVariants()
        {
            return new[]
            {
                new OutfitVariantDefinition
                {
                    Id = "ChristmasOutfit",
                    OutfitPath = Source("character/player/human/infant/onepiece/Infant_ChristmasOutfit_M_OnePiece_00.prefab"),
                    HeadPath = Source("character/player/human/facial/customize/infant/head/Infant_Head_Default_00.prefab"),
                    EyePath = Source("character/player/human/facial/customize/infant/eye/Infant_Eye_Default_00.prefab"),
                    HairPath = Source("character/player/human/fbx/human/infant/hair/Infant_Hair_Dandy_00.prefab"),
                    ShoesPath = Source("character/player/human/fbx/human/infant/shoes/Infant_ChristmasOutfit_Shoes_00.prefab"),
                },
                new OutfitVariantDefinition
                {
                    Id = "PiratesEpicA",
                    OutfitPath = Source("character/player/human/infant/onepiece/Infant_PiratesEpicA_M_OnePiece_00.prefab"),
                    HeadPath = Source("character/player/human/facial/customize/infant/head/Infant_HeadB_00.prefab"),
                    EyePath = Source("character/player/human/facial/customize/infant/eye/Infant_Eye_25.prefab"),
                    HairPath = Source("character/player/human/fbx/human/infant/hair/Infant_Hair_GreatSwordWarriorM_00.prefab"),
                    ShoesPath = Source("character/player/human/fbx/human/infant/shoes/Infant_PiratesEpicA_M_Shoes_00.prefab"),
                },
                new OutfitVariantDefinition
                {
                    Id = "Sanrio01",
                    OutfitPath = Source("character/player/human/infant/onepiece/Infant_Sanrio_M_OnePiece_01.prefab"),
                    HeadPath = Source("character/player/human/facial/customize/infant/head/Infant_HeadD_00.prefab"),
                    EyePath = Source("character/player/human/facial/customize/infant/eye/Infant_Eye_40.prefab"),
                    HairPath = Source("character/player/human/fbx/human/infant/hair/Infant_Hair_ArcherM_00.prefab"),
                    ShoesPath = Source("character/player/human/fbx/human/infant/shoes/Infant_Sanrio_M_Shoes_01.prefab"),
                },
            };
        }

        static SampleDefinition CreateMaleVariantDefinition(SampleDefinition baseDefinition, OutfitVariantDefinition variant)
        {
            return new SampleDefinition
            {
                Id = baseDefinition.Id + variant.Id,
                OutputRoot = baseDefinition.OutputRoot,
                MaterialsRoot = baseDefinition.MaterialsRoot,
                PrefabPath = baseDefinition.OutputRoot + "/Prefabs/Outfits/Infant_Cute_01_Male_" + variant.Id + "_Reconstructed.prefab",
                ScenePath = baseDefinition.ScenePath,
                RootName = "Infant_Cute_01_Male_" + variant.Id + "_Reconstructed",
                IsMale = true,
                UseSourceBodyCuttingGuides = true,
                BodyPath = baseDefinition.BodyPath,
                HeadPath = variant.HeadPath,
                EyePath = variant.EyePath,
                HairPath = variant.HairPath,
                OutfitPath = variant.OutfitPath,
                ShoesPath = variant.ShoesPath,
            };
        }

        static GameObject BuildPrefab(SampleDefinition definition)
        {
            MaterialCache.Clear();
            var root = new GameObject(definition.RootName);
            try
            {
                AddPart(root.transform, "Body", definition.BodyPath, definition);
                AddPart(root.transform, "Head", definition.HeadPath, definition);
                AddPart(root.transform, "Eye", definition.EyePath, definition);
                AddPart(root.transform, "Hair", definition.HairPath, definition);
                AddPart(root.transform, "OnePiece", definition.OutfitPath, definition);
                AddPart(root.transform, "Shoes", definition.ShoesPath, definition);
                int removedMissingScripts = 0;
                foreach (var child in root.GetComponentsInChildren<Transform>(true))
                    removedMissingScripts += GameObjectUtility.RemoveMonoBehavioursWithMissingScript(child.gameObject);
                if (removedMissingScripts > 0)
                    Debug.Log("[InfantReconstructed] removed " + removedMissingScripts + " missing source scripts from " + definition.RootName);
                return PrefabUtility.SaveAsPrefabAsset(root, definition.PrefabPath);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(root);
            }
        }

        static void AddPart(Transform parent, string label, string path, SampleDefinition definition)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null) throw new InvalidOperationException("Source prefab is missing: " + path);

            var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefab);
            instance.name = label + " - " + prefab.name;
            instance.transform.SetParent(parent, false);

            foreach (var animator in instance.GetComponentsInChildren<Animator>(true))
                animator.enabled = false;

            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
            {
                renderer.sharedMaterials = renderer.sharedMaterials.Select(material => GetOrCreateMaterial(material, definition)).ToArray();
                if (definition.UseSourceBodyCuttingGuides &&
                    label == "Body" &&
                    renderer.name == "Mesh_Skin_Body")
                {
                    var skinnedRenderer = renderer as SkinnedMeshRenderer;
                    if (skinnedRenderer == null)
                        throw new InvalidOperationException("Expected a SkinnedMeshRenderer for the base body.");
                    skinnedRenderer.sharedMesh = GetOrCreateSourceGuidedBodyMesh(skinnedRenderer, definition);
                }
                if (ShouldHideInNormalPreview(renderer.name))
                {
                    renderer.gameObject.SetActive(false);
                }
            }
        }

        static Mesh GetOrCreateSourceGuidedBodyMesh(SkinnedMeshRenderer renderer, SampleDefinition definition)
        {
            Mesh source = renderer.sharedMesh;
            if (source == null) throw new InvalidOperationException("Base body mesh is missing.");

            var outfit = LoadSourcePrefab(definition.OutfitPath);
            var shoes = LoadSourcePrefab(definition.ShoesPath);
            var outfitGuides = LoadBodyCutGuides(outfit, false);
            var shoeGuides = LoadBodyCutGuides(shoes, true);
            BoneWeight[] boneWeights = source.boneWeights;
            Vector3[] vertices = source.vertices;
            var generated = UnityEngine.Object.Instantiate(source);
            generated.name = definition.Id + "_BodySourceCut";
            generated.subMeshCount = source.subMeshCount;

            for (int subMeshIndex = 0; subMeshIndex < source.subMeshCount; subMeshIndex++)
            {
                int[] sourceTriangles = source.GetTriangles(subMeshIndex);
                var visibleTriangles = new List<int>(sourceTriangles.Length);
                for (int i = 0; i < sourceTriangles.Length; i += 3)
                {
                    int a = sourceTriangles[i];
                    int b = sourceTriangles[i + 1];
                    int c = sourceTriangles[i + 2];
                    BodySegment segment = GetTriangleBodySegment(renderer.bones, boneWeights[a], boneWeights[b], boneWeights[c]);
                    if (!outfitGuides.TryGetValue(segment, out BodyCutGuide outfitGuide)) continue;

                    Vector3 center = (vertices[a] + vertices[b] + vertices[c]) / 3f;
                    if (!outfitGuide.Keeps(center)) continue;

                    if (TryGetFootSegment(segment, out BodySegment footSegment) &&
                        shoeGuides.TryGetValue(footSegment, out BodyCutGuide shoeGuide) &&
                        !shoeGuide.Keeps(center))
                        continue;

                    visibleTriangles.Add(a);
                    visibleTriangles.Add(b);
                    visibleTriangles.Add(c);
                }

                generated.SetTriangles(visibleTriangles, subMeshIndex, false);
            }

            generated.RecalculateBounds();
            EnsureFolder(definition.OutputRoot + "/Meshes");
            string meshPath = definition.OutputRoot + "/Meshes/" + definition.Id + "_BodySourceCut.asset";
            var mesh = AssetDatabase.LoadAssetAtPath<Mesh>(meshPath);
            if (mesh == null)
            {
                AssetDatabase.CreateAsset(generated, meshPath);
                return generated;
            }

            EditorUtility.CopySerialized(generated, mesh);
            mesh.name = generated.name;
            EditorUtility.SetDirty(mesh);
            UnityEngine.Object.DestroyImmediate(generated);
            return mesh;
        }

        static GameObject LoadSourcePrefab(string path)
        {
            var prefab = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (prefab == null) throw new InvalidOperationException("Source prefab is missing: " + path);
            return prefab;
        }

        static Dictionary<BodySegment, BodyCutGuide> LoadBodyCutGuides(GameObject prefab, bool feet)
        {
            var renderers = prefab.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            var result = new Dictionary<BodySegment, BodyCutGuide>();
            AddBodyCutGuide(result, renderers, feet ? "LFoot" : "LArm", feet ? BodySegment.LeftLeg : BodySegment.LeftArm);
            AddBodyCutGuide(result, renderers, feet ? "RFoot" : "RArm", feet ? BodySegment.RightLeg : BodySegment.RightArm);
            if (!feet)
            {
                AddBodyCutGuide(result, renderers, "LLeg", BodySegment.LeftLeg);
                AddBodyCutGuide(result, renderers, "RLeg", BodySegment.RightLeg);
            }

            return result;
        }

        static void AddBodyCutGuide(
            IDictionary<BodySegment, BodyCutGuide> result,
            IEnumerable<SkinnedMeshRenderer> renderers,
            string suffix,
            BodySegment segment)
        {
            var slicer = renderers.FirstOrDefault(renderer => renderer.name == "Mesh_SP_" + suffix);
            var boundary = renderers.FirstOrDefault(renderer => renderer.name == "Mesh_BP_" + suffix);
            if (slicer == null || slicer.sharedMesh == null || boundary == null || boundary.sharedMesh == null)
                throw new InvalidOperationException("Source cutting guide pair is missing: " + suffix);

            Vector3 slicerCenter = slicer.sharedMesh.bounds.center;
            Vector3 boundaryCenter = boundary.sharedMesh.bounds.center;
            // The original MorphableMesh pipeline cuts at SP and uses BP as the retained-side boundary.
            Vector3 keepDirection = boundaryCenter - slicerCenter;
            if (keepDirection.sqrMagnitude <= Mathf.Epsilon)
                throw new InvalidOperationException("Source cutting guide pair has no direction: " + suffix);

            result.Add(segment, new BodyCutGuide(slicerCenter, keepDirection.normalized));
        }

        static BodySegment GetTriangleBodySegment(
            Transform[] bones,
            BoneWeight a,
            BoneWeight b,
            BoneWeight c)
        {
            float leftArm = 0f;
            float rightArm = 0f;
            float leftLeg = 0f;
            float rightLeg = 0f;
            AddBodySegmentWeights(bones, a, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
            AddBodySegmentWeights(bones, b, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
            AddBodySegmentWeights(bones, c, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);

            float max = Mathf.Max(leftArm, rightArm, leftLeg, rightLeg);
            if (max <= 0f) return BodySegment.None;
            if (max == leftArm) return BodySegment.LeftArm;
            if (max == rightArm) return BodySegment.RightArm;
            if (max == leftLeg) return BodySegment.LeftLeg;
            return BodySegment.RightLeg;
        }

        static void AddBodySegmentWeights(
            Transform[] bones,
            BoneWeight weight,
            ref float leftArm,
            ref float rightArm,
            ref float leftLeg,
            ref float rightLeg)
        {
            AddBodySegmentWeight(bones, weight.boneIndex0, weight.weight0, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
            AddBodySegmentWeight(bones, weight.boneIndex1, weight.weight1, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
            AddBodySegmentWeight(bones, weight.boneIndex2, weight.weight2, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
            AddBodySegmentWeight(bones, weight.boneIndex3, weight.weight3, ref leftArm, ref rightArm, ref leftLeg, ref rightLeg);
        }

        static void AddBodySegmentWeight(
            Transform[] bones,
            int boneIndex,
            float weight,
            ref float leftArm,
            ref float rightArm,
            ref float leftLeg,
            ref float rightLeg)
        {
            if (weight <= 0f || boneIndex < 0 || boneIndex >= bones.Length || bones[boneIndex] == null) return;

            switch (GetBodySegment(bones[boneIndex].name))
            {
                case BodySegment.LeftArm:
                    leftArm += weight;
                    break;
                case BodySegment.RightArm:
                    rightArm += weight;
                    break;
                case BodySegment.LeftLeg:
                    leftLeg += weight;
                    break;
                case BodySegment.RightLeg:
                    rightLeg += weight;
                    break;
            }
        }

        static BodySegment GetBodySegment(string boneName)
        {
            bool isLeft = boneName.StartsWith("_L ", StringComparison.Ordinal);
            bool isRight = boneName.StartsWith("_R ", StringComparison.Ordinal);
            if (!isLeft && !isRight) return BodySegment.None;

            bool isArm = boneName.IndexOf("Arm", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Forearm", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Hand", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Finger", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Deltoid", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Clavicle", StringComparison.Ordinal) >= 0;
            if (isArm) return isLeft ? BodySegment.LeftArm : BodySegment.RightArm;

            bool isLeg = boneName.IndexOf("Hip", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Thigh", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Calf", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Foot", StringComparison.Ordinal) >= 0 ||
                         boneName.IndexOf("Toe", StringComparison.Ordinal) >= 0;
            if (isLeg) return isLeft ? BodySegment.LeftLeg : BodySegment.RightLeg;
            return BodySegment.None;
        }

        static bool TryGetFootSegment(BodySegment segment, out BodySegment footSegment)
        {
            footSegment = segment;
            return segment == BodySegment.LeftLeg || segment == BodySegment.RightLeg;
        }

        static bool ShouldHideInNormalPreview(string objectName)
        {
            return objectName == "Mesh_EyeBasePlane" ||
                   objectName.StartsWith("Mesh_BP_", StringComparison.Ordinal) ||
                   objectName.StartsWith("Mesh_SP_", StringComparison.Ordinal);
        }

        static Material GetOrCreateMaterial(Material source, SampleDefinition definition)
        {
            if (source == null) return null;
            if (MaterialCache.TryGetValue(source, out var cached)) return cached;

            string sourceShaderName = source.shader != null ? source.shader.name : string.Empty;
            if (!ShaderMap.TryGetValue(sourceShaderName, out string targetShaderName))
                throw new InvalidOperationException("No reconstructed shader mapping for: " + sourceShaderName);

            var targetShader = Shader.Find(targetShaderName);
            if (targetShader == null) throw new InvalidOperationException("Reconstructed shader is missing: " + targetShaderName);

            string sourcePath = AssetDatabase.GetAssetPath(source);
            string guid = AssetDatabase.AssetPathToGUID(sourcePath);
            string safeName = string.Concat(source.name.Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c));
            string materialPath = $"{definition.MaterialsRoot}/{safeName}_{guid.Substring(0, 8)}.mat";
            var material = AssetDatabase.LoadAssetAtPath<Material>(materialPath);
            if (material == null)
            {
                material = new Material(targetShader) { name = source.name + " (Reconstructed)" };
                AssetDatabase.CreateAsset(material, materialPath);
            }
            else
            {
                material.shader = targetShader;
            }

            CopyMatchingProperties(source, material);
            if (definition.IsMale && source.name == "Infant_EyeBall_F_00")
            {
                var maleEyeBall = AssetDatabase.LoadAssetAtPath<Texture2D>(MaleEyeBallPath);
                material.SetTexture("_BaseMap", maleEyeBall);
                material.SetTextureScale("_BaseMap", Vector2.one);
                material.SetTextureOffset("_BaseMap", Vector2.zero);
            }
            if (targetShaderName == "Characters/Infant/Reconstructed/SkinFace" &&
                source.name == "Infant_HeadA_00" &&
                material.GetTexture("_MouthMap") == null)
            {
                var defaultMouth = AssetDatabase.LoadAssetAtPath<Texture2D>(DefaultInfantMouthPath);
                material.SetTexture("_MouthMap", defaultMouth);
                material.SetTextureScale("_MouthMap", Vector2.one);
                material.SetTextureOffset("_MouthMap", Vector2.zero);
                material.SetFloat("_MouthShowType", 0f);
            }
            if (material.HasProperty("_HasBaseMap"))
                material.SetFloat("_HasBaseMap", source.HasProperty("_BaseMap") && source.GetTexture("_BaseMap") != null ? 1f : 0f);
            if (material.HasProperty("_StencilRef"))
                material.SetFloat("_StencilRef", 1f);
            if (source.name == PiratesEpicAShoesMaterialName || source.name == PiratesEpicAOnePieceMaterialName)
            {
                if (material.HasProperty("_UseBaseMapAlpha"))
                    material.SetFloat("_UseBaseMapAlpha", 0f);
                if (material.HasProperty("_Cutoff"))
                    material.SetFloat("_Cutoff", 0.05f);
            }
            bool isEyeHighlight = targetShaderName == "Characters/Infant/Reconstructed/EyeShadeHighlight" &&
                                  source.GetTexture("_BaseMap") == null;
            material.renderQueue = isEyeHighlight ? (int)RenderQueue.Transparent + 20 : -1;
            EditorUtility.SetDirty(material);
            MaterialCache[source] = material;
            return material;
        }

        static void CopyMatchingProperties(Material source, Material destination)
        {
            Shader shader = destination.shader;
            int propertyCount = ShaderUtil.GetPropertyCount(shader);
            for (int i = 0; i < propertyCount; i++)
            {
                string propertyName = ShaderUtil.GetPropertyName(shader, i);
                if (!source.HasProperty(propertyName)) continue;

                switch (ShaderUtil.GetPropertyType(shader, i))
                {
                    case ShaderUtil.ShaderPropertyType.Color:
                        destination.SetColor(propertyName, source.GetColor(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.Vector:
                        destination.SetVector(propertyName, source.GetVector(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.Float:
                    case ShaderUtil.ShaderPropertyType.Range:
                        destination.SetFloat(propertyName, source.GetFloat(propertyName));
                        break;
                    case ShaderUtil.ShaderPropertyType.TexEnv:
                        destination.SetTexture(propertyName, source.GetTexture(propertyName));
                        destination.SetTextureScale(propertyName, source.GetTextureScale(propertyName));
                        destination.SetTextureOffset(propertyName, source.GetTextureOffset(propertyName));
                        break;
                }
            }
        }

        static void BuildScene(SampleDefinition definition, GameObject prefab)
        {
            BuildScene(definition, new List<GameObject> { prefab });
        }

        static void BuildScene(SampleDefinition definition, IList<GameObject> prefabs)
        {
            if (prefabs == null || prefabs.Count == 0 || prefabs.Any(prefab => prefab == null))
                throw new InvalidOperationException("Reconstructed prefab was not created.");

            Scene previous = SceneManager.GetActiveScene();
            bool replaceOpenScene = string.Equals(previous.path, definition.ScenePath, StringComparison.OrdinalIgnoreCase);
            Scene scene = EditorSceneManager.NewScene(
                NewSceneSetup.EmptyScene,
                replaceOpenScene ? NewSceneMode.Single : NewSceneMode.Additive);
            SceneManager.SetActiveScene(scene);
            try
            {
                float spacing = prefabs.Count > 1 ? 1.1f : 0f;
                float center = (prefabs.Count - 1) * 0.5f;
                for (int i = 0; i < prefabs.Count; i++)
                {
                    var instance = (GameObject)PrefabUtility.InstantiatePrefab(prefabs[i]);
                    instance.transform.SetPositionAndRotation(
                        new Vector3((i - center) * spacing, 0f, 0f),
                        Quaternion.identity);
                }
                BuildCamera(prefabs.Count);
                BuildLighting();
                BuildGround(prefabs.Count, spacing);
                EditorSceneManager.SaveScene(scene, definition.ScenePath);
            }
            finally
            {
                if (!replaceOpenScene)
                {
                    EditorSceneManager.CloseScene(scene, true);
                    if (previous.IsValid()) SceneManager.SetActiveScene(previous);
                }
            }
        }

        static void BuildCamera(int modelCount)
        {
            var cameraObject = new GameObject("Main Camera") { tag = "MainCamera" };
            cameraObject.transform.position = new Vector3(0f, 0.8f, modelCount > 1 ? 8.5f : 2.1f);
            cameraObject.transform.LookAt(new Vector3(0f, 0.65f, 0f));
            var camera = cameraObject.AddComponent<Camera>();
            camera.fieldOfView = modelCount > 1 ? 32f : 30f;
            camera.orthographic = modelCount > 1;
            camera.orthographicSize = 4.8f;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = 50f;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.12f, 0.16f, 0.22f, 1f);
        }

        static void BuildLighting()
        {
            var key = new GameObject("Key Light");
            key.transform.rotation = Quaternion.Euler(35f, 145f, 0f);
            var keyLight = key.AddComponent<Light>();
            keyLight.type = LightType.Directional;
            keyLight.intensity = 1.3f;
            keyLight.color = new Color(1f, 0.9f, 0.82f);
            keyLight.shadows = LightShadows.Soft;

            var fill = new GameObject("Fill Light");
            fill.transform.position = new Vector3(-1.5f, 1.2f, 1.2f);
            var fillLight = fill.AddComponent<Light>();
            fillLight.type = LightType.Point;
            fillLight.range = 5f;
            fillLight.intensity = 2f;
            fillLight.color = new Color(0.6f, 0.75f, 1f);

            RenderSettings.ambientMode = AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.35f, 0.4f, 0.5f);
            RenderSettings.ambientEquatorColor = new Color(0.18f, 0.2f, 0.25f);
            RenderSettings.ambientGroundColor = new Color(0.08f, 0.08f, 0.1f);
        }

        static void BuildGround(int modelCount, float spacing)
        {
            var material = new Material(Shader.Find("Universal Render Pipeline/Lit"))
            {
                name = "Preview Pedestal",
                color = new Color(0.18f, 0.22f, 0.3f),
            };
            float center = (modelCount - 1) * 0.5f;
            for (int i = 0; i < modelCount; i++)
            {
                var ground = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
                ground.name = modelCount > 1 ? "Preview Pedestal " + (i + 1) : "Preview Pedestal";
                ground.transform.position = new Vector3((i - center) * spacing, -0.04f, 0f);
                ground.transform.localScale = new Vector3(0.65f, 0.04f, 0.65f);
                UnityEngine.Object.DestroyImmediate(ground.GetComponent<Collider>());
                ground.GetComponent<Renderer>().sharedMaterial = material;
            }
        }

        static string Source(string relative)
        {
            return SourceRoot + "/" + relative;
        }

        static void EnsureFolder(string path)
        {
            if (AssetDatabase.IsValidFolder(path)) return;
            string parent = Path.GetDirectoryName(path).Replace('\\', '/');
            EnsureFolder(parent);
            AssetDatabase.CreateFolder(parent, Path.GetFileName(path));
        }
    }
}
