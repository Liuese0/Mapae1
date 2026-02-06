class AppConstants {
  AppConstants._();

  // Supabase
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // OCR.space API
  static const String ocrApiKey = 'YOUR_OCR_SPACE_API_KEY';
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
