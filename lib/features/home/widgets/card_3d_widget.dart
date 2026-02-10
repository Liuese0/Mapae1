import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../shared/models/business_card.dart';

/// A 3D-perspective business card widget that responds to drag gestures.
class Card3DWidget extends StatefulWidget {
  final BusinessCard card;

  const Card3DWidget({super.key, required this.card});

  @override
  State<Card3DWidget> createState() => _Card3DWidgetState();
}

class _Card3DWidgetState extends State<Card3DWidget>
    with SingleTickerProviderStateMixin {
  double _rotateX = 0;
  double _rotateY = 0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimationX;
  late Animation<double> _resetAnimationY;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _resetController.addListener(() {
      setState(() {
        _rotateX = _resetAnimationX.value;
        _rotateY = _resetAnimationY.value;
      });
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotateY += details.delta.dx * 0.008;
      _rotateX -= details.delta.dy * 0.008;
      _rotateX = _rotateX.clamp(-0.3, 0.3);
      _rotateY = _rotateY.clamp(-0.3, 0.3);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _resetAnimationX = Tween<double>(begin: _rotateX, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetAnimationY = Tween<double>(begin: _rotateY, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // perspective
          ..rotateX(_rotateX)
          ..rotateY(_rotateY),
        child: AspectRatio(
          aspectRatio: 9 / 5,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                  const Color(0xFF2C2C2C),
                  const Color(0xFF1A1A1A),
                ]
                    : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF5F5F5),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                  blurRadius: 24,
                  offset: Offset(_rotateY * 20, _rotateX * -20 + 8),
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: widget.card.imageUrl != null
                  ? _buildImageCard()
                  : _buildInfoCard(theme, isDark),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Image.network(
      widget.card.imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildInfoCard(
        Theme.of(context),
        Theme.of(context).brightness == Brightness.dark,
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Company
          if (widget.card.company != null)
            Text(
              widget.card.company!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                letterSpacing: 1,
              ),
            ),
          const Spacer(),
          // Name
          Text(
            widget.card.name ?? 'Mapae',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (widget.card.position != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.card.position!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          const Spacer(),
          // Contact info
          Row(
            children: [
              if (widget.card.email != null)
                Expanded(
                  child: Text(
                    widget.card.email!,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.card.phone != null)
                Text(
                  widget.card.phone!,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}