# Godot Pixel Painter

A **Godot 4.6** pixel drawing and refinement tool for single-image quantization, sprite-sheet editing, transparency-rule processing, palette reduction analysis, and full-sheet export.

## Main Features

- Pixel canvas editing: supports sizes from `16x16` to `64x64`, with left-click paint and right-click erase.
- Preset palettes: multiple built-in pixel-art palettes, switchable at any time.
- Reference image quantization: import an image and quantize it to the current palette.
- Smart palette recommendation: evaluates preset error and switches to a better match.
- Image pixel analysis: builds the dynamic palette `Image Pixels` for rapid color reduction.
- Color limit and merge: uses `Limit + Tolerance` to control color count and merge strength.
- Transparency panel: pick transparency key colors, set alpha tolerance, apply to one frame or all frames.
- Sprite-sheet workflow: import sheet, split by grid, preview at bottom, edit frame-by-frame.
- Frame offset tool: use top-right `OF` to shift a frame and apply the offset to the target frame.
- Export tools: export current canvas PNG, export/import JSON config, and use `Gen` to compose a full sheet (with user-selected folder at export time).

## Controls

### Basic Controls

- Left click: paint with current color.
- Right click: erase (set transparent).
- Middle mouse drag: pan canvas.
- Mouse wheel: zoom canvas.
- Number keys `1-9`: switch to the first 9 palette colors.
- `C`: clear canvas (undoable).
- `Ctrl+Z`: undo the latest action.
- `E`: export current canvas PNG (opens folder picker).

### Top Toolbar

- `Canvas`: switch canvas size.
- `Palette`: switch preset palette.
- `Clear`: clear current canvas.
- `ExportPNG`: export current canvas (opens folder picker).
- `SaveCfg / LoadCfg`: save or restore canvas, palette, and pixel data.
- `Restore`: restore original source state (single image or selected frame).
- `BestPal`: recommend a better preset for the current source.
- `Analyze`: analyze current source and generate `Image Pixels`.
- `Limit`: set dynamic palette color count.
- `Max`: reset to the current maximum available color count.
- `Tolerance`: control color merging strength (`0-100`).

### Top-Right Quick Buttons

- `EN/中`: language toggle.
- `FR`: import sprite sheet and open frame-splitting workflow.
- `OF`: enter frame offset mode; click again in `ApplyOfs` state to apply offset.
- `Gen`: compose all preview frames into one sheet PNG.

### Bottom Frame Preview

- Left click on a frame: load it into the main canvas.
- Right click on a frame: open per-frame rectangle fine-tune mode.
- Keyboard `←/→`: switch selected frame.

### Transparency Panel

- Right click a color in the left palette: add/remove transparency key color.
- `AlphaTol`: expand similar colors into transparency set.
- Right click a transparency chip: remove that color from transparency set.
- `ApplyAll`: apply current transparency rule to all frames.

## Typical Workflows

### Single-Image Workflow

1. Import a reference image.
2. Click `BestPal` (optional).
3. Click `Analyze`, then tune style with `Limit / Tolerance`.
4. Hand-edit pixels and export PNG.

### Sprite-Sheet Workflow

1. Click top-right `FR` and import a sprite sheet.
2. Set rows/cols in the split window and confirm frame regions.
3. Switch frames in the bottom strip and edit frame-by-frame.
4. Use transparency rules and frame offset for batch or fine adjustments.
5. Click top-right `Gen` to export the composed sheet.

## Output and Files

- PNG output directory: selected by user from the system folder picker on each export.
- Config file: `res://configs/pixel_canvas_config.json`
- Main scene: `res://scenes/pixel_painter.tscn`
- Core script: `res://scripts/pixel_painter.gd`

Config key fields:

- `grid`: canvas width, height, and cell size.
- `palette`: current palette (HEX).
- `pixels`: 2D pixel index array (`-1` means transparent).
- `meta.preset_name`: current preset palette name.

## Run

1. Open the project with Godot `4.6`.
2. Run `res://scenes/pixel_painter.tscn` (already configured as main scene).
