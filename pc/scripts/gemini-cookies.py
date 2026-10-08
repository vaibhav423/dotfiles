#!/home/ixdire/.pyenv/bin/python
"""
Copy the Gemini cookies of one Firefox profile to ~/.local/share/gemini/cookies.json.

A profile holds one Google account, so the profile *is* the account - there is nothing
to look up, resolve or guess. Gemini-FastAPI uses the "fastapi" profile by default. To
use a different account, sign it into another Firefox profile and pass its name here.

Usage:
    gemini-cookies                    # cookies for the "fastapi" profile
    gemini-cookies work               # cookies for the profile named "work"
    gemini-cookies --restart          # ... and restart Gemini-FastAPI
"""

import argparse
import configparser
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

FIREFOX_DIR = Path.home() / ".mozilla" / "firefox"
PROFILES_INI = FIREFOX_DIR / "profiles.ini"
DATA_DIR = Path.home() / ".local" / "share" / "gemini"
COOKIE_FILE = DATA_DIR / "cookies.json"
DEFAULT_PROFILE = "fastapi"
COOKIE_NAMES = ("__Secure-1PSID", "__Secure-1PSIDTS")

SESSION = "gemini-fastapi"
START_SCRIPT = Path.home() / "Water" / "crap" / "scripts" / "start-gemini-fastapi.sh"
SERVER_DIR = Path.home() / "Water" / "crap" / "srcgit" / "Gemini-FastAPI"


def profile_path(name: str) -> Path:
    """Firefox names profile directories <random>.<name>, so profiles.ini does the lookup."""
    ini = configparser.ConfigParser()
    ini.read(PROFILES_INI)
    profiles = {
        ini[s]["Name"]: ini[s]["Path"] for s in ini.sections() if s.startswith("Profile")
    }
    if name not in profiles:
        sys.exit(f"No Firefox profile named {name!r}. Known profiles: {', '.join(profiles)}")
    return FIREFOX_DIR / profiles[name]


def read_cookies(profile: Path) -> dict:
    """The two session cookies, taking the most recently used of each."""
    db = profile / "cookies.sqlite"
    if not db.exists():
        sys.exit(f"{profile} has no cookies.sqlite - has this profile ever been run?")

    with tempfile.NamedTemporaryFile(suffix=".sqlite", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        # Copied because Firefox holds a lock on the live database.
        shutil.copyfile(db, tmp_path)
        rows = sqlite3.connect(tmp_path).execute(
            f"""
            SELECT name, value FROM moz_cookies
            WHERE host LIKE '%google.com%' AND name IN ({",".join("?" * len(COOKIE_NAMES))})
            ORDER BY lastAccessed DESC
            """,
            COOKIE_NAMES,
        ).fetchall()
    finally:
        Path(tmp_path).unlink(missing_ok=True)

    found: dict[str, str] = {}
    for cookie_name, value in rows:
        found.setdefault(cookie_name, value)

    missing = [n for n in COOKIE_NAMES if not found.get(n)]
    if missing:
        sys.exit(
            f"{profile.name} is not signed in to Google - missing {', '.join(missing)}.\n"
            "Log into gemini.google.com in that profile first."
        )
    return {n: found[n] for n in COOKIE_NAMES}


def write_cookies(cookies: dict) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = COOKIE_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(cookies, indent=2))
    os.chmod(tmp, 0o600)
    # Renamed, so a half-written file can never be read as valid credentials.
    tmp.replace(COOKIE_FILE)


def restart_server() -> None:
    if START_SCRIPT.exists():
        cmd = f"'{START_SCRIPT}'"
    else:
        cmd = f"cd {SERVER_DIR} && exec {Path.home()}/.pyenv/bin/python run.py"
    res = subprocess.run(
        [
            "bash",
            "-c",
            f"tmux kill-session -t {SESSION} 2>/dev/null; "
            f"tmux new-session -d -s {SESSION} {cmd}",
        ],
        capture_output=True,
        text=True,
    )
    print("  server restarted" if res.returncode == 0 else f"  restart failed: {res.stderr.strip()}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("profile", nargs="?", default=DEFAULT_PROFILE, help="Firefox profile name")
    parser.add_argument("--restart", action="store_true", help="restart Gemini-FastAPI")
    args = parser.parse_args()

    cookies = read_cookies(profile_path(args.profile))
    write_cookies(cookies)

    print(f"  {args.profile} -> {COOKIE_FILE}")
    for name in COOKIE_NAMES:
        print(f"  {name:18} {cookies[name][:14]}...")

    if args.restart:
        restart_server()


if __name__ == "__main__":
    main()
