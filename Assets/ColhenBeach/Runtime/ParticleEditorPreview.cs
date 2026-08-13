using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace ColhenBeach
{
    /// <summary>
    /// Edit-mode stand-in for the Particle Effect overlay. Scene view defaults Simulate Layers to
    /// Nothing, so an unplayed shoreline prefab shows zero particles. This advances each emitter
    /// by deltaTime with a locked seed: restarting every frame (the previous version) re-rolled
    /// autoRandomSeed and made the cards jump around the box.
    ///
    /// Play mode must not call ParticleSystem.Simulate: Simulate pauses the system, and this
    /// component then bails out of Update, so the shoreline foam froze after 0.01s. Unity's own
    /// player loop drives the emitters once they are left alone. Edit mode ticks from
    /// EditorApplication.update and repaints the Scene view, otherwise the foam only moves when
    /// the viewport is clicked.
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class ParticleEditorPreview : MonoBehaviour
    {
        struct Track
        {
            public ParticleSystem Ps;
            public bool OrigAuto;
            public uint OrigSeed;
            public float Time;
        }

        Track[] _tracks;
        float _lastRealtime;

        void OnEnable()
        {
            Capture();
            if (Application.isPlaying)
                return;

            LockSeedsAndRewind();
            _lastRealtime = Time.realtimeSinceStartup;
#if UNITY_EDITOR
            EditorApplication.update -= EditorTick;
            EditorApplication.update += EditorTick;
            EnableSceneViewPlayback();
#endif
        }

        void OnDisable()
        {
#if UNITY_EDITOR
            EditorApplication.update -= EditorTick;
#endif
            if (!Application.isPlaying)
                RestoreSeeds();
        }

#if UNITY_EDITOR
        void EditorTick()
        {
            if (Application.isPlaying || this == null || !isActiveAndEnabled)
                return;

            if (_tracks == null || _tracks.Length == 0)
            {
                Capture();
                LockSeedsAndRewind();
            }

            float now = Time.realtimeSinceStartup;
            float dt = Mathf.Clamp(now - _lastRealtime, 0.001f, 0.05f);
            _lastRealtime = now;

            bool any = false;
            for (int i = 0; i < _tracks.Length; i++)
            {
                var t = _tracks[i];
                if (t.Ps == null) continue;
                float cycle = Mathf.Max(t.Ps.main.duration, 8f);
                t.Time += dt;
                if (t.Time >= cycle)
                {
                    t.Time %= cycle;
                    t.Ps.Simulate(t.Time, false, true, false);
                }
                else
                {
                    t.Ps.Simulate(dt, false, false, false);
                }
                _tracks[i] = t;
                any = true;
            }

            if (any)
                SceneView.RepaintAll();
        }

        static void EnableSceneViewPlayback()
        {
            var sv = SceneView.lastActiveSceneView;
            if (sv == null) return;
            var state = sv.sceneViewState;
            state.alwaysRefresh = true;
            state.alwaysRefresh = true;
            state.fxEnabled = true;
            sv.sceneViewState = state;
        }
#endif

        void Capture()
        {
            var systems = GetComponentsInChildren<ParticleSystem>(true);
            _tracks = new Track[systems.Length];
            for (int i = 0; i < systems.Length; i++)
            {
                var ps = systems[i];
                _tracks[i] = new Track
                {
                    Ps = ps,
                    OrigAuto = ps.useAutoRandomSeed,
                    OrigSeed = ps.randomSeed,
                    Time = 0f
                };
            }
        }

        void LockSeedsAndRewind()
        {
            if (_tracks == null) return;
            for (int i = 0; i < _tracks.Length; i++)
            {
                var t = _tracks[i];
                if (t.Ps == null) continue;
                t.Ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
                t.Ps.useAutoRandomSeed = false;
                t.Ps.randomSeed = (uint)(t.Ps.name.GetHashCode() ^ 0x51ED);
                t.Time = 0f;
                t.Ps.Simulate(0.01f, false, true, false);
                _tracks[i] = t;
            }
        }

        void RestoreSeeds()
        {
            if (_tracks == null) return;
            foreach (var t in _tracks)
            {
                if (t.Ps == null) continue;
                t.Ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
                t.Ps.useAutoRandomSeed = t.OrigAuto;
                t.Ps.randomSeed = t.OrigSeed;
            }
        }
    }
}
