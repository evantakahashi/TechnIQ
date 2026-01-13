#!/usr/bin/env python3
"""
Updates Xcode asset catalog with sliced avatar images.
Copies PNG files from sliced_assets/ to Assets.xcassets/Avatar/
"""

import os
import shutil
import json

SLICED_DIR = "/Users/evantakahashi/Desktop/TechnIQ/sliced_assets"
ASSETS_DIR = "/Users/evantakahashi/Desktop/TechnIQ/TechnIQ/Assets.xcassets/Avatar"

# Map sliced folder names to asset catalog folder names
FOLDER_MAP = {
    "bodies": "Bodies",
    "hair": "Hair",
    "faces": "Faces",
    "jerseys": "Jerseys",
    "shorts": "Shorts",
    "socks": "Socks",
    "cleats": "Cleats"
}

CONTENTS_JSON = {
    "images": [
        {
            "idiom": "universal",
            "scale": "1x"
        },
        {
            "idiom": "universal",
            "scale": "2x"
        },
        {
            "idiom": "universal",
            "scale": "3x"
        }
    ],
    "info": {
        "author": "xcode",
        "version": 1
    }
}

FOLDER_CONTENTS_JSON = {
    "info": {
        "author": "xcode",
        "version": 1
    }
}


def create_imageset(asset_folder, image_name, image_path):
    """Create an imageset folder with the image and Contents.json."""
    imageset_name = image_name.replace(".png", "")
    imageset_path = os.path.join(asset_folder, f"{imageset_name}.imageset")

    # Create imageset folder
    os.makedirs(imageset_path, exist_ok=True)

    # Copy image file
    dest_image_path = os.path.join(imageset_path, image_name)
    shutil.copy2(image_path, dest_image_path)

    # Create Contents.json with filename
    contents = CONTENTS_JSON.copy()
    contents["images"] = [
        {
            "filename": image_name,
            "idiom": "universal",
            "scale": "1x"
        },
        {
            "idiom": "universal",
            "scale": "2x"
        },
        {
            "idiom": "universal",
            "scale": "3x"
        }
    ]

    contents_path = os.path.join(imageset_path, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(contents, f, indent=2)

    return imageset_name


def main():
    print("=" * 60)
    print("TechnIQ Avatar Asset Catalog Updater")
    print("=" * 60)

    total_count = 0

    for sliced_folder, asset_folder in FOLDER_MAP.items():
        sliced_path = os.path.join(SLICED_DIR, sliced_folder)
        asset_path = os.path.join(ASSETS_DIR, asset_folder)

        if not os.path.exists(sliced_path):
            print(f"\nSKIPPED: {sliced_folder} - source folder not found")
            continue

        print(f"\nProcessing {sliced_folder} -> {asset_folder}")

        # Remove existing imagesets (but keep Contents.json)
        if os.path.exists(asset_path):
            for item in os.listdir(asset_path):
                item_path = os.path.join(asset_path, item)
                if item.endswith(".imageset"):
                    shutil.rmtree(item_path)
        else:
            os.makedirs(asset_path)

        # Ensure folder Contents.json exists
        folder_contents_path = os.path.join(asset_path, "Contents.json")
        if not os.path.exists(folder_contents_path):
            with open(folder_contents_path, "w") as f:
                json.dump(FOLDER_CONTENTS_JSON, f, indent=2)

        # Copy each PNG to an imageset
        count = 0
        for filename in sorted(os.listdir(sliced_path)):
            if filename.endswith(".png"):
                image_path = os.path.join(sliced_path, filename)
                create_imageset(asset_path, filename, image_path)
                count += 1

        print(f"  Created {count} imagesets")
        total_count += count

    print("\n" + "=" * 60)
    print(f"Asset catalog updated! Total: {total_count} imagesets")
    print("=" * 60)


if __name__ == "__main__":
    main()
