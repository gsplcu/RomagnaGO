#!/usr/bin/env python3
"""
Rigenera le voci pubspec per le cartelle assets/shapes/{fc,ra,rn}/route_*/
e aggiorna pubspec.yaml (compatibile Windows, niente glob **).

Esecuzione dalla root del progetto:
  python tool/gen_shape_asset_lines.py
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


def collect_shape_folder_lines(root: Path) -> list[str]:
    lines: list[str] = []
    for bac in ("fc", "ra", "rn"):
        p = root / "assets" / "shapes" / bac
        if not p.is_dir():
            print(f"Avviso: cartella assente {p}", file=sys.stderr)
            continue
        for name in sorted(os.listdir(p)):
            d = p / name
            if name.startswith("route_") and d.is_dir():
                lines.append(f"    - assets/shapes/{bac}/{name}/")
    return lines


def patch_pubspec(root: Path, generated: list[str]) -> None:
    pub = root / "pubspec.yaml"
    text = pub.read_text(encoding="utf-8")
    lines = text.splitlines()

    anchor_after = "    - assets/logofull_square_for_launcher.png"
    anchor_before = "    - assets/data/linee.json"

    try:
        end_idx = lines.index(anchor_after)
    except ValueError as e:
        raise SystemExit(
            f"pubspec.yaml: non trovo la riga ancoraggio dopo gli shape:\n  {anchor_after!r}"
        ) from e

    try:
        before_idx = lines.index(anchor_before)
    except ValueError as e:
        raise SystemExit(
            f"pubspec.yaml: non trovo la riga ancoraggio prima degli shape:\n  {anchor_before!r}"
        ) from e

    start_idx: int | None = None
    for i in range(before_idx + 1, end_idx):
        ln = lines[i]
        if "Tracciati GPX" in ln or "RFG_SHAPES" in ln:
            start_idx = i
            break
        if ln.startswith("    - assets/shapes/"):
            start_idx = i
            break

    header = (
        "    # Tracciati GPX: rigenerato da tool/gen_shape_asset_lines.py "
        "(una riga per cartella route_*; compatibile Windows)."
    )
    block = [header, *generated]

    if start_idx is None:
        new_lines = lines[:end_idx] + block + lines[end_idx:]
    else:
        new_lines = lines[:start_idx] + block + lines[end_idx:]

    pub.write_text("\n".join(new_lines) + "\n", encoding="utf-8")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    generated = collect_shape_folder_lines(root)

    frag = root / "tool" / "_shape_asset_lines.txt"
    frag.write_text("\n".join(generated) + "\n", encoding="utf-8")

    patch_pubspec(root, generated)

    print(f"OK: {len(generated)} cartelle route_*")
    print(f"     Fragment: {frag}")
    print("     pubspec.yaml aggiornato. Esegui: flutter pub get")


if __name__ == "__main__":
    main()
