// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'Jetons : $count';
  }

  @override
  String get breakingTab => 'À la une';

  @override
  String get breakingTabShort => 'À la une';

  @override
  String topBreakingHeadlines(String region) {
    return 'Dernières infos · $region';
  }

  @override
  String get tapTitleToEditKeyword =>
      'Touchez le titre pour modifier le mot-clé';

  @override
  String get noKeywordSet => 'Aucun mot-clé défini pour cet onglet.';

  @override
  String get setKeyword => 'Définir un mot-clé';

  @override
  String setKeywordForTab(String tab) {
    return 'Définir un mot-clé pour $tab';
  }

  @override
  String get keywordHint => 'ex. IA, climat, bitcoin';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get breakingNewsFixed => 'Breaking news est fixé.';

  @override
  String fixedLabel(String label) {
    return 'Fixé : $label';
  }

  @override
  String get noKeyword => 'Aucun mot-clé';

  @override
  String get regionFilter => 'Filtre de région';

  @override
  String get refresh => 'Actualiser';

  @override
  String get toggleTheme => 'Changer le thème';

  @override
  String get regionSettingsTitle => 'Région de l\'article';

  @override
  String get languageSettingsTitle => 'Langue de l\'application';

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageEnglishUk => 'Anglais (R.-U.)';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageRussian => 'Russe';

  @override
  String get languageArabic => 'Arabe';

  @override
  String get notificationSettingsTitle => 'Paramètres des notifications';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsClear => 'Tout effacer';

  @override
  String get notificationsEmpty => 'Aucune notification.';

  @override
  String get notificationsSeverity => 'Gravité';

  @override
  String get regionUnitedStates => 'États-Unis';

  @override
  String get regionUnitedKingdom => 'Royaume-Uni';

  @override
  String get regionKorea => 'Corée du Sud';

  @override
  String get regionJapan => 'Japon';

  @override
  String get regionFrance => 'France';

  @override
  String get regionSpain => 'Espagne';

  @override
  String get regionRussia => 'Russie';

  @override
  String get regionUnitedArabEmirates => 'Émirats arabes unis';

  @override
  String get regionAllCountries => 'Tous les pays';

  @override
  String get syncChoiceTitle => 'Choisir les données';

  @override
  String get syncChoiceBody =>
      'Des données sont déjà enregistrées sur votre compte. Lesquelles utiliser ?';

  @override
  String get syncChoiceUseCloud => 'Utiliser les données du compte';

  @override
  String get syncChoiceKeepLocal => 'Garder cet appareil';

  @override
  String get notificationBreakingTitle => 'Alertes flash';

  @override
  String get notificationBreakingSubtitle => 'Critique (niveau 5) uniquement';

  @override
  String get notificationKeywordTitle => 'Alertes par mot-clé';

  @override
  String get notificationSeverity4 => 'Niveau 4';

  @override
  String get notificationSeverity5 => 'Niveau 5';

  @override
  String get notificationSeverity4Label => 'Important';

  @override
  String get notificationSeverity5Label => 'Critique';

  @override
  String get exitConfirmTitle => 'Quitter l\'application ?';

  @override
  String get exitConfirmBody => 'Voulez-vous fermer l\'application ?';

  @override
  String get exitConfirmNo => 'Non';

  @override
  String get exitConfirmYes => 'Oui';

  @override
  String get loginRequiredTitle => 'Connexion requise';

  @override
  String get loginRequiredBody =>
      'Connectez-vous pour acheter des onglets ou des jetons.';

  @override
  String get loginFailedTitle => 'Échec de la connexion';

  @override
  String get loginFailedBody =>
      'La connexion Google a échoué. Veuillez réessayer.';

  @override
  String get purchaseLockedTitle => 'Déverrouillage séquentiel';

  @override
  String get purchaseLockedBody =>
      'Déverrouillez d\'abord l\'onglet précédent.';

  @override
  String get insufficientTokensTitle => 'Jetons insuffisants';

  @override
  String get insufficientTokensBody =>
      'Rechargez des jetons pour acheter cet onglet.';

  @override
  String get openTokenStore => 'Ouvrir la boutique';

  @override
  String get noThanks => 'Non';

  @override
  String get confirm => 'OK';

  @override
  String get confirmPurchase => 'Acheter';

  @override
  String purchaseTabTitle(String tab) {
    return 'Acheter l\'onglet $tab';
  }

  @override
  String purchaseTabBody(int cost) {
    return '$cost jetons pour 30 jours. Continuer ?';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'Achat onglet $tab';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'Achat de jetons +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return 'Solde : $count';
  }

  @override
  String get tabUsageTitle => 'Accès aux onglets';

  @override
  String tabLabelWithIndex(String label) {
    return 'Onglet $label';
  }

  @override
  String tabRemainingLabel(String time) {
    return 'Reste $time';
  }

  @override
  String get tabLockedLabel => 'Verrouillé';

  @override
  String get tokenHistoryTitle => 'Historique des jetons';

  @override
  String get notSignedIn => 'Non connecté';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get noArticlesFound =>
      'Mises à jour automatiques à intervalles réguliers.';

  @override
  String get failedToLoadNews => 'Échec du chargement des actualités.';

  @override
  String get summaryUnavailable => 'Résumé indisponible.';

  @override
  String get failedToLoadArticle => 'Échec du chargement de l\'article.';

  @override
  String get noArticleContent => 'Aucun contenu d\'article.';

  @override
  String get translationOn => 'Traduction activée';

  @override
  String get originalOn => 'Original affiché';

  @override
  String get contentUnavailable => 'Contenu indisponible.';

  @override
  String get translateFullArticle => 'Traduire l\'article complet';

  @override
  String get translating => 'Traduction...';

  @override
  String get openOriginal => 'Ouvrir l\'original';

  @override
  String get openOriginalArticle => 'Ouvrir l\'article original';

  @override
  String get summarySettingsTitle => 'Paramètres du résumé';

  @override
  String get summaryLengthLabel => 'Longueur du résumé';

  @override
  String get summaryShort => 'Court';

  @override
  String get summaryMedium => 'Moyen';

  @override
  String get summaryLong => 'Long';

  @override
  String get summaryFull => 'Texte complet (sans résumé)';

  @override
  String get summarySave => 'Enregistrer';

  @override
  String get summaryLimitedNotice =>
      'Cet article ne peut pas être consulté entièrement dans l\'application. Veuillez ouvrir le lien ci-dessous pour le lire.';

  @override
  String get translationLongContentNotice =>
      'Le texte original est trop long. Un résumé traduit est affiché.';

  @override
  String get urgentBadge => 'Urgent';

  @override
  String get translatingBadge => 'Traitement IA';

  @override
  String processingEtaMinutes(int minutes) {
    return 'env. $minutes min';
  }

  @override
  String get signInWithGoogle => 'Se connecter avec Google';

  @override
  String get tapToConnectAccount =>
      'Touchez ci-dessous pour connecter votre compte.';

  @override
  String get googleAccount => 'Compte Google';

  @override
  String get connectSync =>
      'Synchronisez les mots-clés et les jetons entre appareils.';

  @override
  String get continueWithGoogle => 'Continuer avec Google';

  @override
  String get tokensStore => 'Boutique de jetons';

  @override
  String get reportArticle => 'Signaler cet article';

  @override
  String get blockSource => 'Bloquer ce média';

  @override
  String get blockedSourceToast => 'Ce média a été bloqué.';

  @override
  String get blockedSourcesTitle => 'Sources bloquées';

  @override
  String get blockedSourcesEmpty => 'Aucune source bloquée.';

  @override
  String get unblockSource => 'Débloquer';

  @override
  String get unblockedSourceToast => 'Source débloquée.';

  @override
  String get reportedArticleToast => 'Le signalement a été envoyé.';

  @override
  String tokenPackLabel(int count) {
    return '$count jetons';
  }

  @override
  String perTokenPrice(String price) {
    return '$price par jeton';
  }

  @override
  String get language => 'Langue';

  @override
  String get retry => 'Réessayer';

  @override
  String get purchaseFailedCheckPayment =>
      'L\'achat a échoué. Vérifiez la disponibilité de l\'achat et votre moyen de paiement, puis réessayez.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsAppearanceTitle => 'Apparence';

  @override
  String get contactSupport => 'Contacter l’assistance';

  @override
  String get reviewPromptTitle => 'Vous aimez SCOOP ?';

  @override
  String get reviewPromptBody => 'Quelle note donneriez-vous à l’application ?';

  @override
  String get reviewPromptLater => 'Plus tard';

  @override
  String get reviewPromptContinue => 'Continuer';

  @override
  String get reviewHighTitle => 'Merci !';

  @override
  String get reviewHighBody =>
      'Souhaitez-vous laisser un avis sur la boutique ?';

  @override
  String get reviewWriteAction => 'Écrire un avis';

  @override
  String get reviewLowTitle => 'Envoyer des commentaires';

  @override
  String get reviewLowBody => 'Dites-nous ce que nous pouvons améliorer.';

  @override
  String get bannedTitle => 'Compte suspendu';

  @override
  String get bannedBody =>
      'Ce compte a été suspendu. Si vous pensez qu\'il s\'agit d\'une erreur, veuillez contacter l’assistance.';

  @override
  String get developerEmailTitle => 'Email du développeur';

  @override
  String get savedArticlesTitle => 'Articles enregistrés';

  @override
  String get savedArticlesEmpty => 'Aucun article enregistré.';

  @override
  String get saveArticle => 'Enregistrer';

  @override
  String get removeSaved => 'Retirer';

  @override
  String get autoRenewTitle => 'Renouvellement automatique';

  @override
  String get autoRenewSubtitle =>
      'Facturer 2 jetons 1 heure avant l\'expiration';

  @override
  String get ledgerPurchase => 'Recharge de jetons';

  @override
  String get ledgerSpend => 'Achat d\'onglet';

  @override
  String get ledgerAutoRenew => 'Renouvellement automatique';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'Achat d’onglet · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return 'Renouvellement automatique · $tab';
  }

  @override
  String get autoRenewConfirmTitle => 'Activer le renouvellement automatique ?';

  @override
  String get autoRenewConfirmBody =>
      'Nous débiterons 2 jetons 1 heure avant l\'expiration pour prolonger l\'accès.';

  @override
  String get autoRenewConfirmEnable => 'Activer';

  @override
  String get autoRenewFailedTitle => 'Renouvellement automatique échoué';

  @override
  String get autoRenewFailedBody =>
      'Le renouvellement automatique a échoué faute de jetons.';

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
  String get shareArticle => 'Partager';

  @override
  String get shareSheetTitle => 'Partager l\'article';

  @override
  String get shareSheetShare => 'Partager vers une app';

  @override
  String get shareSheetCopy => 'Copier';

  @override
  String get shareCopiedToast => 'Copié dans le presse-papiers.';

  @override
  String shareMessage(String title, String url) {
    return 'Tu as vu cette actu ?\n$title\n$url\n\n⚡ Les infos essentielles du monde, plus vite grâce aux résumés et traductions IA sur « SCOOP ».';
  }

  @override
  String rateLimitToast(int seconds) {
    return 'Trop de demandes de mise à jour. Réessaie dans ${seconds}s.';
  }

  @override
  String get tokenStoreSubscriptionNote =>
      'Abonnez-vous à au moins un onglet payant pour des traductions illimitées sans publicité.';

  @override
  String get subscribeTabPromptTitle => 'S’abonner à cet onglet de mots-clés ?';

  @override
  String get insufficientTokensPromptTitle => 'Pas assez de jetons';

  @override
  String get insufficientTokensPromptBody => 'Aller à la boutique de jetons ?';

  @override
  String get bannerSponsored => 'Sponsorisé';

  @override
  String get bannerHeadline =>
      'Découvrez des avantages d’actualités personnalisés';

  @override
  String get bannerAdLabel => 'Pub';

  @override
  String get freeTranslationTitle => 'Traductions gratuites';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return 'Vous avez utilisé $used traductions gratuites ; il vous en reste $remaining aujourd’hui.';
  }

  @override
  String freeTranslationRemaining(int count) {
    return 'Il vous reste $count traductions gratuites aujourd’hui.';
  }

  @override
  String get freeTranslationExhausted =>
      'Vous avez utilisé toutes les traductions gratuites aujourd’hui.';

  @override
  String get translationAdTitle => 'Pub';

  @override
  String get translationAdBody => 'Une publicité s’affiche.';

  @override
  String get onboardingTitle1 => 'Toute l’actualité mondiale dans votre main';

  @override
  String get onboardingBody1 =>
      'Ajoutez vos mots-clés favoris.\nSuivez les grandes actus des États-Unis, du Royaume-Uni, du Japon, etc., en temps réel.';

  @override
  String get onboardingTitle2 => 'Pressé ? Aucun souci';

  @override
  String get onboardingBody2 =>
      'L’IA résume les longs articles en 3 lignes et traduit les actus internationales dans votre langue.';

  @override
  String get onboardingTitle3 => 'Abonnez-vous à vos centres d’intérêt';

  @override
  String get onboardingBody3 =>
      'Accumulez des jetons pour débloquer plus d’onglets.\nBitcoin, IA… créez votre propre fil d’actualités.';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingDone => 'Commencer';

  @override
  String get privacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get privacyPolicyButton =>
      'Politique de confidentialité / Conditions de remboursement';

  @override
  String get accountDeletionTitle => 'Supprimer le compte';

  @override
  String get privacyConsentTitle => 'Consentement à la confidentialité';

  @override
  String get privacyConsentBody =>
      'Pour utiliser l\'application, vous devez accepter les éléments obligatoires ci-dessous.';

  @override
  String get privacyConsentRequiredHint =>
      'Cochez tous les éléments obligatoires pour continuer.';

  @override
  String get privacyConsentPolicyLabel =>
      '[Obligatoire] Accepter la politique de confidentialité';

  @override
  String get privacyConsentOverseasLabel =>
      '[Obligatoire] Accepter le transfert international des données (Google/Firebase/AdMob)';

  @override
  String get privacyConsentDecline => 'Refuser';

  @override
  String get privacyConsentAccept => 'Accepter';
}
