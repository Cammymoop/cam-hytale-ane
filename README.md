<div align="center">

![Cam Hytale ANE Logo](./public/cam-hytale-ane-logo-v2_256.png)

  <h1>Cam Hytale ANE</h1>
  <p><b>A custom, cross-platform Asset Node editor for Hytale, primarily for worldgen v2</b></p>
</div>
<hr>

> [!WARNING]
> PLEASE READ: This is an alpha release, it is provided as-is, please take care to properly version control or backup any files you may be editing.

## Current Status:
Alpha, usable but not very stable

### What works:
* WorldGen Asset Node workspaces (Biome, Density, BlockMask, Assignments)
* Loading a WorldGen Asset Node JSON file and saving (keep backups if saving over your work!)
* Adding, editing, removing nodes etc. Changing graph connections.
* Cutting connections by drawing a freeform line (ctr+right click)
* Remembering favorites and recently used directories accross app restarts
* Windows and Linux support (unsigned Mac build is available, mileage may vary)

### What doesn't work:
* Doesn't yet work with non-worldgen Workspaces, only those that start with "HytaleGenerator - "
* Node Comments, Separate Comments, and Groups are not yet implemented
* Customizable Theme Colors do not persist across sessions yet
* Custom Node Titles are supported but there's no way to rename nodes in the editor itself yet

### Unique Features:
* Custom Manual Curve Editor with a built-in visual editor

![Manual Curve Editor](./public/manual_curve_editor.png)
* Easily customizable colors for every type of node
* Auto-add node if there is only one possible node for the connection type you dragged out
* Stay tuned for more

<hr>
<div align="center">

[![Powered By Godot](./public/powered_by_godot_dark.png#gh-dark-mode-only)](https://godotengine.org)
[![Powered By Godot](./public/powered_by_godot_light.png#gh-light-mode-only)](https://godotengine.org)

</div>