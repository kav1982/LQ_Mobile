using UnityEngine;

namespace CloudWilderness
{
    [ExecuteAlways]
    public class CloudWildernessGpuGrass : MonoBehaviour
    {
        const int Slice = 1023;

        [System.Serializable]
        public class Batch
        {
            public Mesh mesh;
            public Material material;
            public Material[] materials;
            public Matrix4x4[] matrices;
        }

        public Batch[] batches;

        void LateUpdate()
        {
            if (batches == null) return;
            for (int b = 0; b < batches.Length; b++)
            {
                var batch = batches[b];
                if (batch == null || batch.mesh == null || batch.material == null || batch.matrices == null)
                    continue;
                int n = batch.matrices.Length;
                int subCount = Mathf.Max(1, batch.mesh.subMeshCount);
                for (int s = 0; s < subCount; s++)
                {
                    var mat = MaterialFor(batch, s);
                    if (mat == null) continue;
                    if (n <= Slice)
                    {
                        Graphics.DrawMeshInstanced(batch.mesh, s, mat, batch.matrices);
                        continue;
                    }
                    for (int i = 0; i < n; i += Slice)
                    {
                        int count = Mathf.Min(Slice, n - i);
                        var slice = new Matrix4x4[count];
                        System.Array.Copy(batch.matrices, i, slice, 0, count);
                        Graphics.DrawMeshInstanced(batch.mesh, s, mat, slice);
                    }
                }
            }
        }

        static Material MaterialFor(Batch batch, int submesh)
        {
            if (batch.materials != null && submesh < batch.materials.Length && batch.materials[submesh] != null)
                return batch.materials[submesh];
            return batch.material;
        }
    }
}
