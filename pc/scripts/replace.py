import os
import re


def main():
    # Regular expression to match the exact block you described.
    # We use \r?\n to handle both Windows and Linux line endings.
    # \1 captures the 'Assets/...' part so we can keep it in the replacement.
    pattern = re.compile(
        r"# gallery\r?\n"
        r"```img-gallery\r?\n"
        r"path: (Assets/[^\r\n]+)\r?\n"
        r"type: vertical\r?\n"
        r"mobile: 3\r?\n"
        r"columns: 3\r?\n"
        r"gutter: 2\r?\n"
        r"radius: 20\r?\n"
        r"```"
    )

    # The replacement string utilizing the captured path (\1)
    replacement = "# gallery\n```img-gallery\npath: \\1\n```"

    cwd = os.getcwd()
    print(f"Scanning directory: {cwd}")

    for root, dirs, files in os.walk(cwd):
        # Exclude the .git directory so we don't accidentally corrupt repository data
        if ".git" in dirs:
            dirs.remove(".git")

        for file in files:
            filepath = os.path.join(root, file)

            try:
                # Read the file content
                with open(filepath, "r", encoding="utf-8") as f:
                    content = f.read()

                # Perform the substitution and get the replacement count
                new_content, count = pattern.subn(replacement, content)

                # If matches were found, write the updated content back to the file
                if count > 0:
                    with open(filepath, "w", encoding="utf-8", newline="\n") as f:
                        f.write(new_content)
                    print(f"✅ Updated {count} occurrence(s) in: {filepath}")

            except UnicodeDecodeError:
                # Skip binary files like images, PDFs, etc.
                pass
            except Exception as e:
                print(f"⚠️  Could not process {filepath}: {e}")


if __name__ == "__main__":
    main()
