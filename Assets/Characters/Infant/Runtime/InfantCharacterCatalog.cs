using System;
using System.Collections.Generic;
using UnityEngine;

namespace Characters.Infant
{
    public enum InfantCharacterCategory
    {
        Body,
        Head,
        Eye,
        MouthTexture,
        FaceDecal,
        FaceAccessory,
        Hair,
        Top,
        Bottom,
        OnePiece,
        Shoes,
        Gloves,
        Helmet,
        Robe,
        Etc,
        FacialAnimation,
    }

    public enum InfantCharacterGender
    {
        Shared,
        Female,
        Male,
    }

    [Serializable]
    public sealed class InfantCharacterEntry
    {
        public string displayName;
        public InfantCharacterCategory category;
        public InfantCharacterGender gender;
        public string sourcePath;
        public GameObject prefab;
        public AnimationClip animation;
        public Texture2D texture;
    }

    [CreateAssetMenu(menuName = "Characters/Infant Character Catalog")]
    public sealed class InfantCharacterCatalog : ScriptableObject
    {
        public List<InfantCharacterEntry> entries = new List<InfantCharacterEntry>();
    }
}
