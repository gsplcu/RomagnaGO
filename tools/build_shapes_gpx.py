"""Generate route shape GPX under assets/shapes; optional move + RN/RA batch."""
from __future__ import annotations

import json
import re
import shutil
import unicodedata
import xml.sax.saxutils as sx
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHAPES = ROOT / "assets" / "shapes"
OD = ROOT / "Open Data"

pat_dup = re.compile(r"^(?P<base>.+)__(?P<sid>\d+)\.gpx$", re.I)


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


def to_lat_lon(coord: list | tuple) -> tuple[float, float] | None:
    """GTFS bundle may ship [lat, lon] or [lon, lat]; detect for Romagna."""
    if not isinstance(coord, (list, tuple)) or len(coord) < 2:
        return None
    a, b = float(coord[0]), float(coord[1])
    if 40.0 <= a <= 47.0 and 8.0 <= b <= 16.0:
        return a, b
    if 40.0 <= b <= 47.0 and 8.0 <= a <= 16.0:
        return b, a
    return a, b


def hhmm(t: str | None) -> str | None:
    if not t or not isinstance(t, str):
        return None
    parts = t.strip().split(":")
    if len(parts) < 2:
        return None
    return f"{int(parts[0]):02d}{int(parts[1]):02d}"


def times_for_shape(data: dict, sid: str) -> list[str]:
    seen: list[str] = []
    for tr in data.get("trips") or []:
        if not isinstance(tr, dict):
            continue
        if str(tr.get("shape_id", "")).strip() != sid:
            continue
        h = hhmm(tr.get("start_time"))
        if h and h not in seen:
            seen.append(h)
    seen.sort()
    return seen


def build_suffix(times: list[str]) -> str:
    if not times:
        return "no_times"
    if len(times) <= 24:
        return "-".join(times)
    return f"{times[0]}-{times[-1]}_{len(times)}runs"


def generate_route_folder(json_path: Path, out_base: Path) -> int:
    route_name = json_path.stem
    out_dir = out_base / route_name
    out_dir.mkdir(parents=True, exist_ok=True)
    data = json.loads(json_path.read_text(encoding="utf-8"))
    shapes = data.get("shapes", {})
    stops = data.get("stops", {})
    trips = data.get("trips", [])

    shape_terminals: dict[str, tuple[str, str]] = {}
    for t in trips:
        if not isinstance(t, dict):
            continue
        sid = str(t.get("shape_id", "")).strip()
        st = t.get("stop_times") or []
        if not sid or not st or sid in shape_terminals:
            continue
        first = str(st[0].get("stop_id", "")).strip() if isinstance(st[0], dict) else ""
        last = str(st[-1].get("stop_id", "")).strip() if isinstance(st[-1], dict) else ""
        if first and last:
            shape_terminals[sid] = (first, last)

    used_names: set[str] = set()
    created = 0
    if not isinstance(shapes, dict):
        return 0
    for shape_id, coords in shapes.items():
        if not isinstance(coords, list) or not coords:
            continue
        sid = str(shape_id)
        terminals = shape_terminals.get(sid)
        if terminals:
            dep = stop_name(stops, terminals[0])
            arr = stop_name(stops, terminals[1])
        else:
            dep = f"shape_{sid}"
            arr = "unknown"
        base = f"{slug(dep)}_to_{slug(arr)}"
        fn = base + ".gpx"
        if fn in used_names:
            fn = f"{base}__{sid}.gpx"
        used_names.add(fn)

        pts: list[tuple[float, float]] = []
        for c in coords:
            ll = to_lat_lon(c)
            if ll is not None:
                pts.append(ll)
        if not pts:
            continue
        trk_name = sx.escape(f"{dep} -> {arr} [{sid}]")
        lines = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<gpx version="1.1" creator="RomagnaGO" xmlns="http://www.topografix.com/GPX/1/1">',
            f"  <trk><name>{trk_name}</name><trkseg>",
        ]
        for lat, lon in pts:
            lines.append(f'    <trkpt lat="{lat:.8f}" lon="{lon:.8f}" />')
        lines.append("  </trkseg></trk>")
        lines.append("</gpx>")
        (out_dir / fn).write_text("\n".join(lines) + "\n", encoding="utf-8")
        created += 1
    return created


def rename_duplicates_with_times(route_dir: Path, data_json: Path) -> int:
    if not data_json.exists():
        return 0
    data = json.loads(data_json.read_text(encoding="utf-8"))
    files = {p.name: p for p in route_dir.glob("*.gpx")}
    renamed = 0
    for fname, path in list(files.items()):
        m = pat_dup.match(fname)
        if not m:
            continue
        base = m.group("base")
        sid = m.group("sid")
        plain = base + ".gpx"
        if plain not in files:
            continue
        times = times_for_shape(data, sid)
        suf = build_suffix(times)
        new_name = f"{base}_{suf}__{sid}.gpx"
        new_path = route_dir / new_name
        if new_path.exists() and new_path.resolve() != path.resolve():
            continue
        path.rename(new_path)
        renamed += 1
        files.pop(fname, None)
        files[new_name] = new_path
    return renamed


def move_fc_shapes() -> None:
    SHAPES.mkdir(parents=True, exist_ok=True)
    fc_dir = SHAPES / "fc"
    fc_dir.mkdir(parents=True, exist_ok=True)
    for child in list(SHAPES.iterdir()):
        if not child.is_dir():
            continue
        if child.name in ("fc", "rn", "ra"):
            continue
        dest = fc_dir / child.name
        if dest.exists():
            shutil.rmtree(dest)
        shutil.move(str(child), str(dest))
        print("moved", child.name, "-> fc/")


def expected_route_dirs(od_sub: str) -> set[str]:
    od_path = OD / od_sub
    return {
        p.stem
        for p in od_path.glob("route_*.json")
        if p.is_file()
    }


def prune_stale_shape_dirs(out_sub: str, od_sub: str) -> int:
    out_base = SHAPES / out_sub
    if not out_base.is_dir():
        return 0
    keep = expected_route_dirs(od_sub)
    removed = 0
    for child in list(out_base.iterdir()):
        if not child.is_dir() or not child.name.startswith("route_"):
            continue
        if child.name not in keep:
            shutil.rmtree(child)
            removed += 1
    return removed


def refresh_route_shapes(json_path: Path, out_base: Path) -> int:
    route_name = json_path.stem
    out_dir = out_base / route_name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    return generate_route_folder(json_path, out_base)


def generate_basin(od_sub: str, out_sub: str) -> int:
    out_base = SHAPES / out_sub
    out_base.mkdir(parents=True, exist_ok=True)
    pruned = prune_stale_shape_dirs(out_sub, od_sub)
    if pruned:
        print(out_sub, "removed stale route dirs:", pruned)
    total = 0
    for jf in sorted((OD / od_sub).glob("route_*.json")):
        total += refresh_route_shapes(jf, out_base)
    print(out_sub, "gpx segments:", total)
    return total


def process_basin_renames(out_sub: str, od_sub: str) -> int:
    basin_dir = SHAPES / out_sub
    od_path = OD / od_sub
    renamed = 0
    for route_dir in sorted(basin_dir.iterdir()):
        if not route_dir.is_dir():
            continue
        jf = od_path / f"{route_dir.name}.json"
        renamed += rename_duplicates_with_times(route_dir, jf)
    print(out_sub, "time-renames:", renamed)
    return renamed


def main() -> None:
    for od_sub, out_sub in (("FC", "fc"), ("RA", "ra"), ("RN", "rn")):
        generate_basin(od_sub, out_sub)
        process_basin_renames(out_sub, od_sub)
    print("done")


if __name__ == "__main__":
    main()
