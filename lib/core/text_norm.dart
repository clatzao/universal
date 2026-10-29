const _map = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'ª': 'a',
  'Á': 'a', 'À': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'É': 'e', 'È': 'e', 'Ê': 'e', 'Ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'Í': 'i', 'Ì': 'i', 'Î': 'i', 'Ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'º': 'o',
  'Ó': 'o', 'Ò': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'Ú': 'u', 'Ù': 'u', 'Û': 'u', 'Ü': 'u',
  'ç': 'c', 'Ç': 'c', 'ñ': 'n', 'Ñ': 'n',
};

/// Minúsculas sem acentos, com o MESMO tamanho (em unidades UTF-16) da
/// entrada, para que índices de casamento valham também no texto original.
String normalizeKeepLength(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    final mapped = _map[ch];
    if (mapped != null) {
      b.write(mapped);
      continue;
    }
    final lower = ch.toLowerCase();
    b.write(lower.length == 1 ? lower : ch);
  }
  return b.toString();
}
