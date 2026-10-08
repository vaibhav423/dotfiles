"""Test: can gemini-webapi drive a non-default Google account slot (/u/1/)?

gemini-webapi hardcodes slot-0 endpoints. Google selects the account by URL path, so
this shims the endpoint constants to /u/1/ and checks whether the other account answers.
"""

import asyncio
import json
import time
from pathlib import Path
from types import SimpleNamespace

import gemini_webapi.client as gc

PSID = "g.a000DAmXoZbP9_D-tR7cpb9wjr2BiwbNaHH7XGY0m7FL7tMTOX51VRAmU6F68xqVqn7zvvGWIQACgYKAV8SARYSFQHGX2MiLAYzkR3wwmY_49ZMdfvlaxoVAUF8yKrVnl8F4gPf0MlR5alXhb7N0076"
PSIDTS = "sidts-CjEBkldj_0wHewzMAaPX6PjO2Bf06DT7AIhXTIQ3mZ46WwhRIfBFHrNHYXsxdl_gcY_fEAA"
SLOT = "/u/1"


def shim(slot: str) -> SimpleNamespace:
    base = f"https://gemini.google.com{slot}"
    return SimpleNamespace(
        GOOGLE="https://www.google.com",
        INIT=f"{base}/app",
        GENERATE=f"{base}/_/BardChatUi/data/assistant.lamda.BardFrontendService/StreamGenerate",
        BATCH_EXEC=f"{base}/_/BardChatUi/data/batchexecute",
        ROTATE_COOKIES="https://accounts.google.com/RotateCookies",
        UPLOAD="https://content-push.googleapis.com/upload",
    )


async def main() -> None:
    orig = gc.Endpoint
    gc.Endpoint = shim(SLOT)
    try:
        client = gc.GeminiClient(secure_1psid=PSID, secure_1psidts=PSIDTS)
        await client.init(timeout=60)
        print("status:", client.account_status.name, flush=True)
        models = client.list_models() or []
        print("models:", [m.model_name for m in models], flush=True)
        for model in ("gemini-flash", "gemini-pro"):
            try:
                session = client.start_chat(model=model)
                t0 = time.time()
                out = await session.send_message("Say OK")
                print(f"{model} ({time.time() - t0:.1f}s) -> {out.text[:70]!r}", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"{model} -> {type(exc).__name__}: {str(exc)[:120]}", flush=True)
    finally:
        gc.Endpoint = orig


asyncio.run(main())
