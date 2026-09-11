#!/home/ixdire/.pyenv/bin/python
"""
Extract Firefox Gemini cookies for bdrestrolimd@gmail.com (or latest profile),
validate them, write to ~/.local/share/gemini-chat/cookies.json, and restart Gemini-FastAPI.
"""

import asyncio
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

from gemini_webapi import GeminiClient
from gemini_webapi.constants import AccountStatus

FIREFOX_DIR = Path.home() / ".mozilla" / "firefox"
TARGET_COOKIE_FILE = Path.home() / ".local" / "share" / "gemini-chat" / "cookies.json"
TARGET_EMAIL = "bdrestrolimd"


def find_profile_cookies(email_query: str = TARGET_EMAIL):
    """
    Search Firefox profiles for the best profile match for email_query
    and return the latest __Secure-1PSID and __Secure-1PSIDTS cookies.
    """
    if not FIREFOX_DIR.exists():
        print(f"Error: Firefox directory {FIREFOX_DIR} not found.")
        sys.exit(1)

    candidates = []
    for profile_dir in FIREFOX_DIR.glob("*"):
        if not profile_dir.is_dir():
            continue
        cookie_db = profile_dir / "cookies.sqlite"
        if not cookie_db.exists():
            continue

        # Check if profile matches email_query in places.sqlite or sessionstore
        email_matched = False
        places_db = profile_dir / "places.sqlite"
        if places_db.exists():
            try:
                with open(places_db, "rb") as f:
                    if email_query.encode("utf-8").lower() in f.read().lower():
                        email_matched = True
            except Exception:
                pass

        # Safely copy cookies.sqlite to temp file (prevents DB lock if Firefox is running)
        with tempfile.NamedTemporaryFile(suffix=".sqlite") as tmp:
            try:
                shutil.copyfile(cookie_db, tmp.name)
                conn = sqlite3.connect(tmp.name)
                c = conn.cursor()
                c.execute("""
                    SELECT name, value, datetime(lastAccessed/1000000, "unixepoch")
                    FROM moz_cookies
                    WHERE host LIKE "%google.com%" AND name IN ("__Secure-1PSID", "__Secure-1PSIDTS")
                    ORDER BY lastAccessed DESC
                """)
                rows = c.fetchall()
                conn.close()

                psid, psidts, last_accessed = None, None, None
                for name, val, t in rows:
                    if name == "__Secure-1PSID" and not psid:
                        psid = val
                        last_accessed = t
                    elif name == "__Secure-1PSIDTS" and not psidts:
                        psidts = val

                if psid:
                    candidates.append({
                        "profile_name": profile_dir.name,
                        "email_matched": email_matched,
                        "last_accessed": last_accessed or "",
                        "psid": psid,
                        "psidts": psidts or "",
                    })
            except Exception:
                pass

    if not candidates:
        print(f"No Google cookies found in any Firefox profile in {FIREFOX_DIR}.")
        sys.exit(1)

    # Sort: matching email profile first, then by most recent access
    candidates.sort(key=lambda x: (x["email_matched"], x["last_accessed"]), reverse=True)
    return candidates[0]


async def validate_cookies(psid: str, psidts: str):
    """Test cookies using gemini_webapi initialization."""
    print("Testing extracted cookies with Gemini Web API...")
    client = GeminiClient(secure_1psid=psid, secure_1psidts=psidts)
    try:
        await client.init(timeout=20)
        is_ok = client.account_status == AccountStatus.AVAILABLE
        return is_ok, client.account_status.name, client.account_status.description
    except Exception as e:
        return False, "ERROR", str(e)


def restart_fastapi_server():
    """Restart gemini-fastapi tmux session."""
    print("Restarting Gemini-FastAPI tmux session...")
    cmd = (
        "tmux kill-session -t gemini-fastapi 2>/dev/null; "
        "cd /home/ixdire/Water/crap/srcgit/Gemini-FastAPI && "
        "tmux new-session -d -s gemini-fastapi '/home/ixdire/.pyenv/bin/python run.py'"
    )
    res = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True)
    if res.returncode == 0:
        print("✓ Gemini-FastAPI server restarted successfully.")
    else:
        print(f"Warning: Server restart command output: {res.stderr or res.stdout}")


def main():
    print(f"Searching Firefox profiles for account matching '{TARGET_EMAIL}'...")
    best = find_profile_cookies(TARGET_EMAIL)
    print(
        f"Selected Firefox Profile: {best['profile_name']} "
        f"(Email Match: {best['email_matched']}, Last Access: {best['last_accessed']})"
    )

    # Validate cookies asynchronously
    is_valid, status_name, status_desc = asyncio.run(
        validate_cookies(best["psid"], best["psidts"])
    )

    print(f"Cookie Auth Check: {status_name} — {status_desc}")

    if not is_valid:
        print("\n⚠️ WARNING: The cookies extracted from Firefox are UNAUTHENTICATED or EXPIRED.")
        print(f"Please open Firefox (profile: {best['profile_name']}), navigate to https://gemini.google.com,")
        print(f"ensure you are logged into {TARGET_EMAIL}@gmail.com, and run this script again.")
        sys.exit(1)

    # Save to cookies.json
    TARGET_COOKIE_FILE.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "__Secure-1PSID": best["psid"],
        "__Secure-1PSIDTS": best["psidts"],
    }
    TARGET_COOKIE_FILE.write_text(json.dumps(data, indent=2))
    TARGET_COOKIE_FILE.chmod(0o600)
    print(f"✓ Updated persistent cookies at {TARGET_COOKIE_FILE}")

    # Restart FastAPI server
    restart_fastapi_server()
    print("Done!")


if __name__ == "__main__":
    main()
