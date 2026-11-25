/// Accent- and case-insensitive alphabetical comparison/sorting
/// (Àliga/Álvaro sort before Baliza, not at the end).
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

/// Does [haystack] contain [needle] ignoring accents and case?
/// ("tomas" finds "Tomás"). [needle] is assumed already trimmed by the caller.
bool foldContains(String haystack, String needle) =>
    foldAccents(haystack).toLowerCase().contains(foldAccents(needle).toLowerCase());
