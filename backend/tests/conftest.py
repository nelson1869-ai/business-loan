"""Pytest configuration and shared fixtures for the backend test suite.

Engine disposal fixture:
    On Windows, asyncio uses the ProactorEventLoop. When pytest runs async
    tests with asyncio_default_fixture_loop_scope='function', each test gets
    a fresh event loop. The global SQLAlchemy AsyncEngine holds a connection
    pool whose underlying asyncpg sockets are tied to the previous event
    loop's I/O handles. Reusing those stale connections on a new event loop
    causes:

        AttributeError: 'NoneType' object has no attribute 'send'

    Disposing the engine's pool after each function-scoped test forces fresh
    connections on the next test's event loop, eliminating the stale-socket
    crash.

    NOTE: This fixture must be SYNCHRONOUS (not async def) so that pytest
    can inject it into both anyio/asyncio-style tests AND unittest.TestCase
    subclasses. Async autouse fixtures cause ERROR on unittest.TestCase tests.
"""

import asyncio

import pytest


@pytest.fixture(autouse=True)
def _dispose_engine_after_test():
    """Dispose the global async engine pool after every test.

    Uses a private, short-lived event loop so the disposal coroutine can run
    synchronously in teardown — safe for both pytest-style and
    unittest.TestCase tests.
    """
    yield
    try:
        from app.core.database import engine  # noqa: PLC0415

        loop = asyncio.new_event_loop()
        try:
            loop.run_until_complete(engine.dispose())
        finally:
            loop.close()
    except Exception:  # noqa: BLE001
        pass  # Never let teardown noise kill the test report
