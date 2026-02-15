import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/image_processing_service.dart';

/// In-app image crop screen for business cards with perspective correction.
/// Supports two modes:
/// 1. Perspective mode: 4-corner drag for warped/tilted card flattening
/// 2. Rectangle crop mode: traditional crop with rotation
/// Returns a [File] with the processed image, or null if cancelled.
class CardCropScreen extends StatefulWidget {
  final File imageFile;

  const CardCropScreen({super.key, required this.imageFile});

  @override
  State<CardCropScreen> createState() => _CardCropScreenState();
}

class _CardCropScreenState extends State<CardCropScreen> {
  ui.Image? _image;
  img.Image? _rawImage; // for edge detection
  bool _isSaving = false;
  bool _enhance = true;
  double _rotation = 0.0; // radians (only for rect mode)
  double _brightnessOffset = 0.0; // -60 to +60
  double _contrastOffset = 0.0; // -50 to +50
  double _warmthOffset = 0.0; // -30 to +30

  // Mode toggle
  bool _perspectiveMode = false;

  // Perspective mode: 4 corner points in display coordinates
  List<Offset> _corners = [];
  int? _activeCornerId;
  bool _autoDetected = false;

  // Rect mode: crop rect in image-display coordinates
  Rect _cropRect = Rect.zero;
  Rect _imageDisplayRect = Rect.zero;
  _DragHandle? _activeHandle;
  Offset _dragStart = Offset.zero;
  Rect _cropAtDragStart = Rect.zero;

  static const double _handleSize = 24;
  static const double _minCropSize = 60;
  static const double _maxRotation = math.pi / 12; // ±15°
  static const double _cornerHitRadius = 30;

  final ImageProcessingService _imageProcessor = ImageProcessingService();

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

    // Load for Flutter rendering
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    // Load for edge detection
    final rawImage = img.decodeImage(bytes);

    if (mounted) {
      final image = frame.image;
      final matrix = await _computeAdaptiveMatrix(image);
      setState(() {
        _image = image;
        _rawImage = rawImage;
        _previewMatrix = matrix;
      });

      // Try auto-detect card edges
      if (rawImage != null) {
        _tryAutoDetectEdges(rawImage);
      }
    }
  }

  /// Attempt automatic card edge detection.
  void _tryAutoDetectEdges(img.Image rawImage) {
    try {
      final detectedCorners = _imageProcessor.detectCardEdges(rawImage);
      if (detectedCorners != null && mounted && _image != null) {
        // Schedule corner initialization after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _imageDisplayRect != Rect.zero) {
            final scaleX = _imageDisplayRect.width / rawImage.width;
            final scaleY = _imageDisplayRect.height / rawImage.height;

            setState(() {
              _corners = detectedCorners
                  .map((p) => Offset(
                _imageDisplayRect.left + p.x * scaleX,
                _imageDisplayRect.top + p.y * scaleY,
              ))
                  .toList();
              _autoDetected = true;
            });
          }
        });
      }
    } catch (_) {
      // Auto-detection failed silently - user can manually adjust
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

      for (int i = 0; i + 2 < pixels.length; i += 40) {
        totalLum +=
            0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
        sampleCount++;
      }

      if (sampleCount == 0) return _fallbackMatrix;
      final avgLum = totalLum / sampleCount;

      double contrast;
      if (avgLum < 80) {
        contrast = 1.1;
      } else if (avgLum > 190) {
        contrast = 1.1;
      } else {
        contrast = 1.2;
      }

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

  /// Returns the adaptive matrix with user brightness, contrast, warmth offsets.
  List<double> get _combinedMatrix {
    final base = List<double>.from(_previewMatrix);

    // Apply user brightness offset
    base[4] += _brightnessOffset;
    base[9] += _brightnessOffset;
    base[14] += _brightnessOffset;

    // Apply contrast offset (scale the diagonal)
    final contrastScale = 1.0 + _contrastOffset / 100.0;
    base[0] *= contrastScale;
    base[6] *= contrastScale;
    base[12] *= contrastScale;

    // Apply warmth offset (shift R up, B down or vice versa)
    base[4] += _warmthOffset * 0.5; // red channel
    base[14] -= _warmthOffset * 0.3; // blue channel

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

    // Init perspective corners if not auto-detected
    if (_corners.isEmpty) {
      _corners = [
        Offset(cropX, cropY), // topLeft
        Offset(cropX + cropW, cropY), // topRight
        Offset(cropX + cropW, cropY + cropH), // bottomRight
        Offset(cropX, cropY + cropH), // bottomLeft
      ];
    }
  }

  // ──────────────────────────────────────────────
  // Perspective mode: 4-corner drag
  // ──────────────────────────────────────────────

  int? _hitTestCorner(Offset pos) {
    for (int i = 0; i < _corners.length; i++) {
      if ((pos - _corners[i]).distance < _cornerHitRadius) {
        return i;
      }
    }
    return null;
  }

  void _onPerspectivePanStart(DragStartDetails d) {
    _activeCornerId = _hitTestCorner(d.localPosition);
  }

  void _onPerspectivePanUpdate(DragUpdateDetails d) {
    if (_activeCornerId == null) return;

    final newPos = Offset(
      d.localPosition.dx.clamp(
          _imageDisplayRect.left, _imageDisplayRect.right),
      d.localPosition.dy.clamp(
          _imageDisplayRect.top, _imageDisplayRect.bottom),
    );

    setState(() {
      _corners[_activeCornerId!] = newPos;
    });
  }

  void _onPerspectivePanEnd(DragEndDetails d) {
    _activeCornerId = null;
  }

  // ──────────────────────────────────────────────
  // Rectangle mode: existing crop logic
  // ──────────────────────────────────────────────

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

  void _onRectPanStart(DragStartDetails d) {
    _activeHandle = _hitTest(d.localPosition);
    _dragStart = d.localPosition;
    _cropAtDragStart = _cropRect;
  }

  void _onRectPanUpdate(DragUpdateDetails d) {
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

  void _onRectPanEnd(DragEndDetails d) {
    _activeHandle = null;
  }

  // ──────────────────────────────────────────────
  // Image enhancement (Flutter Canvas-based for preview)
  // ──────────────────────────────────────────────

  Future<ui.Image> _enhanceCardImage(ui.Image source) async {
    final w = source.width;
    final h = source.height;
    final srcRect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    final baseMatrix = await _computeAdaptiveMatrix(source);
    final matrix = List<double>.from(baseMatrix);
    matrix[4] += _brightnessOffset;
    matrix[9] += _brightnessOffset;
    matrix[14] += _brightnessOffset;

    // Apply contrast
    final contrastScale = 1.0 + _contrastOffset / 100.0;
    matrix[0] *= contrastScale;
    matrix[6] *= contrastScale;
    matrix[12] *= contrastScale;

    // Apply warmth
    matrix[4] += _warmthOffset * 0.5;
    matrix[14] -= _warmthOffset * 0.3;

    // Pass 1: Adaptive contrast + brightness + warmth
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

    // Pass 3: Saturation boost
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

  // ──────────────────────────────────────────────
  // Save / Confirm
  // ──────────────────────────────────────────────

  Future<void> _confirmCrop() async {
    if (_image == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (_perspectiveMode) {
        await _savePerspective();
      } else {
        await _saveRectCrop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('처리 실패: $e')),
        );
        setState(() => _isSaving = false);
      }
    }
  }

  /// Save with perspective correction using the 4 corner points.
  Future<void> _savePerspective() async {
    if (_rawImage == null || _corners.length != 4) return;

    // Convert display-space corners to original image pixel coordinates
    final scaleX = _rawImage!.width / _imageDisplayRect.width;
    final scaleY = _rawImage!.height / _imageDisplayRect.height;

    final imgCorners = _corners.map((c) {
      return math.Point<double>(
        (c.dx - _imageDisplayRect.left) * scaleX,
        (c.dy - _imageDisplayRect.top) * scaleY,
      );
    }).toList();

    // Apply perspective correction
    File resultFile = await _imageProcessor.perspectiveCorrect(
      widget.imageFile,
      imgCorners,
    );

    // Apply enhanced color/light correction if enabled
    if (_enhance) {
      resultFile = await _imageProcessor.enhanceCardImage(resultFile);
    }

    if (mounted) Navigator.of(context).pop(resultFile);
  }

  /// Save with traditional rectangle crop + rotation.
  Future<void> _saveRectCrop() async {
    final scaleX = _image!.width / _imageDisplayRect.width;
    final scaleY = _image!.height / _imageDisplayRect.height;

    final outW = (_cropRect.width * scaleX).round();
    final outH = (_cropRect.height * scaleY).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final outputRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

    canvas.drawRect(outputRect, Paint()..color = const Color(0xFFFFFFFF));

    final imgCx = _imageDisplayRect.center.dx;
    final imgCy = _imageDisplayRect.center.dy;

    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-_cropRect.left, -_cropRect.top);
    canvas.translate(imgCx, imgCy);
    canvas.rotate(_rotation);
    canvas.translate(-imgCx, -imgCy);
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
  }

  String get _rotationDegreeText {
    final deg = (_rotation * 180 / math.pi);
    return '${deg >= 0 ? '+' : ''}${deg.toStringAsFixed(1)}°';
  }

  // ──────────────────────────────────────────────
  // UI Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            _buildTopBar(),

            // Mode toggle
            _buildModeToggle(theme),

            // Image + crop/perspective area
            Expanded(
              child: _image == null
                  ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
                  : LayoutBuilder(
                builder: (context, constraints) {
                  final displaySize = Size(
                      constraints.maxWidth, constraints.maxHeight);
                  if (_cropRect == Rect.zero) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _initCropRect(displaySize));
                      }
                    });
                  }
                  return GestureDetector(
                    onPanStart: _perspectiveMode
                        ? _onPerspectivePanStart
                        : _onRectPanStart,
                    onPanUpdate: _perspectiveMode
                        ? _onPerspectivePanUpdate
                        : _onRectPanUpdate,
                    onPanEnd: _perspectiveMode
                        ? _onPerspectivePanEnd
                        : _onRectPanEnd,
                    child: CustomPaint(
                      size: displaySize,
                      painter: _perspectiveMode
                          ? _PerspectivePainter(
                        image: _image!,
                        corners: _corners,
                        imageDisplayRect: _imageDisplayRect,
                        enhance: _enhance,
                        enhanceMatrix: _combinedMatrix,
                        activeCorner: _activeCornerId,
                      )
                          : _CropPainter(
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
            _buildBottomControls(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              _perspectiveMode ? '명함 모서리를 맞춰주세요' : '명함 영역을 선택하세요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _perspectiveMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _perspectiveMode
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _perspectiveMode
                        ? theme.colorScheme.primary
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.transform,
                      size: 16,
                      color: _perspectiveMode
                          ? theme.colorScheme.primary
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '원근 보정',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _perspectiveMode
                            ? theme.colorScheme.primary
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _perspectiveMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_perspectiveMode
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: !_perspectiveMode
                        ? theme.colorScheme.primary
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.crop,
                      size: 16,
                      color: !_perspectiveMode
                          ? theme.colorScheme.primary
                          : Colors.white54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '직사각 크롭',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_perspectiveMode
                            ? theme.colorScheme.primary
                            : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rotation slider (only in rect mode)
          if (!_perspectiveMode) ...[
            _buildSliderRow(
              icon: Icons.rotate_right,
              value: _rotation,
              min: -_maxRotation,
              max: _maxRotation,
              label: _rotationDegreeText,
              isActive: _rotation != 0,
              onChanged: (v) => setState(() => _rotation = v),
              onReset: () => setState(() => _rotation = 0),
              theme: theme,
            ),
            const SizedBox(height: 4),
          ],

          // Brightness slider
          _buildSliderRow(
            icon: Icons.brightness_6,
            value: _brightnessOffset,
            min: -60,
            max: 60,
            label:
            '${_brightnessOffset >= 0 ? '+' : ''}${_brightnessOffset.round()}',
            isActive: _brightnessOffset != 0,
            onChanged: (v) => setState(() => _brightnessOffset = v),
            onReset: () => setState(() => _brightnessOffset = 0),
            theme: theme,
          ),
          const SizedBox(height: 4),

          // Contrast slider
          _buildSliderRow(
            icon: Icons.contrast,
            value: _contrastOffset,
            min: -50,
            max: 50,
            label:
            '${_contrastOffset >= 0 ? '+' : ''}${_contrastOffset.round()}',
            isActive: _contrastOffset != 0,
            onChanged: (v) => setState(() => _contrastOffset = v),
            onReset: () => setState(() => _contrastOffset = 0),
            theme: theme,
          ),
          const SizedBox(height: 4),

          // Warmth slider
          _buildSliderRow(
            icon: Icons.wb_sunny_outlined,
            value: _warmthOffset,
            min: -30,
            max: 30,
            label:
            '${_warmthOffset >= 0 ? '+' : ''}${_warmthOffset.round()}',
            isActive: _warmthOffset != 0,
            onChanged: (v) => setState(() => _warmthOffset = v),
            onReset: () => setState(() => _warmthOffset = 0),
            theme: theme,
          ),
          const SizedBox(height: 8),

          // Auto-detection badge + enhance toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_autoDetected && _perspectiveMode)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        '자동 감지됨',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              GestureDetector(
                onTap: () => setState(() => _enhance = !_enhance),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _enhance
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                      _enhance ? theme.colorScheme.primary : Colors.white24,
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
            ],
          ),
          const SizedBox(height: 10),

          // Action buttons
          Row(
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
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required String label,
    required bool isActive,
    required ValueChanged<double> onChanged,
    required VoidCallback onReset,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        GestureDetector(
          onTap: onReset,
          child: Icon(
            icon,
            size: 18,
            color: isActive ? Colors.white : Colors.white38,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: theme.colorScheme.primary.withOpacity(0.2),
              trackHeight: 2,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        GestureDetector(
          onTap: onReset,
          child: SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? Colors.white : Colors.white38,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Perspective Painter: draws image with 4-corner overlay
// ──────────────────────────────────────────────

class _PerspectivePainter extends CustomPainter {
  final ui.Image image;
  final List<Offset> corners;
  final Rect imageDisplayRect;
  final bool enhance;
  final List<double> enhanceMatrix;
  final int? activeCorner;

  _PerspectivePainter({
    required this.image,
    required this.corners,
    required this.imageDisplayRect,
    required this.enhance,
    required this.enhanceMatrix,
    this.activeCorner,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());

    // Draw full image dimmed
    final dimPaint = Paint()
      ..colorFilter = const ColorFilter.matrix(<double>[
        0.4, 0, 0, 0, 0,
        0, 0.4, 0, 0, 0,
        0, 0, 0.4, 0, 0,
        0, 0, 0, 1, 0,
      ]);
    canvas.drawImageRect(image, src, imageDisplayRect, dimPaint);

    if (corners.length != 4) return;

    // Draw the selected quad area bright/enhanced
    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    canvas.save();
    canvas.clipPath(path);
    final brightPaint = enhance
        ? (Paint()..colorFilter = ColorFilter.matrix(enhanceMatrix))
        : Paint();
    canvas.drawImageRect(image, src, imageDisplayRect, brightPaint);
    canvas.restore();

    // Draw quad border
    final borderPaint = Paint()
      ..color = const Color(0xFF00C6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);

    // Draw edge lines between corners with subtle blue glow
    final edgeGlowPaint = Paint()
      ..color = const Color(0x3300C6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawPath(path, edgeGlowPaint);

    // Draw corner handles
    for (int i = 0; i < 4; i++) {
      final isActive = activeCorner == i;
      final cornerRadius = isActive ? 14.0 : 10.0;

      // Outer glow
      canvas.drawCircle(
        corners[i],
        cornerRadius + 4,
        Paint()..color = const Color(0x2200C6FF),
      );

      // Fill
      canvas.drawCircle(
        corners[i],
        cornerRadius,
        Paint()..color = isActive ? const Color(0xFF00C6FF) : Colors.white,
      );

      // Inner dot
      canvas.drawCircle(
        corners[i],
        3,
        Paint()
          ..color =
          isActive ? Colors.white : const Color(0xFF00C6FF),
      );

      // Corner bracket lines
      _drawCornerBracket(canvas, corners[i], i);
    }

    // Draw grid inside the quad (3x3)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 2; i++) {
      final t = i / 3.0;
      // Horizontal lines
      final leftPoint = Offset.lerp(corners[0], corners[3], t)!;
      final rightPoint = Offset.lerp(corners[1], corners[2], t)!;
      canvas.drawLine(leftPoint, rightPoint, gridPaint);

      // Vertical lines
      final topPoint = Offset.lerp(corners[0], corners[1], t)!;
      final bottomPoint = Offset.lerp(corners[3], corners[2], t)!;
      canvas.drawLine(topPoint, bottomPoint, gridPaint);
    }
  }

  void _drawCornerBracket(Canvas canvas, Offset center, int cornerIndex) {
    const len = 20.0;
    final paint = Paint()
      ..color = const Color(0xFF00C6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Direction vectors based on corner position
    final double dx1, dy1, dx2, dy2;
    switch (cornerIndex) {
      case 0: // topLeft
        dx1 = len;
        dy1 = 0;
        dx2 = 0;
        dy2 = len;
        break;
      case 1: // topRight
        dx1 = -len;
        dy1 = 0;
        dx2 = 0;
        dy2 = len;
        break;
      case 2: // bottomRight
        dx1 = -len;
        dy1 = 0;
        dx2 = 0;
        dy2 = -len;
        break;
      case 3: // bottomLeft
        dx1 = len;
        dy1 = 0;
        dx2 = 0;
        dy2 = -len;
        break;
      default:
        return;
    }

    canvas.drawLine(center, Offset(center.dx + dx1, center.dy + dy1), paint);
    canvas.drawLine(center, Offset(center.dx + dx2, center.dy + dy2), paint);
  }

  @override
  bool shouldRepaint(covariant _PerspectivePainter old) =>
      old.corners != corners ||
          old.image != image ||
          old.enhance != enhance ||
          old.activeCorner != activeCorner;
}

// ──────────────────────────────────────────────
// Rectangle Crop Painter (original, preserved)
// ──────────────────────────────────────────────

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
        ..color = const Color(0x5500CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7;

      final cx = cropRect.center.dx;
      final cy = cropRect.center.dy;

      canvas.drawLine(
        Offset(cx, cropRect.top - 20),
        Offset(cx, cropRect.bottom + 20),
        guidePaint,
      );
      canvas.drawLine(
        Offset(cropRect.left - 20, cy),
        Offset(cropRect.right + 20, cy),
        guidePaint,
      );

      final sixthH = cropRect.height / 6;
      final sixthW = cropRect.width / 6;
      final fineGuidePaint = Paint()
        ..color = const Color(0x2A00CCFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      for (var i = 1; i < 6; i++) {
        if (i == 3) continue;
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