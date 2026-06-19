/// Codifica righe prezzo compatte per baseline start_content.
List<Map<String, String?>> pr(List<List<String?>> rows) => [
  for (final r in rows)
    {
      'titolo': r[0]!,
      'prezzo': r[1]!,
      if (r.length > 2 && r[2] != null) 'nota': r[2],
    },
];
