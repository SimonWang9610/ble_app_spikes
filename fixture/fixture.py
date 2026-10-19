"""BLE peripheral fixture for the hm_ble apps. GATT layout: docs/test-plan.md. Control page: web.py."""

import argparse
import asyncio
import logging
import shutil
import struct
import subprocess
import time
from collections import deque

from CoreBluetooth import CBAdvertisementDataLocalNameKey
from Foundation import NSData
from bless import (
    BlessServer,
    GATTAttributePermissions as Perm,
    GATTCharacteristicProperties as Prop,
)

NAME = "HM-BLE-FIXTURE"

# The GATT tree: service -> characteristics with their properties. The page renders this as is.
GATT = {
    "DATA": {
        "uuid": "f0e10000-5a3e-4c1a-9d2b-1b2c3d4e5f60",
        "characteristics": {
            "VALUE": ("f0e10001-5a3e-4c1a-9d2b-1b2c3d4e5f60", ["read", "write", "write-without-response"]),
        },
    },
    "STREAM": {
        "uuid": "f0e10100-5a3e-4c1a-9d2b-1b2c3d4e5f60",
        "characteristics": {
            "NOTIFY": ("f0e10101-5a3e-4c1a-9d2b-1b2c3d4e5f60", ["notify"]),
            "INDICATE": ("f0e10102-5a3e-4c1a-9d2b-1b2c3d4e5f60", ["indicate"]),
        },
    },
}
PROPS = {
    "read": Prop.read,
    "write": Prop.write,
    "write-without-response": Prop.write_without_response,
    "notify": Prop.notify,
    "indicate": Prop.indicate,
}
CHARS = {name: (service, uuid, props) for service, s in GATT.items() for name, (uuid, props) in s["characteristics"].items()}
NAMES = {uuid: name for name, (_, uuid, _) in CHARS.items()}

# CBManagerState values
BT_STATES = {0: "unknown", 1: "resetting", 2: "unsupported", 3: "unauthorized", 4: "off", 5: "on"}

log = logging.getLogger("fixture")

# Log line kinds, the page colors lines by them.
READ, WRITE, SUBSCRIBE, LINK, SET, WARN = ({"kind": k} for k in ("read", "write", "subscribe", "link", "set", "warn"))


class Stream:
    """What one notify / indicate characteristic sends: a counter every `interval` seconds."""

    def __init__(self):
        self.interval = 1.0
        self.paused = False
        self.counter = 0
        self.sent = 0
        self.due = 0.0


class Mock:
    """Repeating link drops: Bluetooth off for `off` seconds every `interval` seconds."""

    def __init__(self):
        self.running = False
        self.interval = 30.0
        self.off = 3.0
        self.count = 0
        self.next = None  # epoch of the next drop
        self.task = None
        self.bt_off = False  # Bluetooth is off because of the mock


class Fixture:
    """The peripheral: stored values, streams, publishing, and what the control page shows."""

    def __init__(self):
        self.server = BlessServer(name=NAME)
        self.server.read_request_func = self._on_read
        self.server.write_request_func = self._on_write
        # Returned to phones on read; VALUE is also replaced by their writes.
        self.stored = {"VALUE": b"\x01\x02\x03\x04"}
        self.streams = {"NOTIFY": Stream(), "INDICATE": Stream()}
        self.mock = Mock()
        self.last = {}  # characteristic -> "read" / "write" / "set" / "sent" -> {"value", "time"}
        self.published = False
        self.bt_state = "unknown"
        self.centrals = {}  # central id -> subscribed characteristic names
        self.drop = None  # timeline of the last Bluetooth off -> on, see _drop_json
        self.listeners = set()  # asyncio.Queue per control page client
        self.loop = None

    # GATT callbacks run on CoreBluetooth's dispatch queue, not the event loop.

    def _on_read(self, char, **_):
        name = NAMES.get(str(char.uuid).lower(), str(char.uuid))
        value = self.stored.get(name, b"")
        self._record(name, "read", value)
        log.info("%s phone read %s", name, _show(value), extra=READ)
        return bytearray(value)

    def _on_write(self, char, value, **_):
        name = NAMES.get(str(char.uuid).lower(), str(char.uuid))
        value = bytes(value)
        if name == "VALUE":
            self.stored[name] = value
        self._record(name, "write", value)
        log.info("%s phone wrote %s", name, _show(value), extra=WRITE)

    def _record(self, name, op, value):
        self.last.setdefault(name, {})[op] = {"value": value.hex(" "), "time": time.strftime("%H:%M:%S")}
        self.changed()

    # State for the control page

    def subscribers(self, name):
        return [central for central, names in self.centrals.items() if name in names]

    def snapshot(self):
        pm = self.server.peripheral_manager_delegate.peripheral_manager
        services = []
        for service, s in GATT.items():
            characteristics = []
            for name, (uuid, props) in s["characteristics"].items():
                char = {"name": name, "uuid": uuid, "properties": props, "last": self.last.get(name, {})}
                if name in self.stored:
                    char["stored"] = _value_json(self.stored[name])
                if name in self.streams:
                    stream = self.streams[name]
                    char["stream"] = {
                        "interval": stream.interval,
                        "paused": stream.paused,
                        "counter": stream.counter,
                        "sent": stream.sent,
                    }
                    char["subscribers"] = self.subscribers(name)
                characteristics.append(char)
            services.append({"name": service, "uuid": s["uuid"], "characteristics": characteristics})
        return {
            "device": {
                "name": NAME,
                "bluetooth": self.bt_state,
                "advertising": bool(pm.isAdvertising()),
                "published": self.published,
                "centrals": [{"id": c, "subscribed": sorted(n)} for c, n in self.centrals.items()],
            },
            "services": services,
            "drop": self._drop_json(),
            "mock": {
                "running": self.mock.running,
                "interval": self.mock.interval,
                "off": self.mock.off,
                "count": self.mock.count,
                "next": self.mock.next,
            },
        }

    def _drop_json(self):
        d = self.drop
        if not d:
            return None
        events = [(d["off"], "Bluetooth off", f"link dropped for {_phones(d['phones'])}"
                   + (f" ({', '.join(d['subscribed'])})" if d["subscribed"] else ""))]
        if d.get("on"):
            events.append((d["on"], "Bluetooth on", ""))
        if d.get("published"):
            events.append((d["published"], "Services published", ""))
        for name, t in d["resubscribed"].items():
            events.append((t, "Phone re-subscribed", name))
        for name, sent in d["first_sent"].items():
            events.append((sent["time"], "First value sent", f"{name} {sent['value']}"))
        events.sort(key=lambda e: e[0])

        summary = "waiting for Bluetooth to come back"
        if d.get("on"):
            summary = "waiting for a phone to re-subscribe"
        if d["first_sent"]:
            first = min(v["time"] for v in d["first_sent"].values())
            summary = f"resumed in {first - d['on']:.1f} s after Bluetooth came back"
            continued = [
                f"{n} {d['counters'][n]} → {v['counter']}"
                for n, v in d["first_sent"].items()
                if v["counter"] is not None and n in d["counters"]
            ]
            if continued:
                summary += "; counter continued (" + ", ".join(continued) + ")"
        elif d["resubscribed"]:
            summary = "re-subscribed, waiting for the first value"
        return {
            "summary": summary,
            "events": [{"time": _clock(t), "what": what, "detail": detail} for t, what, detail in events],
        }

    def changed(self):
        """Pushes the new state to every open control page; safe from any thread."""
        if self.loop:
            self.loop.call_soon_threadsafe(self._broadcast, {"type": "state", "state": self.snapshot()})

    def _broadcast(self, event):
        for queue in self.listeners:
            queue.put_nowait(event)

    # Controls

    async def publish(self):
        """Adds both services and starts advertising (also after Bluetooth comes back on)."""
        delegate = self.server.peripheral_manager_delegate
        delegate.peripheral_manager.removeAllServices()
        for service in self.server.services.values():
            for char in service.characteristics:
                char.obj.setValue_(None)  # only read-only characteristics may carry a cached value
            await delegate.add_service(service.obj)
        self.published = True
        if self.drop and self.drop.get("on") and not self.drop.get("published"):
            self.drop["published"] = time.time()
        log.info("Services published", extra=LINK)
        await self.set_advertising(True)

    async def set_bluetooth(self, on):
        await _power(on)
        log.info("Turning Bluetooth %s from the page", "on" if on else "off", extra=SET)

    async def set_mock(self, on, interval=None, off=None):
        """Starts (or restarts with new timings) or stops the repeating link drops."""
        mock = self.mock
        if not on:
            if mock.running:
                await self._stop_mock()
                log.info("Mock link drops stopped after %d drops", mock.count, extra=LINK)
            return
        interval = _number(mock.interval if interval is None else interval, "interval")
        off = _number(mock.off if off is None else off, "off")
        if interval < 10:
            raise ValueError("interval must be at least 10 s")
        if off < 1:
            raise ValueError("off must be at least 1 s")
        if off >= interval:
            raise ValueError("off must be shorter than the interval")
        if not shutil.which("blueutil"):
            raise ValueError("blueutil not found, run: brew install blueutil")
        await self._stop_mock()
        mock.interval, mock.off, mock.count, mock.running = interval, off, 0, True
        mock.task = asyncio.create_task(self._mock_drops())
        log.info("Mock link drops every %g s, Bluetooth off for %g s", interval, off, extra=LINK)

    async def _stop_mock(self):
        mock = self.mock
        if mock.task:
            mock.task.cancel()
            try:
                await mock.task
            except asyncio.CancelledError:
                pass
            mock.task = None
        if mock.bt_off:
            await _power(True)
            mock.bt_off = False
        mock.running, mock.next = False, None
        self.changed()

    async def _mock_drops(self):
        """A macOS peripheral can't drop a central itself; turning Bluetooth off drops them all."""
        mock = self.mock
        mock.next = time.time() + mock.interval
        self.changed()
        try:
            while True:
                await asyncio.sleep(max(0.0, mock.next - time.time()))
                log.info("Mock link drop %d: Bluetooth off for %g s", mock.count + 1, mock.off, extra=LINK)
                mock.bt_off = True
                await _power(False)
                await asyncio.sleep(mock.off)
                await _power(True)
                mock.bt_off = False
                mock.count += 1
                mock.next += mock.interval
                self.changed()
        except ValueError as error:
            log.warning("Mock link drops stopped: %s", error, extra=WARN)
            mock.running, mock.next, mock.task = False, None, None
            self.changed()

    async def set_advertising(self, on):
        delegate = self.server.peripheral_manager_delegate
        if on:
            try:
                await delegate.start_advertising({CBAdvertisementDataLocalNameKey: NAME})
            except TimeoutError:
                log.warning("Advertising did not confirm within 2 s", extra=WARN)
            log.info("Advertising as %s", NAME, extra=LINK)
        else:
            delegate.peripheral_manager.stopAdvertising()
            log.info("Advertising stopped", extra=LINK)
        self.changed()

    def set_stored(self, name, value):
        """Changes what phones get on their next read; sends nothing."""
        if name not in self.stored:
            raise ValueError(f"{name} has no stored value")
        self.stored[name] = value
        self._record(name, "set", value)
        log.info("%s set to %s (phones read it next)", name, _show(value), extra=SET)

    def set_stream(self, name, interval=None, paused=None):
        stream = self._stream(name)
        if interval is not None:
            stream.interval = max(0.05, float(interval))
        if paused is not None:
            stream.paused = bool(paused)
        log.info("%s %s every %.2f s", name, "paused, was sending" if stream.paused else "sending", stream.interval, extra=SET)
        self.changed()

    def reset_counter(self, name):
        self._stream(name).counter = 0
        log.info("%s counter reset", name, extra=SET)
        self.changed()

    def send(self, name, value=None):
        """Sends `value`, or the next counter value, to the phones subscribed to `name`."""
        stream = self._stream(name)
        phones = self.subscribers(name)
        if not phones:
            log.info("%s not sent, no phone subscribed", name, extra=WARN)
            return
        counter = None
        if value is None:
            stream.counter += 1
            counter = stream.counter
            value = struct.pack("<I", counter)
        _, uuid, props = CHARS[name]
        # Sent directly, not stored on the characteristic: a stored value would make CoreBluetooth
        # treat it as cached, and re-adding the service would then fail.
        pm = self.server.peripheral_manager_delegate.peripheral_manager
        char = self.server.get_characteristic(uuid).obj
        if not pm.updateValue_forCharacteristic_onSubscribedCentrals_(NSData.dataWithBytes_length_(value, len(value)), char, None):
            log.warning("%s not sent, CoreBluetooth's send queue is full", name, extra=WARN)
            return
        stream.sent += 1
        self._record(name, "sent", value)
        d = self.drop
        if d and name in d["resubscribed"] and name not in d["first_sent"]:
            d["first_sent"][name] = {"time": time.time(), "value": _show(value, True), "counter": counter}
        kind = {"kind": "indicate" if "indicate" in props else "notify"}
        log.info("%s sent %s to %s", name, _show(value, True), _phones(len(phones)), extra=kind)

    def _stream(self, name):
        if name not in self.streams:
            raise ValueError(f"{name} is not a notify / indicate characteristic")
        return self.streams[name]

    # Background tasks

    async def watch(self):
        """Follows Bluetooth power and subscriptions; re-publishes when Bluetooth is back on."""
        delegate = self.server.peripheral_manager_delegate
        while True:
            state = BT_STATES.get(delegate.peripheral_manager.state(), "unknown")
            if state != self.bt_state:
                was, self.bt_state = self.bt_state, state
                if state != "on":
                    # CoreBluetooth drops the services and every link when the radio goes off.
                    subscribed = sorted({n for names in self.centrals.values() for n in names})
                    if was == "on":
                        self.drop = {
                            "off": time.time(),
                            "phones": len(self.centrals),
                            "subscribed": subscribed,
                            "counters": {n: s.counter for n, s in self.streams.items()},
                            "resubscribed": {},
                            "first_sent": {},
                        }
                    log.info("Bluetooth %s, link dropped for %s", state, _phones(len(self.centrals)), extra=LINK)
                    self.published = False
                    self.centrals = {}
                else:
                    log.info("Bluetooth on", extra=LINK)
                    if was != "unknown":
                        if self.drop:
                            self.drop["on"] = time.time()
                        await self.publish()
                self.changed()

            # bless's subscription list can keep entries for centrals that vanished, so it only
            # counts while the services are published.
            subs = list(delegate._central_subscriptions.items()) if self.published else []
            now = {central: {NAMES[uuid.lower()] for uuid in list(uuids)} for central, uuids in subs}
            if now != self.centrals:
                for central, names in now.items():
                    for name in sorted(names - self.centrals.get(central, set())):
                        log.info("%s phone subscribed (%s…)", name, central[:8], extra=SUBSCRIBE)
                        if self.drop and self.drop.get("on"):
                            self.drop["resubscribed"].setdefault(name, time.time())
                for central, names in self.centrals.items():
                    for name in sorted(names - now.get(central, set())):
                        log.info("%s phone unsubscribed (%s…)", name, central[:8], extra=SUBSCRIBE)
                self.centrals = now
                self.changed()
            await asyncio.sleep(0.25)

    async def stream(self):
        """Sends each stream's counter on its own interval, while someone is subscribed."""
        while True:
            now = time.monotonic()
            for name, stream in self.streams.items():
                if now >= stream.due:
                    stream.due = now + stream.interval
                    if self.published and not stream.paused and self.subscribers(name):
                        self.send(name)
            await asyncio.sleep(0.05)


def _show(value, as_counter=False):
    """'2a 00 00 00 (= 42)' for stream counters, '68 69 "hi"' for text, hex otherwise."""
    shown = value.hex(" ") or "(empty)"
    if as_counter and len(value) == 4:
        return f"{shown} (= {struct.unpack('<I', value)[0]})"
    text = _value_json(value)["text"]
    return f'{shown} "{text}"' if text else shown


async def _power(on):
    """Turns the Mac's Bluetooth radio off or on (blueutil). Off drops every phone's link."""
    if not shutil.which("blueutil"):
        raise ValueError("blueutil not found, run: brew install blueutil")
    process = await asyncio.create_subprocess_exec("blueutil", "--power", "1" if on else "0")
    if await process.wait() != 0:
        raise ValueError("blueutil failed")


def _number(value, name):
    try:
        return float(value)
    except (TypeError, ValueError):
        raise ValueError(f"{name} must be a number") from None


def _phones(n):
    return f"{n} phone" if n == 1 else f"{n} phones"


def _clock(t):
    return time.strftime("%H:%M:%S", time.localtime(t))


def _value_json(value):
    try:
        text = value.decode()
        text = text if text.isascii() and text.isprintable() else None
    except UnicodeDecodeError:
        text = None
    return {"hex": value.hex(" "), "text": text}


async def build_gatt(server):
    for service, s in GATT.items():
        await server.add_new_service(s["uuid"])
        for name, (uuid, props) in s["characteristics"].items():
            flags = Prop(0)
            for prop in props:
                flags |= PROPS[prop]
            perms = Perm.readable | (Perm.writeable if "write" in props else Perm(0))
            await server.add_new_characteristic(s["uuid"], uuid, flags, None, perms)


class PageLogHandler(logging.Handler):
    """Sends log lines to open control pages and keeps the recent ones for new pages."""

    def __init__(self, fixture):
        super().__init__()
        self.fixture = fixture
        self.recent = deque(maxlen=300)  # {"type": "log", "line", "kind"}

    def emit(self, record):
        kind = getattr(record, "kind", "warn" if record.levelno >= logging.WARNING else "info")
        event = {"type": "log", "line": self.format(record), "kind": kind}
        self.recent.append(event)
        loop = self.fixture.loop
        if loop and not loop.is_closed():
            loop.call_soon_threadsafe(self.fixture._broadcast, event)


async def main(port):
    fixture = Fixture()
    fixture.loop = asyncio.get_running_loop()
    handler = PageLogHandler(fixture)
    handler.setFormatter(logging.Formatter("%(asctime)s %(message)s", "%H:%M:%S"))
    log.addHandler(handler)

    await build_gatt(fixture.server)
    await fixture.publish()

    tasks = [fixture.watch(), fixture.stream()]
    if port:
        from web import serve

        tasks.append(serve(fixture, handler, port))
    log.info("Ctrl-C to stop")
    try:
        await asyncio.gather(*tasks)
    finally:
        # Don't leave the Mac's Bluetooth off when stopped mid mock drop.
        if fixture.mock.task:
            fixture.mock.task.cancel()
        if fixture.mock.bt_off:
            subprocess.run(["blueutil", "--power", "1"], check=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080, help="control page port on 127.0.0.1, 0 = no page")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
    try:
        asyncio.run(main(args.port))
    except KeyboardInterrupt:
        log.info("stopped")
