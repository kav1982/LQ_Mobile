using UnityEngine;

/// <summary>
/// The shipped campfire decal reads _CampFireLightPositionWS / Color from a client
/// behaviour that is not in this project. Copy the parent Light (or this transform)
/// onto a material property block so the volume lights the ground at the fire.
/// </summary>
[ExecuteAlways]
[DisallowMultipleComponent]
public sealed class MMN_CampFireDecalBinder : MonoBehaviour
{
    static readonly int PosId = Shader.PropertyToID("_CampFireLightPositionWS");
    static readonly int ColorId = Shader.PropertyToID("_CampFireLightColor");

    MaterialPropertyBlock _block;

    void LateUpdate()
    {
        var renderer = GetComponent<Renderer>();
        if (renderer == null) return;

        if (_block == null) _block = new MaterialPropertyBlock();
        renderer.GetPropertyBlock(_block);

        var light = GetComponentInParent<Light>();
        Vector3 pos = light != null ? light.transform.position : transform.position;
        _block.SetVector(PosId, new Vector4(pos.x, pos.y, pos.z, 1f));
        if (light != null)
            _block.SetColor(ColorId, light.color);

        renderer.SetPropertyBlock(_block);
    }
}
