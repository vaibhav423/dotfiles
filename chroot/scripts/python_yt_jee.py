#!/usr/bin/env python3
import sys
import os
import time
from pathlib import Path

# Add path to common utils
# sys.path.append(os.path.expanduser("~/Water/crap/scripts"))
from yt_utils import parse_seconds, process_url

def get_config_paths():
    try:
        vault_base = Path("/sdcard/Documents/Fire/")
        pinned_rel = Path((vault_base / "pinned").read_text().strip())
        pinned_folder_name = pinned_rel.name
        
        image_dir = vault_base / "Assets" / pinned_folder_name
        image_dir.mkdir(parents=True, exist_ok=True)
        
        md_file = vault_base / pinned_rel / f"{pinned_folder_name}.md"
        md_file.parent.mkdir(parents=True, exist_ok=True)
        
        return image_dir, md_file, pinned_folder_name
    except Exception as e:
        print(f"Error resolving paths: {e}")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 script.py <URL>")
        return

    target_url = sys.argv[1]
    image_dir, md_file, pinned_name = get_config_paths()
    
    seconds = parse_seconds(target_url)
    
    # In original script, it uses epoch time for the jpg filename
    filename = f"{int(time.time())}.jpg"
    abs_image_path = image_dir / filename
    
    chapter_title, success = process_url(target_url, abs_image_path)
    
    if not success:
        print("Error: Failed to process and capture image.")
        return

    rel_image_path = f"Assets/{pinned_name}/{filename}"
    md_line = f"![{chapter_title}]({rel_image_path}) [link]({target_url})\n"
    
    with open(md_file, "a") as f:
        f.write(md_line)
    
    print(f"Success: Added entry to {md_file.name}")

if __name__ == "__main__":
    main()
