#!/usr/bin/env python3
"""Aggiorna linea/bacino in assets/data/linee.json secondo regole catalogo RomagnaGO."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LINEE = ROOT / "assets" / "data" / "linee.json"

SPECIAL = {
    "CEA1": ("1A", "CE"),
    "FOA1": ("1A", "FO"),
    "FOA5": ("5A", "FO"),
    "BA01": ("206", "FC"),
    "SA96": ("96A", "FC"),
    "LINR": ("R", "FC"),
    "NAVM": ("Navetta Montiano", "FC"),
    "SS02": ("Navetta Nefetti", "FC"),
}


def linea_from_route(route_id: str) -> str | None:
    rid = route_id.upper()
    if rid in SPECIAL:
        return SPECIAL[rid][0]
    m = re.fullmatch(r"F0(\d+)", rid)
    if m:
        return str(200 + int(m.group(1)))
    m = re.fullmatch(r"F(\d+)", rid)
    if m:
        return str(int(m.group(1)))
    m = re.fullmatch(r"FO(\d+)", rid)
    if m:
        return str(int(m.group(1)))
    m = re.fullmatch(r"CE(\d+)", rid)
    if m:
        return str(int(m.group(1)))
    if rid == "1-2CO":
        return "4"
    m = re.fullmatch(r"(\d+)CO", rid)
    if m:
        return m.group(1)
    m = re.fullmatch(r"S0*(\d+)", rid)
    if m:
        return m.group(1)
    if re.fullmatch(r"\d+", rid):
        return str(int(rid))
    return None


def bacino_for(row: dict) -> str:
    rid = row["route_id"].upper()
    area = row.get("area", "")
    if rid in SPECIAL:
        return SPECIAL[rid][1]
    if "CO" in rid:
        return "CO"
    if "forl" in area.lower():
        return "FO"
    if area == "Cesena":
        return "CE"
    b = row.get("bacino", "FC").upper()
    if b in ("RA", "RN"):
        return b
    return "FC"


def main() -> None:
    data = json.loads(LINEE.read_text(encoding="utf-8"))
    for row in data["linee"]:
        rid = row["route_id"]
        linea = linea_from_route(rid)
        if linea is not None:
            row["linea"] = linea
        row["bacino"] = bacino_for(row)
    LINEE.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"Updated {LINEE}")


if __name__ == "__main__":
    main()
