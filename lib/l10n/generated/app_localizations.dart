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

  // ── Profile ──
  String get personalInfo;
  String get enterNameHint;
  String get nameChanged;
  String get deleteAccount;
  String get deleteAccountWarning;
  String get incorrectPassword;
  String get withdraw;

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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ko', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    if (locale.languageCode == 'en') return AppLocalizationsEn(locale);
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

  @override String get personalInfo => '개인정보';
  @override String get enterNameHint => '이름을 입력하세요';
  @override String get nameChanged => '이름이 변경되었습니다.';
  @override String get deleteAccount => '계정 탈퇴';
  @override String get deleteAccountWarning => '모든 데이터가 삭제되며 복구할 수 없습니다.\n본인 확인을 위해 비밀번호를 입력해주세요.';
  @override String get incorrectPassword => '비밀번호가 올바르지 않습니다';
  @override String get withdraw => '탈퇴';

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

  @override String get personalInfo => 'Personal Info';
  @override String get enterNameHint => 'Enter your name';
  @override String get nameChanged => 'Name updated.';
  @override String get deleteAccount => 'Delete Account';
  @override String get deleteAccountWarning =>
      'All data will be deleted and cannot be recovered.\nPlease enter your password to confirm.';
  @override String get incorrectPassword => 'Incorrect password';
  @override String get withdraw => 'Delete';

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
}
