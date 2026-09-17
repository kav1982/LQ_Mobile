using System.Collections;
using UnityEngine;

namespace FX
{
    /// <summary>
    /// Plays the already-imported Fire Storm pieces as one skill object:
    /// start + idle together, then end after idleDuration.
    /// </summary>
    public sealed class FxFirestormSkill : MonoBehaviour
    {
        [SerializeField] float idleDuration = 5f;

        static readonly string[] StartNames =
        {
            "fx_firemage_firestorm_start",
            "fx_firemage_firestorm_light",
        };

        static readonly string[] IdleNames =
        {
            "fx_firemage_firestorm_idle_01",
            "fx_firemage_firestorm_idle_02",
            "fx_firemage_firestorm_idle_01_decal",
        };

        static readonly string[] EndNames =
        {
            "fx_firemage_firestorm_end",
            "fx_firemage_firestorm_end_decal",
            "fx_firemage_firestorm_end_light",
        };

        void OnEnable()
        {
            SetActive(EndNames, false);
            SetActive(StartNames, true);
            SetActive(IdleNames, true);
            Restart(StartNames);
            Restart(IdleNames);
            StopAllCoroutines();
            StartCoroutine(Run());
        }

        void OnDisable()
        {
            StopAllCoroutines();
        }

        IEnumerator Run()
        {
            yield return new WaitForSeconds(idleDuration);
            StopEmit(StartNames);
            StopEmit(IdleNames);
            SetActive(EndNames, true);
            Restart(EndNames);
        }

        void SetActive(string[] names, bool on)
        {
            for (int i = 0; i < names.Length; i++)
            {
                var t = transform.Find(names[i]);
                if (t != null)
                    t.gameObject.SetActive(on);
            }
        }

        void Restart(string[] names)
        {
            for (int i = 0; i < names.Length; i++)
            {
                var t = transform.Find(names[i]);
                if (t == null || !t.gameObject.activeInHierarchy)
                    continue;
                var systems = t.GetComponentsInChildren<ParticleSystem>(true);
                for (int s = 0; s < systems.Length; s++)
                    systems[s].Play(true);
            }
        }

        void StopEmit(string[] names)
        {
            for (int i = 0; i < names.Length; i++)
            {
                var t = transform.Find(names[i]);
                if (t == null || !t.gameObject.activeInHierarchy)
                    continue;
                var systems = t.GetComponentsInChildren<ParticleSystem>(true);
                for (int s = 0; s < systems.Length; s++)
                    systems[s].Stop(true, ParticleSystemStopBehavior.StopEmitting);
            }
        }
    }
}
