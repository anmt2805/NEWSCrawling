// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'Токены : $count';
  }

  @override
  String get breakingTab => 'Срочно';

  @override
  String get breakingTabShort => 'Срочно';

  @override
  String topBreakingHeadlines(String region) {
    return 'Главные новости · $region';
  }

  @override
  String get tapTitleToEditKeyword =>
      'Нажмите заголовок, чтобы изменить ключевое слово';

  @override
  String get noKeywordSet => 'Для этой вкладки не задано ключевое слово.';

  @override
  String get setKeyword => 'Задать ключевое слово';

  @override
  String setKeywordForTab(String tab) {
    return 'Задать ключевое слово для $tab';
  }

  @override
  String get keywordHint => 'например: AI, климат, биткоин';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get breakingNewsFixed => 'Breaking news фиксирован.';

  @override
  String fixedLabel(String label) {
    return 'Фиксировано: $label';
  }

  @override
  String get noKeyword => 'Нет ключевого слова';

  @override
  String get regionFilter => 'Фильтр региона';

  @override
  String get refresh => 'Обновить';

  @override
  String get toggleTheme => 'Переключить тему';

  @override
  String get regionSettingsTitle => 'Регион статьи';

  @override
  String get languageSettingsTitle => 'Язык приложения';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageEnglishUk => 'Английский (Великобритания)';

  @override
  String get languageKorean => 'Корейский';

  @override
  String get languageJapanese => 'Японский';

  @override
  String get languageFrench => 'Французский';

  @override
  String get languageSpanish => 'Испанский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageArabic => 'Арабский';

  @override
  String get notificationSettingsTitle => 'Настройки уведомлений';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get notificationsClear => 'Очистить все';

  @override
  String get notificationsEmpty => 'Уведомлений нет.';

  @override
  String get notificationsSeverity => 'Серьёзность';

  @override
  String get regionUnitedStates => 'США';

  @override
  String get regionUnitedKingdom => 'Великобритания';

  @override
  String get regionKorea => 'Южная Корея';

  @override
  String get regionJapan => 'Япония';

  @override
  String get regionFrance => 'Франция';

  @override
  String get regionSpain => 'Испания';

  @override
  String get regionRussia => 'Россия';

  @override
  String get regionUnitedArabEmirates => 'ОАЭ';

  @override
  String get regionAllCountries => 'Все страны';

  @override
  String get syncChoiceTitle => 'Выбор данных';

  @override
  String get syncChoiceBody =>
      'В аккаунте есть сохраненные данные. Какие использовать?';

  @override
  String get syncChoiceUseCloud => 'Использовать данные аккаунта';

  @override
  String get syncChoiceKeepLocal => 'Оставить на устройстве';

  @override
  String get notificationBreakingTitle => 'Срочные оповещения';

  @override
  String get notificationBreakingSubtitle => 'Только критические (уровень 5)';

  @override
  String get notificationKeywordTitle => 'Уведомления по ключевым словам';

  @override
  String get notificationSeverity4 => 'Уровень 4';

  @override
  String get notificationSeverity5 => 'Уровень 5';

  @override
  String get notificationSeverity4Label => 'Высокая';

  @override
  String get notificationSeverity5Label => 'Критическая';

  @override
  String get exitConfirmTitle => 'Выйти из приложения?';

  @override
  String get exitConfirmBody => 'Закрыть приложение?';

  @override
  String get exitConfirmNo => 'Нет';

  @override
  String get exitConfirmYes => 'Да';

  @override
  String get loginRequiredTitle => 'Требуется вход';

  @override
  String get loginRequiredBody => 'Войдите, чтобы покупать вкладки или токены.';

  @override
  String get loginFailedTitle => 'Не удалось войти';

  @override
  String get loginFailedBody =>
      'Не удалось войти через Google. Попробуйте ещё раз.';

  @override
  String get purchaseLockedTitle => 'Открывайте по порядку';

  @override
  String get purchaseLockedBody => 'Сначала купите предыдущую вкладку.';

  @override
  String get insufficientTokensTitle => 'Недостаточно токенов';

  @override
  String get insufficientTokensBody => 'Пополните токены для покупки вкладки.';

  @override
  String get openTokenStore => 'Открыть магазин токенов';

  @override
  String get noThanks => 'Нет';

  @override
  String get confirm => 'ОК';

  @override
  String get confirmPurchase => 'Купить';

  @override
  String purchaseTabTitle(String tab) {
    return 'Купить вкладку $tab';
  }

  @override
  String purchaseTabBody(int cost) {
    return '$cost токенов на 30 дней. Продолжить?';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'Покупка вкладки $tab';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'Покупка токенов +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return 'Баланс: $count';
  }

  @override
  String get tabUsageTitle => 'Доступ к вкладкам';

  @override
  String tabLabelWithIndex(String label) {
    return 'Вкладка $label';
  }

  @override
  String tabRemainingLabel(String time) {
    return 'Осталось $time';
  }

  @override
  String get tabLockedLabel => 'Заблокировано';

  @override
  String get tokenHistoryTitle => 'История токенов';

  @override
  String get notSignedIn => 'Не вошли';

  @override
  String get signOut => 'Выйти';

  @override
  String get noArticlesFound =>
      'Автоматически обновляется через регулярные интервалы.';

  @override
  String get failedToLoadNews => 'Не удалось загрузить новости.';

  @override
  String get summaryUnavailable => 'Резюме недоступно.';

  @override
  String get failedToLoadArticle => 'Не удалось загрузить статью.';

  @override
  String get noArticleContent => 'Нет содержания статьи.';

  @override
  String get translationOn => 'Перевод включен';

  @override
  String get originalOn => 'Оригинал включен';

  @override
  String get contentUnavailable => 'Содержимое недоступно.';

  @override
  String get translateFullArticle => 'Перевести статью полностью';

  @override
  String get translating => 'Перевод...';

  @override
  String get openOriginal => 'Открыть оригинал';

  @override
  String get openOriginalArticle => 'Открыть оригинальную статью';

  @override
  String get summarySettingsTitle => 'Настройки резюме';

  @override
  String get summaryLengthLabel => 'Длина резюме';

  @override
  String get summaryShort => 'Короткое';

  @override
  String get summaryMedium => 'Среднее';

  @override
  String get summaryLong => 'Длинное';

  @override
  String get summaryFull => 'Полный текст (без резюме)';

  @override
  String get summarySave => 'Сохранить';

  @override
  String get summaryLimitedNotice =>
      'Эта статья не может быть полностью показана в приложении. Откройте ссылку ниже, чтобы прочитать её.';

  @override
  String get translationLongContentNotice =>
      'Исходный текст слишком длинный. Показана переведенная сводка.';

  @override
  String get urgentBadge => 'Срочно';

  @override
  String get translatingBadge => 'Обработка ИИ';

  @override
  String processingEtaMinutes(int minutes) {
    return 'примерно $minutes мин';
  }

  @override
  String get signInWithGoogle => 'Войти через Google';

  @override
  String get tapToConnectAccount => 'Нажмите ниже, чтобы подключить аккаунт.';

  @override
  String get googleAccount => 'Аккаунт Google';

  @override
  String get connectSync =>
      'Синхронизация ключевых слов и токенов между устройствами.';

  @override
  String get continueWithGoogle => 'Продолжить с Google';

  @override
  String get tokensStore => 'Магазин токенов';

  @override
  String get reportArticle => 'Пожаловаться на статью';

  @override
  String get blockSource => 'Заблокировать источник';

  @override
  String get blockedSourceToast => 'Источник заблокирован.';

  @override
  String get blockedSourcesTitle => 'Заблокированные источники';

  @override
  String get blockedSourcesEmpty => 'Заблокированных источников нет.';

  @override
  String get unblockSource => 'Разблокировать';

  @override
  String get unblockedSourceToast => 'Источник разблокирован.';

  @override
  String get reportedArticleToast => 'Жалоба отправлена.';

  @override
  String tokenPackLabel(int count) {
    return '$count токенов';
  }

  @override
  String perTokenPrice(String price) {
    return '$price за токен';
  }

  @override
  String get language => 'Язык';

  @override
  String get retry => 'Повторить';

  @override
  String get purchaseFailedCheckPayment =>
      'Покупка не удалась. Проверьте доступность покупки и способ оплаты, затем попробуйте снова.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAppearanceTitle => 'Внешний вид';

  @override
  String get contactSupport => 'Связаться с поддержкой';

  @override
  String get reviewPromptTitle => 'Нравится SCOOP?';

  @override
  String get reviewPromptBody => 'Как бы вы оценили приложение?';

  @override
  String get reviewPromptLater => 'Позже';

  @override
  String get reviewPromptContinue => 'Далее';

  @override
  String get reviewHighTitle => 'Спасибо!';

  @override
  String get reviewHighBody => 'Хотите оставить отзыв в магазине?';

  @override
  String get reviewWriteAction => 'Написать отзыв';

  @override
  String get reviewLowTitle => 'Обратная связь';

  @override
  String get reviewLowBody => 'Расскажите, что можно улучшить.';

  @override
  String get bannedTitle => 'Аккаунт заблокирован';

  @override
  String get bannedBody =>
      'Этот аккаунт заблокирован. Если вы считаете, что это ошибка, свяжитесь со службой поддержки.';

  @override
  String get developerEmailTitle => 'Email разработчика';

  @override
  String get savedArticlesTitle => 'Сохранённые статьи';

  @override
  String get savedArticlesEmpty => 'Сохранённых статей нет.';

  @override
  String get saveArticle => 'Сохранить';

  @override
  String get removeSaved => 'Удалить';

  @override
  String get autoRenewTitle => 'Автопродление';

  @override
  String get autoRenewSubtitle => 'Списывать 2 токена за час до окончания';

  @override
  String get ledgerPurchase => 'Пополнение токенов';

  @override
  String get ledgerSpend => 'Покупка вкладки';

  @override
  String get ledgerAutoRenew => 'Автопродление';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'Покупка вкладки · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return 'Автопродление · $tab';
  }

  @override
  String get autoRenewConfirmTitle => 'Включить автопродление?';

  @override
  String get autoRenewConfirmBody =>
      'Мы спишем 2 токена за час до окончания, чтобы продлить доступ.';

  @override
  String get autoRenewConfirmEnable => 'Включить';

  @override
  String get autoRenewFailedTitle => 'Автопродление не удалось';

  @override
  String get autoRenewFailedBody =>
      'Автопродление не удалось из-за нехватки токенов.';

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
  String get shareArticle => 'Поделиться';

  @override
  String get shareSheetTitle => 'Поделиться новостью';

  @override
  String get shareSheetShare => 'Поделиться через приложение';

  @override
  String get shareSheetCopy => 'Копировать';

  @override
  String get shareCopiedToast => 'Скопировано в буфер.';

  @override
  String shareMessage(String title, String url) {
    return 'Видел(а) эту новость?\n$title\n$url\n\n⚡ Ключевые новости мира быстрее с AI‑переводом и краткими обзорами в «SCOOP».';
  }

  @override
  String rateLimitToast(int seconds) {
    return 'Слишком много запросов на обновление. Повторите через $seconds c.';
  }

  @override
  String get tokenStoreSubscriptionNote =>
      'Подпишитесь минимум на одну платную вкладку, чтобы получить неограниченный перевод без рекламы.';

  @override
  String get subscribeTabPromptTitle =>
      'Подписаться на эту вкладку с ключевыми словами?';

  @override
  String get insufficientTokensPromptTitle => 'Недостаточно токенов';

  @override
  String get insufficientTokensPromptBody => 'Перейти в магазин токенов?';

  @override
  String get bannerSponsored => 'Спонсировано';

  @override
  String get bannerHeadline => 'Откройте персональные новости и предложения';

  @override
  String get bannerAdLabel => 'Реклама';

  @override
  String get freeTranslationTitle => 'Бесплатные переводы';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return 'Вы использовали $used бесплатных переводов; осталось $remaining на сегодня.';
  }

  @override
  String freeTranslationRemaining(int count) {
    return 'Сегодня осталось $count бесплатных переводов.';
  }

  @override
  String get freeTranslationExhausted =>
      'Вы использовали все бесплатные переводы на сегодня.';

  @override
  String get translationAdTitle => 'Реклама';

  @override
  String get translationAdBody => 'Показывается реклама.';

  @override
  String get onboardingTitle1 => 'Все мировые новости у вас в руке';

  @override
  String get onboardingBody1 =>
      'Добавьте интересующие ключевые слова.\nСледите за новостями США, Великобритании, Японии и других стран в реальном времени.';

  @override
  String get onboardingTitle2 => 'Нет времени? Не страшно';

  @override
  String get onboardingBody2 =>
      'ИИ сокращает длинные статьи до 3 строк и переводит мировые новости на ваш язык.';

  @override
  String get onboardingTitle3 => 'Подписывайтесь на интересы';

  @override
  String get onboardingBody3 =>
      'Собирайте токены, чтобы открыть больше вкладок.\nBitcoin, AI — создайте свою ленту новостей.';

  @override
  String get onboardingSkip => 'Пропустить';

  @override
  String get onboardingNext => 'Далее';

  @override
  String get onboardingDone => 'Начать';

  @override
  String get privacyPolicyTitle => 'Политика конфиденциальности';

  @override
  String get privacyPolicyButton =>
      'Политика конфиденциальности / Условия возврата';

  @override
  String get accountDeletionTitle => 'Удалить аккаунт';

  @override
  String get privacyConsentTitle => 'Согласие на обработку данных';

  @override
  String get privacyConsentBody =>
      'Чтобы пользоваться приложением, необходимо согласиться с обязательными пунктами ниже.';

  @override
  String get privacyConsentRequiredHint =>
      'Отметьте все обязательные пункты, чтобы продолжить.';

  @override
  String get privacyConsentPolicyLabel =>
      '[Обязательно] Согласие с политикой конфиденциальности';

  @override
  String get privacyConsentOverseasLabel =>
      '[Обязательно] Согласие на международную передачу данных (Google/Firebase/AdMob)';

  @override
  String get privacyConsentDecline => 'Отказаться';

  @override
  String get privacyConsentAccept => 'Согласиться';
}
