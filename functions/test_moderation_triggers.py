"""Tests for the auto-hide moderation triggers.

The trigger handlers receive an Event[Change[DocumentSnapshot]]; we mock the
snapshot + its document reference so no Firestore network is touched.
"""
from __future__ import annotations

from unittest.mock import MagicMock

import moderation_triggers as mt


def _make_event(after_data, after_none: bool = False) -> MagicMock:
    event = MagicMock()
    if after_none:
        event.data.after = None
        return event
    after = MagicMock()
    after.to_dict.return_value = after_data
    after.reference = MagicMock()
    event.data.after = after
    return event


# --- _should_hide decision gate ---

def test_should_hide_at_and_above_threshold():
    assert mt._should_hide({"reportCount": 3}) is True
    assert mt._should_hide({"reportCount": 7}) is True


def test_should_not_hide_below_threshold():
    assert mt._should_hide({"reportCount": 2}) is False
    assert mt._should_hide({"reportCount": 0}) is False
    assert mt._should_hide({}) is False


def test_should_not_hide_when_already_hidden():
    assert mt._should_hide({"reportCount": 99, "isHidden": True}) is False


def test_should_not_hide_on_malformed_count():
    assert mt._should_hide({"reportCount": "lots"}) is False


def test_hidden_fields_shape():
    fields = mt._hidden_fields()
    assert fields["isHidden"] is True
    assert fields["hiddenReason"] == mt.AUTO_HIDE_REASON
    assert "hiddenAt" in fields


# --- handler behavior ---

def test_handler_hides_when_threshold_crossed():
    event = _make_event({"reportCount": 3, "isHidden": False})
    mt._auto_hide_on_report(event)
    event.data.after.reference.update.assert_called_once()
    written = event.data.after.reference.update.call_args[0][0]
    assert written["isHidden"] is True
    assert written["hiddenReason"] == mt.AUTO_HIDE_REASON


def test_handler_noop_below_threshold():
    event = _make_event({"reportCount": 1})
    mt._auto_hide_on_report(event)
    event.data.after.reference.update.assert_not_called()


def test_handler_noop_when_already_hidden():
    event = _make_event({"reportCount": 50, "isHidden": True})
    mt._auto_hide_on_report(event)
    event.data.after.reference.update.assert_not_called()


def test_handler_noop_on_delete():
    event = _make_event(None, after_none=True)
    mt._auto_hide_on_report(event)  # must not raise


def test_public_trigger_symbols_exist():
    # Names main.py imports for deploy registration.
    for name in ("hide_reported_post", "hide_reported_comment", "hide_reported_drill"):
        assert hasattr(mt, name)
