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

  /// 네이티브 연락처 앱의 "새 연락처" 화면을 미리 채워서 띄운다.
  ///
  /// 직접 insert 를 호출하면 일부 OEM(삼성 등) 에서 계정 미지정 시 보이지 않는
  /// "기기 전용" 계정으로 들어가 사용자가 못 찾는 문제가 있다.
  /// 시스템 UI 를 띄우면 사용자가 계정을 선택해 본인이 보이는 곳에 저장하게 되어 가장 확실하다.
  ///
  /// 반환: 성공적으로 시스템 UI 를 띄웠으면 null, 실패 시 에러 문자열.
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

      debugPrint('[DeviceContacts] launching system insert UI '
          'phones=${contact.phones.length} emails=${contact.emails.length} '
          'addrs=${contact.addresses.length}');
      await FlutterContacts.openExternalInsert(contact);
      debugPrint('[DeviceContacts] system insert UI closed');
      return null;
    } catch (e, st) {
      debugPrint('[DeviceContacts] openExternalInsert failed: $e\n$st');
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
