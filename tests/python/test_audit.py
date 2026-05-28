"""Tests for payload/agent/audit.py — redaction, chain, verification."""
from __future__ import annotations

import json
from pathlib import Path

import pytest


def _setup(monkeypatch, tmp_path: Path):
    monkeypatch.setenv("ZOMBIE_AUDIT_LOG", str(tmp_path / "audit.log"))
    import importlib
    import audit
    importlib.reload(audit)
    return audit


def _lines(p: Path) -> list[dict]:
    return [json.loads(line) for line in p.read_text().splitlines() if line]


def test_log_event_writes_chain_link(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    audit.log_event("a")
    audit.log_event("b")
    entries = _lines(Path(audit.AUDIT_PATH))
    assert len(entries) == 2
    assert entries[0]["prev_sha256"] == "0" * 64
    # second entry's prev_sha256 must match sha256 of the first line
    import hashlib
    first_line = Path(audit.AUDIT_PATH).read_text().splitlines()[0]
    assert entries[1]["prev_sha256"] == hashlib.sha256(first_line.encode()).hexdigest()


def test_verify_chain_ok(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    audit.log_event("x"); audit.log_event("y"); audit.log_event("z")
    ok, ln, msg = audit.verify_chain()
    assert ok and ln == 0


def test_verify_chain_detects_tamper(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    audit.log_event("x", val=1)
    audit.log_event("y", val=2)
    p = Path(audit.AUDIT_PATH)
    lines = p.read_text().splitlines()
    # mutate the first line
    lines[0] = lines[0].replace('"val":1', '"val":99')
    p.write_text("\n".join(lines) + "\n")
    ok, ln, msg = audit.verify_chain()
    assert not ok
    assert ln == 2  # the chain mismatch is detected at line 2


def test_redact_token_patterns(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    entry_id = audit.log_event("note", body="key=sk-abcdefghijklmno OPENAI_API_KEY=sk-xyz12345678")
    contents = Path(audit.AUDIT_PATH).read_text()
    assert "sk-abcdefghijklmno" not in contents
    assert "sk-xyz12345678" not in contents
    assert "***REDACTED***" in contents
    assert entry_id


def test_log_tool_call_records_digests(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    audit.log_tool_call(
        tool="fs.read",
        classification="read_only",
        decision="auto",
        stdout="hello",
        stderr="",
        exit_code=0,
        duration_ms=12,
    )
    entry = _lines(Path(audit.AUDIT_PATH))[-1]
    assert entry["stdout_sha256"]
    assert entry["stdout_bytes"] == 5
    assert entry["exit_code"] == 0


def test_tail_streams_bounded(monkeypatch, tmp_path):
    audit = _setup(monkeypatch, tmp_path)
    for i in range(20):
        audit.log_event("n", i=i)
    out = audit.tail(5)
    assert len(out) == 5
    assert [e["i"] for e in out] == [15, 16, 17, 18, 19]
