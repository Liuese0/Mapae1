import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shared/models/collected_card.dart';

/// 사용자가 명함 저장 후 'Yes' 를 누르면 휴대폰 네이티브 연락처에 insert 한다.
/// 카드 ID 단위로 다이얼로그를 한 번만 노출하기 위한 추적 API 도 함께 제공한다.
class DeviceContactsService {
  static const _seenKey = 'contacts_offered_card_ids';
  static const _nativeChannel =
      MethodChannel('com.namecard.mapae/permissions');

  Future<bool> hasBeenOffered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_seenKey) ?? const []).contains(id);
  }

  Future<void> markOffered(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_seenKey) ?? <String>[];
    if (list.contains(id)) return;
    await prefs.setStringList(_seenKey, [...list, id]);
  }

  /// flutter_contacts 자체 권한 API 를 사용한다.
  /// permission_handler 의 `Permission.contacts` 는 Android 에서 READ 만
  /// 보장되는 경우가 있어 WRITE 가 빠져 insert 가 silent fail 한다.
  Future<bool> requestPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: false);
    } catch (e) {
      debugPrint('[DeviceContacts] requestPermission failed: $e');
      return false;
    }
  }

  /// 기존 연락처가 사용 중인 (계정 타입, 계정 이름) 목록.
  /// Samsung 등에서 명시적 계정 없이 insert 하면 보이지 않는 "기기 전용" 계정으로
  /// 들어가는 문제를 회피하기 위해 사용한다.
  Future<List<Map<String, String>>> getContactAccounts() async {
    try {
      final raw = await _nativeChannel
          .invokeMethod<List<dynamic>>('getContactAccounts');
      if (raw == null) return const [];
      return raw
          .map((e) => Map<String, String>.from(e as Map))
          .toList(growable: false);
    } catch (e) {
      debugPrint('[DeviceContacts] getContactAccounts failed: $e');
      return const [];
    }
  }

  /// 휴대폰 연락처에 명함 정보를 직접 insert 한다. (시스템 UI 안 띄움)
  ///
  /// 계정 선택 로직 — 보이는 계정에 저장되도록:
  ///   1) Google (`com.google`) 계정이 있으면 첫 번째 사용
  ///   2) 없으면 Samsung (`com.osp.app.signin`) 등 비-기기 계정 사용
  ///   3) 그래도 없으면 기기 기본 계정 (null) — 첫 명함 저장 시 가끔 발생
  ///
  /// [extraNotes] 는 ContextTag 의 비표준 커스텀 필드를 "필드명: 값\n…" 으로
  /// 직렬화한 문자열. CollectedCard.memo 와 합쳐서 하나의 Note 로 저장한다.
  ///
  /// 반환: 성공 시 null, 실패 시 에러 문자열.
  Future<String?> saveToDeviceContacts(
      CollectedCard card, {
        String extraNotes = '',
      }) async {
    debugPrint('[DeviceContacts] saveToDeviceContacts start name=${card.name}');
    try {
      final mergedNote = [
        if ((card.memo ?? '').trim().isNotEmpty) card.memo!.trim(),
        if (extraNotes.trim().isNotEmpty) extraNotes.trim(),
      ].join('\n');

      final hasAnyContent = (card.name ?? '').isNotEmpty ||
          (card.mobile ?? '').isNotEmpty ||
          (card.phone ?? '').isNotEmpty ||
          (card.fax ?? '').isNotEmpty ||
          (card.email ?? '').isNotEmpty ||
          (card.address ?? '').isNotEmpty ||
          (card.website ?? '').isNotEmpty ||
          (card.company ?? '').isNotEmpty ||
          (card.position ?? '').isNotEmpty ||
          (card.department ?? '').isNotEmpty ||
          mergedNote.isNotEmpty;
      if (!hasAnyContent) {
        debugPrint('[DeviceContacts] empty card, abort');
        return 'empty card';
      }

      final contact = Contact()
        ..name.first = card.name ?? ''
        ..phones = [
          if ((card.mobile ?? '').isNotEmpty)
            Phone(card.mobile!, label: PhoneLabel.mobile),
          if ((card.phone ?? '').isNotEmpty)
            Phone(card.phone!, label: PhoneLabel.work),
          if ((card.fax ?? '').isNotEmpty)
            Phone(card.fax!, label: PhoneLabel.faxWork),
        ]
        ..emails = [
          if ((card.email ?? '').isNotEmpty)
            Email(card.email!, label: EmailLabel.work),
        ]
        ..addresses = [
          if ((card.address ?? '').isNotEmpty)
            Address(card.address!, label: AddressLabel.work),
        ]
        ..websites = [
          if ((card.website ?? '').isNotEmpty)
            Website(card.website!, label: WebsiteLabel.work),
        ]
        ..organizations = [
          if ((card.company ?? '').isNotEmpty ||
              (card.position ?? '').isNotEmpty ||
              (card.department ?? '').isNotEmpty)
            Organization(
              company: card.company ?? '',
              title: card.position ?? '',
              department: card.department ?? '',
            ),
        ]
        ..notes = [
          if (mergedNote.isNotEmpty) Note(mergedNote),
        ];

      // 계정 선택 — Google > 비-기기 계정 > 기본 순.
      final accounts = await getContactAccounts();
      debugPrint('[DeviceContacts] available accounts: $accounts');
      Map<String, String>? picked;
      for (final a in accounts) {
        if ((a['type'] ?? '').startsWith('com.google')) {
          picked = a;
          break;
        }
      }
      if (picked == null) {
        for (final a in accounts) {
          final t = a['type'] ?? '';
          if (t.isNotEmpty &&
              t != 'vnd.sec.contact.phone' /* Samsung 기기 전용 */ &&
              t != 'vnd.huawei.account' /* Huawei 비슷한 케이스 */ &&
              !t.contains('.phone')) {
            picked = a;
            break;
          }
        }
      }
      picked ??= accounts.isNotEmpty ? accounts.first : null;

      if (picked != null) {
        debugPrint('[DeviceContacts] using account: '
            '${picked['type']}/${picked['name']}');
        contact.accounts = [Account(picked['name']!, picked['type']!)];
      } else {
        debugPrint('[DeviceContacts] no account found, inserting with default');
      }

      debugPrint('[DeviceContacts] inserting contact: '
          'phones=${contact.phones.length} emails=${contact.emails.length} '
          'addrs=${contact.addresses.length} '
          'orgs=${contact.organizations.length}');
      final inserted = await FlutterContacts.insertContact(contact);
      debugPrint('[DeviceContacts] inserted id=${inserted.id} '
          'displayName=${inserted.displayName}');
      return null;
    } catch (e, st) {
      debugPrint('[DeviceContacts] insert failed: $e\n$st');
      return e.toString();
    }
  }
}

/// `card_edit_screen.dart:17` 의 `_cardFieldMap` 과 동일한 표준 필드명 집합.
/// 이 이름들로 들어오는 ContextTag 값은 CollectedCard 에 이미 매핑되어 있으므로
/// 메모(Note) 에 다시 적지 않는다.
const standardCardFieldNames = <String>{
  '이름', '회사명', '회사', '직급', '직함', '부서', '이메일',
  '전화번호', '전화', '휴대폰', '핸드폰', '팩스', '주소',
  '웹사이트', '홈페이지', '메모',
};

final deviceContactsServiceProvider =
Provider<DeviceContactsService>((_) => DeviceContactsService());
