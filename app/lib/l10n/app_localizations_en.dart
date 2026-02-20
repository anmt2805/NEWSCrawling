// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'Tokens : $count';
  }

  @override
  String get breakingTab => 'Breaking news';

  @override
  String get breakingTabShort => 'Breaking';

  @override
  String topBreakingHeadlines(String region) {
    return 'Top breaking headlines · $region';
  }

  @override
  String get tapTitleToEditKeyword => 'Tap title to edit keyword';

  @override
  String get noKeywordSet => 'No keyword set for this tab.';

  @override
  String get setKeyword => 'Set keyword';

  @override
  String setKeywordForTab(String tab) {
    return 'Set keyword for $tab';
  }

  @override
  String get keywordHint => 'e.g. AI, climate, bitcoin';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get breakingNewsFixed => 'Breaking news is fixed.';

  @override
  String fixedLabel(String label) {
    return 'Fixed: $label';
  }

  @override
  String get noKeyword => 'No keyword';

  @override
  String get regionFilter => 'Region filter';

  @override
  String get refresh => 'Refresh';

  @override
  String get toggleTheme => 'Toggle theme';

  @override
  String get regionSettingsTitle => 'Article region';

  @override
  String get languageSettingsTitle => 'App language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishUk => 'English (UK)';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageFrench => 'French';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get notificationSettingsTitle => 'Push notification settings';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsClear => 'Clear';

  @override
  String get notificationsEmpty => 'No notifications yet.';

  @override
  String get notificationsSeverity => 'Severity';

  @override
  String get regionUnitedStates => 'United States';

  @override
  String get regionUnitedKingdom => 'United Kingdom';

  @override
  String get regionKorea => 'South Korea';

  @override
  String get regionJapan => 'Japan';

  @override
  String get regionFrance => 'France';

  @override
  String get regionSpain => 'Spain';

  @override
  String get regionRussia => 'Russia';

  @override
  String get regionUnitedArabEmirates => 'United Arab Emirates';

  @override
  String get regionAllCountries => 'All countries';

  @override
  String get syncChoiceTitle => 'Choose data to use';

  @override
  String get syncChoiceBody =>
      'We found data saved on your account. Which data should we keep?';

  @override
  String get syncChoiceUseCloud => 'Use account data';

  @override
  String get syncChoiceKeepLocal => 'Keep this device';

  @override
  String get notificationBreakingTitle => 'Breaking alerts';

  @override
  String get notificationBreakingSubtitle => 'Critical alerts only';

  @override
  String get notificationKeywordTitle => 'Keyword alerts';

  @override
  String get notificationSeverity4 => 'Severity 4';

  @override
  String get notificationSeverity5 => 'Severity 5';

  @override
  String get notificationSeverity4Label => 'High';

  @override
  String get notificationSeverity5Label => 'Critical';

  @override
  String get exitConfirmTitle => 'Exit app?';

  @override
  String get exitConfirmBody => 'Do you want to close the app?';

  @override
  String get exitConfirmNo => 'No';

  @override
  String get exitConfirmYes => 'Yes';

  @override
  String get loginRequiredTitle => 'Sign-in required';

  @override
  String get loginRequiredBody => 'Sign in to purchase tabs or tokens.';

  @override
  String get loginFailedTitle => 'Sign-in failed';

  @override
  String get loginFailedBody => 'Google sign-in failed. Please try again.';

  @override
  String get purchaseLockedTitle => 'Unlock in order';

  @override
  String get purchaseLockedBody => 'Please unlock the previous tab first.';

  @override
  String get insufficientTokensTitle => 'Not enough tokens';

  @override
  String get insufficientTokensBody =>
      'You need more tokens to purchase this tab.';

  @override
  String get openTokenStore => 'Open token store';

  @override
  String get noThanks => 'No';

  @override
  String get confirm => 'OK';

  @override
  String get confirmPurchase => 'Purchase';

  @override
  String purchaseTabTitle(String tab) {
    return 'Purchase tab $tab';
  }

  @override
  String purchaseTabBody(int cost) {
    return '$cost tokens for 30 days. Proceed?';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'Tab $tab purchase';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'Token purchase +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return 'Balance: $count';
  }

  @override
  String get tabUsageTitle => 'Tab access';

  @override
  String tabLabelWithIndex(String label) {
    return 'Tab $label';
  }

  @override
  String tabRemainingLabel(String time) {
    return 'Remaining $time';
  }

  @override
  String get tabLockedLabel => 'Locked';

  @override
  String get tokenHistoryTitle => 'Token history';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get signOut => 'Sign out';

  @override
  String get noArticlesFound => 'Updates automatically at regular intervals.';

  @override
  String get failedToLoadNews => 'Failed to load news.';

  @override
  String get summaryUnavailable => 'Summary unavailable.';

  @override
  String get failedToLoadArticle => 'Failed to load article.';

  @override
  String get noArticleContent => 'No article content.';

  @override
  String get translationOn => 'Translation on';

  @override
  String get originalOn => 'Original on';

  @override
  String get contentUnavailable => 'Content unavailable.';

  @override
  String get translateFullArticle => 'Translate full article';

  @override
  String get translating => 'Translating...';

  @override
  String get openOriginal => 'Open original';

  @override
  String get openOriginalArticle => 'Open original article';

  @override
  String get summarySettingsTitle => 'Summary settings';

  @override
  String get summaryLengthLabel => 'Summary length';

  @override
  String get summaryShort => 'Short';

  @override
  String get summaryMedium => 'Medium';

  @override
  String get summaryLong => 'Long';

  @override
  String get summaryFull => 'Full text (no summary)';

  @override
  String get summarySave => 'Save';

  @override
  String get summaryLimitedNotice =>
      'This article cannot be fully viewed in the app. Please open the link below to read it.';

  @override
  String get translationLongContentNotice =>
      'The original text is too long. A summarized translation is shown.';

  @override
  String get urgentBadge => 'Urgent';

  @override
  String get translatingBadge => 'AI processing';

  @override
  String processingEtaMinutes(int minutes) {
    return 'about $minutes min';
  }

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get tapToConnectAccount => 'Tap below to connect your account.';

  @override
  String get googleAccount => 'Google Account';

  @override
  String get connectSync =>
      'Connect to sync keywords and tokens across devices.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get tokensStore => 'Tokens Store';

  @override
  String get reportArticle => 'Report article';

  @override
  String get blockSource => 'Block this source';

  @override
  String get blockedSourceToast => 'Source blocked.';

  @override
  String get blockedSourcesTitle => 'Blocked sources';

  @override
  String get blockedSourcesEmpty => 'No blocked sources.';

  @override
  String get unblockSource => 'Unblock';

  @override
  String get unblockedSourceToast => 'Source unblocked.';

  @override
  String get reportedArticleToast => 'Report submitted.';

  @override
  String tokenPackLabel(int count) {
    return '$count Tokens';
  }

  @override
  String perTokenPrice(String price) {
    return '$price per token';
  }

  @override
  String get language => 'Language';

  @override
  String get retry => 'Retry';

  @override
  String get purchaseFailedCheckPayment =>
      'Purchase failed. Please check purchase availability and payment method, then try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceTitle => 'Appearance';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get reviewPromptTitle => 'Enjoying SCOOP?';

  @override
  String get reviewPromptBody => 'How would you rate the app?';

  @override
  String get reviewPromptLater => 'Later';

  @override
  String get reviewPromptContinue => 'Continue';

  @override
  String get reviewHighTitle => 'Thanks!';

  @override
  String get reviewHighBody => 'Would you like to leave a review on the store?';

  @override
  String get reviewWriteAction => 'Write a review';

  @override
  String get reviewLowTitle => 'Send feedback';

  @override
  String get reviewLowBody => 'Tell us what we can improve.';

  @override
  String get bannedTitle => 'Account suspended';

  @override
  String get bannedBody =>
      'This account has been suspended. If you believe this is a mistake, please contact support.';

  @override
  String get developerEmailTitle => 'Developer email';

  @override
  String get savedArticlesTitle => 'Saved articles';

  @override
  String get savedArticlesEmpty => 'No saved articles yet.';

  @override
  String get saveArticle => 'Save';

  @override
  String get removeSaved => 'Remove';

  @override
  String get autoRenewTitle => 'Auto renewal';

  @override
  String get autoRenewSubtitle => 'Charge 2 tokens 1 hour before expiry';

  @override
  String get ledgerPurchase => 'Token top-up';

  @override
  String get ledgerSpend => 'Tab purchase';

  @override
  String get ledgerAutoRenew => 'Auto renewal';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'Tab purchase · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return 'Auto renewal · $tab';
  }

  @override
  String get autoRenewConfirmTitle => 'Enable auto renewal?';

  @override
  String get autoRenewConfirmBody =>
      'We will charge 2 tokens 1 hour before expiry to keep tabs active.';

  @override
  String get autoRenewConfirmEnable => 'Enable';

  @override
  String get autoRenewFailedTitle => 'Auto renewal failed';

  @override
  String get autoRenewFailedBody =>
      'Auto renewal failed due to insufficient tokens.';

  @override
  String get autoRenewSuccessTitle => 'Auto renewal success';

  @override
  String autoRenewSuccessBody(Object count) {
    return '$count tabs renewed for 30 more days.';
  }

  @override
  String autoRenewSuccessTabsBody(Object tabs) {
    return '$tabs auto renewal succeeded and extended 30 days.';
  }

  @override
  String get shareArticle => 'Share';

  @override
  String get shareSheetTitle => 'Share news';

  @override
  String get shareSheetShare => 'Share to app';

  @override
  String get shareSheetCopy => 'Copy';

  @override
  String get shareCopiedToast => 'Copied to clipboard.';

  @override
  String shareMessage(String title, String url) {
    return 'Seen this news?\n$title\n$url\n\n⚡ Get the world’s top stories faster with AI translation and summaries on \'SCOOP\'.';
  }

  @override
  String rateLimitToast(int seconds) {
    return 'Too many update requests. Try again in ${seconds}s.';
  }

  @override
  String get tokenStoreSubscriptionNote =>
      'Subscribe to at least one paid tab for unlimited translations without ads.';

  @override
  String get subscribeTabPromptTitle => 'Subscribe to this keyword tab?';

  @override
  String get insufficientTokensPromptTitle => 'Not enough tokens';

  @override
  String get insufficientTokensPromptBody => 'Go to the token store?';

  @override
  String get bannerSponsored => 'Sponsored';

  @override
  String get bannerHeadline => 'Discover personalized news benefits';

  @override
  String get bannerAdLabel => 'Ad';

  @override
  String get freeTranslationTitle => 'Free translations';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return 'You used $used free translations; $remaining left today.';
  }

  @override
  String freeTranslationRemaining(int count) {
    return 'You have $count free translations left today.';
  }

  @override
  String get freeTranslationExhausted =>
      'You have used all free translations today.';

  @override
  String get translationAdTitle => 'Ad';

  @override
  String get translationAdBody => 'An ad is being shown.';

  @override
  String get onboardingTitle1 => 'All the world’s news in your hand';

  @override
  String get onboardingBody1 =>
      'Set the keywords you care about.\nSee major news in real time from the U.S., UK, Japan, and more.';

  @override
  String get onboardingTitle2 => 'No time? You’re covered';

  @override
  String get onboardingBody2 =>
      'AI summarizes long articles in 3 lines and translates global news into your language.';

  @override
  String get onboardingTitle3 => 'Subscribe to your interests';

  @override
  String get onboardingBody3 =>
      'Collect tokens to unlock more keyword tabs and build your own news feed.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingDone => 'Get started';

  @override
  String get privacyPolicyTitle => 'Privacy Policy';

  @override
  String get privacyPolicyButton => 'Privacy Policy / Refund Terms';

  @override
  String get accountDeletionTitle => 'Delete account';

  @override
  String get privacyConsentTitle => 'Privacy Consent';

  @override
  String get privacyConsentBody =>
      'To use the app, you must agree to the required items below.';

  @override
  String get privacyConsentRequiredHint =>
      'Please check all required items to continue.';

  @override
  String get privacyConsentPolicyLabel => '[Required] Agree to Privacy Policy';

  @override
  String get privacyConsentOverseasLabel =>
      '[Required] Agree to overseas transfer of personal data (Google/Firebase/AdMob)';

  @override
  String get privacyConsentDecline => 'Decline';

  @override
  String get privacyConsentAccept => 'Agree';
}
