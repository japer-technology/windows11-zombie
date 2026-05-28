"""Tests for payload/agent/policy.py — classification, fail-closed, sudo."""
from __future__ import annotations

from pathlib import Path
from textwrap import dedent

import pytest


def _write_policy(p: Path, body: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body)


def _load(monkeypatch, tmp_path: Path, body: str | None = None):
    pol = tmp_path / "etc" / "policy.yaml"
    if body is None:
        body = dedent(
            """
            settings:
              destructive_confirmation: "yes"
              default_class: destructive
            sudo_allow_list:
              - winget
            classes:
              read_only:
                approval: auto
              user_change:
                approval: required
              system_change:
                approval: required
              network_change:
                approval: required
              destructive:
                approval: required
                confirm_phrase: true
            rules:
              - pattern: '^Get-ChildItem\\b'
                class: read_only
              - pattern: '\\bRemove-Item\\b'
                class: system_change
              - pattern: '\\bFormat-Volume\\b'
                class: destructive
            tool_classes: {}
            agent:
              max_tool_calls_per_turn: 12
              max_elevated_calls_per_turn: 3
            """
        )
    _write_policy(pol, body)
    monkeypatch.setenv("ZOMBIE_POLICY", str(pol))
    import importlib
    import policy
    importlib.reload(policy)
    return policy.load_policy()


def test_classify_read_only(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    assert p.classify("Get-ChildItem C:\\") == "read_only"


def test_classify_system_change(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    assert p.classify("Remove-Item C:\\tmp\\foo") == "system_change"


def test_classify_destructive(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    assert p.classify("Format-Volume -DriveLetter D") == "destructive"


def test_unknown_command_is_failclosed(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    # unknown verb falls through to default_class
    assert p.classify("xyzzy-unknown-cmd") == "destructive"


def test_sudo_allow_list_demotes_to_system(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    # sudo-prefixed invocation of a program in the allow list should
    # classify as system_change instead of falling to the destructive
    # default.
    assert p.classify("sudo winget upgrade --all") == "system_change"


def test_requires_approval(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    assert p.requires_approval("read_only") is False
    assert p.requires_approval("system_change") is True
    assert p.requires_approval("destructive") is True


def test_requires_phrase_only_for_destructive(monkeypatch, tmp_path):
    p = _load(monkeypatch, tmp_path)
    assert p.requires_phrase("destructive") is True
    assert p.requires_phrase("system_change") is False
