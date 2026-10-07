<p align="center"><img src="Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyLib

BootyLib supplies the shared appearance and integration used by BootyGuild, BootyRaider, BootyProfiler, BootyActionBars and Booty Suite on World of Warcraft 1.12.

Install the `BootyLib` folder in `Interface/AddOns` alongside any Booty product. Enable it in the character's addon list. Only one copy is needed, regardless of how many Booty products are installed. The library has no separate minimap button or feature window.

Windows, controls and menus use a consistent foreground order across installed Booty addons.

Settings keeps compact text and clear plus/minus controls for expanding sections.

Settings fields use one to four columns as space permits. Each column fits its full labels; color labels stay next to their swatches.

Resizing Settings reuses its measured labels and leaves current values and drafts intact.

Dropdown captions keep their normal font while windows resize. Disabled text settings release keyboard focus and become read-only until enabled again.

In standalone Booty addons, use the gear in the top-right corner of a feature window to open that addon's Settings. It also works while the window is minimized.

If loading a profile or resetting Settings fails, the previous preferences are restored. The error remains visible; a failed restoration is reported separately.

If an addon cannot start or stop safely, Booty reports the reason. Failed startup cleanup must finish before another startup attempt.
