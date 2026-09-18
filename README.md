# Skyrim Sub-Filters

Sub-category filter rows for the SkyUI inventory. Adds a second row of text tabs under the
existing category icons, so the Weapons and Apparel tabs can be narrowed further.

**Weapons:** `ALL · SWORDS · AXES · MACES · DAGGERS · BOWS · CROSSBOWS · STAFFS · AMMO`

**Apparel:** `ALL · CLOTHES · LIGHT · HEAVY · ROBES · SHIELDS · JEWELLERY`

Built against **SkyUI 6.11** ([doodlum/SkyUI-Community](https://github.com/doodlum/SkyUI-Community),
tag `v6.11`), verified byte-identical to the release build before any changes were made.

---

## What is in this repository

This repo contains **only original work plus the changes needed to apply it**. It deliberately does
**not** redistribute SkyUI's source.

| Path | What it is |
| --- | --- |
| `src/Common/skyui/filter/SubCategoryFilter.as` | new `IFilter` implementation, the matching logic |
| `src/Common/skyui/components/SubCategoryBar.as` | new UI component, the text tab row |
| `patches/InventoryLists.as.patch` | changes to SkyUI's `InventoryLists.as` to wire it in |
| `tools/add_class_triplet.py` | registers a new AS2 class in the SWF XMLs and the build |

This is an **addon**, not a reimplementation. Everything here is original work; SkyUI's own source is
not included and is fetched from upstream at build time.

> **One caveat, for distribution only.** ActionScript 2 classes live inside the SWF, so there is no
> standalone addon file: the build output is a modified copy of SkyUI's `inventorymenu.swf` and
> `inventorylists.swf`. That matters if you ever publish the **built files** (e.g. to Nexus), because
> SkyUI-Community ships no licence file or headers, so redistribution terms are not stated. It does not
> affect this repository, which contains no SkyUI code. Their README does explicitly welcome
> contributions, so upstreaming is likely the cleanest route if this proves useful.

---

## Building

```sh
git clone https://github.com/doodlum/SkyUI-Community.git
cd SkyUI-Community
git checkout v6.11
git submodule update --init --recursive
```

Copy this repo's `src/` over `source/actionscript/`, apply the patch, then register the two new
classes:

```sh
git apply /path/to/patches/InventoryLists.as.patch
python /path/to/tools/add_class_triplet.py \
    skyui.filter.SubCategoryFilter Common/skyui/filter/SubCategoryFilter.as InventoryLists.as
python /path/to/tools/add_class_triplet.py \
    skyui.components.SubCategoryBar Common/skyui/components/SubCategoryBar.as InventoryLists.as
```

Then build:

```sh
set SkyrimSE_PATH=<your Skyrim Special Edition folder>
cmake --preset debug -G Ninja
cmake --build build/debug --target ActionScript
```

Ship `build/debug/interface/inventorymenu.swf` and
`build/debug/interface/skyui/inventorylists.swf` as loose files. They override SkyUI's BSA.

### Build notes

- **Use `-G Ninja`.** The presets default to NMake, which needs a Visual Studio developer shell.
  The project declares `LANGUAGES NONE`, so no C++ compiler is required at all.
- **Build the `ActionScript` target, not the default.** The default also compiles Papyrus, which
  needs Creation Kit and SKSE script sources present in the game folder. This project changes no
  Papyrus.
- Requires CMake 4.2+, Ninja, and Java (for the bundled `ffdec-cli`).

---

## Why a tool instead of an XML patch

`ffdec -importScript` **replaces** existing AS2 classes but cannot **add** one, and it reports success
when it silently skips a new file. A class must first exist in the SWF as a triplet of
`DefineSpriteTag` + `ExportAssetsTag` + `DoInitActionTag`.

`add_class_triplet.py` clones an existing class's triplet under a free sprite id, renames it, and
registers the source in `swfsources.cmake`. Doing it this way rather than shipping a patched XML keeps
the diff small, avoids embedding large generated hex blobs, and survives SkyUI version changes.

---

## ffdec AS2 dialect constraints

Its parser accepts more than its compiler correctly emits. All three of these were hit while building
this, and none produced a useful error:

| Construct | Result |
| --- | --- |
| `import` statements | parse error: *"Parsing finished before end of the file on line 1"* |
| return type annotations, e.g. `function f(): Void` | parse error: *"CURLY_OPEN expected but COLON found"* |
| `switch` with static-property case labels | **compiles silently, matches nothing at runtime** |
| `private static var` read from a static method | **compiles silently, matches nothing at runtime** |

Parameter type annotations are fine. Use fully-qualified names instead of imports, and plain numeric
literals in `if`/`else` instead of `switch`.

**Always verify twice.** Grep the decompressed output SWF for a string unique to the change, then
confirm behaviour in game. A clean build and a present class still prove nothing.

---

## Field reference, measured in game

Matching uses the non-localised numeric fields on the inventory entry. `subTypeDisplay` is translated
and must not be matched on.

### Weapons — match `weaponType`

It holds `ANIM_*` values, **not** `TYPE_*`. The two enums coincide for 0-6 and 9, which hides the bug
until it doesn't. Skyrim uses two parallel ranges for the same classes.

| Tab | `weaponType` |
| --- | --- |
| SWORDS | 1, 11, 5, 15 |
| AXES | 3, 13, or 6/16 **without** `WeapTypeWarhammer` |
| MACES | 4, 14, or 6/16 **with** `WeapTypeWarhammer` |
| BOWS | 7, 17 |
| CROSSBOWS | 9, 19 |
| DAGGERS | 2, 12 |
| STAFFS | 8, 18 |
| AMMO | `formType` == 42 |

Battleaxe and warhammer both report `6`; only the keyword separates them.

### Apparel — match `weightClass` and `partMask`

Unlike weapon `subType`, `weightClass` **is** already processed at filter time.

| Tab | Rule | Observed |
| --- | --- | --- |
| CLOTHES | `weightClass == 3`, robes excluded | Common Clothes `3/4` |
| LIGHT | `weightClass == 0`, shields excluded | Imperial Light Boots `0/128` |
| HEAVY | `weightClass == 1`, shields excluded | Iron Boots `1/128` |
| ROBES | `OCF_BodyTypeRobes` keyword | robe `3/4` with `C`+`R` |
| SHIELDS | `partMask & 512` | Falmer `0/512`, Imperial `1/512` |
| JEWELLERY | `weightClass == 4` | Amulet of Talos `4/32` |

Shields carry a real weight class, so they must be excluded from LIGHT and HEAVY or they appear twice.
Robes are Clothing, so they must be excluded from CLOTHES for the same reason. Some items have a
**null** weight class (e.g. a bandolier at slot 53) and belong to no tab.

`ROBES` is the only tab depending on [Object Categorization
Framework](https://www.nexusmods.com/skyrimspecialedition/mods/49882). Without OCF that one tab is
empty; everything else still works.

---

## Known limitations

- **Gamepad input is not implemented.** The tabs are mouse-only.
- Uses a device font rather than SkyUI's embedded `$EverywhereMediumFont`.
- The 26px list offset and the row's vertical position are tuned by eye.
- `itemList` and `ListBackground` are repositioned directly, bypassing SkyUI's `layout` object.

## Credits

SkyUI by the SkyUI Team; SkyUI 6.x community releases by
[doodlum/SkyUI-Community](https://github.com/doodlum/SkyUI-Community) and contributors.
ActionScript compilation via [JPEXS Free Flash Decompiler](https://github.com/jindrapetrik/jpexs-decompiler).
