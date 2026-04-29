# Godot Pixel Painter

An **Godot 4**-based pixel art tool with canvas drawing, preset palettes, image quantization, palette recommendation, frame-splitting workflow, and image color analysis with palette reduction.
It is especially suitable for post-processing and style unification of AI-generated pixel art.

Great for:
- Pixel character sketches
- Fast reference-to-pixel conversion
- Palette experiments and limited-color practice

## Features

- Multiple canvas sizes: `16x16` to `64x64`
- Preset palettes: retro and thematic color sets
- Bilingual UI: quick toggle between Chinese/English
- Pick-and-quantize workflow: select image from file dialog and auto-quantize
- Palette recommendation: evaluate presets and switch to the best match
- Image color analysis: build dynamic palette `Image Pixels`
- Color count limit: set max color count (capped by detected image colors), with `Max` shortcut
- Color tolerance (`0-100`): merge similar colors and remap pixels
- Sprite-sheet workflow: import sheet, split frames, preview strip, keyboard frame switching
- Frame offset tool: drag green snapped overlay on main canvas and apply to current frame
- Compose sheet: pack previewed frames into a near-square atlas and export PNG
- View controls: middle-mouse pan, mouse-wheel zoom
- PNG export: saved to `res://output/`
- JSON import/export: save and restore canvas, palette, and pixel data

## Requirements

- Godot `4.6` (project feature set is `4.6`)
- Windows/macOS/Linux

## Quick Start

1. Clone the repo:

```bash
git clone https://github.com/<your-name>/godot-pixel.git
cd godot-pixel
```

2. Open the project folder with Godot 4.6.
3. Run the main scene (`res://scenes/pixel_painter.tscn`).

## Usage

### Basic Drawing

- Left click: paint
- Right click: erase
- Number keys `1-9`: pick first 9 palette colors
- Arrow keys `←/→`: switch selected preview frame
- `C`: clear canvas
- `E`: export PNG

### Large Canvas Navigation

- Middle mouse drag: pan canvas
- Mouse wheel: zoom canvas (centered on cursor)

### Reference Image Workflow

1. Click `选择图片像素化` (Pick image to quantize) and select an image (auto-quantizes to current palette).
2. Click `推荐调色板` (Recommend palette) to switch to the best preset.

### Dynamic Palette and Color Reduction

1. Click `分析图像像素` (Analyze image pixels) to generate dynamic palette `此图像素`.
2. Use `限色` (Color limit) to reduce palette size.
3. Adjust `宽容度 (0-100)` (Tolerance) to control merge strength:
- `0`: only identical colors merge
- `100`: aggressive merging, significantly fewer color groups

After reduction, removed colors are automatically remapped using nearest-color matching.

### Sprite-Sheet Workflow

1. Click top-right `帧` button and choose a sprite sheet.
2. In split window, adjust `Rows/Cols`; green grid updates in real time.
3. Bottom preview strip appears:
- Left click: load frame to editor canvas
- Right click: open per-frame rectangle fine-tune mode
4. Once a frame is selected, recommendation/analysis/tolerance/limit calculations use that frame region as source.

### Frame Offset (Canvas Shift Semantics)

1. Select a frame from bottom preview first.
2. Click top-right `偏` (`OF`) to enter offset mode (`ApplyOfs` state).
3. Drag the green translucent grid overlay directly on main canvas (grid-snapped).
4. Click again to apply: content is projected onto the new canvas position and replaces original frame.

### Compose Full Sheet

- Click `生成整图` (`Compose`) to pack preview frames into a near-square grid and export to `res://output/`.

## Project Structure

```text
godot-pixel/
├─ scenes/
│  └─ pixel_painter.tscn          # Main scene
├─ scripts/
│  └─ pixel_painter.gd            # Core logic (UI, drawing, import/export, algorithms)
├─ configs/
│  ├─ pixel_canvas_config.json    # Canvas/palette/pixel config
│  └─ reference.png               # Default reference image
├─ output/                        # PNG export directory
└─ project.godot                  # Godot project config
```

## Config File

Path: `res://configs/pixel_canvas_config.json`

Main fields:
- `grid`: canvas width, height, cell size
- `palette`: current palette (HEX)
- `pixels`: 2D pixel index array (`-1` means empty/transparent)
- `meta.preset_name`: current preset name

## Roadmap (Optional)

- Show current reference path and recent history
- One-key fit/center canvas view
- Dithering mode
- Palette import/export (`.gpl` / `.hex`)

## Contributing

Issues and pull requests are welcome.

---

If this project helps you, a Star is appreciated.
