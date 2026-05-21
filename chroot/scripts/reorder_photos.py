#!/usr/bin/python3
import os
import re
import sys
import argparse

def process_markdown(md_file_path, base_dir):
    md_file_path = os.path.abspath(md_file_path)
    if not os.path.exists(md_file_path):
        print(f"Error: File '{md_file_path}' does not exist.")
        sys.exit(1)
        
    with open(md_file_path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    # Find all markdown images: ![](path)
    pattern = r'!\[.*?\]\((.*?)\)'
    image_paths = re.findall(pattern, content)
    
    if not image_paths:
        print("No images found in the markdown file.")
        return
        
    print(f"Found {len(image_paths)} images. Renaming...")
    
    new_content = content
    temp_paths = []
    
    # Step 1: Rename to temporary files to avoid naming collisions
    # (e.g., renaming 2.png to 1.png when 1.png already exists)
    for i, raw_img_path in enumerate(image_paths, 1):
        img_path = raw_img_path.strip()
        
        # Resolve absolute path of the image
        if os.path.isabs(img_path):
            abs_img_path = img_path
        else:
            abs_img_path = os.path.join(base_dir, img_path)
            
        if not os.path.exists(abs_img_path):
            print(f"Warning: Image not found at {abs_img_path}, skipping.")
            temp_paths.append((raw_img_path, None, None, None, None))
            continue
            
        ext = os.path.splitext(abs_img_path)[1]
        img_dir = os.path.dirname(abs_img_path)
        
        temp_name = f"__temp_rename_{i}{ext}"
        temp_abs_path = os.path.join(img_dir, temp_name)
        
        os.rename(abs_img_path, temp_abs_path)
        
        # Replace in markdown content (first pass)
        img_md_dir = os.path.dirname(img_path)
        temp_md_path = os.path.join(img_md_dir, temp_name).replace("\\", "/")
        
        # Use a safe replace that only targets the exact markdown syntax
        old_md_link = f"]({raw_img_path})"
        new_md_link = f"]({temp_md_path})"
        new_content = new_content.replace(old_md_link, new_md_link, 1)
        
        temp_paths.append((temp_md_path, temp_abs_path, img_dir, ext, img_path))

    # Step 2: Rename from temp files to sequential numbers
    final_content = new_content
    success_count = 0
    
    for i, data in enumerate(temp_paths, 1):
        if data[1] is None:
            continue
            
        temp_md_path, temp_abs_path, img_dir, ext, orig_img_path = data
        
        final_name = f"{i}{ext}"
        final_abs_path = os.path.join(img_dir, final_name)
        
        os.rename(temp_abs_path, final_abs_path)
        
        # Replace in markdown content (second pass)
        img_md_dir = os.path.dirname(orig_img_path)
        final_md_path = os.path.join(img_md_dir, final_name).replace("\\", "/")
        
        old_md_link = f"]({temp_md_path})"
        new_md_link = f"]({final_md_path})"
        final_content = final_content.replace(old_md_link, new_md_link, 1)
        
        success_count += 1

    # Write the updated content back to the markdown file
    with open(md_file_path, 'w', encoding='utf-8') as f:
        f.write(final_content)
        
    print(f"Successfully renamed {success_count} images!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Rename images in a Markdown file sequentially.")
    parser.add_argument("markdown_file", help="Path to the markdown file")
    parser.add_argument("--base-dir", default=os.getcwd(), help="Base directory for relative image paths (defaults to current working directory)")
    
    args = parser.parse_args()
    process_markdown(args.markdown_file, args.base_dir)
