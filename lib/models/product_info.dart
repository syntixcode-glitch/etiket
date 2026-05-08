class ProductInfo {
  final String name;
  final String brand;
  final String size;
  final double price;

  ProductInfo({
    required this.name,
    required this.brand,
    required this.size,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'brand': brand,
      'size': size,
      'price': price,
    };
  }
}
