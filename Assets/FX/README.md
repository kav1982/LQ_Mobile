# FX

Original paths from `assets/patchableassets/fx/`.

- `0_resource/` shared textures, materials, meshes, animations
- `1_effect/environment/` scene FX, grouped by original subfolder (`actionprop`, `actor`, `area_border`, `battlefield`, `dungeon`, `housing`, `prop`, `skysphere`, `town`)
- `1_effect/character/0_common/` shared hit / buff
- `1_effect/character/class/` player-class skill prefabs, original numbering:
  - `1_warrior/` `greatsword`, `knight`, `swordmaster`
  - `2_rogue/` `dualblades`, `fighter`
  - `3_archer/` `arbalist`, `longbow`
  - `4_mage/` `mage_fire`, `mage_ice`, `mage_lightning`
  - `5_healer/` `darkshaman`, `monk`, `priest`
  - `6_bard/` `battlemusician`, `dancer`
- `_import_pack/` extract output
  - `catalog.json` from `appdata/_re_work/extract_fx_environment.py`
  - `catalog_class.json` from `appdata/_re_work/extract_fx_class.py`

Talent folders other than `4_mage/mage_fire` are empty placeholders; import writes into the matching original path.

Import menu:

- **MMN / FX / 1. Import Environment FX**
- **MMN / FX / 2. Import Class FX (Fire Mage)**
