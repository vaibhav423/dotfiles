import subprocess as sp, requests, pytz
from datetime import datetime as dt
from collections import defaultdict

# 1. Extract Cookies directly into a dict
DB = "/data/data/org.mozilla.firefox/files/mozilla/5zle4puh.default/cookies.sqlite"
CMD = f"sqlite3 {DB} \"SELECT name, value FROM moz_cookies WHERE host LIKE '%scaler.com%';\""
ua = {'User-Agent': 'Mozilla/5.0 (Android 16; Mobile; rv:147.0) Gecko/147.0 Firefox/147.0'}
raw = sp.check_output(['su', '-c', CMD], text=True)
ck = {l.split('|')[0]: l.split('|')[1] for l in raw.splitlines() if '|' in l}

# 2. Fetch and Group
res = requests.get("https://www.scaler.com/academy/mentee/events", cookies=ck, headers=ua).json()
events = (res.get("futureEvents") or []) + (res.get("events") or [])
grp = defaultdict(list)

for e in events:
    d = dt.fromisoformat(e.get('date') or e.get('start') or e.get('datetime')).astimezone(pytz.timezone('Asia/Kolkata'))
    grp[d.date()].append(f"[{d.strftime('%I:%M %p').lower()}] : {e.get('title') or e.get('name')}")

# 3. Print
for d in sorted(grp):
    print(f"\n[{d.strftime('%a %d/%m/%Y')}]\n" + "-"*20 + "\n" + "\n".join(grp[d]))

