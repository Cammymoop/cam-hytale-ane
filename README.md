# Cam Hytale ANE
## A custom (cross-platform) asset node editor for Hytale's WorldGen Asset Nodes

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
* Custom Manual Curve Editor that doesn't require a bunch of separate CurvePoint nodes (Previewing curve and editing points in a graph to come soon)
* Easily customizable colors for every type of node
* Auto-add node if there is only one possible node for the connection type you dragged out
* Stay tuned for more
