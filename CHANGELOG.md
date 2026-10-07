# Changelog

## 0.1.0-dev.20 — 2026-10-07

- Restore previous preferences and product state if loading or resetting settings fails during the final refresh.
- Preserve the original failure and report any failed restoration.

## 0.1.0-dev.19 — 2026-10-07

- Reuse measured Settings labels and combine resize callbacks before arranging columns.
- Keep resizing separate from refreshing values and profiles; stop pending work when Settings hides.

## 0.1.0-dev.18 — 2026-10-07

- Arrange Settings fields in up to four columns sized for their full labels.
- Keep color labels left-aligned beside their swatches.

## 0.1.0-dev.17 — 2026-10-07

- Keep dropdown captions readable through resizing and filter refreshes.
- Enable and disable text settings using native input controls, preserving drafts and focus handling.

## 0.1.0-dev.16 — 2026-10-07

- Open addon Settings from the top-right gear in every standalone feature window, including minimized windows.

## 0.1.0-dev.5 — 2026-10-05

- Preserve complete header titles through resizing, skin changes and window restore.
- Restore compact Settings typography and readable accordion plus/minus signs.

## 0.1.0-dev.4 — 2026-10-05

- Support native model controls used by BootyActionBars cooldowns through the shared UI library.

## 0.1.0-dev.3 — 2026-10-05

- Keep complete windows and popups in one shared foreground order across all Booty products.
- Pool formatted project confirmations and preserve native Escape handling without altering the game popup pool.

## 0.1.0-dev.2 — 2026-10-05

- Fix Settings accordion actions on the WoW 1.12 Lua runtime.
- Keep Profile and the product section as the two standalone Settings roots.
- Restore distinct navigation icons and attach header ornaments close to the title.

## 0.1.0-dev.1 — 2026-10-05

- Introduce the shared Booty UI, settings, product hosting and data migration library.
- Preserve the project skins, gold borders and balanced dialog headers.
- Keep legacy settings profiles compatible, batch changes and reuse navigation when products join later.
- Validate product API and view ownership before activation.
