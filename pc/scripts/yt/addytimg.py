#!/usr/bin/env python3
import sys
import os
import json
import logging
import re
from pathlib import Path
import subprocess

# Setup logging
log_file = os.path.expanduser("/tmp/addytimg.log")
logging.basicConfig(
    filename=log_file,
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Add path to common utils
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from yt_utils import parse_seconds, process_url

def get_config_paths():
    config_path = os.path.expanduser("~/.config/personal/config.json")
    logging.debug(f"Reading config from {config_path}")
    with open(config_path, "r") as f:
        config = json.load(f)
    
    vaultdir = os.path.expanduser(config.get("vaultdir", ""))
    logging.debug(f"Vaultdir: {vaultdir}")
    
    pinned_file_path = os.path.join(vaultdir, "pinned_file")
    logging.debug(f"Reading pinned file from {pinned_file_path}")
    with open(pinned_file_path, "r") as f:
        md_file = f.read().strip()
    logging.debug(f"Target markdown file relative/absolute path: {md_file}")
        
    md_file_path = Path(md_file)
    if not md_file_path.is_absolute():
        md_file_path = Path(vaultdir) / md_file_path
    logging.debug(f"Absolute markdown file path: {md_file_path}")
        
    rel_image_dir = "Assets"
    if md_file_path.exists():
        try:
            content = md_file_path.read_text()
            match = re.search(r'#\s*gallery.*?```img-gallery.*?path:\s*([^\n]+).*?```', content, re.DOTALL | re.IGNORECASE)
            if match:
                rel_image_dir = match.group(1).strip()
                logging.info(f"Found gallery path in markdown: {rel_image_dir}")
        except Exception as e:
            logging.error(f"Failed to read markdown file for gallery path: {e}")
            
    image_dir = Path(vaultdir) / rel_image_dir
    logging.debug(f"Ensuring image directory exists: {image_dir}")
    image_dir.mkdir(parents=True, exist_ok=True)
    
    return image_dir, md_file_path, vaultdir, rel_image_dir

def set_red_dot(state):
    state_file = Path("/tmp/yt-processing")
    if state:
        state_file.touch()
    else:
        if state_file.exists():
            state_file.unlink()
    subprocess.run(["pkill", "-RTMIN+8", "waybar"])

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Add youtube image to vault")
    parser.add_argument("--cookie", help="Browser to extract cookies from (e.g., firefox)", default=None)
    args = parser.parse_args()

    url = sys.stdin.read().strip()
    logging.info(f"Received URL: '{url}'")
    
    if not url:
        logging.error("Empty URL received.")
        return
    if "youtu" not in url:
        logging.error("URL does not contain 'youtu'")
        return
    if "?t=" not in url and "&t=" not in url:
        logging.error("URL does not contain a timestamp (?t= or &t=)")
        return
        
    try:
        image_dir, md_file, vaultdir, rel_image_dir = get_config_paths()
    except Exception as e:
        logging.error(f"Error reading config: {e}", exc_info=True)
        print(f"Error reading config: {e}")
        return

    seconds = parse_seconds(url)
    logging.info(f"Parsed seconds: {seconds}")
    if seconds is None:
        logging.error("Failed to parse seconds from URL")
        return

    logging.debug("Setting red dot state to True")
    set_red_dot(True)
    
    import time
    
    try:
        timestamp = int(time.time())
        filename = f"{timestamp}.png"
        abs_image_path = image_dir / filename
        logging.info(f"Target image path: {abs_image_path}")
        
        logging.debug("Calling process_url...")
        chapter_title, success = process_url(url, abs_image_path, cookie_browser=args.cookie)
        logging.info(f"process_url returned success={success}, chapter='{chapter_title}'")
        
        if success:
            # Generate the image path using the dynamically found relative directory
            imgpath = f"{rel_image_dir}/{timestamp}.png"
            md_line = f"\n[{chapter_title}]({imgpath})[link]({url})\n"
            logging.info(f"Writing to markdown file: {md_line.strip()}")
            
            with open(md_file, "a") as f:
                f.write(md_line)
        else:
            logging.error("Image capture failed.")
    except Exception as e:
        logging.error(f"Unexpected error during processing: {e}", exc_info=True)
    finally:
        logging.debug("Setting red dot state to False")
        set_red_dot(False)

if __name__ == "__main__":
    main()
