"""Write partenze_per_shape.txt next to GPX: per ogni shape, shape_id, direzione, soli orari partenza (HHMM)."""
from __future__ import annotations

import json
import re
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHAPES = ROOT / "assets" / "shapes"
OD = ROOT / "Open Data"

BASINS: tuple[tuple[str, str], ...] = (("fc", "FC"), ("rn", "RN"), ("ra", "RA"))
OUT_NAME = "partenze_per_shape.txt"


def slug(text: str) -> str:
    t = unicodedata.normalize("NFKD", str(text))
    t = "".join(ch for ch in t if not unicodedata.combining(ch))
    t = t.lower().replace("→", " to ")
    t = re.sub(r"[^a-z0-9]+", "_", t).strip("_")
    return t or "shape"


def stop_name(stops: dict, stop_id: str) -> str:
    s = stops.get(str(stop_id), {}) if isinstance(stops, dict) else {}
    n = s.get("name") if isinstance(s, dict) else None
    return str(n).strip() if n else str(stop_id)


def hhmm_from_clock(t: str | None) -> str | None:
    if not t or not isinstance(t, str):
        return None
    parts = t.strip().split(":")
    if len(parts) < 2:
        return None
    return f"{int(parts[0]):02d}{int(parts[1]):02d}"


def first_departure_hhmm(trip: dict) -> str | None:
    st = trip.get("stop_times") or []
    if not st:
        return hhmm_from_clock(trip.get("start_time"))
    ordered = sorted(
        (x for x in st if isinstance(x, dict)),
        key=lambda x: int(x.get("stop_sequence") or 0),
    )
    if not ordered:
        return hhmm_from_clock(trip.get("start_time"))
    dep = ordered[0].get("departure_time") or ordered[0].get("arrival_time")
    return hhmm_from_clock(dep) or hhmm_from_clock(trip.get("start_time"))


def shape_terminals_from_trips(trips: list, stops: dict) -> dict[str, tuple[str, str, str, str]]:
    """shape_id -> (first_id, last_id, first_name, last_name)"""
    out: dict[str, tuple[str, str, str, str]] = {}
    for t in trips:
        if not isinstance(t, dict):
            continue
        sid = str(t.get("shape_id", "")).strip()
        st = t.get("stop_times") or []
        if not sid or not st or sid in out:
            continue
        ordered = sorted(
            (x for x in st if isinstance(x, dict)),
            key=lambda x: int(x.get("stop_sequence") or 0),
        )
        if len(ordered) < 2:
            continue
        first = str(ordered[0].get("stop_id", "")).strip()
        last = str(ordered[-1].get("stop_id", "")).strip()
        if first and last:
            out[sid] = (
                first,
                last,
                stop_name(stops, first),
                stop_name(stops, last),
            )
    return out


def departures_per_shape(data: dict) -> dict[str, list[str]]:
    """shape_id -> sorted unique HHMM from first-stop departure of each trip."""
    acc: dict[str, list[str]] = {}
    for tr in data.get("trips") or []:
        if not isinstance(tr, dict):
            continue
        sid = str(tr.get("shape_id", "")).strip()
        if not sid:
            continue
        h = first_departure_hhmm(tr)
        if not h:
            continue
        if sid not in acc:
            acc[sid] = []
        if h not in acc[sid]:
            acc[sid].append(h)
    for sid in acc:
        acc[sid].sort()
    return acc


def write_summary_for_route(json_path: Path, route_dir: Path) -> bool:
    if not json_path.is_file():
        return False
    data = json.loads(json_path.read_text(encoding="utf-8"))
    shapes = data.get("shapes", {})
    if not isinstance(shapes, dict):
        return False
    stops = data.get("stops", {}) if isinstance(data.get("stops"), dict) else {}
    trips = data.get("trips") or []
    terminals = shape_terminals_from_trips(trips, stops)
    by_shape = departures_per_shape(data)

    route_meta = data.get("route") if isinstance(data.get("route"), dict) else {}
    line_label = str(route_meta.get("line") or route_meta.get("route_id") or json_path.stem).strip()
    basin = str(route_meta.get("basin") or "").strip()

    # Stessa selezione shape del GPX: solo coordinate non vuote
    shape_ids: list[str] = []
    for shape_id, coords in shapes.items():
        if isinstance(coords, list) and coords:
            shape_ids.append(str(shape_id))

    def sort_key(s: str) -> tuple[int, str]:
        return (int(s) if s.isdigit() else 10**18, s)

    shape_ids.sort(key=sort_key)

    blocks: list[str] = []
    for sid in shape_ids:
        t = terminals.get(sid)
        if t:
            dep_n, arr_n = t[2], t[3]
            direzione = f"{dep_n} -> {arr_n}"
        else:
            direzione = f"shape_{sid} -> unknown"
        times = by_shape.get(sid, [])
        times_line = " ".join(times) if times else ""
        blocks.append(f"shape_id {sid}\n{direzione}\n{times_line}")

    header = f"# {json_path.name}"
    if basin or line_label:
        header += f" | {basin} linea {line_label}".rstrip()
    if blocks:
        text = header.rstrip() + "\n\n" + "\n\n---\n\n".join(blocks) + "\n"
    else:
        text = header.rstrip() + "\n"
    (route_dir / OUT_NAME).write_text(text, encoding="utf-8")
    return True


def main() -> None:
    n = 0
    for shapes_sub, od_sub in BASINS:
        basin_dir = SHAPES / shapes_sub
        od_dir = OD / od_sub
        if not basin_dir.is_dir():
            continue
        for route_dir in sorted(basin_dir.iterdir()):
            if not route_dir.is_dir():
                continue
            jf = od_dir / f"{route_dir.name}.json"
            if write_summary_for_route(jf, route_dir):
                n += 1
    print("wrote", OUT_NAME, "in", n, "route folders")


if __name__ == "__main__":
    main()
