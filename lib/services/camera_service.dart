import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import '../models/product_info.dart';

class CameraService {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = GoogleMlKit.vision.textRecognizer();

  bool get isInitialized => _cameraController?.value.isInitialized == true;

  Future<void> initialize() async {
    if (isInitialized) {
      return;
    }

    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
  }

  Future<ProductInfo?> scanPriceTag() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    final picture = await _cameraController!.takePicture();
    final inputImage = InputImage.fromFilePath(picture.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;
    return _parseProductInfo(rawText);
  }

  ProductInfo? _parseProductInfo(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return null;
    }

    final price = _extractPrice(rawText);
    if (price == null) {
      return null;
    }

    final name = _extractProductName(lines);
    final brand = _extractBrand(rawText);
    final size = _extractSize(rawText);

    return ProductInfo(
      name: name,
      brand: brand,
      size: size,
      price: price,
    );
  }

  String _extractProductName(List<String> lines) {
    final candidate = lines.firstWhere(
      (line) => line.toLowerCase().contains('süt') || line.toLowerCase().contains('ekmek') || line.toLowerCase().contains('peynir') || line.toLowerCase().contains('çay') || line.toLowerCase().contains('su'),
      orElse: () => lines.first,
    );
    return candidate;
  }

  String _extractBrand(String rawText) {
    final brandPatterns = ['Sütaş', 'Pınar', 'Torku', 'Eti', 'Onur', 'İçecek', 'Finish', 'Ülker'];
    for (final pattern in brandPatterns) {
      if (rawText.toLowerCase().contains(pattern.toLowerCase())) {
        return pattern;
      }
    }
    final words = rawText.split(RegExp(r'\s+'));
    return words.isNotEmpty ? words.first : 'Bilinmiyor';
  }

  String _extractSize(String rawText) {
    final sizeRegex = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?\s?(?:ml|gr|g|kg|l|lt|L|KG|ML|GR))', caseSensitive: false);
    final match = sizeRegex.firstMatch(rawText);
    if (match != null) {
      return match.group(0)!.toUpperCase();
    }
    return 'Bilinmeyen boyut';
  }

  double? _extractPrice(String text) {
    final priceRegex = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)\s*(?:TL|₺)', caseSensitive: false);
    final match = priceRegex.firstMatch(text);
    if (match == null) {
      return null;
    }
    final raw = match.group(1)!.replaceAll(',', '.');
    return double.tryParse(raw);
  }

  Future<void> dispose() async {
    await _cameraController?.dispose();
    await _textRecognizer.close();
  }
}
