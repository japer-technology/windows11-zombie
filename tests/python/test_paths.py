"""Tests for payload/agent/paths.py — env override matrix."""
from __future__ import annotations

import os
from pathlib import Path

import pytest


def test_install_root_honours_env(monkeypatch, tmp_path):
    monkeypatch.setenv("AI_ZOMBIE_ROOT", str(tmp_path))
    import paths
    assert paths.install_root() == tmp_path


def test_secrets_path_env_overrides_install_root(monkeypatch, tmp_path):
    monkeypatch.setenv("ZOMBIE_SECRETS", str(tmp_path / "custom" / "env"))
    import paths
    assert paths.secrets_path() == tmp_path / "custom" / "env"


def test_audit_log_default_is_log_root(monkeypatch, tmp_path):
    monkeypatch.setenv("AI_ZOMBIE_ROOT", str(tmp_path))
    monkeypatch.delenv("ZOMBIE_AUDIT_LOG", raising=False)
    monkeypatch.delenv("AI_ZOMBIE_LOG_ROOT", raising=False)
    import importlib
    import paths
    importlib.reload(paths)
    expected = paths.log_root() / "audit.log"
    assert paths.audit_log_path() == expected


def test_history_db_default(monkeypatch, tmp_path):
    monkeypatch.setenv("AI_ZOMBIE_ROOT", str(tmp_path))
    import importlib
    import paths
    importlib.reload(paths)
    assert paths.history_db_path() == tmp_path / "state" / "conversations.db"
