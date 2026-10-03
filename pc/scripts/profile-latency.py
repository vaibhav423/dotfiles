"""Profile one chat request against a single model, end to end.

Reports: init, chat start, time to first token, total. Reuses one client so
init cost is paid once, not per request.
"""

import asyncio
import json
import sys
import time
from pathlib import Path

from gemini_webapi import GeminiClient

COOKIES = Path.home() / ".local" / "share" / "gemini-chat" / "cookies.json"
MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemini-pro"
ROUNDS = int(sys.argv[2]) if len(sys.argv) > 2 else 3


async def main() -> None:
    data = json.loads(COOKIES.read_text())

    t0 = time.time()
    client = GeminiClient(
        secure_1psid=data["__Secure-1PSID"],
        secure_1psidts=data["__Secure-1PSIDTS"],
    )
    await client.init(timeout=60)
    print(f"model      {MODEL}")
    print(f"status     {client.account_status.name}")
    print(f"init       {time.time() - t0:6.2f}s  (paid once, reused below)")

    for i in range(1, ROUNDS + 1):
        t0 = time.time()
        session = client.start_chat(model=MODEL)
        t_start = time.time() - t0

        t0 = time.time()
        first = None
        text = ""
        async for chunk in session.send_message_stream("Reply with the single word: OK"):
            if first is None:
                first = time.time() - t0
            text += chunk.text
        total = time.time() - t0

        print(
            f"round {i}    start_chat={t_start:5.2f}s  first_token={first:6.2f}s  "
            f"total={total:6.2f}s  -> {text.strip()[:30]!r}"
        )

    await client.close()


asyncio.run(main())
