"""Populate `comune` in fermate_*.json via offline point-in-polygon.

Source boundaries:
openpolis/geojson-italy (municipal boundaries, WGS84)
https://raw.githubusercontent.com/openpolis/geojson-italy/master/geojson/limits_IT_municipalities.geojson

Only municipalities in provinces FC/RA/RN are used.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "assets" / "data"
TARGET_FILES = [
    DATA_DIR / "fermate_fc.json",
    DATA_DIR / "fermate_ra.json",
    DATA_DIR / "fermate_rn.json",
]
BOUNDARY_URL = (
    "https://raw.githubusercontent.com/openpolis/geojson-italy/master/"
    "geojson/limits_IT_municipalities.geojson"
)
CACHE_BOUNDARIES = DATA_DIR / "limits_romagna_municipalities.geojson"
PROV_ALLOWED = {"FC", "RA", "RN"}


@dataclass(frozen=True)
class RingBBox:
    min_lon: float
    min_lat: float
    max_lon: float
    max_lat: float

    def contains(self, lon: float, lat: float) -> bool:
        return (
            self.min_lon <= lon <= self.max_lon
            and self.min_lat <= lat <= self.max_lat
        )


@dataclass
class ComunePoly:
    comune_text: str
    polygons: list[list[list[float]]]  # list of rings (outer + holes)
    bboxes: list[RingBBox]  # one bbox for each polygon's outer ring
    centroid_lon: float
    centroid_lat: float


def _ring_bbox(ring: list[list[float]]) -> RingBBox:
    lons = [p[0] for p in ring]
    lats = [p[1] for p in ring]
    return RingBBox(min(lons), min(lats), max(lons), max(lats))


def _point_in_ring(lon: float, lat: float, ring: list[list[float]]) -> bool:
    inside = False
    n = len(ring)
    if n < 3:
        return False
    j = n - 1
    for i in range(n):
        xi, yi = ring[i][0], ring[i][1]
        xj, yj = ring[j][0], ring[j][1]
        intersects = ((yi > lat) != (yj > lat)) and (
            lon < (xj - xi) * (lat - yi) / ((yj - yi) or 1e-15) + xi
        )
        if intersects:
            inside = not inside
        j = i
    return inside


def _point_in_polygon(lon: float, lat: float, rings: list[list[list[float]]]) -> bool:
    if not rings:
        return False
    if not _point_in_ring(lon, lat, rings[0]):  # outside outer ring
        return False
    for hole in rings[1:]:
        if _point_in_ring(lon, lat, hole):  # inside a hole
            return False
    return True


def _approx_polygon_centroid(rings: list[list[list[float]]]) -> tuple[float, float]:
    # Approximate centroid from outer ring vertices (sufficient for fallback nearest-comune).
    outer = rings[0]
    sx = 0.0
    sy = 0.0
    n = 0
    for p in outer:
        if not isinstance(p, list) or len(p) < 2:
            continue
        sx += float(p[0])
        sy += float(p[1])
        n += 1
    if n == 0:
        return 0.0, 0.0
    return sx / n, sy / n


def _coerce_multipolygon_coords(geom: dict[str, Any]) -> list[list[list[list[float]]]]:
    gtype = geom.get("type")
    coords = geom.get("coordinates")
    if gtype == "Polygon" and isinstance(coords, list):
        return [coords]  # one polygon (list of rings)
    if gtype == "MultiPolygon" and isinstance(coords, list):
        return coords
    return []


def load_romagna_boundaries() -> list[ComunePoly]:
    if CACHE_BOUNDARIES.exists():
        raw = CACHE_BOUNDARIES.read_text(encoding="utf-8")
    else:
        with urlopen(BOUNDARY_URL, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
        CACHE_BOUNDARIES.write_text(raw, encoding="utf-8")

    data = json.loads(raw)
    feats = data.get("features")
    if not isinstance(feats, list):
        raise RuntimeError("GeoJSON features missing")

    out: list[ComunePoly] = []
    for f in feats:
        if not isinstance(f, dict):
            continue
        props = f.get("properties")
        geom = f.get("geometry")
        if not isinstance(props, dict) or not isinstance(geom, dict):
            continue
        prov = props.get("prov_acr")
        if not isinstance(prov, str) or prov not in PROV_ALLOWED:
            continue
        name = props.get("name")
        if not isinstance(name, str) or not name.strip():
            continue
        comune_text = f"{name.strip()} ({prov})"

        polys = _coerce_multipolygon_coords(geom)
        prepared_polys: list[list[list[float]]] = []
        bboxes: list[RingBBox] = []
        centroid_lons: list[float] = []
        centroid_lats: list[float] = []
        for p in polys:
            if not isinstance(p, list) or not p:
                continue
            outer = p[0]
            if not isinstance(outer, list) or len(outer) < 4:
                continue
            # Keep this polygon with all its rings
            prepared_polys.append(p)
            bboxes.append(_ring_bbox(outer))
            cx, cy = _approx_polygon_centroid(p)
            centroid_lons.append(cx)
            centroid_lats.append(cy)

        if prepared_polys:
            out.append(
                ComunePoly(
                    comune_text=comune_text,
                    polygons=prepared_polys,
                    bboxes=bboxes,
                    centroid_lon=sum(centroid_lons) / len(centroid_lons),
                    centroid_lat=sum(centroid_lats) / len(centroid_lats),
                )
            )

    return out


def find_comune(lon: float, lat: float, comuni: list[ComunePoly]) -> str | None:
    for c in comuni:
        for rings, bbox in zip(c.polygons, c.bboxes):
            if not bbox.contains(lon, lat):
                continue
            if _point_in_polygon(lon, lat, rings):
                return c.comune_text
    return None


def nearest_comune(lon: float, lat: float, comuni: list[ComunePoly]) -> str:
    best = comuni[0].comune_text
    best_d = float("inf")
    for c in comuni:
        dx = lon - c.centroid_lon
        dy = lat - c.centroid_lat
        d = dx * dx + dy * dy
        if d < best_d:
            best_d = d
            best = c.comune_text
    return best


def enrich_file(path: Path, comuni: list[ComunePoly]) -> tuple[int, int, int]:
    data = json.loads(path.read_text(encoding="utf-8"))
    stops = data.get("stops")
    if not isinstance(stops, list):
        return 0, 0
    updated = 0
    missing = 0
    nearest_used = 0
    for s in stops:
        if not isinstance(s, dict):
            continue
        lat = s.get("lat")
        lon = s.get("long")
        if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
            missing += 1
            continue
        la = float(lat)
        lo = float(lon)
        if abs(la) > 90 or abs(lo) > 180:
            missing += 1
            continue
        comune = find_comune(lo, la, comuni)
        if comune is None:
            comune = nearest_comune(lo, la, comuni)
            nearest_used += 1
        if s.get("comune") != comune:
            s["comune"] = comune
            updated += 1

    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return updated, missing, nearest_used


def main() -> None:
    comuni = load_romagna_boundaries()
    print(f"loaded romagna comuni polygons: {len(comuni)}")

    total_updated = 0
    total_missing = 0
    total_nearest = 0
    for p in TARGET_FILES:
        updated, missing, nearest_used = enrich_file(p, comuni)
        total_updated += updated
        total_missing += missing
        total_nearest += nearest_used
        print(
            f"{p.name}: updated={updated} missing={missing} nearest_fallback={nearest_used}"
        )

    print(
        f"done: total_updated={total_updated} total_missing={total_missing} "
        f"nearest_fallback={total_nearest}"
    )


if __name__ == "__main__":
    main()
