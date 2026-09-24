# Artwork

This directory contains design sources, drafts, and preview renders. It is not part of the app target.

- `AppIcon/` contains the editable app icon source and its previews. The 1024 px export is retained as the master raster export. A production `AppIcon.appiconset` should be added after all required macOS sizes are exported.
- `Mascot/Previews/` contains visual checks only.
- `Mascot/Drafts/` contains unfinished or invalid source files that are kept for reference.

Runtime-ready artwork belongs in `Kaskas/Resources/Assets.xcassets`. The current mascot SVG lives there as a named, vector-preserving template image.
