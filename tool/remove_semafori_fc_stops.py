#!/usr/bin/env python3
"""Rimuove fermate FC il cui nome inizia con «Semaforo» e le dipendenze in transiti / transit_times."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FC = ROOT / "assets/data/fermate_fc.json"
TRANSITI = ROOT / "assets/data/transiti.json"
TIMES = ROOT / "assets/data/transit_times_by_stop.json"


def is_semaforo_stop(name: str) -> bool:
    n = (name or "").strip()
    return n.lower().startswith("semaforo")


def main() -> None:
    with FC.open(encoding="utf-8") as f:
        fc = json.load(f)
    stops = fc.get("stops") or []
    removed_ids: set[str] = set()
    removed_names: list[str] = []
    kept: list[dict] = []
    for s in stops:
        name = s.get("name") or ""
        sid = str(s.get("id") or "").strip()
        if is_semaforo_stop(name):
            if sid:
                removed_ids.add(sid)
            removed_names.append(name)
        else:
            kept.append(s)
    fc["stops"] = kept
    with FC.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(fc, f, ensure_ascii=False, indent=2)
        f.write("\n")

    unique_names = sorted(set(removed_names))

    with TRANSITI.open(encoding="utf-8") as f:
        tr = json.load(f)
    rows = tr.get("transiti") or []
    tr["transiti"] = [t for t in rows if (t.get("nome_fermata") or "") not in unique_names]
    with TRANSITI.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(tr, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Removed {len(removed_names)} fermate_fc stops ({len(removed_ids)} ids).")
    print(f"Transiti: {len(rows)} -> {len(tr['transiti'])}")

    print("Loading transit_times_by_stop.json …")
    with TIMES.open(encoding="utf-8") as f:
        tt = json.load(f)
    st = tt.get("stops") or {}
    n_before = len(st)
    for sid in removed_ids:
        st.pop(sid, None)
    n_after = len(st)
    tt["stops"] = st
    print(f"transit_times stops: {n_before} -> {n_after} (removed {n_before - n_after})")
    print("Writing transit_times_by_stop.json …")
    with TIMES.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(tt, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print("\n--- Nomi fermate rimosse (unici) ---")
    for n in unique_names:
        print(n)


if __name__ == "__main__":
    main()
