import sys
import os
import re
import shutil

def process_file(filepath):
    if not os.path.isfile(filepath):
        print(f"File not found: {filepath}")
        return

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the path under #gallery inside a markdown code block ```...```
    # We use [^`]*? to ensure we stay inside the backticks block
    gallery_match = re.search(r'#\s*gallery\s*```[^`]*?\bpath:\s*([^\n\r]+)', content, re.IGNORECASE)
    if not gallery_match:
        print(f"No '#gallery' with 'path:' inside a code block found in {filepath}")
        return

    target_rel_path = gallery_match.group(1).strip()
    
    cwd = os.getcwd()

    # Resolve target directory relative to the Current Working Directory (CWD)
    target_dir = os.path.abspath(os.path.join(cwd, target_rel_path))

    if not os.path.exists(target_dir):
        os.makedirs(target_dir)

    # Find all markdown image links: ![alt](path)
    img_pattern = re.compile(r'!\[([^\]]*)\]\(([^)]+)\)')
    
    new_content = content
    modified = False

    for match in img_pattern.finditer(content):
        alt_text = match.group(1)
        img_rel_path = match.group(2)
        
        # Skip web links
        if img_rel_path.startswith(('http://', 'https://')):
            continue
            
        # Resolve image path relative to the Current Working Directory (CWD)
        img_full_path = os.path.abspath(os.path.join(cwd, img_rel_path))
        
        if os.path.isfile(img_full_path):
            img_filename = os.path.basename(img_rel_path)
            dest_full_path = os.path.join(target_dir, img_filename)
            
            # Move the image file
            shutil.move(img_full_path, dest_full_path)
            print(f"Moved {img_full_path} to {dest_full_path}")
            
            # Update the markdown link to be relative to the CWD
            new_img_rel_path = os.path.relpath(dest_full_path, cwd).replace('\\', '/')
            new_content = new_content.replace(f']({img_rel_path})', f']({new_img_rel_path})')
            modified = True
        else:
            print(f"Image not found: {img_full_path}")

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated links in {filepath}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python move_to_gallery.py <filepath> ...")
        sys.exit(1)
        
    for arg in sys.argv[1:]:
        process_file(arg)
