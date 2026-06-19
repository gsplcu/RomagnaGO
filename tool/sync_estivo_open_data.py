"""Copy estivo GTFS route JSON from Desktop bundle into Open Data/{FC,RA,RN}."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(r"C:\Users\lucag\Desktop\start-romagna-gtfs-estivo\data\estivo")
OD = ROOT / "Open Data"
BASINS = ("FC", "RA", "RN")


def sync_basin(basin: str) -> tuple[int, int, int]:
    src_dir = SRC / basin
    dst_dir = OD / basin
    dst_dir.mkdir(parents=True, exist_ok=True)

    copied = 0
    for src_file in sorted(src_dir.glob("route_*.json")):
        shutil.copy2(src_file, dst_dir / src_file.name)
        copied += 1

    services = src_dir / "services.json"
    if services.exists():
        shutil.copy2(services, dst_dir / "services.json")

    keep = {p.name for p in src_dir.glob("route_*.json")} | {"services.json"}
    removed = 0
    for old in dst_dir.glob("*.json"):
        if old.name not in keep:
            old.unlink()
            removed += 1
    return copied, removed, 1 if services.exists() else 0


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Bundle mancante: {SRC}")
    idx_src = SRC / "index.json"
    if idx_src.exists():
        shutil.copy2(idx_src, OD / "index.json")
    for basin in BASINS:
        c, r, s = sync_basin(basin)
        print(f"{basin}: copied {c} routes, removed {r} stale json, services={s}")


if __name__ == "__main__":
    main()
