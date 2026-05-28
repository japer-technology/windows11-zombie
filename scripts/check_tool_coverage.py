#!/usr/bin/env python3
"""CI guard: every tool in payload/agent/tools.py TOOL_REGISTRY must
have a default classification, and every classification used must
appear in policy.yaml `classes`.

Exits non-zero with a human-readable diagnostic on violation.
"""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "payload" / "agent"))

import yaml  # noqa: E402

import tools as tools_mod  # noqa: E402


def main() -> int:
    policy_path = ROOT / "payload" / "etc" / "policy.yaml"
    data = yaml.safe_load(policy_path.read_text(encoding="utf-8"))
    classes = set((data or {}).get("classes", {}).keys())
    tool_classes = (data or {}).get("tool_classes", {}) or {}

    errors: list[str] = []
    for name, spec in tools_mod.TOOL_REGISTRY.items():
        cls = spec.get("classification")
        if not cls:
            errors.append(f"tool '{name}' has no default classification in TOOL_REGISTRY")
            continue
        if cls not in classes:
            errors.append(
                f"tool '{name}' uses classification '{cls}' which is not declared in policy.yaml classes"
            )
        override = tool_classes.get(name)
        if override and override not in classes:
            errors.append(
                f"tool_classes['{name}']='{override}' is not declared in policy.yaml classes"
            )

    if errors:
        print("policy/tool coverage check FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print(f"OK: {len(tools_mod.TOOL_REGISTRY)} tools, all classified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
