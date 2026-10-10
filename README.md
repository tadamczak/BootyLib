<p align="center"><img src="Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyLib

BootyLib supplies the shared appearance and integration used by BootyGuild, BootyRaider, BootyProfiler, BootyActionBars and Booty Suite on World of Warcraft 1.12.

Install the `BootyLib` folder in `Interface/AddOns` alongside any Booty product. Enable it in the character's addon list. Only one copy is needed, regardless of how many Booty products are installed. The library has no separate minimap button or feature window.

When updating this development family, update BootyLib and all installed Booty
products together, then restart the client. Their shared controls require a
matching set of builds. Previous saved data and preferences are retained.

Windows, controls and menus use a consistent foreground order across installed Booty addons.

Booty Suite can open a feature in its dashboard or in a separate window. Both
presentations retain the same addon state and use the shared Settings gear.

Settings keeps compact text and clear plus/minus controls for expanding sections.

Settings fields use one to four columns as space permits. Each column fits its full labels; color labels stay next to their swatches.
Mixed controls align by their bottom edges; captions stay attached to their own controls through resizing.
Related settings can share dedicated rows that wrap with the window. Multi-select dropdowns keep their menu open while choices are checked and save selections in profiles.

Resizing Settings reuses its measured labels and leaves current values and drafts intact.

Dropdown captions keep their normal font while windows resize. Menu choices use the same surface in both skins. Disabled text settings release keyboard focus and become read-only until enabled again.

In standalone Booty addons, use the gear in the top-right corner of a feature window to open that addon's Settings. It also works while the window is minimized.

If loading a profile or resetting Settings fails, the previous preferences are restored. The error remains visible; a failed restoration is reported separately.

If an addon cannot start or stop safely, Booty reports the reason. Failed startup cleanup must finish before another startup attempt. Feature views remain unavailable until the addon starts successfully; its Settings remains accessible.

BootyFrame uses ten shared decorative unit-frame styles supplied by BootyLib.

Circular level slots retain their decorative rims and use a shared black fill.

Percentage settings display 0â€“100 while existing saved appearances and profiles remain compatible.

Action buttons can use rounded or circular icons, shadows and the existing project outline. Hidden styles stay inactive; previous square styles remain available.
