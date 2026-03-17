// Hand-written localizations implementation.
// Based on app_ko.arb and app_en.arb.

import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

abstract class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
  _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
  ];

  // ── Common ──
  String get appTitle;
  String get cancel;
  String get save;
  String get confirm;
  String get edit;
  String get delete;
  String get orDivider;
  String get add;
  String get manage;
  String get create;
  String get share;
  String get join;
  String get leave;
  String get copy;
  String get remove;
  String get close;
  String get noName;
  String get saved;
  String get required;
  String get inputForm;
  String get defaultForm;
  String errorMsg(String e);
  String get cardNotFound;
  String saveFailed(String e);

  // ── Navigation ──
  String get home;
  String get wallet;
  String get management;

  // ── Auth ──
  String get login;
  String get signUp;
  String get loginWithGoogle;
  String get loginWithKakao;
  String get signUpWithGoogle;
  String get email;
  String get password;
  String get name;
  String get confirmPassword;
  String get forgotPassword;
  String get logout;
  String get logoutConfirm;
  String get profile;
  String get autoLogin;
  String get noAccount;
  String get enterEmail;
  String get enterValidEmail;
  String get enterPassword;
  String get enterName;
  String get passwordTooShort;
  String get passwordMismatch;
  String get signUpComplete;
  String get startCardManagement;
  String get nameTooLong;
  String get passwordWeak;
  String get passwordMedium;
  String get passwordStrong;

  // ── Profile ──
  String get personalInfo;
  String get enterNameHint;
  String get nameChanged;
  String get deleteAccount;
  String get deleteAccountWarning;
  String get incorrectPassword;
  String get withdraw;
  String get setPasswordTitle;
  String get setPasswordDescription;
  String get setPasswordHint;
  String get confirmPasswordHint;
  String get passwordSet;

  // ── Cards ──
  String get cardDetail;
  String get addCard;
  String get editCard;
  String get addCardImage;
  String get takePhoto;
  String get chooseFromGallery;
  String get scanningCard;
  String get scanningText;
  String scanTextFailed(String e);
  String get scanComplete;
  String get scanFailed;
  String get shareCard;
  String get shareViaSns;
  String get cardShared;
  String get noCards;
  String get noMyCards;
  String get swipeToSeeMore;
  String get openCard;
  String get sortByDate;
  String get sortByName;
  String totalCards(int count);
  String cardSharedTeamWarning(int count);

  // ── Card fields ──
  String get companyName;
  String get position;
  String get department;
  String get phoneNumber;
  String get mobileNumber;
  String get faxNumber;
  String get address;
  String get website;
  String get memo;

  // ── Categories ──
  String get category;
  String get allCategories;
  String get addCategory;
  String get categoryName;
  String get noCategories;
  String get categoryManagement;
  String get addCategoryTitle;
  String get assignCategory;
  String get categorySelectOptional;
  String get shareWithoutCategory;
  String get deleteCategoryTitle;
  String deleteCategoryConfirm(String name);
  String get createTeamCategory;
  String categoryAdded(String name);
  String get categoryDeleted;
  String categoryDeleteFailed(String e);
  String categoryAssignFailed(String e);
  String categoryCreateFailed(String e);

  // ── My Cards ──
  String get myCards;
  String get addMyCard;
  String get editMyCard;
  String get addMyCardHint;

  // ── Teams ──
  String get team;
  String get teamManagement;
  String get createTeam;
  String get joinTeam;
  String get teamName;
  String get teamMembers;
  String get sharedCards;
  String get shareToTeam;
  String get crmIntegration;
  String get noTeams;
  String get deleteTeam;
  String get deleteTeamConfirm;
  String get leaveTeam;
  String get leaveTeamConfirm;
  String get teamShareCodeHint;
  String get shareCodePlaceholder;
  String joinedTeam(String name);
  String get joinFailed;
  String get alreadyMember;
  String get invalidShareCode;
  String get noCardsInCategory;
  String get noSharedCards;
  String get shareCardAction;
  String get unshareTitle;
  String unshareConfirm(String name);
  String get unshareSuccess;
  String unshareFailed(String e);
  String get copyToWalletSuccess;
  String copyFailed(String e);
  String get duplicateCard;
  String get duplicateCardConfirm;
  String get selectCardToShare;
  String get noCardsInWallet;
  String get alreadyShared;
  String get teamSharedSuccess;
  String shareFailed(String e);

  // ── Tags ──
  String get contextTag;
  String get addContextTag;
  String get tagTemplate;
  String get createTagTemplate;
  String get templateName;
  String get addField;
  String get fieldName;
  String get fieldType;
  String get textField;
  String get dateField;
  String get selectField;
  String get metLocation;
  String get metDate;
  String get notes;
  String get noTagTemplates;
  String get tagTemplateHint;
  String get createTemplate;
  String get contextTagTemplate;
  String get tagTemplateDescription;

  // ── Quick actions ──
  String get call;
  String get sendMessage;
  String get sendEmail;
  String get openSns;
  String incomingCallFrom(String name);

  // ── Settings ──
  String get settings;
  String get language;
  String get darkMode;
  String get notifications;
  String get version;
  String get korean;
  String get english;

  // ── Premium ──
  String get removeAds;
  String get applied;
  String get premiumTitle;
  String get premiumDescription;
  String get removeAdsCompletely;
  String get oneTimePurchase;
  String get restoreOnDevices;
  String get purchaseButton;
  String get restorePurchase;
  String get noPurchaseToRestore;

  // ── Delete confirmation ──
  String get deleteConfirmTitle;
  String get deleteConfirmMessage;

  // ── Invite Member ──
  String get inviteMember;
  String get inviteMemberHint;
  String get emailAddressHint;
  String get cannotInviteSelf;
  String get alreadyTeamMember;
  String get searchError;
  String get alreadyInvited;
  String inviteSent(String name);
  String get inviteError;
  String get noSearchResults;
  String get invite;
  String get inviteConfirmTitle;
  String inviteConfirmMessage(String name);

  // ── Share / QuickShare ──
  String get shareViaSnsSubtitle;
  String get quickShare;
  String get quickShareSubtitle;
  String get startExchange;
  String get done;
  String get scanning;
  String get quickShareScanningDesc;
  String get quickShareDiscoveredDesc;
  String get quickShareExchangingDesc;
  String get quickShareCompletedDesc;
  String nearbyUsers(int count);
  String exchangeCompleted(String name);
  String get exchangeTimeout;
  String get exchangeInProgress;
  String get cardExchangeComplete;
  String get myCard;
  String get opponent;
  String get shareCardContent;
  String shareCardTitle(String name);

  // ── Scan Card ──
  String get scanCard;
  String get scanCardSubtitle;
  String get processingCard;
  String get recognizingText;
  String get savingInfo;
  String get cardAdded;
  String recognitionFailed(String e);
  String get loginRequired;

  // ── Team Members / Roles ──
  String get promoteMember;
  String get demoteToObserver;
  String get transferOwnership;
  String get kickFromTeam;
  String get kick;
  String get kickMemberTitle;
  String get thisMember;
  String kickMemberConfirm(String name);
  String transferOwnershipContent(String name);
  String get transferProceed;
  String get finalConfirm;
  String finalTransferConfirm(String name);
  String get transferSuccess;
  String transferFailed(String e);
  String get finalTransferBtn;
  String get roleOwner;
  String get roleMember;
  String get roleObserver;
  String changeFailed(String e);
  String get shareCodeRegenerated;
  String regenFailed(String e);

  // ── CRM ──
  String get noPermissionObserver;
  String loadFailed(String e);
  String get searchHint;
  String get pipelineView;
  String get noContacts;
  String get addContactHint;
  String get importFromSharedCards;
  String get addManually;
  String get pipeline;
  String totalPeople(int count);
  String get crmSetupRequired;
  String get crmSetupInstruction;
  String get retry;
  String get addCrmContact;
  String get company;
  String get jobTitle;
  String importedContacts(int count);
  String get importAll;
  String get noNewCards;
  String contactAddedFromCard(String name);
  String get contactAdded;
  String get contactInfo;
  String get noInfo;
  String get editInfo;
  String get activityNotes;
  String noteCount(int count);
  String get noteHint;
  String get noNotes;
  String get unknown;
  String get justNow;
  String minutesAgo(int n);
  String hoursAgo(int n);
  String daysAgo(int n);
  String get deleteContact;
  String get thisContact;
  String deleteContactConfirm(String name);
  String get status;
  String get phone;
  String get crmContact;

  // ── Share Code ──
  String get teamShareCode;
  String get shareCodeEnabledHint;
  String get shareCodeDisabled;
  String get codeGenerating;
  String get shareCodeCopied;
  String get regenerateCode;
  String get shareCodeObserverNote;

  // ── Notifications ──
  String get noNotifications;
  String get teamInvitation;
  String inviteAccepted(String teamName);
  String get declineInvite;
  String declineInviteConfirm(String teamName);
  String get decline;
  String get inviteDeclined;
  String get accept;
  String inviterDescription(String inviterName, String teamName);

  // ── Shared Card Receive ──
  String get expiredShareLink;
  String get cannotLoadCard;
  String get saveToWallet;
  String get goBack;

  // ── Search / Category ──
  String get selectCategory;
  String get noCategoriesHint;
  String get searchCardHint;

  // ── CRM Pipeline Status ──
  String get crmStatusLead;
  String get crmStatusContact;
  String get crmStatusMeeting;
  String get crmStatusProposal;
  String get crmStatusContract;
  String get crmStatusClosed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ko', 'en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    if (locale.languageCode == 'en') return AppLocalizationsEn(locale);
    if (locale.languageCode == 'zh') return AppLocalizationsZh(locale);
    return AppLocalizationsKo(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ──────────────── Korean ────────────────

class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo(super.locale);

  @override String get appTitle => 'Mapae';
  @override String get cancel => '취소';
  @override String get save => '저장';
  @override String get confirm => '확인';
  @override String get edit => '수정';
  @override String get delete => '삭제';
  @override String get orDivider => '또는';
  @override String get add => '추가';
  @override String get manage => '관리';
  @override String get create => '만들기';
  @override String get share => '공유';
  @override String get join => '참가';
  @override String get leave => '나가기';
  @override String get copy => '복사';
  @override String get remove => '제거';
  @override String get close => '닫기';
  @override String get noName => '이름 없음';
  @override String get saved => '저장되었습니다';
  @override String get required => '필수 입력';
  @override String get inputForm => '입력 양식';
  @override String get defaultForm => '기본 양식';
  @override String errorMsg(String e) => '오류: $e';
  @override String get cardNotFound => '명함을 찾을 수 없습니다';
  @override String saveFailed(String e) => '저장 실패: $e';

  @override String get home => '홈';
  @override String get wallet => '지갑';
  @override String get management => '관리';

  @override String get login => '로그인';
  @override String get signUp => '회원가입';
  @override String get loginWithGoogle => 'Google로 로그인';
  @override String get loginWithKakao => '카카오로 로그인';
  @override String get signUpWithGoogle => 'Google로 가입';
  @override String get email => '이메일';
  @override String get password => '비밀번호';
  @override String get name => '이름';
  @override String get confirmPassword => '비밀번호 확인';
  @override String get forgotPassword => '비밀번호 찾기';
  @override String get logout => '로그아웃';
  @override String get logoutConfirm => '로그아웃 하시겠습니까?';
  @override String get profile => '프로필';
  @override String get autoLogin => '자동 로그인';
  @override String get noAccount => '계정이 없으신가요?';
  @override String get enterEmail => '이메일을 입력해주세요';
  @override String get enterValidEmail => '올바른 이메일을 입력해주세요';
  @override String get enterPassword => '비밀번호를 입력해주세요';
  @override String get enterName => '이름을 입력해주세요';
  @override String get passwordTooShort => '비밀번호는 6자 이상이어야 합니다';
  @override String get passwordMismatch => '비밀번호가 일치하지 않습니다';
  @override String get signUpComplete => '회원가입이 완료되었습니다. 이메일을 확인해주세요.';
  @override String get startCardManagement => '명함 관리를 시작하세요';
  @override String get nameTooLong => '이름이 너무 깁니다';
  @override String get passwordWeak => '약함';
  @override String get passwordMedium => '보통';
  @override String get passwordStrong => '강함';

  @override String get personalInfo => '개인정보';
  @override String get enterNameHint => '이름을 입력하세요';
  @override String get nameChanged => '이름이 변경되었습니다.';
  @override String get deleteAccount => '계정 탈퇴';
  @override String get deleteAccountWarning => '모든 데이터가 삭제되며 복구할 수 없습니다.\n본인 확인을 위해 비밀번호를 입력해주세요.';
  @override String get incorrectPassword => '비밀번호가 올바르지 않습니다';
  @override String get withdraw => '탈퇴';
  @override String get setPasswordTitle => '비밀번호 설정';
  @override String get setPasswordDescription => '계정 보안을 위해 비밀번호를 설정해주세요.\n나중에 이메일로도 로그인할 수 있습니다.';
  @override String get setPasswordHint => '비밀번호 (6자 이상)';
  @override String get confirmPasswordHint => '비밀번호 확인';
  @override String get passwordSet => '비밀번호가 설정되었습니다.';

  @override String get cardDetail => '명함 상세';
  @override String get addCard => '명함 추가';
  @override String get editCard => '명함 수정';
  @override String get addCardImage => '명함 이미지 추가';
  @override String get takePhoto => '사진 촬영';
  @override String get chooseFromGallery => '갤러리에서 선택';
  @override String get scanningCard => '명함 인식 중...';
  @override String get scanningText => '명함 텍스트 인식 중...';
  @override String scanTextFailed(String e) => '텍스트 인식 실패: $e';
  @override String get scanComplete => '인식 완료';
  @override String get scanFailed => '인식 실패. 다시 시도해주세요.';
  @override String get shareCard => '명함 공유';
  @override String get shareViaSns => 'SNS로 공유';
  @override String get cardShared => '명함이 공유되었습니다.';
  @override String get noCards => '명함이 없습니다.';
  @override String get noMyCards => '등록된 내 명함이 없습니다.';
  @override String get swipeToSeeMore => '좌우로 스와이프하여 다른 명함을 확인하세요';
  @override String get openCard => '명함 보기';
  @override String get sortByDate => '등록순';
  @override String get sortByName => '이름순';
  @override String totalCards(int count) => '전체 명함 $count장';
  @override String cardSharedTeamWarning(int count) =>
      '이 명함은 ${count}개 팀에 공유되어 있습니다.\n개인 지갑에서만 삭제되며, 팀 공유 명함은 유지됩니다.';

  @override String get companyName => '회사명';
  @override String get position => '직급';
  @override String get department => '부서';
  @override String get phoneNumber => '전화번호';
  @override String get mobileNumber => '휴대폰';
  @override String get faxNumber => '팩스';
  @override String get address => '주소';
  @override String get website => '웹사이트';
  @override String get memo => '메모';

  @override String get category => '카테고리';
  @override String get allCategories => '전체';
  @override String get addCategory => '카테고리 추가';
  @override String get categoryName => '카테고리 이름';
  @override String get noCategories => '카테고리가 없습니다';
  @override String get categoryManagement => '카테고리 관리';
  @override String get addCategoryTitle => '팀 카테고리 추가';
  @override String get assignCategory => '카테고리 지정';
  @override String get categorySelectOptional => '카테고리 선택 (선택사항)';
  @override String get shareWithoutCategory => '카테고리 없이 공유';
  @override String get deleteCategoryTitle => '카테고리 삭제';
  @override String deleteCategoryConfirm(String name) =>
      '\'$name\' 카테고리를 삭제하시겠습니까?\n해당 카테고리가 지정된 명함은 카테고리 없음으로 변경됩니다.';
  @override String get createTeamCategory => '팀 카테고리 만들기';
  @override String categoryAdded(String name) => '\'$name\' 카테고리가 추가되었습니다';
  @override String get categoryDeleted => '카테고리가 삭제되었습니다';
  @override String categoryDeleteFailed(String e) => '카테고리 삭제 실패: $e';
  @override String categoryAssignFailed(String e) => '카테고리 지정 실패: $e';
  @override String categoryCreateFailed(String e) => '카테고리 생성 실패: $e';

  @override String get myCards => '내 명함';
  @override String get addMyCard => '내 명함 추가';
  @override String get editMyCard => '내 명함 수정';
  @override String get addMyCardHint => '관리 탭에서 내 명함을 추가해보세요';

  @override String get team => '팀';
  @override String get teamManagement => '팀 관리';
  @override String get createTeam => '팀 만들기';
  @override String get joinTeam => '팀 참여';
  @override String get teamName => '팀 이름';
  @override String get teamMembers => '팀 멤버';
  @override String get sharedCards => '공유된 명함';
  @override String get shareToTeam => '팀에 공유';
  @override String get crmIntegration => 'CRM 연동';
  @override String get noTeams => '소속된 팀이 없습니다';
  @override String get deleteTeam => '팀 삭제';
  @override String get deleteTeamConfirm => '팀을 삭제하면 모든 멤버와 공유 명함이 삭제됩니다.\n정말 삭제하시겠습니까?';
  @override String get leaveTeam => '팀 나가기';
  @override String get leaveTeamConfirm => '팀에서 나가시겠습니까?';
  @override String get teamShareCodeHint => '팀 공유코드를 입력하면 팀에 Observer로 참가합니다.';
  @override String get shareCodePlaceholder => '공유코드 8자리';
  @override String joinedTeam(String name) => '\'$name\'에 Observer로 참가했습니다';
  @override String get joinFailed => '참가 실패: 올바른 공유코드를 입력해주세요';
  @override String get alreadyMember => '이미 해당 팀의 멤버입니다';
  @override String get invalidShareCode => '유효하지 않거나 비활성화된 공유코드입니다';
  @override String get noCardsInCategory => '이 카테고리에 명함이 없습니다';
  @override String get noSharedCards => '공유된 명함이 없습니다';
  @override String get shareCardAction => '명함 공유하기';
  @override String get unshareTitle => '공유 해제';
  @override String unshareConfirm(String name) =>
      '\'$name\' 명함을 팀 공유에서 제거하시겠습니까?\n개인 지갑의 명함은 유지됩니다.';
  @override String get unshareSuccess => '공유가 해제되었습니다';
  @override String unshareFailed(String e) => '공유 해제 실패: $e';
  @override String get copyToWalletSuccess => '명함이 지갑에 복사되었습니다';
  @override String copyFailed(String e) => '복사 실패: $e';
  @override String get duplicateCard => '중복 명함';
  @override String get duplicateCardConfirm => '이미 존재하는 명함입니다. 복사하시겠습니까?';
  @override String get selectCardToShare => '공유할 명함 선택';
  @override String get noCardsInWallet => '지갑에 명함이 없습니다';
  @override String get alreadyShared => '이미 공유한 명함입니다';
  @override String get teamSharedSuccess => '명함이 팀에 공유되었습니다';
  @override String shareFailed(String e) => '공유 실패: $e';

  @override String get contextTag => '상황 태그';
  @override String get addContextTag => '태그 추가';
  @override String get tagTemplate => '태그 템플릿';
  @override String get createTagTemplate => '태그 템플릿 만들기';
  @override String get templateName => '템플릿 이름';
  @override String get addField => '필드 추가';
  @override String get fieldName => '필드 이름';
  @override String get fieldType => '필드 유형';
  @override String get textField => '텍스트';
  @override String get dateField => '날짜';
  @override String get selectField => '선택';
  @override String get metLocation => '만난 장소';
  @override String get metDate => '만난 날짜';
  @override String get notes => '특이사항';
  @override String get noTagTemplates => '태그 템플릿이 없습니다';
  @override String get tagTemplateHint => '명함에 만난 상황이나 특이사항을\n기록할 형식을 만들어보세요';
  @override String get createTemplate => '템플릿 만들기';
  @override String get contextTagTemplate => '상황 태그 템플릿';
  @override String get tagTemplateDescription => '명함에 만난 상황, 특이사항 등을 기록할 태그 형식을 관리합니다';

  @override String get call => '전화';
  @override String get sendMessage => '메시지';
  @override String get sendEmail => '이메일 보내기';
  @override String get openSns => 'SNS 열기';
  @override String incomingCallFrom(String name) => '$name님의 전화';

  @override String get settings => '설정';
  @override String get language => '언어';
  @override String get darkMode => '다크 모드';
  @override String get notifications => '알림';
  @override String get version => '버전';
  @override String get korean => '한국어';
  @override String get english => 'English';

  @override String get removeAds => '광고 제거';
  @override String get applied => '적용됨';
  @override String get premiumTitle => '광고 없는 Mapae';
  @override String get premiumDescription => '명함 리스트의 광고를 영구적으로 제거합니다.';
  @override String get removeAdsCompletely => '명함 리스트 광고 완전 제거';
  @override String get oneTimePurchase => '1회 결제 · 평생 적용';
  @override String get restoreOnDevices => '동일 계정 기기 복원 가능';
  @override String get purchaseButton => '₩1,000 · 광고 제거';
  @override String get restorePurchase => '이전 구매 복원';
  @override String get noPurchaseToRestore => '복원할 구매 내역이 없습니다.';

  @override String get deleteConfirmTitle => '명함 삭제';
  @override String get deleteConfirmMessage => '이 명함을 삭제하시겠습니까?';

  // ── Invite Member ──
  @override String get inviteMember => '멤버 초대';
  @override String get inviteMemberHint => '이메일로 유저를 검색하여 초대할 수 있습니다';
  @override String get emailAddressHint => '이메일 주소 입력';
  @override String get cannotInviteSelf => '자기 자신은 초대할 수 없습니다';
  @override String get alreadyTeamMember => '이미 팀에 소속된 멤버입니다';
  @override String get searchError => '검색 중 오류가 발생했습니다';
  @override String get alreadyInvited => '이미 초대를 보낸 유저입니다';
  @override String inviteSent(String name) => '${name}님에게 초대를 보냈습니다';
  @override String get inviteError => '초대 중 오류가 발생했습니다';
  @override String get noSearchResults => '검색 결과가 없습니다';
  @override String get invite => '초대';
  @override String get inviteConfirmTitle => '초대 확인';
  @override String inviteConfirmMessage(String name) => '${name}님을 팀에 초대하시겠습니까?';

  // ── Share / QuickShare ──
  @override String get shareViaSnsSubtitle => '카카오톡, 메시지 등';
  @override String get quickShare => '퀵쉐어';
  @override String get quickShareSubtitle => '실시간으로 퀵쉐어 중인 사용자와 명함을 교환합니다';
  @override String get startExchange => '명함 교환 시작';
  @override String get done => '완료';
  @override String get scanning => '주변 검색 중...';
  @override String get quickShareScanningDesc => '현재 퀵쉐어 화면을 연 사용자만 실시간으로 표시됩니다.';
  @override String get quickShareDiscoveredDesc => '감지된 사용자 중 교환할 대상을 선택하세요.';
  @override String get quickShareExchangingDesc => '서로의 명함을 교환 중입니다.';
  @override String get quickShareCompletedDesc => '양쪽 지갑에 상대 명함이 저장되었습니다.';
  @override String nearbyUsers(int count) => '근처 사용자 ${count}명';
  @override String exchangeCompleted(String name) => '${name}님과 명함 교환이 완료되었습니다.';
  @override String get exchangeTimeout => '응답 시간이 초과되었습니다. 다시 시도해주세요.';
  @override String get exchangeInProgress => '서로의 명함을 교환하는 중...';
  @override String get cardExchangeComplete => '명함 교환 완료';
  @override String get myCard => '내 명함';
  @override String get opponent => '상대';
  @override String get shareCardContent => '📇 Mapae 앱으로 이 명함을 저장하세요:';
  @override String shareCardTitle(String name) => '명함 공유 - $name';

  // ── Scan Card ──
  @override String get scanCard => '명함 스캔';
  @override String get scanCardSubtitle => '카메라로 명함을 스캔하거나 갤러리에서 선택합니다';
  @override String get processingCard => '명함 인식 중...';
  @override String get recognizingText => '문자 인식 중...';
  @override String get savingInfo => '정보 저장 중...';
  @override String get cardAdded => '명함이 추가되었습니다';
  @override String recognitionFailed(String e) => '인식 실패: $e';
  @override String get loginRequired => '로그인이 필요합니다';

  // ── Team Members / Roles ──
  @override String get promoteMember => '멤버로 승격';
  @override String get demoteToObserver => '관측자로 변경';
  @override String get transferOwnership => 'Owner 양도';
  @override String get kickFromTeam => '팀에서 내보내기';
  @override String get kick => '내보내기';
  @override String get kickMemberTitle => '멤버 내보내기';
  @override String get thisMember => '이 멤버';
  @override String kickMemberConfirm(String name) => '${name}를 팀에서 내보내시겠습니까?';
  @override String transferOwnershipContent(String name) =>
      '${name}에게 Owner 권한을 양도하시겠습니까?\n양도 후 본인은 Member로 변경됩니다.';
  @override String get transferProceed => '양도하기';
  @override String get finalConfirm => '최종 확인';
  @override String finalTransferConfirm(String name) =>
      '정말로 ${name}에게 Owner를 양도하시겠습니까?\n이 작업은 되돌릴 수 없습니다.';
  @override String get transferSuccess => 'Owner가 양도되었습니다';
  @override String transferFailed(String e) => '양도 실패: $e';
  @override String get finalTransferBtn => '최종 양도';
  @override String get roleOwner => 'Owner (주인)';
  @override String get roleMember => 'Member (멤버)';
  @override String get roleObserver => 'Observer (관측자)';
  @override String changeFailed(String e) => '변경 실패: $e';
  @override String get shareCodeRegenerated => '공유코드가 재생성되었습니다';
  @override String regenFailed(String e) => '재생성 실패: $e';

  // ── CRM ──
  @override String get noPermissionObserver => '권한이 없습니다. Observer는 CRM을 수정할 수 없습니다';
  @override String loadFailed(String e) => '로드 실패: $e';
  @override String get searchHint => '검색...';
  @override String get pipelineView => '파이프라인 보기';
  @override String get noContacts => 'CRM 연락처가 없습니다';
  @override String get addContactHint => '공유 명함에서 가져오거나 직접 추가하세요';
  @override String get importFromSharedCards => '공유 명함에서 가져오기';
  @override String get addManually => '직접 추가';
  @override String get pipeline => '파이프라인';
  @override String totalPeople(int count) => '총 ${count}명';
  @override String get crmSetupRequired => 'CRM 테이블 설정 필요';
  @override String get crmSetupInstruction => 'Supabase SQL Editor에서\nmigration_crm.sql을 실행해 주세요.';
  @override String get retry => '다시 시도';
  @override String get addCrmContact => 'CRM 연락처 추가';
  @override String get company => '회사';
  @override String get jobTitle => '직책';
  @override String importedContacts(int count) => '${count}개 연락처를 가져왔습니다';
  @override String get importAll => '전체 가져오기';
  @override String get noNewCards => '가져올 수 있는 새로운 명함이 없습니다';
  @override String contactAddedFromCard(String name) => '\'$name\'이(가) CRM에 추가되었습니다';
  @override String get contactAdded => '연락처가 추가되었습니다';
  @override String get contactInfo => '연락처 정보';
  @override String get noInfo => '정보가 없습니다';
  @override String get editInfo => '정보 수정';
  @override String get activityNotes => '활동 노트';
  @override String noteCount(int count) => '${count}개';
  @override String get noteHint => '노트를 입력하세요...';
  @override String get noNotes => '아직 노트가 없습니다';
  @override String get unknown => '알 수 없음';
  @override String get justNow => '방금 전';
  @override String minutesAgo(int n) => '${n}분 전';
  @override String hoursAgo(int n) => '${n}시간 전';
  @override String daysAgo(int n) => '${n}일 전';
  @override String get deleteContact => '연락처 삭제';
  @override String get thisContact => '이 연락처';
  @override String deleteContactConfirm(String name) =>
      '\'$name\'를 삭제하시겠습니까?\n모든 노트도 함께 삭제됩니다.';
  @override String get status => '상태';
  @override String get phone => '전화';
  @override String get crmContact => 'CRM 연락처';

  // ── Share Code ──
  @override String get teamShareCode => '팀 공유코드';
  @override String get shareCodeEnabledHint => '공유코드를 활성화하면 누구나 코드로 팀에 참가할 수 있습니다';
  @override String get shareCodeDisabled => '공유코드가 비활성화되어 있습니다';
  @override String get codeGenerating => '코드 생성 중...';
  @override String get shareCodeCopied => '공유코드가 복사되었습니다';
  @override String get regenerateCode => '코드 재생성';
  @override String get shareCodeObserverNote => '이 코드로 팀에 참가하면 Observer로 시작합니다';

  // ── Notifications ──
  @override String get noNotifications => '새로운 알림이 없습니다';
  @override String get teamInvitation => '팀 초대';
  @override String inviteAccepted(String teamName) => '$teamName 초대를 수락했습니다';
  @override String get declineInvite => '초대 거절';
  @override String declineInviteConfirm(String teamName) => '$teamName 초대를 거절하시겠습니까?';
  @override String get decline => '거절';
  @override String get inviteDeclined => '초대를 거절했습니다';
  @override String get accept => '수락';
  @override String inviterDescription(String inviterName, String teamName) =>
      '$inviterName님이 \'$teamName\' 팀에 초대했습니다.';

  // ── Shared Card Receive ──
  @override String get expiredShareLink => '만료되었거나 존재하지 않는 공유 링크입니다.';
  @override String get cannotLoadCard => '명함을 불러올 수 없습니다.';
  @override String get saveToWallet => '내 지갑에 저장';
  @override String get goBack => '돌아가기';

  // ── Search / Category ──
  @override String get selectCategory => '카테고리 선택';
  @override String get noCategoriesHint => '카테고리가 없습니다\n위의 + 버튼으로 추가해 보세요';
  @override String get searchCardHint => '이름, 회사, 직함으로 검색';

  // ── CRM Pipeline Status ──
  @override String get crmStatusLead => '리드';
  @override String get crmStatusContact => '연락';
  @override String get crmStatusMeeting => '미팅';
  @override String get crmStatusProposal => '제안';
  @override String get crmStatusContract => '계약';
  @override String get crmStatusClosed => '완료';
}

// ──────────────── English ────────────────

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn(super.locale);

  @override String get appTitle => 'Mapae';
  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get confirm => 'Confirm';
  @override String get edit => 'Edit';
  @override String get delete => 'Delete';
  @override String get orDivider => 'or';
  @override String get add => 'Add';
  @override String get manage => 'Manage';
  @override String get create => 'Create';
  @override String get share => 'Share';
  @override String get join => 'Join';
  @override String get leave => 'Leave';
  @override String get copy => 'Copy';
  @override String get remove => 'Remove';
  @override String get close => 'Close';
  @override String get noName => 'No Name';
  @override String get saved => 'Saved';
  @override String get required => 'Required';
  @override String get inputForm => 'Input Form';
  @override String get defaultForm => 'Default';
  @override String errorMsg(String e) => 'Error: $e';
  @override String get cardNotFound => 'Card not found';
  @override String saveFailed(String e) => 'Save failed: $e';

  @override String get home => 'Home';
  @override String get wallet => 'Wallet';
  @override String get management => 'Manage';

  @override String get login => 'Log In';
  @override String get signUp => 'Sign Up';
  @override String get loginWithGoogle => 'Sign in with Google';
  @override String get loginWithKakao => 'Sign in with Kakao';
  @override String get signUpWithGoogle => 'Sign up with Google';
  @override String get email => 'Email';
  @override String get password => 'Password';
  @override String get name => 'Name';
  @override String get confirmPassword => 'Confirm Password';
  @override String get forgotPassword => 'Forgot Password?';
  @override String get logout => 'Log Out';
  @override String get logoutConfirm => 'Are you sure you want to log out?';
  @override String get profile => 'Profile';
  @override String get autoLogin => 'Auto Login';
  @override String get noAccount => "Don't have an account?";
  @override String get enterEmail => 'Please enter your email';
  @override String get enterValidEmail => 'Please enter a valid email';
  @override String get enterPassword => 'Please enter your password';
  @override String get enterName => 'Please enter your name';
  @override String get passwordTooShort => 'Password must be at least 6 characters';
  @override String get passwordMismatch => 'Passwords do not match';
  @override String get signUpComplete => 'Sign up complete. Please check your email.';
  @override String get startCardManagement => 'Start managing business cards';
  @override String get nameTooLong => 'Name is too long';
  @override String get passwordWeak => 'Weak';
  @override String get passwordMedium => 'Medium';
  @override String get passwordStrong => 'Strong';

  @override String get personalInfo => 'Personal Info';
  @override String get enterNameHint => 'Enter your name';
  @override String get nameChanged => 'Name updated.';
  @override String get deleteAccount => 'Delete Account';
  @override String get deleteAccountWarning =>
      'All data will be deleted and cannot be recovered.\nPlease enter your password to confirm.';
  @override String get incorrectPassword => 'Incorrect password';
  @override String get withdraw => 'Delete';
  @override String get setPasswordTitle => 'Set Password';
  @override String get setPasswordDescription => 'Set a password for account security.\nYou can also log in with email later.';
  @override String get setPasswordHint => 'Password (min 6 characters)';
  @override String get confirmPasswordHint => 'Confirm password';
  @override String get passwordSet => 'Password has been set.';

  @override String get cardDetail => 'Card Detail';
  @override String get addCard => 'Add Card';
  @override String get editCard => 'Edit Card';
  @override String get addCardImage => 'Add Card Image';
  @override String get takePhoto => 'Take Photo';
  @override String get chooseFromGallery => 'Choose from Gallery';
  @override String get scanningCard => 'Scanning card...';
  @override String get scanningText => 'Scanning card text...';
  @override String scanTextFailed(String e) => 'Text recognition failed: $e';
  @override String get scanComplete => 'Scan Complete';
  @override String get scanFailed => 'Scan failed. Please try again.';
  @override String get shareCard => 'Share Card';
  @override String get shareViaSns => 'Share via SNS';
  @override String get cardShared => 'Card has been shared.';
  @override String get noCards => 'No cards yet.';
  @override String get noMyCards => 'No registered cards.';
  @override String get swipeToSeeMore => 'Swipe to see more cards';
  @override String get openCard => 'Open Card';
  @override String get sortByDate => 'By Date';
  @override String get sortByName => 'By Name';
  @override String totalCards(int count) => '$count cards total';
  @override String cardSharedTeamWarning(int count) =>
      'This card is shared with $count team(s).\nIt will only be deleted from your wallet; the team shared card will remain.';

  @override String get companyName => 'Company';
  @override String get position => 'Position';
  @override String get department => 'Department';
  @override String get phoneNumber => 'Phone';
  @override String get mobileNumber => 'Mobile';
  @override String get faxNumber => 'Fax';
  @override String get address => 'Address';
  @override String get website => 'Website';
  @override String get memo => 'Memo';

  @override String get category => 'Category';
  @override String get allCategories => 'All';
  @override String get addCategory => 'Add Category';
  @override String get categoryName => 'Category Name';
  @override String get noCategories => 'No categories';
  @override String get categoryManagement => 'Category Management';
  @override String get addCategoryTitle => 'Add Team Category';
  @override String get assignCategory => 'Assign Category';
  @override String get categorySelectOptional => 'Select Category (Optional)';
  @override String get shareWithoutCategory => 'Share without category';
  @override String get deleteCategoryTitle => 'Delete Category';
  @override String deleteCategoryConfirm(String name) =>
      "Delete category '$name'?\nCards in this category will be uncategorized.";
  @override String get createTeamCategory => 'Create Team Category';
  @override String categoryAdded(String name) => "Category '$name' added";
  @override String get categoryDeleted => 'Category deleted';
  @override String categoryDeleteFailed(String e) => 'Category delete failed: $e';
  @override String categoryAssignFailed(String e) => 'Category assign failed: $e';
  @override String categoryCreateFailed(String e) => 'Category create failed: $e';

  @override String get myCards => 'My Cards';
  @override String get addMyCard => 'Add My Card';
  @override String get editMyCard => 'Edit My Card';
  @override String get addMyCardHint => 'Add your card in the Manage tab';

  @override String get team => 'Team';
  @override String get teamManagement => 'Team Management';
  @override String get createTeam => 'Create Team';
  @override String get joinTeam => 'Join Team';
  @override String get teamName => 'Team Name';
  @override String get teamMembers => 'Team Members';
  @override String get sharedCards => 'Shared Cards';
  @override String get shareToTeam => 'Share to Team';
  @override String get crmIntegration => 'CRM Integration';
  @override String get noTeams => 'No teams yet';
  @override String get deleteTeam => 'Delete Team';
  @override String get deleteTeamConfirm =>
      'Deleting the team will remove all members and shared cards.\nAre you sure?';
  @override String get leaveTeam => 'Leave Team';
  @override String get leaveTeamConfirm => 'Are you sure you want to leave the team?';
  @override String get teamShareCodeHint =>
      'Enter the team share code to join as an Observer.';
  @override String get shareCodePlaceholder => '8-digit share code';
  @override String joinedTeam(String name) => "Joined '$name' as an Observer";
  @override String get joinFailed => 'Join failed: Please enter a valid share code';
  @override String get alreadyMember => 'You are already a member of this team';
  @override String get invalidShareCode => 'Invalid or inactive share code';
  @override String get noCardsInCategory => 'No cards in this category';
  @override String get noSharedCards => 'No shared cards';
  @override String get shareCardAction => 'Share a Card';
  @override String get unshareTitle => 'Remove from Shared';
  @override String unshareConfirm(String name) =>
      "Remove '$name' from team sharing?\nThe card in your wallet will remain.";
  @override String get unshareSuccess => 'Card removed from sharing';
  @override String unshareFailed(String e) => 'Remove failed: $e';
  @override String get copyToWalletSuccess => 'Card copied to wallet';
  @override String copyFailed(String e) => 'Copy failed: $e';
  @override String get duplicateCard => 'Duplicate Card';
  @override String get duplicateCardConfirm => 'This card already exists. Copy anyway?';
  @override String get selectCardToShare => 'Select Card to Share';
  @override String get noCardsInWallet => 'No cards in wallet';
  @override String get alreadyShared => 'This card is already shared';
  @override String get teamSharedSuccess => 'Card shared with team';
  @override String shareFailed(String e) => 'Share failed: $e';

  @override String get contextTag => 'Context Tag';
  @override String get addContextTag => 'Add Tag';
  @override String get tagTemplate => 'Tag Template';
  @override String get createTagTemplate => 'Create Tag Template';
  @override String get templateName => 'Template Name';
  @override String get addField => 'Add Field';
  @override String get fieldName => 'Field Name';
  @override String get fieldType => 'Field Type';
  @override String get textField => 'Text';
  @override String get dateField => 'Date';
  @override String get selectField => 'Select';
  @override String get metLocation => 'Met Location';
  @override String get metDate => 'Met Date';
  @override String get notes => 'Notes';
  @override String get noTagTemplates => 'No tag templates';
  @override String get tagTemplateHint =>
      'Create formats to record\nmeeting situations and notes on cards';
  @override String get createTemplate => 'Create Template';
  @override String get contextTagTemplate => 'Context Tag Templates';
  @override String get tagTemplateDescription =>
      'Manage tag formats to record meeting situations and notes on cards';

  @override String get call => 'Call';
  @override String get sendMessage => 'Message';
  @override String get sendEmail => 'Send Email';
  @override String get openSns => 'Open SNS';
  @override String incomingCallFrom(String name) => 'Incoming call from $name';

  @override String get settings => 'Settings';
  @override String get language => 'Language';
  @override String get darkMode => 'Dark Mode';
  @override String get notifications => 'Notifications';
  @override String get version => 'Version';
  @override String get korean => '한국어';
  @override String get english => 'English';

  @override String get removeAds => 'Remove Ads';
  @override String get applied => 'Active';
  @override String get premiumTitle => 'Ad-free Mapae';
  @override String get premiumDescription =>
      'Permanently removes ads from the card list.';
  @override String get removeAdsCompletely => 'Completely remove ads from card list';
  @override String get oneTimePurchase => 'One-time purchase · Lifetime';
  @override String get restoreOnDevices => 'Restore on devices with same account';
  @override String get purchaseButton => '₩1,000 · Remove Ads';
  @override String get restorePurchase => 'Restore Purchase';
  @override String get noPurchaseToRestore => 'No purchases to restore.';

  @override String get deleteConfirmTitle => 'Delete Card';
  @override String get deleteConfirmMessage =>
      'Are you sure you want to delete this card?';

  // ── Invite Member ──
  @override String get inviteMember => 'Invite Member';
  @override String get inviteMemberHint => 'Search users by email to invite';
  @override String get emailAddressHint => 'Enter email address';
  @override String get cannotInviteSelf => 'Cannot invite yourself';
  @override String get alreadyTeamMember => 'Already a team member';
  @override String get searchError => 'Error during search';
  @override String get alreadyInvited => 'Invitation already sent';
  @override String inviteSent(String name) => 'Invitation sent to $name';
  @override String get inviteError => 'Error sending invitation';
  @override String get noSearchResults => 'No results found';
  @override String get invite => 'Invite';
  @override String get inviteConfirmTitle => 'Confirm Invitation';
  @override String inviteConfirmMessage(String name) => 'Invite $name to the team?';

  // ── Share / QuickShare ──
  @override String get shareViaSnsSubtitle => 'KakaoTalk, Messages, etc.';
  @override String get quickShare => 'QuickShare';
  @override String get quickShareSubtitle => 'Exchange cards with nearby QuickShare users in real time';
  @override String get startExchange => 'Start Exchange';
  @override String get done => 'Done';
  @override String get scanning => 'Searching nearby...';
  @override String get quickShareScanningDesc => 'Only users with QuickShare open are shown in real time.';
  @override String get quickShareDiscoveredDesc => 'Select a user to exchange cards with.';
  @override String get quickShareExchangingDesc => 'Exchanging cards with each other.';
  @override String get quickShareCompletedDesc => "Each other's card has been saved to both wallets.";
  @override String nearbyUsers(int count) => '$count nearby user(s)';
  @override String exchangeCompleted(String name) => 'Card exchange with $name is complete.';
  @override String get exchangeTimeout => 'Response timed out. Please try again.';
  @override String get exchangeInProgress => 'Exchanging cards...';
  @override String get cardExchangeComplete => 'Card Exchange Complete';
  @override String get myCard => 'My Card';
  @override String get opponent => 'Other';
  @override String get shareCardContent => '📇 Save this card with the Mapae app:';
  @override String shareCardTitle(String name) => 'Card Share - $name';

  // ── Scan Card ──
  @override String get scanCard => 'Scan Card';
  @override String get scanCardSubtitle => 'Scan with camera or choose from gallery';
  @override String get processingCard => 'Processing card...';
  @override String get recognizingText => 'Recognizing text...';
  @override String get savingInfo => 'Saving info...';
  @override String get cardAdded => 'Card added';
  @override String recognitionFailed(String e) => 'Recognition failed: $e';
  @override String get loginRequired => 'Login required';

  // ── Team Members / Roles ──
  @override String get promoteMember => 'Promote to Member';
  @override String get demoteToObserver => 'Demote to Observer';
  @override String get transferOwnership => 'Transfer Ownership';
  @override String get kickFromTeam => 'Remove from Team';
  @override String get kick => 'Remove';
  @override String get kickMemberTitle => 'Remove Member';
  @override String get thisMember => 'this member';
  @override String kickMemberConfirm(String name) => 'Remove $name from the team?';
  @override String transferOwnershipContent(String name) =>
      'Transfer Owner to $name?\nYou will become a Member.';
  @override String get transferProceed => 'Transfer';
  @override String get finalConfirm => 'Final Confirmation';
  @override String finalTransferConfirm(String name) =>
      'Really transfer Owner to $name?\nThis cannot be undone.';
  @override String get transferSuccess => 'Ownership transferred';
  @override String transferFailed(String e) => 'Transfer failed: $e';
  @override String get finalTransferBtn => 'Confirm Transfer';
  @override String get roleOwner => 'Owner';
  @override String get roleMember => 'Member';
  @override String get roleObserver => 'Observer';
  @override String changeFailed(String e) => 'Change failed: $e';
  @override String get shareCodeRegenerated => 'Share code regenerated';
  @override String regenFailed(String e) => 'Regeneration failed: $e';

  // ── CRM ──
  @override String get noPermissionObserver => 'No permission. Observers cannot edit CRM';
  @override String loadFailed(String e) => 'Load failed: $e';
  @override String get searchHint => 'Search...';
  @override String get pipelineView => 'Pipeline View';
  @override String get noContacts => 'No CRM contacts';
  @override String get addContactHint => 'Import from shared cards or add manually';
  @override String get importFromSharedCards => 'Import from Shared Cards';
  @override String get addManually => 'Add Manually';
  @override String get pipeline => 'Pipeline';
  @override String totalPeople(int count) => '$count total';
  @override String get crmSetupRequired => 'CRM Setup Required';
  @override String get crmSetupInstruction => 'Run migration_crm.sql in\nSupabase SQL Editor.';
  @override String get retry => 'Retry';
  @override String get addCrmContact => 'Add CRM Contact';
  @override String get company => 'Company';
  @override String get jobTitle => 'Job Title';
  @override String importedContacts(int count) => '$count contacts imported';
  @override String get importAll => 'Import All';
  @override String get noNewCards => 'No new cards available to import';
  @override String contactAddedFromCard(String name) => "'$name' added to CRM";
  @override String get contactAdded => 'Contact added';
  @override String get contactInfo => 'Contact Info';
  @override String get noInfo => 'No info';
  @override String get editInfo => 'Edit Info';
  @override String get activityNotes => 'Activity Notes';
  @override String noteCount(int count) => '$count';
  @override String get noteHint => 'Enter a note...';
  @override String get noNotes => 'No notes yet';
  @override String get unknown => 'Unknown';
  @override String get justNow => 'Just now';
  @override String minutesAgo(int n) => '${n}m ago';
  @override String hoursAgo(int n) => '${n}h ago';
  @override String daysAgo(int n) => '${n}d ago';
  @override String get deleteContact => 'Delete Contact';
  @override String get thisContact => 'this contact';
  @override String deleteContactConfirm(String name) =>
      "Delete '$name'?\nAll notes will also be deleted.";
  @override String get status => 'Status';
  @override String get phone => 'Phone';
  @override String get crmContact => 'CRM Contact';

  // ── Share Code ──
  @override String get teamShareCode => 'Team Share Code';
  @override String get shareCodeEnabledHint => 'When enabled, anyone can join the team with the code';
  @override String get shareCodeDisabled => 'Share code is disabled';
  @override String get codeGenerating => 'Generating code...';
  @override String get shareCodeCopied => 'Share code copied';
  @override String get regenerateCode => 'Regenerate Code';
  @override String get shareCodeObserverNote => 'Users who join with this code start as Observer';

  // ── Notifications ──
  @override String get noNotifications => 'No new notifications';
  @override String get teamInvitation => 'Team Invitation';
  @override String inviteAccepted(String teamName) => 'Accepted invitation to $teamName';
  @override String get declineInvite => 'Decline Invitation';
  @override String declineInviteConfirm(String teamName) => 'Decline invitation to $teamName?';
  @override String get decline => 'Decline';
  @override String get inviteDeclined => 'Invitation declined';
  @override String get accept => 'Accept';
  @override String inviterDescription(String inviterName, String teamName) =>
      '$inviterName invited you to the \'$teamName\' team.';

  // ── Shared Card Receive ──
  @override String get expiredShareLink => 'This share link has expired or does not exist.';
  @override String get cannotLoadCard => 'Cannot load the card.';
  @override String get saveToWallet => 'Save to Wallet';
  @override String get goBack => 'Go Back';

  // ── Search / Category ──
  @override String get selectCategory => 'Select Category';
  @override String get noCategoriesHint => 'No categories\nUse the + button above to add one';
  @override String get searchCardHint => 'Search by name, company, or title';

  // ── CRM Pipeline Status ──
  @override String get crmStatusLead => 'Lead';
  @override String get crmStatusContact => 'Contact';
  @override String get crmStatusMeeting => 'Meeting';
  @override String get crmStatusProposal => 'Proposal';
  @override String get crmStatusContract => 'Contract';
  @override String get crmStatusClosed => 'Closed';
}

// ──────────────── Chinese ────────────────

class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh(super.locale);

  @override String get appTitle => 'Mapae';
  @override String get cancel => '取消';
  @override String get save => '保存';
  @override String get confirm => '确认';
  @override String get edit => '编辑';
  @override String get delete => '删除';
  @override String get orDivider => '或';
  @override String get add => '添加';
  @override String get manage => '管理';
  @override String get create => '创建';
  @override String get share => '分享';
  @override String get join => '加入';
  @override String get leave => '退出';
  @override String get copy => '复制';
  @override String get remove => '移除';
  @override String get close => '关闭';
  @override String get noName => '无名';
  @override String get saved => '已保存';
  @override String get required => '必填';
  @override String get inputForm => '输入表单';
  @override String get defaultForm => '默认';
  @override String errorMsg(String e) => '错误: $e';
  @override String get cardNotFound => '找不到名片';
  @override String saveFailed(String e) => '保存失败: $e';

  @override String get home => '首页';
  @override String get wallet => '名片夹';
  @override String get management => '管理';

  @override String get login => '登录';
  @override String get signUp => '注册';
  @override String get loginWithGoogle => '使用Google登录';
  @override String get loginWithKakao => '使用Kakao登录';
  @override String get signUpWithGoogle => '使用Google注册';
  @override String get email => '邮箱';
  @override String get password => '密码';
  @override String get name => '姓名';
  @override String get confirmPassword => '确认密码';
  @override String get forgotPassword => '忘记密码？';
  @override String get logout => '退出登录';
  @override String get logoutConfirm => '确定要退出登录吗？';
  @override String get profile => '个人资料';
  @override String get autoLogin => '自动登录';
  @override String get noAccount => '没有账号？';
  @override String get enterEmail => '请输入邮箱';
  @override String get enterValidEmail => '请输入有效的邮箱';
  @override String get enterPassword => '请输入密码';
  @override String get enterName => '请输入姓名';
  @override String get passwordTooShort => '密码至少需要6个字符';
  @override String get passwordMismatch => '密码不一致';
  @override String get signUpComplete => '注册完成，请查看邮箱。';
  @override String get startCardManagement => '开始管理名片';
  @override String get nameTooLong => '姓名太长';
  @override String get passwordWeak => '弱';
  @override String get passwordMedium => '中等';
  @override String get passwordStrong => '强';

  @override String get personalInfo => '个人信息';
  @override String get enterNameHint => '请输入姓名';
  @override String get nameChanged => '姓名已更改。';
  @override String get deleteAccount => '注销账号';
  @override String get deleteAccountWarning => '所有数据将被删除且无法恢复。\n请输入密码以确认。';
  @override String get incorrectPassword => '密码不正确';
  @override String get withdraw => '注销';
  @override String get setPasswordTitle => '设置密码';
  @override String get setPasswordDescription => '为了账号安全，请设置密码。\n之后也可以使用邮箱登录。';
  @override String get setPasswordHint => '密码（至少6位）';
  @override String get confirmPasswordHint => '确认密码';
  @override String get passwordSet => '密码已设置。';

  @override String get cardDetail => '名片详情';
  @override String get addCard => '添加名片';
  @override String get editCard => '编辑名片';
  @override String get addCardImage => '添加名片图片';
  @override String get takePhoto => '拍照';
  @override String get chooseFromGallery => '从相册选择';
  @override String get scanningCard => '正在识别名片...';
  @override String get scanningText => '正在识别名片文字...';
  @override String scanTextFailed(String e) => '文字识别失败: $e';
  @override String get scanComplete => '识别完成';
  @override String get scanFailed => '识别失败，请重试。';
  @override String get shareCard => '分享名片';
  @override String get shareViaSns => '通过SNS分享';
  @override String get cardShared => '名片已分享。';
  @override String get noCards => '暂无名片。';
  @override String get noMyCards => '暂无已注册的名片。';
  @override String get swipeToSeeMore => '左右滑动查看更多名片';
  @override String get openCard => '查看名片';
  @override String get sortByDate => '按日期';
  @override String get sortByName => '按姓名';
  @override String totalCards(int count) => '共 $count 张名片';
  @override String cardSharedTeamWarning(int count) =>
      '此名片已分享给 $count 个团队。\n仅从个人名片夹中删除，团队共享名片将保留。';

  @override String get companyName => '公司';
  @override String get position => '职位';
  @override String get department => '部门';
  @override String get phoneNumber => '电话';
  @override String get mobileNumber => '手机';
  @override String get faxNumber => '传真';
  @override String get address => '地址';
  @override String get website => '网站';
  @override String get memo => '备注';

  @override String get category => '分类';
  @override String get allCategories => '全部';
  @override String get addCategory => '添加分类';
  @override String get categoryName => '分类名称';
  @override String get noCategories => '暂无分类';
  @override String get categoryManagement => '分类管理';
  @override String get addCategoryTitle => '添加团队分类';
  @override String get assignCategory => '指定分类';
  @override String get categorySelectOptional => '选择分类（可选）';
  @override String get shareWithoutCategory => '不分类直接分享';
  @override String get deleteCategoryTitle => '删除分类';
  @override String deleteCategoryConfirm(String name) =>
      '删除分类 \'$name\'？\n该分类下的名片将变为未分类。';
  @override String get createTeamCategory => '创建团队分类';
  @override String categoryAdded(String name) => '分类 \'$name\' 已添加';
  @override String get categoryDeleted => '分类已删除';
  @override String categoryDeleteFailed(String e) => '分类删除失败: $e';
  @override String categoryAssignFailed(String e) => '分类指定失败: $e';
  @override String categoryCreateFailed(String e) => '分类创建失败: $e';

  @override String get myCards => '我的名片';
  @override String get addMyCard => '添加我的名片';
  @override String get editMyCard => '编辑我的名片';
  @override String get addMyCardHint => '在管理标签页中添加您的名片';

  @override String get team => '团队';
  @override String get teamManagement => '团队管理';
  @override String get createTeam => '创建团队';
  @override String get joinTeam => '加入团队';
  @override String get teamName => '团队名称';
  @override String get teamMembers => '团队成员';
  @override String get sharedCards => '共享名片';
  @override String get shareToTeam => '分享给团队';
  @override String get crmIntegration => 'CRM集成';
  @override String get noTeams => '暂无团队';
  @override String get deleteTeam => '删除团队';
  @override String get deleteTeamConfirm => '删除团队将移除所有成员和共享名片。\n确定删除吗？';
  @override String get leaveTeam => '退出团队';
  @override String get leaveTeamConfirm => '确定要退出团队吗？';
  @override String get teamShareCodeHint => '输入团队共享码以Observer身份加入。';
  @override String get shareCodePlaceholder => '8位共享码';
  @override String joinedTeam(String name) => '已作为Observer加入 \'$name\'';
  @override String get joinFailed => '加入失败：请输入有效的共享码';
  @override String get alreadyMember => '您已经是该团队的成员';
  @override String get invalidShareCode => '无效或已禁用的共享码';
  @override String get noCardsInCategory => '此分类下暂无名片';
  @override String get noSharedCards => '暂无共享名片';
  @override String get shareCardAction => '分享名片';
  @override String get unshareTitle => '取消分享';
  @override String unshareConfirm(String name) =>
      '将 \'$name\' 从团队分享中移除？\n您名片夹中的名片将保留。';
  @override String get unshareSuccess => '已取消分享';
  @override String unshareFailed(String e) => '取消分享失败: $e';
  @override String get copyToWalletSuccess => '名片已复制到名片夹';
  @override String copyFailed(String e) => '复制失败: $e';
  @override String get duplicateCard => '重复名片';
  @override String get duplicateCardConfirm => '此名片已存在。是否仍要复制？';
  @override String get selectCardToShare => '选择要分享的名片';
  @override String get noCardsInWallet => '名片夹中暂无名片';
  @override String get alreadyShared => '此名片已分享';
  @override String get teamSharedSuccess => '名片已分享给团队';
  @override String shareFailed(String e) => '分享失败: $e';

  @override String get contextTag => '场景标签';
  @override String get addContextTag => '添加标签';
  @override String get tagTemplate => '标签模板';
  @override String get createTagTemplate => '创建标签模板';
  @override String get templateName => '模板名称';
  @override String get addField => '添加字段';
  @override String get fieldName => '字段名称';
  @override String get fieldType => '字段类型';
  @override String get textField => '文本';
  @override String get dateField => '日期';
  @override String get selectField => '选择';
  @override String get metLocation => '会面地点';
  @override String get metDate => '会面日期';
  @override String get notes => '备注事项';
  @override String get noTagTemplates => '暂无标签模板';
  @override String get tagTemplateHint => '创建格式以记录\n会面情况和名片备注';
  @override String get createTemplate => '创建模板';
  @override String get contextTagTemplate => '场景标签模板';
  @override String get tagTemplateDescription => '管理用于记录会面情况和名片备注的标签格式';

  @override String get call => '电话';
  @override String get sendMessage => '短信';
  @override String get sendEmail => '发送邮件';
  @override String get openSns => '打开SNS';
  @override String incomingCallFrom(String name) => '$name来电';

  @override String get settings => '设置';
  @override String get language => '语言';
  @override String get darkMode => '深色模式';
  @override String get notifications => '通知';
  @override String get version => '版本';
  @override String get korean => '한국어';
  @override String get english => 'English';

  @override String get removeAds => '移除广告';
  @override String get applied => '已应用';
  @override String get premiumTitle => '无广告 Mapae';
  @override String get premiumDescription => '永久移除名片列表中的广告。';
  @override String get removeAdsCompletely => '完全移除名片列表广告';
  @override String get oneTimePurchase => '一次购买 · 终身有效';
  @override String get restoreOnDevices => '同一账号设备可恢复';
  @override String get purchaseButton => '¥7 · 移除广告';
  @override String get restorePurchase => '恢复购买';
  @override String get noPurchaseToRestore => '没有可恢复的购买记录。';

  @override String get deleteConfirmTitle => '删除名片';
  @override String get deleteConfirmMessage => '确定要删除这张名片吗？';

  // ── Invite Member ──
  @override String get inviteMember => '邀请成员';
  @override String get inviteMemberHint => '通过邮箱搜索用户并邀请';
  @override String get emailAddressHint => '输入邮箱地址';
  @override String get cannotInviteSelf => '不能邀请自己';
  @override String get alreadyTeamMember => '已经是团队成员';
  @override String get searchError => '搜索时出错';
  @override String get alreadyInvited => '已发送邀请';
  @override String inviteSent(String name) => '已向 $name 发送邀请';
  @override String get inviteError => '发送邀请时出错';
  @override String get noSearchResults => '未找到结果';
  @override String get invite => '邀请';
  @override String get inviteConfirmTitle => '确认邀请';
  @override String inviteConfirmMessage(String name) => '邀请 $name 加入团队？';

  // ── Share / QuickShare ──
  @override String get shareViaSnsSubtitle => '微信、短信等';
  @override String get quickShare => '快速分享';
  @override String get quickShareSubtitle => '与附近快速分享用户实时交换名片';
  @override String get startExchange => '开始交换';
  @override String get done => '完成';
  @override String get scanning => '搜索附近...';
  @override String get quickShareScanningDesc => '仅显示当前打开快速分享的用户。';
  @override String get quickShareDiscoveredDesc => '选择要交换名片的用户。';
  @override String get quickShareExchangingDesc => '正在交换名片。';
  @override String get quickShareCompletedDesc => '双方名片已保存到各自的名片夹中。';
  @override String nearbyUsers(int count) => '附近 $count 位用户';
  @override String exchangeCompleted(String name) => '与 $name 的名片交换已完成。';
  @override String get exchangeTimeout => '响应超时，请重试。';
  @override String get exchangeInProgress => '正在交换名片...';
  @override String get cardExchangeComplete => '名片交换完成';
  @override String get myCard => '我的名片';
  @override String get opponent => '对方';
  @override String get shareCardContent => '📇 使用Mapae应用保存这张名片:';
  @override String shareCardTitle(String name) => '名片分享 - $name';

  // ── Scan Card ──
  @override String get scanCard => '扫描名片';
  @override String get scanCardSubtitle => '使用相机扫描或从相册选择';
  @override String get processingCard => '正在处理名片...';
  @override String get recognizingText => '正在识别文字...';
  @override String get savingInfo => '正在保存信息...';
  @override String get cardAdded => '名片已添加';
  @override String recognitionFailed(String e) => '识别失败: $e';
  @override String get loginRequired => '需要登录';

  // ── Team Members / Roles ──
  @override String get promoteMember => '升级为成员';
  @override String get demoteToObserver => '降级为观察者';
  @override String get transferOwnership => '转让所有权';
  @override String get kickFromTeam => '从团队移除';
  @override String get kick => '移除';
  @override String get kickMemberTitle => '移除成员';
  @override String get thisMember => '此成员';
  @override String kickMemberConfirm(String name) => '将 $name 从团队中移除？';
  @override String transferOwnershipContent(String name) =>
      '将Owner权限转让给 $name？\n转让后您将变为Member。';
  @override String get transferProceed => '转让';
  @override String get finalConfirm => '最终确认';
  @override String finalTransferConfirm(String name) =>
      '确定将Owner转让给 $name？\n此操作不可撤销。';
  @override String get transferSuccess => '所有权已转让';
  @override String transferFailed(String e) => '转让失败: $e';
  @override String get finalTransferBtn => '确认转让';
  @override String get roleOwner => 'Owner（所有者）';
  @override String get roleMember => 'Member（成员）';
  @override String get roleObserver => 'Observer（观察者）';
  @override String changeFailed(String e) => '更改失败: $e';
  @override String get shareCodeRegenerated => '共享码已重新生成';
  @override String regenFailed(String e) => '重新生成失败: $e';

  // ── CRM ──
  @override String get noPermissionObserver => '没有权限。Observer无法编辑CRM';
  @override String loadFailed(String e) => '加载失败: $e';
  @override String get searchHint => '搜索...';
  @override String get pipelineView => '管道视图';
  @override String get noContacts => '暂无CRM联系人';
  @override String get addContactHint => '从共享名片导入或手动添加';
  @override String get importFromSharedCards => '从共享名片导入';
  @override String get addManually => '手动添加';
  @override String get pipeline => '管道';
  @override String totalPeople(int count) => '共 $count 人';
  @override String get crmSetupRequired => '需要设置CRM';
  @override String get crmSetupInstruction => '请在Supabase SQL Editor中\n运行 migration_crm.sql。';
  @override String get retry => '重试';
  @override String get addCrmContact => '添加CRM联系人';
  @override String get company => '公司';
  @override String get jobTitle => '职位';
  @override String importedContacts(int count) => '已导入 $count 个联系人';
  @override String get importAll => '全部导入';
  @override String get noNewCards => '没有可导入的新名片';
  @override String contactAddedFromCard(String name) => '\'$name\' 已添加到CRM';
  @override String get contactAdded => '联系人已添加';
  @override String get contactInfo => '联系人信息';
  @override String get noInfo => '暂无信息';
  @override String get editInfo => '编辑信息';
  @override String get activityNotes => '活动笔记';
  @override String noteCount(int count) => '$count 条';
  @override String get noteHint => '输入笔记...';
  @override String get noNotes => '暂无笔记';
  @override String get unknown => '未知';
  @override String get justNow => '刚刚';
  @override String minutesAgo(int n) => '$n分钟前';
  @override String hoursAgo(int n) => '$n小时前';
  @override String daysAgo(int n) => '$n天前';
  @override String get deleteContact => '删除联系人';
  @override String get thisContact => '此联系人';
  @override String deleteContactConfirm(String name) =>
      '删除 \'$name\'？\n所有笔记也将一并删除。';
  @override String get status => '状态';
  @override String get phone => '电话';
  @override String get crmContact => 'CRM联系人';

  // ── Share Code ──
  @override String get teamShareCode => '团队共享码';
  @override String get shareCodeEnabledHint => '启用后，任何人都可以使用共享码加入团队';
  @override String get shareCodeDisabled => '共享码已禁用';
  @override String get codeGenerating => '正在生成码...';
  @override String get shareCodeCopied => '共享码已复制';
  @override String get regenerateCode => '重新生成码';
  @override String get shareCodeObserverNote => '使用此码加入的用户将以Observer身份开始';

  // ── Notifications ──
  @override String get noNotifications => '暂无新通知';
  @override String get teamInvitation => '团队邀请';
  @override String inviteAccepted(String teamName) => '已接受 $teamName 的邀请';
  @override String get declineInvite => '拒绝邀请';
  @override String declineInviteConfirm(String teamName) => '拒绝 $teamName 的邀请？';
  @override String get decline => '拒绝';
  @override String get inviteDeclined => '已拒绝邀请';
  @override String get accept => '接受';
  @override String inviterDescription(String inviterName, String teamName) =>
      '$inviterName 邀请您加入 \'$teamName\' 团队。';

  // ── Shared Card Receive ──
  @override String get expiredShareLink => '此分享链接已过期或不存在。';
  @override String get cannotLoadCard => '无法加载名片。';
  @override String get saveToWallet => '保存到名片夹';
  @override String get goBack => '返回';

  // ── Search / Category ──
  @override String get selectCategory => '选择分类';
  @override String get noCategoriesHint => '暂无分类\n使用上方的 + 按钮添加';
  @override String get searchCardHint => '按姓名、公司或职位搜索';

  // ── CRM Pipeline Status ──
  @override String get crmStatusLead => '线索';
  @override String get crmStatusContact => '联系';
  @override String get crmStatusMeeting => '会议';
  @override String get crmStatusProposal => '提案';
  @override String get crmStatusContract => '合同';
  @override String get crmStatusClosed => '完成';
}