"""Generate assets/data/orari/{fc,ra,rn}/orari_*.json from route_*.json (GTFS bundle)."""
from __future__ import annotations

import json
import shutil
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(r"C:\Users\lucag\Desktop\start-romagna-gtfs-estivo\data\estivo")
ORARI = ROOT / "assets" / "data" / "orari"
OPEN_DATA_INDEX = ROOT / "Open Data" / "index.json"
DESKTOP_INDEX = SRC / "index.json"
LIBRETTI_SRC = Path(r"C:\Users\lucag\Desktop\start-romagna-gtfs-estivo\orari\estivo")
LIBRETTI_DST = ROOT / "assets" / "data" / "libretti"

BASIN_MAP = {"FC": "fc", "RA": "ra", "RN": "rn"}
KEEP_TXT = {
    "fc": "controllo_incrociato_disabili_fc.txt",
    "ra": "controllo_incrociato_disabili_ra.txt",
}


def stop_name(stops: dict, stop_id: str) -> str:
    s = stops.get(str(stop_id), {})
    if isinstance(s, dict):
        n = s.get("name")
        if n:
            return str(n).strip()
    return str(stop_id)


def route_id_from_filename(path: Path) -> str:
    name = path.stem
    if name.startswith("route_"):
        return name[len("route_") :]
    return name


def route_to_orari(route_path: Path) -> dict:
    data = json.loads(route_path.read_text(encoding="utf-8"))
    route_meta = dict(data.get("route") or {})
    stops = data.get("stops") or {}
    trips = data.get("trips") or []
    groups: dict[str, list[dict]] = defaultdict(list)

    for trip in trips:
        if not isinstance(trip, dict):
            continue
        stop_times = trip.get("stop_times") or []
        if not stop_times:
            continue
        first = stop_times[0]
        last = stop_times[-1]
        fsid = str(first.get("stop_id", "")).strip()
        lsid = str(last.get("stop_id", "")).strip()
        label = f"{stop_name(stops, fsid)} > {stop_name(stops, lsid)}"
        groups[label].append(trip)

    direzioni_orari: list[dict] = []
    for label in sorted(groups.keys()):
        trip_list = groups[label]
        first_trip = trip_list[0]
        st = first_trip.get("stop_times") or []
        fsid = str(st[0].get("stop_id", "")).strip()
        lsid = str(st[-1].get("stop_id", "")).strip()
        partenze = sorted(
            {str(t.get("start_time")) for t in trip_list if t.get("start_time")}
        )
        corse = [
            {
                "trip_id": t.get("trip_id"),
                "service_id": t.get("service_id"),
                "start_time": t.get("start_time"),
                "end_time": t.get("end_time"),
            }
            for t in sorted(trip_list, key=lambda x: str(x.get("start_time", "")))
        ]
        direzioni_orari.append(
            {
                "direction_id": str(first_trip.get("direction_id", "0")),
                "direzione_percorso": label,
                "capolinea_partenza": {
                    "stop_id": fsid,
                    "stop_name": stop_name(stops, fsid),
                },
                "capolinea_arrivo": {
                    "stop_id": lsid,
                    "stop_name": stop_name(stops, lsid),
                },
                "trip_count": len(trip_list),
                "orari_partenza": partenze,
                "corse": corse,
            }
        )

    direzioni_percorso = sorted(groups.keys())
    route_out = {
        "basin": route_meta.get("basin"),
        "area": route_meta.get("area"),
        "line": route_meta.get("line") or route_meta.get("route_id"),
        "name": route_meta.get("name"),
        "direzioni_percorso": direzioni_percorso,
    }
    if route_meta.get("route_id"):
        route_out["route_id"] = route_meta.get("route_id")

    return {
        "estrazione": f"Orari da {route_path.name} (direzioni da nomi fermata)",
        "file_sorgente": str(route_path),
        "route": route_out,
        "totale_trips": len([t for t in trips if isinstance(t, dict)]),
        "totale_direzioni_percorso": len(direzioni_percorso),
        "direzioni_orari": direzioni_orari,
    }


def sync_orari_basin(basin_upper: str) -> list[str]:
    basin_lower = BASIN_MAP[basin_upper]
    src_dir = SRC / basin_upper
    dst_dir = ORARI / basin_lower
    dst_dir.mkdir(parents=True, exist_ok=True)

    keep = KEEP_TXT.get(basin_lower)
    for old in dst_dir.glob("orari_*.json"):
        old.unlink()

    written: list[str] = []
    for route_file in sorted(src_dir.glob("route_*.json")):
        route_id = route_id_from_filename(route_file)
        out_path = dst_dir / f"orari_{route_id}.json"
        payload = route_to_orari(route_file)
        out_path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        written.append(out_path.name)

    if keep and not (dst_dir / keep).exists():
        print(f"WARN: missing preserved file {dst_dir / keep}", file=sys.stderr)
    return written


def copy_index() -> None:
    if not DESKTOP_INDEX.exists():
        raise SystemExit(f"Missing {DESKTOP_INDEX}")
    shutil.copy2(DESKTOP_INDEX, OPEN_DATA_INDEX)


def copy_libretti() -> None:
    LIBRETTI_DST.mkdir(parents=True, exist_ok=True)
    for old in LIBRETTI_DST.glob("*.pdf"):
        old.unlink()
    for pdf in (LIBRETTI_SRC / "libretti").glob("*.pdf"):
        shutil.copy2(pdf, LIBRETTI_DST / pdf.name)
    fc_src = LIBRETTI_SRC / "FC"
    fc_dst = LIBRETTI_DST / "FC"
    if fc_src.is_dir():
        if fc_dst.exists():
            shutil.rmtree(fc_dst)
        shutil.copytree(fc_src, fc_dst)


def sync_linee_json() -> int:
    idx = json.loads(DESKTOP_INDEX.read_text(encoding="utf-8"))
    linee = []
    for r in idx.get("routes") or []:
        linee.append(
            {
                "linea": str(r.get("line") or r.get("route_id") or ""),
                "bacino": r["basin"],
                "area": r["area"],
                "route_id": str(r["route_id"]),
            }
        )
    order = {"RN": 0, "RA": 1, "FC": 2}
    linee.sort(key=lambda x: (order.get(x["bacino"], 9), x["area"], x["linea"]))
    out = ROOT / "assets" / "data" / "linee.json"
    out.write_text(json.dumps({"linee": linee}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return len(linee)


def main() -> None:
    copy_index()
    copy_libretti()
    counts = {}
    for basin in ("FC", "RA", "RN"):
        files = sync_orari_basin(basin)
        counts[basin] = len(files)
        print(f"{basin}: wrote {len(files)} orari_*.json")
    n_linee = sync_linee_json()
    print("index.json ->", OPEN_DATA_INDEX)
    print("libretti ->", LIBRETTI_DST)
    print("linee.json entries:", n_linee)
    print("totals:", counts)


if __name__ == "__main__":
    main()
