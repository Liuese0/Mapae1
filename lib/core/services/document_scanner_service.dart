import 'dart:io';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScannerService {
  DocumentScanner? _scanner;

  DocumentScanner _getScanner({bool galleryImport = true}) {
    _scanner?.close();
    _scanner = DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: galleryImport,
      ),
    );
    return _scanner!;
  }

  /// Opens the ML Kit Document Scanner UI and returns the scanned image file.
  /// Returns null if the user cancels.
  Future<File?> scanDocument({bool galleryImport = true}) async {
    try {
      final scanner = _getScanner(galleryImport: galleryImport);
      final result = await scanner.scanDocument();
      final images = result.images;
      if (images.isNotEmpty) {
        return File(images.first);
      }
      return null;
    } catch (e) {
      // User cancelled or scanner failed
      return null;
    }
  }

  void dispose() {
    _scanner?.close();
    _scanner = null;
  }
}