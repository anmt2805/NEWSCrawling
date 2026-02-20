// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'الرموز : $count';
  }

  @override
  String get breakingTab => 'عاجل';

  @override
  String get breakingTabShort => 'عاجل';

  @override
  String topBreakingHeadlines(String region) {
    return 'أهم الأخبار العاجلة · $region';
  }

  @override
  String get tapTitleToEditKeyword =>
      'اضغط على العنوان لتعديل الكلمة المفتاحية';

  @override
  String get noKeywordSet => 'لا توجد كلمة مفتاحية لهذه التبويب.';

  @override
  String get setKeyword => 'تعيين كلمة مفتاحية';

  @override
  String setKeywordForTab(String tab) {
    return 'تعيين كلمة مفتاحية لـ $tab';
  }

  @override
  String get keywordHint => 'مثال: AI، المناخ، بيتكوين';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get breakingNewsFixed => 'Breaking news ثابت.';

  @override
  String fixedLabel(String label) {
    return 'ثابت: $label';
  }

  @override
  String get noKeyword => 'بدون كلمة مفتاحية';

  @override
  String get regionFilter => 'تصفية المنطقة';

  @override
  String get refresh => 'تحديث';

  @override
  String get toggleTheme => 'تبديل المظهر';

  @override
  String get regionSettingsTitle => 'منطقة المقال';

  @override
  String get languageSettingsTitle => 'لغة التطبيق';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageEnglishUk => 'الإنجليزية (المملكة المتحدة)';

  @override
  String get languageKorean => 'الكورية';

  @override
  String get languageJapanese => 'اليابانية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageSpanish => 'الإسبانية';

  @override
  String get languageRussian => 'الروسية';

  @override
  String get languageArabic => 'العربية';

  @override
  String get notificationSettingsTitle => 'إعدادات الإشعارات';

  @override
  String get notificationsTitle => 'الإشعارات';

  @override
  String get notificationsClear => 'مسح الكل';

  @override
  String get notificationsEmpty => 'لا توجد إشعارات.';

  @override
  String get notificationsSeverity => 'مستوى الخطورة';

  @override
  String get regionUnitedStates => 'الولايات المتحدة';

  @override
  String get regionUnitedKingdom => 'المملكة المتحدة';

  @override
  String get regionKorea => 'كوريا الجنوبية';

  @override
  String get regionJapan => 'اليابان';

  @override
  String get regionFrance => 'فرنسا';

  @override
  String get regionSpain => 'إسبانيا';

  @override
  String get regionRussia => 'روسيا';

  @override
  String get regionUnitedArabEmirates => 'الإمارات';

  @override
  String get regionAllCountries => 'كل الدول';

  @override
  String get syncChoiceTitle => 'اختيار البيانات';

  @override
  String get syncChoiceBody =>
      'يوجد بيانات محفوظة في الحساب. أي بيانات تريد استخدامها؟';

  @override
  String get syncChoiceUseCloud => 'استخدام بيانات الحساب';

  @override
  String get syncChoiceKeepLocal => 'الاحتفاظ بهذا الجهاز';

  @override
  String get notificationBreakingTitle => 'تنبيهات عاجلة';

  @override
  String get notificationBreakingSubtitle => 'حرج (المستوى 5) فقط';

  @override
  String get notificationKeywordTitle => 'تنبيهات الكلمات المفتاحية';

  @override
  String get notificationSeverity4 => 'المستوى 4';

  @override
  String get notificationSeverity5 => 'المستوى 5';

  @override
  String get notificationSeverity4Label => 'خطير';

  @override
  String get notificationSeverity5Label => 'خطير جدًا';

  @override
  String get exitConfirmTitle => 'إغلاق التطبيق؟';

  @override
  String get exitConfirmBody => 'هل تريد إغلاق التطبيق؟';

  @override
  String get exitConfirmNo => 'لا';

  @override
  String get exitConfirmYes => 'نعم';

  @override
  String get loginRequiredTitle => 'يلزم تسجيل الدخول';

  @override
  String get loginRequiredBody => 'سجّل الدخول لشراء التبويبات أو الرموز.';

  @override
  String get loginFailedTitle => 'فشل تسجيل الدخول';

  @override
  String get loginFailedBody => 'فشل تسجيل الدخول عبر Google. حاول مرة أخرى.';

  @override
  String get purchaseLockedTitle => 'افتح بالترتيب';

  @override
  String get purchaseLockedBody => 'يرجى فتح التبويب السابق أولًا.';

  @override
  String get insufficientTokensTitle => 'الرموز غير كافية';

  @override
  String get insufficientTokensBody =>
      'تحتاج إلى رموز إضافية لشراء هذا التبويب.';

  @override
  String get openTokenStore => 'فتح متجر الرموز';

  @override
  String get noThanks => 'لا';

  @override
  String get confirm => 'حسنًا';

  @override
  String get confirmPurchase => 'شراء';

  @override
  String purchaseTabTitle(String tab) {
    return 'شراء التبويب $tab';
  }

  @override
  String purchaseTabBody(int cost) {
    return '$cost رمزًا لمدة 30 يومًا. متابعة؟';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'شراء تبويب $tab';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'شراء رموز +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return 'الرصيد: $count';
  }

  @override
  String get tabUsageTitle => 'حالة التبويبات';

  @override
  String tabLabelWithIndex(String label) {
    return 'تبويب $label';
  }

  @override
  String tabRemainingLabel(String time) {
    return 'المتبقي $time';
  }

  @override
  String get tabLockedLabel => 'مغلق';

  @override
  String get tokenHistoryTitle => 'سجل الرموز';

  @override
  String get notSignedIn => 'غير مسجّل';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get noArticlesFound => 'يتم التحديث تلقائيًا على فترات منتظمة.';

  @override
  String get failedToLoadNews => 'تعذر تحميل الأخبار.';

  @override
  String get summaryUnavailable => 'الملخص غير متوفر.';

  @override
  String get failedToLoadArticle => 'تعذر تحميل المقال.';

  @override
  String get noArticleContent => 'لا يوجد محتوى للمقال.';

  @override
  String get translationOn => 'الترجمة مفعلة';

  @override
  String get originalOn => 'الأصل مفعّل';

  @override
  String get contentUnavailable => 'المحتوى غير متوفر.';

  @override
  String get translateFullArticle => 'ترجمة المقال بالكامل';

  @override
  String get translating => 'جارٍ الترجمة...';

  @override
  String get openOriginal => 'فتح الأصل';

  @override
  String get openOriginalArticle => 'فتح المقال الأصلي';

  @override
  String get summarySettingsTitle => 'إعدادات الملخص';

  @override
  String get summaryLengthLabel => 'طول الملخص';

  @override
  String get summaryShort => 'قصير';

  @override
  String get summaryMedium => 'متوسط';

  @override
  String get summaryLong => 'طويل';

  @override
  String get summaryFull => 'النص الكامل (بدون ملخص)';

  @override
  String get summarySave => 'حفظ';

  @override
  String get summaryLimitedNotice =>
      'لا يمكن عرض هذه المقالة كاملة داخل التطبيق. يرجى فتح الرابط أدناه لقراءتها.';

  @override
  String get translationLongContentNotice =>
      'النص الأصلي طويل جدًا. يتم عرض ملخص مترجم.';

  @override
  String get urgentBadge => 'عاجل';

  @override
  String get translatingBadge => 'جارٍ المعالجة بالذكاء الاصطناعي';

  @override
  String processingEtaMinutes(int minutes) {
    return 'حوالي $minutes دقيقة';
  }

  @override
  String get signInWithGoogle => 'تسجيل الدخول عبر Google';

  @override
  String get tapToConnectAccount => 'اضغط أدناه لربط حسابك.';

  @override
  String get googleAccount => 'حساب Google';

  @override
  String get connectSync => 'مزامنة الكلمات المفتاحية والرموز عبر الأجهزة.';

  @override
  String get continueWithGoogle => 'المتابعة باستخدام Google';

  @override
  String get tokensStore => 'متجر الرموز';

  @override
  String get reportArticle => 'الإبلاغ عن المقال';

  @override
  String get blockSource => 'حظر هذا المصدر';

  @override
  String get blockedSourceToast => 'تم حظر المصدر.';

  @override
  String get blockedSourcesTitle => 'المصادر المحظورة';

  @override
  String get blockedSourcesEmpty => 'لا توجد مصادر محظورة.';

  @override
  String get unblockSource => 'إلغاء الحظر';

  @override
  String get unblockedSourceToast => 'تم إلغاء الحظر عن المصدر.';

  @override
  String get reportedArticleToast => 'تم إرسال البلاغ.';

  @override
  String tokenPackLabel(int count) {
    return '$count رمز';
  }

  @override
  String perTokenPrice(String price) {
    return '$price لكل رمز';
  }

  @override
  String get language => 'اللغة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get purchaseFailedCheckPayment =>
      'فشلت عملية الشراء. تحقّق من إمكانية الشراء ووسيلة الدفع ثم حاول مرة أخرى.';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsAppearanceTitle => 'المظهر';

  @override
  String get contactSupport => 'الاتصال بالدعم';

  @override
  String get reviewPromptTitle => 'هل تستمتع بـ SCOOP؟';

  @override
  String get reviewPromptBody => 'كيف تقيّم التطبيق؟';

  @override
  String get reviewPromptLater => 'لاحقًا';

  @override
  String get reviewPromptContinue => 'متابعة';

  @override
  String get reviewHighTitle => 'شكرًا!';

  @override
  String get reviewHighBody => 'هل ترغب في كتابة مراجعة على المتجر؟';

  @override
  String get reviewWriteAction => 'اكتب مراجعة';

  @override
  String get reviewLowTitle => 'إرسال ملاحظات';

  @override
  String get reviewLowBody => 'أخبرنا بما يمكن تحسينه.';

  @override
  String get bannedTitle => 'تم إيقاف الحساب';

  @override
  String get bannedBody =>
      'تم إيقاف هذا الحساب. إذا كنت تعتقد أن ذلك خطأ، يرجى التواصل مع الدعم.';

  @override
  String get developerEmailTitle => 'بريد المطور الإلكتروني';

  @override
  String get savedArticlesTitle => 'المقالات المحفوظة';

  @override
  String get savedArticlesEmpty => 'لا توجد مقالات محفوظة.';

  @override
  String get saveArticle => 'حفظ';

  @override
  String get removeSaved => 'إزالة';

  @override
  String get autoRenewTitle => 'التجديد التلقائي';

  @override
  String get autoRenewSubtitle => 'خصم رمزين قبل ساعة من الانتهاء';

  @override
  String get ledgerPurchase => 'شحن الرموز';

  @override
  String get ledgerSpend => 'شراء تبويب';

  @override
  String get ledgerAutoRenew => 'التجديد التلقائي';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'شراء تبويب · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return 'التجديد التلقائي · $tab';
  }

  @override
  String get autoRenewConfirmTitle => 'تفعيل التجديد التلقائي؟';

  @override
  String get autoRenewConfirmBody =>
      'سيتم خصم الرمزين تلقائيًا قبل ساعة من انتهاء التبويب، فقط إذا كانت لديك رموز كافية.';

  @override
  String get autoRenewConfirmEnable => 'تفعيل';

  @override
  String get autoRenewFailedTitle => 'فشل التجديد التلقائي';

  @override
  String get autoRenewFailedBody =>
      'الرموز غير كافية، تم إيقاف التجديد التلقائي.';

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
  String get shareArticle => 'مشاركة';

  @override
  String get shareSheetTitle => 'مشاركة الخبر';

  @override
  String get shareSheetShare => 'مشاركة عبر تطبيق';

  @override
  String get shareSheetCopy => 'نسخ';

  @override
  String get shareCopiedToast => 'تم النسخ إلى الحافظة.';

  @override
  String shareMessage(String title, String url) {
    return 'هل رأيت هذا الخبر؟\n$title\n$url\n\n⚡ أهم أخبار العالم أسرع بترجمة وتلخيص الذكاء الاصطناعي عبر «SCOOP».';
  }

  @override
  String rateLimitToast(int seconds) {
    return 'طلبات تحديث كثيرة جدًا. حاول مرة أخرى بعد $seconds ثانية.';
  }

  @override
  String get tokenStoreSubscriptionNote =>
      'اشترك في علامة تبويب مدفوعة واحدة على الأقل للحصول على ترجمة غير محدودة بدون إعلانات.';

  @override
  String get subscribeTabPromptTitle =>
      'هل تريد الاشتراك في علامة تبويب الكلمات المفتاحية؟';

  @override
  String get insufficientTokensPromptTitle => 'الرموز غير كافية';

  @override
  String get insufficientTokensPromptBody =>
      'هل تريد الانتقال إلى متجر الرموز؟';

  @override
  String get bannerSponsored => 'برعاية';

  @override
  String get bannerHeadline => 'اكتشف مزايا الأخبار المخصصة';

  @override
  String get bannerAdLabel => 'إعلان';

  @override
  String get freeTranslationTitle => 'ترجمات مجانية';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return 'استخدمت $used ترجمة مجانية؛ يتبقى $remaining اليوم.';
  }

  @override
  String freeTranslationRemaining(int count) {
    return 'يتبقى لديك اليوم $count ترجمة مجانية.';
  }

  @override
  String get freeTranslationExhausted =>
      'لقد استخدمت جميع الترجمات المجانية اليوم.';

  @override
  String get translationAdTitle => 'إعلان';

  @override
  String get translationAdBody => 'سيتم عرض إعلان.';

  @override
  String get onboardingTitle1 => 'أخبار العالم بين يديك';

  @override
  String get onboardingBody1 =>
      'أضف الكلمات التي تهمك.\nتابع أهم الأخبار من الولايات المتحدة والمملكة المتحدة واليابان وغيرها لحظة بلحظة.';

  @override
  String get onboardingTitle2 => 'حتى لو كنت مشغولًا';

  @override
  String get onboardingBody2 =>
      'الذكاء الاصطناعي يلخّص المقالات الطويلة في 3 أسطر ويترجم الأخبار العالمية إلى لغتك.';

  @override
  String get onboardingTitle3 => 'اشترك باهتماماتك';

  @override
  String get onboardingBody3 =>
      'اجمع الرموز لفتح المزيد من التبويبات.\nبيتكوين، الذكاء الاصطناعي… أنشئ موجزك الخاص.';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingDone => 'ابدأ';

  @override
  String get privacyPolicyTitle => 'سياسة الخصوصية';

  @override
  String get privacyPolicyButton => 'سياسة الخصوصية / شروط الاسترداد';

  @override
  String get accountDeletionTitle => 'حذف الحساب';

  @override
  String get privacyConsentTitle => 'موافقة الخصوصية';

  @override
  String get privacyConsentBody =>
      'لاستخدام التطبيق، يجب الموافقة على البنود الإلزامية أدناه.';

  @override
  String get privacyConsentRequiredHint =>
      'يرجى تحديد جميع البنود الإلزامية للمتابعة.';

  @override
  String get privacyConsentPolicyLabel =>
      '[إلزامي] الموافقة على سياسة الخصوصية';

  @override
  String get privacyConsentOverseasLabel =>
      '[إلزامي] الموافقة على نقل البيانات خارج الدولة (Google/Firebase/AdMob)';

  @override
  String get privacyConsentDecline => 'رفض';

  @override
  String get privacyConsentAccept => 'موافقة';
}
