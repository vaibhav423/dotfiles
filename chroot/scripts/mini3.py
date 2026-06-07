from flask import Flask, send_file, redirect, Response, request
import os
import sys
import re
import urllib.parse
import mimetypes
import time
import datetime
import json
import threading
import signal

app = Flask(__name__)

# Global variable to store the file path
TARGET_FILE = None

def get_file_type(filename):
    """Get simple file type for display"""
    extension = os.path.splitext(filename)[1].lower()
    
    # File type mapping
    type_mapping = {
        # Applications
        '.apk': 'Android App',
        '.exe': 'Windows App',
        '.deb': 'Linux Package',
        '.dmg': 'macOS App',
        
        # Archives
        '.zip': 'ZIP Archive',
        '.rar': 'RAR Archive',
        '.7z': '7Z Archive',
        '.tar': 'TAR Archive',
        '.gz': 'GZ Archive',
        
        # Documents
        '.pdf': 'PDF Document',
        '.doc': 'Word Document',
        '.docx': 'Word Document',
        '.txt': 'Text File',
        '.rtf': 'Rich Text',
        
        # Images
        '.jpg': 'JPEG Image',
        '.jpeg': 'JPEG Image',
        '.png': 'PNG Image',
        '.gif': 'GIF Image',
        '.bmp': 'BMP Image',
        
        # Audio
        '.mp3': 'MP3 Audio',
        '.wav': 'WAV Audio',
        '.m4a': 'M4A Audio',
        
        # Video
        '.mp4': 'MP4 Video',
        '.avi': 'AVI Video',
        '.mkv': 'MKV Video',
        '.mov': 'MOV Video',
        
        # Code
        '.py': 'Python Script',
        '.js': 'JavaScript',
        '.html': 'HTML File',
        '.css': 'CSS File',
        '.php': 'PHP File',
        '.java': 'Java File',
    }
    
    return type_mapping.get(extension, 'File')

def format_size(size):
    if size < 1024:
        return f"{size} B"
    elif size < 1024 * 1024:
        return f"{size/1024:.1f} KB"
    else:
        return f"{size/(1024*1024):.1f} MB"

def format_time(seconds):
    if seconds < 60:
        return f"{seconds:.0f}s"
    elif seconds < 3600:
        minutes = seconds // 60
        seconds = seconds % 60
        return f"{minutes:.0f}m {seconds:.0f}s"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        seconds = seconds % 60
        return f"{hours:.0f}h {minutes:.0f}m {seconds:.0f}s"

class TransferTracker:
    def __init__(self, total_size, filename):
        self.total_size = total_size
        self.filename = filename
        self.bytes_sent = 0
        self.start_time = None
        self.last_update_time = None
        self.last_bytes = 0
        self.current_speed = 0
        self.active = False
        self.is_browser_check = False
        self.max_speed = 0
        self.min_speed = float('inf')
        self.json_file = 'current.json'
        self.stop_flag = False
        self.status = "pending"
        # Initialize the JSON file
        self.write_json(0, 0, 0)
        
        # Start a thread to continuously update the JSON file
        self.update_thread = threading.Thread(target=self.json_update_loop)
        self.update_thread.daemon = True
        self.update_thread.start()
     
    def write_json(self, percent, speed, elapsed):
    # Calculate ETA
     if speed > 0:
        remaining_bytes = self.total_size - self.bytes_sent
        eta_seconds = remaining_bytes / speed
        eta = format_time(eta_seconds)
     else:
        eta = "--"

     data = {
        "filesize": format_size(self.total_size),
        "currentpercent": f"{percent:.1f}",
        "integer":int(percent),
        "currentspeed": f"{format_size(speed)}/s",
        "elapsed": format_time(elapsed),
        "eta": eta,
        "time": datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S'),
        "user": os.getenv('USER', 'unknown'),
        "status": self.status 
     }
     try:
        with open('/sdcard/' +self.json_file, 'w') as f:
            json.dump(data, f, indent=2)
     except Exception as e:
        print(f"\nError writing JSON: {e}")

    def json_update_loop(self):
        while not self.stop_flag:
            if self.active and not self.is_browser_check:
                current_time = time.time()
                elapsed = current_time - self.start_time if self.start_time else 0
                percent = (self.bytes_sent / self.total_size * 100) if self.total_size > 0 else 0
                self.write_json(percent, self.current_speed, elapsed)
            time.sleep(0.5)

    def start(self):
        self.start_time = time.time()
        self.last_update_time = self.start_time
        self.active = True
        if not self.is_browser_check:
            print(f"\nTransfer started: {self.filename}")
            print(f"Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): {datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S')}")
            print(f"Current User's Login: {os.getenv('USER', 'unknown')}")

    def update(self, bytes_sent):
        if not self.active:
            self.start()
        
        if self.is_browser_check:
            return

        current_time = time.time()
        time_diff = current_time - self.last_update_time
        
        if time_diff >= 0.5:  # Update every 0.5 seconds
            bytes_diff = bytes_sent - self.last_bytes
            self.current_speed = bytes_diff / time_diff
            
            # Update min/max speeds
            if self.current_speed > 0:
                self.max_speed = max(self.max_speed, self.current_speed)
                self.min_speed = min(self.min_speed, self.current_speed)
            
            self.last_update_time = current_time
            self.last_bytes = bytes_sent
            
            # Calculate percentage and progress bar
            percentage = (bytes_sent / self.total_size) * 100
            bar_length = 25
            filled_length = int(bar_length * bytes_sent // self.total_size)
            bar = '=' * filled_length + '>' + ' ' * (bar_length - filled_length)
            
            # Calculate ETA
            if self.current_speed > 0:
                eta_seconds = (self.total_size - bytes_sent) / self.current_speed
                eta_str = format_time(eta_seconds)
            else:
                eta_str = "--"
            
            # Calculate elapsed time
            elapsed = current_time - self.start_time
            elapsed_str = format_time(elapsed)
            
            # Clear line and print progress
            print(f"\r[{bar}] {percentage:0.1f} of {format_size(self.total_size)} | "
                  f"Speed: {format_size(self.current_speed)}/s | "
                  f"ETA: {eta_str} | "
                  f"Elapsed: {elapsed_str}", 
                  end="", flush=True)

    def finish(self):
        if self.active and not self.is_browser_check:
            duration = time.time() - self.start_time
            if duration > 0:
                avg_speed = self.bytes_sent / duration
                print(f"\n\nTransfer Summary:")
                print(f"Status: Completed")
                print(f"File: {self.filename}")
                print(f"Size: {format_size(self.total_size)}")
                print(f"Time: {format_time(duration)}")
                print(f"Avg Speed: {format_size(avg_speed)}/s")
                if self.max_speed > 0:
                    print(f"Max Speed: {format_size(self.max_speed)}/s")
                if self.min_speed < float('inf'):
                    print(f"Min Speed: {format_size(self.min_speed)}/s")
                print(f"Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): {datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"Current User's Login: {os.getenv('USER', 'unknown')}")
                
                # Write final status to JSON
                self.status = "completed"
                self.write_json(100, avg_speed, duration)
        
        self.stop_flag = True
        self.active = False

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def index(path):
    """Handle all requests by redirecting to download"""
    headers = {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0'
    }
    
    if not TARGET_FILE or not os.path.exists(TARGET_FILE):
        return "No file available", 404, headers
    return redirect('/download'), 302, headers

@app.route('/download')
def download_file():
    try:
        if not TARGET_FILE or not os.path.exists(TARGET_FILE):
            return "File not found", 404
            
        filename = os.path.basename(TARGET_FILE)
        
        # Get mime type
        mime_type = mimetypes.guess_type(filename)[0] or 'application/octet-stream'
        
        return send_file(
            TARGET_FILE,
            mimetype=mime_type,
            as_attachment=True,
            download_name=filename,
            conditional=True
        )

    except Exception as e:
        return str(e), 500


def signal_handler(signum, frame):
    print("\nShutting down server...")
    try:
        # Clear the JSON file
        with open('/sdcard/current.json', 'w') as f:
            json.dump({
                "filesize": "0 B",
                "currentpercent": "0",
                "currentspeed": "0 B/s",
                "elapsed": "0s",
                "eta": "--",
                "status": "stopped",
                "time": datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S'),
                "user": os.getenv('USER', 'unknown')
            }, f, indent=2)
    except:
        pass
    sys.exit(0)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python3 script.py /path/to/file")
        sys.exit(1)

    TARGET_FILE = os.path.abspath(sys.argv[1])
    
    if not os.path.exists(TARGET_FILE):
        print(f"Error: File not found: {TARGET_FILE}")
        sys.exit(1)

    print(f"Starting server...")
    print(f"Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): {datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Current User's Login: {os.getenv('USER', 'unknown')}")
    print(f"Serving: {os.path.basename(TARGET_FILE)} ({format_size(os.path.getsize(TARGET_FILE))})")
    
    # Register signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        mimetypes.init()
        mimetypes.add_type('application/vnd.android.package-archive', '.apk')
        # Configure Flask for better portal detection and connection handling
        app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 0
        app.run(
            host='0.0.0.0',
            port=8080,
            threaded=True
        )
    except Exception as e:
        print(f"Error: {e}")
