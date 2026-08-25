using DungeonImport.Editor;
using UnityEditor;

namespace GreyMaze.Editor
{
    /// <summary>
    /// Thin menu wrapper around the shared dungeon pack importer for GreyMaze.
    /// </summary>
    public static class GreyMazeImporter
    {
        const string Dungeon = "GreyMaze";

        [MenuItem("Tools/GreyMaze/1. Import Room Assets")]
        public static void ImportAll() => DungeonPackImporter.ImportAll(Dungeon);

        [MenuItem("Tools/GreyMaze/2. Build Dungeon Scene")]
        public static void BuildScene() => DungeonPackImporter.BuildScene(Dungeon);
    }
}
