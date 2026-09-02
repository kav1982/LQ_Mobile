using UnityEditor;
using UnityEngine;

namespace LQMobile.Audio.Editor
{
    /// <summary>
    /// BGM/instrument stream from disk; short clips stay compressed in memory.
    /// Only applies to Assets/Audio so other clips keep their existing importer settings.
    /// </summary>
    public sealed class AudioClipImportSettings : AssetPostprocessor
    {
        const string AudioRoot = "Assets/Audio/";

        void OnPreprocessAudio()
        {
            if (!assetPath.StartsWith(AudioRoot, System.StringComparison.OrdinalIgnoreCase))
                return;

            var importer = (AudioImporter)assetImporter;
            var settings = importer.defaultSampleSettings;
            bool stream = IsStreamingPath(assetPath);

            settings.loadType = stream
                ? AudioClipLoadType.Streaming
                : AudioClipLoadType.CompressedInMemory;
            settings.compressionFormat = AudioCompressionFormat.Vorbis;
            settings.quality = stream ? 0.7f : 0.5f;
            settings.preloadAudioData = !stream;
            importer.defaultSampleSettings = settings;
            importer.forceToMono = false;
        }

        static bool IsStreamingPath(string path)
        {
            return ContainsFolder(path, "/bgm/")
                || ContainsFolder(path, "/instrument/");
        }

        static bool ContainsFolder(string path, string folder)
        {
            return path.IndexOf(folder, System.StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
