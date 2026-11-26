/// Imports the logbook CSV exported by the SSI website (MySSI). The header
/// is in the user's language, so columns are read by position:
///   0 no. · 1 place · 2 country · 3 date[/time] · 4 activity · 5 specialty ·
///   6 type · 7 duration · 8 depth · 9 buddies/instructor/centre
/// (see `ssi_csv_fields.dart` for the format of each cell).
/// The time is only there if the diver filled it in on MySSI. Duplicates are
/// detected by day + depth + duration (+ time if present); those
/// without a time are placed at 12:00 (+1 min for each one that already
/// takes that time), in SSI number order.
library;

import 'package:pandive/core/db/divemate_db.dart';
import 'package:pandive/core/import/ssi_csv_fields.dart';

export 'package:pandive/core/import/ssi_csv_fields.dart';

/// An already parsed SSI CSV row.
class SsiDive {
  final int? number;
  final DateTime date; // with time only if [hasTime]
  final bool hasTime;
  final String? site;
  final String? country;
  final double? minutes;
  final double? depth; // metros
  final List<String> buddies;
  final List<String> tags; // specialties, centre, unusual activity/type
  final String? computer;
  const SsiDive({
    required this.date,
    this.hasTime = false,
    this.number,
    this.site,
    this.country,
    this.minutes,
    this.depth,
    this.buddies = const [],
    this.tags = const [],
    this.computer,
  });
}

/// Result of an import: added, already existing and unreadable rows.
typedef SsiImportResult = ({int added, int duplicates, int skipped});

/// Parses the CSV. Returns the readable dives and how many data rows
/// couldn't be read (no valid date). The header is recognised by
/// having no date and is ignored.
({List<SsiDive> dives, int skipped}) parseSsiCsv(String text) {
  final rows = [
    for (final r in parseCsv(text))
      if (parseSsiDate(r.length > 3 ? r[3] : '') != null) r,
  ];
  final all = parseCsv(text).length;
  // Activity (col. 4) and type (col. 6): the value almost all rows carry
  // ("Buceo", "Inmersión de ocio") adds nothing; the rest become tags.
  final usualActivity = _dominant(rows.map((r) => r[4]));
  final usualType = _dominant(rows.map((r) => r.length > 6 ? r[6] : ''));
  final out = <SsiDive>[];
  for (final r in rows) {
    String col(int n) => n < r.length ? r[n] : '';
    final d = parseSsiDate(col(3))!;
    final people = parseSsiPeople(col(9));
    out.add(SsiDive(
      number: int.tryParse(col(0).trim()),
      date: d.date,
      hasTime: d.hasTime,
      site: _clean(col(1)),
      country: _clean(col(2)),
      minutes: parseSsiMinutes(col(7)),
      depth: parseSsiDepth(col(8)),
      buddies: people.people,
      computer: people.computer,
      tags: {
        ...splitSsiList(col(5)),
        for (final x in splitSsiTabs(col(4))) if (x != usualActivity) x,
        for (final x in splitSsiTabs(col(6))) if (x != usualType) x,
        ?people.center,
      }.toList(),
    ));
  }
  // Rows without a valid date, except the header, couldn't be read.
  return (dives: out, skipped: (all - rows.length - 1).clamp(0, all));
}

String? _clean(String s) {
  final v = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return v.isEmpty ? null : v;
}

// Piece (tab-separated) present in more than half of the rows.
String? _dominant(Iterable<String> cells) {
  final count = <String, int>{};
  var n = 0;
  for (final c in cells) {
    n++;
    for (final x in splitSsiTabs(c).toSet()) {
      count[x] = (count[x] ?? 0) + 1;
    }
  }
  for (final e in count.entries) {
    if (e.value * 2 > n) return e.key;
  }
  return null;
}

// Tolerances to consider a CSV row "already existing". Tuned with a
// real logbook: two divers' computers differ by 2-3 m and a few minutes, and
// the MySSI time can be ~1 h off (the computer's time zone).
const _maxDepthDiff = 3.0; // m
const _maxMinutesDiff = 6.0; // min
const _maxTimeDiff = 90; // min (only if the CSV has a time)

typedef _Existing = ({int id, String? time, double? depth, double? minutes});

// Similarity of [d] to [e] (0 = identical), or null if it can't be the same one.
double? _distance(SsiDive d, _Existing e) {
  var score = 0.0;
  if (d.depth != null && e.depth != null) {
    final x = (d.depth! - e.depth!).abs();
    if (x > _maxDepthDiff) return null;
    score += x / _maxDepthDiff;
  }
  if (d.minutes != null && e.minutes != null) {
    final x = (d.minutes! - e.minutes!).abs();
    if (x > _maxMinutesDiff) return null;
    score += x / _maxMinutesDiff;
  }
  final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(e.time ?? '');
  if (d.hasTime && hm != null) {
    final x = (int.parse(hm[1]!) * 60 + int.parse(hm[2]!) -
            (d.date.hour * 60 + d.date.minute))
        .abs();
    if (x > _maxTimeDiff) return null;
    score += x / _maxTimeDiff;
  }
  return score;
}

/// A CSV row in the import plan. [matchId] is the existing dive it pairs
/// with (same day, depth ±3 m, duration ±6 min and, if there is a time,
/// ±90 min; the most similar among several): then it is a [duplicate], not
/// imported unless the user ticks it, or used to fill that dive in.
class SsiPlanEntry {
  final SsiDive dive;
  final int? matchId;
  const SsiPlanEntry(this.dive, {this.matchId});
  bool get duplicate => matchId != null;
}

/// Plan without writing anything: each CSV row (in chronological order) marked
/// as new or already existing, and how many rows couldn't be read.
({List<SsiPlanEntry> entries, int skipped}) planSsiImport(
    DivemateDb db, String text) {
  final parsed = parseSsiCsv(text);
  final dives = [...parsed.dives]..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : (a.number ?? 0).compareTo(b.number ?? 0);
    });
  final used = <int>{}; // existing dives already paired with a row
  final entries = <SsiPlanEntry>[];
  for (final d in dives) {
    _Existing? match;
    double? best;
    for (final e in db.divesOnDay(d.date)) {
      final x = used.contains(e.id) ? null : _distance(d, e);
      if (x != null && (best == null || x < best)) (match, best) = (e, x);
    }
    if (match != null) used.add(match.id);
    entries.add(SsiPlanEntry(d, matchId: match?.id));
  }
  return (entries: entries, skipped: parsed.skipped);
}

/// Imports [dives] in chunks (one transaction each) yielding the thread
/// between chunks: the UI paints progress and Android doesn't show "not responding".
/// Returns how many were added.
Future<int> applySsiImport(DivemateDb db, List<SsiDive> dives,
        {void Function(int done, int total)? onProgress}) async =>
    (await applySsiChanges(db, insert: dives, onProgress: onProgress)).added;

/// Inserts [insert] as new dives and fills the existing dives of [fill]
/// (entries with a [SsiPlanEntry.matchId]) with their CSV data, keeping what
/// they already have (see `fillDiveFromImport`). Chunked like
/// [applySsiImport]. Returns how many were added and how many changed.
Future<({int added, int filled})> applySsiChanges(DivemateDb db,
    {List<SsiDive> insert = const [],
    List<SsiPlanEntry> fill = const [],
    void Function(int done, int total)? onProgress}) async {
  const chunk = 25;
  final total = insert.length + fill.length;
  var added = 0, filled = 0;
  for (var i = 0; i < fill.length; i += chunk) {
    final part = fill.sublist(i, (i + chunk).clamp(0, fill.length));
    filled += db.inTransaction(() => part.where((e) => _fill(db, e)).length);
    onProgress?.call(i + part.length, total);
    await Future<void>.delayed(Duration.zero);
  }
  for (var i = 0; i < insert.length; i += chunk) {
    final part = insert.sublist(i, (i + chunk).clamp(0, insert.length));
    added += db.inTransaction(() => part.where((d) => _insert(db, d)).length);
    onProgress?.call(fill.length + i + part.length, total);
    await Future<void>.delayed(Duration.zero);
  }
  if (added > 0) db.autoRenumber();
  return (added: added, filled: filled);
}

bool _fill(DivemateDb db, SsiPlanEntry e) {
  final d = e.dive;
  return e.matchId != null &&
      db.fillDiveFromImport(e.matchId!,
          placeName: d.site,
          country: d.country,
          maxDepth: d.depth,
          durationMin: d.minutes,
          computer: d.computer,
          buddies: d.buddies,
          tagNames: d.tags);
}

bool _insert(DivemateDb db, SsiDive d) {
  var when = d.date;
  // No time: 12:00, +1 min for each one already taking that minute. With a real
  // time taken it's the same dive and importExternalDive rejects it.
  while (!d.hasTime && db.hasDiveAt(when)) {
    when = when.add(const Duration(minutes: 1));
  }
  return db.importExternalDive(
    dateTime: when,
    placeName: d.site,
    country: d.country,
    maxDepth: d.depth,
    durationMin: d.minutes,
    buddies: d.buddies,
    tagNames: d.tags,
    computer: d.computer,
  );
}

/// Plan + import the new ones, headless (tests and scripts).
Future<SsiImportResult> importSsiCsv(DivemateDb db, String text) async {
  final plan = planSsiImport(db, text);
  final fresh = [for (final e in plan.entries) if (!e.duplicate) e.dive];
  final added = await applySsiImport(db, fresh);
  return (
    added: added,
    duplicates: plan.entries.length - added,
    skipped: plan.skipped,
  );
}
