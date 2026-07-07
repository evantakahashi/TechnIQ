"""Tests for the hardened request path: IDOR guard, rate limiting, payload caps.

These exercise the production auth path (emulator bypass OFF) by mocking
auth.verify_id_token, and mock Firestore for the rate limiter so no network is used.
"""
from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest
from werkzeug.test import EnvironBuilder
from firebase_functions import https_fn


def _make_request(payload: dict, headers: dict | None = None) -> https_fn.Request:
    hdrs = {"Content-Type": "application/json"}
    if headers:
        hdrs.update(headers)
    env = EnvironBuilder(
        method="POST",
        path="/generate_custom_drill",
        data=json.dumps(payload).encode("utf-8"),
        headers=hdrs,
    ).get_environ()
    return https_fn.Request(env)


_VALID_PAYLOAD = {
    "user_id": "real-uid",
    "player_profile": {"age": 14, "position": "midfielder", "experienceLevel": "intermediate"},
    "requirements": {
        "skill_description": "test",
        "equipment": ["ball"],
        "selected_weaknesses": [{"category": "Passing"}],
    },
}


@pytest.fixture(autouse=True)
def _production_auth(monkeypatch):
    # Emulator bypass OFF so the real token-verification path runs.
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)
    monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key-not-real")


def test_missing_token_returns_401():
    from main import generate_custom_drill

    resp = generate_custom_drill(_make_request(_VALID_PAYLOAD))
    assert resp.status_code == 401


def test_uid_mismatch_returns_403():
    """Body user_id different from the token uid is an IDOR attempt -> 403."""
    from main import generate_custom_drill

    payload = dict(_VALID_PAYLOAD, user_id="attacker-uid")
    with patch("main.auth.verify_id_token", return_value={"uid": "real-uid"}):
        resp = generate_custom_drill(_make_request(payload, {"Authorization": "Bearer faketoken"}))
    assert resp.status_code == 403


def test_rate_limit_returns_429():
    """When the per-uid daily quota is exhausted, the endpoint returns 429."""
    from main import generate_custom_drill

    with patch("main.auth.verify_id_token", return_value={"uid": "real-uid"}), \
         patch("main.db", MagicMock()), \
         patch("main._rate_limit_txn", return_value=False):
        resp = generate_custom_drill(_make_request(_VALID_PAYLOAD, {"Authorization": "Bearer faketoken"}))
    assert resp.status_code == 429


def test_oversized_payload_returns_400():
    """A body larger than MAX_REQUEST_BYTES is rejected before auth/LLM work."""
    from main import generate_custom_drill

    payload = dict(_VALID_PAYLOAD)
    payload["requirements"] = dict(payload["requirements"], skill_description="x" * 200_000)
    resp = generate_custom_drill(_make_request(payload))
    assert resp.status_code == 400
