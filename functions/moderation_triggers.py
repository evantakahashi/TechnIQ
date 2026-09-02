"""Firestore triggers that auto-hide community content once enough distinct
users have reported it.

Triggers run with admin privileges and bypass Firestore security rules, so they
are the ONLY writers of the isHidden / hiddenAt / hiddenReason fields. Clients
are blocked from setting those fields by firestore.rules. Each trigger no-ops
once the doc is already hidden, so the self-write it performs does not loop.
"""
from __future__ import annotations

from typing import Any

from firebase_admin import firestore as admin_firestore
from firebase_functions import firestore_fn

# A document is auto-hidden once this many distinct users have reported it.
REPORT_HIDE_THRESHOLD = 3
AUTO_HIDE_REASON = "auto_report_threshold"


def _should_hide(data: dict[str, Any]) -> bool:
    """True when a doc has crossed the report threshold and is not already hidden."""
    if not data:
        return False
    if data.get("isHidden") is True:
        return False
    try:
        report_count = int(data.get("reportCount") or 0)
    except (TypeError, ValueError):
        return False
    return report_count >= REPORT_HIDE_THRESHOLD


def _hidden_fields() -> dict[str, Any]:
    return {
        "isHidden": True,
        "hiddenAt": admin_firestore.SERVER_TIMESTAMP,
        "hiddenReason": AUTO_HIDE_REASON,
    }


def _auto_hide_on_report(event: firestore_fn.Event) -> None:
    """Shared handler: hide the updated doc if it just crossed the report threshold."""
    change = event.data
    if change is None:
        return
    after = change.after
    if after is None:  # document was deleted
        return
    data = after.to_dict() or {}
    if _should_hide(data):
        after.reference.update(_hidden_fields())


@firestore_fn.on_document_updated(document="communityPosts/{postId}")
def hide_reported_post(event: firestore_fn.Event) -> None:
    _auto_hide_on_report(event)


@firestore_fn.on_document_updated(document="communityPosts/{postId}/comments/{commentId}")
def hide_reported_comment(event: firestore_fn.Event) -> None:
    _auto_hide_on_report(event)


@firestore_fn.on_document_updated(document="sharedDrills/{drillId}")
def hide_reported_drill(event: firestore_fn.Event) -> None:
    _auto_hide_on_report(event)
