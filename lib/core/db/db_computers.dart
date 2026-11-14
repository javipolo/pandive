part of 'divemate_db.dart';

/// Ordenadores de buceo guardados (para reconectar por MAC sin reescanear).
extension DivemateDbComputers on DivemateDb {
  List<DiveComputerRef> listComputers() {
    final rows =
        _db.select('SELECT Address, Name, Vendor, Product FROM PandiveComputer');
    return rows
        .map((r) => DiveComputerRef(
              address: _str(r['Address']) ?? '',
              name: _str(r['Name']) ?? '',
              vendor: _str(r['Vendor']),
              product: _str(r['Product']),
            ))
        .toList()
      ..sort((a, b) => compareFold(a.name, b.name));
  }

  bool isComputerSaved(String address) => _db
      .select('SELECT 1 FROM PandiveComputer WHERE Address=? LIMIT 1', [address])
      .isNotEmpty;

  void addComputer(String address, String name, {String? vendor, String? product}) {
    _db.execute(
      'INSERT OR REPLACE INTO PandiveComputer (Address, Name, Vendor, Product, '
      'Updated) VALUES (?,?,?,?,?)',
      [address, name, vendor, product, _nowStamp()],
    );
  }

  void removeComputer(String address) =>
      _db.execute('DELETE FROM PandiveComputer WHERE Address=?', [address]);
}
