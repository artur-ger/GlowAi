#!/usr/bin/env python3
"""Offline MAE: predicted sensation vs pilot feedback (PDF §8 / pilot).

Compares:
  - UTCI-band baseline (no personal uᵢ)
  - Mixed / personal prediction already stored on the event

Usage:
  python research/offline_mae_utci.py
  python research/offline_mae_utci.py --csv research/sample_pilot_feedback.csv
  python research/offline_mae_utci.py --sqlite backend/glowai.db

Leave-one-user-out: mean absolute error of actual_sensation vs predicted_sensation,
and vs UTCI→band when predicted_utci_c is present.
"""
from __future__ import annotations

import argparse
import csv
import math
import sqlite3
import statistics
from pathlib import Path

def utci_to_sensation(utci_c: float) -> int:
    """Mirror backend `utci.utci_to_sensation` bands."""
    if utci_c < -13:
        return -3
    if utci_c < 0:
        return -2
    if utci_c < 9:
        return -1
    if utci_c <= 26:
        return 0
    if utci_c <= 32:
        return 1
    if utci_c <= 38:
        return 2
    return 3


def _mae(pairs: list[tuple[float, float]]) -> float | None:
    if not pairs:
        return None
    return sum(abs(a - b) for a, b in pairs) / len(pairs)


def load_csv(path: Path) -> list[dict]:
    with path.open(encoding="utf-8") as f:
        return list(csv.DictReader(f))


def load_sqlite(path: Path) -> list[dict]:
    con = sqlite3.connect(path)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute(
            """
            SELECT client_key, city, predicted_sensation, actual_sensation,
                   predicted_utci_c, worn_tier, look_preserved
            FROM climate_feedback_events
            """
        ).fetchall()
    except sqlite3.Error as exc:
        raise SystemExit(f"sqlite read failed: {exc}") from exc
    finally:
        con.close()
    return [dict(r) for r in rows]


def eval_rows(rows: list[dict]) -> dict:
    model_pairs: list[tuple[float, float]] = []
    utci_pairs: list[tuple[float, float]] = []
    by_user: dict[str, list[dict]] = {}
    for r in rows:
        try:
            pred = int(r["predicted_sensation"])
            actual = int(r["actual_sensation"])
        except (KeyError, TypeError, ValueError):
            continue
        model_pairs.append((float(pred), float(actual)))
        utci_raw = r.get("predicted_utci_c")
        if utci_raw not in (None, "", "null"):
            try:
                u = float(utci_raw)
                if not math.isnan(u):
                    utci_pairs.append((float(utci_to_sensation(u)), float(actual)))
            except (TypeError, ValueError):
                pass
        key = str(r.get("client_key") or "anon")
        by_user.setdefault(key, []).append(r)

    # Leave-one-user-out: MAE of held-out user using global mean residual as naive prior
    loo: list[float] = []
    if len(by_user) >= 2:
        for held, held_rows in by_user.items():
            train = [x for k, rs in by_user.items() if k != held for x in rs]
            if not train:
                continue
            residuals = []
            for t in train:
                try:
                    residuals.append(int(t["actual_sensation"]) - int(t["predicted_sensation"]))
                except (KeyError, TypeError, ValueError):
                    continue
            if not residuals:
                continue
            bias = statistics.mean(residuals)
            for h in held_rows:
                try:
                    pred = int(h["predicted_sensation"]) + bias
                    actual = int(h["actual_sensation"])
                except (KeyError, TypeError, ValueError):
                    continue
                loo.append(abs(pred - actual))

    return {
        "n": len(model_pairs),
        "mae_model": _mae(model_pairs),
        "mae_utci_band": _mae(utci_pairs),
        "n_utci": len(utci_pairs),
        "n_users": len(by_user),
        "mae_loo_bias": (sum(loo) / len(loo)) if loo else None,
        "n_loo": len(loo),
    }


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--csv", type=Path, default=None)
    ap.add_argument("--sqlite", type=Path, default=None)
    args = ap.parse_args()
    root = Path(__file__).resolve().parent
    if args.sqlite:
        rows = load_sqlite(args.sqlite)
        src = str(args.sqlite)
    else:
        path = args.csv or (root / "sample_pilot_feedback.csv")
        rows = load_csv(path)
        src = str(path)
    stats = eval_rows(rows)
    print(f"source={src}")
    print(f"n={stats['n']} users={stats['n_users']}")
    print(f"MAE mixed/predicted={stats['mae_model']}")
    print(f"MAE UTCI-band={stats['mae_utci_band']} (n={stats['n_utci']})")
    print(f"MAE LOO+mean-bias={stats['mae_loo_bias']} (n={stats['n_loo']})")
    if stats["mae_model"] is not None and stats["mae_utci_band"] is not None:
        delta = stats["mae_utci_band"] - stats["mae_model"]
        print(f"delta (UTCI_band - model)={delta:+.3f}  (positive => model better)")


if __name__ == "__main__":
    main()
