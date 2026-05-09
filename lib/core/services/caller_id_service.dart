import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  // permission_handler 의 Permission.phone 은 Android 8+ 에서 READ_CALL_LOG 를
  // 함께 요청하지 않습니다. 네이티브 채널을 통해 직접 처리합니다.
  static const _nativeChannel =
      MethodChannel('com.namecard.mapae/permissions');

  Future<bool> _isCallLogGranted() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('isCallLogGranted');
      return result ?? false;
    } catch (e) {
      debugPrint('[CallerIdService] isCallLogGranted error: $e');
      return false;
    }
  }

  Future<bool> _requestCallLog() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('requestCallLog');
      return result ?? false;
    } catch (e) {
      debugPrint('[CallerIdService] requestCallLog error: $e');
      return false;
    }
  }

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

    debugPrint('[CallerIdService] Index built: ${_lookupIndex.length} numbers');
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

    // 정확한 매칭
    if (_lookupIndex.containsKey(normalized)) {
      return _lookupIndex[normalized];
    }

    // 뒤 8자리 매칭 (국가코드 차이 대응)
    if (normalized.length >= 8) {
      final suffix = normalized.substring(normalized.length - 8);
      for (final entry in _lookupIndex.entries) {
        if (entry.key.length >= 8 &&
            entry.key.substring(entry.key.length - 8) == suffix) {
          return entry.value;
        }
      }
    }

    return null;
  }

  /// 필요한 모든 권한이 부여되었는지 확인합니다.
  /// phone_state 플러그인은 READ_PHONE_STATE + READ_CALL_LOG 가 모두
  /// 런타임에 grant 되어야 BroadcastReceiver 를 등록하고 이벤트를 흘립니다.
  Future<bool> hasRequiredPermissions() async {
    final phoneGranted = await Permission.phone.isGranted;
    final callLogGranted = await _isCallLogGranted();
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    return phoneGranted && callLogGranted && overlayGranted;
  }

  /// 전화 상태 / 통화 기록 / 오버레이 권한을 요청합니다.
  /// 반환: 모든 권한이 허용되면 true.
  Future<bool> requestRequiredPermissions() async {
    // 1. READ_PHONE_STATE (Android 6.0+ 런타임 권한)
    var phoneStatus = await Permission.phone.status;
    if (!phoneStatus.isGranted) {
      phoneStatus = await Permission.phone.request();
    }
    if (!phoneStatus.isGranted) {
      debugPrint('[CallerIdService] READ_PHONE_STATE denied: $phoneStatus');
      return false;
    }

    // 2. READ_CALL_LOG — phone_state 플러그인이 발신자 번호를 받기 위해 필수.
    //    Android 8+ 에서는 permission_handler 의 Permission.phone 이 자동으로
    //    포함하지 않으므로 네이티브 MethodChannel 로 직접 요청합니다.
    var callLogGranted = await _isCallLogGranted();
    if (!callLogGranted) {
      callLogGranted = await _requestCallLog();
    }
    if (!callLogGranted) {
      debugPrint('[CallerIdService] READ_CALL_LOG denied');
      return false;
    }

    // 3. SYSTEM_ALERT_WINDOW (수신 화면 위에 오버레이를 그리기 위함)
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      final requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        debugPrint('[CallerIdService] Overlay permission denied');
        return false;
      }
    }

    return true;
  }

  /// 전화 상태 모니터링을 시작합니다.
  Future<void> startListening() async {
    if (_isListening) return;

    final enabled = await isEnabled;
    if (!enabled) return;

    // READ_PHONE_STATE + READ_CALL_LOG 런타임 권한 확인 (Android 6.0+).
    // phone_state 플러그인의 Android 측 코드는 두 권한이 모두 허용되어야
    // BroadcastReceiver 를 등록합니다. 둘 중 하나라도 없으면 스트림이
    // 어떤 이벤트도 발생시키지 않습니다.
    final phoneGranted = await Permission.phone.isGranted;
    final callLogGranted = await _isCallLogGranted();
    if (!phoneGranted || !callLogGranted) {
      debugPrint(
        '[CallerIdService] permissions missing — phone:$phoneGranted callLog:$callLogGranted',
      );
      return;
    }

    // 오버레이 권한 확인
    final hasOverlayPermission =
        await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlayPermission) {
      debugPrint('[CallerIdService] Overlay permission not granted');
      return;
    }

    _phoneStateSubscription = PhoneState.stream.listen((event) {
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
    }, onError: (e) {
      debugPrint('[CallerIdService] PhoneState stream error: $e');
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