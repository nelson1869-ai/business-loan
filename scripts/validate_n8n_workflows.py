#!/usr/bin/env python3
"""Validator script for n8n export workflow JSON files.

Ensures no hardcoded credentials, secret keys, sample borrower PII, or pinned execution data are committed.
"""

import json
import re
import sys
from pathlib import Path

SUSPICIOUS_PATTERNS = [
    (r"YOUR_[A_Z0_9_]+", "Unreplaced template placeholder key"),
    (r"\"apikey\"\s*:\s*\"[^\$][^\"]+\"", "Hardcoded API key"),
    (r"\"chatId\"\s*:\s*\"[0-9]{5,}\"", "Hardcoded numeric Telegram chat ID"),
    (r"\"pinData\"\s*:\s*\{[^\}]+\}", "Pinned execution data present"),
    (r"\b09\d{9}\b", "Sample Philippine phone number in string literal"),
]


def validate_workflow_file(filepath: Path) -> list[str]:
    errors = []
    try:
        content = filepath.read_text(encoding="utf-8")
        data = json.loads(content)
    except Exception as exc:
        return [f"Invalid JSON syntax: {str(exc)}"]

    if not isinstance(data, dict):
        return ["Workflow root must be a JSON object"]

    if not data.get("name"):
        errors.append("Missing workflow 'name' property")

    nodes = data.get("nodes", [])
    if not isinstance(nodes, list) or len(nodes) == 0:
        errors.append("Workflow must contain at least one node in 'nodes'")

    node_names = set()
    for node in nodes:
        node_name = node.get("name")
        if not node_name:
            errors.append("Found node missing a 'name' property")
        elif node_name in node_names:
            errors.append(f"Duplicate node name found: '{node_name}'")
        else:
            node_names.add(node_name)

    if data.get("active") is True:
        errors.append("Workflow should be 'active: false' by default in source control")

    if "pinData" in data and data["pinData"]:
        errors.append("Found 'pinData' (pinned execution test data) in export")

    for pattern, desc in SUSPICIOUS_PATTERNS:
        if re.search(pattern, content):
            errors.append(f"Security risk: {desc} (matched pattern: {pattern})")

    return errors


def main() -> int:
    workflows_dir = Path(__file__).resolve().parent.parent / "n8n" / "workflows"
    if not workflows_dir.exists():
        print(f"Error: Workflows directory '{workflows_dir}' not found.", file=sys.stderr)
        return 1

    json_files = list(workflows_dir.glob("*.json"))
    if not json_files:
        print(f"Warning: No JSON workflow files found in '{workflows_dir}'.", file=sys.stderr)
        return 0

    total_errors = 0
    print(f"Validating {len(json_files)} n8n workflow file(s) in {workflows_dir}...\n")

    for filepath in json_files:
        errors = validate_workflow_file(filepath)
        if errors:
            total_errors += len(errors)
            print(f"[FAIL] {filepath.name}:")
            for err in errors:
                print(f"   - {err}")
        else:
            print(f"[PASS] {filepath.name}: Passed")

    print("\n--------------------------------------------------")
    if total_errors > 0:
        print(f"FAILED: Found {total_errors} validation issue(s).", file=sys.stderr)
        return 1

    print("SUCCESS: All n8n workflow JSON files passed quality and security checks.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
