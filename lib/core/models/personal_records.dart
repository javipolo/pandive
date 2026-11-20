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
  const PersonalRecords({this.deepest, this.longest, this.coldest});

  bool get isEmpty => deepest == null && longest == null && coldest == null;
}
