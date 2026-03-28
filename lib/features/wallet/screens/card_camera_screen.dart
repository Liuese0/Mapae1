import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/services/image_processing_service.dart';

class CardCameraScreen extends StatefulWidget {
  const CardCameraScreen({super.key});

  @override
  State<CardCameraScreen> createState() => _CardCameraScreenState();
}

class _CardCameraScreenState extends State<CardCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isProcessingFrame = false;

  // Detected card corners in camera preview coordinates
  List<Offset>? _detectedCorners;
  // Last detected corners in image coordinates (for passing to crop screen)
  List<math.Point<double>>? _lastDetectedImageCorners;

  final ImageProcessingService _imageProcessor = ImageProcessingService();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라를 사용할 수 없습니다')),
        );
      }
      return;
    }

    final camera = cameras.first;
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
        // Start real-time edge detection
        _startEdgeDetection();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라 초기화 실패: $e')),
        );
      }
    }
  }

  void _startEdgeDetection() {
    _controller?.startImageStream((CameraImage image) {
      if (_isProcessingFrame || _isCapturing) return;
      _isProcessingFrame = true;
      _processFrame(image);
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      if (image.planes.isEmpty) {
        _isProcessingFrame = false;
        return;
      }

      // Extract Y plane (luminance) from YUV420
      final yPlane = image.planes[0].bytes;
      final width = image.width;
      final height = image.height;

      // Run edge detection in isolate to avoid UI jank
      final corners = await Isolate.run(() {
        return ImageProcessingService().detectCardEdgesFromFrame(
          yPlane,
          width,
          height,
        );
      });

      if (mounted) {
        setState(() {
          if (corners != null) {
            _lastDetectedImageCorners = corners;
            // Convert image coordinates to preview coordinates
            _detectedCorners = _convertToPreviewCoords(
              corners,
              width.toDouble(),
              height.toDouble(),
            );
          } else {
            _detectedCorners = null;
          }
        });
      }
    } catch (_) {
      // Silently ignore frame processing errors
    } finally {
      _isProcessingFrame = false;
    }
  }

  /// Convert detected corners from camera image coordinates to
  /// screen preview coordinates.
  List<Offset>? _convertToPreviewCoords(
      List<math.Point<double>> corners,
      double imageWidth,
      double imageHeight,
      ) {
    if (_controller == null) return null;

    final screenSize = MediaQuery.of(context).size;
    final previewSize = _controller!.value.previewSize;
    if (previewSize == null) return null;

    // Camera preview is rotated 90° on most devices
    // previewSize is in landscape (w > h), screen is portrait
    final previewW = previewSize.height; // rotated
    final previewH = previewSize.width; // rotated

    // Scale from image coords to screen coords
    final scaleX = screenSize.width / imageHeight; // rotated
    final scaleY = screenSize.height / imageWidth; // rotated

    return corners.map((p) {
      // Rotate 90° clockwise: (x, y) → (imageHeight - y, x)
      final rotatedX = imageHeight - p.y;
      final rotatedY = p.x;
      return Offset(rotatedX * scaleX, rotatedY * scaleY);
    }).toList();
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      // Stop image stream before capturing
      await _controller!.stopImageStream().catchError((_) {});

      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(File(xFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('��영 실패: $e')),
        );
        setState(() => _isCapturing = false);
        // Restart edge detection on failure
        _startEdgeDetection();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool cardDetected = _detectedCorners != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            Center(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Card guide overlay (shown when no card detected)
          if (_isInitialized && !cardDetected) _CardGuideOverlay(),

          // Detected card overlay (shown when card detected)
          if (_isInitialized && cardDetected && _detectedCorners != null)
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _DetectedCardPainter(corners: _detectedCorners!),
            ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    const Spacer(),
                    const SizedBox(width: 48), // balance
                  ],
                ),
              ),
            ),
          ),

          // Guidance text below card area
          if (_isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 140,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardDetected
                          ? const Color(0xCC00C853)
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cardDetected
                          ? '명함이 인식되었습니다'
                          : '명함을 가이드에 맞춰주세요',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cardDetected
                        ? '촬영 버튼을 눌러주세요'
                        : '기울어져도 자동으로 보정됩니다',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Bottom capture button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Center(
                  child: GestureDetector(
                    onTap: _isCapturing ? null : _capturePhoto,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardDetected
                              ? const Color(0xFF00C853)
                              : Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing
                                ? Colors.grey
                                : cardDetected
                                ? const Color(0xFF00C853)
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the detected card boundary as a green polygon overlay.
class _DetectedCardPainter extends CustomPainter {
  final List<Offset> corners;

  _DetectedCardPainter({required this.corners});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.length != 4) return;

    // Semi-transparent dark overlay
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw overlay with hole for detected card
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();
    canvas.drawPath(path, clearPaint);
    canvas.restore();

    // Draw green border around detected card
    final borderPaint = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // Draw corner dots
    final dotPaint = Paint()
      ..color = const Color(0xFF00C853)
      ..style = PaintingStyle.fill;

    for (final corner in corners) {
      canvas.drawCircle(corner, 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DetectedCardPainter oldDelegate) {
    return true; // Always repaint since corners change frequently
  }
}

/// Static guide overlay shown when no card is detected yet.
class _CardGuideOverlay extends StatelessWidget {
  // Standard business card ratio is roughly 9:5 (90mm x 50mm)
  static const double _cardAspectRatio = 9 / 5;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final cardWidth = screenWidth * 0.85;
        final cardHeight = cardWidth / _cardAspectRatio;
        final left = (screenWidth - cardWidth) / 2;
        final top = (constraints.maxHeight - cardHeight) / 2 - 30;

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _OverlayPainter(
            cardRect: Rect.fromLTWH(left, top, cardWidth, cardHeight),
          ),
        );
      },
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect cardRect;

  _OverlayPainter({required this.cardRect});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent dark overlay outside card area
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Draw overlay with hole
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, overlayPaint);

    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final rrect =
    RRect.fromRectAndRadius(cardRect, const Radius.circular(12));
    canvas.drawRRect(rrect, clearPaint);
    canvas.restore();

    // Draw card border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(rrect, borderPaint);

    // Draw horizontal level line through center
    final levelPaint = Paint()
      ..color = const Color(0x4400C6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(cardRect.left + 10, cardRect.center.dy),
      Offset(cardRect.right - 10, cardRect.center.dy),
      levelPaint,
    );

    // Draw vertical center line
    canvas.drawLine(
      Offset(cardRect.center.dx, cardRect.top + 10),
      Offset(cardRect.center.dx, cardRect.bottom - 10),
      levelPaint,
    );

    // Draw corner accents
    const cornerLen = 24.0;
    const cornerWidth = 3.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round;

    final r = cardRect;
    // Top-left
    canvas.drawLine(
        Offset(r.left, r.top + cornerLen), Offset(r.left, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.left, r.top), Offset(r.left + cornerLen, r.top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r.right - cornerLen, r.top), Offset(r.right, r.top),
        cornerPaint);
    canvas.drawLine(Offset(r.right, r.top),
        Offset(r.right, r.top + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLen),
        Offset(r.left, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.left, r.bottom),
        Offset(r.left + cornerLen, r.bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r.right - cornerLen, r.bottom),
        Offset(r.right, r.bottom), cornerPaint);
    canvas.drawLine(Offset(r.right, r.bottom),
        Offset(r.right, r.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.cardRect != cardRect;
}