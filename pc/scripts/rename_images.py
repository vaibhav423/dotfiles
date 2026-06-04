import re
import os

md_path = "/sdcard/Documents/Fire/MPC/Physics/Physics/Waves/Opticsandwave.md"
assets_dir = "/sdcard/Documents/Fire/Assets/optics"

with open(md_path, 'r') as f:
    content = f.read()

# Find all image links
pattern = r'\]\(Assets/optics/([^)]+)\)'
matches = re.findall(pattern, content)

# Generate temporary renames
temp_renames = []
new_content = content
for i, filename in enumerate(matches, 1):
    old_path = os.path.join(assets_dir, filename)
    ext = filename.split('.')[-1]
    temp_filename = f"temp_{i}.{ext}"
    temp_path = os.path.join(assets_dir, temp_filename)
    
    if os.path.exists(old_path):
        os.rename(old_path, temp_path)
    
    new_content = new_content.replace(f"Assets/optics/{filename}", f"Assets/optics/{temp_filename}", 1)

# Generate final renames
final_content = new_content
for i, filename in enumerate(matches, 1):
    ext = filename.split('.')[-1]
    temp_filename = f"temp_{i}.{ext}"
    final_filename = f"{i}.{ext}"
    
    temp_path = os.path.join(assets_dir, temp_filename)
    final_path = os.path.join(assets_dir, final_filename)
    
    if os.path.exists(temp_path):
        os.rename(temp_path, final_path)
    
    final_content = final_content.replace(f"Assets/optics/{temp_filename}", f"Assets/optics/{final_filename}", 1)

with open(md_path, 'w') as f:
    f.write(final_content)

print(f"Renamed {len(matches)} files.")
