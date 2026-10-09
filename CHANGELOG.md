# Changelog

## 0.1.0-dev.30 — 2026-10-09

- Add ten shared unit-frame decorations for BootyFrame; existing controls are unchanged.

## 0.1.0-dev.28 — 2026-10-09

- Use Booty names in shared controls and settings profiles; read previous preferences without resetting data.
- Remove the unused previous-title texture.

## 0.1.0-dev.27 - 2026-10-08

- Add shared rounded-square and octagonal minimap masks.

## 0.1.0-dev.26 — 2026-10-08

- Supply a shared native message preview for BootyChat history with consistent window ownership.

## 0.1.0-dev.25 — 2026-10-08

- Reuse each integrated feature controller when Suite opens it in a separate project window.
- Preserve window ownership, geometry and Settings access while moving existing content.
- Hide removed navigation buttons and reuse them when restored to the menu.

## 0.1.0-dev.24 — 2026-10-08

- Restore the shared color picker's borrowed drawing order on close and stop the dismiss overlay immediately.
- Remove unused navigation textures and obsolete persistence prompts; retain existing project borders and product reload guards.

## 0.1.0-dev.23 — 2026-10-07

- Share optional rounded action-bar effects and extend the existing native project border with independent corner radius and thickness.
- Supply reusable cooldown and shadow masks for BootyActionBars.

## 0.1.0-dev.22 — 2026-10-07

- Keep retained feature windows and actions unavailable after a failed startup until cleanup and a new activation succeed.

## 0.1.0-dev.21 — 2026-10-07

- Clean prepared product resources after activation failure and retain failed cleanup for an explicit retry.
- Preserve owner diagnostics when Stop is refused.

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
