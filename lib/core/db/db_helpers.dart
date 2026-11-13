part of 'divemate_db.dart';

// Helpers de la librería (accesibles desde todos los parts).

/// Columnas editables desde la UI (allowlist: evita tocar perfiles, IDs,
/// campos de sincronización, etc.).
const _editableColumns = {
  'Comments', 'Rating', 'Buddy', 'Divemaster', 'Divetype', 'Weight',
  'Place', 'Country', 'PlaceID', 'BuddyIDs',
  // Todos los campos escalares editables a mano (el perfil NO se edita).
  'Depth', 'DepthAvg', 'Divetime', 'Watertemp', 'Airtemp', 'Surfint',
  'PresS', 'PresE', 'Divedate', 'Entrytime',
};

Dive _diveFromRow(Row r) {
  return Dive(
    id: r['ID'] as int,
    number: r['Number'] as int?,
    date: _parseDate(r['Divedate'] as String?, r['Entrytime'] as String?),
    place: _str(r['Place']),
    country: _str(r['Country']),
    placeId: r['PlaceID'] as int?,
    durationMin: _num(r['Divetime']),
    maxDepth: _num(r['Depth']),
    avgDepth: _num(r['DepthAvg']),
    waterTemp: _temp(r['Watertemp']),
    airTemp: _temp(r['Airtemp']),
    pressureStart: _num(r['PresS']),
    pressureEnd: _num(r['PresE']),
    weight: _num(r['Weight']),
    rating: r['Rating'] as int?,
    computer: _str(r['Computer']),
    buddy: _str(r['Buddy']),
    diveMaster: _str(r['Divemaster']),
    diveType: _str(r['Divetype']),
    comments: _str(r['Comments']),
    surfaceInterval: _str(r['Surfint']),
    profileInterval: r['ProfileInt'] as int?,
  );
}

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Material de botella <-> entero (Tank.Tanktype): 1=aluminio, 2=acero.
TankMaterial? _materialFromInt(int? v) => switch (v) {
      1 => TankMaterial.aluminium,
      2 => TankMaterial.steel,
      _ => null,
    };

int? _materialToInt(TankMaterial? m) => switch (m) {
      TankMaterial.aluminium => 1,
      TankMaterial.steel => 2,
      null => null,
    };

/// Temperatura, descartando centinelas/implausibles (p.ej. -300 °C).
double? _temp(Object? v) {
  final t = _num(v);
  if (t == null || t <= -50 || t >= 60) return null;
  return t;
}

/// Timestamp en formato DiveMate: YYYY-MM-DDTHH:MM:SS (hora local).
String _nowStamp() {
  final n = DateTime.now();
  String p(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${p(n.month)}-${p(n.day)}T'
      '${p(n.hour)}:${p(n.minute)}:${p(n.second)}';
}

/// UUID v4 (sin dependencia externa).
String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // versión 4
  b[8] = (b[8] & 0x3f) | 0x80; // variante
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Divedate = "YYYY-MM-DD", Entrytime = "HH:MM" (o "HH:MM:SS").
DateTime? _parseDate(String? date, String? time) {
  if (date == null || date.isEmpty) return null;
  final d = DateTime.tryParse(date);
  if (d == null) return null;
  if (time != null && time.isNotEmpty) {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(d.year, d.month, d.day, h, m);
  }
  return d;
}
