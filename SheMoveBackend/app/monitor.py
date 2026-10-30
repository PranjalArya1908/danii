import asyncio

from app.config import get_settings
from app.mongo import persist_snapshot
from app.realtime import broker
from app.store import store


class Monitor:
    def __init__(self) -> None:
        self._task: asyncio.Task | None = None
        self._running = False
        self._persist_every = 6

    async def start(self) -> None:
        if self._task:
            return
        self._running = True

        def on_change() -> None:
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                return
            loop.create_task(broker.publish(store.update_snapshot()))

        store.subscribe(on_change)
        self._task = asyncio.create_task(self._loop())

    async def stop(self) -> None:
        self._running = False
        if self._task:
            self._task.cancel()
            self._task = None

    async def _loop(self) -> None:
        interval = get_settings().monitor_interval_s
        ticks = 0
        while self._running:
            try:
                store.run_monitor_pass()
            except Exception:
                pass
            ticks += 1
            if ticks % self._persist_every == 0:
                try:
                    await persist_snapshot()
                except Exception:
                    pass
            await asyncio.sleep(interval)


monitor = Monitor()
