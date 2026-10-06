# Changelog

## 0.1.0-dev.9 — 2026-10-06

- Fix native text-field enabled state in Settings without calling unsupported Button methods.
- Disable text-field mouse/keyboard input and clear focus through existing save behavior.
- Prevent recursive focus-loss saves and retain typed text when a save fails.

## 0.1.0-dev.8 — 2026-10-06

- Store named appearance presets separately for each supported element.
- Preserve general settings profiles and save only validated appearance values.

## 0.1.0-dev.7 — 2026-10-06

- Preserve saved Suite window position and size when the UI reloads.

## 0.1.0-dev.6 — 2026-10-06

- Support window position and size previews without saving until Apply.
- Cancel unfinished window edits on hide or minimize and preserve later changes.
- Preview a shared interface skin and apply or cancel it without changing other preferences.
- Refresh settings actions when another Booty product takes or releases control of an option.
- Preserve the owner's error when safe product shutdown is refused.

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
