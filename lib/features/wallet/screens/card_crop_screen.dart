import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// In-app image crop screen for business cards.
/// Returns a [File] with the cropped image, or null if cancelled.
class CardCropScreen extends StatefulWidget {
  final File imageFile;

  const CardCropScreen({super.key, required this.imageFile});

  @override
  State<CardCropScreen> createState() => _CardCropScreenState();
}

class _CardCropScreenState extends State<CardCropScreen> {
  ui.Image? _image;
  bool _isSaving = false;

  // Crop rect in image-display coordinates (relative to the displayed image)
  Rect _cropRect = Rect.zero;

  // Image display info
  Rect _imageDisplayRect = Rect.zero;

  // Drag state
  _DragHandle? _activeHandle;
  Offset _dragStart = Offset.zero;
  Rect _cropAtDragStart = Rect.zero;

  static const double _handleSize = 20;
  static const double _minCropSize = 60;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) {
      setState(() => _image = frame.image);
    }
  }

  void _initCropRect(Size displaySize) {
    if (_image == null) return;

    final imgAspect = _image!.width / _image!.height;
    double displayW, displayH, offsetX, offsetY;

    if (imgAspect > displaySize.width / displaySize.height) {
      displayW = displaySize.width;
      displayH = displaySize.width / imgAspect;
      offsetX = 0;
      offsetY = (displaySize.height - displayH) / 2;
    } else {
      displayH = displaySize.height;
      displayW = displaySize.height * imgAspect;
      offsetX = (displaySize.width - displayW) / 2;
      offsetY = 0;
    }

    _imageDisplayRect = Rect.fromLTWH(offsetX, offsetY, displayW, displayH);

    // Default crop: 85% of image area, centered, 9:5 card ratio
    const cardRatio = 9 / 5;
    double cropW = displayW * 0.85;
    double cropH = cropW / cardRatio;
    if (cropH > displayH * 0.85) {
      cropH = displayH * 0.85;
      cropW = cropH * cardRatio;
    }
    final cropX = offsetX + (displayW - cropW) / 2;
    final cropY = offsetY + (displayH - cropH) / 2;

    _cropRect = Rect.fromLTWH(cropX, cropY, cropW, cropH);
  }

  _DragHandle? _hitTest(Offset pos) {
    final r = _cropRect;
    final s = _handleSize;

    if ((pos - r.topLeft).distance < s) return _DragHandle.topLeft;
    if ((pos - r.topRight).distance < s) return _DragHandle.topRight;
    if ((pos - r.bottomLeft).distance < s) return _DragHandle.bottomLeft;
    if ((pos - r.bottomRight).distance < s) return _DragHandle.bottomRight;

    // Edge midpoints
    if ((pos - Offset(r.center.dx, r.top)).distance < s) return _DragHandle.topCenter;
    if ((pos - Offset(r.center.dx, r.bottom)).distance < s) return _DragHandle.bottomCenter;
    if ((pos - Offset(r.left, r.center.dy)).distance < s) return _DragHandle.centerLeft;
    if ((pos - Offset(r.right, r.center.dy)).distance < s) return _DragHandle.centerRight;

    if (r.contains(pos)) return _DragHandle.move;

    return null;
  }

  void _onPanStart(DragStartDetails d) {
    _activeHandle = _hitTest(d.localPosition);
    _dragStart = d.localPosition;
    _cropAtDragStart = _cropRect;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeHandle == null) return;

    final delta = d.localPosition - _dragStart;
    final r = _cropAtDragStart;
    final bounds = _imageDisplayRect;
    Rect newRect;

    switch (_activeHandle!) {
      case _DragHandle.move:
        var dx = delta.dx;
        var dy = delta.dy;
        var l = r.left + dx;
        var t = r.top + dy;
        l = l.clamp(bounds.left, bounds.right - r.width);
        t = t.clamp(bounds.top, bounds.bottom - r.height);
        newRect = Rect.fromLTWH(l, t, r.width, r.height);
        break;
      case _DragHandle.topLeft:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(bounds.left, r.right - _minCropSize),
          (r.top + delta.dy).clamp(bounds.top, r.bottom - _minCropSize),
          r.right,
          r.bottom,
        );
        break;
      case _DragHandle.topRight:
        newRect = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(bounds.top, r.bottom - _minCropSize),
          (r.right + delta.dx).clamp(r.left + _minCropSize, bounds.right),
          r.bottom,
        );
        break;
      case _DragHandle.bottomLeft:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(bounds.left, r.right - _minCropSize),
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + _minCropSize, bounds.bottom),
        );
        break;
      case _DragHandle.bottomRight:
        newRect = Rect.fromLTRB(
          r.left,
          r.top,
          (r.right + delta.dx).clamp(r.left + _minCropSize, bounds.right),
          (r.bottom + delta.dy).clamp(r.top + _minCropSize, bounds.bottom),
        );
        break;
      case _DragHandle.topCenter:
        newRect = Rect.fromLTRB(
          r.left,
          (r.top + delta.dy).clamp(bounds.top, r.bottom - _minCropSize),
          r.right,
          r.bottom,
        );
        break;
      case _DragHandle.bottomCenter:
        newRect = Rect.fromLTRB(
          r.left,
          r.top,
          r.right,
          (r.bottom + delta.dy).clamp(r.top + _minCropSize, bounds.bottom),
        );
        break;
      case _DragHandle.centerLeft:
        newRect = Rect.fromLTRB(
          (r.left + delta.dx).clamp(bounds.left, r.right - _minCropSize),
          r.top,
          r.right,
          r.bottom,
        );
        break;
      case _DragHandle.centerRight:
        newRect = Rect.fromLTRB(
          r.left,
          r.top,
          (r.right + delta.dx).clamp(r.left + _minCropSize, bounds.right),
          r.bottom,
        );
        break;
    }

    setState(() => _cropRect = newRect);
  }

  void _onPanEnd(DragEndDetails d) {
    _activeHandle = null;
  }

  Future<void> _confirmCrop() async {
    if (_image == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      // Convert crop rect from display coordinates to actual image pixels
      final scaleX = _image!.width / _imageDisplayRect.width;
      final scaleY = _image!.height / _imageDisplayRect.height;

      final srcLeft = (_cropRect.left - _imageDisplayRect.left) * scaleX;
      final srcTop = (_cropRect.top - _imageDisplayRect.top) * scaleY;
      final srcWidth = _cropRect.width * scaleX;
      final srcHeight = _cropRect.height * scaleY;

      final srcRect = Rect.fromLTWH(
        srcLeft.clamp(0, _image!.width.toDouble()),
        srcTop.clamp(0, _image!.height.toDouble()),
        srcWidth.clamp(1, _image!.width.toDouble() - srcLeft),
        srcHeight.clamp(1, _image!.height.toDouble() - srcTop),
      );

      // Draw cropped region to a new image
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(
        _image!,
        srcRect,
        Rect.fromLTWH(0, 0, srcRect.width, srcRect.height),
        Paint(),
      );
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(
        srcRect.width.round(),
        srcRect.height.round(),
      );

      // Encode to PNG and save
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('이미지 저장 실패');

      final tempDir = await getTemporaryDirectory();
      final outFile = File(
        '${tempDir.path}/card_cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) Navigator.of(context).pop(outFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('크롭 실패: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      '명함 영역을 선택하세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Image + crop area
            Expanded(
              child: _image == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final displaySize = Size(constraints.maxWidth, constraints.maxHeight);
                  if (_cropRect == Rect.zero) {
                    // Run after build to set initial crop rect
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _initCropRect(displaySize));
                      }
                    });
                  }
                  return GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: CustomPaint(
                      size: displaySize,
                      painter: _CropPainter(
                        image: _image!,
                        cropRect: _cropRect,
                        imageDisplayRect: _imageDisplayRect,
                        handleSize: _handleSize,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSaving ? null : _confirmCrop,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('완료'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  final ui.Image image;
  final Rect cropRect;
  final Rect imageDisplayRect;
  final double handleSize;

  _CropPainter({
    required this.image,
    required this.cropRect,
    required this.imageDisplayRect,
    required this.handleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw image
    final src = Rect.fromLTWH(
      0, 0, image.width.toDouble(), image.height.toDouble(),
    );
    canvas.drawImageRect(image, src, imageDisplayRect, Paint());

    if (cropRect == Rect.zero) return;

    // Dim area outside crop
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.55);
    // Top
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), dimPaint);
    // Bottom
    canvas.drawRect(Rect.fromLTRB(0, cropRect.bottom, size.width, size.height), dimPaint);
    // Left
    canvas.drawRect(Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom), dimPaint);
    // Right
    canvas.drawRect(Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom), dimPaint);

    // Crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // Grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final thirdW = cropRect.width / 3;
    final thirdH = cropRect.height / 3;
    for (var i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(cropRect.left + thirdW * i, cropRect.top),
        Offset(cropRect.left + thirdW * i, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + thirdH * i),
        Offset(cropRect.right, cropRect.top + thirdH * i),
        gridPaint,
      );
    }

    // Corner handles
    const cornerLen = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final r = cropRect;
    // Top-left
    canvas.drawLine(Offset(r.left, r.top + cornerLen), r.topLeft, cornerPaint);
    canvas.drawLine(r.topLeft, Offset(r.left + cornerLen, r.top), cornerPaint);
    // Top-right
    canvas.drawLine(Offset(r.right - cornerLen, r.top), r.topRight, cornerPaint);
    canvas.drawLine(r.topRight, Offset(r.right, r.top + cornerLen), cornerPaint);
    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLen), r.bottomLeft, cornerPaint);
    canvas.drawLine(r.bottomLeft, Offset(r.left + cornerLen, r.bottom), cornerPaint);
    // Bottom-right
    canvas.drawLine(Offset(r.right - cornerLen, r.bottom), r.bottomRight, cornerPaint);
    canvas.drawLine(r.bottomRight, Offset(r.right, r.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.cropRect != cropRect || old.image != image;
}

enum _DragHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  bottomCenter,
  centerLeft,
  centerRight,
  move,
}