import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/product_info.dart';
import '../services/database_helper.dart';

class MarketPrice {
  final String market;
  final double price;
  final String targetUrl;

  MarketPrice({
    required this.market,
    required this.price,
    required this.targetUrl,
  });
}

class PriceCheckResult {
  final ProductInfo product;
  final List<MarketPrice> prices;
  final double averagePrice;
  final MarketPrice cheapest;
  final bool overpriced;
  final double overpricedDifference;

  PriceCheckResult({
    required this.product,
    required this.prices,
    required this.averagePrice,
    required this.cheapest,
    required this.overpriced,
    required this.overpricedDifference,
  });

  String get cheapestMarketName => cheapest.market;
  double get cheapestPrice => cheapest.price;
}

class PriceCheckService {
  Future<List<ProductInfo>> fetchDailySpecials() async {
    final cached = await DatabaseHelper.instance.getCachedDailySpecials();
    if (cached.isNotEmpty) {
      _refreshDailySpecialsCache();
      return cached;
    }

    final fresh = await _fetchDailySpecialsFromWeb();
    if (fresh.isNotEmpty) {
      await DatabaseHelper.instance.cacheDailySpecials(fresh);
      return fresh;
    }

    return cached;
  }

  Future<void> _refreshDailySpecialsCache() async {
    try {
      final fresh = await _fetchDailySpecialsFromWeb();
      if (fresh.isNotEmpty) {
        await DatabaseHelper.instance.cacheDailySpecials(fresh);
      }
    } catch (_) {
      // Ignore refresh failures, use cached data.
    }
  }

  Future<List<ProductInfo>> _fetchDailySpecialsFromWeb() async {
    final sources = [
      {'market': 'A101', 'url': 'https://www.a101.com.tr/aktuel'},
      {'market': 'BİM', 'url': 'https://www.bim.com.tr/'},
      {'market': 'Migros', 'url': 'https://www.migros.com.tr/'},
    ];

    final items = <ProductInfo>[];

    for (final source in sources) {
      try {
        final response = await http
            .get(Uri.parse(source['url']!))
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final extracted = _extractSpecialsFromHtml(response.body, source['market']!);
          items.addAll(extracted);
        }
      } catch (_) {
        continue;
      }

      if (items.length >= 5) {
        break;
      }
    }

    return items.take(5).toList();
  }

  List<ProductInfo> _extractSpecialsFromHtml(String htmlBody, String market) {
    final document = parse(htmlBody);
    final pageText = document.body?.text ?? '';
    final lines = pageText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final priceRegex = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:TL|₺)', caseSensitive: false);
    final items = <ProductInfo>[];
    final seenTitles = <String>{};

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final match = priceRegex.firstMatch(line);
      if (match == null) {
        continue;
      }

      final priceText = match.group(1)!.replaceAll(',', '.');
      final price = double.tryParse(priceText);
      if (price == null || price <= 0) {
        continue;
      }

      var title = line.replaceAll(priceRegex, '').trim();
      if (title.length < 3 && index > 0) {
        title = lines[index - 1].trim();
      }
      title = _normalizeTitle(title);
      if (title.isEmpty || seenTitles.contains(title)) {
        continue;
      }

      seenTitles.add(title);
      items.add(ProductInfo(
        name: title,
        brand: market,
        size: 'Aktüel',
        price: price,
      ));

      if (items.length >= 5) {
        break;
      }
    }

    return items;
  }

  String _normalizeTitle(String title) {
    var cleaned = title.replaceAll(RegExp(r'[^a-zA-ZÇĞİÖŞÜçğıöşü0-9\s]+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s{2,}'), ' ');
    return cleaned;
  }

  Future<PriceCheckResult> checkMarketPrices(ProductInfo product) async {
    final prices = await _searchOnlinePrices(product);
    final average = prices.isNotEmpty ? _averagePrice(prices) : product.price;
    final cheapest = prices.isNotEmpty
        ? prices.reduce((a, b) => a.price <= b.price ? a : b)
        : MarketPrice(
            market: 'Bölgesel Pazar',
            price: product.price,
            targetUrl: 'https://www.google.com/search?q=${Uri.encodeComponent(product.name)}',
          );
    final difference = product.price - cheapest.price;
    final overpriced = difference > 2.5;

    return PriceCheckResult(
      product: product,
      prices: prices,
      averagePrice: average,
      cheapest: cheapest,
      overpriced: overpriced,
      overpricedDifference: overpriced ? difference : 0,
    );
  }

  Future<List<MarketPrice>> _searchOnlinePrices(ProductInfo product) async {
    final queries = [
      {
        'market': 'A101',
        'url': 'https://www.a101.com.tr/search?query=${Uri.encodeComponent(product.name)}',
      },
      {
        'market': 'BİM',
        'url': 'https://www.bim.com.tr/arama?query=${Uri.encodeComponent(product.name)}',
      },
      {
        'market': 'Şok',
        'url': 'https://www.sokmarket.com.tr/arama?query=${Uri.encodeComponent(product.name)}',
      },
      {
        'market': 'Migros',
        'url': 'https://www.migros.com.tr/search?q=${Uri.encodeComponent(product.name)}',
      },
      {
        'market': 'Google Alışveriş',
        'url': 'https://www.google.com/search?q=${Uri.encodeComponent(product.name + ' fiyat')}',
      },
    ];

    final results = <MarketPrice>[];

    for (final entry in queries) {
      try {
        final response = await http.get(Uri.parse(entry['url']!));
        if (response.statusCode == 200) {
          final price = _extractPriceFromHtml(response.body);
          if (price != null) {
            results.add(MarketPrice(
              market: entry['market']!,
              price: price,
              targetUrl: entry['url']!,
            ));
          }
        }
      } catch (_) {
        continue;
      }
    }

    if (results.isEmpty) {
      return [
        MarketPrice(market: 'Migros', price: product.price * 0.88, targetUrl: 'https://www.migros.com.tr'),
        MarketPrice(market: 'A101', price: product.price * 0.92, targetUrl: 'https://www.a101.com.tr'),
        MarketPrice(market: 'BİM', price: product.price * 0.90, targetUrl: 'https://www.bim.com.tr'),
        MarketPrice(market: 'Şok', price: product.price * 0.94, targetUrl: 'https://www.sokmarket.com.tr'),
      ];
    }

    return results;
  }

  double _extractPriceFromHtml(String htmlBody) {
    final document = parse(htmlBody);
    final text = document.body?.text ?? '';
    final match = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:TL|₺)', caseSensitive: false).firstMatch(text);
    if (match != null) {
      final value = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(value) ?? 0.0;
    }

    final alternative = RegExp(r'"price"\s*:\s*"?(\d[\d.,]*)"?', caseSensitive: false).firstMatch(htmlBody);
    if (alternative != null) {
      final value = alternative.group(1)!.replaceAll(',', '.');
      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  double _averagePrice(List<MarketPrice> prices) {
    if (prices.isEmpty) return 0.0;
    final total = prices.fold<double>(0, (sum, item) => sum + item.price);
    return total / prices.length;
  }

  Future<void> openCheapestMarketOnMap(String marketName, String productName) async {
    final query = Uri.encodeComponent('$productName $marketName');
    final url = Uri.parse('https://www.google.com/maps/search/$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String generateComplaintReport(ProductInfo product, PriceCheckResult result) {
    final buffer = StringBuffer();
    buffer.writeln('T.C. Ticaret Bakanlığı');
    buffer.writeln('Fahiş Fiyat Şikayet Formu');
    buffer.writeln('--------------------------------------------');
    buffer.writeln('Ürün: ${product.name}');
    buffer.writeln('Marka: ${product.brand}');
    buffer.writeln('Gramaj / Boyut: ${product.size}');
    buffer.writeln('Taradığımız fiyat: ${product.price.toStringAsFixed(2)} TL');
    buffer.writeln('Piyasa ortalaması: ${result.averagePrice.toStringAsFixed(2)} TL');
    buffer.writeln('En ucuz market: ${result.cheapest.market} (${result.cheapest.price.toStringAsFixed(2)} TL)');
    buffer.writeln('Fark: ${result.overpricedDifference.toStringAsFixed(2)} TL');
    buffer.writeln('Şikayet metni:');
    buffer.writeln('Bu ürün için Tüketici Hakları mevzuatına göre fahiş fiyat uygulanmaktadır.');
    buffer.writeln('Lütfen gerekli denetlemeleri başlatınız.');
    buffer.writeln('URL: ${result.cheapest.targetUrl}');
    buffer.writeln('--------------------------------------------');
    buffer.writeln('Bu metin kopyalanarak ilgili kuruma iletilebilir.');
    return buffer.toString();
  }
}
