import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:phone_state/phone_state.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/phone_utils.dart';
import '../../features/shared/models/caller_info.dart';
import '../../features/shared/models/collected_card.dart';
import '../../features/shared/models/crm_contact.dart';

/// Caller ID 서비스 - 수신 전화 시 명함 정보를 오버레이로 표시합니다. (Android)
class CallerIdService {
  static final CallerIdService _instance = CallerIdService._();
  factory CallerIdService() => _instance;
  CallerIdService._();

  final Map<String, CallerInfo> _lookupIndex = {};
  StreamSubscription? _phoneStateSubscription;
  bool _isListening = false;

  static const _prefKey = 'caller_id_enabled';

  /// Caller ID 기능 활성화 여부
  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// 활성화/비활성화 토글
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
    if (enabled) {
      await startListening();
    } else {
      stopListening();
    }
  }

  /// 수집한 명함 + CRM 연락처로 전화번호 인덱스를 구축합니다.
  void buildIndex({
    List<CollectedCard>? collectedCards,
    List<CrmContact>? crmContacts,
  }) {
    _lookupIndex.clear();

    // 수집한 명함
    if (collectedCards != null) {
      for (final card in collectedCards) {
        _addToIndex(
          phones: [card.phone, card.mobile],
          info: CallerInfo(
            name: card.name ?? '',
            company: card.company,
            position: card.position,
            imageUrl: card.imageUrl,
            source: 'collected',
          ),
        );
      }
    }

    // CRM 연락처
    if (crmContacts != null) {
      for (final contact in crmContacts) {
        _addToIndex(
          phones: [contact.phone, contact.mobile],
          info: CallerInfo(
            name: contact.name ?? '',
            company: contact.company,
            position: contact.position,
            source: 'crm',
          ),
        );
      }
    }

    final collectedCount = collectedCards?.length ?? 0;
    final crmCount = crmContacts?.length ?? 0;
    debugPrint(
      '[CallerIdService] Index built: ${_lookupIndex.length} numbers '
          '(collected=$collectedCount, crm=$crmCount)',
    );
  }

  void _addToIndex({required List<String?> phones, required CallerInfo info}) {
    for (final phone in phones) {
      if (phone == null || phone.isEmpty) continue;
      final normalized = normalizePhone(phone);
      if (normalized.length >= 7) {
        _lookupIndex[normalized] = info;
      }
    }
  }

  /// 전화번호로 명함 정보를 조회합니다.
  CallerInfo? lookupNumber(String incomingNumber) {
    final normalized = normalizePhone(incomingNumber);
    debugPrint(
      '[CallerIdService] lookup raw="$incomingNumber" normalized="$normalized" '
          'indexSize=${_lookupIndex.length}',
    );

    // 정확한 매칭
    if (_lookupIndex.containsKey(normalized)) {
      debugPrint('[CallerIdService] lookup HIT (exact)');
      return _lookupIndex[normalized];
    }

    // 뒤 8자리 매칭 (국가코드 차이 대응)
    if (normalized.length >= 8) {
      final suffix = normalized.substring(normalized.length - 8);
      for (final entry in _lookupIndex.entries) {
        if (entry.key.length >= 8 &&
            entry.key.substring(entry.key.length - 8) == suffix) {
          debugPrint('[CallerIdService] lookup HIT (suffix)');
          return entry.value;
        }
      }
    }

    debugPrint('[CallerIdService] lookup MISS');
    return null;
  }

  /// 전화 상태 모니터링을 시작합니다.
  Future<void> startListening() async {
    if (_isListening) return;

    final enabled = await isEnabled;
    if (!enabled) return;

    // 오버레이 권한 확인
    final hasOverlay = await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlay) {
      debugPrint('[CallerIdService] Overlay permission not granted');
      return;
    }

    // 전화 상태 권한 확인 (Android 6+ 런타임 요청 필요)
    final phoneStatus = await Permission.phone.request();
    if (!phoneStatus.isGranted) {
      debugPrint('[CallerIdService] Phone permission not granted: $phoneStatus');
      return;
    }

    _phoneStateSubscription = PhoneState.stream.listen((event) {
      final tail = (event.number != null && event.number!.length >= 4)
          ? event.number!.substring(event.number!.length - 4)
          : (event.number ?? '');
      debugPrint('[CallerIdService] PhoneState ${event.status} ...$tail');

      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final number = event.number;
        if (number != null && number.isNotEmpty) {
          final info = lookupNumber(number);
          if (info != null) {
            _showOverlay(info);
          }
        }
      } else if (event.status == PhoneStateStatus.CALL_ENDED) {
        _hideOverlay();
      }
    });

    _isListening = true;
    debugPrint('[CallerIdService] Listening started');
  }

  /// 전화 상태 모니터링을 중지합니다.
  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _isListening = false;
    debugPrint('[CallerIdService] Listening stopped');
  }

  Future<void> _showOverlay(CallerInfo info) async {
    try {
      await FlutterOverlayWindow.showOverlay(
        height: 180,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        enableDrag: true,
      );
      // 오버레이에 데이터 전달
      await FlutterOverlayWindow.shareData({
        'name': info.name,
        'company': info.company ?? '',
        'position': info.position ?? '',
        'source': info.source,
      });
    } catch (e) {
      debugPrint('[CallerIdService] Overlay error: $e');
    }
  }

  Future<void> _hideOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('[CallerIdService] Hide overlay error: $e');
    }
  }
}