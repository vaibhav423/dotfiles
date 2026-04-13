

import os
import sys
import shutil
import sqlite3
import subprocess
import requests
from datetime import datetime
import pytz
import tempfile
from urllib.parse import unquote


# Paths modeled after scaler-cookies.sh
DB_PATH = "/data/data/org.mozilla.firefox/files/mozilla/5zle4puh.default/cookies.sqlite"
TEMP_DB = "/sdcard/cookies-copy.sqlite"

URL = "https://www.scaler.com/academy/mentee/events"


def extract_scaler_cookies(db_path=DB_PATH, temp_db=TEMP_DB):
    """Return a tuple (cookie_header, cookie_dict).

    cookie_header is a string suitable for a `Cookie` header.
    cookie_dict is a mapping of cookie-name -> cookie-value for use with
    `requests.Session().cookies.update()`.

    If a regular copy fails due to permissions, try using `sudo cp` to copy
    only the DB file (so the rest of the script can run without root).
    """
    used_db = db_path
    created_temp = False

    # First try a normal copy to the preferred temp location
    try:
        shutil.copy2(db_path, temp_db)
        try:
            os.chmod(temp_db, 0o600)
        except Exception:
            # chmod may fail for non-root, that's okay
            pass
        used_db = temp_db
        created_temp = True
    except Exception:
        # If normal copy fails, attempt to use sudo to copy the DB only
        sudo = shutil.which('sudo')
        if sudo:
            try:
                subprocess.run([sudo, 'cp', db_path, temp_db], check=True)
                subprocess.run([sudo, 'chmod', '600', temp_db], check=False)
                used_db = temp_db
                created_temp = True
            except Exception:
                created_temp = False

        # If sudo copy didn't work, try system temp fallback (may still fail)
        if not created_temp:
            try:
                tf = tempfile.NamedTemporaryFile(delete=False)
                tf.close()
                shutil.copy2(db_path, tf.name)
                try:
                    os.chmod(tf.name, 0o600)
                except Exception:
                    pass
                used_db = tf.name
                created_temp = True
            except Exception:
                # Fall back to original DB (may fail if locked or permission denied)
                used_db = db_path

    rows = []
    try:
        conn = sqlite3.connect(used_db)
        try:
            cur = conn.cursor()
            cur.execute("SELECT name, value FROM moz_cookies WHERE host LIKE '%scaler.com%';")
            rows = cur.fetchall()
        finally:
            conn.close()
    except Exception:
        rows = []

    # Clean up temporary copy if we created one; try sudo rm if plain remove fails
    try:
        if created_temp and used_db != db_path and os.path.exists(used_db):
            try:
                os.remove(used_db)
            except Exception:
                sudo = shutil.which('sudo')
                if sudo:
                    try:
                        subprocess.run([sudo, 'rm', '-f', used_db], check=False)
                    except Exception:
                        pass
    except Exception:
        pass

    cookie_dict = {}
    for name, value in rows:
        if name is None or value is None:
            continue
        cookie_dict[name] = value

    if not cookie_dict:
        return "", {}

    # Build cookie header string
    cookie_parts = [f"{k}={v}" for k, v in cookie_dict.items()]
    return "; ".join(cookie_parts), cookie_dict


def parse_utc_datetime(dt_str):
    """Parse a UTC datetime string from the scaler API into a timezone-aware UTC datetime.

    Handles formats like:
      2025-01-02T15:04:05.000Z
      2025-01-02T15:04:05Z
    Returns None if parsing fails.
    """
    if not dt_str:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            dt = datetime.strptime(dt_str, fmt)
            # treat as UTC
            return pytz.utc.localize(dt)
        except Exception:
            continue
    # Last resort: try fromisoformat after replacing Z
    try:
        iso = dt_str.replace("Z", "+00:00")
        return datetime.fromisoformat(iso)
    except Exception:
        return None


def format_event_schedule_with_cookies(cookie_header, cookie_dict=None):
    headers = {
        "User-Agent": "Mozilla/5.0 (Android 16; Mobile; rv:147.0) Gecko/147.0 Firefox/147.0",
        "Accept": "*/*",
        "Accept-Language": "en-US",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Referer": "https://www.scaler.com/academy/mentee-dashboard/todos",
        "X-Requested-With": "XMLHttpRequest",
        "App-Name": "desktop",
        "sec-fetch-dest": "empty",
        "sec-fetch-mode": "cors",
        "sec-fetch-site": "same-origin",
        "TE": "trailers",
    }

    session = requests.Session()

    # Apply cookies to session if present
    if cookie_dict:
        session.cookies.update(cookie_dict)

    # Prefer an explicit x-user-token header if we can find a token in cookies
    #token_candidates = [
 #       ('x-user-token', cookie_dict.get('x-user-token') if cookie_dict else None),
 #       ('auth_session_id', cookie_dict.get('auth_session_id') if cookie_dict else None),
 #       ('remember_user_token', cookie_dict.get('remember_user_token') if cookie_dict else None),
 #   ]
 #   for key, val in token_candidates:
 #       if val:
 #           try:
 #               headers['x-user-token'] = unquote(val)
 #           except Exception:
 #               headers['x-user-token'] = val
 #           break

    # If we have an XSRF cookie, set the X-CSRF-Token header to its URL-decoded value
    #xsrf = None
    #if cookie_dict:
        #xsrf = cookie_dict.get('XSRF-TOKEN') or cookie_dict.get('xsrf-token')
    #if xsrf:
        #try:
            #headers['X-CSRF-Token'] = unquote(xsrf)
        #except Exception:
            #headers['X-CSRF-Token'] = xsrf

    # Some code paths may expect a Cookie header; include it if we built one
    if cookie_header:
        headers['Cookie'] = cookie_header

    try:
        resp = session.get(URL, headers=headers, timeout=15)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"Failed to fetch events: {e}")
        return

    events = data.get("futureEvents") or data.get("events") or []
    if not events:
        print("No future events found.")
        return

    grouped_events = {}
    ist = pytz.timezone('Asia/Kolkata')

    for event in events:
        dt_str = event.get('date') or event.get('start') or event.get('datetime')
        utc_dt = parse_utc_datetime(dt_str)
        if not utc_dt:
            continue
        ist_dt = utc_dt.astimezone(ist)

        date_key = ist_dt.date()  # group by date object for correct sorting
        time_str = ist_dt.strftime("%I:%M %p").lstrip('0').lower()
        title = event.get('title') or event.get('name') or ''

        grouped_events.setdefault(date_key, []).append((ist_dt, time_str, title))

    if not grouped_events:
        print("No parsable future events.")
        return

    # Sort dates and within each date sort by time
    for date in sorted(grouped_events.keys()):
        print(f"[{date.strftime('%a %d/%m/%Y')}]")
        print("----------------")
        sessions = sorted(grouped_events[date], key=lambda t: t[0])
        for _, time_str, title in sessions:
            print(f"[{time_str}] : {title}")
        print("-" * 99)


if __name__ == "__main__":
    cookie_header, cookie_dict = extract_scaler_cookies()
    if not cookie_dict:
        print("No scaler.com cookies found or failed to extract cookies.")
        # still try without cookies; some endpoints may be public
        format_event_schedule_with_cookies("", {})
        sys.exit(0)

    format_event_schedule_with_cookies(cookie_header, cookie_dict)
