# Godot Pixel Painter

An **Godot 4**-based pixel art tool with canvas drawing, preset palettes, reference image quantization, palette recommendation, and image color analysis with palette reduction.

Great for:
- Pixel character sketches
- Fast reference-to-pixel conversion
- Palette experiments and limited-color practice

## Features

- Multiple canvas sizes: `16x16` to `64x64`
- Preset palettes: retro and thematic color sets
- Reference image quantization: map image colors to the current palette
- Palette recommendation: evaluate presets and switch to the best match
- Image color analysis: build dynamic palette `Image Pixels`
- Color count limit: set max color count (capped by detected image colors)
- Color tolerance (`0-100`): merge similar colors and remap pixels
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
- `C`: clear canvas
- `E`: export PNG

### Large Canvas Navigation

- Middle mouse drag: pan canvas
- Mouse wheel: zoom canvas (centered on cursor)

### Reference Image Workflow

1. Click `选择图片像素化` (Pick image to quantize) and select an image.
2. Click `推荐调色板` (Recommend palette) to switch to the best preset.
3. Click `参考图像素化` (Quantize reference) to map the image to current palette.

### Dynamic Palette and Color Reduction

1. Click `分析图像像素` (Analyze image pixels) to generate dynamic palette `此图像素`.
2. Use `限色` (Color limit) to reduce palette size.
3. Adjust `宽容度 (0-100)` (Tolerance) to control merge strength:
- `0`: only identical colors merge
- `100`: aggressive merging, significantly fewer color groups

After reduction, removed colors are automatically remapped using nearest-color matching.

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
