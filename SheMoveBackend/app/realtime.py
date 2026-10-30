import asyncio
import json
from collections.abc import AsyncIterator
from typing import Any


class EventBroker:
    def __init__(self) -> None:
        self._subscribers: set[asyncio.Queue] = set()

    def subscribe(self) -> asyncio.Queue:
        queue: asyncio.Queue = asyncio.Queue(maxsize=64)
        self._subscribers.add(queue)
        return queue

    def unsubscribe(self, queue: asyncio.Queue) -> None:
        self._subscribers.discard(queue)

    async def publish(self, payload: dict[str, Any]) -> None:
        stale: list[asyncio.Queue] = []
        for queue in list(self._subscribers):
            try:
                queue.put_nowait(payload)
            except asyncio.QueueFull:
                stale.append(queue)
        for queue in stale:
            self.unsubscribe(queue)

    async def sse_stream(self, snapshot_factory) -> AsyncIterator[str]:
        queue = self.subscribe()
        try:
            snapshot = snapshot_factory()
            yield f"data: {json.dumps(snapshot)}\n\n"
            while True:
                try:
                    payload = await asyncio.wait_for(queue.get(), timeout=10)
                    yield f"data: {json.dumps(payload)}\n\n"
                except TimeoutError:
                    yield ": ping\n\n"
        finally:
            self.unsubscribe(queue)


broker = EventBroker()
