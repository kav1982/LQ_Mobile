using UnityEngine;

namespace FX
{
    /// <summary>
    /// Reconstruction of MM.Client.Presentation.Effect.DecalTransformMaterialSetter.
    /// The shipped ParticleDecal / EffectLightDecal shaders read _worldScaleAndRotY as
    /// (lossyScale.xyz, eulerY). Write it through a property block so instanced
    /// particles keep their own box.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public sealed class DecalTransformMaterialSetter : MonoBehaviour
    {
        public bool useZeroTimeBurst;

        static readonly int ScaleRotId = Shader.PropertyToID("_worldScaleAndRotY");
        static readonly int WorldPosId = Shader.PropertyToID("_worldPosition");

        MaterialPropertyBlock _block;
        bool _wrote;

        void OnEnable()
        {
            _wrote = false;
            Write();
        }

        void LateUpdate()
        {
            if (useZeroTimeBurst && _wrote)
                return;
            Write();
        }

        void Write()
        {
            var renderer = GetComponent<Renderer>();
            if (renderer == null)
                return;

            if (_block == null)
                _block = new MaterialPropertyBlock();
            renderer.GetPropertyBlock(_block);

            var scale = transform.lossyScale;
            _block.SetVector(ScaleRotId, new Vector4(scale.x, scale.y, scale.z, transform.eulerAngles.y));
            if (renderer.sharedMaterial != null && renderer.sharedMaterial.HasProperty(WorldPosId))
            {
                var p = transform.position;
                _block.SetVector(WorldPosId, new Vector4(p.x, p.y, p.z, 1f));
            }

            renderer.SetPropertyBlock(_block);
            _wrote = true;
        }
    }
}
