# 资源路径规则

后续导入、搬迁、预览场景都按这里落盘。不要把区域包、道具包、特效包直接摊在 `Assets/` 根下。

路径一律正斜杠，相对 `Assets/`。搬文件用 Unity `MoveAsset`，带着 `.meta`，不要手改 GUID。

## 根目录

| 根 | 放什么 | 不放什么 |
|---|---|---|
| `Assets/Worlds/{Region}/` | 区域 / 地下城场景资源 | 跨区域共用道具、角色、特效 |
| `Assets/Props/` | 跨场景道具（目前 `Plants`、`TreasureBox`） | 某个区域私有的建筑、植被 |
| `Assets/FX/` | 特效 prefab / 贴图 / 材质 / 预览场景 | shader 源文件 |
| `Assets/MMN/Shaders/` | 全部 MMN shader 与 include | 特效贴图、prefab |
| `Assets/Characters/` | 角色（`Infant`）与怪物（`Monsters/{Species}`） | 场景、道具 |
| `Assets/DungeonImport/` | 地下城导入器代码 | 导入产物 |
| `Assets/FX/_import_pack/` 与 `{Root}/_import_pack/` | 解包中间结果 | 最终给场景用的 prefab |

`Assets/Scenes/` 只留工程默认场景（如 `SampleScene`）。区域预览不写这里。

## 硬约束

1. **包内结构不摊平。** `_import_pack` 里原来的子目录、文件名保持原样；导入器写到 `OutRoot` 时按包内相对路径，不要把所有 prefab 抽到同一层。
2. **区域包不抽 `.unity`。** 解包出来的场景文件不当作工程场景用；预览场景由导入器/预览脚本另建。
3. **shader 只活在 `Assets/MMN/Shaders/`。** 特效包、区域包里若带了同名 shader：指向已有 MMN 资源，不要再复制一份。包里独有的 shader 迁到 MMN 对应分类（FX / BG / …），guid 保留。
4. **共用道具进 `Props/`，不进 `Worlds/`。** 植物、宝箱这类跨图资源不要塞进某个区域文件夹。
5. **`_import_pack` 留在本域根下。** 例如 `Assets/Worlds/Alby/_import_pack`、`Assets/FX/_import_pack`，不要提到 `Assets/` 根。

## Worlds

路径：`Assets/Worlds/{Region}/`

当前区域：`Alby`、`Bangor`、`CloudWilderness`、`ColhenBeach`、`Gothic`、`GreyMaze`、`IceCanyon`、`Labyrinth`、`MoonGate`、`Runda`、`SidheSneachta`、`SkySanctum`、`TirChonaill`。

地下城导入（`DungeonPackImporter`，`outRoot = Assets/Worlds/{dungeon}`）标准子目录：

```
{Region}/
  _import_pack/     解包
  Textures/
  Materials/
  Meshes/
  Prefabs/
  Scenes/           预览场景 {Region}_Preview.unity
  Editor/           该区域导入/预览脚本
```

城镇包同样落在 `Assets/Worlds/{Region}/`，内部可以保留包原来的分类（例如 TirChonaill 的 `Buildings/`、`Vegetation/`、`Shared/`），不要为了整齐而打散。

新区域：新建 `Assets/Worlds/{PascalCase英文名}/`，不要用中文文件夹名，不要和已有 13 个重名。

## Props

| 包 | 根 | 导入器 OutRoot |
|---|---|---|
| 植物 | `Assets/Props/Plants/` | 同左 |
| 宝箱 | `Assets/Props/TreasureBox/` | 同左 |

子目录与地下城包相同：`_import_pack`、`Textures`、`Materials`、`Meshes`、`Prefabs`、`Scenes`、`Editor`。

新的跨图道具：`Assets/Props/{Pack}/`，不要放到 `Worlds/` 或 `FX/`。

## FX

根：`Assets/FX/`。原包路径来自 `assets/patchableassets/fx/`。

```
FX/
  0_resource/
    texture/
    materials_new/
    mesh/
    animations/
  1_effect/
    environment/{town,dungeon,prop,housing,battlefield,actionprop,actor,area_border,skysphere}/…
    character/0_common/
    character/class/
      1_warrior/{greatsword,knight,swordmaster}/
      2_rogue/{dualblades,fighter}/
      3_archer/{arbalist,longbow}/
      4_mage/{mage_fire,mage_ice,mage_lightning}/
      5_healer/{darkshaman,monk,priest}/
      6_bard/{battlemusician,dancer}/
  Scene/            预览场景，不是玩法关卡
  _import_pack/     catalog.json / catalog_class.json
  Editor/
```

- 共用贴图、材质、网格、动画 → `0_resource/…`（按类型，不按区域再分一层）。
- prefab → 写回原 `1_effect/…` 相对路径，职业编号和天赋文件夹名不要改。
- 空的职业/天赋目录是占位，导入时往对应路径写，不要新建另一套 `class/warrior` 之类的名字。
- 预览场景只放 `FX/Scene/`：`FX_TestEnvironment`、`FX_TestClassFire`、`FX_TestWater`。不要再开 `Assets/WaterFX/` 这类平行展示包。

导入菜单：`MMN / FX / 1. Import Environment FX`、`MMN / FX / 2. Import Class FX (Fire Mage)`。

## MMN Shaders

```
Assets/MMN/Shaders/
  FX/           特效 shader（含 Amplify 名、Dissolve、MMCustomParticle）
  BG/           场景/海面等（如 MMN_BG_OceanSunGlitterPath）
  Include/      公共 hlsl
  Special/ Impostor/ Generated/
  Contracts/Original/     从 bytecode 抽出的契约，禁止手改
  Contracts/Extensions/   项目有意加的 Pass/属性
```

特效材质继续放 `Assets/FX/0_resource/materials_new/`，shader 字段指向 `MMN/Shaders` 里的资源。

## Characters

```
Assets/Characters/Infant/
  Source/           AssetRipper 原路径
  Generated/        目录 ScriptableObject
  Reconstructed/    示例 Prefab / 材质 / 场景
  Editor/ Runtime/ Shaders/
```

```
Assets/Characters/Monsters/{Species}/
  Source/           AssetRipper 原路径（包内相对路径不摊平）
  Generated/        预览 Prefab / 材质 / AnimatorController
  Scenes/           该种展示场，默认 {Species}_Preview.unity
  Editor/           该种预览脚本
```

当前怪物：

| 种 | 身体 | 预览场景 |
|---|---|---|
| `Goblin` | `monster_goblin_*` 42 只 + 对应武器 / `animation/monster/goblin/` Clip | `Goblin/Scenes/Goblin_Preview.unity`（格子场，Goblinpig 也摆在这里） |
| `GoblinPig` | `monster_goblinpig_*` 9 只；动画在 `animation/monster/pig/` | 无独立场景，由 Goblin 展示场一起生成 |
| `Gnoll` | `monster_gnoll_*` 50 只 + 9 件武器 / `animation/monster/gnoll/` | `Gnoll/Scenes/Gnoll_Preview.unity`（GnollArcher 也摆在这里） |
| `GnollArcher` | `monster_gnollarcher_*` 3 只；动画用 gnoll 的 archer clip | 无独立场景，由 Gnoll 展示场一起生成 |
| `GhostArmor` | `monster_ghostarmor_*` 约 40 只 + 32 件武器 | `GhostArmor/Scenes/GhostArmor_Preview.unity` |
| `Ratman` | `monster_ratman_*` 39 只；包里没有独立武器 Prefab | `Ratman/Scenes/Ratman_Preview.unity` |
| `Skeleton` | `monster_skeleton_*`；`default_hound` / `default_swordsman` 的 UnityFS 未导出 | `Skeleton/Scenes/Skeleton_Preview.unity` |
| `Golem` | `monster_golem_*`；格子间距 8m（体型比人形大） | `Golem/Scenes/Golem_Preview.unity` |
| `Kobold` | `monster_kobold_*` 33 只 + 22 件武器 | `Kobold/Scenes/Kobold_Preview.unity` |
| `Mud` | `monster_mud_*` 30 只 + 弓/斧/大剑/剑/盾/杖 | `Mud/Scenes/Mud_Preview.unity` |
| `Earthen` | `monster_earthen_*` 22 只 + 弓/斧/钝器/大剑/盾/杖；格子间距 5m；clip 只有 highshaman / duelist 两套 | `Earthen/Scenes/Earthen_Preview.unity` |
| `Digger` | `monster_digger_*` 23 只；格子间距 5m；包里没有独立武器 | `Digger/Scenes/Digger_Preview.unity` |
| `Slime` | `monster_slime_*` 17 只（去掉 cutscene / maplecollabo）；格子间距 5m | `Slime/Scenes/Slime_Preview.unity` |
| `Rat` | `monster_rat_*` 20 只（不含 Ratman）；包里没有独立武器 | `Rat/Scenes/Rat_Preview.unity` |
| `Spider` | `monster_spider_*` 20 只 | `Spider/Scenes/Spider_Preview.unity`（Spiderling 也摆在这里） |
| `Spiderling` | `monster_spiderling_*` 11 只；动画用 spider clip | 无独立场景，由 Spider 展示场一起生成 |

玩家种族：`Assets/Characters/{Race}/`，不要和场景、特效混放。细节见 `Assets/Characters/Infant/README.md`。

怪物不按 118 种各开一个 Characters 顶级目录。shader dummy 不复制；`MMN/CH/Standard` 继续用 Infant Source 里已有的那份。预览材质绑 `Characters/Infant/Reconstructed/Standard`。

## 预览场景

| 内容 | 路径 |
|---|---|
| 区域 | `Assets/Worlds/{Region}/Scenes/{Region}_Preview.unity` |
| 道具 | `Assets/Props/{Pack}/Scenes/` |
| 特效 | `Assets/FX/Scene/FX_Test*.unity` |
| 角色示例 | `Assets/Characters/{Race}/Reconstructed/…` |
| 怪物预览 | `Assets/Characters/Monsters/{Species}/Scenes/` |

预览场景可以重排实例坐标，不要改 prefab 资源本身的路径。

## 解包脚本（仓库外）

`appdata/_re_work/` 的 extract 脚本输出应对准上面的 `_import_pack`，不要写到 `Assets/` 根。本文件只约束 Unity 工程内落点。
