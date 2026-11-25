/// Saved dive computer (to reconnect without rescanning, by MAC).
library;

class DiveComputerRef {
  final String address; // MAC BLE
  final String name; // nombre anunciado
  final String? vendor;
  final String? product;

  const DiveComputerRef({
    required this.address,
    required this.name,
    this.vendor,
    this.product,
  });
}
