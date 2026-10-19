"""BLE peripheral fixture for the hm_ble apps. GATT layout: docs/test-plan.md. Control page: web.py."""

import argparse
import asyncio
import logging
import shutil
import struct
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
            "INFO": ("f0e10002-5a3e-4c1a-9d2b-1b2c3d4e5f60", ["read"]),
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


class Stream:
    """What one notify / indicate characteristic sends: a counter every `interval` seconds."""

    def __init__(self):
        self.interval = 1.0
        self.paused = False
        self.counter = 0
        self.sent = 0
        self.due = 0.0


class Fixture:
    """The peripheral: stored values, streams, publishing, and what the control page shows."""

    def __init__(self):
        self.server = BlessServer(name=NAME)
        self.server.read_request_func = self._on_read
        self.server.write_request_func = self._on_write
        # Returned to phones on read; VALUE is also replaced by their writes.
        self.stored = {"VALUE": b"\x01\x02\x03\x04", "INFO": b"hm-ble-fixture"}
        self.streams = {"NOTIFY": Stream(), "INDICATE": Stream()}
        self.last = {}  # characteristic -> {"op", "value", "time"}
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
        self._record(name, "phone read", value)
        log.info("%s phone read %s", name, _show(value))
        return bytearray(value)

    def _on_write(self, char, value, **_):
        name = NAMES.get(str(char.uuid).lower(), str(char.uuid))
        value = bytes(value)
        if name == "VALUE":
            self.stored[name] = value
        self._record(name, "phone wrote", value)
        log.info("%s phone wrote %s", name, _show(value))

    def _record(self, name, op, value):
        self.last[name] = {"op": op, "value": value.hex(" "), "time": time.strftime("%H:%M:%S")}
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
                char = {"name": name, "uuid": uuid, "properties": props, "last": self.last.get(name)}
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
        log.info("Services published")
        await self.set_advertising(True)

    async def set_bluetooth(self, on):
        """Turns the Mac's Bluetooth radio off or on (blueutil). Off drops every phone's link."""
        if not shutil.which("blueutil"):
            raise ValueError("blueutil not found, run: brew install blueutil")
        process = await asyncio.create_subprocess_exec("blueutil", "--power", "1" if on else "0")
        if await process.wait() != 0:
            raise ValueError("blueutil failed")
        log.info("Turning Bluetooth %s from the page", "on" if on else "off")

    async def set_advertising(self, on):
        delegate = self.server.peripheral_manager_delegate
        if on:
            try:
                await delegate.start_advertising({CBAdvertisementDataLocalNameKey: NAME})
            except TimeoutError:
                log.warning("Advertising did not confirm within 2 s")
            log.info("Advertising as %s", NAME)
        else:
            delegate.peripheral_manager.stopAdvertising()
            log.info("Advertising stopped")
        self.changed()

    def set_stored(self, name, value):
        """Changes what phones get on their next read; sends nothing."""
        if name not in self.stored:
            raise ValueError(f"{name} has no stored value")
        self.stored[name] = value
        self._record(name, "set here", value)
        log.info("%s set to %s (phones read it next)", name, _show(value))

    def set_stream(self, name, interval=None, paused=None):
        stream = self._stream(name)
        if interval is not None:
            stream.interval = max(0.05, float(interval))
        if paused is not None:
            stream.paused = bool(paused)
        log.info("%s %s every %.2f s", name, "paused, was sending" if stream.paused else "sending", stream.interval)
        self.changed()

    def reset_counter(self, name):
        self._stream(name).counter = 0
        log.info("%s counter reset", name)
        self.changed()

    def send(self, name, value=None):
        """Sends `value`, or the next counter value, to the phones subscribed to `name`."""
        stream = self._stream(name)
        phones = self.subscribers(name)
        if not phones:
            log.info("%s not sent, no phone subscribed", name)
            return
        counter = None
        if value is None:
            stream.counter += 1
            counter = stream.counter
            value = struct.pack("<I", counter)
        _, uuid, _ = CHARS[name]
        # Sent directly, not stored on the characteristic: a stored value would make CoreBluetooth
        # treat it as cached, and re-adding the service would then fail.
        pm = self.server.peripheral_manager_delegate.peripheral_manager
        char = self.server.get_characteristic(uuid).obj
        if not pm.updateValue_forCharacteristic_onSubscribedCentrals_(NSData.dataWithBytes_length_(value, len(value)), char, None):
            log.warning("%s not sent, CoreBluetooth's send queue is full", name)
            return
        stream.sent += 1
        self._record(name, "sent", value)
        d = self.drop
        if d and name in d["resubscribed"] and name not in d["first_sent"]:
            d["first_sent"][name] = {"time": time.time(), "value": _show(value, True), "counter": counter}
        log.info("%s sent %s to %s", name, _show(value, True), _phones(len(phones)))

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
                    log.info("Bluetooth %s, link dropped for %s", state, _phones(len(self.centrals)))
                    self.published = False
                    self.centrals = {}
                else:
                    log.info("Bluetooth on")
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
                        log.info("%s phone subscribed (%s…)", name, central[:8])
                        if self.drop and self.drop.get("on"):
                            self.drop["resubscribed"].setdefault(name, time.time())
                for central, names in self.centrals.items():
                    for name in sorted(names - now.get(central, set())):
                        log.info("%s phone unsubscribed (%s…)", name, central[:8])
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
        self.recent = deque(maxlen=300)

    def emit(self, record):
        line = self.format(record)
        self.recent.append(line)
        if self.fixture.loop:
            self.fixture.loop.call_soon_threadsafe(self.fixture._broadcast, {"type": "log", "line": line})


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
    await asyncio.gather(*tasks)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080, help="control page port on 127.0.0.1, 0 = no page")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
    try:
        asyncio.run(main(args.port))
    except KeyboardInterrupt:
        log.info("stopped")
