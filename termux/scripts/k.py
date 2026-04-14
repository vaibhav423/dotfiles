import sys  
from pathlib import Path

def get_config_paths():
    """Resolves paths based on /sdcard/ configuration files."""
    try:
        # 1. Base vault path
        vault_base = Path(Path("/sdcard/vault").read_text().strip())
        
        # 2. Pinned relative path
        pinned_rel = Path(Path("/sdcard/pinned").read_text().strip())
        
        # Name of the folder (e.g., 'Chemistry')
        pinned_folder_name = pinned_rel.name
        
        # Image Dir: {vault}/Assets/{folder_name_of_pinned}
        image_dir = vault_base / "Assets" / pinned_folder_name
        print(image_dir)
        image_dir.mkdir(parents=True, exist_ok=True)
        
        # Markdown File: {vault}/{pinned_rel}/{folder_name_of_pinned}.md
        md_file = vault_base / pinned_rel / f"{pinned_folder_name}.md"
        
        return image_dir, md_file, pinned_folder_name
    except Exception as e:
        print(f"Error resolving paths: {e}")
        sys.exit(1)

get_config_paths()
