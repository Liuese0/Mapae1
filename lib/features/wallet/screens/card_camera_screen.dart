import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CardCameraScreen extends StatefulWidget {
  const CardCameraScreen({super.key});

  @override
  State<CardCameraScreen> createState() => _CardCameraScreenState();
}

class _CardCameraScreenState extends State<CardCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

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
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('카메라 초기화 실패: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || _isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      final xFile = await _controller!.takePicture();
      if (mounted) {
        Navigator.of(context).pop(File(xFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('촬영 실패: $e')),
        );
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

          // Card guide overlay
          if (_isInitialized) _CardGuideOverlay(),

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
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '명함을 가이드에 맞춰주세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '기울어져도 자동으로 보정됩니다',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
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
                        border:
                        Border.all(color: Colors.white, width: 4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isCapturing
                                ? Colors.grey
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
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);
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
      ..color = Colors.white.withOpacity(0.8)
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