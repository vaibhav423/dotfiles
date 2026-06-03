import os
from pathlib import Path

def init_and_pin_dir():
    # 1. Get the respective paths and convert to Path objects
    # Added .strip() to remove hidden newlines
    try:
        vault_path = Path(open('/sdcard/vault').read().strip())
        pinned_file_path = Path(open("/sdcard/pinned").read().strip())
    except FileNotFoundError:
        print("Error: Configuration files not found in /sdcard/")
        return

    # 2. Get user input
    pinned_relative = input(f"Current Vault: {vault_path}\nEnter Pinned Path (relative to vault): ").strip()
    
    # Save the relative path back to the pinned config file
    with open(pinned_file_path, "w") as f:
        f.write(pinned_relative + "\n")

    # 3. Setup Directories
    full_pinned_dir = vault_path / pinned_relative
    full_pinned_dir.mkdir(parents=True, exist_ok=True)

    topic_name = full_pinned_dir.name
    assets_dir = vault_path / "Assets" / topic_name
    questions_dir = assets_dir / "questions"
    
    # Create asset subfolders
    questions_dir.mkdir(parents=True, exist_ok=True)

    # 4. Create Topic Markdown File
    topic_md_content = f"""# gallery
```img-gallery
path: Assets/{topic_name}
```
# general
[[{topic_name}-Questions]]
# images
"""
topic_file = full_pinned_dir / f"{topic_name}.md"
with open(topic_file, "w") as f:
f.write(topic_md_content)
# 5. Create Questions Markdown File
questions_md_content = f"""# gallery
```img-gallery
path: Assets/{topic_name}/questions
```
# general
# solve-tips
# Question
"""
questions_file = full_pinned_dir / f"{topic_name}-Questions.md"
with open(questions_file, "w") as f:
f.write(questions_md_content)
print(f"\n✅ Initialized: {topic_name}")
print(f"📍 Pinned to: {pinned_file_path}")
if name == "main":
init_and_pin_dir()
