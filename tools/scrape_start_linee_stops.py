"""
Download Start Romagna /linee/{slug}/ pages and extract Google Maps marker arrays.
Output: JSON sotto assets/data/ (schema: source_url, line_label, note, directions).
Non generare file indice separati: metadati menù Orari v2.0 nel campo `note`.
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data"

USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) RomagnaGO-scraper/1.0"


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=90) as r:
        return r.read().decode("utf-8", errors="replace")


# ['Name', lat, lng, seq], ...
ROW_RE = re.compile(
    r"\[\s*'([^']*(?:''[^']*)*)'\s*,\s*([0-9.+-]+)\s*,\s*([0-9.+-]+)\s*,\s*(\d+)\s*\]"
)


def extract_array(html: str, var_name: str) -> list[tuple[str, float, float, int]]:
    m = re.search(
        rf"var\s+{re.escape(var_name)}\s*=\s*\[(.*?)\]\s*;",
        html,
        re.DOTALL,
    )
    if not m:
        return []
    body = m.group(1)
    out: list[tuple[str, float, float, int]] = []
    for name, la, lo, seq in ROW_RE.findall(body):
        name = name.replace("''", "'")
        out.append((name, float(la), float(lo), int(seq)))
    return out


def slugify_id(text: str) -> str:
    """Id direzione snake_case ASCII (estremità percorso)."""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower()
    text = text.replace("→", " to ").replace("–", "-")
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


def direction_id_from_label(label: str) -> str:
    parts = re.split(r"\s*→\s*", label, maxsplit=1)
    if len(parts) == 2:
        return f"{slugify_id(parts[0])}_to_{slugify_id(parts[1])}"
    return slugify_id(label)


def extract_route_labels(html: str) -> tuple[str | None, str | None]:
    """Estrae i titoli percorso da #fermate_linee1 / #fermate_linee2 (tag strong)."""
    lab1 = lab2 = None
    m1 = re.search(
        r'id="fermate_linee1"[^>]*>.*?<strong[^>]*class="[^"]*mb-3[^"]*_h4[^"]*"[^>]*>([^<]+)</strong>',
        html,
        re.DOTALL | re.I,
    )
    if m1:
        lab1 = re.sub(r"\s+", " ", m1.group(1)).strip()
    m2 = re.search(
        r'id="fermate_linee2"[^>]*>.*?<strong[^>]*class="[^"]*mb-3[^"]*_h4[^"]*"[^>]*>([^<]+)</strong>',
        html,
        re.DOTALL | re.I,
    )
    if m2:
        lab2 = re.sub(r"\s+", " ", m2.group(1)).strip()
    return lab1, lab2


def page_to_json(
    url: str,
    html: str,
    *,
    line_number: str,
    wordpress_post_id: int,
    orari_menu_url: str,
) -> dict:
    loc1 = extract_array(html, "locations")
    loc2 = extract_array(html, "locations2")
    lab1, lab2 = extract_route_labels(html)

    def pack(
        rows: list[tuple[str, float, float, int]],
    ) -> list[dict]:
        return [
            {
                "sequence": seq,
                "stop_name": name,
                "lat": lat,
                "long": lon,
            }
            for name, lat, lon, seq in rows
        ]

    directions: list[dict] = []
    if loc1:
        lb = lab1 or "Percorso 1"
        directions.append(
            {
                "id": direction_id_from_label(lb),
                "label": lb,
                "stops": pack(loc1),
            }
        )
    if loc2:
        lb = lab2 or "Percorso 2"
        directions.append(
            {
                "id": direction_id_from_label(lb),
                "label": lb,
                "stops": pack(loc2),
            }
        )

    slug = url.rstrip("/").split("/")[-1]
    line_label = f"{line_number} — Cesenatico"

    note = (
        "Coordinate estratte dagli array JavaScript `locations` / `locations2` "
        "della pagina ufficiale (ordine come sul sito). "
        f"Menù «Cerca per linea» su {orari_menu_url} "
        f"(ID WordPress {wordpress_post_id}, slug {slug})."
    )

    return {
        "source_url": url,
        "line_label": line_label,
        "note": note,
        "directions": directions,
    }


ORARI_MENU = "https://www.startromagna.it/orari-e-percorsi-vers-2-0/"


def format_linea_stops_json(data: dict) -> str:
    """JSON indentato: ogni fermata su una riga."""
    lines: list[str] = []
    lines.append("{")
    lines.append(f'  "source_url": {json.dumps(data["source_url"], ensure_ascii=False)},')
    lines.append(f'  "line_label": {json.dumps(data["line_label"], ensure_ascii=False)},')
    lines.append(f'  "note": {json.dumps(data["note"], ensure_ascii=False)},')
    lines.append('  "directions": [')
    dirs = data["directions"]
    for i, d in enumerate(dirs):
        dcomma = "," if i < len(dirs) - 1 else ""
        lines.append("    {")
        lines.append(f'      "id": {json.dumps(d["id"], ensure_ascii=False)},')
        lines.append(f'      "label": {json.dumps(d["label"], ensure_ascii=False)},')
        lines.append('      "stops": [')
        stops = d["stops"]
        for j, s in enumerate(stops):
            sc = "," if j < len(stops) - 1 else ""
            blob = json.dumps(s, ensure_ascii=False, separators=(", ", ": "))
            lines.append(f"        {blob}{sc}")
        lines.append("      ]")
        lines.append("    }" + dcomma)
    lines.append("  ]")
    lines.append("}")
    return "\n".join(lines) + "\n"


LINES = [
    {"url": "https://www.startromagna.it/linee/co_1/", "number": "1", "post_id": 884},
    {"url": "https://www.startromagna.it/linee/co_2/", "number": "2", "post_id": 886},
    {"url": "https://www.startromagna.it/linee/co_3/", "number": "3", "post_id": 888},
]


def main() -> None:
    DATA.mkdir(parents=True, exist_ok=True)
    for spec in LINES:
        url = spec["url"]
        slug = url.rstrip("/").split("/")[-1]
        out_path = DATA / f"linea_{slug}_stops.json"
        print("fetch", url, "->", out_path.name)
        html = fetch(url)
        data = page_to_json(
            url,
            html,
            line_number=spec["number"],
            wordpress_post_id=spec["post_id"],
            orari_menu_url=ORARI_MENU,
        )
        if not data["directions"]:
            print("  WARN: no locations found", file=sys.stderr)
        out_path.write_text(format_linea_stops_json(data), encoding="utf-8")


if __name__ == "__main__":
    main()
