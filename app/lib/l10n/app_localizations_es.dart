// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String tokensLabel(int count) {
    return 'Tokens : $count';
  }

  @override
  String get breakingTab => 'Últimas';

  @override
  String get breakingTabShort => 'Últimas';

  @override
  String topBreakingHeadlines(String region) {
    return 'Últimas noticias · $region';
  }

  @override
  String get tapTitleToEditKeyword =>
      'Toca el título para editar la palabra clave';

  @override
  String get noKeywordSet => 'No hay palabra clave en esta pestaña.';

  @override
  String get setKeyword => 'Configurar palabra clave';

  @override
  String setKeywordForTab(String tab) {
    return 'Configurar palabra clave para $tab';
  }

  @override
  String get keywordHint => 'ej.: IA, clima, bitcoin';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get breakingNewsFixed => 'Breaking news es fijo.';

  @override
  String fixedLabel(String label) {
    return 'Fijo: $label';
  }

  @override
  String get noKeyword => 'Sin palabra clave';

  @override
  String get regionFilter => 'Filtro de región';

  @override
  String get refresh => 'Actualizar';

  @override
  String get toggleTheme => 'Cambiar tema';

  @override
  String get regionSettingsTitle => 'Región del artículo';

  @override
  String get languageSettingsTitle => 'Idioma de la app';

  @override
  String get languageEnglish => 'Inglés';

  @override
  String get languageEnglishUk => 'Inglés (UK)';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languageJapanese => 'Japonés';

  @override
  String get languageFrench => 'Francés';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageRussian => 'Ruso';

  @override
  String get languageArabic => 'Árabe';

  @override
  String get notificationSettingsTitle => 'Ajustes de notificaciones';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get notificationsClear => 'Borrar todo';

  @override
  String get notificationsEmpty => 'No hay notificaciones.';

  @override
  String get notificationsSeverity => 'Gravedad';

  @override
  String get regionUnitedStates => 'Estados Unidos';

  @override
  String get regionUnitedKingdom => 'Reino Unido';

  @override
  String get regionKorea => 'Corea del Sur';

  @override
  String get regionJapan => 'Japón';

  @override
  String get regionFrance => 'Francia';

  @override
  String get regionSpain => 'España';

  @override
  String get regionRussia => 'Rusia';

  @override
  String get regionUnitedArabEmirates => 'Emiratos Árabes Unidos';

  @override
  String get regionAllCountries => 'Todos los países';

  @override
  String get syncChoiceTitle => 'Elegir datos';

  @override
  String get syncChoiceBody =>
      'Hay datos guardados en tu cuenta. ¿Qué datos quieres usar?';

  @override
  String get syncChoiceUseCloud => 'Usar datos de la cuenta';

  @override
  String get syncChoiceKeepLocal => 'Mantener este dispositivo';

  @override
  String get notificationBreakingTitle => 'Alertas urgentes';

  @override
  String get notificationBreakingSubtitle => 'Solo crítico (nivel 5)';

  @override
  String get notificationKeywordTitle => 'Alertas por palabra clave';

  @override
  String get notificationSeverity4 => 'Nivel 4';

  @override
  String get notificationSeverity5 => 'Nivel 5';

  @override
  String get notificationSeverity4Label => 'Grave';

  @override
  String get notificationSeverity5Label => 'Muy grave';

  @override
  String get exitConfirmTitle => '¿Salir de la app?';

  @override
  String get exitConfirmBody => '¿Quieres cerrar la app?';

  @override
  String get exitConfirmNo => 'No';

  @override
  String get exitConfirmYes => 'Sí';

  @override
  String get loginRequiredTitle => 'Se requiere iniciar sesión';

  @override
  String get loginRequiredBody =>
      'Inicia sesión para comprar pestañas o tokens.';

  @override
  String get loginFailedTitle => 'Error de inicio de sesión';

  @override
  String get loginFailedBody =>
      'Falló el inicio de sesión con Google. Inténtalo de nuevo.';

  @override
  String get purchaseLockedTitle => 'Desbloqueo en orden';

  @override
  String get purchaseLockedBody => 'Primero desbloquea la pestaña anterior.';

  @override
  String get insufficientTokensTitle => 'Tokens insuficientes';

  @override
  String get insufficientTokensBody =>
      'Necesitas más tokens para comprar esta pestaña.';

  @override
  String get openTokenStore => 'Abrir tienda de tokens';

  @override
  String get noThanks => 'No';

  @override
  String get confirm => 'OK';

  @override
  String get confirmPurchase => 'Comprar';

  @override
  String purchaseTabTitle(String tab) {
    return 'Comprar pestaña $tab';
  }

  @override
  String purchaseTabBody(int cost) {
    return '$cost tokens por 30 días. ¿Continuar?';
  }

  @override
  String tabPurchaseLedger(String tab) {
    return 'Compra pestaña $tab';
  }

  @override
  String tokenPurchaseLedger(int count, String price) {
    return 'Compra de tokens +$count ($price)';
  }

  @override
  String tokensBalanceLabel(int count) {
    return 'Saldo: $count';
  }

  @override
  String get tabUsageTitle => 'Uso de pestañas';

  @override
  String tabLabelWithIndex(String label) {
    return 'Pestaña $label';
  }

  @override
  String tabRemainingLabel(String time) {
    return 'Restante $time';
  }

  @override
  String get tabLockedLabel => 'Bloqueada';

  @override
  String get tokenHistoryTitle => 'Historial de tokens';

  @override
  String get notSignedIn => 'No has iniciado sesión';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get noArticlesFound =>
      'Se actualiza automáticamente a intervalos regulares.';

  @override
  String get failedToLoadNews => 'No se pudieron cargar las noticias.';

  @override
  String get summaryUnavailable => 'Resumen no disponible.';

  @override
  String get failedToLoadArticle => 'No se pudo cargar el artículo.';

  @override
  String get noArticleContent => 'No hay contenido del artículo.';

  @override
  String get translationOn => 'Traducción activada';

  @override
  String get originalOn => 'Original activado';

  @override
  String get contentUnavailable => 'Contenido no disponible.';

  @override
  String get translateFullArticle => 'Traducir artículo completo';

  @override
  String get translating => 'Traduciendo...';

  @override
  String get openOriginal => 'Abrir original';

  @override
  String get openOriginalArticle => 'Abrir artículo original';

  @override
  String get summarySettingsTitle => 'Configuración del resumen';

  @override
  String get summaryLengthLabel => 'Longitud del resumen';

  @override
  String get summaryShort => 'Corto';

  @override
  String get summaryMedium => 'Medio';

  @override
  String get summaryLong => 'Largo';

  @override
  String get summaryFull => 'Texto completo (sin resumen)';

  @override
  String get summarySave => 'Guardar';

  @override
  String get summaryLimitedNotice =>
      'Este artículo no se puede ver completo en la app. Abre el enlace de abajo para leerlo.';

  @override
  String get translationLongContentNotice =>
      'El texto original es demasiado largo. Se muestra un resumen traducido.';

  @override
  String get urgentBadge => 'Urgente';

  @override
  String get translatingBadge => 'Procesando con IA';

  @override
  String processingEtaMinutes(int minutes) {
    return 'aprox. $minutes min';
  }

  @override
  String get signInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get tapToConnectAccount => 'Toca abajo para conectar tu cuenta.';

  @override
  String get googleAccount => 'Cuenta de Google';

  @override
  String get connectSync =>
      'Sincroniza palabras clave y tokens entre dispositivos.';

  @override
  String get continueWithGoogle => 'Continuar con Google';

  @override
  String get tokensStore => 'Tienda de tokens';

  @override
  String get reportArticle => 'Reportar este artículo';

  @override
  String get blockSource => 'Bloquear este medio';

  @override
  String get blockedSourceToast => 'Se bloqueó este medio.';

  @override
  String get blockedSourcesTitle => 'Fuentes bloqueadas';

  @override
  String get blockedSourcesEmpty => 'No hay fuentes bloqueadas.';

  @override
  String get unblockSource => 'Desbloquear';

  @override
  String get unblockedSourceToast => 'Fuente desbloqueada.';

  @override
  String get reportedArticleToast => 'El reporte fue enviado.';

  @override
  String tokenPackLabel(int count) {
    return '$count tokens';
  }

  @override
  String perTokenPrice(String price) {
    return '$price por token';
  }

  @override
  String get language => 'Idioma';

  @override
  String get retry => 'Reintentar';

  @override
  String get purchaseFailedCheckPayment =>
      'La compra falló. Verifica si la compra está disponible y el método de pago, y vuelve a intentarlo.';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsAppearanceTitle => 'Apariencia';

  @override
  String get contactSupport => 'Contactar soporte';

  @override
  String get reviewPromptTitle => '¿Te gusta SCOOP?';

  @override
  String get reviewPromptBody => '¿Qué calificación le das a la app?';

  @override
  String get reviewPromptLater => 'Más tarde';

  @override
  String get reviewPromptContinue => 'Continuar';

  @override
  String get reviewHighTitle => '¡Gracias!';

  @override
  String get reviewHighBody => '¿Quieres dejar una reseña en la tienda?';

  @override
  String get reviewWriteAction => 'Escribir reseña';

  @override
  String get reviewLowTitle => 'Enviar comentarios';

  @override
  String get reviewLowBody => 'Cuéntanos qué podemos mejorar.';

  @override
  String get bannedTitle => 'Cuenta suspendida';

  @override
  String get bannedBody =>
      'Esta cuenta ha sido suspendida. Si crees que es un error, contacta con soporte.';

  @override
  String get developerEmailTitle => 'Correo del desarrollador';

  @override
  String get savedArticlesTitle => 'Artículos guardados';

  @override
  String get savedArticlesEmpty => 'No hay artículos guardados.';

  @override
  String get saveArticle => 'Guardar';

  @override
  String get removeSaved => 'Quitar';

  @override
  String get autoRenewTitle => 'Renovación automática';

  @override
  String get autoRenewSubtitle =>
      'Cobrar 2 tokens 1 hora antes del vencimiento';

  @override
  String get ledgerPurchase => 'Recarga de tokens';

  @override
  String get ledgerSpend => 'Compra de pestaña';

  @override
  String get ledgerAutoRenew => 'Renovación automática';

  @override
  String ledgerSpendWithTab(Object tab) {
    return 'Compra de pestaña · $tab';
  }

  @override
  String ledgerAutoRenewWithTab(Object tab) {
    return 'Renovación automática · $tab';
  }

  @override
  String get autoRenewConfirmTitle => '¿Activar renovación automática?';

  @override
  String get autoRenewConfirmBody =>
      'Cobraremos 2 tokens 1 hora antes del vencimiento para mantener las pestañas activas.';

  @override
  String get autoRenewConfirmEnable => 'Activar';

  @override
  String get autoRenewFailedTitle => 'Fallo de renovación automática';

  @override
  String get autoRenewFailedBody =>
      'La renovación automática falló por falta de tokens.';

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
  String get shareArticle => 'Compartir';

  @override
  String get shareSheetTitle => 'Compartir noticia';

  @override
  String get shareSheetShare => 'Compartir con app';

  @override
  String get shareSheetCopy => 'Copiar';

  @override
  String get shareCopiedToast => 'Copiado al portapapeles.';

  @override
  String shareMessage(String title, String url) {
    return '¿Viste esta noticia?\n$title\n$url\n\n⚡ Las noticias clave del mundo, más rápido con traducción y resúmenes IA en «SCOOP».';
  }

  @override
  String rateLimitToast(int seconds) {
    return 'Demasiadas solicitudes de actualización. Intenta de nuevo en ${seconds}s.';
  }

  @override
  String get tokenStoreSubscriptionNote =>
      'Suscríbete a al menos una pestaña de pago para traducciones ilimitadas sin anuncios.';

  @override
  String get subscribeTabPromptTitle =>
      '¿Suscribirse a esta pestaña de palabras clave?';

  @override
  String get insufficientTokensPromptTitle => 'No hay suficientes tokens';

  @override
  String get insufficientTokensPromptBody => '¿Ir a la tienda de tokens?';

  @override
  String get bannerSponsored => 'Patrocinado';

  @override
  String get bannerHeadline => 'Descubre beneficios de noticias personalizados';

  @override
  String get bannerAdLabel => 'Anuncio';

  @override
  String get freeTranslationTitle => 'Traducciones gratuitas';

  @override
  String freeTranslationUsage(int used, int remaining) {
    return 'Has usado $used traducciones gratuitas; te quedan $remaining hoy.';
  }

  @override
  String freeTranslationRemaining(int count) {
    return 'Te quedan $count traducciones gratuitas hoy.';
  }

  @override
  String get freeTranslationExhausted =>
      'Has usado todas las traducciones gratuitas de hoy.';

  @override
  String get translationAdTitle => 'Anuncio';

  @override
  String get translationAdBody => 'Se mostrará un anuncio.';

  @override
  String get onboardingTitle1 => 'Todas las noticias del mundo en tu mano';

  @override
  String get onboardingBody1 =>
      'Registra tus palabras clave.\nConsulta noticias principales de EE. UU., Reino Unido, Japón y más en tiempo real.';

  @override
  String get onboardingTitle2 => '¿Sin tiempo? No pasa nada';

  @override
  String get onboardingBody2 =>
      'La IA resume artículos largos en 3 líneas y traduce noticias internacionales a tu idioma.';

  @override
  String get onboardingTitle3 => 'Suscríbete a tus intereses';

  @override
  String get onboardingBody3 =>
      'Acumula tokens para abrir más pestañas.\nBitcoin, IA… crea tu propio feed de noticias.';

  @override
  String get onboardingSkip => 'Saltar';

  @override
  String get onboardingNext => 'Siguiente';

  @override
  String get onboardingDone => 'Empezar';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';

  @override
  String get privacyPolicyButton =>
      'Política de privacidad / Condiciones de reembolso';

  @override
  String get accountDeletionTitle => 'Eliminar cuenta';

  @override
  String get privacyConsentTitle => 'Consentimiento de privacidad';

  @override
  String get privacyConsentBody =>
      'Para usar la app, debes aceptar los elementos obligatorios a continuación.';

  @override
  String get privacyConsentRequiredHint =>
      'Marca todos los elementos obligatorios para continuar.';

  @override
  String get privacyConsentPolicyLabel =>
      '[Obligatorio] Aceptar la política de privacidad';

  @override
  String get privacyConsentOverseasLabel =>
      '[Obligatorio] Aceptar la transferencia internacional de datos (Google/Firebase/AdMob)';

  @override
  String get privacyConsentDecline => 'Rechazar';

  @override
  String get privacyConsentAccept => 'Aceptar';
}
