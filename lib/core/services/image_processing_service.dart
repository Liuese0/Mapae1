import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Service for advanced business card image processing:
/// - Perspective correction (flatten warped/tilted cards)
/// - Auto edge detection
/// - Color & light normalization
/// - OCR-optimized preprocessing
class ImageProcessingService {
  /// Apply perspective correction using 4 source corner points.
  /// [srcCorners] are the 4 corners of the detected card in the original image
  /// in order: topLeft, topRight, bottomRight, bottomLeft.
  /// [imageFile] is the source image file.
  /// Returns a new file with the perspective-corrected image.
  Future<File> perspectiveCorrect(
      File imageFile,
      List<math.Point<double>> srcCorners, {
        int? outputWidth,
        int? outputHeight,
      }) async {
    final bytes = await imageFile.readAsBytes();
    final srcImage = img.decodeImage(bytes);
    if (srcImage == null) throw Exception('이미지를 디코딩할 수 없습니다');

    // Calculate output dimensions from the card corners if not specified
    final topEdge = _distance(srcCorners[0], srcCorners[1]);
    final bottomEdge = _distance(srcCorners[3], srcCorners[2]);
    final leftEdge = _distance(srcCorners[0], srcCorners[3]);
    final rightEdge = _distance(srcCorners[1], srcCorners[2]);

    final outW = outputWidth ?? math.max(topEdge, bottomEdge).round();
    final outH = outputHeight ?? math.max(leftEdge, rightEdge).round();

    // Destination corners: a flat rectangle
    final dstCorners = [
      math.Point<double>(0, 0),
      math.Point<double>(outW.toDouble(), 0),
      math.Point<double>(outW.toDouble(), outH.toDouble()),
      math.Point<double>(0, outH.toDouble()),
    ];

    // Compute the inverse homography (dst -> src) for sampling
    final h = _computeHomography(dstCorners, srcCorners);

    final result = img.Image(width: outW, height: outH);

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final srcPt = _applyHomography(h, x.toDouble(), y.toDouble());
        final sx = srcPt.x;
        final sy = srcPt.y;

        if (sx >= 0 &&
            sx < srcImage.width - 1 &&
            sy >= 0 &&
            sy < srcImage.height - 1) {
          final pixel = _bilinearSample(srcImage, sx, sy);
          result.setPixel(x, y, pixel);
        } else {
          result.setPixelRgba(x, y, 255, 255, 255, 255);
        }
      }
    }

    return _saveImage(result, 'perspective');
  }

  /// Detect card edges automatically from the image.
  /// Returns 4 corner points [topLeft, topRight, bottomRight, bottomLeft]
  /// in image pixel coordinates, or null if detection fails.
  List<math.Point<double>>? detectCardEdges(img.Image image) {
    // Downscale for faster processing
    final scale = math.min(1.0, 500.0 / math.max(image.width, image.height));
    final small = scale < 1.0
        ? img.copyResize(image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round())
        : image;

    // Convert to grayscale
    final gray = img.grayscale(small);

    // Apply Gaussian blur to reduce noise
    final blurred = img.gaussianBlur(gray, radius: 3);

    // Edge detection using Sobel
    final edges = _sobelEdgeDetection(blurred);

    // Find the largest rectangular contour
    final corners = _findLargestQuad(edges, small.width, small.height);

    if (corners == null) return null;

    // Scale corners back to original image coordinates
    final invScale = 1.0 / scale;
    return corners
        .map((p) => math.Point<double>(p.x * invScale, p.y * invScale))
        .toList();
  }

  /// Enhanced color and light correction for business card images.
  /// Uses lightweight operations for speed.
  Future<File> enhanceCardImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final srcImage = img.decodeImage(bytes);
    if (srcImage == null) throw Exception('이미지를 디코딩할 수 없습니다');

    var result = srcImage;

    // Downscale if too large for pixel-level processing
    final maxDim = math.max(result.width, result.height);
    if (maxDim > 2000) {
      final scale = 2000.0 / maxDim;
      result = img.copyResize(
        result,
        width: (result.width * scale).round(),
        height: (result.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Step 1: White balance correction (fast, sampling-based)
    result = _whiteBalance(result);

    // Step 2: Adaptive contrast enhancement (LUT-based, fast)
    result = _adaptiveContrastEnhance(result);

    // Step 3: Light sharpening (small radius blur only)
    result = _sharpen(result);

    return _saveImage(result, 'enhanced');
  }

  /// Lightweight preprocessing for OCR: only contrast stretching via LUT.
  /// Avoids heavy gaussianBlur operations that are too slow in pure Dart.
  /// OCR.space API handles orientation detection and scaling itself.
  Future<File> preprocessForOcr(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final srcImage = img.decodeImage(bytes);
    if (srcImage == null) return imageFile;

    var result = srcImage;

    // Downscale large images to max 2000px for faster processing
    final maxDim = math.max(result.width, result.height);
    if (maxDim > 2000) {
      final scale = 2000.0 / maxDim;
      result = img.copyResize(
        result,
        width: (result.width * scale).round(),
        height: (result.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Ensure minimum resolution for OCR
    final minDim = math.min(result.width, result.height);
    if (minDim < 800) {
      final scale = 800.0 / minDim;
      result = img.copyResize(
        result,
        width: (result.width * scale).round(),
        height: (result.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }

    // Fast contrast stretching only (single-pass LUT, no blur)
    result = _fastContrastStretch(result);

    return _saveImage(result, 'ocr_preprocessed');
  }

  /// Fast single-pass contrast stretching using a lookup table.
  /// Much faster than gaussianBlur-based approaches.
  img.Image _fastContrastStretch(img.Image image) {
    // Build histogram by sampling every 4th pixel (fast)
    final histogram = List<int>.filled(256, 0);
    int count = 0;

    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        final lum = (0.299 * p.r.toDouble() +
            0.587 * p.g.toDouble() +
            0.114 * p.b.toDouble())
            .round()
            .clamp(0, 255);
        histogram[lum]++;
        count++;
      }
    }

    if (count == 0) return image;

    // Find 2nd and 98th percentile
    final lowTarget = (count * 0.02).round();
    final highTarget = (count * 0.98).round();
    int low = 0, high = 255;
    int cumulative = 0;

    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative >= lowTarget && low == 0) low = i;
      if (cumulative >= highTarget) {
        high = i;
        break;
      }
    }

    if (high <= low) return image;

    // Build LUT with slight gamma darkening for text
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      final stretched = ((i - low) * 255.0 / (high - low)).clamp(0.0, 255.0);
      lut[i] = (255 * math.pow(stretched / 255.0, 0.9)).round().clamp(0, 255);
    }

    // Apply LUT in single pass
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        image.setPixelRgba(
          x,
          y,
          lut[p.r.toInt().clamp(0, 255)],
          lut[p.g.toInt().clamp(0, 255)],
          lut[p.b.toInt().clamp(0, 255)],
          p.a.toInt(),
        );
      }
    }
    return image;
  }

  // ──────────────────────────────────────────────
  // Private: Perspective transform helpers
  // ──────────────────────────────────────────────

  double _distance(math.Point<double> a, math.Point<double> b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  /// Compute 3x3 homography matrix from src to dst using DLT algorithm.
  /// Both [src] and [dst] must have exactly 4 points.
  List<double> _computeHomography(
      List<math.Point<double>> src,
      List<math.Point<double>> dst,
      ) {
    // Set up the 8x9 matrix for DLT
    final a = List<List<double>>.generate(8, (_) => List.filled(9, 0.0));

    for (int i = 0; i < 4; i++) {
      final sx = src[i].x, sy = src[i].y;
      final dx = dst[i].x, dy = dst[i].y;

      a[i * 2][0] = sx;
      a[i * 2][1] = sy;
      a[i * 2][2] = 1;
      a[i * 2][3] = 0;
      a[i * 2][4] = 0;
      a[i * 2][5] = 0;
      a[i * 2][6] = -dx * sx;
      a[i * 2][7] = -dx * sy;
      a[i * 2][8] = -dx;

      a[i * 2 + 1][0] = 0;
      a[i * 2 + 1][1] = 0;
      a[i * 2 + 1][2] = 0;
      a[i * 2 + 1][3] = sx;
      a[i * 2 + 1][4] = sy;
      a[i * 2 + 1][5] = 1;
      a[i * 2 + 1][6] = -dy * sx;
      a[i * 2 + 1][7] = -dy * sy;
      a[i * 2 + 1][8] = -dy;
    }

    // Solve using Gaussian elimination to find the null space
    final h = _solveHomography(a);
    return h;
  }

  /// Solve 8x9 homogeneous system Ah=0 via Gaussian elimination.
  List<double> _solveHomography(List<List<double>> a) {
    const rows = 8;
    const cols = 9;

    // Forward elimination with partial pivoting
    for (int col = 0; col < rows; col++) {
      // Find pivot
      int maxRow = col;
      double maxVal = a[col][col].abs();
      for (int row = col + 1; row < rows; row++) {
        if (a[row][col].abs() > maxVal) {
          maxVal = a[row][col].abs();
          maxRow = row;
        }
      }
      if (maxRow != col) {
        final temp = a[col];
        a[col] = a[maxRow];
        a[maxRow] = temp;
      }

      final pivot = a[col][col];
      if (pivot.abs() < 1e-10) continue;

      for (int j = col; j < cols; j++) {
        a[col][j] /= pivot;
      }

      for (int row = 0; row < rows; row++) {
        if (row == col) continue;
        final factor = a[row][col];
        for (int j = col; j < cols; j++) {
          a[row][j] -= factor * a[col][j];
        }
      }
    }

    // Back-substitute: set h[8] = 1
    final h = List<double>.filled(9, 0.0);
    h[8] = 1.0;
    for (int i = rows - 1; i >= 0; i--) {
      h[i] = -a[i][8]; // since a[i][i]*h[i] + a[i][8]*1 = 0
    }

    return h;
  }

  /// Apply homography transform to a point.
  math.Point<double> _applyHomography(List<double> h, double x, double y) {
    final w = h[6] * x + h[7] * y + h[8];
    if (w.abs() < 1e-10) return math.Point(x, y);
    final nx = (h[0] * x + h[1] * y + h[2]) / w;
    final ny = (h[3] * x + h[4] * y + h[5]) / w;
    return math.Point(nx, ny);
  }

  /// Bilinear sampling from an image at sub-pixel coordinates.
  img.Color _bilinearSample(img.Image image, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = x0 + 1;
    final y1 = y0 + 1;
    final fx = x - x0;
    final fy = y - y0;

    final clampX0 = x0.clamp(0, image.width - 1);
    final clampY0 = y0.clamp(0, image.height - 1);
    final clampX1 = x1.clamp(0, image.width - 1);
    final clampY1 = y1.clamp(0, image.height - 1);

    final p00 = image.getPixel(clampX0, clampY0);
    final p10 = image.getPixel(clampX1, clampY0);
    final p01 = image.getPixel(clampX0, clampY1);
    final p11 = image.getPixel(clampX1, clampY1);

    final r = _bilerp(p00.r.toDouble(), p10.r.toDouble(),
        p01.r.toDouble(), p11.r.toDouble(), fx, fy);
    final g = _bilerp(p00.g.toDouble(), p10.g.toDouble(),
        p01.g.toDouble(), p11.g.toDouble(), fx, fy);
    final b = _bilerp(p00.b.toDouble(), p10.b.toDouble(),
        p01.b.toDouble(), p11.b.toDouble(), fx, fy);

    return img.ColorRgba8(r.round().clamp(0, 255), g.round().clamp(0, 255),
        b.round().clamp(0, 255), 255);
  }

  double _bilerp(
      double v00, double v10, double v01, double v11, double fx, double fy) {
    return v00 * (1 - fx) * (1 - fy) +
        v10 * fx * (1 - fy) +
        v01 * (1 - fx) * fy +
        v11 * fx * fy;
  }

  // ──────────────────────────────────────────────
  // Private: Edge detection
  // ──────────────────────────────────────────────

  /// Simple Sobel edge detection returning edge magnitude image.
  img.Image _sobelEdgeDetection(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final result = img.Image(width: w, height: h);

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        // Sobel kernels
        final gx = -_lum(gray, x - 1, y - 1) -
            2 * _lum(gray, x - 1, y) -
            _lum(gray, x - 1, y + 1) +
            _lum(gray, x + 1, y - 1) +
            2 * _lum(gray, x + 1, y) +
            _lum(gray, x + 1, y + 1);

        final gy = -_lum(gray, x - 1, y - 1) -
            2 * _lum(gray, x, y - 1) -
            _lum(gray, x + 1, y - 1) +
            _lum(gray, x - 1, y + 1) +
            2 * _lum(gray, x, y + 1) +
            _lum(gray, x + 1, y + 1);

        final mag = math.sqrt(gx * gx + gy * gy).round().clamp(0, 255);
        result.setPixelRgba(x, y, mag, mag, mag, 255);
      }
    }
    return result;
  }

  double _lum(img.Image image, int x, int y) {
    final p = image.getPixel(x, y);
    return p.r.toDouble();
  }

  /// Find the largest quadrilateral in edge image using line scanning.
  /// Returns 4 corners or null if no good quad found.
  List<math.Point<double>>? _findLargestQuad(
      img.Image edges, int width, int height) {
    // Apply threshold to get binary edge map
    const threshold = 50;
    final binary = List<List<bool>>.generate(
        height, (y) => List.generate(width, (x) => false));

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges.getPixel(x, y).r > threshold) {
          binary[y][x] = true;
        }
      }
    }

    // Use Hough-like line detection to find card boundary
    // Scan from each edge to find the card boundary
    final top = _scanFromEdge(binary, width, height, _ScanDirection.top);
    final bottom =
    _scanFromEdge(binary, width, height, _ScanDirection.bottom);
    final left = _scanFromEdge(binary, width, height, _ScanDirection.left);
    final right =
    _scanFromEdge(binary, width, height, _ScanDirection.right);

    if (top == null || bottom == null || left == null || right == null) {
      return null;
    }

    // Validate the detected quad has reasonable proportions
    final quadWidth = right - left;
    final quadHeight = bottom - top;
    if (quadWidth < width * 0.3 || quadHeight < height * 0.2) {
      return null;
    }

    return [
      math.Point<double>(left.toDouble(), top.toDouble()),
      math.Point<double>(right.toDouble(), top.toDouble()),
      math.Point<double>(right.toDouble(), bottom.toDouble()),
      math.Point<double>(left.toDouble(), bottom.toDouble()),
    ];
  }

  int? _scanFromEdge(List<List<bool>> binary, int width, int height,
      _ScanDirection direction) {
    switch (direction) {
      case _ScanDirection.top:
        for (int y = 0; y < height; y++) {
          int edgeCount = 0;
          for (int x = 0; x < width; x++) {
            if (binary[y][x]) edgeCount++;
          }
          if (edgeCount > width * 0.15) return y;
        }
        return null;
      case _ScanDirection.bottom:
        for (int y = height - 1; y >= 0; y--) {
          int edgeCount = 0;
          for (int x = 0; x < width; x++) {
            if (binary[y][x]) edgeCount++;
          }
          if (edgeCount > width * 0.15) return y;
        }
        return null;
      case _ScanDirection.left:
        for (int x = 0; x < width; x++) {
          int edgeCount = 0;
          for (int y = 0; y < height; y++) {
            if (binary[y][x]) edgeCount++;
          }
          if (edgeCount > height * 0.15) return x;
        }
        return null;
      case _ScanDirection.right:
        for (int x = width - 1; x >= 0; x--) {
          int edgeCount = 0;
          for (int y = 0; y < height; y++) {
            if (binary[y][x]) edgeCount++;
          }
          if (edgeCount > height * 0.15) return x;
        }
        return null;
    }
  }

  // ──────────────────────────────────────────────
  // Private: Color & Light correction
  // ──────────────────────────────────────────────

  /// White balance correction using gray-world assumption.
  img.Image _whiteBalance(img.Image image) {
    double totalR = 0, totalG = 0, totalB = 0;
    int count = 0;

    // Sample pixels for average color
    for (int y = 0; y < image.height; y += 4) {
      for (int x = 0; x < image.width; x += 4) {
        final p = image.getPixel(x, y);
        totalR += p.r.toDouble();
        totalG += p.g.toDouble();
        totalB += p.b.toDouble();
        count++;
      }
    }

    if (count == 0) return image;

    final avgR = totalR / count;
    final avgG = totalG / count;
    final avgB = totalB / count;
    final avgGray = (avgR + avgG + avgB) / 3.0;

    if (avgGray < 1) return image;

    final scaleR = avgGray / (avgR < 1 ? 1 : avgR);
    final scaleG = avgGray / (avgG < 1 ? 1 : avgG);
    final scaleB = avgGray / (avgB < 1 ? 1 : avgB);

    // Clamp scale factors to avoid extreme corrections
    final clampedR = scaleR.clamp(0.7, 1.5);
    final clampedG = scaleG.clamp(0.7, 1.5);
    final clampedB = scaleB.clamp(0.7, 1.5);

    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        result.setPixelRgba(
          x,
          y,
          (p.r * clampedR).round().clamp(0, 255),
          (p.g * clampedG).round().clamp(0, 255),
          (p.b * clampedB).round().clamp(0, 255),
          p.a.toInt(),
        );
      }
    }
    return result;
  }

  /// Adaptive contrast enhancement (simplified CLAHE-like approach).
  img.Image _adaptiveContrastEnhance(img.Image image) {
    // Compute histogram
    final histogram = List<int>.filled(256, 0);
    int count = 0;

    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final p = image.getPixel(x, y);
        final lum =
        (0.299 * p.r.toDouble() + 0.587 * p.g.toDouble() + 0.114 * p.b.toDouble())
            .round()
            .clamp(0, 255);
        histogram[lum]++;
        count++;
      }
    }

    if (count == 0) return image;

    // Find 5th and 95th percentile for contrast stretching
    final p5Target = (count * 0.05).round();
    final p95Target = (count * 0.95).round();
    int p5 = 0, p95 = 255;
    int cumulative = 0;

    for (int i = 0; i < 256; i++) {
      cumulative += histogram[i];
      if (cumulative >= p5Target && p5 == 0) p5 = i;
      if (cumulative >= p95Target) {
        p95 = i;
        break;
      }
    }

    if (p95 <= p5) return image;

    // Build lookup table for contrast stretching
    final lut = Uint8List(256);
    for (int i = 0; i < 256; i++) {
      lut[i] = ((i - p5) * 255.0 / (p95 - p5)).round().clamp(0, 255);
    }

    final result = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        result.setPixelRgba(
          x,
          y,
          lut[p.r.toInt().clamp(0, 255)],
          lut[p.g.toInt().clamp(0, 255)],
          lut[p.b.toInt().clamp(0, 255)],
          p.a.toInt(),
        );
      }
    }
    return result;
  }

  /// Unsharp mask sharpening.
  img.Image _sharpen(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 1);
    final result = img.Image(width: image.width, height: image.height);
    const amount = 0.6; // sharpening strength

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final orig = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (orig.r + (orig.r - blur.r) * amount)
            .round()
            .clamp(0, 255);
        final g = (orig.g + (orig.g - blur.g) * amount)
            .round()
            .clamp(0, 255);
        final b = (orig.b + (orig.b - blur.b) * amount)
            .round()
            .clamp(0, 255);

        result.setPixelRgba(x, y, r, g, b, orig.a.toInt());
      }
    }
    return result;
  }

  // ──────────────────────────────────────────────
  // Private: Utility
  // ──────────────────────────────────────────────

  Future<File> _saveImage(img.Image image, String prefix) async {
    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final encoded = img.encodeJpg(image, quality: 90);
    final outFile = File(outPath);
    await outFile.writeAsBytes(encoded);
    return outFile;
  }
}

enum _ScanDirection { top, bottom, left, right }