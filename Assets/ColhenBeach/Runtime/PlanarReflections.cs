using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace ColhenBeach
{
    /// <summary>
    /// Stand-in for the shipped PlanarReflections MonoBehaviour that sits on colhen_water_00 and
    /// fills _PlanarReflectionTexture for MMN/Special/PlanarReflectionWater. The shipped component
    /// is compiled game code and was not extracted; what is reproduced here is its serialised
    /// configuration and the job it has to do, so the water shader gets the input it expects.
    ///
    /// Shipped field values on Colhen_Water_00, for reference:
    ///   ResolutionMultiplier 2, AutoResolutionMultiplier 1, ClipPlaneOffset 0.55,
    ///   ReflectLayers bits 2048 (layer 11 only), PlaneNormal 0 (up), CameraHeightOffset 0.
    /// ReflectLayers is left open in the preview because the beach objects are not on the game's
    /// layer 11; with the shipped mask nothing would show up in the mirror.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class PlanarReflections : MonoBehaviour
    {
        static readonly int PlanarReflectionTextureId = Shader.PropertyToID("_PlanarReflectionTexture");

        [Tooltip("Renderers whose material receives the reflection texture. Empty = this object's.")]
        public List<Renderer> meshRenderers = new List<Renderer>();

        [Tooltip("Divides the reflection resolution. The shipped water uses 2, i.e. half res.")]
        [Range(1, 8)] public int resolutionDivider = 2;

        [Tooltip("Pushes the mirror plane along its normal, hiding the seam where the water meets the sand.")]
        public float clipPlaneOffset = 0.55f;

        public LayerMask reflectLayers = -1;

        [Tooltip("Height of the mirror plane in world space; the shipped water plane sits at y=0.588.")]
        public float planeHeight;

        public float cameraHeightOffset;

        Camera _reflectionCamera;
        RenderTexture _target;
        MaterialPropertyBlock _block;

        void OnEnable()
        {
            RenderPipelineManager.beginCameraRendering += OnBeginCamera;
        }

        void OnDisable()
        {
            RenderPipelineManager.beginCameraRendering -= OnBeginCamera;
            Cleanup();
        }

        void Cleanup()
        {
            if (_reflectionCamera != null)
            {
                _reflectionCamera.targetTexture = null;
                if (Application.isPlaying) Destroy(_reflectionCamera.gameObject);
                else DestroyImmediate(_reflectionCamera.gameObject);
                _reflectionCamera = null;
            }
            if (_target != null)
            {
                RenderTexture.ReleaseTemporary(_target);
                _target = null;
            }
        }

        void OnBeginCamera(ScriptableRenderContext context, Camera camera)
        {
            // Without this the mirror camera would ask for its own reflection, forever.
            if (camera.cameraType == CameraType.Reflection || camera.cameraType == CameraType.Preview) return;
            if (_reflectionCamera != null && camera == _reflectionCamera) return;

            UpdateCamera(camera);
            if (_reflectionCamera == null) return;

            var plane = new Vector3(0f, planeHeight + clipPlaneOffset, 0f);
            var normal = Vector3.up;
            Matrix4x4 reflection = CalculateReflectionMatrix(normal, -Vector3.Dot(normal, plane));

            _reflectionCamera.transform.position = reflection.MultiplyPoint(camera.transform.position)
                                                   + Vector3.up * cameraHeightOffset;
            var forward = reflection.MultiplyVector(camera.transform.forward);
            var up = reflection.MultiplyVector(camera.transform.up);
            _reflectionCamera.transform.rotation = Quaternion.LookRotation(forward, up);

            _reflectionCamera.worldToCameraMatrix = camera.worldToCameraMatrix * reflection;

            // Oblique projection clips everything below the water, so the sea floor and the
            // underside of the terrain never appear in the mirror.
            Vector4 clipPlane = CameraSpacePlane(_reflectionCamera, plane, normal, 1f);
            _reflectionCamera.projectionMatrix = camera.CalculateObliqueMatrix(clipPlane);

            bool invert = GL.invertCulling;
            GL.invertCulling = !invert;
#pragma warning disable 618 // RenderSingleCamera is the only entry point that works from inside beginCameraRendering in URP 14.
            UniversalRenderPipeline.RenderSingleCamera(context, _reflectionCamera);
#pragma warning restore 618
            GL.invertCulling = invert;

            ApplyTexture();
        }

        void UpdateCamera(Camera source)
        {
            int w = Mathf.Max(64, source.pixelWidth / Mathf.Max(1, resolutionDivider));
            int h = Mathf.Max(64, source.pixelHeight / Mathf.Max(1, resolutionDivider));

            if (_target == null || _target.width != w || _target.height != h)
            {
                if (_target != null) RenderTexture.ReleaseTemporary(_target);
                _target = RenderTexture.GetTemporary(w, h, 24,
                    source.allowHDR ? RenderTextureFormat.DefaultHDR : RenderTextureFormat.Default);
                _target.name = "PlanarReflection";
                // The water samples the reflection at a mip level to blur it with distance, so the
                // target has to carry mips.
                _target.useMipMap = true;
                _target.autoGenerateMips = true;
                if (_reflectionCamera != null) _reflectionCamera.targetTexture = _target;
            }

            if (_reflectionCamera == null)
            {
                var go = new GameObject("PlanarReflectionCamera")
                {
                    hideFlags = HideFlags.HideAndDontSave
                };
                _reflectionCamera = go.AddComponent<Camera>();
                _reflectionCamera.enabled = false;
                _reflectionCamera.cameraType = CameraType.Reflection;
                var data = go.AddComponent<UniversalAdditionalCameraData>();
                data.renderShadows = false;
                data.requiresColorOption = CameraOverrideOption.Off;
                data.requiresDepthOption = CameraOverrideOption.Off;
            }

            _reflectionCamera.CopyFrom(source);
            _reflectionCamera.enabled = false;
            _reflectionCamera.cameraType = CameraType.Reflection;
            _reflectionCamera.targetTexture = _target;
            _reflectionCamera.cullingMask = reflectLayers;
            _reflectionCamera.useOcclusionCulling = false;
        }

        void ApplyTexture()
        {
            _block ??= new MaterialPropertyBlock();
            if (meshRenderers.Count == 0)
            {
                var own = GetComponent<Renderer>();
                if (own != null) meshRenderers.Add(own);
            }
            foreach (var r in meshRenderers)
            {
                if (r == null) continue;
                r.GetPropertyBlock(_block);
                _block.SetTexture(PlanarReflectionTextureId, _target);
                r.SetPropertyBlock(_block);
            }
        }

        static Matrix4x4 CalculateReflectionMatrix(Vector3 n, float d)
        {
            var m = Matrix4x4.identity;
            m.m00 = 1f - 2f * n.x * n.x; m.m01 = -2f * n.x * n.y; m.m02 = -2f * n.x * n.z; m.m03 = -2f * n.x * d;
            m.m10 = -2f * n.y * n.x; m.m11 = 1f - 2f * n.y * n.y; m.m12 = -2f * n.y * n.z; m.m13 = -2f * n.y * d;
            m.m20 = -2f * n.z * n.x; m.m21 = -2f * n.z * n.y; m.m22 = 1f - 2f * n.z * n.z; m.m23 = -2f * n.z * d;
            return m;
        }

        static Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sign)
        {
            var m = cam.worldToCameraMatrix;
            var cpos = m.MultiplyPoint(pos);
            var cnormal = m.MultiplyVector(normal).normalized * sign;
            return new Vector4(cnormal.x, cnormal.y, cnormal.z, -Vector3.Dot(cpos, cnormal));
        }
    }
}
