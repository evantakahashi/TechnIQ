#!/usr/bin/env python3
"""
Avatar Sprite Sheet Slicer for TechnIQ - Version 2.0
Slices properly-layered sprite sheets into individual PNG files.

NEW in v2.0:
- Standard 512x768 cell size for all assets
- No cropping needed (assets pre-positioned correctly)
- Transparency validation
- Updated file naming conventions
"""

from PIL import Image
import os
import shutil

# Configuration
DOWNLOADS_DIR = "/Users/evantakahashi/Downloads"
OUTPUT_DIR = "/Users/evantakahashi/Desktop/TechnIQ/sliced_assets"

# Standard canvas size for all assets (2:3 ratio)
STANDARD_WIDTH = 512
STANDARD_HEIGHT = 768

# Sprite sheet file mappings (new naming convention)
SPRITE_SHEETS = {
    "bodies": "bodies_spritesheet.png",
    "hair": "hair_spritesheet.png",
    "faces": "faces_spritesheet.png",
    "jerseys": "jerseys_spritesheet.png",
    "shorts": "shorts_spritesheet.png",
    "socks": "socks_spritesheet.png",
    "cleats": "cleats_spritesheet.png",
}

# Naming conventions for each asset type
BODY_NAMES = [
    "light", "light_medium", "medium",
    "medium_tan", "tan", "brown",
    "dark_brown", "dark", "deep"
]

HAIR_STYLES = [
    "short_wavy", "medium_wavy", "long_wavy", "buzz_cut",
    "crew_cut", "afro", "braided", "slicked_back"
]

HAIR_COLORS = [
    "black", "dark_brown", "brown", "auburn", "red",
    "strawberry_blonde", "blonde", "platinum", "white"
]

FACE_NAMES = [
    "happy", "determined", "cool",
    "excited", "focused", "celebrating"
]

JERSEY_NAMES = [
    "starter_green", "classic_white", "striker_red", "royal_blue",
    "brazil_yellow", "barcelona_style", "classic_black", "orange_blaze"
]

SHORTS_NAMES = [
    "starter_white", "classic_black", "matching_green",
    "blue_athletic", "red_sport"
]

SOCKS_NAMES = [
    "green_striped", "white_classic", "black_athletic", "matching_color"
]

CLEATS_NAMES = [
    "starter_green", "classic_black", "speed_white",
    "gold_elite", "neon_blue"
]


def ensure_dir(path):
    """Create directory if it doesn't exist."""
    os.makedirs(path, exist_ok=True)


def validate_dimensions(img, cols, rows, asset_type):
    """Validate sprite sheet has correct dimensions for standard cell size."""
    expected_width = cols * STANDARD_WIDTH
    expected_height = rows * STANDARD_HEIGHT
    actual_width, actual_height = img.size

    if actual_width != expected_width or actual_height != expected_height:
        print(f"  WARNING: {asset_type} has dimensions {actual_width}x{actual_height}")
        print(f"           Expected {expected_width}x{expected_height} ({cols}x{rows} grid)")
        return False
    return True


def check_transparency(cell, name):
    """Check if image has transparent areas (RGBA mode with alpha < 255)."""
    if cell.mode != 'RGBA':
        print(f"  WARNING: {name} is not RGBA mode (no transparency support)")
        return False

    alpha = cell.split()[3]
    extrema = alpha.getextrema()

    if extrema == (255, 255):
        print(f"  WARNING: {name} has NO transparency (alpha is all 255)")
        return False

    return True


def slice_standard_grid(img, cols, rows, names, output_dir, prefix, validate=True):
    """
    Slice a sprite sheet using standard 512x768 cell size.
    No cropping needed - assets should be pre-positioned correctly.
    """
    ensure_dir(output_dir)

    # Validate dimensions
    if validate:
        validate_dimensions(img, cols, rows, prefix)

    # Calculate actual cell size (in case dimensions don't match perfectly)
    actual_cell_width = img.width // cols
    actual_cell_height = img.height // rows

    idx = 0
    saved_count = 0

    for row in range(rows):
        for col in range(cols):
            if idx >= len(names):
                break

            # Calculate cell bounds
            left = col * actual_cell_width
            top = row * actual_cell_height
            right = left + actual_cell_width
            bottom = top + actual_cell_height

            # Crop cell
            cell = img.crop((left, top, right, bottom))

            # Resize to standard size if needed
            if cell.width != STANDARD_WIDTH or cell.height != STANDARD_HEIGHT:
                cell = cell.resize((STANDARD_WIDTH, STANDARD_HEIGHT), Image.Resampling.LANCZOS)

            name = names[idx]
            filename = f"{prefix}_{name}.png"

            # Check for transparency
            check_transparency(cell, filename)

            # Save
            filepath = os.path.join(output_dir, filename)
            cell.save(filepath, "PNG")
            print(f"  Saved: {filename} ({STANDARD_WIDTH}x{STANDARD_HEIGHT})")

            saved_count += 1
            idx += 1

    return saved_count


def slice_hair(img, output_dir):
    """Slice hair sprite sheet (9 columns x 8 rows = 72 variants)."""
    ensure_dir(output_dir)

    # Validate dimensions
    validate_dimensions(img, cols=9, rows=8, asset_type="hair")

    # Calculate actual cell size
    actual_cell_width = img.width // 9
    actual_cell_height = img.height // 8

    saved_count = 0

    for row_idx, style in enumerate(HAIR_STYLES):
        for col_idx, color in enumerate(HAIR_COLORS):
            left = col_idx * actual_cell_width
            top = row_idx * actual_cell_height
            right = left + actual_cell_width
            bottom = top + actual_cell_height

            cell = img.crop((left, top, right, bottom))

            # Resize to standard size if needed
            if cell.width != STANDARD_WIDTH or cell.height != STANDARD_HEIGHT:
                cell = cell.resize((STANDARD_WIDTH, STANDARD_HEIGHT), Image.Resampling.LANCZOS)

            filename = f"hair_{style}_{color}.png"

            # Check for transparency
            check_transparency(cell, filename)

            filepath = os.path.join(output_dir, filename)
            cell.save(filepath, "PNG")
            print(f"  Saved: {filename}")

            saved_count += 1

    return saved_count


def main():
    """Main function to slice all sprite sheets."""
    print("=" * 60)
    print("TechnIQ Avatar Sprite Sheet Slicer v2.0")
    print(f"Standard cell size: {STANDARD_WIDTH}x{STANDARD_HEIGHT}")
    print("=" * 60)

    # Create output directory
    if os.path.exists(OUTPUT_DIR):
        print(f"\nRemoving existing output directory: {OUTPUT_DIR}")
        shutil.rmtree(OUTPUT_DIR)
    os.makedirs(OUTPUT_DIR)

    # Track results
    results = {}

    # Process bodies (3x3 = 9)
    filename = SPRITE_SHEETS["bodies"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing bodies: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "bodies")
        results["bodies"] = slice_standard_grid(img, cols=3, rows=3, names=BODY_NAMES,
                                                 output_dir=output_dir, prefix="body")
    else:
        print(f"\nSKIPPED: bodies - file not found: {filename}")
        results["bodies"] = 0

    # Process hair (10x8 = 80)
    filename = SPRITE_SHEETS["hair"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing hair: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "hair")
        results["hair"] = slice_hair(img, output_dir)
    else:
        print(f"\nSKIPPED: hair - file not found: {filename}")
        results["hair"] = 0

    # Process faces (3x2 = 6)
    filename = SPRITE_SHEETS["faces"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing faces: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "faces")
        results["faces"] = slice_standard_grid(img, cols=3, rows=2, names=FACE_NAMES,
                                                output_dir=output_dir, prefix="face")
    else:
        print(f"\nSKIPPED: faces - file not found: {filename}")
        results["faces"] = 0

    # Process jerseys (4x2 = 8)
    filename = SPRITE_SHEETS["jerseys"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing jerseys: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "jerseys")
        results["jerseys"] = slice_standard_grid(img, cols=4, rows=2, names=JERSEY_NAMES,
                                                  output_dir=output_dir, prefix="jersey")
    else:
        print(f"\nSKIPPED: jerseys - file not found: {filename}")
        results["jerseys"] = 0

    # Process shorts (3x2 = 5, last cell empty)
    filename = SPRITE_SHEETS["shorts"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing shorts: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "shorts")
        results["shorts"] = slice_standard_grid(img, cols=3, rows=2, names=SHORTS_NAMES,
                                                 output_dir=output_dir, prefix="shorts")
    else:
        print(f"\nSKIPPED: shorts - file not found: {filename}")
        results["shorts"] = 0

    # Process socks (4x1 = 4)
    filename = SPRITE_SHEETS["socks"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing socks: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "socks")
        results["socks"] = slice_standard_grid(img, cols=4, rows=1, names=SOCKS_NAMES,
                                                output_dir=output_dir, prefix="socks")
    else:
        print(f"\nSKIPPED: socks - file not found: {filename}")
        results["socks"] = 0

    # Process cleats (3x2 = 5, last cell empty)
    filename = SPRITE_SHEETS["cleats"]
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    if os.path.exists(filepath):
        print(f"\nProcessing cleats: {filepath}")
        img = Image.open(filepath)
        print(f"  Source: {img.width}x{img.height}")
        output_dir = os.path.join(OUTPUT_DIR, "cleats")
        results["cleats"] = slice_standard_grid(img, cols=3, rows=2, names=CLEATS_NAMES,
                                                 output_dir=output_dir, prefix="cleats")
    else:
        print(f"\nSKIPPED: cleats - file not found: {filename}")
        results["cleats"] = 0

    # Summary
    print("\n" + "=" * 60)
    print("Slicing complete!")
    print(f"Output directory: {OUTPUT_DIR}")
    print("=" * 60)

    total = 0
    for asset_type, count in results.items():
        print(f"  {asset_type}: {count} images")
        total += count
    print(f"  TOTAL: {total} images")

    print("\n" + "=" * 60)
    print("Expected sprite sheet filenames in Downloads:")
    for asset_type, filename in SPRITE_SHEETS.items():
        status = "FOUND" if results.get(asset_type, 0) > 0 else "MISSING"
        print(f"  [{status}] {filename}")
    print("=" * 60)


if __name__ == "__main__":
    main()
