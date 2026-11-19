/// Documento del buzo (certificación, seguro, etc.): una imagen en disco más
/// metadatos (título, notas, caducidad). Fila de `PandiveDocument`.
library;

enum DocStatus { none, valid, soon, expired }

class DiveDoc {
  final int id;
  final String title;
  final String? notes;
  final bool expires;
  final DateTime? expiryDate; // solo fecha (sin hora)
  final String fileName; // relativo dentro de la carpeta documents/
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

  /// Estado respecto a [now]: vigente / próximo (≤30 días) / caducado.
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
