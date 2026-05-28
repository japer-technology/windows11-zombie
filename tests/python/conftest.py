"""Shared pytest configuration: redirect AI_ZOMBIE_ROOT to a tmp dir
so the agent modules never touch a real install."""
from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def _isolate_install_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("AI_ZOMBIE_ROOT", str(tmp_path))
    monkeypatch.delenv("ZOMBIE_AUDIT_LOG", raising=False)
    monkeypatch.delenv("ZOMBIE_HISTORY_DB", raising=False)
    monkeypatch.delenv("ZOMBIE_SECRETS", raising=False)
    monkeypatch.delenv("ZOMBIE_POLICY", raising=False)
    # Reload modules that capture paths at import time.
    for mod in ("audit", "paths", "history", "policy"):
        sys.modules.pop(mod, None)
    return tmp_path


@pytest.fixture
def agent_path() -> Path:
    here = Path(__file__).resolve()
    repo = here.parents[2]
    return repo / "payload" / "agent"


@pytest.fixture(autouse=True)
def _agent_on_path(agent_path: Path) -> None:
    if str(agent_path) not in sys.path:
        sys.path.insert(0, str(agent_path))
