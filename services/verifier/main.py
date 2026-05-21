"""
Verification: post-execution checks
"""

import asyncio
import json
import os
import signal
import logging

from aiohttp import web
from nats.aio.client import Client as NATS

SERVICE_NAME = "verifier"
HEALTH_PORT = 9106
NATS_URL = os.getenv("NATS_URL", "nats://nats:4222")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
logger = logging.getLogger(SERVICE_NAME)

nc = NATS()
health_status = {"status": "starting", "ready": False}


async def handle_health(request):
    """Health check endpoint"""
    status_code = 200 if health_status["ready"] else 503
    return web.json_response(health_status, status=status_code)


async def on_message(msg):
    """Handle incoming NATS message"""
    subject = msg.subject
    data = msg.data.decode()
    logger.info(f"Received on {subject}: {data[:200]}")
    try:
        payload = json.loads(data)
        # TODO: implement service logic
    except json.JSONDecodeError:
        logger.warning(f"Invalid JSON on {subject}")


async def subscribe_all(nc_conn):
    """Subscribe to relevant NATS subjects"""
    for subject in ['daos.events.executed']:
        await nc_conn.subscribe(subject, cb=on_message)
        logger.info(f"Subscribed to {subject}")


async def main():
    logger.info(f"Starting {SERVICE_NAME}")
    global health_status

    # Connect to NATS
    try:
        await nc.connect(NATS_URL)
        logger.info(f"Connected to NATS at {NATS_URL}")
        await subscribe_all(nc)
    except Exception as e:
        logger.warning(f"NATS not available: {e}")

    # Start HTTP health server
    app = web.Application()
    app.router.add_get("/health", handle_health)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, "0.0.0.0", HEALTH_PORT)
    await site.start()
    logger.info(f"Health server on :{HEALTH_PORT}")

    health_status = {"status": "running", "ready": True}

    # Graceful shutdown
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, lambda: asyncio.ensure_future(shutdown()))

    # Keep running
    await asyncio.Event().wait()


async def shutdown():
    logger.info("Shutting down...")
    await nc.drain()
    asyncio.get_event_loop().stop()


if __name__ == "__main__":
    asyncio.run(main())
