import 'dart:async';
import 'dart:convert';
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

/// Caller ID 서비스 — 수신 전화 시 명함 정보를 오버레이로 표시합니다. (Android)
///
/// 동작:
///   • 사용자가 명함을 추가/수정/삭제하면 자동으로 인덱스 + 로컬 캐시(SharedPreferences)
///     를 갱신합니다.
///   • 앱이 살아있는 동안에는 phone_state 스트림을 통해 수신을 감지하고 오버레이를
///     띄웁니다.
///   • 앱이 종료된 상태에서는 native BroadcastReceiver(CallReceiver) 가 동일한
///     SharedPreferences 캐시를 읽고 오버레이 서비스를 직접 시작합니다.
class CallerIdService {
  static final CallerIdService _instance = CallerIdService._();
  factory CallerIdService() => _instance;
  CallerIdService._();

  final Map<String, CallerInfo> _lookupIndex = {};
  StreamSubscription? _phoneStateSubscription;
  bool _isListening = false;
  bool _overlayVisible = false;
  CallerInfo? _currentCaller;

  // SharedPreferences 키 (네이티브에서도 동일한 이름으로 읽음)
  static const _prefEnabledKey = 'caller_id_enabled';
  static const _prefCacheKey = 'caller_id_cache_v1';

  static const _nativeChannel =
  MethodChannel('com.namecard.mapae/permissions');

  // -------------------- 권한 헬퍼 (네이티브) --------------------

  Future<bool> _isCallLogGranted() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('isCallLogGranted');
      return result ?? false;
    } catch (e) {
      debugPrint('[CallerId] isCallLogGranted error: $e');
      return false;
    }
  }

  Future<bool> _requestCallLog() async {
    try {
      final result = await _nativeChannel.invokeMethod<bool>('requestCallLog');
      return result ?? false;
    } catch (e) {
      debugPrint('[CallerId] requestCallLog error: $e');
      return false;
    }
  }

  /// 진단용: 임의의 번호로 오버레이 표시를 시뮬레이션합니다.
  /// 실제 전화 없이 표시 동작을 확인하기 위함.
  /// 반환: 정상적으로 시작되면 true, 캐시에 매칭되는 번호가 없으면 false.
  Future<bool> testOverlay({
    required String number,
    String mode = 'banner',
  }) async {
    try {
      final ok = await _nativeChannel.invokeMethod<bool>(
        'testOverlay',
        {'number': number, 'mode': mode},
      );
      return ok ?? false;
    } catch (e) {
      debugPrint('[CallerId] testOverlay error: $e');
      return false;
    }
  }

  Future<void> stopOverlay() async {
    try {
      await _nativeChannel.invokeMethod('stopOverlay');
    } catch (_) {}
  }

  // -------------------- 활성화 토글 --------------------

  Future<bool> get isEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefEnabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabledKey, enabled);
    if (enabled) {
      await startListening();
    } else {
      stopListening();
    }
  }

  // -------------------- 인덱스 + 로컬 캐시 --------------------

  /// 수집한 명함 + CRM 연락처로 전화번호 인덱스와 SharedPreferences 캐시를
  /// 동시에 구축합니다. 캐시는 네이티브 BroadcastReceiver 가 그대로 읽습니다.
  Future<void> buildIndex({
    List<CollectedCard>? collectedCards,
    List<CrmContact>? crmContacts,
  }) async {
    _lookupIndex.clear();

    if (collectedCards != null) {
      for (final card in collectedCards) {
        _addToIndex(
          phones: [card.phone, card.mobile],
          info: CallerInfo(
            name: card.name ?? '',
            company: card.company,
            position: card.position,
            department: card.department,
            email: card.email,
            imageUrl: card.imageUrl,
            memo: card.memo,
            source: 'collected',
          ),
        );
      }
    }

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

    await _persistCache();
    debugPrint('[CallerId] Index built: ${_lookupIndex.length} numbers');
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

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{};
      _lookupIndex.forEach((number, info) {
        map[number] = info.toJson();
      });
      await prefs.setString(_prefCacheKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[CallerId] persistCache error: $e');
    }
  }

  /// 외부에서 호출하는 동기화 헬퍼.
  /// 명함이 추가/수정/삭제된 직후 호출하여 인덱스 + 캐시를 최신화합니다.
  Future<void> syncCardsFromList(List<CollectedCard> cards,
      {List<CrmContact>? crmContacts}) async {
    await buildIndex(collectedCards: cards, crmContacts: crmContacts);
  }

  /// 전화번호로 명함 정보를 조회합니다. (앱이 살아있을 때 사용)
  CallerInfo? lookupNumber(String incomingNumber) {
    final normalized = normalizePhone(incomingNumber);
    if (_lookupIndex.containsKey(normalized)) {
      return _lookupIndex[normalized];
    }
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

  // -------------------- 권한 요청 --------------------

  /// 필요한 모든 권한이 부여되었는지 확인합니다.
  /// (READ_PHONE_STATE + READ_CALL_LOG + SYSTEM_ALERT_WINDOW)
  Future<bool> hasRequiredPermissions() async {
    final phoneGranted = await Permission.phone.isGranted;
    final callLogGranted = await _isCallLogGranted();
    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    return phoneGranted && callLogGranted && overlayGranted;
  }

  /// 전화 상태 / 통화 기록 / 오버레이 권한을 요청합니다.
  Future<bool> requestRequiredPermissions() async {
    var phoneStatus = await Permission.phone.status;
    if (!phoneStatus.isGranted) {
      phoneStatus = await Permission.phone.request();
    }
    if (!phoneStatus.isGranted) {
      debugPrint('[CallerId] READ_PHONE_STATE denied: $phoneStatus');
      return false;
    }

    var callLogGranted = await _isCallLogGranted();
    if (!callLogGranted) {
      callLogGranted = await _requestCallLog();
    }
    if (!callLogGranted) {
      debugPrint('[CallerId] READ_CALL_LOG denied');
      return false;
    }

    final overlayGranted = await FlutterOverlayWindow.isPermissionGranted();
    if (!overlayGranted) {
      final requested = await FlutterOverlayWindow.requestPermission();
      if (requested != true) {
        debugPrint('[CallerId] Overlay permission denied');
        return false;
      }
    }
    return true;
  }

  // -------------------- 전화 상태 리스너 --------------------
  //
  // 네이티브 BroadcastReceiver(CallReceiver) 가 앱 종료 상태를 포함한 모든
  // 시나리오에서 PHONE_STATE 를 처리하므로, Flutter 측 phone_state 스트림은
  // 더 이상 사용하지 않습니다. 단, 권한 체크/로그 일관성을 위해 startListening
  // 진입점은 그대로 유지합니다 (실제 native 측에서 동작 검증).

  Future<void> startListening() async {
    if (_isListening) return;

    final enabled = await isEnabled;
    if (!enabled) return;

    final phoneGranted = await Permission.phone.isGranted;
    final callLogGranted = await _isCallLogGranted();
    if (!phoneGranted || !callLogGranted) {
      debugPrint(
        '[CallerId] permissions missing — phone:$phoneGranted callLog:$callLogGranted',
      );
      return;
    }

    final hasOverlayPermission =
    await FlutterOverlayWindow.isPermissionGranted();
    if (!hasOverlayPermission) {
      debugPrint('[CallerId] Overlay permission not granted');
      return;
    }

    _isListening = true;
    debugPrint('[CallerId] Active (native receiver handles incoming calls)');
  }

  // ignore: unused_element
  void _onPhoneEvent(PhoneState event) {
    debugPrint('[CallerId] (legacy) event status=${event.status}');
    if (event.status == PhoneStateStatus.CALL_INCOMING) {
      final number = event.number;
      if (number == null || number.isEmpty) return;
      final info = lookupNumber(number);
      if (info != null) {
        _currentCaller = info;
        _showOverlay(info, OverlayMode.banner);
      }
    } else if (event.status == PhoneStateStatus.CALL_STARTED) {
      if (_currentCaller != null) {
        _showOverlay(_currentCaller!, OverlayMode.detail);
      }
    } else if (event.status == PhoneStateStatus.CALL_ENDED) {
      _hideOverlay();
      _currentCaller = null;
    }
  }

  void stopListening() {
    _phoneStateSubscription?.cancel();
    _phoneStateSubscription = null;
    _isListening = false;
    debugPrint('[CallerId] Listening stopped');
  }

  // -------------------- 오버레이 --------------------

  Future<void> _showOverlay(CallerInfo info, OverlayMode mode) async {
    try {
      // 기존 오버레이가 있다면 닫고 다시 띄움 (사이즈 변경 위해)
      if (_overlayVisible) {
        await FlutterOverlayWindow.closeOverlay();
        _overlayVisible = false;
      }

      final isDetail = mode == OverlayMode.detail;
      await FlutterOverlayWindow.showOverlay(
        height: isDetail ? 360 : 110,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        overlayTitle: 'Mapae Caller ID',
      );
      _overlayVisible = true;

      // 오버레이 isolate 가 listener 를 등록할 시간을 잠깐 줍니다.
      await Future.delayed(const Duration(milliseconds: 250));

      await FlutterOverlayWindow.shareData({
        'mode': isDetail ? 'detail' : 'banner',
        'name': info.name,
        'company': info.company ?? '',
        'position': info.position ?? '',
        'department': info.department ?? '',
        'email': info.email ?? '',
        'imageUrl': info.imageUrl ?? '',
        'memo': info.memo ?? '',
        'source': info.source,
      });
      debugPrint('[CallerId] overlay shown mode=${mode.name} name=${info.name}');
    } catch (e) {
      debugPrint('[CallerId] Overlay error: $e');
    }
  }

  Future<void> _hideOverlay() async {
    try {
      if (_overlayVisible) {
        await FlutterOverlayWindow.closeOverlay();
        _overlayVisible = false;
        debugPrint('[CallerId] overlay closed');
      }
    } catch (e) {
      debugPrint('[CallerId] Hide overlay error: $e');
    }
  }
}

enum OverlayMode { banner, detail }