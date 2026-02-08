# Changelog

## 0.3.1
### New Features:
- The add new node menu can now be filtered by typing the part of a name of the node
- Can now insert a graph node into connections by dropping it on top of a compatible connection
  - Will not try to patch a node into a connection if it already has it's output connected somewhere
  - May change this to require holding a key when you drop it (configurable) in the future but for now it's mandatory

### Improvements:
- "Dissolve Node" in the node context menu now works, it removes the node and tries to connect it's inputs to where it's output was connected

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