"""Enrich fermate_*.json with a `comune` field using reverse geocoding.

Writes `comune` as "Comune (PR)" for each stop in:
- assets/data/fermate_fc.json
- assets/data/fermate_ra.json
- assets/data/fermate_rn.json

The script is resumable via a coordinate cache file:
- assets/data/comune_reverse_cache.json
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "assets" / "data"
TARGET_FILES = [
    DATA_DIR / "fermate_fc.json",
    DATA_DIR / "fermate_ra.json",
    DATA_DIR / "fermate_rn.json",
]
CACHE_PATH = DATA_DIR / "comune_reverse_cache.json"


def cache_key(lat: float, lon: float) -> str:
    return f"{lat:.6f},{lon:.6f}"


def _province_from_iso(addr: dict[str, Any]) -> str | None:
    code = addr.get("ISO3166-2-lvl6")
    if not isinstance(code, str):
        return None
    parts = code.split("-")
    if len(parts) < 2:
        return None
    p = parts[-1].strip().upper()
    return p if len(p) == 2 else None


def _province_from_county(county: str) -> str | None:
    n = county.lower()
    pairs = {
        "forlì-cesena": "FC",
        "forli-cesena": "FC",
        "rimini": "RN",
        "ravenna": "RA",
        "bologna": "BO",
        "ferrara": "FE",
        "modena": "MO",
        "reggio nell": "RE",
        "reggio emilia": "RE",
        "parma": "PR",
        "piacenza": "PC",
        "pesaro": "PU",
        "urbino": "PU",
        "ancona": "AN",
        "macerata": "MC",
        "fermo": "FM",
        "ascoli": "AP",
        "perugia": "PG",
        "terni": "TR",
    }
    for k, v in pairs.items():
        if k in n:
            return v
    return None


def _pick_comune(addr: dict[str, Any]) -> str | None:
    for k in ("city", "town", "village", "hamlet", "municipality", "suburb"):
        v = addr.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip()
    return None


def reverse_comune(
    lat: float,
    lon: float,
    timeout_s: float = 12.0,
    email: str | None = None,
) -> str | None:
    params = {
        "lat": f"{lat}",
        "lon": f"{lon}",
        "format": "json",
        "addressdetails": "1",
        "accept-language": "it",
        "zoom": "16",
    }
    if email:
        params["email"] = email
    uri = f"https://nominatim.openstreetmap.org/reverse?{urlencode(params)}"
    req = Request(
        uri,
        headers={
            "User-Agent": "RomagnaGO/1.0 (stops comune enrichment)",
            "Accept": "application/json",
        },
        method="GET",
    )
    with urlopen(req, timeout=timeout_s) as resp:
        if resp.status != 200:
            return None
        data = json.loads(resp.read().decode("utf-8"))
    if not isinstance(data, dict):
        return None
    addr = data.get("address")
    if not isinstance(addr, dict):
        return None
    comune = _pick_comune(addr)
    if not comune:
        return None
    prov = _province_from_iso(addr)
    if not prov:
        county = addr.get("county")
        if isinstance(county, str):
            prov = _province_from_county(county)
    if not prov:
        prov = "??"
    return f"{comune} ({prov})"


def load_cache() -> dict[str, str]:
    if not CACHE_PATH.exists():
        return {}
    try:
        data = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            return {}
        out: dict[str, str] = {}
        for k, v in data.items():
            if isinstance(k, str) and isinstance(v, str):
                out[k] = v
        return out
    except Exception:
        return {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.write_text(
        json.dumps(cache, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


def load_files() -> list[tuple[Path, dict[str, Any]]]:
    out = []
    for p in TARGET_FILES:
        d = json.loads(p.read_text(encoding="utf-8"))
        out.append((p, d))
    return out


def collect_missing_coords(
    files: list[tuple[Path, dict[str, Any]]],
    cache: dict[str, str],
) -> list[tuple[str, float, float]]:
    coords: dict[str, tuple[float, float]] = {}
    for _, d in files:
        stops = d.get("stops")
        if not isinstance(stops, list):
            continue
        for s in stops:
            if not isinstance(s, dict):
                continue
            if isinstance(s.get("comune"), str) and s["comune"].strip():
                continue
            lat = s.get("lat")
            lon = s.get("long")
            if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                continue
            la = float(lat)
            lo = float(lon)
            if abs(la) > 90 or abs(lo) > 180:
                continue
            k = cache_key(la, lo)
            if k in cache:
                continue
            coords[k] = (la, lo)
    return [(k, v[0], v[1]) for k, v in coords.items()]


def write_back(
    files: list[tuple[Path, dict[str, Any]]],
    cache: dict[str, str],
) -> tuple[int, int]:
    updated = 0
    missing = 0
    for p, d in files:
        changed = False
        stops = d.get("stops")
        if not isinstance(stops, list):
            continue
        for s in stops:
            if not isinstance(s, dict):
                continue
            if isinstance(s.get("comune"), str) and s["comune"].strip():
                continue
            lat = s.get("lat")
            lon = s.get("long")
            if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
                continue
            k = cache_key(float(lat), float(lon))
            comune = cache.get(k)
            if comune:
                s["comune"] = comune
                changed = True
                updated += 1
            else:
                missing += 1
        if changed:
            p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            print(f"updated file: {p.name}")
    return updated, missing


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sleep-ms", type=int, default=1200, help="Delay between API calls")
    ap.add_argument("--max-new", type=int, default=0, help="Max new reverse calls (0 = all)")
    ap.add_argument("--retries", type=int, default=3)
    ap.add_argument("--email", type=str, default="", help="Contact email for Nominatim")
    args = ap.parse_args()

    files = load_files()
    cache = load_cache()
    pending = collect_missing_coords(files, cache)
    print(f"cache entries: {len(cache)}")
    print(f"missing unique coords: {len(pending)}")

    if args.max_new > 0:
        pending = pending[: args.max_new]
        print(f"processing limited batch: {len(pending)}")

    done = 0
    for i, (k, lat, lon) in enumerate(pending, start=1):
        ok = False
        for attempt in range(1, args.retries + 1):
            try:
                comune = reverse_comune(lat, lon, email=args.email.strip() or None)
                if comune:
                    cache[k] = comune
                ok = True
                break
            except HTTPError as e:
                if e.code == 429:
                    cooldown = 8.0 * attempt
                    print(f"429 rate-limit at {i}/{len(pending)}: cooldown {cooldown:.1f}s")
                    time.sleep(cooldown)
                    continue
                if attempt == args.retries:
                    break
                time.sleep(2.0 * attempt)
            except (URLError, TimeoutError):
                if attempt == args.retries:
                    break
                time.sleep(1.0 * attempt)
            except Exception:
                break
        done += 1
        if done % 25 == 0:
            save_cache(cache)
            updated, missing = write_back(files, cache)
            print(
                f"progress {i}/{len(pending)} | cache={len(cache)} | "
                f"updated_stops={updated} | still_missing={missing}",
            )
        if args.sleep_ms > 0:
            time.sleep(args.sleep_ms / 1000.0)
        if not ok:
            continue

    save_cache(cache)
    updated, missing = write_back(files, cache)
    print(
        f"done | cache={len(cache)} | updated_stops={updated} | still_missing={missing}",
    )


if __name__ == "__main__":
    main()
