"""Download Start Romagna GTFS estivo bundle to Desktop."""
from __future__ import annotations

import json
import os
import urllib.request
from pathlib import Path
from urllib.error import HTTPError

BASE = "https://www.startromagna.it/orari-start-romagna"
OUT = Path(r"C:\Users\lucag\Desktop\start-romagna-gtfs-estivo")
DATA = OUT / "data" / "estivo"
ORARI = OUT / "orari" / "estivo"


def fetch(url: str) -> tuple[bytes, str | None]:
    req = urllib.request.Request(url, headers={"User-Agent": "RomagnaGO-download/1.0"})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read(), r.headers.get_content_type()


def save_bytes(path: Path, data: bytes) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return len(data)


def try_download(url: str, dest: Path, report: dict) -> bool:
    try:
        data, ctype = fetch(url)
        save_bytes(dest, data)
        report["ok"].append(
            {"url": url, "path": str(dest), "bytes": len(data), "type": ctype}
        )
        return True
    except HTTPError as e:
        report["failed"].append(
            {"url": url, "path": str(dest), "error": f"HTTP {e.code}"}
        )
        return False
    except Exception as e:
        report["failed"].append({"url": url, "path": str(dest), "error": str(e)})
        return False


def main() -> None:
    report: dict = {"ok": [], "failed": [], "skipped": []}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "LEGGIMI.txt").write_text(
        """Start Romagna GTFS estivo 2026
=============================

Scaricato da: https://www.startromagna.it/trova-linea-orari/
Bundle web: /orari-start-romagna/

Contenuto:
  config.json
  data/estivo/index.json
  data/estivo/{FC,RA,RN}/route_*.json
  data/estivo/{FC,RA,RN}/services.json
  data/estivo/locality_overrides.json
  data/estivo/area_overrides.json
  orari/estivo/libretti/libretto_{RN,RA,FC}.pdf
  orari/estivo/{RN,RA,FC}/*.pdf (se disponibili)
  _download_report.json
""",
        encoding="utf-8",
    )

    try_download(f"{BASE}/config.json", OUT / "config.json", report)

    for name in ("index.json", "locality_overrides.json", "area_overrides.json"):
        try_download(f"{BASE}/data/estivo/{name}", DATA / name, report)

    idx_path = DATA / "index.json"
    if not idx_path.exists():
        raise SystemExit("index.json non scaricato")

    idx = json.loads(idx_path.read_text(encoding="utf-8"))
    routes = idx.get("routes") or []
    (DATA / "_index_meta.json").write_text(
        json.dumps(
            {
                "version": idx.get("version"),
                "season": idx.get("season"),
                "validFrom": idx.get("validFrom"),
                "validTo": idx.get("validTo"),
                "areas": idx.get("areas"),
                "route_count": len(routes),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    for i, r in enumerate(routes, 1):
        data_file = (r.get("data_file") or "").strip()
        if not data_file:
            continue
        dest = DATA / data_file.replace("/", os.sep)
        try_download(f"{BASE}/data/estivo/{data_file}", dest, report)
        if i % 25 == 0:
            print(f"  route {i}/{len(routes)}")

    basins = sorted({r.get("basin") for r in routes if r.get("basin")})
    for b in basins:
        try_download(
            f"{BASE}/data/estivo/{b}/services.json",
            DATA / b / "services.json",
            report,
        )

    for b in ("RN", "RA", "FC"):
        try_download(
            f"{BASE}/orari/estivo/libretti/libretto_{b}.pdf",
            ORARI / "libretti" / f"libretto_{b}.pdf",
            report,
        )

    for r in routes:
        pdf = (r.get("pdf_url") or "").strip()
        if not pdf.endswith(".pdf"):
            continue
        rel = pdf.lstrip("./")
        if rel.startswith("orari/"):
            rel = rel[len("orari/") :]
        # index uses ./orari/RN/RN_Linea_1_est26.pdf -> estivo/RN/...
        parts = rel.split("/")
        if len(parts) >= 2:
            basin, fname = parts[-2], parts[-1]
            dest = ORARI / basin / fname
            try_download(f"{BASE}/orari/estivo/{basin}/{fname}", dest, report)

    report["summary"] = {
        "ok": len(report["ok"]),
        "failed": len(report["failed"]),
        "output": str(OUT),
    }
    (OUT / "_download_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("Output:", OUT)
    print("OK:", report["summary"]["ok"], "Failed:", report["summary"]["failed"])
    for f in report["failed"][:10]:
        print(" FAIL", f["url"], "->", f["error"])


if __name__ == "__main__":
    main()
