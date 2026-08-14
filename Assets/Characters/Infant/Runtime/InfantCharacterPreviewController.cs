using System.Collections.Generic;
using UnityEngine;

namespace Characters.Infant
{
    [ExecuteAlways]
    public sealed class InfantCharacterPreviewController : MonoBehaviour
    {
        public InfantCharacterCatalog catalog;
        public Shader previewShader;

        [Header("Current Parts")]
        public GameObject body;
        public GameObject head;
        public GameObject eye;
        public GameObject hair;
        public GameObject onePiece;
        public GameObject shoes;
        public GameObject helmet;

        Transform _previewRoot;
        readonly List<Material> _temporaryMaterials = new List<Material>();
        bool _isRebuilding;

        void OnEnable()
        {
            Rebuild();
        }

        void OnValidate()
        {
#if UNITY_EDITOR
            if (!Application.isPlaying)
            {
                UnityEditor.EditorApplication.delayCall -= RebuildAfterValidation;
                UnityEditor.EditorApplication.delayCall += RebuildAfterValidation;
                return;
            }
#endif
            if (isActiveAndEnabled) Rebuild();
        }

        void OnDisable()
        {
#if UNITY_EDITOR
            UnityEditor.EditorApplication.delayCall -= RebuildAfterValidation;
#endif
            ClearPreview();
        }

#if UNITY_EDITOR
        void RebuildAfterValidation()
        {
            if (this != null && isActiveAndEnabled) Rebuild();
        }
#endif

        [ContextMenu("Rebuild Preview")]
        public void Rebuild()
        {
            if (_isRebuilding || previewShader == null) return;
            _isRebuilding = true;
            try
            {
                ClearPreview();
                var root = new GameObject("__InfantPreviewModel");
                root.hideFlags = HideFlags.DontSaveInEditor | HideFlags.DontSaveInBuild;
                root.transform.SetParent(transform, false);
                _previewRoot = root.transform;

                AddPart("Body", body);
                AddPart("Head", head);
                AddPart("Eye", eye);
                AddPart("Hair", hair);
                AddPart("OnePiece", onePiece);
                AddPart("Shoes", shoes);
                AddPart("Helmet", helmet);
            }
            finally
            {
                _isRebuilding = false;
            }
        }

        void AddPart(string label, GameObject prefab)
        {
            if (prefab == null) return;
            var instance = Instantiate(prefab, _previewRoot);
            instance.name = label + " - " + prefab.name;
            instance.transform.localPosition = Vector3.zero;
            instance.transform.localRotation = Quaternion.identity;
            instance.transform.localScale = Vector3.one;

            foreach (var animator in instance.GetComponentsInChildren<Animator>(true))
                animator.enabled = false;
            foreach (var renderer in instance.GetComponentsInChildren<Renderer>(true))
                renderer.sharedMaterials = BuildPreviewMaterials(renderer.sharedMaterials);
        }

        Material[] BuildPreviewMaterials(Material[] sourceMaterials)
        {
            var result = new Material[sourceMaterials.Length];
            for (int i = 0; i < sourceMaterials.Length; i++)
            {
                var source = sourceMaterials[i];
                if (source == null) continue;

                var material = new Material(previewShader)
                {
                    name = source.name + " (Preview)",
                    hideFlags = HideFlags.HideAndDontSave,
                };
                InfantPreviewMaterialUtility.CopyProperties(source, material);
                _temporaryMaterials.Add(material);
                result[i] = material;
            }
            return result;
        }

        void ClearPreview()
        {
            if (_previewRoot != null)
            {
                if (Application.isPlaying) Destroy(_previewRoot.gameObject);
                else DestroyImmediate(_previewRoot.gameObject);
                _previewRoot = null;
            }

            foreach (var material in _temporaryMaterials)
            {
                if (material == null) continue;
                if (Application.isPlaying) Destroy(material);
                else DestroyImmediate(material);
            }
            _temporaryMaterials.Clear();
        }
    }
}
