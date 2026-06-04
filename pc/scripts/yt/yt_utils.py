#!/usr/bin/env python3
import sys
import re
import json
import time
import subprocess
from pathlib import Path

def parse_seconds(url):
    match = re.search(r'[?&]t=([^&#]+)', url)
    if not match: return None
    
    t_str = match.group(1)
    h = int(re.search(r'(\d+)h', t_str).group(1)) if 'h' in t_str else 0
    m = int(re.search(r'(\d+)m', t_str).group(1)) if 'm' in t_str else 0
    s = int(re.search(r'(\d+)s', t_str).group(1)) if 's' in t_str else 0
    
    if any(x in t_str for x in 'hms'):
        return h * 3600 + m * 60 + s
    
    try:
        return int(t_str)
    except ValueError:
        return None

def fetch_yt_data(url, cookie_browser=None):
    clean_url = re.sub(r'[?&]t=[^&]*', '', url)
    
    cmd = ["yt-dlp", "-j", "-f", "bestvideo"]
    if cookie_browser:
        cmd.extend(["--cookies-from-browser", cookie_browser])
    cmd.append(clean_url)
    
    # Add logging for yt-dlp error
    import logging
    try:
        logging.getLogger().debug(f"Running yt-dlp command: {' '.join(cmd)}")
    except:
        pass
        
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        try:
            logging.getLogger().error(f"yt-dlp failed with returncode {result.returncode}")
            logging.getLogger().error(f"yt-dlp stderr: {result.stderr}")
        except:
            pass
        return None, [], {}

    try:
        data = json.loads(result.stdout)
        return data.get('url'), data.get('chapters', []), data.get('http_headers', {})
    except json.JSONDecodeError as e:
        try:
            logging.getLogger().error(f"Failed to parse JSON from yt-dlp: {e}")
        except:
            pass
        return None, [], {}

def get_chapter_title(chapters, seconds):
    if not seconds or not chapters:
        return ""
    
    for ch in chapters:
        start = ch.get('start_time', 0)
        end = ch.get('end_time', float('inf'))
        if start <= seconds < end:
            return ch.get('title', "")
    return ""

def capture_frame(stream_url, headers, seconds, abs_image_path):
    ffmpeg_cmd = ["ffmpeg", "-y", "-loglevel", "error"]
    
    if headers:
        header_str = "".join(f"{k}: {v}\r\n" for k, v in headers.items())
        ffmpeg_cmd += ["-headers", header_str]

    if seconds:
        ts_formatted = time.strftime('%H:%M:%S', time.gmtime(seconds))
        ffmpeg_cmd += ["-ss", ts_formatted]
    
    ffmpeg_cmd += ["-i", stream_url, "-frames:v", "1", "-q:v", "2", str(abs_image_path)]
    subprocess.run(ffmpeg_cmd)

    return Path(abs_image_path).exists()

def process_url(url, abs_image_path, cookie_browser=None):
    seconds = parse_seconds(url)
    stream_url, chapters, headers = fetch_yt_data(url, cookie_browser)
    
    if not stream_url:
        return None, False

    chapter_title = get_chapter_title(chapters, seconds)
    success = capture_frame(stream_url, headers, seconds, abs_image_path)
    return chapter_title, success

if __name__ == "__main__":
    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        
        if cmd == "--cli" and len(sys.argv) == 4:
            # Usage: yt_utils.py --cli <url> <out_path>
            url = sys.argv[2]
            out_path = sys.argv[3]
            chapter, ok = process_url(url, out_path)
            print(json.dumps({"chapter": chapter, "success": ok}))
            
        elif cmd == "--info" and len(sys.argv) == 3:
            # Usage: yt_utils.py --info <url>
            # Returns all info needed so caller can proceed async
            url = sys.argv[2]
            seconds = parse_seconds(url)
            stream_url, chapters, headers = fetch_yt_data(url)
            chapter_title = get_chapter_title(chapters, seconds)
            
            print(json.dumps({
                "chapter": chapter_title,
                "seconds": seconds,
                "stream_url": stream_url,
                "headers": headers
            }))
            
        elif cmd == "--capture" and len(sys.argv) == 6:
            # Usage: yt_utils.py --capture <stream_url> <seconds> <headers_json> <out_path>
            stream_url = sys.argv[2]
            seconds = int(sys.argv[3]) if sys.argv[3] != "None" else None
            headers = json.loads(sys.argv[4])
            out_path = sys.argv[5]
            
            success = capture_frame(stream_url, headers, seconds, out_path)
            sys.exit(0 if success else 1)
