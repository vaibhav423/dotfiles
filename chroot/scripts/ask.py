import asyncio
import sys
import argparse
import os
import subprocess
import tempfile

# --- Monkey-patch browser_cookie3 to support Firefox on Android/Termux ---
try:
    import browser_cookie3

    # Check if we're on a Linux-like system (Android is linux)
    if sys.platform.startswith("linux"):
        android_firefox_path = "/data/data/org.mozilla.firefox/files/mozilla"

        # We patch the FirefoxBased class which is used by Firefox, LibreWolf, etc.
        original_firefoxbased_init = browser_cookie3.FirefoxBased.__init__

        def patched_firefoxbased_init(
            self,
            browser_name,
            cookie_file=None,
            domain_name="",
            key_file=None,
            **kwargs,
        ):
            if browser_name == "Firefox" and "linux_data_dirs" in kwargs:
                if android_firefox_path not in kwargs["linux_data_dirs"]:
                    kwargs["linux_data_dirs"].insert(0, android_firefox_path)
            return original_firefoxbased_init(
                self, browser_name, cookie_file, domain_name, key_file, **kwargs
            )

        browser_cookie3.FirefoxBased.__init__ = patched_firefoxbased_init
except ImportError:
    pass
# ------------------------------------------------------------------------

from gemini_webapi import GeminiClient, set_log_level

# List of models supported by the web API (as per the library's constants and current availability)
# Note: these are the strings accepted by the 'model' parameter in the library
AVAILABLE_MODELS = [
    "unspecified",
    "gemini-3-pro",
    "gemini-3-flash",
    "gemini-3-flash-thinking",
]

DEFAULT_MODEL = "unspecified"


def print_help():
    print("Usage: ask.py [-q] [-t] [-p] [--select-model] [--list-models] [prompt]")
    print("  -q                       Use model gemini-3-flash")
    print("  -t                       Use model gemini-3-flash-thinking")
    print(
        "  -p, --persistent         Save conversation to history (Disabled by default)"
    )
    print("  --list-models            Show all available Gemini models")
    print("  --select-model           Select a model from the list")
    print("  --help                   Show this help message")
    print("  prompt                   The prompt to send to Gemini")


def list_models():
    print("Available models:")
    for model in AVAILABLE_MODELS:
        print(f"  {model}")


def select_model_interactive():
    try:
        # Check if fzf is available
        subprocess.run(["fzf", "--version"], capture_output=True, check=True)
        models_input = "\n".join(AVAILABLE_MODELS)
        result = subprocess.run(
            ["fzf", "--prompt=Select Gemini model: "],
            input=models_input,
            capture_output=True,
            text=True,
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("fzf not found. Falling back to basic selector.")
        for i, model in enumerate(AVAILABLE_MODELS):
            print(f"{i + 1}) {model}")
        try:
            choice = input("Select a model number: ")
            if choice.isdigit():
                idx = int(choice)
                if 1 <= idx <= len(AVAILABLE_MODELS):
                    return AVAILABLE_MODELS[idx - 1]
        except EOFError:
            pass
    return None


def open_editor_for_input():
    editor = os.environ.get("EDITOR", "nvim")
    with tempfile.NamedTemporaryFile(suffix=".md", delete=False) as tf:
        tf_path = tf.name

    try:
        subprocess.run([editor, tf_path], check=True)
        with open(tf_path, "r") as f:
            content = f.read().strip()
        return content
    finally:
        if os.path.exists(tf_path):
            os.remove(tf_path)


async def main():
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--help", action="store_true")
    parser.add_argument("--list-models", action="store_true")
    parser.add_argument("--select-model", action="store_true")
    parser.add_argument("-q", action="store_true")
    parser.add_argument("-t", action="store_true")
    parser.add_argument("-p", "--persistent", action="store_true")
    parser.add_argument("prompt", nargs="*", default=[])

    args, unknown = parser.parse_known_args()

    if args.help:
        print_help()
        return

    if args.list_models:
        list_models()
        return

    model_name = DEFAULT_MODEL
    if args.q:
        model_name = "gemini-3-flash"
    elif args.t:
        model_name = "gemini-3-flash-thinking"

    if args.select_model:
        selected = select_model_interactive()
        if selected:
            model_name = selected
        else:
            print("No model selected.")
            return

    prompt = " ".join(args.prompt)

    # If no prompt provided via args, check stdin or open editor
    if not prompt:
        if not sys.stdin.isatty():
            # Reading from piped input
            prompt = sys.stdin.read().strip()
        else:
            # Interactive input
            print(
                "Enter your prompt (Press Ctrl+D to submit, or type 'e' then enter to open nvim):"
            )
            # Basic fallback for interactive multiline input
            try:
                line = input("> ")
                if line.strip() == "e":
                    prompt = open_editor_for_input()
                else:
                    prompt = line + "\n"
                    while True:
                        line = input("> ")
                        prompt += line + "\n"
            except (EOFError, KeyboardInterrupt):
                prompt = prompt.strip()

    if not prompt:
        print("Error: No prompt provided.")
        print_help()
        return

    # Use glow to print the model name if available
    try:
        subprocess.run(
            ["glow"], input=f"Model: {model_name}\n---\n", text=True, check=True
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"Model: {model_name}")

    set_log_level("WARNING")
    client = GeminiClient()

    try:
        await client.init(timeout=30, auto_close=False, auto_refresh=True)

        # Use streaming to match the behavior of the bash script
        full_text = ""
        # The library returns delta chunks

        async for chunk in client.generate_content_stream(
            prompt, model=model_name, temporary=not args.persistent
        ):
            delta = chunk.text_delta
            if delta:
                print(delta, end="", flush=True)
                full_text += delta
        print("\n")  # Newline at the end

    except Exception as e:
        print(f"\nError: {e}")
        sys.exit(1)
    finally:
        await client.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
