# SkyUI Sub-Filters — working notes for Claude

Read this before touching anything. Read `README.md` too; it carries the measured field reference.

**This is an addon for SkyUI, not a fork of it.** This repo holds only original work plus a patch.
SkyUI's source is never committed here; it is cloned from upstream at build time.

---

## What this is

A second row of text tabs under the SkyUI inventory category icons, narrowing Weapons and Apparel by
type. Built against **doodlum/SkyUI-Community tag `v6.11`**, which was verified **byte-identical** to
the installed SkyUI 6.11 release before any changes were made.

Two new AS2 classes plus a patch to one SkyUI file:

| File | Role |
| --- | --- |
| `src/Common/skyui/filter/SubCategoryFilter.as` | `IFilter` in the `FilteredEnumeration` chain |
| `src/Common/skyui/components/SubCategoryBar.as` | the tab row, built at runtime |
| `patches/InventoryLists.as.patch` | wires both into `InventoryLists.as` |
| `tools/add_class_triplet.py` | registers a new AS2 class in the SWF XMLs and `swfsources.cmake` |

---

## Build recipe

```sh
git clone https://github.com/doodlum/SkyUI-Community.git && cd SkyUI-Community
git checkout v6.11 && git submodule update --init --recursive
# copy src/ over source/actionscript/, then:
git apply .../patches/InventoryLists.as.patch
python .../tools/add_class_triplet.py skyui.filter.SubCategoryFilter Common/skyui/filter/SubCategoryFilter.as InventoryLists.as
python .../tools/add_class_triplet.py skyui.components.SubCategoryBar Common/skyui/components/SubCategoryBar.as InventoryLists.as
export SkyrimSE_PATH="E:/Modlists/Still In Skyrim/stock"
cmake --preset debug -G Ninja
cmake --build build/debug --target ActionScript
```

Ship `build/debug/interface/inventorymenu.swf` and `build/debug/interface/skyui/inventorylists.swf`
as **loose files**. They override SkyUI's BSA.

### Two deviations from upstream's README, both required

1. **`-G Ninja`.** The presets default to NMake, which needs a Visual Studio developer shell. The
   project declares `LANGUAGES NONE`, so no C++ compiler is needed at all.
2. **`--target ActionScript`, not the default.** The default target also compiles Papyrus, which needs
   Creation Kit and SKSE script sources in the game folder. It **will fail** on a portable MO2 install
   and that failure is expected and irrelevant. This project changes no Papyrus.

---

## HARD RULES

1. **VERIFY TWICE AFTER EVERY BUILD.** This is not optional and it caught three separate failures.
   - Decompress the output SWF and grep for a string unique to the change. A zero byte delta means
     nothing landed.
   - **Then confirm behaviour in game.** A clean build and a present class still prove nothing.
2. **`ffdec -importScript` cannot ADD a class, only replace one, and it reports success when it
   silently skips your new file.** A class must already exist in the SWF as a
   `DefineSpriteTag` + `ExportAssetsTag` + `DoInitActionTag` triplet. Use `tools/add_class_triplet.py`.
3. **Never match on display strings.** `subTypeDisplay`, `weightClassDisplay` and friends are
   localised and break on any non-English game. Match the numeric fields.
4. **`InventoryLists.as` compiles into SIX SWFs** (barter, container, gift, inventory, magic,
   skyui_inventorylists). Any class it references must exist in **all six** or those menus throw at
   runtime. `add_class_triplet.py` handles this; do not shortcut it.
5. **Only ship `inventorymenu.swf` and `inventorylists.swf`.** Shipping the other four would apply the
   sub-filter to container, barter, gift and magic menus, which is not wanted.

---

## ffdec's AS2 dialect — its parser accepts more than its compiler emits

| Construct | Result |
| --- | --- |
| `import` | parse error, *"Parsing finished before end of the file on line 1"* |
| return types, `function f(): Void` | parse error, *"CURLY_OPEN expected but COLON found"* |
| `switch` on static-property case labels | **compiles silently, matches nothing** |
| `private static var` read from a static method | **compiles silently, matches nothing** |
| parameter types, `function f(a: Number)` | fine |
| `//` and `/** */` comments | fine |

Write in the style of `ItemTypeFilter.as`: fully-qualified names, plain numeric literals in
`if`/`else`, no imports, no return types.

---

## Things that bit us, so don't re-derive them

- **`weaponType` holds `ANIM_*` values, not `TYPE_*`.** They coincide for 0-6 and 9, so a crossbow test
  passes by luck while BOWS silently lists staves. Measured table is in `README.md`.
- **Battleaxe and warhammer both report `6`.** Only the `WeapTypeWarhammer` keyword separates them.
- **Weapon `subType` is NOT processed at filter time**, but apparel `weightClass` **is**. Do not assume
  one rule covers both. The data processor runs after the filter chain.
- **Shields carry a real weight class** (Falmer `0/512`, Imperial `1/512`), so they must be excluded
  from LIGHT and HEAVY or they appear under two tabs. Robes are Clothing and need the same treatment.
- **Some items have a `null` weight class** (bandolier, slot 53). The matcher must not choke.
- **A Flash MovieClip does not clip its children.** An overflowing row draws over the item preview;
  there is no `overflow: hidden`. `SubCategoryBar.layout()` auto-fits by shrinking padding then font.
- **`onItemRollOut` in stock `CategoryList` restores a hardcoded alpha** instead of re-deriving state.
  Do not copy that; `SubCategoryBar.refreshState()` is the correct pattern.

---

## Outstanding

1. **Gamepad input is not implemented.** Tabs are mouse-only. Stock binds `prevColumn`/`nextColumn` to
   the shoulder buttons and `switchTab` to BACK, so a second row needs non-colliding bindings.
2. Device font, not SkyUI's embedded `$EverywhereMediumFont`.
3. The 26px list offset and the row's vertical position are eyeballed, not measured.
4. `itemList` and `ListBackground` are moved directly, bypassing SkyUI's `layout` object. This is the
   most likely thing to break if the layout system is ever touched.

---

## Distribution

The repo is clean. The caveat applies only to the **built SWFs**, which are modified copies of SkyUI's
files: SkyUI-Community ships no licence file or headers, so redistribution terms are unstated. Their
README welcomes contributions, so **upstreaming is likely the cleanest route** if this proves useful.

Full project history and reasoning: `Still in Skyrim Plus Documentation/SKYUI_CATEGORY_ADDON_BRIEF.md`
in the BarryRim modlist repo.
