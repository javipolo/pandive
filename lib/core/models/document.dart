/// Diver document (certification, insurance, etc.): an image on disk plus
/// metadata (title, notes, expiry). Row of `PandiveDocument`.
library;

enum DocStatus { none, valid, soon, expired }

class DiveDoc {
  final int id;
  final String title;
  final String? notes;
  final bool expires;
  final DateTime? expiryDate; // date only (no time)
  final String fileName; // relative inside the documents/ folder
  final DateTime? created;
  final DateTime? updated;

  const DiveDoc({
    required this.id,
    required this.title,
    this.notes,
    this.expires = false,
    this.expiryDate,
    required this.fileName,
    this.created,
    this.updated,
  });

  /// Status relative to [now]: valid / due soon (≤30 days) / expired.
  DocStatus status(DateTime now) {
    if (!expires || expiryDate == null) return DocStatus.none;
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final days = exp.difference(today).inDays;
    if (days < 0) return DocStatus.expired;
    if (days <= 30) return DocStatus.soon;
    return DocStatus.valid;
  }
}
