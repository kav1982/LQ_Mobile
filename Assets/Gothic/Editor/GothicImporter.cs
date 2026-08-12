using DungeonImport.Editor;
using UnityEditor;

namespace Gothic.Editor
{
    /// <summary>
    /// Thin menu wrapper around the shared dungeon pack importer for the Gothic dungeon.
    /// </summary>
    public static class GothicImporter
    {
        const string Dungeon = "Gothic";

        [MenuItem("Tools/Gothic/1. Import Room Assets")]
        public static void ImportAll() => DungeonPackImporter.ImportAll(Dungeon);

        [MenuItem("Tools/Gothic/2. Build Dungeon Scene")]
        public static void BuildScene() => DungeonPackImporter.BuildScene(Dungeon);
    }
}
