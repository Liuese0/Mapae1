import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  AppConstants._();

  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // OCR.space API
  static String get ocrApiKey => dotenv.env['OCR_API_KEY'] ?? '';
  static const String ocrApiUrl = 'https://api.ocr.space/parse/image';

  // App
  static const String appName = 'NameCard';
  static const int maxMyCards = 10;
  static const int maxCategories = 50;

  // NFC
  static const String nfcMimeType = 'application/com.namecard.card';

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);

  // Card dimensions ratio (standard business card)
  static const double cardAspectRatio = 9.0 / 5.0;
}