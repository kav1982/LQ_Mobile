using DungeonImport.Editor;
using UnityEditor;

namespace Runda.Editor
{
    /// <summary>
    /// Thin menu wrapper around the shared dungeon pack importer for the Runda dungeon.
    /// </summary>
    public static class RundaImporter
    {
        const string Dungeon = "Runda";

        [MenuItem("Tools/Runda/1. Import Room Assets")]
        public static void ImportAll() => DungeonPackImporter.ImportAll(Dungeon);

        [MenuItem("Tools/Runda/2. Build Dungeon Scene")]
        public static void BuildScene() => DungeonPackImporter.BuildScene(Dungeon);
    }
}
