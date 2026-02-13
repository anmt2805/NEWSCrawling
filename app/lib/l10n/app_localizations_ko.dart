// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String tokensLabel(int count) {
    return '토큰 : $count';
  }

  @override
  String get breakingTab => '속보';

  @override
  String get breakingTabShort => '속보';

  @override
  String topBreakingHeadlines(String region) {
    return '주요 속보 · $region';
  }

  @override
  String get tapTitleToEditKeyword => '제목을 눌러 키워드 수정';

  @override
  String get noKeywordSet => '이 탭에 키워드가 없습니다.';

  @override
  String get setKeyword => '키워드 설정';

  @override
  String setKeywordForTab(String tab) {
    return '$tab 키워드 설정';
  }

  @override
  String get keywordHint => '예: AI, 기후, 비트코인';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get breakingNewsFixed => '브레이킹 뉴스는 고정입니다.';

  @override
  String fixedLabel(String label) {
    return '고정: $label';
  }

  @override
  String get noKeyword => '키워드 없음';

  @override
  String get regionFilter => '지역 필터';

  @override
  String get refresh => '새로고침';

  @override
  String get toggleTheme => '테마 전환';

  @override
  String get regionSettingsTitle => '기사 작성 국가';

  @override
  String get languageSettingsTitle => '앱 언어';

  @override
  String get languageEnglish => '영어';

  @override
  String get languageEnglishUk => '영어(영국)';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageJapanese => '일본어';

  @override
  String get languageFrench => '프랑스어';

  @override
  String get languageSpanish => '스페인어';

  @override
  String get languageRussian => '러시아어';

  @override
  String get languageArabic => '아랍어';

  @override
  String get notificationSettingsTitle => '푸시 알림 설정';

  @override
  String get notificationsTitle => '알림';

  @override
  String get notificationsClear => '모두 지우기';

  @override
  String get notificationsEmpty => '알림이 없습니다.';

  @override
  String get notificationsSeverity => '심각도';

  @override
  String get regionUnitedStates => '미국';

  @override
  String get regionUnitedKingdom => '영국';

  @override
  String get regionKorea => '대한민국';

  @override
  String get regionJapan => '일본';

  @override
  String get regionFrance => '프랑스';

  @override
  String get regionSpain => '스페인';

  @override
  String get regionRussia => '러시아';

  @override
  String get regionUnitedArabEmirates => '아랍에미리트';

  @override
  String get regionAllCountries => '모든 국가';

  @override
  String get syncChoiceTitle => '데이터 선택';

  @override
  String get syncChoiceBody => '계정에 저장된 데이터가 있습니다. 어떤 데이터를 사용할까요?';

  @override
  String get syncChoiceUseCloud => '계정 데이터 불러오기';

  @override
  String get syncChoiceKeepLocal => '현재 기기 유지';

  @override
  String get notificationBreakingTitle => '속보 알림';

  @override
  String get notificationBreakingSubtitle => '긴급(5단계)만 수신';

  @override
  String get notificationKeywordTitle => '키워드 알림';

  @override
  String get notificationSeverity4 => '4단계';

  @override
  String get notificationSeverity5 => '5단계';

  @override
  String get notificationSeverity4Label => '심각';

  @override
  String get notificationSeverity5Label => '매우 심각';

  @override
  String get exitConfirmTitle => '앱을 종료하시겠습니까?';

  @override
  String get exitConfirmBody => '앱을 종료할까요?';

  @override
  String get exitConfirmNo => '아니요';

  @override
  String get exitConfirmYes => '예';

  @override
  String get loginRequiredTitle => '로그인이 필요합니다';

  @override
  String get loginRequiredBody => '탭 구매와 토큰 충전을 위해 로그인해주세요.';

  @override
  String get loginFailedTitle => '로그인 실패';

  @override
  String get loginFailedBody => 'Google 로그인에 실패했습니다. 다시 시도해주세요.';

  @override
  String get purchaseLockedTitle => '순서대로 해제하세요';

  @override
  String get purchaseLockedBody => '이전 탭을 먼저 구매해야 합니다.';

  @override
  String get insufficientTokensTitle => '토큰이 부족합니다';

  @override
  String get insufficientTokensBody => '탭을 구매하려면 토큰을 충전해주세요.';

  @override
  String get openTokenStore => '토큰 상점 열기';

  @override
  String get noThanks => '아니오';

  @override
  String get confirm => '확인';

  @override
  String get confirmPurchase => '구매';

  @override
  String purchaseTabTitle(String tab) {
    return '$tab 탭 구매';
  }

  @override
  String purchaseTabBody(int cost) {
    return '30일 이용권 $cost 토큰을 사용합니다. 구매할까요?';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return '$tab 탭 이용권 구매';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return '토큰 충전 +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return '보유 토큰: $count';
  }

  @override
  String get tabUsageTitle => '탭 이용 현황';

  @override
  String tabLabelWithIndex(String label) {
    return '$label 탭';
  }

  @override
  String tabRemainingLabel(String time) {
    return '잔여 $time';
  }

  @override
  String get tabLockedLabel => '잠김';

  @override
  String get tokenHistoryTitle => '토큰 내역';

  @override
  String get notSignedIn => '로그인되지 않음';

  @override
  String get signOut => '로그아웃';

  @override
  String get noArticlesFound => '일정 주기에 맞춰 자동 업데이트 됩니다.';

  @override
  String get failedToLoadNews => '뉴스를 불러오지 못했습니다.';

  @override
  String get summaryUnavailable => '요약을 불러올 수 없습니다.';

  @override
  String get failedToLoadArticle => '기사를 불러오지 못했습니다.';

  @override
  String get noArticleContent => '기사 내용이 없습니다.';

  @override
  String get translationOn => '번역 보기';

  @override
  String get originalOn => '원문 보기';

  @override
  String get contentUnavailable => '내용을 불러올 수 없습니다.';

  @override
  String get translateFullArticle => '본문 번역';

  @override
  String get translating => '번역 중...';

  @override
  String get openOriginal => '원문 열기';

  @override
  String get openOriginalArticle => '원문 기사 열기';

  @override
  String get summarySettingsTitle => '요약 설정';

  @override
  String get summaryLengthLabel => '요약 길이';

  @override
  String get summaryShort => '짧게';

  @override
  String get summaryMedium => '중간';

  @override
  String get summaryLong => '길게';

  @override
  String get summaryFull => '원문 전체 (요약 없음)';

  @override
  String get summarySave => '저장';

  @override
  String get summaryLimitedNotice =>
      '해당 기사는 앱에서 완전한 열람이 불가합니다. 아래 링크로 직접 접속하시어 읽어주시기 바랍니다.';

  @override
  String get translationLongContentNotice => '원문이 길어 요약본으로 제공됩니다.';

  @override
  String get urgentBadge => '긴급';

  @override
  String get translatingBadge => 'AI 가공 중';

  @override
  String processingEtaMinutes(int minutes) {
    return '약 $minutes분';
  }

  @override
  String get signInWithGoogle => 'Google로 로그인';

  @override
  String get tapToConnectAccount => '아래 버튼으로 계정을 연결하세요.';

  @override
  String get googleAccount => 'Google 계정';

  @override
  String get connectSync => '키워드와 토큰을 기기 간 동기화합니다.';

  @override
  String get continueWithGoogle => 'Google로 계속';

  @override
  String get tokensStore => '토큰 상점';

  @override
  String get reportArticle => '이 기사 신고하기';

  @override
  String get blockSource => '이 언론사 차단하기';

  @override
  String get blockedSourceToast => '해당 언론사를 차단했습니다.';

  @override
  String get blockedSourcesTitle => '차단된 언론사';

  @override
  String get blockedSourcesEmpty => '차단한 언론사가 없습니다.';

  @override
  String get unblockSource => '차단 해제';

  @override
  String get unblockedSourceToast => '차단을 해제했습니다.';

  @override
  String get reportedArticleToast => '기사 신고가 접수되었습니다.';

  @override
  String tokenPackLabel(int count) {
    return '$count 토큰';
  }

  @override
  String perTokenPrice(String price) {
    return '토큰당 $price';
  }

  @override
  String get language => '언어';

  @override
  String get retry => '다시 시도';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsAppearanceTitle => '모양';

  @override
  String get contactSupport => '문의하기';

  @override
  String get reviewPromptTitle => 'SCOOP은 어떠신가요?';

  @override
  String get reviewPromptBody => '앱을 평가해 주세요.';

  @override
  String get reviewPromptLater => '나중에';

  @override
  String get reviewPromptContinue => '계속';

  @override
  String get reviewHighTitle => '감사합니다!';

  @override
  String get reviewHighBody => '스토어에 리뷰를 남겨주실래요?';

  @override
  String get reviewWriteAction => '리뷰 쓰기';

  @override
  String get reviewLowTitle => '의견 보내기';

  @override
  String get reviewLowBody => '불편한 점을 알려주시면 개선에 도움이 됩니다.';

  @override
  String get bannedTitle => '계정이 정지되었습니다';

  @override
  String get bannedBody => '이 계정은 이용이 제한되었습니다. 문제가 있다면 문의하기로 알려주세요.';

  @override
  String get developerEmailTitle => '개발자 이메일';

  @override
  String get savedArticlesTitle => '저장한 기사';

  @override
  String get savedArticlesEmpty => '저장된 기사가 없습니다.';

  @override
  String get saveArticle => '저장';

  @override
  String get removeSaved => '해제';

  @override
  String get autoRenewTitle => '자동 결제';

  @override
  String get autoRenewSubtitle => '만료 1시간 전에 2토큰 결제';

  @override
  String get ledgerPurchase => '토큰 충전';

  @override
  String get ledgerSpend => '탭 구매';

  @override
  String get ledgerAutoRenew => '자동 결제';

  @override
  String ledgerSpendWithTab(Object tab) {
    return '탭 구매 · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return '자동 결제 · $tab';
  }

  @override
  String get autoRenewConfirmTitle => '자동 결제를 켤까요?';

  @override
  String get autoRenewConfirmBody => '만료 1시간 전에 2토큰을 결제하여 탭을 연장합니다.';

  @override
  String get autoRenewConfirmEnable => '켜기';

  @override
  String get autoRenewFailedTitle => '자동 결제 실패';

  @override
  String get autoRenewFailedBody => '토큰이 부족하여 자동 결제가 실패했습니다.';

  @override
  String get autoRenewSuccessTitle => '자동 결제 성공';

  @override
  String autoRenewSuccessBody(Object count) {
    return '$count개 탭 자동 결제 성공, 30일 연장되었습니다.';
  }

  @override
  String autoRenewSuccessTabsBody(Object tabs) {
    return '$tabs 자동 결제 성공, 30일 연장되었습니다.';
  }

  @override
  String get shareArticle => '공유';

  @override
  String get shareSheetTitle => '기사 공유';

  @override
  String get shareSheetShare => '앱으로 공유';

  @override
  String get shareSheetCopy => '복사하기';

  @override
  String get shareCopiedToast => '클립보드에 복사했습니다.';

  @override
  String shareMessage(String title, String url) {
    return '이 뉴스 봤어?\n$title\n$url\n\n⚡ 전 세계 핵심 뉴스, \'SCOOP\'에서 AI 번역, 요약으로 가장 빠르게 확인하세요.';
  }

  @override
  String rateLimitToast(int seconds) {
    return '업데이트 요청이 너무 많습니다. $seconds초 후 다시 시도하세요.';
  }

  @override
  String get tokenStoreSubscriptionNote => '유료 탭 1개 이상 구독 시 광고 없이 무제한 번역 가능';

  @override
  String get subscribeTabPromptTitle => '키워드 탭을 구독하시겠습니까?';

  @override
  String get insufficientTokensPromptTitle => '토큰이 부족합니다';

  @override
  String get insufficientTokensPromptBody => '토큰 상점으로 이동하시겠습니까?';

  @override
  String get bannerSponsored => '스폰서';

  @override
  String get bannerHeadline => '맞춤형 뉴스 혜택을 확인하세요';

  @override
  String get bannerAdLabel => '광고';

  @override
  String get freeTranslationTitle => '무료 번역 안내';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return '무료 번역 $used회 사용하여 $remaining회 남았습니다';
  }

  @override
  String freeTranslationRemaining(int count) {
    return '오늘 무료 번역 $count회 남았습니다';
  }

  @override
  String get freeTranslationExhausted => '오늘 무료 번역을 모두 사용했습니다';

  @override
  String get translationAdTitle => '광고';

  @override
  String get translationAdBody => '광고가 표시됩니다.';

  @override
  String get onboardingTitle1 => '전 세계 뉴스를 한 손에';

  @override
  String get onboardingBody1 =>
      '관심 있는 키워드를 등록하세요.\n미국, 영국, 일본 등 원하는 국가의 주요 뉴스를 실시간으로 확인하세요.';

  @override
  String get onboardingTitle2 => '바빠도 괜찮아요';

  @override
  String get onboardingBody2 =>
      'AI가 전 세계 뉴스를 실시간으로 요약해줍니다.\n긴 기사는 3줄로 요약하고, 해외 뉴스는 사용자의 언어로 번역합니다.';

  @override
  String get onboardingTitle3 => '관심사를 구독하세요';

  @override
  String get onboardingBody3 =>
      '토큰을 모아 더 많은 키워드 탭을 열어보세요.\n비트코인, AI 등 원하는 키워드로 나만의 뉴스 피드를 만드세요.';

  @override
  String get onboardingSkip => '건너뛰기';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingDone => '시작하기';

  @override
  String get privacyPolicyTitle => '개인정보처리방침';

  @override
  String get privacyPolicyButton => '개인정보처리방침 / 환불약관';

  @override
  String get accountDeletionTitle => '계정 탈퇴';

  @override
  String get privacyConsentTitle => '개인정보 동의';

  @override
  String get privacyConsentBody => '앱을 이용하려면 아래 필수 항목에 동의해야 합니다.';

  @override
  String get privacyConsentRequiredHint => '필수 항목에 모두 체크해야 동의할 수 있습니다.';

  @override
  String get privacyConsentPolicyLabel => '[필수] 개인정보처리방침 동의';

  @override
  String get privacyConsentOverseasLabel =>
      '[필수] 개인정보 국외이전 동의 (Google/Firebase/AdMob 등)';

  @override
  String get privacyConsentDecline => '동의거부';

  @override
  String get privacyConsentAccept => '동의';
}
