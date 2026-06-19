#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Legge i libretti PDF e imposta "P":"1" nelle entry di assets/data/transit_times_by_stop.json
che corrispondono a corse su prenotazione (colonna con lettera P).

- CO_pre-estivo 26.pdf → solo 1CO, 2CO, 3CO
- inverno_FC 25-26.pdf → FO13, F132, F141, F148, F166, NAVL, NAVM (se route_*.json esiste; F208/F225 ignorate finché mancano i route JSON)

3CO festivo (domenica e festivi): in route_3CO.json ogni service_id elencato in
PRENOTAZIONE_SERVICE_IDS_3CO_FESTIVI contiene solo corse del libretto festivo
(Celle 07:35, 11:15, 14:20, 16:40, 17:10; Comandini 09:40, 12:40, 18:40; Cimitero 16:15, 16:45).

Uso: python tool/mark_prenotazione_libretti.py
"""
from __future__ import annotations

import json
import re
import sys
from collections.abc import Iterable
from pathlib import Path

import pdfplumber

ROOT = Path(__file__).resolve().parent.parent
OPEN_FC = ROOT / "Open Data/FC"
TRANSIT_JSON = ROOT / "assets/data/transit_times_by_stop.json"
CO_PDF = ROOT / "assets/data/libretti/CO_pre-estivo 26.pdf"
INV_PDF = ROOT / "assets/data/libretti/inverno_FC 25-26.pdf"

LINE_NUM_CO = {"1": "1CO", "2": "2CO", "3": "3CO"}

# Trip il cui libretto PDF (CO) dichiara P ma l’estrazione tabellare può perderli.
# (3CO 18:40 festivo: trip 818_1032832 coperto da PRENOTAZIONE_SERVICE_IDS_3CO_FESTIVI.)
RESCUE_TRIP_IDS_CO: dict[str, str] = {}

# Celle ↔ Comandini (3CO): corse P da Open Data, full-trip (non dipendono dalla colonna P del PDF).
# 08:15 da Comandini: due corse parallele — solo 818_1037188 (Celle 08:38) è su prenotazione.
PRENOTAZIONE_TRIP_IDS_3CO: frozenset[str] = frozenset(
    {
        # Celle → Comandini (libretto + GTFS)
        "818_1030433",
        "818_1030434",
        "818_1030435",
        "818_1030436",
        "818_1030437",
        "818_1030428",
        "818_1030429",
        # Comandini → Celle
        "818_1037188",
        "818_1032829",
        "818_1032826",
        "818_1032830",
        "818_1032831",
        "818_1032828",
    }
)

# Rimuovi P su tutto il viaggio (falsi positivi PDF o corsa non in libretto a quell’ora).
NO_PRENOTAZIONE_TRIP_IDS_3CO: frozenset[str] = frozenset(
    {
        "818_1032827",  # 08:15 → Celle 08:35 (non P; parallela a 818_1037188)
        "818_1037238",  # Celle 17:47 (feriale; non in elenco festivo)
    }
)

# 3CO domenica/festivi: in route_3CO.json questi service_id hanno solo le corse festive concordate.
PRENOTAZIONE_SERVICE_IDS_3CO_FESTIVI: frozenset[str] = frozenset(
    {
        "818_1000000006485",  # Celle 07:35; Comandini 09:40, 12:40, 18:40
        "818_1000000006477",  # Celle 11:15
        "818_1000000006476",  # Celle 14:20, 16:40; Cimitero→… (16:15)
        "818_1000000006473",  # Celle 17:10; Cimitero 16:45→…
    }
)

# Navetta Montiano: tutte le corse su prenotazione tranne le due eccezioni (14:00 Suzzi / 14:15 Montenovo).
NAVM_NO_PRENOTAZIONE_TRIP_IDS: frozenset[str] = frozenset(
    {
        "818_1036354",
        "818_1034646",
    }
)

# Linea 148: coppia 10:00 Cesena / 10:30 Gambettola (svc 6467), non le altre corse dello stesso svc.
PRENOTAZIONE_TRIP_IDS_F148: frozenset[str] = frozenset(
    {
        "818_1038759",
        "818_1038775",
    }
)

# Righe tabella libretto: colonna zona (3 cifre, tip. 7xx–9xx). Solo 890 era troppo stretto per i libretti FC.
ZONE_IN_ROW_RE = re.compile(r"\b[6-9]\d{2}\b")

INV_ROUTE_PATTERNS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"Navetta\s+Longiano", re.I), "NAVL"),
    (re.compile(r"Navetta\s+Montiano", re.I), "NAVM"),
    # "Linea 13" da sola (es. San Leonardo ↔ FS); non deve matchare Linea 131/132/134/136/137/138/139.
    (re.compile(r"(?<!\d)Linea\s+13\b(?!\d)"), "FO13"),
    (re.compile(r"Linea\s+132\b", re.I), "F132"),
    (re.compile(r"Linea\s+141\b", re.I), "F141"),
    (re.compile(r"Linea\s+148\b", re.I), "F148"),
    (re.compile(r"Linea\s+166\b", re.I), "F166"),
    (re.compile(r"Linea\s+208\b", re.I), "F208"),
    (re.compile(r"Linea\s+225\b", re.I), "F225"),
]


def norm_dep(s: str) -> str:
    s = s.strip()
    p = s.split(":")
    if len(p) == 2:
        return f"{int(p[0]):02d}:{int(p[1]):02d}:00"
    if len(p) == 3:
        return f"{int(p[0]):02d}:{int(p[1]):02d}:{int(p[2]):02d}"
    return s


def time_token(w: str) -> bool:
    return bool(re.match(r"^\d{1,2}:\d{2}(:\d{2})?$", w.strip()))


def is_p_symbol(text: str) -> bool:
    t = text.strip()
    if t.startswith("P"):
        return True
    return False


def row_words_at_y(words: list[dict], y_mid: float, tol: float = 2.8) -> list[dict]:
    return [w for w in words if abs((w["top"] + w["bottom"]) / 2 - y_mid) <= tol]


def cluster_row_mids(words: list[dict]) -> list[float]:
    tops = sorted({(w["top"] + w["bottom"]) / 2 for w in words})
    if not tops:
        return []
    rows = []
    cur = tops[0]
    for t in tops[1:]:
        if t - cur <= 3.0:
            cur = (cur + t) / 2
        else:
            rows.append(cur)
            cur = t
    rows.append(cur)
    return rows


def extract_table_marks(words: list[dict]) -> list[tuple[str, str]]:
    """
    Trova tabelle con header 'Zona … Località' e riga dati 890; allinea colonne P agli orari.
    Ritorna (anchor_label, dep HH:MM:SS).
    """
    out: list[tuple[str, str]] = []
    row_mids = cluster_row_mids(words)

    for ym in row_mids:
        rw = row_words_at_y(words, ym)
        joined = " ".join(w["text"] for w in sorted(rw, key=lambda x: x["x0"]))
        if "Localit" not in joined:
            continue
        if "Zona" not in joined and sum(1 for w in rw if w["text"].strip() == "P") < 2:
            continue

        # Simboli di colonna (P, §, …): nelle pagine FC spesso più a sinistra che a Cesenaatico 890.
        sym_words = [w for w in rw if w["x0"] >= 45]
        sym_sorted = sorted(sym_words, key=lambda x: x["x0"])

        # Non prendere la prima riga 890 (es. solo 3 orari IAL): scegli la riga "principale" del quadro.
        def ref_row_priority(j: str, n_times: int) -> tuple[int, int]:
            jl = j.lower()
            if "p.le comandini" in jl or re.search(r"890\s+.*comandini", jl):
                return (400, n_times)
            if "porto canale" in jl:
                return (350, n_times)
            if re.search(r"890\s+celle\b", jl):
                return (300, n_times)
            if "zadina" in jl and "campeggi" not in jl:
                return (250, n_times)
            if "stazione cesenatico" in jl:
                return (200, n_times)
            if "forlì punto bus" in jl or "forli punto bus" in jl:
                return (190, n_times)
            if "cesena punto bus" in jl:
                return (185, n_times)
            return (n_times, n_times)

        ref_row = None
        best_key: tuple[int, int] | None = None
        for cand in row_mids:
            if cand <= ym + 0.5:
                continue
            if cand > ym + 120:
                break
            r2 = row_words_at_y(words, cand)
            j2 = " ".join(w["text"] for w in sorted(r2, key=lambda x: x["x0"]))
            if not ZONE_IN_ROW_RE.search(j2):
                continue
            tks = [w["text"] for w in sorted(r2, key=lambda x: x["x0"]) if time_token(w["text"])]
            if len(tks) < 2:
                continue
            key = ref_row_priority(j2, len(tks))
            if best_key is None or key > best_key:
                best_key = key
                ref_row = r2
        if ref_row is None:
            continue

        w_sorted = sorted(ref_row, key=lambda x: x["x0"])
        anchor = "?"
        for wi, w in enumerate(w_sorted):
            if w["text"] == "890" and wi + 1 < len(w_sorted):
                rest = []
                for u in w_sorted[wi + 1 :]:
                    if time_token(u["text"]):
                        break
                    rest.append(u["text"])
                anchor = " ".join(rest).strip()
                break

        time_words = [w for w in w_sorted if time_token(w["text"])]
        if not time_words:
            continue

        marks = []
        for tw in time_words:
            cx = (tw["x0"] + tw["x1"]) / 2
            best_d = 999.0
            best_p = False
            for sw in sym_sorted:
                scx = (sw["x0"] + sw["x1"]) / 2
                d = abs(scx - cx)
                if d < best_d:
                    best_d = d
                    best_p = is_p_symbol(sw["text"])
            marks.append(best_p if best_d <= 14 else False)

        times = [norm_dep(w["text"]) for w in time_words]
        if len(marks) != len(times):
            continue
        for m, ti in zip(marks, times):
            if m:
                out.append((anchor, ti))
    return out


def detect_route_co_page(text: str) -> str | None:
    m = re.search(r"Linea\s+([123])\b", text)
    if m:
        return LINE_NUM_CO[m.group(1)]
    return None


def detect_route_inv_page(text: str) -> str | None:
    for pat, rid in INV_ROUTE_PATTERNS:
        if pat.search(text):
            return rid
    return None


def load_route_trips(route_id: str) -> list[dict] | None:
    f = OPEN_FC / f"route_{route_id}.json"
    if not f.exists():
        return None
    data = json.loads(f.read_text(encoding="utf-8"))
    return data.get("trips") or []


def anchor_to_stop_ids(anchor: str, route_id: str) -> list[str]:
    a = anchor.lower()
    if route_id == "3CO":
        if "comandini" in a:
            return ["10722", "10721"]
        if "celle" in a and "bivio" not in a:
            return ["30220", "30222"]
    if route_id in ("1CO", "2CO"):
        if "porto canale" in a or "porto" in a.split()[:2]:
            return ["30110"]
        if "comandini" in a or "carducci" in a:
            return ["30122"]
        if "zadina" in a and "campeggi" not in a:
            return ["30012"]
    return []


def trip_matches_stop_time(
    trip: dict, stop_ids: list[str], hhmmss: str
) -> bool:
    hhmm = hhmmss[:5]
    for st in trip.get("stop_times") or []:
        if str(st.get("stop_id")) not in stop_ids:
            continue
        dep = (st.get("departure_time") or st.get("arrival_time") or "").strip()
        if dep[:5] == hhmm:
            return True
    return False


def trip_markers(trip: dict, route_id: str) -> list[tuple[str, str, str, str]]:
    ck = f"FC|{route_id}"
    svc = str(trip.get("service_id") or "").strip()
    out = []
    for st in trip.get("stop_times") or []:
        sid = str(st.get("stop_id", "")).strip()
        dep = (st.get("departure_time") or st.get("arrival_time") or "").strip()
        if sid and dep:
            out.append((ck, sid, dep, svc))
    return out


def markers_full_trips_for_trip_ids(
    route_id: str, trip_ids: Iterable[str]
) -> set[tuple[str, str, str, str]]:
    want = {str(x) for x in trip_ids}
    trips = load_route_trips(route_id)
    if not trips:
        return set()
    out: set[tuple[str, str, str, str]] = set()
    for trip in trips:
        if str(trip.get("trip_id")) not in want:
            continue
        out.update(trip_markers(trip, route_id))
    return out


def markers_all_trips_route(route_id: str) -> set[tuple[str, str, str, str]]:
    trips = load_route_trips(route_id)
    if not trips:
        return set()
    out: set[tuple[str, str, str, str]] = set()
    for trip in trips:
        out.update(trip_markers(trip, route_id))
    return out


def markers_all_trips_route_except(
    route_id: str, exclude_trip_ids: frozenset[str]
) -> set[tuple[str, str, str, str]]:
    ex = {str(x) for x in exclude_trip_ids}
    trips = load_route_trips(route_id)
    if not trips:
        return set()
    out: set[tuple[str, str, str, str]] = set()
    for trip in trips:
        if str(trip.get("trip_id")) in ex:
            continue
        out.update(trip_markers(trip, route_id))
    return out


def markers_full_trips_for_service(
    route_id: str, service_id: str
) -> set[tuple[str, str, str, str]]:
    want_svc = str(service_id).strip()
    trips = load_route_trips(route_id)
    if not trips:
        return set()
    out: set[tuple[str, str, str, str]] = set()
    for trip in trips:
        if str(trip.get("service_id") or "").strip() != want_svc:
            continue
        out.update(trip_markers(trip, route_id))
    return out


def match_first_stop_trips(
    route_id: str, hhmmss: str
) -> set[tuple[str, str, str, str]]:
    """Match viaggi il cui primo stop ha partenza = hhmm (fallback senza ancoraggio fermata)."""
    trips = load_route_trips(route_id)
    if not trips:
        return set()
    hhmm = hhmmss[:5]
    marks: set[tuple[str, str, str, str]] = set()
    for trip in trips:
        sts = trip.get("stop_times") or []
        if not sts:
            continue
        d0 = (sts[0].get("departure_time") or sts[0].get("arrival_time") or "").strip()
        if d0[:5] != hhmm:
            continue
        for x in trip_markers(trip, route_id):
            marks.add(x)
    return marks


def process_pdf(path: Path, mode: str) -> set[tuple[str, str, str, str]]:
    marks: set[tuple[str, str, str, str]] = set()
    if not path.exists():
        print(f"SKIP mancante: {path}", file=sys.stderr)
        return marks

    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            if mode == "co":
                rid = detect_route_co_page(text)
                if not rid:
                    continue
            else:
                rid = detect_route_inv_page(text)
                if not rid or not (OPEN_FC / f"route_{rid}.json").exists():
                    continue

            words = page.extract_words(use_text_flow=False)
            for anchor, hhmmss in extract_table_marks(words):
                sid_list = anchor_to_stop_ids(anchor, rid)
                trips = load_route_trips(rid)
                if not trips:
                    continue
                if not sid_list:
                    marks |= match_first_stop_trips(rid, hhmmss)
                    continue
                for trip in trips:
                    if not trip_matches_stop_time(trip, sid_list, hhmmss):
                        continue
                    for x in trip_markers(trip, rid):
                        marks.add(x)

    if mode == "co":
        for tid, rid in RESCUE_TRIP_IDS_CO.items():
            trips = load_route_trips(rid)
            if not trips:
                continue
            for trip in trips:
                if str(trip.get("trip_id")) == tid:
                    for x in trip_markers(trip, rid):
                        marks.add(x)
                    break
    return marks


def apply_marks_to_json(marks: set[tuple[str, str, str, str]]) -> tuple[int, list[str]]:
    data = json.loads(TRANSIT_JSON.read_text(encoding="utf-8"))
    stops = data.get("stops")
    if not isinstance(stops, dict):
        raise SystemExit("JSON non valido")

    # Ricostruzione completa: rimuovi vecchi "P" su tutte le linee FC (evita falsi positivi da run precedenti).
    for sid, routes in stops.items():
        if not isinstance(routes, dict):
            continue
        for rk, entries in routes.items():
            if not isinstance(rk, str) or not rk.startswith("FC|"):
                continue
            if not isinstance(entries, list):
                continue
            for e in entries:
                if isinstance(e, dict) and "P" in e:
                    del e["P"]

    n = 0
    report_lines: list[str] = []
    for sid, routes in stops.items():
        if not isinstance(routes, dict):
            continue
        for rk, entries in routes.items():
            if not isinstance(entries, list):
                continue
            for e in entries:
                if not isinstance(e, dict):
                    continue
                dep = (e.get("dep") or "").strip()
                svc = (e.get("svc") or "").strip()
                key = (rk.strip(), str(sid).strip(), dep, svc)
                if key in marks:
                    if e.get("P") != "1":
                        e["P"] = "1"
                        n += 1
                    report_lines.append(f"{rk} stop {sid} dep {dep} svc {svc}")

    TRANSIT_JSON.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return n, sorted(set(report_lines))


def main() -> None:
    all_marks: set[tuple[str, str, str, str]] = set()
    all_marks |= process_pdf(CO_PDF, "co")
    all_marks |= process_pdf(INV_PDF, "inv")

    # Ground truth da route_*.json (corregge collisioni PDF / colonne P).
    all_marks |= markers_full_trips_for_trip_ids("3CO", PRENOTAZIONE_TRIP_IDS_3CO)
    all_marks -= markers_full_trips_for_trip_ids("3CO", NO_PRENOTAZIONE_TRIP_IDS_3CO)
    for svc_fest in PRENOTAZIONE_SERVICE_IDS_3CO_FESTIVI:
        all_marks |= markers_full_trips_for_service("3CO", svc_fest)
    all_marks |= markers_all_trips_route("NAVL")
    all_marks |= markers_all_trips_route_except("NAVM", NAVM_NO_PRENOTAZIONE_TRIP_IDS)
    all_marks |= markers_full_trips_for_trip_ids("F148", PRENOTAZIONE_TRIP_IDS_F148)
    all_marks |= markers_full_trips_for_service("F132", "818_1000000006609")

    print(f"Tripletta (chiave JSON) uniche: {len(all_marks)}")
    n, rep = apply_marks_to_json(all_marks)
    print(f'Campi aggiunti "P":"1" (numero entry aggiornate): {n}')
    print("--- Elenco route|stop|dep (unico) — max 400 righe ---")
    for line in rep[:400]:
        print(line)
    if len(rep) > 400:
        print(f"... e altre {len(rep) - 400} voci")

    report_path = ROOT / "tool/_p_report.txt"
    report_path.write_text(
        "\n".join(
            [
                f"Tripletta (chiave JSON) uniche: {len(all_marks)}",
                f'Campi "P":"1": {n}',
                "---",
            ]
            + rep
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Report salvato: {report_path.relative_to(ROOT)}")

if __name__ == "__main__":
    main()
