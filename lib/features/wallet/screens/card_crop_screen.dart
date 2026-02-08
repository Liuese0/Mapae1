import 'dart:io';
import 'dart:math' as math;
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
  bool _enhance = true;
  double _rotation = 0.0; // radians
  double _brightnessOffset = 0.0; // -60 to +60, user manual adjustment

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
  static const double _maxRotation = math.pi / 12; // ±15°

  // Adaptive enhancement matrix (computed from image brightness)
  List<double> _previewMatrix = _fallbackMatrix;

  static const _fallbackMatrix = <double>[
    1.2, 0, 0, 0, -5.0,
    0, 1.2, 0, 0, -5.0,
    0, 0, 1.2, 0, -5.0,
    0, 0, 0, 1, 0,
  ];

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
      final image = frame.image;
      final matrix = await _computeAdaptiveMatrix(image);
      setState(() {
        _image = image;
        _previewMatrix = matrix;
      });
    }
  }

  /// Samples image pixels to compute brightness-adaptive color correction.
  static Future<List<double>> _computeAdaptiveMatrix(ui.Image image) async {
    try {
      final byteData =
      await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return _fallbackMatrix;

      final pixels = byteData.buffer.asUint8List();
      double totalLum = 0;
      int sampleCount = 0;

      // Sample every 40 bytes (= every 10th pixel) for performance
      for (int i = 0; i + 2 < pixels.length; i += 40) {
        totalLum += 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
        sampleCount++;
      }

      if (sampleCount == 0) return _fallbackMatrix;
      final avgLum = totalLum / sampleCount;

      // Adaptive contrast: gentler at extremes to avoid clipping
      double contrast;
      if (avgLum < 80) {
        contrast = 1.1;
      } else if (avgLum > 190) {
        contrast = 1.1;
      } else {
        contrast = 1.2;
      }

      // Push average luminance toward target (~135 for clean card look)
      const target = 135.0;
      double brightness = target - avgLum * contrast;
      brightness = brightness.clamp(-50.0, 60.0);

      return <double>[
        contrast, 0, 0, 0, brightness,
        0, contrast, 0, 0, brightness,
        0, 0, contrast, 0, brightness,
        0, 0, 0, 1, 0,
      ];
    } catch (_) {
      return _fallbackMatrix;
    }
  }

  /// Returns the adaptive matrix with user brightness offset applied.
  List<double> get _combinedMatrix {
    final base = List<double>.from(_previewMatrix);
    base[4] += _brightnessOffset;
    base[9] += _brightnessOffset;
    base[14] += _brightnessOffset;
    return base;
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

    if ((pos - Offset(r.center.dx, r.top)).distance < s)
      return _DragHandle.topCenter;
    if ((pos - Offset(r.center.dx, r.bottom)).distance < s)
      return _DragHandle.bottomCenter;
    if ((pos - Offset(r.left, r.center.dy)).distance < s)
      return _DragHandle.centerLeft;
    if ((pos - Offset(r.right, r.center.dy)).distance < s)
      return _DragHandle.centerRight;

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
        var l = r.left + delta.dx;
        var t = r.top + delta.dy;
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

  /// Enhances the cropped image with adaptive brightness + sharpening + saturation.
  Future<ui.Image> _enhanceCardImage(ui.Image source) async {
    final w = source.width;
    final h = source.height;
    final srcRect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    // Recompute adaptive matrix for the actual cropped content + user offset
    final baseMatrix = await _computeAdaptiveMatrix(source);
    final matrix = List<double>.from(baseMatrix);
    matrix[4] += _brightnessOffset;
    matrix[9] += _brightnessOffset;
    matrix[14] += _brightnessOffset;

    // Pass 1: Adaptive contrast + brightness
    final recorder1 = ui.PictureRecorder();
    final canvas1 = Canvas(recorder1);
    canvas1.drawImageRect(
      source,
      srcRect,
      srcRect,
      Paint()..colorFilter = ColorFilter.matrix(matrix),
    );
    final pass1 = await recorder1.endRecording().toImage(w, h);

    // Pass 2: Sharpening via unsharp mask
    final recorder2 = ui.PictureRecorder();
    final canvas2 = Canvas(recorder2);
    canvas2.drawImage(pass1, Offset.zero, Paint());

    canvas2.saveLayer(srcRect, Paint()..blendMode = BlendMode.plus);
    canvas2.drawImage(
      pass1,
      Offset.zero,
      Paint()
        ..colorFilter = const ColorFilter.matrix(<double>[
          0.15, 0, 0, 0, 0,
          0, 0.15, 0, 0, 0,
          0, 0, 0.15, 0, 0,
          0, 0, 0, 1, 0,
        ]),
    );
    canvas2.drawImage(
      pass1,
      Offset.zero,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5)
        ..colorFilter = const ColorFilter.matrix(<double>[
          0.15, 0, 0, 0, 0,
          0, 0.15, 0, 0, 0,
          0, 0, 0.15, 0, 0,
          0, 0, 0, 1, 0,
        ]),
    );
    canvas2.restore();

    // Pass 3: Slight saturation boost
    final pass2 = await recorder2.endRecording().toImage(w, h);
    final recorder3 = ui.PictureRecorder();
    final canvas3 = Canvas(recorder3);
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    const s = 1.15;
    const sr = (1 - s) * lr;
    const sg = (1 - s) * lg;
    const sb = (1 - s) * lb;
    canvas3.drawImageRect(
      pass2,
      srcRect,
      srcRect,
      Paint()
        ..colorFilter = ColorFilter.matrix(<double>[
          sr + s, sg, sb, 0, 0,
          sr, sg + s, sb, 0, 0,
          sr, sg, sb + s, 0, 0,
          0, 0, 0, 1, 0,
        ]),
    );

    return recorder3.endRecording().toImage(w, h);
  }

  Future<void> _confirmCrop() async {
    if (_image == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final scaleX = _image!.width / _imageDisplayRect.width;
      final scaleY = _image!.height / _imageDisplayRect.height;

      final outW = (_cropRect.width * scaleX).round();
      final outH = (_cropRect.height * scaleY).round();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final outputRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

      // White background for areas outside source after rotation
      canvas.drawRect(outputRect, Paint()..color = const Color(0xFFFFFFFF));

      // Transform: source pixel → display (unrotated) → display (rotated) → output pixel
      final imgCx = _imageDisplayRect.center.dx;
      final imgCy = _imageDisplayRect.center.dy;

      canvas.save();
      // Step 3: rotated display → output
      canvas.scale(scaleX, scaleY);
      canvas.translate(-_cropRect.left, -_cropRect.top);
      // Step 2: rotate around image center
      canvas.translate(imgCx, imgCy);
      canvas.rotate(_rotation);
      canvas.translate(-imgCx, -imgCy);
      // Step 1: source → unrotated display
      canvas.translate(_imageDisplayRect.left, _imageDisplayRect.top);
      canvas.scale(1.0 / scaleX, 1.0 / scaleY);

      canvas.drawImage(_image!, Offset.zero, Paint());
      canvas.restore();

      var croppedImage = await recorder.endRecording().toImage(outW, outH);

      if (_enhance) {
        croppedImage = await _enhanceCardImage(croppedImage);
      }

      final byteData =
      await croppedImage.toByteData(format: ui.ImageByteFormat.png);
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

  String get _rotationDegreeText {
    final deg = (_rotation * 180 / math.pi);
    return '${deg >= 0 ? '+' : ''}${deg.toStringAsFixed(1)}°';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  ? const Center(
                  child:
                  CircularProgressIndicator(color: Colors.white))
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final displaySize = Size(
                      constraints.maxWidth, constraints.maxHeight);
                  if (_cropRect == Rect.zero) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) {
                      if (mounted) {
                        setState(
                                () => _initCropRect(displaySize));
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
                        enhance: _enhance,
                        enhanceMatrix: _combinedMatrix,
                        rotation: _rotation,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom controls
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rotation slider
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _rotation = 0),
                        child: Icon(
                          Icons.rotate_right,
                          size: 20,
                          color: _rotation != 0
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor:
                            theme.colorScheme.primary.withOpacity(0.2),
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _rotation,
                            min: -_maxRotation,
                            max: _maxRotation,
                            onChanged: (v) =>
                                setState(() => _rotation = v),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _rotation = 0),
                        child: SizedBox(
                          width: 44,
                          child: Text(
                            _rotationDegreeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: _rotation != 0
                                  ? Colors.white
                                  : Colors.white38,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Brightness slider
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _brightnessOffset = 0),
                        child: Icon(
                          Icons.brightness_6,
                          size: 20,
                          color: _brightnessOffset != 0
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor:
                            theme.colorScheme.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: theme.colorScheme.primary
                                .withOpacity(0.2),
                            trackHeight: 2,
                            thumbShape:
                            const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: _brightnessOffset,
                            min: -60,
                            max: 60,
                            onChanged: (v) => setState(
                                    () => _brightnessOffset = v),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _brightnessOffset = 0),
                        child: SizedBox(
                          width: 44,
                          child: Text(
                            '${_brightnessOffset >= 0 ? '+' : ''}${_brightnessOffset.round()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _brightnessOffset != 0
                                  ? Colors.white
                                  : Colors.white38,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Enhance toggle
                  GestureDetector(
                    onTap: () => setState(() => _enhance = !_enhance),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _enhance
                            ? theme.colorScheme.primary.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _enhance
                              ? theme.colorScheme.primary
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_fix_high,
                            size: 18,
                            color: _enhance
                                ? theme.colorScheme.primary
                                : Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '자동 보정',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _enhance
                                  ? theme.colorScheme.primary
                                  : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _confirmCrop,
                          style: FilledButton.styleFrom(
                            padding:
                            const EdgeInsets.symmetric(vertical: 14),
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
  final bool enhance;
  final List<double> enhanceMatrix;
  final double rotation;

  _CropPainter({
    required this.image,
    required this.cropRect,
    required this.imageDisplayRect,
    required this.handleSize,
    required this.enhance,
    required this.enhanceMatrix,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0, 0, image.width.toDouble(), image.height.toDouble(),
    );

    final imgCx = imageDisplayRect.center.dx;
    final imgCy = imageDisplayRect.center.dy;

    // Draw full image (dimmed + rotated)
    final dimPaint = Paint()
      ..colorFilter = const ColorFilter.matrix(<double>[
        0.4, 0, 0, 0, 0,
        0, 0.4, 0, 0, 0,
        0, 0, 0.4, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    canvas.save();
    canvas.translate(imgCx, imgCy);
    canvas.rotate(rotation);
    canvas.translate(-imgCx, -imgCy);
    canvas.drawImageRect(image, src, imageDisplayRect, dimPaint);
    canvas.restore();

    if (cropRect == Rect.zero) return;

    // Draw crop area (bright/enhanced + rotated)
    canvas.save();
    canvas.clipRect(cropRect);
    canvas.translate(imgCx, imgCy);
    canvas.rotate(rotation);
    canvas.translate(-imgCx, -imgCy);
    final cropPaint = enhance
        ? (Paint()..colorFilter = ColorFilter.matrix(enhanceMatrix))
        : Paint();
    canvas.drawImageRect(image, src, imageDisplayRect, cropPaint);
    canvas.restore();

    // Crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(cropRect, borderPaint);

    // Alignment guide lines (only when rotating)
    if (rotation != 0) {
      final guidePaint = Paint()
        ..color = const Color(0x5500CCFF) // cyan, semi-transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;

      final cx = cropRect.center.dx;
      final cy = cropRect.center.dy;

      // Vertical center line (extends beyond crop)
      canvas.drawLine(
        Offset(cx, cropRect.top - 20),
        Offset(cx, cropRect.bottom + 20),
        guidePaint,
      );
      // Horizontal center line (extends beyond crop)
      canvas.drawLine(
        Offset(cropRect.left - 20, cy),
        Offset(cropRect.right + 20, cy),
        guidePaint,
      );

      // Fine horizontal guide lines (every 1/6 of height)
      final sixthH = cropRect.height / 6;
      final sixthW = cropRect.width / 6;
      final fineGuidePaint = Paint()
        ..color = const Color(0x2A00CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      for (var i = 1; i < 6; i++) {
        if (i == 3) continue; // skip center, already drawn
        canvas.drawLine(
          Offset(cropRect.left, cropRect.top + sixthH * i),
          Offset(cropRect.right, cropRect.top + sixthH * i),
          fineGuidePaint,
        );
        canvas.drawLine(
          Offset(cropRect.left + sixthW * i, cropRect.top),
          Offset(cropRect.left + sixthW * i, cropRect.bottom),
          fineGuidePaint,
        );
      }
    }

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
    canvas.drawLine(
        Offset(r.left, r.top + cornerLen), r.topLeft, cornerPaint);
    canvas.drawLine(
        r.topLeft, Offset(r.left + cornerLen, r.top), cornerPaint);
    canvas.drawLine(
        Offset(r.right - cornerLen, r.top), r.topRight, cornerPaint);
    canvas.drawLine(
        r.topRight, Offset(r.right, r.top + cornerLen), cornerPaint);
    canvas.drawLine(
        Offset(r.left, r.bottom - cornerLen), r.bottomLeft, cornerPaint);
    canvas.drawLine(
        r.bottomLeft, Offset(r.left + cornerLen, r.bottom), cornerPaint);
    canvas.drawLine(
        Offset(r.right - cornerLen, r.bottom), r.bottomRight, cornerPaint);
    canvas.drawLine(
        r.bottomRight, Offset(r.right, r.bottom - cornerLen), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      old.cropRect != cropRect ||
          old.image != image ||
          old.enhance != enhance ||
          old.rotation != rotation;
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