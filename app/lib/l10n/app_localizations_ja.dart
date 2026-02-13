// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'トークン : $count';
  }

  @override
  String get breakingTab => '速報';

  @override
  String get breakingTabShort => '速報';

  @override
  String topBreakingHeadlines(String region) {
    return '速報トップ · $region';
  }

  @override
  String get tapTitleToEditKeyword => 'タイトルをタップしてキーワードを編集';

  @override
  String get noKeywordSet => 'このタブにキーワードが設定されていません。';

  @override
  String get setKeyword => 'キーワードを設定';

  @override
  String setKeywordForTab(String tab) {
    return '$tab のキーワードを設定';
  }

  @override
  String get keywordHint => '例: AI、気候、ビットコイン';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get breakingNewsFixed => 'Breaking news は固定です。';

  @override
  String fixedLabel(String label) {
    return '固定: $label';
  }

  @override
  String get noKeyword => 'キーワードなし';

  @override
  String get regionFilter => '地域フィルター';

  @override
  String get refresh => '更新';

  @override
  String get toggleTheme => 'テーマ切替';

  @override
  String get regionSettingsTitle => '記事の地域';

  @override
  String get languageSettingsTitle => 'アプリ言語';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageEnglishUk => '英語(英国)';

  @override
  String get languageKorean => '韓国語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageFrench => 'フランス語';

  @override
  String get languageSpanish => 'スペイン語';

  @override
  String get languageRussian => 'ロシア語';

  @override
  String get languageArabic => 'アラビア語';

  @override
  String get notificationSettingsTitle => 'プッシュ通知設定';

  @override
  String get notificationsTitle => '通知';

  @override
  String get notificationsClear => 'すべてクリア';

  @override
  String get notificationsEmpty => '通知はありません。';

  @override
  String get notificationsSeverity => '重大度';

  @override
  String get regionUnitedStates => 'アメリカ';

  @override
  String get regionUnitedKingdom => 'イギリス';

  @override
  String get regionKorea => '韓国';

  @override
  String get regionJapan => '日本';

  @override
  String get regionFrance => 'フランス';

  @override
  String get regionSpain => 'スペイン';

  @override
  String get regionRussia => 'ロシア';

  @override
  String get regionUnitedArabEmirates => 'アラブ首長国連邦';

  @override
  String get regionAllCountries => 'すべての国';

  @override
  String get syncChoiceTitle => 'データの選択';

  @override
  String get syncChoiceBody => 'アカウントに保存されたデータが見つかりました。どちらを使いますか？';

  @override
  String get syncChoiceUseCloud => 'アカウントのデータを使用';

  @override
  String get syncChoiceKeepLocal => 'この端末のデータを使用';

  @override
  String get notificationBreakingTitle => '速報アラート';

  @override
  String get notificationBreakingSubtitle => '重大(5段階)のみ';

  @override
  String get notificationKeywordTitle => 'キーワード通知';

  @override
  String get notificationSeverity4 => 'レベル4';

  @override
  String get notificationSeverity5 => 'レベル5';

  @override
  String get notificationSeverity4Label => '深刻';

  @override
  String get notificationSeverity5Label => '極めて深刻';

  @override
  String get exitConfirmTitle => 'アプリを終了しますか？';

  @override
  String get exitConfirmBody => 'アプリを終了しますか？';

  @override
  String get exitConfirmNo => 'いいえ';

  @override
  String get exitConfirmYes => 'はい';

  @override
  String get loginRequiredTitle => 'ログインが必要です';

  @override
  String get loginRequiredBody => 'タブ購入とトークン充電のためログインしてください。';

  @override
  String get loginFailedTitle => 'ログインに失敗しました';

  @override
  String get loginFailedBody => 'Googleログインに失敗しました。もう一度お試しください。';

  @override
  String get purchaseLockedTitle => '順番に開放してください';

  @override
  String get purchaseLockedBody => '前のタブを先に購入してください。';

  @override
  String get insufficientTokensTitle => 'トークン不足';

  @override
  String get insufficientTokensBody => 'タブ購入にはトークンが必要です。';

  @override
  String get openTokenStore => 'トークンストアへ';

  @override
  String get noThanks => 'いいえ';

  @override
  String get confirm => 'OK';

  @override
  String get confirmPurchase => '購入';

  @override
  String purchaseTabTitle(String tab) {
    return 'タブ$tab購入';
  }

  @override
  String purchaseTabBody(int cost) {
    return '30日利用 $costトークン。購入しますか？';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'タブ$tab購入';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'トークン追加 +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return '保有トークン: $count';
  }

  @override
  String get tabUsageTitle => 'タブ利用状況';

  @override
  String tabLabelWithIndex(String label) {
    return '$labelタブ';
  }

  @override
  String tabRemainingLabel(String time) {
    return '残り $time';
  }

  @override
  String get tabLockedLabel => 'ロック';

  @override
  String get tokenHistoryTitle => 'トークン履歴';

  @override
  String get notSignedIn => '未ログイン';

  @override
  String get signOut => 'ログアウト';

  @override
  String get noArticlesFound => '一定の周期で自動更新されます。';

  @override
  String get failedToLoadNews => 'ニュースの読み込みに失敗しました。';

  @override
  String get summaryUnavailable => '要約を取得できません。';

  @override
  String get failedToLoadArticle => '記事の読み込みに失敗しました。';

  @override
  String get noArticleContent => '記事内容がありません。';

  @override
  String get translationOn => '翻訳表示';

  @override
  String get originalOn => '原文表示';

  @override
  String get contentUnavailable => '内容を取得できません。';

  @override
  String get translateFullArticle => '本文を翻訳';

  @override
  String get translating => '翻訳中...';

  @override
  String get openOriginal => '原文を開く';

  @override
  String get openOriginalArticle => '原文記事を開く';

  @override
  String get summarySettingsTitle => '要約設定';

  @override
  String get summaryLengthLabel => '要約の長さ';

  @override
  String get summaryShort => '短め';

  @override
  String get summaryMedium => '普通';

  @override
  String get summaryLong => '長め';

  @override
  String get summaryFull => '全文（要約なし）';

  @override
  String get summarySave => '保存';

  @override
  String get summaryLimitedNotice => 'この記事はアプリ内で全文を表示できません。下のリンクから直接開いてご覧ください。';

  @override
  String get translationLongContentNotice => '本文が長いため、要約版で提供しています。';

  @override
  String get urgentBadge => '緊急';

  @override
  String get translatingBadge => 'AI処理中';

  @override
  String processingEtaMinutes(int minutes) {
    return '約$minutes分';
  }

  @override
  String get signInWithGoogle => 'Google でログイン';

  @override
  String get tapToConnectAccount => '下のボタンでアカウントを接続します。';

  @override
  String get googleAccount => 'Google アカウント';

  @override
  String get connectSync => 'キーワードとトークンを端末間で同期します。';

  @override
  String get continueWithGoogle => 'Google で続行';

  @override
  String get tokensStore => 'トークンストア';

  @override
  String get reportArticle => 'この記事を報告する';

  @override
  String get blockSource => 'このメディアをブロック';

  @override
  String get blockedSourceToast => 'このメディアをブロックしました。';

  @override
  String get blockedSourcesTitle => 'ブロックしたメディア';

  @override
  String get blockedSourcesEmpty => 'ブロックしたメディアはありません。';

  @override
  String get unblockSource => '解除';

  @override
  String get unblockedSourceToast => 'ブロックを解除しました。';

  @override
  String get reportedArticleToast => '記事の報告を受け付けました。';

  @override
  String tokenPackLabel(int count) {
    return '$count トークン';
  }

  @override
  String perTokenPrice(String price) {
    return '1トークンあたり $price';
  }

  @override
  String get language => '言語';

  @override
  String get retry => '再試行';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsAppearanceTitle => '外観';

  @override
  String get contactSupport => 'お問い合わせ';

  @override
  String get reviewPromptTitle => 'SCOOPはいかがですか？';

  @override
  String get reviewPromptBody => 'アプリの評価をお願いします。';

  @override
  String get reviewPromptLater => '後で';

  @override
  String get reviewPromptContinue => '続ける';

  @override
  String get reviewHighTitle => 'ありがとうございます！';

  @override
  String get reviewHighBody => 'ストアにレビューを投稿しますか？';

  @override
  String get reviewWriteAction => 'レビューを書く';

  @override
  String get reviewLowTitle => 'フィードバック';

  @override
  String get reviewLowBody => '改善のため、ご意見をお聞かせください。';

  @override
  String get bannedTitle => 'アカウントが停止されました';

  @override
  String get bannedBody => 'このアカウントは停止されています。誤りだと思われる場合はサポートにお問い合わせください。';

  @override
  String get developerEmailTitle => '開発者メール';

  @override
  String get savedArticlesTitle => '保存した記事';

  @override
  String get savedArticlesEmpty => '保存した記事がありません。';

  @override
  String get saveArticle => '保存';

  @override
  String get removeSaved => '解除';

  @override
  String get autoRenewTitle => '自動更新';

  @override
  String get autoRenewSubtitle => '期限の1時間前に2トークン課金';

  @override
  String get ledgerPurchase => 'トークンチャージ';

  @override
  String get ledgerSpend => 'タブ購入';

  @override
  String get ledgerAutoRenew => '自動更新';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'タブ購入 · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return '自動更新 · $tab';
  }

  @override
  String get autoRenewConfirmTitle => '自動更新を有効にしますか？';

  @override
  String get autoRenewConfirmBody => '期限の1時間前に2トークンを課金してタブを延長します。';

  @override
  String get autoRenewConfirmEnable => '有効にする';

  @override
  String get autoRenewFailedTitle => '自動更新に失敗';

  @override
  String get autoRenewFailedBody => 'トークン不足のため自動更新に失敗しました。';

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
  String get shareArticle => '共有';

  @override
  String get shareSheetTitle => 'ニュースを共有';

  @override
  String get shareSheetShare => 'アプリで共有';

  @override
  String get shareSheetCopy => 'コピー';

  @override
  String get shareCopiedToast => 'クリップボードにコピーしました。';

  @override
  String shareMessage(String title, String url) {
    return 'このニュース見た？\n$title\n$url\n\n⚡ 世界の重要ニュースをAI翻訳・要約で最速チェック。『SCOOP』で確認しよう。';
  }

  @override
  String rateLimitToast(int seconds) {
    return '更新リクエストが多すぎます。$seconds秒後に再試行してください。';
  }

  @override
  String get tokenStoreSubscriptionNote => '有料タブを1つ以上購読すると、広告なしで無制限翻訳が可能です。';

  @override
  String get subscribeTabPromptTitle => 'キーワードタブを購読しますか？';

  @override
  String get insufficientTokensPromptTitle => 'トークンが不足しています';

  @override
  String get insufficientTokensPromptBody => 'トークンストアへ移動しますか？';

  @override
  String get bannerSponsored => 'スポンサー';

  @override
  String get bannerHeadline => 'パーソナライズされたニュース特典をチェック';

  @override
  String get bannerAdLabel => '広告';

  @override
  String get freeTranslationTitle => '無料翻訳の案内';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return '無料翻訳を$used回使用し、残り$remaining回です。';
  }

  @override
  String freeTranslationRemaining(int count) {
    return '本日の無料翻訳はあと$count回です。';
  }

  @override
  String get freeTranslationExhausted => '本日の無料翻訳はすべて使い切りました。';

  @override
  String get translationAdTitle => '広告';

  @override
  String get translationAdBody => '広告が表示されます。';

  @override
  String get onboardingTitle1 => '世界のニュースを手のひらに';

  @override
  String get onboardingBody1 => '気になるキーワードを登録。\n米国・英国・日本など主要ニュースをリアルタイムでチェック。';

  @override
  String get onboardingTitle2 => '忙しくても大丈夫';

  @override
  String get onboardingBody2 =>
      'AIが世界のニュースをリアルタイムで要約。\n長い記事は3行に、海外ニュースはあなたの言語に翻訳します。';

  @override
  String get onboardingTitle3 => '興味を購読しよう';

  @override
  String get onboardingBody3 =>
      'トークンを集めてタブを増やそう。\nビットコインやAIなど、キーワードで自分だけのニュースフィードを作成。';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingDone => '開始する';

  @override
  String get privacyPolicyTitle => 'プライバシーポリシー';

  @override
  String get privacyPolicyButton => 'プライバシーポリシー / 返金規約';

  @override
  String get accountDeletionTitle => 'アカウント削除';

  @override
  String get privacyConsentTitle => '個人情報の同意';

  @override
  String get privacyConsentBody => 'アプリを利用するには、以下の必須項目に同意する必要があります。';

  @override
  String get privacyConsentRequiredHint => '必須項目にすべてチェックすると同意できます。';

  @override
  String get privacyConsentPolicyLabel => '【必須】プライバシーポリシーに同意';

  @override
  String get privacyConsentOverseasLabel =>
      '【必須】個人情報の国外移転に同意（Google/Firebase/AdMob など）';

  @override
  String get privacyConsentDecline => '同意しない';

  @override
  String get privacyConsentAccept => '同意する';
}
