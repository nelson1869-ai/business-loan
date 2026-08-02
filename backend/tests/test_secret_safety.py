"""Repository test verifying no hardcoded database passwords exist in source files."""

import re
import unittest
from pathlib import Path

# Regex matching postgres URLs with passwords: postgresql(+driver)://user:password@host
POSTGRES_PASSWORD_URL_PATTERN = re.compile(
    r"postgresql(?:\+[a-z0-9_]+)?://[^:@\s]+:[^@\s]+@[^/\s]+(?:/[^\s\"\']*)?",
    re.IGNORECASE,
)


class SecretSafetyTests(unittest.TestCase):
    """Ensure no password-bearing database URLs exist in tracked Python source files."""

    def test_no_hardcoded_database_passwords_in_python_files(self) -> None:
        backend_dir = Path(__file__).resolve().parent.parent
        py_files = list(backend_dir.rglob("*.py"))
        violations = []

        for py_file in py_files:
            # Skip virtual environment files if located inside backend/
            if ".venv" in py_file.parts or "venv" in py_file.parts:
                continue

            content = py_file.read_text(encoding="utf-8")
            matches = POSTGRES_PASSWORD_URL_PATTERN.findall(content)

            # Ignore allowed test placeholder URLs with user:pass or postgres:test-only-password
            for match in matches:
                if "user:pass@" in match or "postgres:test-only-password@" in match:
                    continue
                relative_path = py_file.relative_to(backend_dir)
                violations.append(f"{relative_path}: {match}")

        self.assertEqual(
            violations,
            [],
            "Found hardcoded database passwords in Python source files:\n"
            + "\n".join(violations),
        )
