part of 'divemate_db.dart';

/// Esquema DiveMate para crear una base de datos vacía nueva (compatible con
/// divemate-cli). Replica las tablas del formato .ddb original.
const _schemaSql = <String>[
  'CREATE TABLE Logbook (ID INTEGER PRIMARY KEY, Number INTEGER, Divedate TEXT, '
      'Entrytime TEXT, Country TEXT, Place TEXT, PlaceID INTEGER, Divetime REAL, '
      'Surfint TEXT, Comments TEXT, Depth REAL, PresS REAL, PresE REAL, Weight REAL, '
      'Airtemp REAL, Watertemp REAL, O2 REAL, MaxPPO2 REAL, ProfileInt INTEGER, '
      'Profile TEXT, Rating INTEGER, Computer TEXT, Water INTEGER, VisHor TEXT, '
      'UWCurrent TEXT, Entry INTEGER, Divesuit TEXT, Deco INTEGER, Buddy TEXT, '
      'BuddyIDs TEXT, UUID TEXT, Updated TEXT, DiverID INTEGER, Profile2 TEXT, '
      'UTCoffset INTEGER, Tanksize REAL, DepthAvg REAL, Waves TEXT, Tanktype INTEGER, '
      'Boat TEXT, Weather TEXT, Status INTEGER, diviacStatus INTEGER, Divetype TEXT, '
      'PresW REAL, DiveNumInSession INTEGER, Divemaster TEXT, UsedEquip TEXT, '
      'DiversIDs TEXT, prefPicID INTEGER, Profile3 TEXT, ShopID INTEGER, '
      'Profile10 TEXT, AvgHR INTEGER, MaxHR INTEGER, MinHR INTEGER, '
      'MinSkinTemp INTEGER, MaxSkinTemp INTEGER, EquipWeight REAL, TypeOfDive INTEGER, '
      'tpDescent BLOB, tpAscent BLOB, Profile4 TEXT)',
  'CREATE TABLE Place (ID INTEGER PRIMARY KEY, Country TEXT, Place TEXT, Lat TEXT, '
      'Lon TEXT, MapPath TEXT, UUID TEXT, Updated TEXT, tp BLOB, Type INTEGER, '
      'Rating INTEGER, Water INTEGER, MaxDepth REAL, Comments TEXT, Altitude TEXT, '
      'WaterName TEXT, Region TEXT, Difficulty TEXT, prefPicID INTEGER)',
  'CREATE TABLE Tank (ID INTEGER PRIMARY KEY, LogID INTEGER, TankID INTEGER, '
      'SortOrd INTEGER, Tanktype INTEGER, Tanksize REAL, PresS REAL, PresE REAL, '
      'PresW REAL, O2 REAL, He REAL, SupplyType INTEGER, UUID TEXT, Updated TEXT, '
      'Weight REAL, Name TEXT, DivePhase INTEGER, BreathingTime INTEGER)',
  'CREATE TABLE Buddy (ID INTEGER PRIMARY KEY, FirstName TEXT, LastName TEXT, '
      'Street TEXT, Zip TEXT, City TEXT, Country TEXT, State TEXT, Phone TEXT, '
      'Mobile TEXT, Email TEXT, URL TEXT, Birthdate TEXT, Comments TEXT, '
      'PhotoPath TEXT, UUID TEXT, Updated TEXT, tpMap BLOB)',
  'CREATE TABLE Divetype (ID INTEGER PRIMARY KEY, Typename TEXT, SortOrd INTEGER, '
      'UUID TEXT, Updated TEXT)',
  'CREATE TABLE Personal (ID INTEGER PRIMARY KEY, FirstName TEXT, LastName TEXT, '
      'Street TEXT, Zip TEXT, City TEXT, Country TEXT, Phone TEXT, Mobile TEXT, '
      'Email TEXT, URL TEXT, Birthdate TEXT, Bloodgroup TEXT, Comments TEXT, '
      'EmergContact TEXT, PhotoPath TEXT, UUID TEXT, Updated TEXT, '
      'importedFromFile TEXT, USBComputer TEXT, DCSerialNo TEXT, BrevetID TEXT, '
      'EmergContactNumber TEXT, EmergMessage TEXT, tpMap BLOB, diviacToken TEXT, '
      'Type INTEGER, State TEXT, syncCfg INTEGER, EmergEmail TEXT, DiveInsurance TEXT)',
  'CREATE TABLE Equipment (ID INTEGER PRIMARY KEY, Object TEXT, Manufacturer TEXT, '
      'Serial TEXT, DateP TEXT, DateR TEXT, Warranty TEXT, Shop TEXT, Price REAL, '
      'PhotoPath TEXT, Photo BLOB, Comments TEXT, DateRN TEXT, Inactive INTEGER, '
      'Weight REAL, UUID TEXT, Updated TEXT, DiverID INTEGER, Category TEXT, '
      'Name TEXT, Info TEXT, prefPicID INTEGER, TypeID INTEGER, Val1 REAL, '
      'Val2 REAL, Val3 INTEGER, RevInt INTEGER)',
  'CREATE TABLE Brevets (ID INTEGER PRIMARY KEY, Brevet TEXT, Org TEXT, '
      'CertDate TEXT, Number TEXT, Instructor TEXT, InstructorNo TEXT, '
      'Scan1Path TEXT, Scan1 BLOB, Scan2Path TEXT, Scan2 BLOB, UUID TEXT, '
      'Updated TEXT, DiverID INTEGER, SortOrd INTEGER)',
  'CREATE TABLE Shop (ID INTEGER PRIMARY KEY, ShopName TEXT, UUID TEXT, Updated TEXT)',
  'CREATE TABLE Pictures (ID INTEGER PRIMARY KEY, LogID INTEGER, Path TEXT, '
      'Description TEXT, Graphic BLOB, UUID TEXT, Updated TEXT, DiverID INTEGER, '
      'PlaceID INTEGER, BuddyID INTEGER, EquipmentID INTEGER, SortOrd INTEGER)',
  'CREATE TABLE DBInfo (PrgName TEXT, DBVersion TEXT, UUID TEXT, Updated TEXT)',
];

/// Crea el esquema y una fila de buceador (owner) con ID 1.
void _createSchema(Database db) {
  for (final sql in _schemaSql) {
    db.execute(sql);
  }
  final now = _nowStamp();
  db.execute(
    'INSERT INTO Personal (ID, FirstName, UUID, Updated) VALUES (1, ?, ?, ?)',
    ['Buceador', _uuid(), now],
  );
  db.execute(
    'INSERT INTO DBInfo (PrgName, DBVersion, UUID, Updated) VALUES (?, ?, ?, ?)',
    ['Pandive', '1', _uuid(), now],
  );
}
