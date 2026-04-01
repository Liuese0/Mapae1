import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 수신 전화 시 표시되는 오버레이 위젯 (엔트리포인트)
///
/// flutter_overlay_window에 의해 별도 isolate에서 실행됩니다.
class CallerIdOverlay extends StatefulWidget {
  const CallerIdOverlay({super.key});

  @override
  State<CallerIdOverlay> createState() => _CallerIdOverlayState();
}

class _CallerIdOverlayState extends State<CallerIdOverlay> {
  String _name = '';
  String _company = '';
  String _position = '';
  String _source = '';
  StreamSubscription? _dataSub;

  @override
  void initState() {
    super.initState();
    _dataSub = FlutterOverlayWindow.overlayListener.listen((data) {
      if (data is Map) {
        setState(() {
          _name = data['name'] as String? ?? '';
          _company = data['company'] as String? ?? '';
          _position = data['position'] as String? ?? '';
          _source = data['source'] as String? ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.isNotEmpty ? _name[0] : '?';
    final isFromCrm = _source == 'crm';

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => FlutterOverlayWindow.closeOverlay(),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 48, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 아바타
              CircleAvatar(
                radius: 24,
                backgroundColor: isFromCrm
                    ? const Color(0xFF6366F1).withOpacity(0.2)
                    : const Color(0xFF10B981).withOpacity(0.2),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isFromCrm
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF10B981),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Mapae 로고/레이블
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Mapae',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isFromCrm
                                ? const Color(0xFF6366F1).withOpacity(0.1)
                                : const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isFromCrm ? 'CRM' : 'Contact',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w500,
                              color: isFromCrm
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_company.isNotEmpty || _position.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [_company, _position].where((s) => s.isNotEmpty).join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              // 닫기 버튼
              IconButton(
                onPressed: () => FlutterOverlayWindow.closeOverlay(),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}