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

  // ── Navigation ──
  String get home;
  String get wallet;
  String get management;

  // ── Auth ──
  String get login;
  String get signUp;
  String get loginWithGoogle;
  String get email;
  String get password;
  String get name;
  String get confirmPassword;
  String get forgotPassword;
  String get logout;
  String get logoutConfirm;
  String get profile;

  // ── Cards ──
  String get cardDetail;
  String get addCard;
  String get takePhoto;
  String get chooseFromGallery;
  String get scanningCard;
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

  // ── My Cards ──
  String get myCards;
  String get addMyCard;
  String get editMyCard;

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

  @override String get home => '홈';
  @override String get wallet => '지갑';
  @override String get management => '관리';

  @override String get login => '로그인';
  @override String get signUp => '회원가입';
  @override String get loginWithGoogle => 'Google로 로그인';
  @override String get email => '이메일';
  @override String get password => '비밀번호';
  @override String get name => '이름';
  @override String get confirmPassword => '비밀번호 확인';
  @override String get forgotPassword => '비밀번호 찾기';
  @override String get logout => '로그아웃';
  @override String get logoutConfirm => '로그아웃 하시겠습니까?';
  @override String get profile => '프로필';

  @override String get cardDetail => '명함 상세';
  @override String get addCard => '명함 추가';
  @override String get takePhoto => '사진 촬영';
  @override String get chooseFromGallery => '갤러리에서 선택';
  @override String get scanningCard => '명함 인식 중...';
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

  @override String get myCards => '내 명함';
  @override String get addMyCard => '내 명함 추가';
  @override String get editMyCard => '내 명함 수정';

  @override String get team => '팀';
  @override String get teamManagement => '팀 관리';
  @override String get createTeam => '팀 만들기';
  @override String get joinTeam => '팀 참여';
  @override String get teamName => '팀 이름';
  @override String get teamMembers => '팀 멤버';
  @override String get sharedCards => '공유된 명함';
  @override String get shareToTeam => '팀에 공유';
  @override String get crmIntegration => 'CRM 연동';

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

  @override String get home => 'Home';
  @override String get wallet => 'Wallet';
  @override String get management => 'Manage';

  @override String get login => 'Log In';
  @override String get signUp => 'Sign Up';
  @override String get loginWithGoogle => 'Sign in with Google';
  @override String get email => 'Email';
  @override String get password => 'Password';
  @override String get name => 'Name';
  @override String get confirmPassword => 'Confirm Password';
  @override String get forgotPassword => 'Forgot Password?';
  @override String get logout => 'Log Out';
  @override String get logoutConfirm => 'Are you sure you want to log out?';
  @override String get profile => 'Profile';

  @override String get cardDetail => 'Card Detail';
  @override String get addCard => 'Add Card';
  @override String get takePhoto => 'Take Photo';
  @override String get chooseFromGallery => 'Choose from Gallery';
  @override String get scanningCard => 'Scanning card...';
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

  @override String get myCards => 'My Cards';
  @override String get addMyCard => 'Add My Card';
  @override String get editMyCard => 'Edit My Card';

  @override String get team => 'Team';
  @override String get teamManagement => 'Team Management';
  @override String get createTeam => 'Create Team';
  @override String get joinTeam => 'Join Team';
  @override String get teamName => 'Team Name';
  @override String get teamMembers => 'Team Members';
  @override String get sharedCards => 'Shared Cards';
  @override String get shareToTeam => 'Share to Team';
  @override String get crmIntegration => 'CRM Integration';

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

  @override String get deleteConfirmTitle => 'Delete Card';
  @override String get deleteConfirmMessage => 'Are you sure you want to delete this card?';
}