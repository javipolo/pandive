/// Color y etiqueta para el estado de caducidad de un documento.
library;

import 'package:material_ui/material_ui.dart';

import 'package:pandive/core/models/models.dart';
import 'package:pandive/l10n/app_localizations.dart';

Color docStatusColor(BuildContext context, DocStatus s) {
  switch (s) {
    case DocStatus.expired:
      return Theme.of(context).colorScheme.error;
    case DocStatus.soon:
      return Colors.orange.shade700;
    case DocStatus.valid:
      return Colors.green.shade700;
    case DocStatus.none:
      return Theme.of(context).disabledColor;
  }
}

String docStatusLabel(AppLocalizations t, DocStatus s, DateTime? expiry) {
  switch (s) {
    case DocStatus.expired:
      return t.docExpired;
    case DocStatus.soon:
      return t.docExpiresSoon;
    case DocStatus.valid:
      return t.docValid;
    case DocStatus.none:
      return '';
  }
}
