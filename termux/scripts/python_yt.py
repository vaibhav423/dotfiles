
import sys
import re
import time
import json
import subprocess
from pathlib import Path

def get_config_paths():
    """Resolves paths based on Termux/Linux configuration files."""
    try:
        # Resolve the base vault path (Expand ~ if present in the config file)
        vault_raw = Path("/data/local/tmp/archl/home/fire/Water/Fire/vault").read_text().strip()
        vault_base = Path(vault_raw).expanduser()
        
        # Resolve the pinned relative path
        pinned_raw = Path("/data/local/tmp/archl/home/fire/Water/Fire/pinned").read_text().strip()
        pinned_rel = Path(pinned_raw)
        
        # Name of the folder (e.g., 'electrostatics')
        pinned_folder_name = pinned_rel.name
        
        # Image Dir: {vault}/Assets/{folder_name_of_pinned}
        image_dir = vault_base / "Assets" / pinned_folder_name
        image_dir.mkdir(parents=True, exist_ok=True)
        
        # Markdown File: {vault}/{pinned_rel}/{folder_name_of_pinned}.md
        # If pinned_rel is already an absolute path starting with ~, expand it
        if str(pinned_rel).startswith('~'):
            md_file = pinned_rel.expanduser()
        else:
            md_file = vault_base / pinned_rel / f"{pinned_folder_name}.md"
            
        # Ensure the directory for the markdown file exists
        md_file.parent.mkdir(parents=True, exist_ok=True)
        
        return image_dir, md_file, pinned_folder_name
    except Exception as e:
        print(f"Error resolving paths: {e}")
        sys.exit(1)

def parse_seconds(url):
    """Extracts ?t= timestamp and converts to total seconds."""
    match = re.search(r'[?&]t=([^&#]+)', url)
    if not match: return None
    
    t_str = match.group(1)
    # Match 1h2m3s format
    h = int(re.search(r'(\d+)h', t_str).group(1)) if 'h' in t_str else 0
    m = int(re.search(r'(\d+)m', t_str).group(1)) if 'm' in t_str else 0
    s = int(re.search(r'(\d+)s', t_str).group(1)) if 's' in t_str else 0
    
    if any(x in t_str for x in 'hms'):
        return h * 3600 + m * 60 + s
    
    try:
        # Clean non-numeric chars like 's' from '371s'
        clean_t = re.sub(r'[^0-9]', '', t_str)
        return int(clean_t)
    except ValueError:
        return None

def fetch_yt_data(url):
    """Uses yt-dlp to get stream URL and chapters."""
    clean_url = re.sub(r'[?&]t=[^&]*', '', url)
    print(f"Fetching metadata for: {clean_url}")
    
    cmd = ["yt-dlp", "-j", "-f", "bestvideo", clean_url]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: yt-dlp failed.\n{result.stderr}")
        return None, []

    try:
        data = json.loads(result.stdout)
        return data.get('url'), data.get('chapters', [])
    except json.JSONDecodeError:
        print("Error: Could not parse JSON from yt-dlp.")
        return None, []

def get_chapter_title(chapters, seconds):
    """Finds the chapter title for the given timestamp."""
    if seconds is None or not chapters:
        return "Screenshot"
    
    for ch in chapters:
        start = ch.get('start_time', 0)
        end = ch.get('end_time', float('inf'))
        if start <= seconds < end:
            return ch.get('title', "")
    return "Screenshot"

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 script.py <URL>")
        return

    target_url = sys.argv[1]
    image_dir, md_file, pinned_name = get_config_paths()
    
    # 1. Get Data
    seconds = parse_seconds(target_url)
    stream_url, chapters = fetch_yt_data(target_url)
    
    if not stream_url:
        print("Error: Failed to retrieve stream URL.")
        return

    chapter_title = get_chapter_title(chapters, seconds)
    
    # 2. Capture Frame
    filename = f"{int(time.time())}.jpg"
    abs_image_path = image_dir / filename
    
    ffmpeg_cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    if seconds is not None:
        ts_formatted = time.strftime('%H:%M:%S', time.gmtime(seconds))
        ffmpeg_cmd += ["-ss", ts_formatted]
    
    ffmpeg_cmd += ["-i", stream_url, "-frames:v", "1", "-q:v", "2", str(abs_image_path)]
    
    print(f"Capturing frame at {seconds}s to: {filename}")
    subprocess.run(ffmpeg_cmd)

    if not abs_image_path.exists():
        print("Error: FFmpeg failed to create image.")
        return

    # 3. Update Markdown
    # Assuming relative path for Obsidian/Markdown: Assets/{pinned_folder}/{filename}
    rel_image_path = f"Assets/{pinned_name}/{filename}"

    md_line = f"![{chapter_title}]({rel_image_path}) [link]({target_url})\n"
    
    try:
        with open(md_file, "a") as f:
            f.write(md_line)
        print(f"Success: Added entry to {md_file}")
    except Exception as e:
        print(f"Error writing to file: {e}")

if __name__ == "__main__":
    main()
