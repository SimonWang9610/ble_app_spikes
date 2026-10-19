"""Control page for the fixture: http://127.0.0.1:<port>, this Mac only."""

import asyncio
import json
import logging
from pathlib import Path

from aiohttp import web

log = logging.getLogger("fixture")
PAGE = Path(__file__).with_name("static") / "index.html"


def _value(body):
    text, fmt = body.get("text", ""), body.get("format", "hex")
    if fmt == "utf8":
        return text.encode()
    return bytes.fromhex(text.replace("0x", "").replace(" ", ""))


async def serve(fixture, handler, port):
    async def index(_):
        return web.FileResponse(PAGE)

    async def events(request):
        """Server-Sent Events: the state and recent log first, then every change."""
        response = web.StreamResponse(headers={"Content-Type": "text/event-stream", "Cache-Control": "no-cache"})
        await response.prepare(request)
        queue = asyncio.Queue()
        fixture.listeners.add(queue)
        try:
            await _send(response, {"type": "state", "state": fixture.snapshot()})
            for event in list(handler.recent):
                await _send(response, event)
            while True:
                await _send(response, await queue.get())
        except (ConnectionResetError, asyncio.CancelledError):
            pass
        finally:
            fixture.listeners.discard(queue)
        return response

    async def action(request):
        body = await request.json() if request.can_read_body else {}
        name = request.match_info["name"]
        try:
            match name:
                case "advertising":
                    await fixture.set_advertising(bool(body["on"]))
                case "bluetooth":
                    await fixture.set_bluetooth(bool(body["on"]))
                case "mock":
                    await fixture.set_mock(bool(body["on"]), body.get("interval"), body.get("off"))
                case "stored":
                    fixture.set_stored(body["char"], _value(body))
                case "stream":
                    fixture.set_stream(body["char"], body.get("interval"), body.get("paused"))
                case "send":
                    fixture.send(body["char"], _value(body) if body.get("text") else None)
                case "reset":
                    fixture.reset_counter(body["char"])
                case _:
                    raise web.HTTPNotFound()
        except (KeyError, ValueError) as error:
            log.warning("page: %s rejected: %s", name, error, extra={"kind": "warn"})
            return web.json_response({"error": str(error)}, status=400)
        return web.json_response(fixture.snapshot())

    app = web.Application()
    app.add_routes([web.get("/", index), web.get("/events", events), web.post("/api/{name}", action)])
    runner = web.AppRunner(app, access_log=None)
    await runner.setup()
    await web.TCPSite(runner, "127.0.0.1", port).start()
    log.info("control page http://127.0.0.1:%d", port, extra={"kind": "info"})
    await asyncio.Event().wait()


async def _send(response, event):
    await response.write(f"data: {json.dumps(event)}\n\n".encode())
