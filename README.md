# Cam Hytale ANE (AssetNodeEditor)

> [!WARNING]
> PLEASE READ: This is just an early alpha, provided as-is, take care to properly version control or backup any files you may be editing.

## Current Status:
Early Alpha

### What works:
* WorldGen Asset Node workspaces (Biome, Density, BlockMask, Assignments)
* Loading a WorldGen Asset Node JSON file
* Saving to a new JSON file (keep backups if saving over your work!)
* Adding nodes either with the menu (space) or by dragging out a new connection
* Copying, Cutting, Pasting, Duplicating (ctr+d), and deleting nodes, including copy/paste between instances and sessions
* Modifying existing nodes connections
* Cutting connections by drawing a line (ctr+right click)
* Remembering favorites and recently used directories accross app restarts
* Windows and Linux support (Mac build exists but is currently completely untested and not properly signed)

### What doesn't work:
* Doesn't yet work with non-worldgen Workspaces, only those that start with "HytaleGenerator - "
  * Can load other HytaleGenerator workspace files besides Biome files, but new files are always created as a Biome workspace for now, this will be addressed in the next version
* Node Comments, Separate Comments, and Groups are not yet implemented
* Custom Node Titles are supported but there's no way to rename nodes in the editor itself yet
* Certain node types parameters use a simple string input box, which may not work for everything

### Unique Features:
* Custom Manual Curve Editor that doesn't require a bunch of separate CurvePoint nodes (Previewing curve and editing points in a graph to come soon)
* Auto-add node if there is only one possible node for the connection type you dragged out
* Stay tuned for more
