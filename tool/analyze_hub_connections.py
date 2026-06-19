#!/usr/bin/env python3
import json
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sec(h):
    p = h.split(":")
    return int(p[0]) * 3600 + int(p[1]) * 60 + int(p[2] if len(p) > 2 else 0)


def active(cal, basin, svc, date):
    return date.strftime("%Y%m%d") in cal.get(basin, {}).get(svc, [])


def trip_rows(trips, cal, basin, date, route_key):
    for tid, t in trips.items():
        if t.get("rk") != route_key:
            continue
        if not active(cal, basin, t["svc"], date):
            continue
        yield tid, [(s[0], s[1], s[2]) for s in t["st"]]


def leg_hits(st, board_ids, alight_ids, min_dep=0, max_dep=86400):
    by = {}
    for sid, seq, dep in st:
        by.setdefault(sid, []).append((seq, dep))
    out = []
    for b in board_ids:
        if b not in by:
            continue
        for a in alight_ids:
            if a not in by:
                continue
            for bseq, bdep in by[b]:
                bd = sec(bdep)
                if bd < min_dep or bd > max_dep:
                    continue
                for aseq, aarr in by[a]:
                    if aseq <= bseq:
                        continue
                    out.append((b, a, bdep, aarr, bd, sec(aarr)))
    out.sort(key=lambda x: x[4])
    return out


def main():
    date = datetime(2026, 6, 15)
    cal = json.loads((ROOT / "assets/data/service_calendars.json").read_text())
    fc = json.loads((ROOT / "assets/data/trip_index_fc.json").read_text())["trips"]
    ra = json.loads((ROOT / "assets/data/trip_index_ra.json").read_text())["trips"]
    rn = json.loads((ROOT / "assets/data/trip_index_rn.json").read_text())["trips"]

    cesena = {"999A2", "999B2", "20102"}
    cesenatico = {"15942", "10732", "10721", "30110"}
    forli = {"1660", "3120D", "151"}
    san_mauro_fc = {"11830"}
    rimini_ra = {"A00149", "W00026"}

    print("=== 94+92 Cesenatico -> Forli (08:00-10:00) ===")
    s094 = []
    for tid, st in trip_rows(fc, cal, "FC", date, "FC|S094"):
        s094.extend((tid, *h) for h in leg_hits(st, cesenatico, cesena, 7 * 3600, 10 * 3600))
    s092 = []
    for tid, st in trip_rows(fc, cal, "FC", date, "FC|S092"):
        s092.extend((tid, *h) for h in leg_hits(st, cesena, forli, 7 * 3600, 12 * 3600))
    print(f"S094 legs to Cesena hub: {len(s094)}")
    print(f"S092 legs from Cesena hub: {len(s092)}")
    combos = 0
    for t1, b1, a1, dep1, arr1, ds1, as1 in s094:
        if ds1 < 8 * 3600 or ds1 > 9 * 3600:
            continue
        for t2, b2, a2, dep2, arr2, ds2, as2 in s092:
            if b2 != a1:
                continue
            wait = ds2 - as1
            if 3 * 60 <= wait <= 25 * 60:
                combos += 1
                print(f"  94 {dep1}->{arr1}@{a1} + 92 {dep2}->{arr2} wait {wait//60}m")
    print("combos:", combos)

    print("\n=== F126 Cesenatico -> Forli (08:00-10:00) ===")
    n = 0
    for tid, st in trip_rows(fc, cal, "FC", date, "FC|F126"):
        for row in leg_hits(st, cesenatico, forli, 8 * 3600, 10 * 3600):
            n += 1
            print(f"  {row[2]}->{row[3]} trip {tid}")
    print("tot", n)

    print("\n=== S094 -> San Mauro Mare 11830 (tutti gli orari) ===")
    sm = []
    for tid, st in trip_rows(fc, cal, "FC", date, "FC|S094"):
        sm.extend((tid, *h) for h in leg_hits(st, cesenatico, san_mauro_fc))
    print(f"tot legs: {len(sm)}")
    for row in sm:
        print(f"  {row[2]} {row[0]}->{row[1]} arr {row[3]} trip {row[4]}")

    print("\n=== RA|4 da vicino San Mauro verso Rimini ===")
  # find RA stops near 11830
    ffc = json.loads((ROOT / "assets/data/fermate_fc.json").read_text(encoding="utf-8"))
    sm_pin = next(s for s in ffc if s["id"] == "11830")
    lat, lon = sm_pin["lat"], sm_pin["long"]
    fra = json.loads((ROOT / "assets/data/fermate_ra.json").read_text(encoding="utf-8"))

    def dist(a, b, c, d):
        from math import radians, sin, cos, atan2, sqrt

        r = 6371000
        la1, lo1, la2, lo2 = map(radians, [a, b, c, d])
        x = sin((la2 - la1) / 2) ** 2 + cos(la1) * cos(la2) * sin((lo2 - lo1) / 2) ** 2
        return 2 * r * atan2(sqrt(x), sqrt(1 - x))

    near_ra = sorted(
        ((dist(lat, lon, s["lat"], s["long"]), s["id"], s["name"]) for s in fra),
        key=lambda x: x[0],
    )[:8]
    print("RA stops near 11830:", near_ra)
    ra_near_ids = {x[1] for x in near_ra if x[0] < 2500}

    ra4 = []
    for tid, st in trip_rows(ra, cal, "RA", date, "RA|4"):
        ra4.extend((tid, *h) for h in leg_hits(st, ra_near_ids, rimini_ra, 6 * 3600, 22 * 3600))
    print(f"RA4 legs from near SM: {len(ra4)}")
    for row in ra4[:12]:
        print(f"  {row[2]}->{row[3]} trip {row[4]}")

    print("\n=== 94+4 combos via 11830 (wait<=20m) ===")
    c4 = 0
    for t1, b1, a1, dep1, arr1, ds1, as1 in sm:
        for t2, b2, a2, dep2, arr2, ds2, as2 in ra4:
            walk_ok = True  # assume transfer graph handles
            if b2 not in ra_near_ids:
                continue
            wait = ds2 - as1
            if 3 * 60 <= wait <= 20 * 60:
                c4 += 1
                print(f"  94 {dep1}->{arr1} + RA4 {dep2}->{arr2} wait {wait//60}m")
    print("combos:", c4)


if __name__ == "__main__":
    main()
