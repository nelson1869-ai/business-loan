"""Smoke test for FastAPI application import and router registration."""

import unittest


class TestFastApiImportSmoke(unittest.TestCase):
    """Ensure backend application imports cleanly without any NameError or missing dependency imports."""

    def test_fastapi_application_imports(self) -> None:
        from app.main import app

        self.assertIsNotNone(app)

    def test_route_registration_contract(self) -> None:
        from app.main import app

        all_routes: list[tuple[str, set[str]]] = []
        for route in app.routes:
            if hasattr(route, "path") and hasattr(route, "methods"):
                all_routes.append((route.path, route.methods or set()))
            if hasattr(route, "original_router") and hasattr(route, "include_context"):
                prefix = route.include_context.prefix or ""
                for sub in route.original_router.routes:
                    if hasattr(sub, "path") and hasattr(sub, "methods"):
                        all_routes.append((prefix + sub.path, sub.methods or set()))

        paths = [p for p, _ in all_routes]
        self.assertTrue(any("/api/v1/auth" in path for path in paths), f"No /api/v1/auth route found in {paths}")
        self.assertTrue(any("/api/v1/borrowers" in path for path in paths), f"No /api/v1/borrowers route found in {paths}")
        self.assertTrue(any("/api/v1/client" in path for path in paths), f"No /api/v1/client route found in {paths}")
        self.assertTrue(any("/api/v1/loans" in path for path in paths), f"No /api/v1/loans route found in {paths}")

        register_routes = [
            path
            for path, methods in all_routes
            if path == "/api/v1/client/auth/register" and "POST" in methods
        ]
        self.assertEqual(
            len(register_routes),
            1,
            f"Expected exactly 1 POST /api/v1/client/auth/register route, found {len(register_routes)}: {register_routes}",
        )
