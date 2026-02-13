import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('ru'),
  ];

  /// No description provided for @tokensLabel.
  ///
  /// In en, this message translates to:
  /// **'Tokens : {count}'**
  String tokensLabel(int count);

  /// No description provided for @breakingTab.
  ///
  /// In en, this message translates to:
  /// **'Breaking news'**
  String get breakingTab;

  /// No description provided for @breakingTabShort.
  ///
  /// In en, this message translates to:
  /// **'Breaking'**
  String get breakingTabShort;

  /// No description provided for @topBreakingHeadlines.
  ///
  /// In en, this message translates to:
  /// **'Top breaking headlines · {region}'**
  String topBreakingHeadlines(String region);

  /// No description provided for @tapTitleToEditKeyword.
  ///
  /// In en, this message translates to:
  /// **'Tap title to edit keyword'**
  String get tapTitleToEditKeyword;

  /// No description provided for @noKeywordSet.
  ///
  /// In en, this message translates to:
  /// **'No keyword set for this tab.'**
  String get noKeywordSet;

  /// No description provided for @setKeyword.
  ///
  /// In en, this message translates to:
  /// **'Set keyword'**
  String get setKeyword;

  /// No description provided for @setKeywordForTab.
  ///
  /// In en, this message translates to:
  /// **'Set keyword for {tab}'**
  String setKeywordForTab(String tab);

  /// No description provided for @keywordHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AI, climate, bitcoin'**
  String get keywordHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @breakingNewsFixed.
  ///
  /// In en, this message translates to:
  /// **'Breaking news is fixed.'**
  String get breakingNewsFixed;

  /// No description provided for @fixedLabel.
  ///
  /// In en, this message translates to:
  /// **'Fixed: {label}'**
  String fixedLabel(String label);

  /// No description provided for @noKeyword.
  ///
  /// In en, this message translates to:
  /// **'No keyword'**
  String get noKeyword;

  /// No description provided for @regionFilter.
  ///
  /// In en, this message translates to:
  /// **'Region filter'**
  String get regionFilter;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @regionSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Article region'**
  String get regionSettingsTitle;

  /// No description provided for @languageSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get languageSettingsTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishUk.
  ///
  /// In en, this message translates to:
  /// **'English (UK)'**
  String get languageEnglishUk;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @notificationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Push notification settings'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get notificationsClear;

  /// No description provided for @notificationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get notificationsEmpty;

  /// No description provided for @notificationsSeverity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get notificationsSeverity;

  /// No description provided for @regionUnitedStates.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get regionUnitedStates;

  /// No description provided for @regionUnitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get regionUnitedKingdom;

  /// No description provided for @regionKorea.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get regionKorea;

  /// No description provided for @regionJapan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get regionJapan;

  /// No description provided for @regionFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get regionFrance;

  /// No description provided for @regionSpain.
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get regionSpain;

  /// No description provided for @regionRussia.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get regionRussia;

  /// No description provided for @regionUnitedArabEmirates.
  ///
  /// In en, this message translates to:
  /// **'United Arab Emirates'**
  String get regionUnitedArabEmirates;

  /// No description provided for @regionAllCountries.
  ///
  /// In en, this message translates to:
  /// **'All countries'**
  String get regionAllCountries;

  /// No description provided for @syncChoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose data to use'**
  String get syncChoiceTitle;

  /// No description provided for @syncChoiceBody.
  ///
  /// In en, this message translates to:
  /// **'We found data saved on your account. Which data should we keep?'**
  String get syncChoiceBody;

  /// No description provided for @syncChoiceUseCloud.
  ///
  /// In en, this message translates to:
  /// **'Use account data'**
  String get syncChoiceUseCloud;

  /// No description provided for @syncChoiceKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep this device'**
  String get syncChoiceKeepLocal;

  /// No description provided for @notificationBreakingTitle.
  ///
  /// In en, this message translates to:
  /// **'Breaking alerts'**
  String get notificationBreakingTitle;

  /// No description provided for @notificationBreakingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts only'**
  String get notificationBreakingSubtitle;

  /// No description provided for @notificationKeywordTitle.
  ///
  /// In en, this message translates to:
  /// **'Keyword alerts'**
  String get notificationKeywordTitle;

  /// No description provided for @notificationSeverity4.
  ///
  /// In en, this message translates to:
  /// **'Severity 4'**
  String get notificationSeverity4;

  /// No description provided for @notificationSeverity5.
  ///
  /// In en, this message translates to:
  /// **'Severity 5'**
  String get notificationSeverity5;

  /// No description provided for @notificationSeverity4Label.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get notificationSeverity4Label;

  /// No description provided for @notificationSeverity5Label.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get notificationSeverity5Label;

  /// No description provided for @exitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit app?'**
  String get exitConfirmTitle;

  /// No description provided for @exitConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to close the app?'**
  String get exitConfirmBody;

  /// No description provided for @exitConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get exitConfirmNo;

  /// No description provided for @exitConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get exitConfirmYes;

  /// No description provided for @loginRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get loginRequiredTitle;

  /// No description provided for @loginRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Sign in to purchase tabs or tokens.'**
  String get loginRequiredBody;

  /// No description provided for @loginFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get loginFailedTitle;

  /// No description provided for @loginFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get loginFailedBody;

  /// No description provided for @purchaseLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock in order'**
  String get purchaseLockedTitle;

  /// No description provided for @purchaseLockedBody.
  ///
  /// In en, this message translates to:
  /// **'Please unlock the previous tab first.'**
  String get purchaseLockedBody;

  /// No description provided for @insufficientTokensTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough tokens'**
  String get insufficientTokensTitle;

  /// No description provided for @insufficientTokensBody.
  ///
  /// In en, this message translates to:
  /// **'You need more tokens to purchase this tab.'**
  String get insufficientTokensBody;

  /// No description provided for @openTokenStore.
  ///
  /// In en, this message translates to:
  /// **'Open token store'**
  String get openTokenStore;

  /// No description provided for @noThanks.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get noThanks;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get confirm;

  /// No description provided for @confirmPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get confirmPurchase;

  /// No description provided for @purchaseTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase tab {tab}'**
  String purchaseTabTitle(String tab);

  /// No description provided for @purchaseTabBody.
  ///
  /// In en, this message translates to:
  /// **'{cost} tokens for 30 days. Proceed?'**
  String purchaseTabBody(int cost);

  /// No description provided for @tabPurchaseLedger.
  ///
  /// In en, this message translates to:
  /// **'Tab {tab} purchase'**
  String tabPurchaseLedger(String tab);

  /// No description provided for @tokenPurchaseLedger.
  ///
  /// In en, this message translates to:
  /// **'Token purchase +{count} ({price})'**
  String tokenPurchaseLedger(int count, String price);

  /// No description provided for @tokensBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Balance: {count}'**
  String tokensBalanceLabel(int count);

  /// No description provided for @tabUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tab access'**
  String get tabUsageTitle;

  /// No description provided for @tabLabelWithIndex.
  ///
  /// In en, this message translates to:
  /// **'Tab {label}'**
  String tabLabelWithIndex(String label);

  /// No description provided for @tabRemainingLabel.
  ///
  /// In en, this message translates to:
  /// **'Remaining {time}'**
  String tabRemainingLabel(String time);

  /// No description provided for @tabLockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get tabLockedLabel;

  /// No description provided for @tokenHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Token history'**
  String get tokenHistoryTitle;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @noArticlesFound.
  ///
  /// In en, this message translates to:
  /// **'Updates automatically at regular intervals.'**
  String get noArticlesFound;

  /// No description provided for @failedToLoadNews.
  ///
  /// In en, this message translates to:
  /// **'Failed to load news.'**
  String get failedToLoadNews;

  /// No description provided for @summaryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Summary unavailable.'**
  String get summaryUnavailable;

  /// No description provided for @failedToLoadArticle.
  ///
  /// In en, this message translates to:
  /// **'Failed to load article.'**
  String get failedToLoadArticle;

  /// No description provided for @noArticleContent.
  ///
  /// In en, this message translates to:
  /// **'No article content.'**
  String get noArticleContent;

  /// No description provided for @translationOn.
  ///
  /// In en, this message translates to:
  /// **'Translation on'**
  String get translationOn;

  /// No description provided for @originalOn.
  ///
  /// In en, this message translates to:
  /// **'Original on'**
  String get originalOn;

  /// No description provided for @contentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Content unavailable.'**
  String get contentUnavailable;

  /// No description provided for @translateFullArticle.
  ///
  /// In en, this message translates to:
  /// **'Translate full article'**
  String get translateFullArticle;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translating;

  /// No description provided for @openOriginal.
  ///
  /// In en, this message translates to:
  /// **'Open original'**
  String get openOriginal;

  /// No description provided for @openOriginalArticle.
  ///
  /// In en, this message translates to:
  /// **'Open original article'**
  String get openOriginalArticle;

  /// No description provided for @summarySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary settings'**
  String get summarySettingsTitle;

  /// No description provided for @summaryLengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary length'**
  String get summaryLengthLabel;

  /// No description provided for @summaryShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get summaryShort;

  /// No description provided for @summaryMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get summaryMedium;

  /// No description provided for @summaryLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get summaryLong;

  /// No description provided for @summaryFull.
  ///
  /// In en, this message translates to:
  /// **'Full text (no summary)'**
  String get summaryFull;

  /// No description provided for @summarySave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get summarySave;

  /// No description provided for @summaryLimitedNotice.
  ///
  /// In en, this message translates to:
  /// **'This article cannot be fully viewed in the app. Please open the link below to read it.'**
  String get summaryLimitedNotice;

  /// No description provided for @translationLongContentNotice.
  ///
  /// In en, this message translates to:
  /// **'The original text is too long. A summarized translation is shown.'**
  String get translationLongContentNotice;

  /// No description provided for @urgentBadge.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get urgentBadge;

  /// No description provided for @translatingBadge.
  ///
  /// In en, this message translates to:
  /// **'AI processing'**
  String get translatingBadge;

  /// No description provided for @processingEtaMinutes.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String processingEtaMinutes(int minutes);

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @tapToConnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Tap below to connect your account.'**
  String get tapToConnectAccount;

  /// No description provided for @googleAccount.
  ///
  /// In en, this message translates to:
  /// **'Google Account'**
  String get googleAccount;

  /// No description provided for @connectSync.
  ///
  /// In en, this message translates to:
  /// **'Connect to sync keywords and tokens across devices.'**
  String get connectSync;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @tokensStore.
  ///
  /// In en, this message translates to:
  /// **'Tokens Store'**
  String get tokensStore;

  /// No description provided for @reportArticle.
  ///
  /// In en, this message translates to:
  /// **'Report article'**
  String get reportArticle;

  /// No description provided for @blockSource.
  ///
  /// In en, this message translates to:
  /// **'Block this source'**
  String get blockSource;

  /// No description provided for @blockedSourceToast.
  ///
  /// In en, this message translates to:
  /// **'Source blocked.'**
  String get blockedSourceToast;

  /// No description provided for @blockedSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked sources'**
  String get blockedSourcesTitle;

  /// No description provided for @blockedSourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No blocked sources.'**
  String get blockedSourcesEmpty;

  /// No description provided for @unblockSource.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockSource;

  /// No description provided for @unblockedSourceToast.
  ///
  /// In en, this message translates to:
  /// **'Source unblocked.'**
  String get unblockedSourceToast;

  /// No description provided for @reportedArticleToast.
  ///
  /// In en, this message translates to:
  /// **'Report submitted.'**
  String get reportedArticleToast;

  /// No description provided for @tokenPackLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Tokens'**
  String tokenPackLabel(int count);

  /// No description provided for @perTokenPrice.
  ///
  /// In en, this message translates to:
  /// **'{price} per token'**
  String perTokenPrice(String price);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceTitle;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get contactSupport;

  /// No description provided for @reviewPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoying SCOOP?'**
  String get reviewPromptTitle;

  /// No description provided for @reviewPromptBody.
  ///
  /// In en, this message translates to:
  /// **'How would you rate the app?'**
  String get reviewPromptBody;

  /// No description provided for @reviewPromptLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reviewPromptLater;

  /// No description provided for @reviewPromptContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get reviewPromptContinue;

  /// No description provided for @reviewHighTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks!'**
  String get reviewHighTitle;

  /// No description provided for @reviewHighBody.
  ///
  /// In en, this message translates to:
  /// **'Would you like to leave a review on the store?'**
  String get reviewHighBody;

  /// No description provided for @reviewWriteAction.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get reviewWriteAction;

  /// No description provided for @reviewLowTitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get reviewLowTitle;

  /// No description provided for @reviewLowBody.
  ///
  /// In en, this message translates to:
  /// **'Tell us what we can improve.'**
  String get reviewLowBody;

  /// No description provided for @bannedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account suspended'**
  String get bannedTitle;

  /// No description provided for @bannedBody.
  ///
  /// In en, this message translates to:
  /// **'This account has been suspended. If you believe this is a mistake, please contact support.'**
  String get bannedBody;

  /// No description provided for @developerEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Developer email'**
  String get developerEmailTitle;

  /// No description provided for @savedArticlesTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved articles'**
  String get savedArticlesTitle;

  /// No description provided for @savedArticlesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved articles yet.'**
  String get savedArticlesEmpty;

  /// No description provided for @saveArticle.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveArticle;

  /// No description provided for @removeSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeSaved;

  /// No description provided for @autoRenewTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal'**
  String get autoRenewTitle;

  /// No description provided for @autoRenewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Charge 2 tokens 1 hour before expiry'**
  String get autoRenewSubtitle;

  /// No description provided for @ledgerPurchase.
  ///
  /// In en, this message translates to:
  /// **'Token top-up'**
  String get ledgerPurchase;

  /// No description provided for @ledgerSpend.
  ///
  /// In en, this message translates to:
  /// **'Tab purchase'**
  String get ledgerSpend;

  /// No description provided for @ledgerAutoRenew.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal'**
  String get ledgerAutoRenew;

  /// No description provided for @ledgerSpendWithTab.
  ///
  /// In en, this message translates to:
  /// **'Tab purchase · {tab}'**
  String ledgerSpendWithTab(Object tab);

  /// No description provided for @ledgerAutoRenewWithTab.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal · {tab}'**
  String ledgerAutoRenewWithTab(Object tab);

  /// No description provided for @autoRenewConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable auto renewal?'**
  String get autoRenewConfirmTitle;

  /// No description provided for @autoRenewConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'We will charge 2 tokens 1 hour before expiry to keep tabs active.'**
  String get autoRenewConfirmBody;

  /// No description provided for @autoRenewConfirmEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get autoRenewConfirmEnable;

  /// No description provided for @autoRenewFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal failed'**
  String get autoRenewFailedTitle;

  /// No description provided for @autoRenewFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal failed due to insufficient tokens.'**
  String get autoRenewFailedBody;

  /// No description provided for @autoRenewSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto renewal success'**
  String get autoRenewSuccessTitle;

  /// No description provided for @autoRenewSuccessBody.
  ///
  /// In en, this message translates to:
  /// **'{count} tabs renewed for 30 more days.'**
  String autoRenewSuccessBody(Object count);

  /// No description provided for @autoRenewSuccessTabsBody.
  ///
  /// In en, this message translates to:
  /// **'{tabs} auto renewal succeeded and extended 30 days.'**
  String autoRenewSuccessTabsBody(Object tabs);

  /// No description provided for @shareArticle.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareArticle;

  /// No description provided for @shareSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Share news'**
  String get shareSheetTitle;

  /// No description provided for @shareSheetShare.
  ///
  /// In en, this message translates to:
  /// **'Share to app'**
  String get shareSheetShare;

  /// No description provided for @shareSheetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareSheetCopy;

  /// No description provided for @shareCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard.'**
  String get shareCopiedToast;

  /// No description provided for @shareMessage.
  ///
  /// In en, this message translates to:
  /// **'Seen this news?\n{title}\n{url}\n\n⚡ Get the world’s top stories faster with AI translation and summaries on \'SCOOP\'.'**
  String shareMessage(String title, String url);

  /// No description provided for @rateLimitToast.
  ///
  /// In en, this message translates to:
  /// **'Too many update requests. Try again in {seconds}s.'**
  String rateLimitToast(int seconds);

  /// No description provided for @tokenStoreSubscriptionNote.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to at least one paid tab for unlimited translations without ads.'**
  String get tokenStoreSubscriptionNote;

  /// No description provided for @subscribeTabPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to this keyword tab?'**
  String get subscribeTabPromptTitle;

  /// No description provided for @insufficientTokensPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Not enough tokens'**
  String get insufficientTokensPromptTitle;

  /// No description provided for @insufficientTokensPromptBody.
  ///
  /// In en, this message translates to:
  /// **'Go to the token store?'**
  String get insufficientTokensPromptBody;

  /// No description provided for @bannerSponsored.
  ///
  /// In en, this message translates to:
  /// **'Sponsored'**
  String get bannerSponsored;

  /// No description provided for @bannerHeadline.
  ///
  /// In en, this message translates to:
  /// **'Discover personalized news benefits'**
  String get bannerHeadline;

  /// No description provided for @bannerAdLabel.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get bannerAdLabel;

  /// No description provided for @freeTranslationTitle.
  ///
  /// In en, this message translates to:
  /// **'Free translations'**
  String get freeTranslationTitle;

  /// No description provided for @freeTranslationUsage.
  ///
  /// In en, this message translates to:
  /// **'You used {used} free translations; {remaining} left today.'**
  String freeTranslationUsage(int used, int remaining);

  /// No description provided for @freeTranslationRemaining.
  ///
  /// In en, this message translates to:
  /// **'You have {count} free translations left today.'**
  String freeTranslationRemaining(int count);

  /// No description provided for @freeTranslationExhausted.
  ///
  /// In en, this message translates to:
  /// **'You have used all free translations today.'**
  String get freeTranslationExhausted;

  /// No description provided for @translationAdTitle.
  ///
  /// In en, this message translates to:
  /// **'Ad'**
  String get translationAdTitle;

  /// No description provided for @translationAdBody.
  ///
  /// In en, this message translates to:
  /// **'An ad is being shown.'**
  String get translationAdBody;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'All the world’s news in your hand'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In en, this message translates to:
  /// **'Set the keywords you care about.\nSee major news in real time from the U.S., UK, Japan, and more.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'No time? You’re covered'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In en, this message translates to:
  /// **'AI summarizes long articles in 3 lines and translates global news into your language.'**
  String get onboardingBody2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to your interests'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In en, this message translates to:
  /// **'Collect tokens to unlock more keyword tabs and build your own news feed.'**
  String get onboardingBody3;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingDone.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingDone;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// No description provided for @privacyPolicyButton.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy / Refund Terms'**
  String get privacyPolicyButton;

  /// No description provided for @accountDeletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeletionTitle;

  /// No description provided for @privacyConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Consent'**
  String get privacyConsentTitle;

  /// No description provided for @privacyConsentBody.
  ///
  /// In en, this message translates to:
  /// **'To use the app, you must agree to the required items below.'**
  String get privacyConsentBody;

  /// No description provided for @privacyConsentRequiredHint.
  ///
  /// In en, this message translates to:
  /// **'Please check all required items to continue.'**
  String get privacyConsentRequiredHint;

  /// No description provided for @privacyConsentPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'[Required] Agree to Privacy Policy'**
  String get privacyConsentPolicyLabel;

  /// No description provided for @privacyConsentOverseasLabel.
  ///
  /// In en, this message translates to:
  /// **'[Required] Agree to overseas transfer of personal data (Google/Firebase/AdMob)'**
  String get privacyConsentOverseasLabel;

  /// No description provided for @privacyConsentDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get privacyConsentDecline;

  /// No description provided for @privacyConsentAccept.
  ///
  /// In en, this message translates to:
  /// **'Agree'**
  String get privacyConsentAccept;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'ru',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
