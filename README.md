<p align="center"><img src="Assets/readme-header.png" width="100%" alt="Sons of Mukla"></p>

# BootyLib

BootyLib supplies the shared appearance and integration used by BootyGuild, BootyRaider, BootyProfiler, BootyActionBars, BootyUI and Booty Suite on World of Warcraft 1.12.

Install the `BootyLib` folder in `Interface/AddOns` alongside any Booty product. Enable it in the character's addon list. Only one copy is needed, regardless of how many Booty products are installed. The library has no separate minimap button or feature window.

Windows, controls and menus use a consistent foreground order across installed Booty addons.

Compatible layout editors can preview window position, size, scale and supported anchor points, then apply or cancel the edit. Hiding or minimizing a window cancels its unfinished preview. Unavailable anchor elements retain their saved reference and use a recoverable screen position.
Applied Suite window position and size are restored when the UI reloads.
Ordinary window movement also updates a visible compatible editor. Content may extend beyond the screen while part of the title remains reachable.
Grid snapping keeps the selected point on a reachable grid line while preserving the window's size. Numeric inputs retain their text during window resizing and scaling.

Compatible appearance editors can preview the shared interface skin before applying it. A new choice in Settings ends an unfinished skin preview.
Supported editors can also save named appearance presets for individual elements. These presets remain separate from general settings profiles.

Settings keeps compact text and clear plus/minus controls for expanding sections.
Dropdowns retain their normal text size when windows change size or scale. Numeric fields retain their entered values.
