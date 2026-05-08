import 'package:flutter/material.dart';
import '../models/product_info.dart';
import '../services/price_check_service.dart';
import 'scanner_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final PriceCheckService _priceCheckService = PriceCheckService();
  final List<ProductInfo> _dailySpecials = [];
  bool _specialsLoading = true;
  bool _specialsError = false;
  late final AnimationController _tickerController;

  @override
  void initState() {
    super.initState();
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _loadDailySpecials();
  }

  @override
  void dispose() {
    _tickerController.dispose();
    super.dispose();
  }

  Future<void> _loadDailySpecials() async {
    try {
      final specials = await _priceCheckService.fetchDailySpecials();
      setState(() {
        _dailySpecials.clear();
        _dailySpecials.addAll(specials);
        _specialsLoading = false;
        _specialsError = specials.isEmpty;
      });
    } catch (_) {
      setState(() {
        _specialsLoading = false;
        _specialsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final items = _specialsError
        ? [ProductInfo(name: 'İndirimler şu an yüklenemiyor', brand: '', size: '', price: 0)]
        : _specialsLoading
            ? [ProductInfo(name: 'İndirimler yükleniyor...', brand: '', size: '', price: 0)]
            : (_dailySpecials.isEmpty
                ? [ProductInfo(name: 'İndirimler şu an yüklenemiyor', brand: '', size: '', price: 0)]
                : _dailySpecials);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'ETİKET',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Cyber-Zabıta Fiyat Tarayıcı',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScannerScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 240,
                  width: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.12),
                        const Color(0xFF00FFEA).withOpacity(0.14),
                      ],
                      center: Alignment.center,
                      radius: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00FFEA).withOpacity(0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFF00FFEA),
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'TARAMAYA BAŞLA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.cyanAccent.withOpacity(0.8),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 2),
            Container(
              width: size.width,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRect(
                child: AnimatedBuilder(
                  animation: _tickerController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        -size.width * _tickerController.value,
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: Row(
                    children: [
                      ...items.map(
                        (item) {
                          final text = item.price > 0
                              ? '${item.brand}: ${item.name} • ${item.price.toStringAsFixed(2)} TL'
                              : item.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 48),
                            child: Text(
                              text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
