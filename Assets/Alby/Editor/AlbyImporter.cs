using DungeonImport.Editor;
using UnityEditor;

namespace Alby.Editor
{
    /// <summary>
    /// Thin menu wrapper around the shared dungeon pack importer for Alby.
    /// </summary>
    public static class AlbyImporter
    {
        const string Dungeon = "Alby";

        [MenuItem("Tools/Alby/1. Import Room Assets")]
        public static void ImportAll() => DungeonPackImporter.ImportAll(Dungeon);

        [MenuItem("Tools/Alby/2. Build Dungeon Scene")]
        public static void BuildScene() => DungeonPackImporter.BuildScene(Dungeon);
    }
}
