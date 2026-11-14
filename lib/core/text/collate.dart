/// Comparación/ordenación alfabética insensible a acentos y mayúsculas
/// (Àliga/Álvaro ordenan antes que Baliza, no al final).
library;

const _from = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
const _to = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';

String foldAccents(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    final i = _from.indexOf(ch);
    b.write(i >= 0 ? _to[i] : ch);
  }
  return b.toString();
}

int compareFold(String a, String b) =>
    foldAccents(a).toLowerCase().compareTo(foldAccents(b).toLowerCase());
