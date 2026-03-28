import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:path_provider/path_provider.dart';

/// Service for advanced business card image processing using OpenCV native:
/// - Perspective correction (flatten warped/tilted cards)
/// - Contour-based auto edge detection
/// - Shadow removal & illumination normalization
/// - CLAHE adaptive contrast
/// - Color & light normalization
/// - OCR-optimized preprocessing
class ImageProcessingService {
  // ──────────────────────────────────────────────
  // Public API
  // ──────────────────────────────────────────────

  /// Detect card edges automatically from image bytes or img.Image.
  /// Returns 4 corner points [topLeft, topRight, bottomRight, bottomLeft]
  /// in image pixel coordinates, or null if detection fails.
  /// Accepts either Uint8List (JPEG/PNG bytes) or img.Image.
  List<math.Point<double>>? detectCardEdges(dynamic image) {
    try {
      Uint8List bytes;
      if (image is Uint8List) {
        bytes = image;
      } else if (image is img.Image) {
        bytes = Uint8List.fromList(img.encodeJpg(image, quality: 85));
      } else {
        return null;
      }
      return _detectCardEdgesImpl(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Apply perspective correction using 4 source corner points.
  /// [srcCorners] are the 4 corners of the detected card in the original image
  /// in order: topLeft, topRight, bottomRight, bottomLeft.
  /// Returns a new file with the perspective-corrected image.
  Future<File> perspectiveCorrect(
      File imageFile,
      List<math.Point<double>> srcCorners, {
        int? outputWidth,
        int? outputHeight,
      }) async {
    final bytes = await imageFile.readAsBytes();
    final resultBytes = _perspectiveCorrectImpl(
      bytes,
      srcCorners,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    );
    return _writeTempFile(resultBytes, 'perspective');
  }

  /// Pro-level enhancement pipeline for saved card images (vFlat Scan quality).
  /// Stages: shadow removal → white balance → CLAHE → sharpening → background cleanup.
  Future<File> enhanceCardImagePro(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final resultBytes = _enhanceCardImageProImpl(bytes);
    return _writeTempFile(resultBytes, 'enhanced_pro');
  }

  /// Standard enhancement (lighter than Pro). Used by CardCropScreen.
  /// Stages: white balance → CLAHE → light sharpening.
  Future<File> enhanceCardImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final resultBytes = _enhanceCardImageImpl(bytes);
    return _writeTempFile(resultBytes, 'enhanced');
  }

  /// Lightweight preprocessing for OCR: contrast stretching + resize.
  Future<File> preprocessForOcr(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final resultBytes = _preprocessForOcrImpl(bytes);
    return _writeTempFile(resultBytes, 'ocr_preprocessed');
  }

  /// Detect edges from camera frame bytes (YUV420 or raw).
  /// Used for real-time camera preview overlay.
  /// Returns corners in the frame's coordinate space, or null.
  List<math.Point<double>>? detectCardEdgesFromFrame(
      Uint8List yPlane,
      int width,
      int height,
      ) {
    return _detectEdgesFromYPlane(yPlane, width, height);
  }

  // ──────────────────────────────────────────────
  // Static implementations (isolate-safe)
  // ──────────────────────────────────────────────

  /// Edge detection using Canny + findContours + approxPolyDP.
  static List<math.Point<double>>? _detectCardEdgesImpl(Uint8List imageBytes) {
    final mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (mat.isEmpty) return null;

    try {
      final result = _detectEdgesFromMat(mat);
      return result;
    } finally {
      mat.dispose();
    }
  }

  /// Core edge detection logic on a cv.Mat.
  static List<math.Point<double>>? _detectEdgesFromMat(cv.Mat mat) {
    // Downscale for faster processing
    final scale = math.min(1.0, 500.0 / math.max(mat.cols, mat.rows));
    cv.Mat working;
    if (scale < 1.0) {
      working = cv.resize(mat, (
      (mat.cols * scale).round(),
      (mat.rows * scale).round(),
      ));
    } else {
      working = mat.clone();
    }

    late cv.Mat gray;
    late cv.Mat blurred;
    late cv.Mat edges;

    try {
      // Grayscale → Blur → Canny
      gray = cv.cvtColor(working, cv.COLOR_BGR2GRAY);
      blurred = cv.gaussianBlur(gray, (5, 5), 1.0);
      edges = cv.canny(blurred, 50, 150);

      // Dilate to close gaps in edges
      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      final dilated = cv.dilate(edges, kernel);
      kernel.dispose();
      edges.dispose();
      edges = dilated;

      // Find contours
      final (contours, hierarchy) =
      cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

      // Find largest quadrilateral contour
      List<math.Point<double>>? bestCorners;
      double maxArea = working.cols * working.rows * 0.15; // Minimum 15% of image

      for (int i = 0; i < contours.length; i++) {
        final area = cv.contourArea(contours[i]);
        if (area < maxArea) continue;

        final peri = cv.arcLength(contours[i], true);
        final approx = cv.approxPolyDP(contours[i], 0.02 * peri, true);

        if (approx.length == 4) {
          // Validate aspect ratio (card is roughly 1.4:1 to 2.2:1)
          final corners = _vecPointToList(approx);
          final sorted = _orderCorners(corners);
          if (sorted != null) {
            final w = _distance(sorted[0], sorted[1]);
            final h = _distance(sorted[0], sorted[3]);
            final aspect = w > h ? w / h : h / w;
            if (aspect >= 1.3 && aspect <= 2.5) {
              maxArea = area;
              bestCorners = sorted;
            }
          }
        }
        approx.dispose();
      }

      contours.dispose();
      hierarchy.dispose();

      if (bestCorners == null) return null;

      // Scale corners back to original image coordinates
      final invScale = 1.0 / scale;
      return bestCorners
          .map((p) => math.Point<double>(p.x * invScale, p.y * invScale))
          .toList();
    } finally {
      working.dispose();
      gray.dispose();
      blurred.dispose();
      edges.dispose();
    }
  }

  /// Detect edges from Y plane (camera frame) for real-time preview.
  static List<math.Point<double>>? _detectEdgesFromYPlane(
      Uint8List yPlane,
      int width,
      int height,
      ) {
    // Create grayscale Mat from Y plane
    final mat = cv.Mat.create(rows: height, cols: width, type: cv.MatType.CV_8UC1);
    mat.data.setAll(0, yPlane);

    try {
      // Downscale to ~300px for speed
      final scale = math.min(1.0, 300.0 / math.max(width, height));
      final small = scale < 1.0
          ? cv.resize(mat, (
      (width * scale).round(),
      (height * scale).round(),
      ))
          : mat.clone();

      final blurred = cv.gaussianBlur(small, (5, 5), 1.0);
      final edges = cv.canny(blurred, 50, 150);

      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
      final dilated = cv.dilate(edges, kernel);

      final (contours, hierarchy) =
      cv.findContours(dilated, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

      List<math.Point<double>>? bestCorners;
      double maxArea = small.cols * small.rows * 0.15;

      for (int i = 0; i < contours.length; i++) {
        final area = cv.contourArea(contours[i]);
        if (area < maxArea) continue;

        final peri = cv.arcLength(contours[i], true);
        final approx = cv.approxPolyDP(contours[i], 0.02 * peri, true);

        if (approx.length == 4) {
          final corners = _vecPointToList(approx);
          final sorted = _orderCorners(corners);
          if (sorted != null) {
            maxArea = area;
            bestCorners = sorted;
          }
        }
        approx.dispose();
      }

      contours.dispose();
      hierarchy.dispose();
      small.dispose();
      blurred.dispose();
      edges.dispose();
      kernel.dispose();
      dilated.dispose();

      if (bestCorners == null) return null;

      // Scale back to original frame coordinates
      final invScale = 1.0 / scale;
      return bestCorners
          .map((p) => math.Point<double>(p.x * invScale, p.y * invScale))
          .toList();
    } finally {
      mat.dispose();
    }
  }

  /// Perspective correction implementation.
  static Uint8List _perspectiveCorrectImpl(
      Uint8List imageBytes,
      List<math.Point<double>> srcCorners, {
        int? outputWidth,
        int? outputHeight,
      }) {
    final mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (mat.isEmpty) throw Exception('이미지를 디코딩할 수 없습니다');

    try {
      // Calculate output dimensions from card corners if not specified
      final topEdge = _distance(srcCorners[0], srcCorners[1]);
      final bottomEdge = _distance(srcCorners[3], srcCorners[2]);
      final leftEdge = _distance(srcCorners[0], srcCorners[3]);
      final rightEdge = _distance(srcCorners[1], srcCorners[2]);

      final outW = outputWidth ?? math.max(topEdge, bottomEdge).round();
      final outH = outputHeight ?? math.max(leftEdge, rightEdge).round();

      // Source points (getPerspectiveTransform requires VecPoint)
      final srcPts = srcCorners
          .map((p) => cv.Point(p.x.round(), p.y.round()))
          .toList();

      // Destination points (flat rectangle)
      final dstPts = [
        cv.Point(0, 0),
        cv.Point(outW, 0),
        cv.Point(outW, outH),
        cv.Point(0, outH),
      ];

      final srcMat = cv.VecPoint.fromList(srcPts);
      final dstMat = cv.VecPoint.fromList(dstPts);

      final M = cv.getPerspectiveTransform(srcMat, dstMat);
      final warped = cv.warpPerspective(
        mat,
        M,
        (outW, outH),
        borderValue: cv.Scalar(255, 255, 255, 255),
      );

      final (success, encoded) = cv.imencode('.jpg', warped, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 85]));

      srcMat.dispose();
      dstMat.dispose();
      M.dispose();
      warped.dispose();

      if (!success) throw Exception('이미지 인코딩 실패');
      return encoded;
    } finally {
      mat.dispose();
    }
  }

  /// Pro enhancement pipeline implementation (runs in isolate).
  static Uint8List _enhanceCardImageProImpl(Uint8List imageBytes) {
    var mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (mat.isEmpty) throw Exception('이미지를 디코딩할 수 없습니다');

    try {
      // Downscale if too large
      final maxDim = math.max(mat.cols, mat.rows);
      if (maxDim > 2000) {
        final scale = 2000.0 / maxDim;
        final resized = cv.resize(mat, (
        (mat.cols * scale).round(),
        (mat.rows * scale).round(),
        ), interpolation: cv.INTER_AREA);
        mat.dispose();
        mat = resized;
      }

      // Compute average luminance to detect dark cards
      final avgLum = _computeAvgLuminance(mat);
      final isDark = avgLum < 60;

      // Stage 0: Shadow removal (skip for dark background cards)
      if (!isDark) {
        final shadowRemoved = _removeShadows(mat);
        mat.dispose();
        mat = shadowRemoved;
      }

      // Stage 1: White balance (gray world)
      final balanced = _whiteBalance(mat, isDark);
      mat.dispose();
      mat = balanced;

      // Stage 2: CLAHE adaptive contrast
      final claheResult = _applyCLAHE(mat, isDark);
      mat.dispose();
      mat = claheResult;

      // Stage 3: Sharpening (unsharp mask)
      final sharpened = _sharpen(mat);
      mat.dispose();
      mat = sharpened;

      // Stage 4: Background edge cleanup + scan margin
      if (!isDark) {
        final cleaned = _cleanEdgesAndAddMargin(mat);
        mat.dispose();
        mat = cleaned;
      }

      final (success, encoded) = cv.imencode('.jpg', mat, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 85]));
      if (!success) throw Exception('이미지 인코딩 실패');
      return encoded;
    } finally {
      mat.dispose();
    }
  }

  /// Standard enhancement implementation (lighter than Pro).
  static Uint8List _enhanceCardImageImpl(Uint8List imageBytes) {
    var mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (mat.isEmpty) throw Exception('이미지를 디코딩할 수 없습니다');

    try {
      // Downscale if too large
      final maxDim = math.max(mat.cols, mat.rows);
      if (maxDim > 2000) {
        final scale = 2000.0 / maxDim;
        final resized = cv.resize(mat, (
        (mat.cols * scale).round(),
        (mat.rows * scale).round(),
        ), interpolation: cv.INTER_AREA);
        mat.dispose();
        mat = resized;
      }

      final isDark = _computeAvgLuminance(mat) < 60;

      // Stage 1: White balance
      final balanced = _whiteBalance(mat, isDark);
      mat.dispose();
      mat = balanced;

      // Stage 2: CLAHE
      final claheResult = _applyCLAHE(mat, isDark);
      mat.dispose();
      mat = claheResult;

      // Stage 3: Light sharpening
      final sharpened = _sharpen(mat);
      mat.dispose();
      mat = sharpened;

      final (success, encoded) = cv.imencode('.jpg', mat, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 90]));
      if (!success) throw Exception('이미지 인코딩 실패');
      return encoded;
    } finally {
      mat.dispose();
    }
  }

  /// OCR preprocessing implementation.
  static Uint8List _preprocessForOcrImpl(Uint8List imageBytes) {
    var mat = cv.imdecode(imageBytes, cv.IMREAD_COLOR);
    if (mat.isEmpty) return imageBytes;

    try {
      // Downscale large images
      final maxDim = math.max(mat.cols, mat.rows);
      if (maxDim > 2000) {
        final scale = 2000.0 / maxDim;
        final resized = cv.resize(mat, (
        (mat.cols * scale).round(),
        (mat.rows * scale).round(),
        ), interpolation: cv.INTER_AREA);
        mat.dispose();
        mat = resized;
      }

      // Ensure minimum resolution
      final minDim = math.min(mat.cols, mat.rows);
      if (minDim < 800) {
        final scale = 800.0 / minDim;
        final resized = cv.resize(mat, (
        (mat.cols * scale).round(),
        (mat.rows * scale).round(),
        ), interpolation: cv.INTER_CUBIC);
        mat.dispose();
        mat = resized;
      }

      // CLAHE for contrast enhancement
      final enhanced = _applyCLAHE(mat, false);
      mat.dispose();
      mat = enhanced;

      final (success, encoded) = cv.imencode('.jpg', mat, params: cv.VecI32.fromList([cv.IMWRITE_JPEG_QUALITY, 90]));
      if (!success) return imageBytes;
      return encoded;
    } finally {
      mat.dispose();
    }
  }

  // ──────────────────────────────────────────────
  // Private: Enhancement stages
  // ──────────────────────────────────────────────

  /// Shadow removal using morphological divide technique.
  /// Creates illumination estimate via dilate+medianBlur, then divides original.
  static cv.Mat _removeShadows(cv.Mat mat) {
    final gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);

    // Estimate illumination field: dilate → medianBlur
    final kernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (31, 31));
    final dilated = cv.dilate(gray, kernel);
    kernel.dispose();

    final bg = cv.medianBlur(dilated, 21);
    dilated.dispose();

    // Divide: result = gray / bg * 255
    // This normalizes illumination
    final divided = cv.divide(gray, bg, scale: 255.0);
    gray.dispose();
    bg.dispose();

    // Normalize to full range
    final normDst = cv.Mat.empty();
    final normalized = cv.normalize(divided, normDst, alpha: 0, beta: 255, normType: cv.NORM_MINMAX, dtype: cv.MatType.CV_8UC1.value);
    divided.dispose();

    // Convert back to BGR for downstream stages
    final result = cv.cvtColor(normalized, cv.COLOR_GRAY2BGR);
    normalized.dispose();

    return result;
  }

  /// White balance using gray world assumption.
  /// Splits into channels, scales each by avgGray/channelMean, merges back.
  static cv.Mat _whiteBalance(cv.Mat mat, bool isDark) {
    final avgLum = _computeAvgLuminance(mat);
    if (isDark || avgLum < 80) return mat.clone();

    // Split channels
    final channels = cv.split(mat);
    if (channels.length < 3) {
      for (final c in channels) {
        c.dispose();
      }
      return mat.clone();
    }

    // Compute mean of each channel
    final meanB = cv.mean(channels[0]).val1;
    final meanG = cv.mean(channels[1]).val1;
    final meanR = cv.mean(channels[2]).val1;
    final avgGray = (meanB + meanG + meanR) / 3.0;

    if (avgGray < 1) {
      for (final c in channels) {
        c.dispose();
      }
      return mat.clone();
    }

    // Scale factors (clamped to prevent aggressive shifts)
    final scaleB = (avgGray / (meanB < 1 ? 1 : meanB)).clamp(0.85, 1.2);
    final scaleG = (avgGray / (meanG < 1 ? 1 : meanG)).clamp(0.85, 1.2);
    final scaleR = (avgGray / (meanR < 1 ? 1 : meanR)).clamp(0.85, 1.2);

    // Apply scaling using convertTo (alpha=scale, beta=0)
    final scaledB = channels[0].convertTo(cv.MatType.CV_8UC1, alpha: scaleB);
    final scaledG = channels[1].convertTo(cv.MatType.CV_8UC1, alpha: scaleG);
    final scaledR = channels[2].convertTo(cv.MatType.CV_8UC1, alpha: scaleR);

    for (final c in channels) {
      c.dispose();
    }

    // Merge channels back
    final merged = cv.merge(cv.VecMat.fromList([scaledB, scaledG, scaledR]));
    scaledB.dispose();
    scaledG.dispose();
    scaledR.dispose();

    return merged;
  }

  /// CLAHE adaptive contrast enhancement.
  static cv.Mat _applyCLAHE(cv.Mat mat, bool isDark) {
    // Convert to LAB color space for luminance-only enhancement
    final lab = cv.cvtColor(mat, cv.COLOR_BGR2Lab);
    final channels = cv.split(lab);
    lab.dispose();

    if (channels.length < 3) {
      for (final c in channels) {
        c.dispose();
      }
      return mat.clone();
    }

    // Apply CLAHE to L channel only
    final clipLimit = isDark ? 1.5 : 2.5;
    final clahe = cv.CLAHE.create(clipLimit, (8, 8));
    final enhancedL = clahe.apply(channels[0]);
    clahe.dispose();
    channels[0].dispose();

    // Merge back
    final merged = cv.merge(cv.VecMat.fromList([enhancedL, channels[1], channels[2]]));
    enhancedL.dispose();
    channels[1].dispose();
    channels[2].dispose();

    // Convert back to BGR
    final result = cv.cvtColor(merged, cv.COLOR_Lab2BGR);
    merged.dispose();

    return result;
  }

  /// Unsharp mask sharpening using GaussianBlur + addWeighted.
  static cv.Mat _sharpen(cv.Mat mat) {
    final blurred = cv.gaussianBlur(mat, (0, 0), 3.0);

    // unsharp mask: result = original * (1 + amount) - blurred * amount
    // Using addWeighted: alpha=1.5, beta=-0.5, gamma=0
    final sharpened = cv.addWeighted(mat, 1.5, blurred, -0.5, 0);
    blurred.dispose();

    return sharpened;
  }

  /// Clean edges and add white scan margin for clean "scanned" look.
  static cv.Mat _cleanEdgesAndAddMargin(cv.Mat mat) {
    // Add 2% white margin on all sides
    final marginH = (mat.cols * 0.02).round().clamp(4, 20);
    final marginV = (mat.rows * 0.02).round().clamp(4, 20);

    final result = cv.copyMakeBorder(
      mat,
      marginV,
      marginV,
      marginH,
      marginH,
      cv.BORDER_CONSTANT,
      value: cv.Scalar(255, 255, 255, 255),
    );

    return result;
  }

  // ──────────────────────────────────────────────
  // Private: Utility helpers
  // ──────────────────────────────────────────────

  /// Compute average luminance by sampling pixels.
  static double _computeAvgLuminance(cv.Mat mat) {
    final gray = cv.cvtColor(mat, cv.COLOR_BGR2GRAY);
    final mean = cv.mean(gray);
    gray.dispose();
    return mean.val1;
  }

  /// Convert VecPoint to list of Point<double>.
  static List<math.Point<double>> _vecPointToList(cv.VecPoint vec) {
    final result = <math.Point<double>>[];
    for (int i = 0; i < vec.length; i++) {
      final p = vec[i];
      result.add(math.Point<double>(p.x.toDouble(), p.y.toDouble()));
    }
    return result;
  }

  /// Order 4 corners as: topLeft, topRight, bottomRight, bottomLeft.
  static List<math.Point<double>>? _orderCorners(
      List<math.Point<double>> corners) {
    if (corners.length != 4) return null;

    // Sum and diff to identify corners
    // topLeft has smallest sum (x+y)
    // bottomRight has largest sum (x+y)
    // topRight has smallest diff (y-x)
    // bottomLeft has largest diff (y-x)
    final sorted = List<math.Point<double>>.from(corners);

    sorted.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final topLeft = sorted[0];
    final bottomRight = sorted[3];

    sorted.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    final topRight = sorted[0];
    final bottomLeft = sorted[3];

    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  /// Euclidean distance between two points.
  static double _distance(math.Point<double> a, math.Point<double> b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  /// Write bytes to a temp file.
  static Future<File> _writeTempFile(Uint8List bytes, String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes);
    return outFile;
  }
}