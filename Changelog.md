# Changelog

## 0.4.2
### Fixes:
- Fixed multiple bugs with undo on settings, and a bug where if the first thing you do is edit a setting it breaks the undo
- Fixed regression in 0.4.0 causing errors when trying to add new groups
- Fixed regression in 0.4.0 where updating the theme colors doesn't update existing graph nodes

### Improvements:
- Group settings are now editable in the settings menu
  - Color used for all groups without a specific accent color selected
  - Whether new groups have shrinkwrap enabled by default
  - Size of newly created groups can be reset to default from the settings menu, to set it to a new size right click on a group of that size and select "Set Group Size As Default for New Groups"
- Improved (hopefully) the theme in a lot of minor ways, working toward making it easier to make a custom theme to replace the default
- You can now set the interface color from the settings menu, this is used for the main menu nodes at the top and also for context menus

## 0.4.1
Fixed a critical bug in 0.4.0 where ctr_right clicking to cut connections then undoing would add many duplicate copies of connected asset nodes on save

## 0.4.0
This is a big refactor and rewrite of the core editor code which will make lots of new stuff possible but the new stuff is relatively minimal for this release

### Improvements:
- You can now automatically color nested groups on opening a file
- Groups now correctly have a semi-transparent background, and are more readable in general
- Editing values inside nodes, text, numbers, checkboxes etc, now supports undo and redo

### Fixes:
- This version should fix a lot of bugs with copy/paste and undo/redo but also might have introduced some new ones
- In addition to trying to enforce integer values for fields where we know hytale expects an integer, saving files will now save int values in all fields in a way that doesn't cause hytale's strict json parser to reject them if it expects an integer there. This should help in any cases I missed or later if/when custom node types are added it means you wont have to be as precise with defining the custom node type

## 0.3.2
### New Features:
- **Group support!** This might still have a bit of bugs, especially when it comes to undo/redo and copy/paste, please let me know or create an issue if you notice any odd behavior
  - Can now load groups created in the official Node Editor
  - You can now create groups, change their accent color, create nested groups, etc
  - Select a group by left-clicking on it's titlebar or by right clicking anywhere inside the group (not on another node)
  - When moving a node, hold shift when first clicking or press shift while dragging to remove the node from it's current group
  - Drop a node above a group to add it into the group
  - Dropping a new connection into a group will also add the new node to the group
  - Groups will automatically shrink to only cover the current members, this can be changed per-group from the context menu
  - Add keyboard shortcut for "Cut Inclusive" (ctr-shift-x) Which cuts all selected nodes as well as all unselected nodes inside of selected groups

### Improvements:
- Dragging points in Manual Curve editor now creates multiple undo steps, one per click and release
- Many more options in the context menu for managing the current selection, adding new nodes/groups, etc
- New select subtree mode "Greedy" which selects all nodes in a subtree, all groups that contain any of the nodes in the subtree, and all other nodes inside those groups 
  - good for keeping floating nodes associated with a subtree by including them in a group with others in the subtree
  - the default behavior of double clicking a node's titlebar is the non-greedy version but this can be toggled in the settings menu
  - the non-greedy version also selects groups, but only if all of the group's members are part of the subtree

### Fixes:
- More fixes to cases where keyboard shortcuts were not being detected properly
- Fix duplicated or pasted nodes showing default values or broken inputs for some fields
- Fix deselect all keyboard shortcut not doing anything
- Fix a regression (I think?) error in the schema for ClusterProp nodes
- Lots of other fixes in relation to copy and paste, duplicate, and undo/redo in general

## 0.3.1
### New Features:
- The add new node menu can now be filtered by typing the part of a name of the node
- Can now insert a graph node into connections by dropping it on top of a compatible connection
  - Will not try to patch a node into a connection if it already has it's output connected somewhere
  - May change this to require holding a key when you drop it (configurable) in the future but for now it's mandatory
- Can now select a subtree by double-clicking on the base node's titlebar, or from the node context menu
- Can now edit the title of a node by selecting "Edit Title" from the context menu

### Improvements:
- "Dissolve Node" in the node context menu now works, it removes the node and tries to connect it's inputs to where it's output was connected
- Manual Curve editor now supports undo/redo
- Can now resize the maximum height of the add new node menu
- Manual Curve editor hides the ExportAs field by default, it has an extra menu that you can use to make it show up, this is an expirimental idea

### Fixes:
- Fix nodes pasted from the system clipboard not being able to save their position
- Fix not being able to use keyboard shortcuts after certain operations
- Fix dropping the wrong node from the new node menu sometimes

## 0.3.0
### Visual curve editor!
- Can see a visualization of the manual curve and edit it by dragging the points around, even dragging them out past the edge of the current graph
- Add new points by ctr-clicking on the curve graph, remove points by right-clicking them

### Fixes:
- Fix Space menu not working until after left clicking the editor after closing a popup menu

## 0.2.2
### Improvements:
- Spin-box type buttons for number range inputs
- Keyboard Shortcut for new file

### Fixes:
- Fix Manual Curve not being able to connect back to a Curve connection port
- Fix regression with number range inputs like Octaves in Simplex noise nodes

## 0.2.1
### Improvements:
- Can now save custom theme colors
- Number fields can now have an expression like "123/5" typed into them which will set the resulting value

## 0.2.0
For use with Hytale 2026.02.05 and later

### New Upstream Changes:
- Materials now have directionality
- Added YSampled Density (Defines sample spacing in Y and interpolates density values between samples)
- Added Bound Positions Provider (limits positions within a bounding box I think)

### Improvements:
- Options with a limited set of values now use a dropdown selector (like Distance Function for Positions Cell Noise)
- Options that consist of a set of limited values now use a set of checkboxes (like Directions for Wall Pattern)
- Can now save custom theme colors, these will also be loaded automatically on startup
- Improved unchecked checkbox appearance

### Fixes:
- Added missing Pattern Directionality
- Added missing Delimiter for Field Function Positions Provider
- Fix Positions Cell Noise distance function types being treated as 2 separate node types


## 0.1.8
### Improvements:
- Add an "Open File" button to the new file popup that shows on opening the editor
- Separate "Save" and "Save As" - you no longer need to go through the file dialog every time you save
- Show a quick toast message when a file is saved

### Fixes:
- Fix a few more cases of floats serialized instead of ints which would cause the asset not to load
- Fix Manual Curve saving and loading causing extra floating CurvePoint nodes at the origin
- Fix duplicating or pasting special nodes not being placed at the duplicate/pasted position
- Fix regression: Using space to open the new node menu would only work once until another popup was opened

## 0.1.6
### Improvements:
- Add Display scaling detection, on windows and linux (x11) this is always 100%, and manually setting display scale
  - Custom display scale is saved and persists across sessions
- Less blurry font and port icon rendering at higher zoom levels
- Cmd+Backspace or Ctr+Backspace now works as a delete shortcut
- Can now load files with missing metadata and automatically do a basic arrangement of nodes so they aren't all overlapping

## 0.1.5
### Fixes:
- Added some missing Postions, Curve, and VectorProvider Nodes

### Improvements:
- Make theme colors customizable
- Prompt for saving unsaved changes before opening a new file
- Allow choosing a new file type when creating a new file
- Drag & drop support to open a json file

## 0.1.4
### Big New Stuff:
* Deleting is now a thing (press delete with nodes selected)
* Also copy/cut/paste with ctr-c/ctr-x/ctr-v
* Copy and paste works using the system clipboard so it works across different instances of the program or when closing the session and opening a new one or just making a new file
* Duplicate with ctr-d

### Fixes:
* Various things saving incorrectly or not being saved to the file at all

### Improvements:
* Labels next to connections are now color-coded
* File dialog favorites and recently used folders are now saved and loaded across sessions

## 0.1.3
### Fixes:
* Fixes loading old-style .json files like those found in the current Hytale asset bundle
* Doesn't remove extra editor metadata that it doesn't know what to do with when opening an existing file then re-saving
* Fixes "Exported Density" nodes not being loaded properly

### Improvements:
* Remember last used directory across editor restarts

## 0.1.2
First publicly released version

### Features:
- Opening and saving Biome workspace files
- cutting connections, making connections, adding new nodes, editing node parameters