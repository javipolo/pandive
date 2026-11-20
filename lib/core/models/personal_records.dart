/// Récords personales del logbook: el buceo que logró cada marca.
library;

class DiveRecord {
  final int diveId;
  final double value;
  final DateTime? date;
  final String? site;
  const DiveRecord(this.diveId, this.value, this.date, this.site);
}

class PersonalRecords {
  final DiveRecord? deepest; // m
  final DiveRecord? longest; // min
  final DiveRecord? coldest; // °C
  final DiveRecord? longestDeco; // TTS máx (min)
  final DiveRecord? longestCeiling; // más tiempo con techo (min)
  const PersonalRecords({
    this.deepest,
    this.longest,
    this.coldest,
    this.longestDeco,
    this.longestCeiling,
  });

  bool get isEmpty =>
      deepest == null &&
      longest == null &&
      coldest == null &&
      longestDeco == null &&
      longestCeiling == null;
}
