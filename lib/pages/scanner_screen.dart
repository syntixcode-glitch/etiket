import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product_info.dart';
import '../services/camera_service.dart';
import '../services/database_helper.dart';
import '../services/price_check_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final CameraService _cameraService = CameraService();
  final PriceCheckService _priceCheckService = PriceCheckService();
  ProductInfo? _product;
  PriceCheckResult? _priceResult;
  String _statusMessage = 'Kamerayı ürün etiketine doğrulayın.';
  bool _isBusy = false;
  String _complaintText = '';

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _statusMessage = 'Tarama başlatıldı. Lütfen bekleyin...';
    });

    try {
      await _cameraService.initialize();
      final product = await _cameraService.scanPriceTag();

      if (product == null) {
        setState(() {
          _statusMessage = 'Ürün ya da fiyat algılanamadı. Lütfen net bir etiket yönlendirin.';
          _isBusy = false;
        });
        return;
      }

      final result = await _priceCheckService.checkMarketPrices(product);
      await DatabaseHelper.instance.insertScan(product);

      setState(() {
        _product = product;
        _priceResult = result;
        _statusMessage = result.overpriced
            ? 'Fahiş fiyat tespit edildi. Karşılaştırma tamamlandı.'
            : 'Fiyat karşılaştırması tamamlandı. Ürün normaller içinde.';
        _complaintText = _priceCheckService.generateComplaintReport(product, result);
        _isBusy = false;
      });
    } catch (error) {
      setState(() {
        _statusMessage = 'Tarama sırasında bir hata oluştu: ${error.toString()}';
        _isBusy = false;
      });
    }
  }

  Future<void> _copyComplaint() async {
    if (_complaintText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _complaintText));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikayet metni panoya kopyalandı.')), 
      );
    }
  }

  Future<void> _openRoute() async {
    if (_product == null || _priceResult == null) return;
    await _priceCheckService.openCheapestMarketOnMap(
      _priceResult!.cheapestMarketName,
      _product!.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _priceResult?.overpriced == true ? Colors.red.shade900 : Colors.black;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('ETİKET TARAMA'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusMessage,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              if (_product != null) ...[
                Text(
                  _product!.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_product!.brand} • ${_product!.size} • ${_product!.price.toStringAsFixed(2)} TL',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_priceResult != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Piyasa ortalaması: ${_priceResult!.averagePrice.toStringAsFixed(2)} TL',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'En ucuz market: ${_priceResult!.cheapestMarketName} ${_priceResult!.cheapestPrice.toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                  color: Colors.lightGreenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_priceResult!.overpriced) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'FAHİŞ FİYAT: DİĞER MARKETLERDE ${_priceResult!.overpricedDifference.toStringAsFixed(2)} TL DAHA UCUZ!',
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton(
                              onPressed: _openRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                              child: const Text('EN UCUZ BURADA'),
                            ),
                            ElevatedButton(
                              onPressed: _copyComplaint,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple.shade700,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              ),
                              child: const Text('KOPYALA VE ŞİKAYET ET'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isBusy ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  child: _isBusy
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('HIZLI TARAYIŞI BAŞLAT'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
