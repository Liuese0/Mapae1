import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/shared/models/collected_card.dart';

/// 사용자가 명함 저장 후 'Yes' 를 누르면 휴대폰 네이티브 연락처에 insert 한다.
/// 카드 ID 단위로 다이얼로그를 한 번만 노출하기 위한 추적 API 도 함께 제공한다.
class DeviceContactsService {
  static const _seenKey = 'contacts_offered_card_ids';

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

  /// 휴대폰 연락처에 명함 정보를 직접 insert 한다.
  /// 계정은 기기에 등록된 계정 중 Google → 그 외 → 로컬 순으로 자동 선택한다.
  /// (account 지정 없이 insert 하면 로컬 "Phone storage" 로 저장돼 대부분의
  /// 연락처 앱에서 숨겨지는 문제 회피.)
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

      // Android: insert 시 account 를 지정하지 않으면 ContentProvider 가
      // 연락처를 "Phone storage" (로컬 계정) 으로 저장하는데, Google Contacts /
      // 삼성 연락처 등 대부분의 앱은 기본적으로 이 로컬 계정을 숨긴다.
      // 결과적으로 insert 는 성공해도 사용자 눈에는 보이지 않는다.
      // 동기화 가능한 계정(Google 우선) 을 골라 명시적으로 지정해 해결한다.
      //
      // flutter_contacts 1.1.x 에는 공개 getAccounts() API 가 없어서 기존
      // 연락처를 1건 정도 조회해 거기서 account 를 추출한다 (속성/사진은
      // 모두 false 로 가벼운 조회).
      try {
        final existing = await FlutterContacts.getContacts(
          withProperties: false,
          withPhoto: false,
          withThumbnail: false,
          withAccounts: true,
        );
        final accountSet = <String, Account>{};
        for (final c in existing) {
          for (final a in c.accounts) {
            accountSet['${a.type}/${a.name}'] = a;
          }
        }
        final accounts = accountSet.values.toList();
        debugPrint('[DeviceContacts] available accounts: '
            '${accounts.map((a) => '${a.type}/${a.name}').toList()}');
        if (accounts.isNotEmpty) {
          final preferred = accounts.firstWhere(
            (a) => a.type == 'com.google',
            orElse: () => accounts.firstWhere(
              (a) => a.type != 'vnd.sec.contact.phone' &&
                  a.type != 'com.android.contacts.local',
              orElse: () => accounts.first,
            ),
          );
          contact.accounts = [preferred];
          debugPrint('[DeviceContacts] using account: '
              '${preferred.type}/${preferred.name}');
        } else {
          debugPrint('[DeviceContacts] no accounts found, '
              'will fall back to local phone storage');
        }
      } catch (e) {
        debugPrint('[DeviceContacts] account lookup failed: $e');
      }

      debugPrint('[DeviceContacts] inserting contact: '
          'phones=${contact.phones.length} emails=${contact.emails.length} '
          'addrs=${contact.addresses.length} '
          'orgs=${contact.organizations.length}');
      final inserted = await FlutterContacts.insertContact(contact);
      debugPrint('[DeviceContacts] inserted id=${inserted.id} '
          'displayName=${inserted.displayName} '
          'accounts=${inserted.accounts.map((a) => '${a.type}/${a.name}').toList()}');
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