import 'package:flutter/material.dart';
import '../../shared/models/crm_contact.dart';
import '../../../l10n/generated/app_localizations.dart';

/// CRM 상태별 색상
Color crmStatusColor(CrmStatus status) {
  switch (status) {
    case CrmStatus.lead:
      return Colors.grey;
    case CrmStatus.contact:
      return Colors.blue;
    case CrmStatus.meeting:
      return Colors.orange;
    case CrmStatus.proposal:
      return Colors.purple;
    case CrmStatus.contract:
      return Colors.teal;
    case CrmStatus.closed:
      return Colors.green;
  }
}

/// CRM 상태별 아이콘
IconData crmStatusIcon(CrmStatus status) {
  switch (status) {
    case CrmStatus.lead:
      return Icons.person_search_outlined;
    case CrmStatus.contact:
      return Icons.phone_outlined;
    case CrmStatus.meeting:
      return Icons.handshake_outlined;
    case CrmStatus.proposal:
      return Icons.description_outlined;
    case CrmStatus.contract:
      return Icons.assignment_outlined;
    case CrmStatus.closed:
      return Icons.check_circle_outlined;
  }
}

/// CRM 파이프라인 상태를 현재 언어로 반환합니다.
String crmStatusLabel(CrmStatus s, AppLocalizations l10n) {
  switch (s) {
    case CrmStatus.lead:     return l10n.crmStatusLead;
    case CrmStatus.contact:  return l10n.crmStatusContact;
    case CrmStatus.meeting:  return l10n.crmStatusMeeting;
    case CrmStatus.proposal: return l10n.crmStatusProposal;
    case CrmStatus.contract: return l10n.crmStatusContract;
    case CrmStatus.closed:   return l10n.crmStatusClosed;
  }
}

/// CRM 정렬 모드
enum CrmSortMode { recent, name, status }