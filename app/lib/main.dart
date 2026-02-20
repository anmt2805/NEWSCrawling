import 'dart:convert';
import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:news_crawl/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:introduction_screen/introduction_screen.dart';
import 'package:in_app_purchase/in_app_purchase.dart'
    hide ProductDetailsResponse;
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_onestore_inapp/flutter_onestore_inapp.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:url_launcher/url_launcher.dart';

const String apiBaseUrl =
    'https://news-crawl-server-1008445727632.asia-northeast3.run.app';
const int _dailyFreeTranslationLimit = 3;
const String _freeTranslationDateKey = 'freeTranslationDate';
const String _freeTranslationUsedKey = 'freeTranslationUsed';
const String _guestSyncAtKey = 'guestSyncAt';
const String _admobBannerId = 'ca-app-pub-4338188988925499/9794490659';
const String _admobRewardedId = 'ca-app-pub-4338188988925499/2298325772';
const String _unityGameIdAndroid = String.fromEnvironment(
  'UNITY_GAME_ID_ANDROID',
  defaultValue: '6032938',
);
const String _unityBannerPlacementIdAndroid = String.fromEnvironment(
  'UNITY_BANNER_PLACEMENT_ID_ANDROID',
  defaultValue: 'FALLBACKBANNER',
);
const String _unityRewardedPlacementIdAndroid = String.fromEnvironment(
  'UNITY_REWARDED_PLACEMENT_ID_ANDROID',
  defaultValue: 'FALLBACKAI',
);
const bool _unityAdsTestMode = bool.fromEnvironment(
  'UNITY_ADS_TEST_MODE',
  defaultValue: false,
);
const bool _forceUnityAdsFallback = bool.fromEnvironment(
  'FORCE_UNITY_ADS_FALLBACK',
  defaultValue: false,
);
const bool _adsDebugToast = bool.fromEnvironment(
  'ADS_DEBUG_TOAST',
  defaultValue: false,
);
const String _accountDeletionUrl = 'https://forms.gle/USYUJGbfAmnwfQZZA';
const String _googleWebClientId =
    '442218050266-7t8egh8fpn4jvq1vhqs1kn8bdlhmocro.apps.googleusercontent.com';

const Duration _reviewPromptCooldown = Duration(days: 30);
const int _reviewPromptLaunchThreshold = 100;
const String _reviewFirstSeenAtKey = 'reviewFirstSeenAtMs';
const String _reviewLaunchCountKey = 'reviewLaunchCount';
const String _reviewLastPromptAtKey = 'reviewLastPromptAtMs';
const String _reviewLaunchCountAtPromptKey = 'reviewLaunchCountAtPrompt';
const String _reviewWriteClickedKey = 'reviewWriteClicked';
const String _reviewLastRatingKey = 'reviewLastRating';

enum _ReviewPromptAction { dismiss, writeReview, contactSupport }

class _ReviewPromptResult {
  const _ReviewPromptResult({required this.rating, required this.action});

  final int rating;
  final _ReviewPromptAction action;
}

enum _AndroidBillingStore { play, onestore }

class _StoreProduct {
  const _StoreProduct({
    required this.id,
    required this.title,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    this.playProduct,
    this.oneStoreProduct,
  });

  final String id;
  final String title;
  final String price;
  final double rawPrice;
  final String currencyCode;
  final ProductDetails? playProduct;
  final ProductDetail? oneStoreProduct;
}

String _privacyPolicyAssetForLanguage(String language) {
  final code = language.toLowerCase().split('-').first;
  switch (code) {
    case 'ko':
      return 'assets/privacy/privacy_ko.txt';
    case 'ja':
      return 'assets/privacy/privacy_ja.txt';
    case 'fr':
      return 'assets/privacy/privacy_fr.txt';
    case 'es':
      return 'assets/privacy/privacy_es.txt';
    case 'ru':
      return 'assets/privacy/privacy_ru.txt';
    case 'ar':
      return 'assets/privacy/privacy_ar.txt';
    default:
      return 'assets/privacy/privacy_en.txt';
  }
}

bool _privacyPolicyIsRtl(String language) {
  return language.toLowerCase().split('-').first == 'ar';
}

Future<String> _loadPrivacyPolicyText(String language) async {
  final asset = _privacyPolicyAssetForLanguage(language);
  try {
    return await rootBundle.loadString(asset);
  } catch (_) {
    return rootBundle.loadString(_privacyPolicyAssetForLanguage('en'));
  }
}

const Duration _serverTimeSyncInterval = Duration(hours: 6);
const String _serverTimeOffsetKey = 'serverTimeOffsetMs';
const String _serverTimeSyncKey = 'serverTimeSyncAt';
const String _notificationLangHistoryKey = 'notificationLangHistory';

int _serverTimeOffsetMs = 0;
int _lastRateLimitToastAtMs = 0;
Completer<bool>? _unityAdsInitCompleter;
bool _unityAdsInitialized = false;

bool get _unityAdsSupportedPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android;
}

bool get _unityAdsConfigured {
  return _unityAdsSupportedPlatform && _unityGameIdAndroid.trim().isNotEmpty;
}

bool get _unityBannerFallbackConfigured {
  return _unityAdsConfigured &&
      _unityBannerPlacementIdAndroid.trim().isNotEmpty;
}

bool get _unityRewardedFallbackConfigured {
  return _unityAdsConfigured &&
      _unityRewardedPlacementIdAndroid.trim().isNotEmpty;
}

Future<bool> _ensureUnityAdsInitialized() async {
  if (!_unityAdsConfigured) return false;
  if (_unityAdsInitialized) {
    try {
      final initialized = await UnityAds.isInitialized();
      if (initialized) {
        return true;
      }
    } catch (_) {}
    _unityAdsInitialized = false;
  }
  if (_unityAdsInitCompleter != null) {
    return _unityAdsInitCompleter!.future;
  }
  final completer = Completer<bool>();
  _unityAdsInitCompleter = completer;
  try {
    await UnityAds.init(
      gameId: _unityGameIdAndroid,
      testMode: _unityAdsTestMode,
      onComplete: (_) {
        if (_unityAdsInitialized) return;
        _unityAdsInitialized = true;
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onFailed: (error, message) {
        debugPrint('[AD DEBUG] Unity Ads init failed [$error] $message');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );
  } catch (error) {
    debugPrint('[AD DEBUG] Unity Ads init exception: $error');
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }
  var timedOut = false;
  final ok = await completer.future.timeout(
    const Duration(seconds: 12),
    onTimeout: () {
      timedOut = true;
      return false;
    },
  );
  var initialized = ok;
  if (timedOut) {
    // Some devices miss the init callback. Poll SDK state briefly before failing.
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await UnityAds.isInitialized()) {
          initialized = true;
          break;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
  if (timedOut && !initialized) {
    debugPrint('[AD DEBUG] Unity Ads init timed out. SDK not initialized yet.');
  }
  if (!initialized) {
    debugPrint('[AD DEBUG] Unity Ads init failed.');
    _unityAdsInitCompleter = null;
    _unityAdsInitialized = false;
    if (!completer.isCompleted) {
      completer.complete(false);
    }
    return false;
  }
  _unityAdsInitialized = true;
  if (!completer.isCompleted) {
    completer.complete(true);
  }
  return true;
}

DateTime _serverNow() {
  final now = DateTime.now();
  return DateTime.fromMillisecondsSinceEpoch(
    now.millisecondsSinceEpoch + _serverTimeOffsetMs,
  );
}

Future<void> _loadServerTimeOffset() async {
  final prefs = await SharedPreferences.getInstance();
  _serverTimeOffsetMs = prefs.getInt(_serverTimeOffsetKey) ?? 0;
}

Future<void> _updateServerTimeOffset(int serverTimeMs) async {
  final deviceNow = DateTime.now().millisecondsSinceEpoch;
  _serverTimeOffsetMs = serverTimeMs - deviceNow;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_serverTimeOffsetKey, _serverTimeOffsetMs);
  await prefs.setInt(_serverTimeSyncKey, deviceNow);
}

Future<void> _syncServerTime({bool force = false}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_serverTimeSyncKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force &&
        lastSync > 0 &&
        nowMs - lastSync < _serverTimeSyncInterval.inMilliseconds) {
      _serverTimeOffsetMs = prefs.getInt(_serverTimeOffsetKey) ?? 0;
      return;
    }
    final response = await http.get(Uri.parse('$apiBaseUrl/time'));
    if (response.statusCode != 200) return;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final serverTimeMs = int.tryParse(
        decoded['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
    }
  } catch (_) {}
}

DateTime? _parseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}

bool _isRtlLanguage(String language) {
  return language.toLowerCase().split('-').first == 'ar';
}

final ValueNotifier<bool> _bannedNotifier = ValueNotifier<bool>(false);

void _markUserBanned() {
  if (_bannedNotifier.value) return;
  _bannedNotifier.value = true;
  try {
    FirebaseAuth.instance.signOut();
  } catch (_) {}
  final navigator = navigatorKey.currentState;
  if (navigator != null) {
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BannedPage()),
      (route) => false,
    );
  }
}

void _handleBannedResponse(int statusCode, Map<String, dynamic> payload) {
  final error = payload['error']?.toString() ?? '';
  if (statusCode == 403 && error == 'user_banned') {
    _markUserBanned();
  }
}

class MaintenanceStatus {
  MaintenanceStatus({
    required this.enabled,
    required this.active,
    this.startAt,
    this.endAt,
    this.storeUrlAndroid,
    this.storeUrlIos,
  });

  final bool enabled;
  final bool active;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? storeUrlAndroid;
  final String? storeUrlIos;

  factory MaintenanceStatus.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return MaintenanceStatus(enabled: false, active: false);
    }
    return MaintenanceStatus(
      enabled: json['enabled'] == true,
      active: json['active'] == true,
      startAt: _parseIsoDate(json['startAt']?.toString()),
      endAt: _parseIsoDate(json['endAt']?.toString()),
      storeUrlAndroid: (json['storeUrlAndroid']?.toString() ?? '').trim(),
      storeUrlIos: (json['storeUrlIos']?.toString() ?? '').trim(),
    );
  }
}

class _MaintenanceCopy {
  const _MaintenanceCopy({
    required this.title,
    required this.body,
    required this.detail,
    required this.storeButton,
    required this.exitButton,
    required this.windowLabel,
    required this.untilLabel,
  });

  final String title;
  final String body;
  final String detail;
  final String storeButton;
  final String exitButton;
  final String windowLabel;
  final String untilLabel;
}

_MaintenanceCopy _maintenanceCopyForLanguage(String language) {
  switch (language.toLowerCase().split('-').first) {
    case 'ko':
      return const _MaintenanceCopy(
        title: '서버 점검 중',
        body: '현재 서버 점검 중입니다.',
        detail: '잠시 후 다시 접속해 주세요.',
        storeButton: '앱스토어 열기',
        exitButton: '앱 종료',
        windowLabel: '점검 시간',
        untilLabel: '점검 종료',
      );
    case 'ja':
      return const _MaintenanceCopy(
        title: 'メンテナンス中',
        body: 'ただいまサーバーメンテナンス中です。',
        detail: 'しばらくしてから再度お試しください。',
        storeButton: 'ストアを開く',
        exitButton: 'アプリを終了',
        windowLabel: 'メンテナンス時間',
        untilLabel: '終了予定',
      );
    case 'fr':
      return const _MaintenanceCopy(
        title: 'Maintenance',
        body: 'Le service est en maintenance.',
        detail: 'Veuillez réessayer plus tard.',
        storeButton: 'Ouvrir l’App Store',
        exitButton: 'Quitter',
        windowLabel: 'Période',
        untilLabel: 'Jusqu’au',
      );
    case 'es':
      return const _MaintenanceCopy(
        title: 'Mantenimiento',
        body: 'El servicio está en mantenimiento.',
        detail: 'Vuelve a intentarlo más tarde.',
        storeButton: 'Abrir App Store',
        exitButton: 'Salir',
        windowLabel: 'Horario',
        untilLabel: 'Hasta',
      );
    case 'ru':
      return const _MaintenanceCopy(
        title: 'Техническое обслуживание',
        body: 'Сервис на обслуживании.',
        detail: 'Пожалуйста, зайдите позже.',
        storeButton: 'Открыть магазин',
        exitButton: 'Выйти',
        windowLabel: 'Время',
        untilLabel: 'До',
      );
    case 'ar':
      return const _MaintenanceCopy(
        title: 'الصيانة',
        body: 'الخدمة قيد الصيانة.',
        detail: 'يرجى المحاولة لاحقًا.',
        storeButton: 'فتح المتجر',
        exitButton: 'إغلاق التطبيق',
        windowLabel: 'وقت الصيانة',
        untilLabel: 'حتى',
      );
    case 'en':
    default:
      return const _MaintenanceCopy(
        title: 'Maintenance Mode',
        body: 'The service is under maintenance.',
        detail: 'Please try again later.',
        storeButton: 'Open App Store',
        exitButton: 'Exit',
        windowLabel: 'Scheduled',
        untilLabel: 'Until',
      );
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
      'severity_alerts',
      'Severity alerts',
      description: 'Notifications for severity 4+ news',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

class NotificationService {
  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    final settings = InitializationSettings(android: androidSettings);
    await _localNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        handleNotificationResponse(response.payload);
      },
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_notificationChannel);
  }

  static Future<void> show(
    RemoteMessage message,
    int severity,
    String payload,
  ) async {
    final title = message.notification?.title ?? 'Breaking News';
    final body = message.notification?.body ?? '';

    // [추가] payload에서 url을 꺼내 고유 ID로 사용
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      final data = jsonDecode(payload);
      if (data['url'] != null) {
        // URL을 숫자로 변환하여 고유 ID 생성 (겹침 방지)
        notificationId = data['url'].toString().hashCode;
      }
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      _notificationChannel.id,
      _notificationChannel.name,
      channelDescription: _notificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: const DefaultStyleInformation(true, true),
    );

    await _localNotificationsPlugin.show(
      notificationId, // [수정] 여기가 기존엔 시간(초)이었습니다.
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> showLocal({
    required String title,
    required String body,
    required int severity,
    required String payload,
  }) async {
    // [추가] payload에서 url을 꺼내 고유 ID로 사용
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      final data = jsonDecode(payload);
      if (data['url'] != null) {
        notificationId = data['url'].toString().hashCode;
      }
    } catch (_) {}

    final androidDetails = AndroidNotificationDetails(
      _notificationChannel.id,
      _notificationChannel.name,
      channelDescription: _notificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: const DefaultStyleInformation(true, true),
    );

    await _localNotificationsPlugin.show(
      notificationId, // [수정] 고유 ID 적용
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static void handleNotificationResponse(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final payloadMap = jsonDecode(payload);
      final url = payloadMap['url']?.toString() ?? '';
      if (url.isEmpty) return;
      final language = navigatorKey.currentContext != null
          ? Localizations.localeOf(navigatorKey.currentContext!).languageCode
          : 'en';
      final item = NewsItem(
        title: payloadMap['title']?.toString() ?? 'Notification',
        summary: payloadMap['summary']?.toString() ?? '',
        content: payloadMap['summary']?.toString() ?? '',
        url: url,
        resolvedUrl: url,
        sourceUrl: url,
        source: payloadMap['source']?.toString() ?? 'Notification',
        publishedAt: DateTime.now().toIso8601String(),
        severity: int.tryParse(payloadMap['severity']?.toString() ?? '') ?? 5,
      );
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ArticlePage(item: item, language: language),
        ),
      );
    } catch (_) {}
  }
}

class NotificationPreferences {
  NotificationPreferences({
    required this.breakingEnabled,
    required this.keywordSeverity4,
    required this.keywordSeverity5,
  });

  bool breakingEnabled;
  bool keywordSeverity4;
  bool keywordSeverity5;

  Map<String, dynamic> toJson() => {
    'breakingEnabled': breakingEnabled,
    'keywordSeverity4': keywordSeverity4,
    'keywordSeverity5': keywordSeverity5,
  };

  static NotificationPreferences fromJson(Map<String, dynamic>? json) {
    return NotificationPreferences(
      breakingEnabled: json?['breakingEnabled'] as bool? ?? true,
      keywordSeverity4: json?['keywordSeverity4'] as bool? ?? true,
      keywordSeverity5: json?['keywordSeverity5'] as bool? ?? true,
    );
  }
}

class TokenLedgerEntry {
  TokenLedgerEntry({
    required this.timestamp,
    required this.amount,
    required this.type,
    required this.description,
  });

  final DateTime timestamp;
  final int amount;
  final String type;
  final String description;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'amount': amount,
    'type': type,
    'description': description,
  };

  static TokenLedgerEntry fromJson(Map<String, dynamic> json) {
    return TokenLedgerEntry(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'unknown',
      description: json['description']?.toString() ?? '',
    );
  }
}

class NotificationEntry {
  NotificationEntry({
    required this.title,
    required this.body,
    required this.url,
    required this.source,
    required this.severity,
    required this.isAdmin,
    required this.timestamp,
  });

  final String title;
  final String body;
  final String url;
  final String source;
  final int severity;
  final bool isAdmin;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'url': url,
    'source': source,
    'severity': severity,
    'isAdmin': isAdmin,
    'timestamp': timestamp.toIso8601String(),
  };

  static NotificationEntry fromJson(Map<String, dynamic> json) {
    return NotificationEntry(
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Notification',
      severity: (json['severity'] as num?)?.toInt() ?? 0,
      isAdmin: json['isAdmin'] == true,
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

const Duration _notificationRetention = Duration(days: 3);
final ValueNotifier<int> _notificationTick = ValueNotifier<int>(0);

List<NotificationEntry> _pruneNotificationEntries(
  List<NotificationEntry> entries,
) {
  final cutoff = DateTime.now().subtract(_notificationRetention);
  final pruned = entries
      .where((entry) => entry.timestamp.isAfter(cutoff))
      .toList();
  pruned.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return pruned;
}

String _notificationKeyForPayloadGlobal(
  String url,
  String title,
  String summary,
) {
  if (url.isNotEmpty) return url;
  final seed = '$title::$summary';
  return sha1.convert(utf8.encode(seed)).toString();
}

NotificationPreferences _notificationPrefsFromStorage(SharedPreferences prefs) {
  NotificationPreferences prefsModel = NotificationPreferences(
    breakingEnabled: true,
    keywordSeverity4: true,
    keywordSeverity5: true,
  );
  final raw = prefs.getString('notificationPrefs');
  if (raw != null && raw.isNotEmpty) {
    try {
      prefsModel = NotificationPreferences.fromJson(jsonDecode(raw));
    } catch (_) {}
  }
  return prefsModel;
}

Future<void> _storeNotificationFromMessage(RemoteMessage message) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final severity =
        int.tryParse(message.data['severity']?.toString() ?? '') ?? 0;
    final pushType = message.data['pushType']?.toString() ?? '';
    final isAdminPush =
        pushType == 'admin_manual' ||
        (message.data['adminScope']?.toString().isNotEmpty ?? false);
    final prefsModel = _notificationPrefsFromStorage(prefs);
    final allowBreaking = prefsModel.breakingEnabled && pushType == 'breaking';
    final allowKeyword =
        pushType == 'keyword' &&
        ((severity == 4 && prefsModel.keywordSeverity4) ||
            (severity == 5 && prefsModel.keywordSeverity5));
    final shouldStore =
        isAdminPush || (severity >= 4 && (allowBreaking || allowKeyword));
    if (!shouldStore) return;

    final notificationTitle = message.notification?.title ?? 'Breaking News';
    final notificationBody = message.notification?.body ?? '';
    final title = message.data['title']?.toString() ?? notificationTitle;
    final summary = message.data['summary']?.toString() ?? notificationBody;
    final url = message.data['url']?.toString() ?? '';
    final key = _notificationKeyForPayloadGlobal(url, title, summary);

    final notifiedRaw = prefs.getString('notifiedUrls');
    final notified = <String>{};
    if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(notifiedRaw) as List<dynamic>;
        notified.addAll(parsed.map((e) => e.toString()));
      } catch (_) {}
    }
    if (!isAdminPush &&
        (notified.contains(key) ||
            (url.isNotEmpty && notified.contains(url)))) {
      return;
    }

    final publishedAtRaw =
        message.data['publishedAt'] ??
        message.data['published_at'] ??
        message.data['publishedAtUtc'];
    DateTime? publishedAt;
    if (publishedAtRaw != null) {
      publishedAt = DateTime.tryParse(publishedAtRaw.toString());
    }
    publishedAt ??= message.sentTime ?? DateTime.now();
    final localTime = publishedAt.isUtc ? publishedAt.toLocal() : publishedAt;
    if (DateTime.now().difference(localTime) > const Duration(minutes: 120)) {
      return;
    }

    final historyRaw = prefs.getString('notificationHistory');
    final loaded = <NotificationEntry>[];
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(historyRaw) as List<dynamic>;
        loaded.addAll(
          parsed.whereType<Map<String, dynamic>>().map(
            NotificationEntry.fromJson,
          ),
        );
      } catch (_) {}
    }

    final entry = NotificationEntry(
      title: title,
      body: summary,
      url: url,
      source:
          message.data['source']?.toString() ??
          _domainFromUrl(url) ??
          'Notification',
      severity: severity,
      isAdmin: isAdminPush,
      timestamp: localTime,
    );
    final updated = _pruneNotificationEntries([...loaded, entry]);
    final trimmed = updated.length > 200 ? updated.take(200).toList() : updated;
    prefs.setString(
      'notificationHistory',
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
    if (!isAdminPush) {
      notified.add(key);
      if (url.isNotEmpty) {
        notified.add(url);
      }
    }
    prefs.setString('notifiedUrls', jsonEncode(notified.toList()));
    prefs.setBool('notificationsUnread', true);
  } catch (_) {}
}

class SavedArticle {
  SavedArticle({required this.item, required this.savedAt});

  final NewsItem item;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'item': item.toJson(),
    'savedAt': savedAt.toIso8601String(),
  };

  static SavedArticle fromJson(Map<String, dynamic> json) {
    return SavedArticle(
      item: NewsItem.fromJson(
        (json['item'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      savedAt:
          DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class _UserStateSnapshot {
  _UserStateSnapshot({
    required this.tokenBalance,
    required this.tokenLedger,
    required this.tabExpiry,
    required this.notificationPrefs,
    required this.autoRenewEnabled,
    required this.tabKeywords,
    required this.tabRegions,
    required this.canonicalKeywords,
  });

  final int tokenBalance;
  final List<TokenLedgerEntry> tokenLedger;
  final Map<int, DateTime> tabExpiry;
  final NotificationPreferences notificationPrefs;
  final bool autoRenewEnabled;
  final List<String> tabKeywords;
  final List<String> tabRegions;
  final Map<int, String> canonicalKeywords;

  bool get hasData {
    return tabKeywords.any((k) => k.trim().isNotEmpty) ||
        tabRegions.any(
          (r) => r.trim().isNotEmpty && r.toUpperCase() != 'ALL',
        ) ||
        canonicalKeywords.isNotEmpty;
  }
}

String _normalizeWhitespace(String input) {
  return input.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _topicHash(String input) {
  final bytes = utf8.encode(_normalizeWhitespace(input).toLowerCase());
  return sha1.convert(bytes).toString();
}

String _topicLangCode(String lang) {
  return lang.toLowerCase().split('-').first;
}

String _topicRegionCode(String region) {
  return (region.isEmpty ? 'ALL' : region.toUpperCase());
}

String _maskToken(String? token) {
  if (token == null || token.isEmpty) return '';
  if (token.length <= 8) return token;
  return '${token.substring(0, 4)}...${token.substring(token.length - 4)}';
}

String? _domainFromUrl(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null) return null;
  final host = parsed.host;
  if (host.isEmpty) return null;
  if (host.startsWith('www.')) {
    return host.substring(4);
  }
  return host;
}

bool _isGoogleDomain(String domain) {
  final lower = domain.toLowerCase();
  return lower.contains('news.google.com') || lower.endsWith('.google.com');
}

String? _resolveFaviconDomain(NewsItem item) {
  final candidates = [item.sourceUrl, item.resolvedUrl, item.url];
  for (final candidate in candidates) {
    if (candidate.isEmpty) continue;
    final domain = _domainFromUrl(candidate);
    if (domain == null || domain.isEmpty) continue;
    if (_isGoogleDomain(domain)) continue;
    return domain;
  }
  return null;
}

String _articleShareUrl(NewsItem item) {
  if (item.resolvedUrl.isNotEmpty) return item.resolvedUrl;
  if (item.url.isNotEmpty) return item.url;
  return '';
}

String _buildShareMessage(AppLocalizations loc, NewsItem item) {
  final url = _articleShareUrl(item);
  return loc.shareMessage(item.title, url);
}

void _showRateLimitToast(BuildContext context, int seconds) {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  // Avoid spamming snackbars when multiple tabs/requests hit 429 at once.
  if (nowMs - _lastRateLimitToastAtMs < 1500) return;
  _lastRateLimitToastAtMs = nowMs;
  final loc = AppLocalizations.of(context)!;
  final bottomInset = MediaQuery.of(context).padding.bottom;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(loc.rateLimitToast(seconds)),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
    ),
  );
}

Future<void> _showShareSheet(BuildContext context, NewsItem item) async {
  final loc = AppLocalizations.of(context)!;
  final message = _buildShareMessage(loc, item);
  await showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                loc.shareSheetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(loc.shareSheetShare),
              onTap: () async {
                Navigator.of(context).pop();
                await Share.share(message, subject: item.title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(loc.shareSheetCopy),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(loc.shareCopiedToast)));
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

String _upgradeToHttps(String url) {
  if (url.startsWith('http://')) {
    return 'https://${url.substring(7)}';
  }
  return url;
}

String _faviconUrl(String domain) {
  return 'https://www.google.com/s2/favicons?domain=$domain&sz=64';
}

String _timeagoLocale(String language) {
  final code = language.toLowerCase().split('-').first;
  switch (code) {
    case 'ko':
    case 'ja':
    case 'fr':
    case 'es':
    case 'ru':
    case 'ar':
      return code;
    default:
      return 'en';
  }
}

String _localDateKey(DateTime date) {
  final local = date.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

ThemeData _buildScoopTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? const Color(0xFF8FB3FF) : const Color(0xFF2C2A26),
    onPrimary: isDark ? const Color(0xFF0E1116) : const Color(0xFFFDF9F2),
    secondary: isDark ? const Color(0xFFB3B1A8) : const Color(0xFF6E6558),
    onSecondary: isDark ? const Color(0xFF12151A) : const Color(0xFFFDF9F2),
    tertiary: isDark ? const Color(0xFF8AD3C4) : const Color(0xFFB47D4B),
    onTertiary: isDark ? const Color(0xFF0E1116) : const Color(0xFFFDF9F2),
    error: const Color(0xFFB94A48),
    onError: const Color(0xFFFDF9F2),
    surface: isDark ? const Color(0xFF1A1F27) : const Color(0xFFFDF9F2),
    onSurface: isDark ? const Color(0xFFECE7DF) : const Color(0xFF2C2A26),
    surfaceVariant: isDark ? const Color(0xFF232A34) : const Color(0xFFF0E8DD),
    onSurfaceVariant: isDark
        ? const Color(0xFFB7C0CF)
        : const Color(0xFF6E6558),
    outline: isDark ? const Color(0xFF2F3743) : const Color(0xFFD6CFC2),
    outlineVariant: isDark ? const Color(0xFF262C36) : const Color(0xFFE6DED2),
    background: isDark ? const Color(0xFF0E1116) : const Color(0xFFF5EFE6),
    onBackground: isDark ? const Color(0xFFECE7DF) : const Color(0xFF2C2A26),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? const Color(0xFFF5EFE6) : const Color(0xFF161B22),
    onInverseSurface: isDark
        ? const Color(0xFF2C2A26)
        : const Color(0xFFECE7DF),
    inversePrimary: isDark ? const Color(0xFF3A4E7A) : const Color(0xFF8FB3FF),
  );

  final baseTextTheme = ThemeData(brightness: brightness).textTheme;
  final textTheme = baseTextTheme.copyWith(
    headlineMedium: baseTextTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.45),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.5),
  );

  return ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.background,
    canvasColor: colorScheme.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: colorScheme.onBackground,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onBackground,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shadowColor: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceVariant,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colorScheme.surface.withOpacity(isDark ? 0.9 : 0.96),
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.surface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.onSurface,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorColor: colorScheme.primary,
      labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      unselectedLabelStyle: textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colorScheme.onSurface,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

const LinearGradient _scoopLightGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF6F1E8), Color(0xFFF2E9DD), Color(0xFFEFE6DA)],
);

const LinearGradient _scoopDarkGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0D1117), Color(0xFF131A22), Color(0xFF0F141C)],
);

const RadialGradient _scoopLightHaloTop = RadialGradient(
  colors: [Color(0x59DCC9B5), Colors.transparent],
);

const RadialGradient _scoopLightHaloBottom = RadialGradient(
  colors: [Color(0x4DDCC9B5), Colors.transparent],
);

const RadialGradient _scoopDarkHaloTop = RadialGradient(
  colors: [Color(0x47334155), Colors.transparent],
);

const RadialGradient _scoopDarkHaloBottom = RadialGradient(
  colors: [Color(0x38334155), Colors.transparent],
);

Widget _buildScoopBackground(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final gradient = isDark ? _scoopDarkGradient : _scoopLightGradient;
  final haloTop = isDark ? _scoopDarkHaloTop : _scoopLightHaloTop;
  final haloBottom = isDark ? _scoopDarkHaloBottom : _scoopLightHaloBottom;
  return RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        Positioned(
          top: -120,
          left: -80,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: haloTop,
              ),
              child: const SizedBox(width: 320, height: 320),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: haloBottom,
              ),
              child: const SizedBox(width: 340, height: 340),
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  await Firebase.initializeApp();
  await _storeNotificationFromMessage(message);
}

Future<void> _bootstrapDeferredServices() async {
  // Keep first frame fast: initialize non-critical services after runApp.
  await _loadServerTimeOffset();
  unawaited(_syncServerTime());
  try {
    await MobileAds.instance.initialize();
  } catch (_) {}
  try {
    await _ensureUnityAdsInitialized();
  } catch (_) {}
  try {
    await NotificationService.init();
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const NewsCrawlApp());
  unawaited(_bootstrapDeferredServices());
}

class NewsCrawlApp extends StatefulWidget {
  const NewsCrawlApp({super.key});

  @override
  State<NewsCrawlApp> createState() => _NewsCrawlAppState();
}

class _NewsCrawlAppState extends State<NewsCrawlApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  String _region = 'ALL';
  String _language = 'en';
  static const String _onboardingKey = 'onboardingCompleted';
  static const String _privacyConsentKey = 'privacyConsentAccepted';
  static const String _themeModeKey = 'themeMode';
  bool _showOnboarding = false;
  bool _showPrivacyConsent = false;
  bool _privacyPolicyChecked = false;
  bool _privacyOverseasChecked = false;
  bool _prefsLoaded = false;
  MaintenanceStatus? _maintenanceStatus;
  bool _maintenanceActive = false;
  Timer? _maintenanceTimer;
  static const Duration _maintenancePollInterval = Duration(minutes: 3);
  static const List<String> _languageCodes = [
    'en',
    'en-GB',
    'ko',
    'ja',
    'fr',
    'es',
    'ru',
    'ar',
  ];
  final List<NotificationEntry> _notificationHistoryApp = [];
  final Set<String> _notifiedUrlsApp = {};
  bool _notificationCacheLoaded = false;
  static bool _timeagoInitialized = false;

  void toggleThemeMode() {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    setState(() {
      _themeMode = nextMode;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_themeModeKey, _themeModeToString(nextMode));
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locale = _localeForLanguage(_language);
    _initTimeagoLocales();
    _loadPreferences();
    _startMaintenancePolling();
    _initPushNotifications();
  }

  void _initTimeagoLocales() {
    if (_timeagoInitialized) return;
    timeago.setLocaleMessages('en', timeago.EnMessages());
    timeago.setLocaleMessages('ko', timeago.KoMessages());
    timeago.setLocaleMessages('ja', timeago.JaMessages());
    timeago.setLocaleMessages('fr', timeago.FrMessages());
    timeago.setLocaleMessages('es', timeago.EsMessages());
    timeago.setLocaleMessages('ru', timeago.RuMessages());
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    _timeagoInitialized = true;
  }

  @override
  void dispose() {
    _maintenanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMaintenanceStatus();
    }
  }

  void _startMaintenancePolling() {
    _refreshMaintenanceStatus();
    _maintenanceTimer?.cancel();
    _maintenanceTimer = Timer.periodic(
      _maintenancePollInterval,
      (_) => _refreshMaintenanceStatus(),
    );
  }

  Future<void> _refreshMaintenanceStatus() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/app/status'));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final serverTimeMs = int.tryParse(
        decoded['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      final maintenanceRaw = decoded['maintenance'];
      final maintenance = MaintenanceStatus.fromJson(
        maintenanceRaw is Map
            ? Map<String, dynamic>.from(maintenanceRaw)
            : null,
      );
      if (!mounted) return;
      setState(() {
        _maintenanceStatus = maintenance;
        _maintenanceActive = maintenance.active;
      });
    } catch (_) {}
  }

  String? _resolveStoreUrl() {
    final status = _maintenanceStatus;
    if (status == null) return null;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final url = status.storeUrlIos ?? '';
      return url.isNotEmpty ? url : null;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final url = status.storeUrlAndroid ?? '';
      return url.isNotEmpty ? url : null;
    }
    final url = status.storeUrlAndroid ?? status.storeUrlIos ?? '';
    return url.isNotEmpty ? url : null;
  }

  String _formatMaintenanceWindow(BuildContext context) {
    final status = _maintenanceStatus;
    if (status == null) return '';
    final startAt = status.startAt;
    final endAt = status.endAt;
    if (startAt == null && endAt == null) return '';
    final copy = _maintenanceCopyForLanguage(_language);
    final localeTag = (_locale ?? _localeForLanguage(_language)).toString();
    final format = DateFormat.yMMMd(localeTag).add_Hm();
    if (startAt != null && endAt != null) {
      final startText = format.format(startAt.toLocal());
      final endText = format.format(endAt.toLocal());
      return '${copy.windowLabel}: $startText - $endText';
    }
    if (endAt != null) {
      final endText = format.format(endAt.toLocal());
      return '${copy.untilLabel}: $endText';
    }
    final startText = format.format(startAt!.toLocal());
    return '${copy.windowLabel}: $startText';
  }

  String _normalizeStoreUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('market://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  Future<void> _openStoreUrl(String url) async {
    final normalized = _normalizeStoreUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildMaintenanceScreen(BuildContext context) {
    final copy = _maintenanceCopyForLanguage(_language);
    final theme = Theme.of(context);
    final scheduleText = _formatMaintenanceWindow(context);
    final storeUrl = _resolveStoreUrl();
    final isRtl = _isRtlLanguage(_language);
    return WillPopScope(
      onWillPop: () async {
        SystemNavigator.pop();
        return false;
      },
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style:
                        theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ) ??
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    copy.detail,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (scheduleText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      scheduleText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (storeUrl != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _openStoreUrl(storeUrl),
                        child: Text(copy.storeButton),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => SystemNavigator.pop(),
                      child: Text(copy.exitButton),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ThemeMode _themeModeFromString(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    if (mode == ThemeMode.dark) return 'dark';
    if (mode == ThemeMode.light) return 'light';
    return 'system';
  }

  String _notificationKeyForPayload(String url, String title, String summary) {
    if (url.isNotEmpty) return url;
    final seed = '$title::$summary';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final firstSeenAt = prefs.getInt(_reviewFirstSeenAtKey) ?? 0;
    if (firstSeenAt <= 0) {
      await prefs.setInt(_reviewFirstSeenAtKey, nowMs);
    }
    final launchCount = (prefs.getInt(_reviewLaunchCountKey) ?? 0) + 1;
    await prefs.setInt(_reviewLaunchCountKey, launchCount);

    final region = prefs.getString('region');
    final language = prefs.getString('language');
    final themeModeRaw = prefs.getString(_themeModeKey);
    final seenOnboarding = prefs.getBool(_onboardingKey) ?? false;
    final privacyAccepted = prefs.getBool(_privacyConsentKey) ?? false;
    final resolvedLanguage = (language != null && language.isNotEmpty)
        ? language
        : _resolveDeviceLanguage();
    final resolvedThemeMode = _themeModeFromString(themeModeRaw);
    if (language == null || language.isEmpty) {
      await prefs.setString('language', resolvedLanguage);
    }
    if (!mounted) return;
    setState(() {
      if (region != null && region.isNotEmpty) {
        _region = region;
      }
      _language = resolvedLanguage;
      _themeMode = resolvedThemeMode;
      _locale = _localeForLanguage(resolvedLanguage);
      _showOnboarding = !seenOnboarding;
      _showPrivacyConsent = !privacyAccepted;
      _prefsLoaded = true;
    });
  }

  Future<void> _setRegion(String region) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('region', region);
    setState(() {
      _region = region;
    });
    await _syncTopicSubscriptions();
  }

  Future<void> _syncTopicSubscriptions() async {
    // Topic subscriptions are managed inside NewsHomePage.
  }

  Future<void> _setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    setState(() {
      _language = language;
      _locale = _localeForLanguage(language);
    });
  }

  String _resolveDeviceLanguage() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final langCode = deviceLocale.languageCode.toLowerCase();
    final country = (deviceLocale.countryCode ?? '').toUpperCase();
    if (langCode == 'en' && country == 'GB') {
      return 'en-GB';
    }
    if (_languageCodes.contains(langCode)) {
      return langCode;
    }
    return 'en';
  }

  Future<void> _initPushNotifications() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // 로딩 화면 등 초기화 시간을 벌기 위해 0.5초 대기
          await Future.delayed(const Duration(milliseconds: 500));
          _handleMessageTap(initialMessage);
        });
      }
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      FirebaseMessaging.onMessage.listen((message) {
        if (!mounted) return;
        final severity =
            int.tryParse(message.data['severity']?.toString() ?? '') ?? 0;
        final pushType = message.data['pushType']?.toString() ?? '';
        final isAdminPush =
            pushType == 'admin_manual' ||
            (message.data['adminScope']?.toString().isNotEmpty ?? false);
        final notificationTitle =
            message.notification?.title ?? 'Breaking News';
        final notificationBody = message.notification?.body ?? '';
        debugPrint(
          'FCM onMessage: type=$pushType sev=$severity '
          'hasNotif=${message.notification != null} lang=${message.data['lang'] ?? ''}',
        );
        final prefs = SharedPreferences.getInstance();
        prefs.then((storage) {
          if (!_notificationCacheLoaded) {
            _notificationCacheLoaded = true;
            try {
              final historyRaw = storage.getString('notificationHistory');
              if (historyRaw != null && historyRaw.isNotEmpty) {
                final parsed = jsonDecode(historyRaw) as List<dynamic>;
                final loaded = parsed
                    .whereType<Map<String, dynamic>>()
                    .map(NotificationEntry.fromJson)
                    .toList();
                final pruned = _pruneNotificationEntries(loaded);
                _notificationHistoryApp
                  ..clear()
                  ..addAll(pruned);
                if (pruned.length != loaded.length) {
                  storage.setString(
                    'notificationHistory',
                    jsonEncode(
                      _notificationHistoryApp.map((e) => e.toJson()).toList(),
                    ),
                  );
                }
              }
              final notifiedRaw = storage.getString('notifiedUrls');
              if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
                final parsed = jsonDecode(notifiedRaw) as List<dynamic>;
                _notifiedUrlsApp
                  ..clear()
                  ..addAll(parsed.map((e) => e.toString()));
              }
            } catch (_) {}
          }
          NotificationPreferences prefsModel = NotificationPreferences(
            breakingEnabled: true,
            keywordSeverity4: true,
            keywordSeverity5: true,
          );
          final raw = storage.getString('notificationPrefs');
          if (raw != null && raw.isNotEmpty) {
            try {
              prefsModel = NotificationPreferences.fromJson(jsonDecode(raw));
            } catch (_) {}
          }
          final allowBreaking =
              prefsModel.breakingEnabled && pushType == 'breaking';
          final allowKeyword =
              pushType == 'keyword' &&
              ((severity == 4 && prefsModel.keywordSeverity4) ||
                  (severity == 5 && prefsModel.keywordSeverity5));
          final shouldNotify =
              isAdminPush || (severity >= 4 && (allowBreaking || allowKeyword));
          if (!shouldNotify) {
            debugPrint(
              'FCM onMessage skip: prefs type=$pushType sev=$severity',
            );
            return;
          }
          final url = message.data['url']?.toString() ?? '';
          final title = message.data['title']?.toString() ?? notificationTitle;
          final summary =
              message.data['summary']?.toString() ?? notificationBody;
          final key = _notificationKeyForPayload(url, title, summary);
          if (!isAdminPush &&
              (_notifiedUrlsApp.contains(key) ||
                  (url.isNotEmpty && _notifiedUrlsApp.contains(url)))) {
            return;
          }
          final publishedAtRaw =
              message.data['publishedAt'] ??
              message.data['published_at'] ??
              message.data['publishedAtUtc'];
          DateTime? publishedAt;
          if (publishedAtRaw != null) {
            publishedAt = DateTime.tryParse(publishedAtRaw.toString());
          }
          publishedAt ??= message.sentTime ?? DateTime.now();
          final localTime = publishedAt.isUtc
              ? publishedAt.toLocal()
              : publishedAt;
          if (DateTime.now().difference(localTime) >
              const Duration(minutes: 120)) {
            debugPrint(
              'FCM onMessage skip: stale age=${DateTime.now().difference(localTime).inMinutes}m url=$url',
            );
            return;
          }
          final payload = jsonEncode({
            'url': url,
            'title': title,
            'summary': summary,
            'source': message.data['source'] ?? 'Notification',
            'severity': severity.toString(),
          });
          if (!isAdminPush) {
            _notifiedUrlsApp.add(key);
          }
          final entry = NotificationEntry(
            title: title,
            body: summary,
            url: url,
            source:
                message.data['source']?.toString() ??
                _domainFromUrl(url) ??
                'Notification',
            severity: severity,
            isAdmin: isAdminPush,
            timestamp: localTime,
          );
          _recordNotificationApp(storage, entry);
          debugPrint('FCM onMessage show: url=$url sev=$severity');
          NotificationService.show(message, severity, payload);
          if (notificationBody.isEmpty) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$notificationTitle\n$notificationBody')),
          );
        });
      });
    } catch (error) {
      // Ignore push setup errors in UI.
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final payload = _payloadFromRemoteMessage(message);
    NotificationService.handleNotificationResponse(payload);
  }

  String _payloadFromRemoteMessage(RemoteMessage message) {
    final notificationTitle = message.notification?.title ?? 'Breaking News';
    final notificationBody = message.notification?.body ?? '';
    final payload = {
      'url': message.data['url']?.toString() ?? '',
      'title': message.data['title'] ?? notificationTitle,
      'summary': message.data['summary'] ?? notificationBody,
      'source': message.data['source'] ?? 'Notification',
      'severity': message.data['severity']?.toString() ?? '4',
    };
    return jsonEncode(payload);
  }

  void _recordNotificationApp(
    SharedPreferences storage,
    NotificationEntry entry,
  ) {
    _notificationHistoryApp
      ..removeWhere(
        (item) => item.timestamp.isBefore(
          DateTime.now().subtract(_notificationRetention),
        ),
      )
      ..insert(0, entry);
    if (_notificationHistoryApp.length > 200) {
      _notificationHistoryApp.removeRange(200, _notificationHistoryApp.length);
    }
    storage.setString(
      'notificationHistory',
      jsonEncode(_notificationHistoryApp.map((e) => e.toJson()).toList()),
    );
    storage.setString('notifiedUrls', jsonEncode(_notifiedUrlsApp.toList()));
    storage.setBool('notificationsUnread', true);
    _notificationTick.value = _notificationTick.value + 1;
  }

  Locale _localeForLanguage(String language) {
    switch (language) {
      case 'en-GB':
        return const Locale('en', 'GB');
      case 'ko':
        return const Locale('ko');
      case 'ja':
        return const Locale('ja');
      case 'fr':
        return const Locale('fr');
      case 'es':
        return const Locale('es');
      case 'ru':
        return const Locale('ru');
      case 'ar':
        return const Locale('ar');
      case 'en':
      default:
        return const Locale('en');
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  Future<void> _completePrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyConsentKey, true);
    if (!mounted) return;
    setState(() {
      _showPrivacyConsent = false;
      _privacyPolicyChecked = false;
      _privacyOverseasChecked = false;
    });
  }

  Future<void> _declinePrivacyConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyConsentKey, false);
    SystemNavigator.pop();
  }

  Widget _buildPrivacyConsent(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final canAccept = _privacyPolicyChecked && _privacyOverseasChecked;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.privacyConsentTitle,
                style:
                    theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ) ??
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(loc.privacyConsentBody, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: PrivacyPolicyContent(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                      textStyle: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _privacyPolicyChecked,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(loc.privacyConsentPolicyLabel),
                onChanged: (value) {
                  setState(() {
                    _privacyPolicyChecked = value ?? false;
                  });
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _privacyOverseasChecked,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(loc.privacyConsentOverseasLabel),
                onChanged: (value) {
                  setState(() {
                    _privacyOverseasChecked = value ?? false;
                  });
                },
              ),
              const SizedBox(height: 4),
              Text(
                loc.privacyConsentRequiredHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _declinePrivacyConsent,
                      child: Text(loc.privacyConsentDecline),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: canAccept ? _completePrivacyConsent : null,
                      child: Text(loc.privacyConsentAccept),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(BuildContext context) {
    return Stack(
      children: [
        // 1. 배경 이미지 (SizedBox.expand로 강제 확장)
        SizedBox.expand(
          child: Image.asset(
            'assets/SCOOP_LOADING.webp',
            fit: BoxFit.cover, // 화면 비율에 맞춰 꽉 채우기
          ),
        ),

        // 2. 로딩 바 (중앙 정렬)
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                minHeight: 6,
                backgroundColor: Colors.black.withOpacity(0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOnboarding(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final pageDecoration = PageDecoration(
      titleTextStyle:
          theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ) ??
          const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      bodyTextStyle:
          (theme.textTheme.bodyMedium ??
                  const TextStyle(fontSize: 15, height: 1.4))
              .copyWith(color: Colors.black),
      bodyAlignment: Alignment.center,
      imagePadding: EdgeInsets.zero,
      contentMargin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      fullScreen: true,
      imageFlex: 6,
      bodyFlex: 3,
    );
    return IntroductionScreen(
      globalBackgroundColor: theme.colorScheme.surface,
      pages: [
        PageViewModel(
          title: loc.onboardingTitle1,
          body: loc.onboardingBody1,
          image: Image.asset(
            'assets/onboarding/onboarding_1.webp',
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: loc.onboardingTitle2,
          body: loc.onboardingBody2,
          image: Image.asset(
            'assets/onboarding/onboarding_2.webp',
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: loc.onboardingTitle3,
          body: loc.onboardingBody3,
          image: Image.asset(
            'assets/onboarding/onboarding_3.webp',
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          decoration: pageDecoration,
        ),
      ],
      showSkipButton: true,
      skip: Text(loc.onboardingSkip),
      next: Text(loc.onboardingNext),
      done: Text(loc.onboardingDone),
      onDone: _completeOnboarding,
      onSkip: _completeOnboarding,
      controlsPadding: EdgeInsets.fromLTRB(16, 8, 16, 12 + bottomInset),
      dotsDecorator: DotsDecorator(
        color: theme.colorScheme.outlineVariant,
        activeColor: theme.colorScheme.primary,
        size: const Size(8, 8),
        activeSize: const Size(18, 8),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCOOP',
      theme: _buildScoopTheme(Brightness.light),
      darkTheme: _buildScoopTheme(Brightness.dark),
      themeAnimationDuration: const Duration(milliseconds: 40),
      themeAnimationCurve: Curves.linear,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: const [
        Locale('en'),
        Locale('en', 'GB'),
        Locale('ko'),
        Locale('ja'),
        Locale('fr'),
        Locale('es'),
        Locale('ru'),
        Locale('ar'),
      ],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      navigatorKey: navigatorKey,
      home: ValueListenableBuilder<bool>(
        valueListenable: _bannedNotifier,
        builder: (context, banned, _) {
          if (banned) {
            return const BannedPage();
          }
          if (_prefsLoaded) {
            if (_maintenanceActive) {
              return _buildMaintenanceScreen(context);
            }
            if (_showPrivacyConsent) {
              return _buildPrivacyConsent(context);
            }
            if (_showOnboarding) {
              return _buildOnboarding(context);
            }
            return NewsHomePage(
              onToggleTheme: toggleThemeMode,
              initialRegion: _region,
              onRegionChanged: _setRegion,
              initialLanguage: _language,
              onLanguageChanged: _setLanguage,
            );
          }
          return _maintenanceActive
              ? _buildMaintenanceScreen(context)
              : _buildLoadingScreen(context);
        },
      ),
    );
  }
}

class BannedPage extends StatelessWidget {
  const BannedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isRtl = _isRtlLanguage(Localizations.localeOf(context).languageCode);
    return WillPopScope(
      onWillPop: () async => false,
      child: Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 72,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.bannedTitle,
                    textAlign: TextAlign.center,
                    style:
                        theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ) ??
                        const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.bannedBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const SupportPage(),
                          ),
                        );
                      },
                      child: Text(loc.contactSupport),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NewsHomePage extends StatefulWidget {
  const NewsHomePage({
    super.key,
    required this.onToggleTheme,
    required this.initialRegion,
    required this.onRegionChanged,
    required this.initialLanguage,
    required this.onLanguageChanged,
  });

  final VoidCallback onToggleTheme;
  final String initialRegion;
  final ValueChanged<String> onRegionChanged;
  final String initialLanguage;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<NewsHomePage> createState() => _NewsHomePageState();
}

enum _PanelType { account, token }

class _NewsHomePageState extends State<NewsHomePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final TextEditingController _keywordController = TextEditingController();
  static const int _tabCount = 7;
  final List<String> _tabs = const ['Breaking', '1', '2', '3', '4', '5', '6'];
  List<String> _keywords = List.filled(_tabCount, '');
  List<String> _tabRegions = List.filled(_tabCount, 'ALL');
  int _currentIndex = 0;
  bool _loading = true;
  User? _user;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  static const String _breakingKeyword = 'Breaking news';
  int _tokenBalance = 0;
  List<TokenLedgerEntry> _tokenLedger = [];
  final Map<int, DateTime> _tabExpiry = {};
  bool _autoRenewEnabled = false;
  final Map<int, String> _canonicalKeywords = {};
  final Set<String> _notifiedUrls = {};
  List<NotificationEntry> _notificationHistory = [];
  bool _hasUnreadNotifications = false;
  final Set<String> _notificationLangs = {};
  List<SavedArticle> _savedArticles = [];
  final Set<String> _savedArticleKeys = {};
  final Set<String> _blockedDomains = {};
  final Set<String> _reportedUrls = {};
  NotificationPreferences _notificationPrefs = NotificationPreferences(
    breakingEnabled: true,
    keywordSeverity4: true,
    keywordSeverity5: true,
  );
  int _tokenHistoryPage = 1;
  bool _tokenHistoryLoadingMore = false;
  bool _hasPromptedSync = false;
  bool _expiryCheckInFlight = false;
  bool _expiryPruneScheduled = false;
  int _refreshToken = 0;
  bool _refreshInProgress = false;
  int _refreshTurns = 0;
  int _autoRefreshToken = 0;
  bool _showPanel = false;
  bool _exitDialogShowing = false;
  bool _reviewPromptAttempted = false;
  int _reviewPromptDeferrals = 0;
  _PanelType _panelType = _PanelType.account;
  final GlobalKey _accountButtonKey = GlobalKey();
  final GlobalKey _tokenButtonKey = GlobalKey();
  Timer? _autoRefreshTimer;
  Timer? _tabExpiryTimer;
  Timer? _heartbeatTimer;
  bool _heartbeatInFlight = false;
  static const Duration _heartbeatInterval = Duration(minutes: 5);
  StreamSubscription<RemoteMessage>? _pushRefreshSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _canonicalSyncInFlight = false;
  bool _savedSyncInFlight = false;
  Timer? _prefetchPollTimer;
  int _prefetchPollRemaining = 0;
  static const int _prefetchPollAttempts = 3;
  static const Duration _prefetchPollInterval = Duration(seconds: 4);
  static const Duration _breakingActivateCooldown = Duration(minutes: 3);
  String _breakingActivateLastKey = '';
  int _breakingActivateLastAtMs = 0;
  Timer? _processingPollTimer;
  int _processingPollRemaining = 0;
  static const int _processingPollAttempts = 5;
  static const Duration _processingPollInterval = Duration(seconds: 90);
  final Set<int> _processingTabs = {};
  late final AnimationController _sheetController;
  late final Animation<double> _sheetAnimation;
  Rect? _sheetStartRect;
  Rect? _sheetEndRect;
  static const MethodChannel _appConfigChannel = MethodChannel(
    'com.anmt2805.news_crawl/app_config',
  );
  final InAppPurchase _iap = InAppPurchase.instance;
  OneStoreAuthClient? _oneStoreAuthClient;
  PurchaseClientManager? _oneStoreIap;
  StreamSubscription<List<PurchaseDetails>>? _iapPurchaseSub;
  StreamSubscription<List<PurchaseData>>? _oneStorePurchaseSub;
  bool _oneStoreIapInitialized = false;
  _AndroidBillingStore _androidBillingStore = _AndroidBillingStore.play;
  bool _iapAvailable = false;
  bool _iapLoading = false;
  bool _iapPurchaseInFlight = false;
  String _iapError = '';
  final Map<String, int> _iapProductTokens = {};
  List<_StoreProduct> _iapProducts = [];

  Future<void> _debugShowReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final result = await _showReviewRatingDialog();
    if (!mounted || result == null) return;

    await prefs.setInt(_reviewLastRatingKey, result.rating);

    if (result.action == _ReviewPromptAction.writeReview) {
      await prefs.setBool(_reviewWriteClickedKey, true);
      await _requestStoreReview();
      return;
    }

    if (result.action == _ReviewPromptAction.contactSupport) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const SupportPage()));
    }
  }

  Future<void> _debugResetReviewPromptState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reviewFirstSeenAtKey);
    await prefs.remove(_reviewLaunchCountKey);
    await prefs.remove(_reviewLastPromptAtKey);
    await prefs.remove(_reviewLaunchCountAtPromptKey);
    await prefs.remove(_reviewWriteClickedKey);
    await prefs.remove(_reviewLastRatingKey);

    _reviewPromptAttempted = false;
    _reviewPromptDeferrals = 0;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review prompt state reset (debug).')),
    );
  }

  String _breakingKeywordForLanguage(String language) {
    switch (language.toLowerCase().split('-').first) {
      case 'ko':
        return '속보';
      case 'ja':
        return '速報';
      case 'fr':
        return 'Dernières nouvelles';
      case 'es':
        return 'Última hora';
      case 'ru':
        return 'Срочные новости';
      case 'ar':
        return 'أخبار عاجلة';
      default:
        return _breakingKeyword;
    }
  }

  String _breakingKeywordForRegion(String region, String language) {
    switch (region.toUpperCase()) {
      case 'KR':
        return '속보';
      case 'JP':
        return '速報';
      case 'FR':
        return 'Dernières nouvelles';
      case 'ES':
        return 'Última hora';
      case 'RU':
        return 'Срочные новости';
      case 'AE':
        return 'أخبار عاجلة';
      case 'UK':
      case 'US':
      case 'ALL':
        return 'breaking news';
      default:
        final regionLang = _regionNewsLang[region.toUpperCase()] ?? language;
        return _breakingKeywordForLanguage(regionLang);
    }
  }

  String _regionForTab(int index) {
    if (_tabRegions.isEmpty) return 'ALL';
    final safeIndex = index.clamp(0, _tabRegions.length - 1);
    final value = _tabRegions[safeIndex].trim();
    return value.isEmpty ? 'ALL' : value.toUpperCase();
  }

  String get _currentRegion => _regionForTab(_currentIndex);
  Alignment _sheetAnchorAlignment = Alignment.topRight;
  static const List<String> _regions = [
    'US',
    'UK',
    'KR',
    'JP',
    'FR',
    'ES',
    'RU',
    'AE',
  ];
  static const Map<String, int> _regionOffsets = {
    'US': -5,
    'UK': 0,
    'KR': 9,
    'JP': 9,
    'FR': 1,
    'ES': 1,
    'RU': 3,
    'AE': 4,
    'ALL': 0,
  };
  static const Map<String, String> _regionNewsLang = {
    'US': 'en',
    'UK': 'en',
    'KR': 'ko',
    'JP': 'ja',
    'FR': 'fr',
    'ES': 'es',
    'RU': 'ru',
    'AE': 'ar',
    'ALL': 'en',
  };
  static const Map<String, String> _regionNamesEnglish = {
    'US': 'United States',
    'UK': 'United Kingdom',
    'CA': 'Canada',
    'AU': 'Australia',
    'NZ': 'New Zealand',
    'IE': 'Ireland',
    'FR': 'France',
    'DE': 'Germany',
    'IT': 'Italy',
    'ES': 'Spain',
    'NL': 'Netherlands',
    'BE': 'Belgium',
    'SE': 'Sweden',
    'NO': 'Norway',
    'DK': 'Denmark',
    'FI': 'Finland',
    'PL': 'Poland',
    'CZ': 'Czech Republic',
    'AT': 'Austria',
    'CH': 'Switzerland',
    'PT': 'Portugal',
    'GR': 'Greece',
    'RO': 'Romania',
    'HU': 'Hungary',
    'UA': 'Ukraine',
    'RU': 'Russia',
    'TR': 'Turkey',
    'IL': 'Israel',
    'AE': 'United Arab Emirates',
    'SA': 'Saudi Arabia',
    'QA': 'Qatar',
    'KW': 'Kuwait',
    'OM': 'Oman',
    'BH': 'Bahrain',
    'EG': 'Egypt',
    'MA': 'Morocco',
    'TN': 'Tunisia',
    'ZA': 'South Africa',
    'NG': 'Nigeria',
    'KE': 'Kenya',
    'IN': 'India',
    'PK': 'Pakistan',
    'BD': 'Bangladesh',
    'LK': 'Sri Lanka',
    'MY': 'Malaysia',
    'SG': 'Singapore',
    'TH': 'Thailand',
    'VN': 'Vietnam',
    'ID': 'Indonesia',
    'PH': 'Philippines',
    'HK': 'Hong Kong',
    'TW': 'Taiwan',
    'CN': 'China',
    'JP': 'Japan',
    'KR': 'South Korea',
    'BR': 'Brazil',
    'AR': 'Argentina',
    'CL': 'Chile',
    'CO': 'Colombia',
    'MX': 'Mexico',
    'PE': 'Peru',
  };
  String _language = 'en';
  static const Map<String, String> _languageLabels = {
    'en': 'English',
    'en-GB': 'English (UK)',
    'ko': 'Korean',
    'ja': 'Japanese',
    'fr': 'French',
    'es': 'Spanish',
    'ru': 'Russian',
    'ar': 'Arabic',
  };
  static const List<String> _languageCodes = [
    'en',
    'en-GB',
    'ko',
    'ja',
    'fr',
    'es',
    'ru',
    'ar',
  ];
  static const int _tabMonthlyCost = 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notificationTick.addListener(_handleNotificationTick);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _sheetAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _language = widget.initialLanguage;
    _user = FirebaseAuth.instance.currentUser;
    _listenAuthChanges();
    _bannedNotifier.addListener(_handleBannedChange);
    _startHeartbeatTimer();
    Future(() => _sendHeartbeat());
    _loadKeywords();
    _startTabExpiryTimer();
    _syncServerTime();
    _initIap();
    _scheduleReviewPrompt();
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _triggerAutoRefresh(),
    );
    _pushRefreshSub = FirebaseMessaging.onMessage.listen(_handlePushRefresh);
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      debugPrint('FCM token refreshed: ${_maskToken(token)}');
      _syncTopicSubscriptions();
    });
  }

  @override
  void didUpdateWidget(covariant NewsHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialLanguage != widget.initialLanguage) {
      setState(() {
        _language = widget.initialLanguage;
      });
      Future(() async {
        await _sendHeartbeat();
        await _syncGuestTracking(force: true);
        await _updateNotificationLangHistory();
        await _syncTopicSubscriptions();
        await _prefetchCachesForLanguage(_language);
      });
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _pulseController.dispose();
    _sheetController.dispose();
    _autoRefreshTimer?.cancel();
    _tabExpiryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pushRefreshSub?.cancel();
    _tokenRefreshSub?.cancel();
    _iapPurchaseSub?.cancel();
    _oneStorePurchaseSub?.cancel();
    _oneStoreIap?.dispose();
    _prefetchPollTimer?.cancel();
    _processingPollTimer?.cancel();
    _notificationTick.removeListener(_handleNotificationTick);
    _bannedNotifier.removeListener(_handleBannedChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeatTimer();
      _sendHeartbeat();
      _triggerAutoRefresh();
      // If the user toggled OS-level notification permission while the app was backgrounded,
      // re-check token/topic subscriptions on resume.
      Future(() async {
        await _reloadNotificationCacheFromPrefs();
        await _ensureFcmReady();
        await _syncTopicSubscriptions();
        await _refreshTokenStateFromServer();
        await _pruneExpiredTabs();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  void _handlePushRefresh(RemoteMessage message) {
    final severity =
        int.tryParse(message.data['severity']?.toString() ?? '') ?? 0;
    final pushType = message.data['pushType']?.toString() ?? '';
    if (severity < 4) return;
    if (pushType != 'keyword' && pushType != 'breaking') return;
    _triggerAutoRefresh();
  }

  void _triggerRefresh() {
    setState(() {
      _refreshToken++;
      _refreshInProgress = true;
      _refreshTurns++;
    });
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_refreshInProgress) {
        setState(() {
          _refreshInProgress = false;
        });
      }
    });
  }

  void _triggerAutoRefresh() {
    if (!mounted) return;
    setState(() {
      _autoRefreshToken++;
    });
  }

  void _startTabExpiryTimer() {
    _tabExpiryTimer?.cancel();
    _tabExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _pruneExpiredTabs();
    });
  }

  void _scheduleExpiredPrune() {
    if (_expiryPruneScheduled) return;
    _expiryPruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _expiryPruneScheduled = false;
      await _pruneExpiredTabs();
    });
  }

  Future<void> _pruneExpiredTabs({bool syncServer = true}) async {
    final now = _serverNow();
    final expired = <int>[];
    for (var index = 2; index < _tabs.length; index += 1) {
      final expiry = _tabExpiry[index];
      // Keep keyword settings even when the tab is locked (no expiry).
      // Only prune when an existing purchase has actually expired.
      if (expiry == null) continue;
      if (!expiry.isAfter(now)) {
        expired.add(index);
      }
    }
    if (expired.isEmpty) return;
    if (_expiryCheckInFlight) return;
    _expiryCheckInFlight = true;
    try {
      if (mounted) {
        setState(() {
          for (final index in expired) {
            _tabExpiry.remove(index);
            if (index >= 0 && index < _keywords.length) {
              _keywords[index] = '';
            }
            _canonicalKeywords.remove(index);
          }
        });
      } else {
        for (final index in expired) {
          _tabExpiry.remove(index);
          if (index >= 0 && index < _keywords.length) {
            _keywords[index] = '';
          }
          _canonicalKeywords.remove(index);
        }
      }
      await _saveLocalState();
      await _syncTopicSubscriptions();
      if (syncServer && _user != null) {
        await _saveUserStateToFirestore();
      }
    } finally {
      _expiryCheckInFlight = false;
    }
  }

  String _notificationKeyForItem(NewsItem item) {
    final url = item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url;
    if (url.isNotEmpty) return url;
    final seed = '${item.title}::${item.summary}';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  String _notificationKeyForPayload(String url, String title, String summary) {
    if (url.isNotEmpty) return url;
    final seed = '$title::$summary';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  String _articleKey(NewsItem item) {
    return _notificationKeyForItem(item);
  }

  String _savedArticleId(NewsItem item) {
    final url = item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url;
    final seed = url.isNotEmpty ? url : '${item.title}::${item.summary}';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  bool _authListenerSet = false;

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _googleWebClientId,
  );

  void _listenAuthChanges() {
    if (_authListenerSet) return;
    _authListenerSet = true;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      setState(() {
        _user = user;
      });
      if (user != null) {
        _loadUserStateFromFirestore();
        _loadSavedArticlesFromServer();
        _recoverPendingPurchases();
        _sendHeartbeat();
      }
    });
  }

  void _handleBannedChange() {
    if (!_bannedNotifier.value) return;
    _resetLocalUserStateAfterLogout();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (!mounted) return;
      _sendHeartbeat();
    });
  }

  Future<void> _sendHeartbeat() async {
    if (_heartbeatInFlight) return;
    if (_bannedNotifier.value) return;
    _heartbeatInFlight = true;
    try {
      if (_user != null) {
        await _postWithAuth('/users/heartbeat', {'language': _language});
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _postJson('/users/guest_heartbeat', {
        'token': token,
        'language': _language,
      }, withAuth: false);
    } catch (_) {
    } finally {
      _heartbeatInFlight = false;
    }
  }

  void _scheduleReviewPrompt() {
    if (_reviewPromptAttempted) return;
    _reviewPromptAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 6), () {
        if (!mounted) return;
        _maybePromptForReview();
      });
    });
  }

  Future<void> _maybePromptForReview() async {
    if (!mounted) return;
    if (_bannedNotifier.value) return;

    void defer() {
      if (_reviewPromptDeferrals >= 3) return;
      _reviewPromptDeferrals += 1;
      Future.delayed(const Duration(seconds: 20), () {
        if (!mounted) return;
        _maybePromptForReview();
      });
    }

    if (ModalRoute.of(context)?.isCurrent != true) {
      defer();
      return;
    }
    if (_showPanel || _exitDialogShowing) {
      defer();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final disabled = prefs.getBool(_reviewWriteClickedKey) ?? false;
    if (disabled) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final firstSeenAtMs = prefs.getInt(_reviewFirstSeenAtKey) ?? 0;
    final lastPromptAtMs = prefs.getInt(_reviewLastPromptAtKey) ?? 0;
    final launchCount = prefs.getInt(_reviewLaunchCountKey) ?? 0;
    final launchCountAtPrompt =
        prefs.getInt(_reviewLaunchCountAtPromptKey) ?? 0;

    final baseTimeMs = (lastPromptAtMs > 0)
        ? lastPromptAtMs
        : (firstSeenAtMs > 0 ? firstSeenAtMs : nowMs);
    final timeOk = nowMs - baseTimeMs >= _reviewPromptCooldown.inMilliseconds;
    final launchesSince = lastPromptAtMs > 0
        ? (launchCount - launchCountAtPrompt)
        : launchCount;
    final launchOk = launchesSince >= _reviewPromptLaunchThreshold;

    if (!timeOk && !launchOk) return;

    await prefs.setInt(_reviewLastPromptAtKey, nowMs);
    await prefs.setInt(_reviewLaunchCountAtPromptKey, launchCount);

    final result = await _showReviewRatingDialog();
    if (!mounted) return;
    if (result == null) return;
    await prefs.setInt(_reviewLastRatingKey, result.rating);

    if (result.action == _ReviewPromptAction.writeReview) {
      await prefs.setBool(_reviewWriteClickedKey, true);
      await _requestStoreReview();
      return;
    }

    if (result.action == _ReviewPromptAction.contactSupport) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const SupportPage()));
    }
  }

  Future<_ReviewPromptResult?> _showReviewRatingDialog() async {
    if (!mounted) return null;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    int rating = 0;
    return showDialog<_ReviewPromptResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final helperText = rating <= 0
                ? ''
                : (rating >= 4 ? loc.reviewHighBody : loc.reviewLowBody);
            final primaryLabel = rating <= 0
                ? loc.reviewPromptContinue
                : (rating >= 4 ? loc.reviewWriteAction : loc.confirm);
            return AlertDialog(
              title: Text(loc.reviewPromptTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.reviewPromptBody),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final selected = value <= rating;
                      final color = selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline;
                      return IconButton(
                        onPressed: () => setState(() => rating = value),
                        icon: Icon(
                          selected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                        ),
                        color: color,
                        tooltip: value.toString(),
                      );
                    }),
                  ),
                  if (helperText.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      helperText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (rating > 0 && rating <= 3) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(
                          _ReviewPromptResult(
                            rating: rating,
                            action: _ReviewPromptAction.contactSupport,
                          ),
                        ),
                        icon: const Icon(Icons.support_agent_outlined),
                        label: Text(loc.contactSupport),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: Text(loc.reviewPromptLater),
                ),
                FilledButton(
                  onPressed: rating > 0
                      ? () => Navigator.of(dialogContext).pop(
                          _ReviewPromptResult(
                            rating: rating,
                            action: rating >= 4
                                ? _ReviewPromptAction.writeReview
                                : _ReviewPromptAction.dismiss,
                          ),
                        )
                      : null,
                  child: Text(primaryLabel),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _requestStoreReview() async {
    try {
      final inAppReview = InAppReview.instance;
      final available = await inAppReview.isAvailable();
      if (available) {
        await inAppReview.requestReview();
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await inAppReview.openStoreListing();
      }
    } catch (_) {
      if (defaultTargetPlatform != TargetPlatform.android) return;
      final package = 'com.anmt2805.news_crawl';
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$package',
      );
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Future<void> _signInWithGoogle() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;
      final auth = await account.authentication;
      if ((auth.accessToken == null || auth.accessToken!.isEmpty) &&
          (auth.idToken == null || auth.idToken!.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.loginFailedBody)));
        return;
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final userCred = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      if (!mounted) return;
      setState(() {
        _user = userCred.user;
      });
      await _loadUserStateFromFirestore();
      await _loadSavedArticlesFromServer();
      await _syncGuestTracking(force: true);
    } on FirebaseAuthException catch (error) {
      debugPrint('FirebaseAuth sign-in failed: ${error.code} ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.loginFailedBody)));
    } on PlatformException catch (error) {
      debugPrint('Google sign-in failed: ${error.code} ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.loginFailedBody)));
    } catch (error) {
      debugPrint('Google sign-in failed: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.loginFailedBody)));
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      try {
        await _googleSignIn.disconnect();
      } catch (_) {}
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _user = null;
    });
    await _resetLocalUserStateAfterLogout();
  }

  Future<void> _resetLocalUserStateAfterLogout() async {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
      _tokenBalance = 0;
      _tokenLedger = [];
      _tabExpiry.clear();
      _autoRenewEnabled = false;
      _keywords = List.filled(_tabs.length, '');
      _tabRegions = List.filled(_tabs.length, 'ALL');
      _canonicalKeywords.clear();
    });
    await _saveLocalState();
    await _syncTopicSubscriptions();
  }

  Future<void> _loadUserStateFromFirestore() async {
    final user = _user;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await _saveUserStateToFirestore();
      return;
    }
    final data = snapshot.data() ?? {};
    if (data['banned'] == true) {
      _markUserBanned();
      return;
    }
    if (!mounted) return;
    final cloudState = _userStateFromMap(data);
    final localState = _userStateFromLocal();
    final mergedLocal = _mergeTokenState(localState, cloudState);
    final pendingKeywordSync =
        prefs.getBool(_pendingKeywordSyncKey(user.uid)) ?? false;
    if (pendingKeywordSync && localState.hasData) {
      _applyUserState(mergedLocal);
      await _saveLocalState();
      final synced = await _saveUserStateToFirestore();
      if (synced) {
        await prefs.setBool(_pendingKeywordSyncKey(user.uid), false);
      }
      await _syncTopicSubscriptions();
      await _applyAutoRenewOnServer();
      await _pruneExpiredTabs();
      return;
    }
    final syncMode = prefs.getString(_syncModeKey(user.uid));
    if (syncMode == 'local' && localState.hasData) {
      if (!cloudState.hasData) {
        await _saveUserStateToFirestore();
      }
      _applyUserState(mergedLocal);
      await _saveLocalState();
      await _syncTopicSubscriptions();
      await _applyAutoRenewOnServer();
      await _pruneExpiredTabs();
      return;
    }
    if (!cloudState.hasData && localState.hasData) {
      await _saveUserStateToFirestore();
      _applyUserState(localState);
      await _saveLocalState();
      await _syncTopicSubscriptions();
      await _applyAutoRenewOnServer();
      await _pruneExpiredTabs();
      return;
    }
    final promptKey = _syncPromptKey(user.uid);
    final alreadyPrompted = prefs.getBool(promptKey) ?? false;
    if (cloudState.hasData &&
        localState.hasData &&
        !_hasPromptedSync &&
        !alreadyPrompted) {
      _hasPromptedSync = true;
      await prefs.setBool(promptKey, true);
      final loc = AppLocalizations.of(context)!;
      final useCloud =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(loc.syncChoiceTitle),
              content: Text(loc.syncChoiceBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.syncChoiceKeepLocal),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.syncChoiceUseCloud),
                ),
              ],
            ),
          ) ??
          false;
      if (!mounted) return;
      if (useCloud) {
        await prefs.setString(_syncModeKey(user.uid), 'cloud');
        _applyUserState(cloudState);
        await _saveLocalState();
        await _syncTopicSubscriptions();
        await _applyAutoRenewOnServer();
      } else {
        await prefs.setString(_syncModeKey(user.uid), 'local');
        _applyUserState(mergedLocal);
        await _saveLocalState();
        await _saveUserStateToFirestore();
        await _syncTopicSubscriptions();
        await _applyAutoRenewOnServer();
      }
      await _pruneExpiredTabs();
      return;
    }
    if (cloudState.hasData) {
      _applyUserState(cloudState);
      await _saveLocalState();
      await _syncTopicSubscriptions();
      await _applyAutoRenewOnServer();
      await _pruneExpiredTabs();
    }
  }

  _UserStateSnapshot _userStateFromMap(Map<String, dynamic> data) {
    final tokenBalance = (data['tokenBalance'] as num?)?.toInt() ?? 0;
    final ledgerRaw = data['tokenLedger'];
    final keywordRaw = data['tabKeywords'];
    final ledger = <TokenLedgerEntry>[];
    if (ledgerRaw is List) {
      for (final item in ledgerRaw.whereType<Map<String, dynamic>>()) {
        ledger.add(TokenLedgerEntry.fromJson(item));
      }
    }
    final keywords = <String>[];
    if (keywordRaw is List) {
      keywords.addAll(keywordRaw.map((e) => e.toString().trim()));
    }
    final regions = <String>[];
    final regionsRaw = data['tabRegions'];
    if (regionsRaw is List) {
      regions.addAll(regionsRaw.map((e) => e.toString().trim().toUpperCase()));
    }
    if (regions.isEmpty) {
      regions.addAll(List.filled(_tabs.length, 'ALL'));
    } else if (regions.length != _tabs.length) {
      final padded = List<String>.filled(_tabs.length, 'ALL');
      for (var i = 0; i < _tabs.length; i++) {
        if (i < regions.length && regions[i].isNotEmpty) {
          padded[i] = regions[i];
        }
      }
      regions
        ..clear()
        ..addAll(padded);
    }
    final expiry = <int, DateTime>{};
    final expiryRaw = data['tabExpiry'];
    if (expiryRaw is Map) {
      expiryRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        final date = DateTime.tryParse(value.toString());
        if (index != null && date != null) {
          expiry[index] = date;
        }
      });
    }
    final prefsRaw = data['notificationPrefs'];
    final prefs = prefsRaw is Map<String, dynamic>
        ? NotificationPreferences.fromJson(prefsRaw)
        : NotificationPreferences(
            breakingEnabled: true,
            keywordSeverity4: true,
            keywordSeverity5: true,
          );
    final autoRenewEnabled = data['autoRenewEnabled'] as bool? ?? false;
    final canonicalRaw = data['canonicalKeywords'];
    final canonical = <int, String>{};
    if (canonicalRaw is Map) {
      canonicalRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        if (index != null && value != null) {
          canonical[index] = value.toString();
        }
      });
    }
    return _UserStateSnapshot(
      tokenBalance: tokenBalance,
      tokenLedger: ledger,
      tabExpiry: expiry,
      notificationPrefs: prefs,
      autoRenewEnabled: autoRenewEnabled,
      tabKeywords: keywords,
      tabRegions: regions,
      canonicalKeywords: canonical,
    );
  }

  _UserStateSnapshot _userStateFromLocal() {
    return _UserStateSnapshot(
      tokenBalance: _tokenBalance,
      tokenLedger: List<TokenLedgerEntry>.from(_tokenLedger),
      tabExpiry: Map<int, DateTime>.from(_tabExpiry),
      notificationPrefs: _notificationPrefs,
      autoRenewEnabled: _autoRenewEnabled,
      tabKeywords: List<String>.from(_keywords),
      tabRegions: List<String>.from(_tabRegions),
      canonicalKeywords: Map<int, String>.from(_canonicalKeywords),
    );
  }

  _UserStateSnapshot _mergeTokenState(
    _UserStateSnapshot base,
    _UserStateSnapshot tokenSource,
  ) {
    return _UserStateSnapshot(
      tokenBalance: tokenSource.tokenBalance,
      tokenLedger: List<TokenLedgerEntry>.from(tokenSource.tokenLedger),
      tabExpiry: Map<int, DateTime>.from(tokenSource.tabExpiry),
      notificationPrefs: base.notificationPrefs,
      autoRenewEnabled: base.autoRenewEnabled,
      tabKeywords: List<String>.from(base.tabKeywords),
      tabRegions: List<String>.from(base.tabRegions),
      canonicalKeywords: Map<int, String>.from(base.canonicalKeywords),
    );
  }

  String _syncPromptKey(String uid) => 'syncPrompted_$uid';
  String _syncModeKey(String uid) => 'syncMode_$uid';
  String _pendingKeywordSyncKey(String uid) => 'pendingKeywordSync_$uid';

  Future<void> _setPendingUserStateSync(
    bool pending, {
    String? uidOverride,
  }) async {
    final uid = (uidOverride ?? _user?.uid ?? '').trim();
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKeywordSyncKey(uid), pending);
  }

  void _applyUserState(_UserStateSnapshot snapshot) {
    setState(() {
      _tokenBalance = snapshot.tokenBalance;
      _tokenLedger = List<TokenLedgerEntry>.from(snapshot.tokenLedger);
      _tabExpiry
        ..clear()
        ..addAll(snapshot.tabExpiry);
      _notificationPrefs = snapshot.notificationPrefs;
      _autoRenewEnabled = snapshot.autoRenewEnabled;
      if (snapshot.tabKeywords.isNotEmpty) {
        final padded = List<String>.filled(_tabs.length, '');
        for (var i = 0; i < _tabs.length; i++) {
          if (i < snapshot.tabKeywords.length) {
            padded[i] = snapshot.tabKeywords[i];
          }
        }
        _keywords = padded;
      }
      if (snapshot.tabRegions.isNotEmpty) {
        final padded = List<String>.filled(_tabs.length, 'ALL');
        for (var i = 0; i < _tabs.length; i++) {
          if (i < snapshot.tabRegions.length &&
              snapshot.tabRegions[i].isNotEmpty) {
            padded[i] = snapshot.tabRegions[i].toUpperCase();
          }
        }
        _tabRegions = padded;
      }
      if (snapshot.canonicalKeywords.isNotEmpty) {
        _canonicalKeywords
          ..clear()
          ..addAll(snapshot.canonicalKeywords);
      }
    });
  }

  Future<void> _saveLocalState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tabKeywords', _keywords);
    await prefs.setInt('tokenBalance', _tokenBalance);
    await prefs.setString(
      'tokenLedger',
      jsonEncode(_tokenLedger.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'tabExpiry',
      jsonEncode(
        _tabExpiry.map(
          (key, value) => MapEntry(key.toString(), value.toIso8601String()),
        ),
      ),
    );
    await prefs.setString(
      'notificationPrefs',
      jsonEncode(_notificationPrefs.toJson()),
    );
    await prefs.setBool('autoRenewEnabled', _autoRenewEnabled);
    await prefs.setStringList('tabRegions', _tabRegions);
    await prefs.setString(
      'canonicalKeywords',
      jsonEncode(
        _canonicalKeywords.map((key, value) => MapEntry(key.toString(), value)),
      ),
    );
    await prefs.setString(
      'notificationHistory',
      jsonEncode(_notificationHistory.map((e) => e.toJson()).toList()),
    );
    await prefs.setString('notifiedUrls', jsonEncode(_notifiedUrls.toList()));
    await prefs.setBool('notificationsUnread', _hasUnreadNotifications);
    await prefs.setString(
      'savedArticles',
      jsonEncode(_savedArticles.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'blockedDomains',
      jsonEncode(_blockedDomains.toList()),
    );
    await prefs.setString('reportedUrls', jsonEncode(_reportedUrls.toList()));
  }

  Future<bool> _saveUserStateToFirestore() async {
    final user = _user;
    final uid = (user?.uid ?? '').trim();
    if (uid.isEmpty) return false;
    var synced = false;
    try {
      final payload = await _postWithAuth('/users/state', {
        'tabKeywords': _keywords,
        'tabRegions': _tabRegions,
        'canonicalKeywords': _canonicalKeywords.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        'notificationPrefs': _notificationPrefs.toJson(),
        'autoRenewEnabled': _autoRenewEnabled,
        'language': _language,
      });
      final serverTimeMs = int.tryParse(
        payload?['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      final status =
          int.tryParse(payload?['statusCode']?.toString() ?? '') ?? 0;
      synced = status >= 200 && status < 300;
    } catch (_) {
      synced = false;
    }
    await _setPendingUserStateSync(!synced, uidOverride: uid);
    return synced;
  }

  Future<void> _loadSavedArticlesFromServer() async {
    final user = _user;
    if (user == null || _savedSyncInFlight) return;
    _savedSyncInFlight = true;
    try {
      final idToken = await user.getIdToken();
      final uri = Uri.parse('$apiBaseUrl/saved_articles');
      final response = await http
          .get(uri, headers: {'Authorization': 'Bearer $idToken'})
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 403) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            _handleBannedResponse(response.statusCode, decoded);
            if (_bannedNotifier.value) return;
          }
        } catch (_) {}
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      if (response.body.isEmpty) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final itemsRaw = decoded['items'];
      if (itemsRaw is! List) return;
      final loaded = <SavedArticle>[];
      for (final entry in itemsRaw) {
        if (entry is! Map) continue;
        final data = entry.cast<String, dynamic>();
        final severityRaw = data['severity'];
        int parsedSeverity = 3;
        if (severityRaw is num) {
          parsedSeverity = severityRaw.toInt();
        } else {
          parsedSeverity = int.tryParse(severityRaw?.toString() ?? '') ?? 3;
        }
        final item = NewsItem(
          title: (data['title'] ?? '').toString(),
          summary: (data['summary'] ?? '').toString(),
          content: '',
          url: (data['url'] ?? '').toString(),
          resolvedUrl: (data['resolvedUrl'] ?? '').toString(),
          sourceUrl: (data['sourceUrl'] ?? '').toString(),
          source: (data['source'] ?? '').toString(),
          publishedAt: (data['publishedAt'] ?? '').toString(),
          severity: parsedSeverity.clamp(1, 5),
        );
        final savedAt =
            DateTime.tryParse(data['savedAt']?.toString() ?? '') ??
            DateTime.now();
        loaded.add(SavedArticle(item: item, savedAt: savedAt));
      }
      if (mounted) {
        setState(() {
          _savedArticles = loaded;
          _savedArticleKeys
            ..clear()
            ..addAll(_savedArticles.map((e) => _savedArticleId(e.item)));
        });
      } else {
        _savedArticles = loaded;
        _savedArticleKeys
          ..clear()
          ..addAll(_savedArticles.map((e) => _savedArticleId(e.item)));
      }
      await _saveLocalState();
    } catch (_) {
    } finally {
      _savedSyncInFlight = false;
    }
  }

  bool _isTabUnlocked(int index) {
    if (index == 0) return true;
    if (index == 1) return true;
    final expiry = _tabExpiry[index];
    if (expiry == null) return false;
    return expiry.isAfter(_serverNow());
  }

  Future<void> _handleTabTap(int index) async {
    HapticFeedback.selectionClick();
    final safeIndex = index.clamp(0, _tabs.length - 1);
    if (safeIndex <= 1 || _isTabUnlocked(safeIndex)) {
      setState(() {
        _currentIndex = safeIndex;
      });
      return;
    }

    final loc = AppLocalizations.of(context)!;
    if (_user == null) {
      final shouldLogin =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(loc.loginRequiredTitle),
              content: Text(loc.loginRequiredBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.continueWithGoogle),
                ),
              ],
            ),
          ) ??
          false;
      if (shouldLogin) {
        _togglePanel(_PanelType.account);
      }
      return;
    }

    final firstLocked = List<int>.generate(
      _tabs.length,
      (i) => i,
    ).firstWhere((i) => i >= 2 && !_isTabUnlocked(i), orElse: () => safeIndex);
    final targetIndex = firstLocked.clamp(2, safeIndex);

    if (_tokenBalance < _tabMonthlyCost) {
      final openStore =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(loc.insufficientTokensTitle),
              content: Text(loc.insufficientTokensBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.noThanks),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.openTokenStore),
                ),
              ],
            ),
          ) ??
          false;
      if (openStore) {
        _togglePanel(_PanelType.account);
      }
      return;
    }

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(loc.purchaseTabTitle(_tabs[targetIndex])),
            content: Text(loc.purchaseTabBody(_tabMonthlyCost)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(loc.confirmPurchase),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    final purchased = await _purchaseTabOnServer(targetIndex);
    if (!purchased) return;
    if (!mounted) return;
    setState(() {
      _currentIndex = targetIndex;
    });
  }

  Future<void> _promptTabSubscription(int tabIndex) async {
    if (!_showPanel) return;
    if (_isTabUnlocked(tabIndex)) return;
    final loc = AppLocalizations.of(context)!;
    if (_user == null) {
      final shouldLogin =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(loc.loginRequiredTitle),
              content: Text(loc.loginRequiredBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.continueWithGoogle),
                ),
              ],
            ),
          ) ??
          false;
      if (shouldLogin) {
        _togglePanel(_PanelType.account);
      }
      return;
    }

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(loc.subscribeTabPromptTitle),
            content: Text(loc.purchaseTabBody(_tabMonthlyCost)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(loc.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    if (_tokenBalance < _tabMonthlyCost) {
      final openStore =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(loc.insufficientTokensPromptTitle),
              content: Text(loc.insufficientTokensPromptBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.confirm),
                ),
              ],
            ),
          ) ??
          false;
      if (openStore) {
        _togglePanel(_PanelType.account);
      }
      return;
    }

    final purchased = await _purchaseTabOnServer(tabIndex);
    if (!purchased) return;
  }

  bool get _iapSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  String get _currentIapStoreType {
    return _androidBillingStore == _AndroidBillingStore.onestore
        ? 'onestore'
        : 'play';
  }

  Future<_AndroidBillingStore> _resolveAndroidBillingStore() async {
    if (!_iapSupportedPlatform) return _AndroidBillingStore.play;
    try {
      final flavor =
          (await _appConfigChannel.invokeMethod<String>('storeFlavor') ?? '')
              .toLowerCase();
      if (flavor.contains('onestore')) {
        return _AndroidBillingStore.onestore;
      }
    } catch (_) {}
    return _AndroidBillingStore.play;
  }

  Future<void> _initIap() async {
    if (!_iapSupportedPlatform) return;
    _androidBillingStore = await _resolveAndroidBillingStore();
    if (_androidBillingStore == _AndroidBillingStore.onestore) {
      await _initOneStoreIap();
      return;
    }
    await _initPlayIap();
  }

  Future<void> _initPlayIap() async {
    _iapPurchaseSub ??= _iap.purchaseStream.listen(
      _handlePlayPurchaseUpdates,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _iapPurchaseInFlight = false;
          _iapError = 'Purchase stream error.';
        });
      },
    );
    final available = await _iap.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _iapAvailable = false;
        _iapError = 'Store unavailable.';
      });
      return;
    }
    setState(() {
      _iapAvailable = true;
    });
    await _loadIapProducts();
    await _recoverPendingPurchases();
  }

  Future<void> _initOneStoreIap() async {
    try {
      await _ensureOneStoreClientInitialized();
      if (!mounted) return;
      setState(() {
        _iapAvailable = true;
        _iapError = '';
      });
      await _loadIapProducts();
      await _recoverPendingPurchases();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _iapAvailable = false;
        _iapError = 'ONE store unavailable.';
      });
      debugPrint('ONE store init failed: $error');
    }
  }

  Future<void> _ensureOneStoreClientInitialized() async {
    _oneStoreAuthClient ??= OneStoreAuthClient();
    _oneStoreIap ??= PurchaseClientManager.instance;
    if (!_oneStoreIapInitialized) {
      _oneStoreIap!.initialize();
      _oneStoreIapInitialized = true;
    }
    _oneStorePurchaseSub ??= _oneStoreIap!.purchasesUpdatedStream.listen(
      _handleOneStorePurchaseUpdates,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _iapPurchaseInFlight = false;
          if (error is IapResult) {
            _iapError = _oneStoreErrorMessage(error);
          } else {
            _iapError = 'Purchase stream error.';
          }
        });
      },
    );
  }

  Future<void> _loadIapProducts() async {
    if (!_iapSupportedPlatform) return;
    if (_androidBillingStore == _AndroidBillingStore.onestore) {
      await _loadOneStoreIapProducts();
      return;
    }
    await _loadPlayIapProducts();
  }

  Future<void> _retryIapProducts() async {
    if (_iapSupportedPlatform &&
        _androidBillingStore == _AndroidBillingStore.onestore) {
      await _recoverOneStorePendingPurchases();
    }
    await _loadIapProducts();
  }

  Future<void> _loadPlayIapProducts() async {
    setState(() {
      _iapLoading = true;
      _iapError = '';
    });
    final productMap = await _fetchIapProductMap();
    if (!mounted) return;
    if (productMap.isEmpty) {
      setState(() {
        _iapLoading = false;
        _iapError = 'No products available.';
      });
      return;
    }
    final response = await _iap.queryProductDetails(productMap.keys.toSet());
    if (!mounted) return;
    if (response.error != null) {
      setState(() {
        _iapLoading = false;
        _iapError = response.error!.message;
      });
      return;
    }
    _iapProductTokens
      ..clear()
      ..addAll(productMap);
    _iapProducts =
        response.productDetails
            .map(
              (product) => _StoreProduct(
                id: product.id,
                title: product.title,
                price: product.price,
                rawPrice: product.rawPrice,
                currencyCode: product.currencyCode,
                playProduct: product,
              ),
            )
            .toList()
          ..sort((a, b) {
            final tokensA = _iapProductTokens[a.id] ?? 0;
            final tokensB = _iapProductTokens[b.id] ?? 0;
            return tokensA.compareTo(tokensB);
          });
    setState(() {
      _iapLoading = false;
    });
  }

  Future<void> _loadOneStoreIapProducts() async {
    await _ensureOneStoreClientInitialized();
    setState(() {
      _iapLoading = true;
      _iapError = '';
    });
    final productMap = await _fetchIapProductMap();
    if (!mounted) return;
    if (productMap.isEmpty) {
      setState(() {
        _iapLoading = false;
        _iapError = 'No products available.';
      });
      return;
    }

    ProductDetailsResponse response = await _oneStoreIap!.queryProductDetails(
      productIds: productMap.keys.toList(),
      productType: ProductType.inapp,
    );
    if (!response.iapResult.isSuccess()) {
      final recovered = await _tryRecoverOneStoreSession(response.iapResult);
      if (recovered) {
        response = await _oneStoreIap!.queryProductDetails(
          productIds: productMap.keys.toList(),
          productType: ProductType.inapp,
        );
      }
    }
    if (!mounted) return;
    if (!response.iapResult.isSuccess()) {
      setState(() {
        _iapLoading = false;
        _iapError = _oneStoreErrorMessage(response.iapResult);
      });
      return;
    }

    _iapProductTokens
      ..clear()
      ..addAll(productMap);
    _iapProducts =
        response.productDetailsList
            .map(
              (product) => _StoreProduct(
                id: product.productId,
                title: product.title,
                price: product.price,
                rawPrice: _oneStorePriceAsDouble(product.priceAmountMicros),
                currencyCode: product.priceCurrencyCode,
                oneStoreProduct: product,
              ),
            )
            .where((product) => _iapProductTokens.containsKey(product.id))
            .toList()
          ..sort((a, b) {
            final tokensA = _iapProductTokens[a.id] ?? 0;
            final tokensB = _iapProductTokens[b.id] ?? 0;
            return tokensA.compareTo(tokensB);
          });

    setState(() {
      _iapLoading = false;
    });
  }

  Future<void> _recoverPendingPurchases() async {
    if (!_iapSupportedPlatform) return;
    if (_user == null) return;
    if (!_iapAvailable) return;
    if (_androidBillingStore == _AndroidBillingStore.onestore) {
      await _recoverOneStorePendingPurchases();
      return;
    }
    await _recoverPlayPendingPurchases();
  }

  Future<void> _recoverPlayPendingPurchases() async {
    try {
      final androidAddition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await androidAddition.queryPastPurchases();
      if (response.error != null) {
        debugPrint('IAP past purchases error: ${response.error}');
        return;
      }
      for (final purchase in response.pastPurchases) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          final verified = await _verifyPlayPurchaseWithServer(purchase);
          if (verified && purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        }
      }
    } catch (error) {
      debugPrint('IAP past purchases failed: $error');
    }
  }

  Future<void> _recoverOneStorePendingPurchases() async {
    try {
      await _ensureOneStoreClientInitialized();
      PurchasesResultResponse response = await _oneStoreIap!.queryPurchases(
        productType: ProductType.inapp,
      );
      if (!response.iapResult.isSuccess()) {
        final recovered = await _tryRecoverOneStoreSession(response.iapResult);
        if (recovered) {
          response = await _oneStoreIap!.queryPurchases(
            productType: ProductType.inapp,
          );
        }
      }
      if (!response.iapResult.isSuccess()) {
        debugPrint('ONE store past purchases error: ${response.iapResult}');
        return;
      }

      for (final purchase in response.purchasesList) {
        if (purchase.purchaseState != PurchaseState.purchased) continue;
        final verified = await _verifyOneStorePurchaseWithServer(purchase);
        if (!verified) continue;
        final consumeResult = await _oneStoreIap!.consumePurchase(
          purchaseData: purchase,
        );
        if (!consumeResult.isSuccess()) {
          debugPrint('ONE store consume failed: ${consumeResult.message}');
        }
      }
    } catch (error) {
      debugPrint('ONE store past purchases failed: $error');
    }
  }

  Future<Map<String, int>> _fetchIapProductMap() async {
    try {
      final uri = Uri.parse(
        '$apiBaseUrl/iap/products',
      ).replace(queryParameters: {'storeType': _currentIapStoreType});
      final response = await http.get(uri);
      if (response.statusCode != 200) return {};
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (decoded['ok'] != true) return {};
      final serverTimeMs = int.tryParse(
        decoded['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      final products = decoded['products'];
      if (products is! List) return {};
      final map = <String, int>{};
      for (final item in products) {
        if (item is! Map) continue;
        final productId = item['productId']?.toString() ?? '';
        final tokens = int.tryParse(item['tokens']?.toString() ?? '');
        if (productId.isEmpty || tokens == null || tokens <= 0) continue;
        map[productId] = tokens;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Future<void> _handlePlayPurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) {
          setState(() {
            _iapPurchaseInFlight = true;
          });
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _iapPurchaseInFlight = false;
          });
          _showIapMessage('Purchase failed.');
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _iapPurchaseInFlight = false;
          });
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          final verified = await _verifyPlayPurchaseWithServer(purchase);
          if (verified && purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
        } catch (error) {
          debugPrint('IAP purchase handling failed: $error');
          if (mounted) {
            _showIapMessage('Purchase verification failed.');
          }
        } finally {
          if (mounted) {
            setState(() {
              _iapPurchaseInFlight = false;
            });
          }
        }
      }
    }
  }

  Future<void> _handleOneStorePurchaseUpdates(
    List<PurchaseData> purchases,
  ) async {
    for (final purchase in purchases) {
      if (purchase.purchaseState != PurchaseState.purchased) {
        if (mounted) {
          setState(() {
            _iapPurchaseInFlight = false;
          });
        }
        continue;
      }
      try {
        final verified = await _verifyOneStorePurchaseWithServer(purchase);
        if (verified) {
          final consumeResult = await _oneStoreIap!.consumePurchase(
            purchaseData: purchase,
          );
          if (!consumeResult.isSuccess()) {
            debugPrint('ONE store consume failed: ${consumeResult.message}');
          }
        }
      } catch (error) {
        debugPrint('ONE store purchase handling failed: $error');
        if (mounted) {
          _showIapMessage('Purchase verification failed.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _iapPurchaseInFlight = false;
          });
        }
      }
    }
  }

  Future<bool> _verifyPlayPurchaseWithServer(PurchaseDetails purchase) async {
    if (_user == null) {
      _showIapMessage('Login required.');
      return false;
    }
    final purchaseToken = purchase.verificationData.serverVerificationData;
    if (purchaseToken.isEmpty) {
      _showIapMessage('Invalid purchase token.');
      return false;
    }
    final idToken = await _user!.getIdToken();
    final response = await http.post(
      Uri.parse('$apiBaseUrl/iap/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'productId': purchase.productID,
        'purchaseToken': purchaseToken,
        'platform': 'android',
        'storeType': 'play',
      }),
    );
    return _applyVerifiedPurchaseResponse(response);
  }

  Future<bool> _verifyOneStorePurchaseWithServer(PurchaseData purchase) async {
    if (_user == null) {
      _showIapMessage('Login required.');
      return false;
    }
    final purchaseToken = purchase.purchaseToken;
    if (purchaseToken.isEmpty) {
      _showIapMessage('Invalid purchase token.');
      return false;
    }
    final idToken = await _user!.getIdToken();
    final response = await http.post(
      Uri.parse('$apiBaseUrl/iap/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'productId': purchase.productId,
        'purchaseToken': purchaseToken,
        'platform': 'android',
        'storeType': 'onestore',
        'marketCode': _oneStoreMarketCode,
      }),
    );
    return _applyVerifiedPurchaseResponse(response);
  }

  Future<bool> _applyVerifiedPurchaseResponse(http.Response response) async {
    if (response.statusCode == 403) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _handleBannedResponse(response.statusCode, decoded);
          if (_bannedNotifier.value) {
            return false;
          }
        }
      } catch (_) {}
    }
    if (response.statusCode != 200) {
      String err = 'Purchase verification failed.';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          err = 'Purchase verification failed: ${decoded['error']}';
        }
      } catch (_) {}
      _showIapMessage(err);
      return false;
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    if (decoded['ok'] != true) {
      _showIapMessage(
        'Purchase verification failed: ${decoded['error'] ?? 'unknown'}',
      );
      return false;
    }

    final balance = int.tryParse(decoded['tokenBalance']?.toString() ?? '');
    final entryRaw = decoded['tokenLedgerEntry'];
    if (balance != null && mounted) {
      setState(() {
        _tokenBalance = balance;
        if (entryRaw is Map<String, dynamic>) {
          _tokenLedger.insert(0, TokenLedgerEntry.fromJson(entryRaw));
        }
      });
      await _saveLocalState();
    }
    return true;
  }

  Future<void> _buyProduct(_StoreProduct product) async {
    if (_iapPurchaseInFlight) return;
    final loc = AppLocalizations.of(context)!;
    if (_user == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.loginRequiredTitle),
          content: Text(loc.loginRequiredBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.confirm),
            ),
          ],
        ),
      );
      if (mounted) {
        _togglePanel(_PanelType.account);
      }
      return;
    }
    if (_androidBillingStore == _AndroidBillingStore.onestore) {
      await _buyOneStoreProduct(product);
      return;
    }
    await _buyPlayProduct(product);
  }

  Future<void> _buyPlayProduct(_StoreProduct product) async {
    final playProduct = product.playProduct;
    if (playProduct == null) {
      _showIapMessage('Unable to start purchase.');
      return;
    }
    setState(() {
      _iapPurchaseInFlight = true;
    });
    final purchaseParam = PurchaseParam(productDetails: playProduct);
    bool started = false;
    try {
      started = await _iap.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
    } catch (error) {
      debugPrint('IAP start purchase failed: $error');
      if (mounted) {
        setState(() {
          _iapPurchaseInFlight = false;
        });
        _showIapMessage('Unable to start purchase.');
      }
      return;
    }
    if (!started && mounted) {
      setState(() {
        _iapPurchaseInFlight = false;
      });
      _showIapMessage('Unable to start purchase.');
    }
  }

  Future<void> _buyOneStoreProduct(_StoreProduct product) async {
    await _ensureOneStoreClientInitialized();
    final oneStoreProduct = product.oneStoreProduct;
    if (oneStoreProduct == null) {
      _showIapMessage('Unable to start purchase.');
      return;
    }

    setState(() {
      _iapPurchaseInFlight = true;
    });
    IapResult result = await _oneStoreIap!.launchPurchaseFlow(
      productDetail: oneStoreProduct,
    );
    if (!result.isSuccess()) {
      final recovered = await _tryRecoverOneStoreSession(result);
      if (recovered) {
        result = await _oneStoreIap!.launchPurchaseFlow(
          productDetail: oneStoreProduct,
        );
      }
    }
    if (result.responseCode == PurchaseResponse.itemAlreadyOwned) {
      await _recoverOneStorePendingPurchases();
      result = await _oneStoreIap!.launchPurchaseFlow(
        productDetail: oneStoreProduct,
      );
    }
    if (!result.isSuccess()) {
      if (mounted) {
        setState(() {
          _iapPurchaseInFlight = false;
        });
      }
      _showIapMessage(_oneStoreErrorMessage(result));
    }
  }

  Future<bool> _tryRecoverOneStoreSession(IapResult result) async {
    if (result.responseCode == PurchaseResponse.needLogin) {
      _oneStoreAuthClient ??= OneStoreAuthClient();
      final signInResult = await _oneStoreAuthClient!.launchSignInFlow();
      if (signInResult.isSuccess()) return true;
      if (signInResult.code == AuthResponse.userCanceled) {
        _showIapMessage('ONE store login canceled.');
      } else {
        _showIapMessage('ONE store login failed.');
      }
      return false;
    }
    if (result.responseCode == PurchaseResponse.needUpdate ||
        result.responseCode == PurchaseResponse.updateOrInstall) {
      try {
        await _oneStoreIap?.launchUpdateOrInstall();
      } catch (_) {}
      _showIapMessage('Please update/install ONE store.');
      return false;
    }
    return false;
  }

  String _oneStoreErrorMessage(IapResult result) {
    final loc = AppLocalizations.of(context)!;
    final code = result.responseCode;
    if (code == PurchaseResponse.userCanceled) return 'Purchase canceled.';
    if (code == PurchaseResponse.itemAlreadyOwned) {
      return 'Owned item detected. Please try again after recovery.';
    }
    if (code == PurchaseResponse.needLogin) return 'ONE store login required.';
    if (code == PurchaseResponse.needUpdate ||
        code == PurchaseResponse.updateOrInstall) {
      return 'Please update/install ONE store.';
    }
    final msg = (result.message ?? '').trim();
    if (msg.isNotEmpty) {
      final normalized = msg.toLowerCase();
      final isGenericPurchaseFailure =
          normalized.contains('결제에 실패했습니다') ||
          normalized.contains('purchase failed');
      if (isGenericPurchaseFailure) {
        return loc.purchaseFailedCheckPayment;
      }
      return msg;
    }
    return loc.purchaseFailedCheckPayment;
  }

  double _oneStorePriceAsDouble(String priceAmountMicros) {
    final micros = num.tryParse(priceAmountMicros)?.toDouble() ?? 0;
    if (micros <= 0) return 0;
    return micros / 1000000;
  }

  String get _oneStoreMarketCode {
    final code = (_oneStoreIap?.storeCode ?? '').trim().toUpperCase();
    if (code == 'MKT_ONE' || code == 'MKT_GLB') return code;
    return '';
  }

  void _showIapMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showTokenMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _postWithAuth(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _postJson(path, body, withAuth: true);
  }

  Future<Map<String, dynamic>?> _postJson(
    String path,
    Map<String, dynamic> body, {
    required bool withAuth,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (withAuth) {
        if (_user == null) return null;
        final idToken = await _user!.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
      }
      final response = await http.post(
        Uri.parse('$apiBaseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );
      Map<String, dynamic> result = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          result = Map<String, dynamic>.from(decoded);
        }
      }
      result['statusCode'] = response.statusCode;
      _handleBannedResponse(response.statusCode, result);
      final serverTimeMs = int.tryParse(
        result['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getWithAuth(String path) async {
    try {
      if (_user == null) return null;
      final idToken = await _user!.getIdToken();
      final response = await http.get(
        Uri.parse('$apiBaseUrl$path'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      Map<String, dynamic> result = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          result = Map<String, dynamic>.from(decoded);
        }
      }
      result['statusCode'] = response.statusCode;
      _handleBannedResponse(response.statusCode, result);
      final serverTimeMs = int.tryParse(
        result['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> _refreshTokenStateFromServer() async {
    if (_user == null) return;
    final payload = await _getWithAuth('/users/state_snapshot');
    if (payload == null || payload['ok'] != true) return;
    bool changed = false;
    final balance = int.tryParse(payload['tokenBalance']?.toString() ?? '');
    if (balance != null) {
      _tokenBalance = balance;
      changed = true;
    }
    final ledgerRaw = payload['tokenLedger'];
    if (ledgerRaw is List) {
      _tokenLedger = ledgerRaw
          .whereType<Map<String, dynamic>>()
          .map(TokenLedgerEntry.fromJson)
          .toList();
      changed = true;
    }
    final expiryRaw = payload['tabExpiry'];
    if (expiryRaw is Map) {
      _tabExpiry.clear();
      expiryRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        final date = DateTime.tryParse(value.toString());
        if (index != null && date != null) {
          _tabExpiry[index] = date;
        }
      });
      changed = true;
    }
    final autoRenewEnabled = payload['autoRenewEnabled'];
    if (autoRenewEnabled is bool) {
      _autoRenewEnabled = autoRenewEnabled;
      changed = true;
    }
    if (changed) {
      if (mounted) {
        setState(() {});
      }
      await _saveLocalState();
    }
  }

  Future<void> _applyServerTokenUpdate(Map<String, dynamic> payload) async {
    bool changed = false;
    final serverTimeMs = int.tryParse(
      payload['serverTimeMs']?.toString() ?? '',
    );
    if (serverTimeMs != null) {
      await _updateServerTimeOffset(serverTimeMs);
    }
    final balance = int.tryParse(payload['tokenBalance']?.toString() ?? '');
    if (balance != null) {
      _tokenBalance = balance;
      changed = true;
    }
    final entryRaw = payload['tokenLedgerEntry'];
    if (entryRaw is Map<String, dynamic>) {
      _tokenLedger.insert(0, TokenLedgerEntry.fromJson(entryRaw));
      changed = true;
    }
    final entriesRaw = payload['tokenLedgerEntries'];
    if (entriesRaw is List) {
      for (final entry in entriesRaw.reversed) {
        if (entry is Map<String, dynamic>) {
          _tokenLedger.insert(0, TokenLedgerEntry.fromJson(entry));
          changed = true;
        }
      }
    }
    final expiryRaw = payload['tabExpiry'];
    if (expiryRaw is Map) {
      expiryRaw.forEach((key, value) {
        final index = int.tryParse(key.toString());
        final date = DateTime.tryParse(value.toString());
        if (index != null && date != null) {
          _tabExpiry[index] = date;
          changed = true;
        }
      });
    }
    final autoRenewEnabled = payload['autoRenewEnabled'];
    if (autoRenewEnabled is bool) {
      _autoRenewEnabled = autoRenewEnabled;
      changed = true;
    }
    if (!mounted) {
      if (changed) {
        await _saveLocalState();
      }
      return;
    }
    if (changed) {
      setState(() {});
      await _saveLocalState();
    }
  }

  Future<bool> _purchaseTabOnServer(int tabIndex) async {
    final loc = AppLocalizations.of(context)!;
    final payload = await _postWithAuth('/tabs/purchase', {
      'tabIndex': tabIndex,
    });
    if (payload == null) {
      _showTokenMessage('Purchase failed.');
      await _refreshTokenStateFromServer();
      return false;
    }
    if (payload['ok'] != true) {
      final error = payload['error']?.toString() ?? '';
      if (error == 'insufficient_tokens') {
        _showTokenMessage(loc.insufficientTokensBody);
      } else {
        _showTokenMessage('Purchase failed.');
      }
      await _refreshTokenStateFromServer();
      return false;
    }
    await _applyServerTokenUpdate(payload);
    final expiry = _tabExpiry[tabIndex];
    if (payload['tabExpiry'] == null ||
        expiry == null ||
        !expiry.isAfter(_serverNow())) {
      await _refreshTokenStateFromServer();
    }
    return true;
  }

  Future<void> _applyAutoRenewOnServer() async {
    if (!_autoRenewEnabled) return;
    if (_user == null) return;
    final loc = AppLocalizations.of(context)!;
    final payload = await _postWithAuth('/tabs/auto-renew', {});
    if (payload == null || payload['ok'] != true) {
      await _refreshTokenStateFromServer();
      return;
    }
    final renewedTabs =
        int.tryParse(payload['renewedTabs']?.toString() ?? '') ?? 0;
    final renewedTabIndexes =
        (payload['renewedTabIndexes'] as List?)
            ?.map((e) => int.tryParse(e.toString()) ?? -1)
            .where((value) => value >= 2 && value < _tabs.length)
            .toList() ??
        [];
    final autoRenewDisabled = payload['autoRenewDisabled'] == true;
    if (autoRenewDisabled && mounted) {
      setState(() {
        _autoRenewEnabled = false;
      });
      await _saveLocalState();
      await NotificationService.showLocal(
        title: loc.autoRenewFailedTitle,
        body: loc.autoRenewFailedBody,
        severity: 4,
        payload: jsonEncode({'type': 'auto_renew_failed'}),
      );
    }
    await _applyServerTokenUpdate(payload);
    if (payload['tabExpiry'] == null) {
      await _refreshTokenStateFromServer();
    }
    if (renewedTabIndexes.isNotEmpty) {
      final tabs = renewedTabIndexes
          .map((index) => loc.tabLabelWithIndex(_tabs[index]))
          .join(', ');
      await NotificationService.showLocal(
        title: loc.autoRenewSuccessTitle,
        body: loc.autoRenewSuccessTabsBody(tabs),
        severity: 2,
        payload: jsonEncode({'type': 'auto_renew_success'}),
      );
    } else if (renewedTabs > 0) {
      await NotificationService.showLocal(
        title: loc.autoRenewSuccessTitle,
        body: loc.autoRenewSuccessBody(renewedTabs),
        severity: 2,
        payload: jsonEncode({'type': 'auto_renew_success'}),
      );
    }
  }

  String _formatRemaining(DateTime expiry) {
    final diff = expiry.difference(_serverNow());
    if (diff.isNegative) return '0d 0h';
    final totalMinutes = diff.inMinutes;
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;
    if (days == 0) {
      return '${hours}h ${minutes}m';
    }
    return '${days}d ${hours}h';
  }

  Future<void> _updateCanonicalKeyword(int index, String canonical) async {
    if (canonical.isEmpty) return;
    if (_canonicalKeywords[index] == canonical) return;
    setState(() {
      _canonicalKeywords[index] = canonical;
    });
    await _saveLocalState();
    await _syncTopicSubscriptions();
  }

  void _handleItemsLoaded(int tabIndex, List<NewsItem> items) {
    if (_refreshInProgress && tabIndex == _currentIndex) {
      setState(() {
        _refreshInProgress = false;
      });
    }
    final hadProcessing = _processingTabs.isNotEmpty;
    if (items.isEmpty) {
      _processingTabs.remove(tabIndex);
      if (hadProcessing && _processingTabs.isEmpty) {
        _processingPollTimer?.cancel();
        _processingPollRemaining = 0;
      }
      return;
    }
    final hasProcessing = items.any((item) => item.processing);
    if (hasProcessing) {
      _processingTabs.add(tabIndex);
    } else {
      _processingTabs.remove(tabIndex);
    }
    if (!hadProcessing && _processingTabs.isNotEmpty) {
      _scheduleProcessingPolling();
    } else if (hadProcessing && _processingTabs.isEmpty) {
      _processingPollTimer?.cancel();
      _processingPollRemaining = 0;
    }
  }

  void _recordNotification(NotificationEntry entry, String key) {
    _notifiedUrls.add(key);
    _notificationHistory
      ..removeWhere(
        (item) => item.timestamp.isBefore(
          DateTime.now().subtract(_notificationRetention),
        ),
      )
      ..insert(0, entry);
    _hasUnreadNotifications = true;
    if (_notificationHistory.length > 200) {
      _notificationHistory = _notificationHistory.take(200).toList();
    }
    if (mounted) {
      setState(() {});
    }
    _saveLocalState();
  }

  Future<void> _clearNotifications() async {
    _notificationHistory = [];
    _notifiedUrls.clear();
    _hasUnreadNotifications = false;
    await _localNotificationsPlugin.cancelAll();
    await _saveLocalState();
  }

  Widget _buildPanelContainer(Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(isDark ? 0.94 : 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildLockedTab(AppLocalizations loc, int tabIndex) {
    final theme = Theme.of(context);
    return Center(
      key: ValueKey('locked-$tabIndex'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              loc.tabLockedLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.purchaseTabBody(_tabMonthlyCost),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _handleTabTap(tabIndex),
              child: Text(loc.purchaseTabTitle(_tabs[tabIndex])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountPanel(AppLocalizations loc) {
    return _buildPanelContainer(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  backgroundImage: _user?.photoURL != null
                      ? NetworkImage(_user!.photoURL!)
                      : null,
                  child: _user?.photoURL == null
                      ? Icon(
                          Icons.person,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user == null
                            ? loc.signInWithGoogle
                            : (_user?.displayName ?? loc.googleAccount),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user == null
                            ? loc.tapToConnectAccount
                            : (_user?.email ?? loc.notSignedIn),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _closePanel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Text(
                    loc.googleAccount,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _user?.email ?? loc.notSignedIn,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _user == null ? loc.connectSync : loc.connectSync,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTokenStoreSection(loc),
                  if (kDebugMode) ...[
                    const SizedBox(height: 18),
                    Text(
                      'DEBUG',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () async {
                          _closePanel();
                          await Future.delayed(
                            const Duration(milliseconds: 250),
                          );
                          if (!mounted) return;
                          await _debugShowReviewPrompt();
                        },
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('Review prompt (debug)'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceVariant,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _debugResetReviewPromptState,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset review state (debug)'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _user == null ? _signInWithGoogle : _signOut,
                      icon: Icon(_user == null ? Icons.login : Icons.logout),
                      label: Text(
                        _user == null ? loc.continueWithGoogle : loc.signOut,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenStoreSection(AppLocalizations loc) {
    if (!_iapSupportedPlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.tokensStore,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Store unavailable on this platform.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          loc.tokensStore,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          loc.tokenStoreSubscriptionNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_iapLoading)
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading store...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (!_iapAvailable)
          Text(
            'Store unavailable.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else if (_iapError.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  _iapError,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(onPressed: _retryIapProducts, child: Text(loc.retry)),
            ],
          )
        else if (_iapProducts.isEmpty)
          Text(
            'No products available.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _iapProducts.map((product) {
              final tokens = _iapProductTokens[product.id];
              if (tokens == null) return const SizedBox.shrink();
              return _TokenPackTile(
                tokens: tokens,
                product: product,
                onPressed: _iapPurchaseInFlight
                    ? null
                    : () => _buyProduct(product),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTokenPanel(AppLocalizations loc) {
    final visibleCount = _tokenLedger.length < _tokenHistoryPage * 10
        ? _tokenLedger.length
        : _tokenHistoryPage * 10;
    final visibleLedger = _tokenLedger.take(visibleCount).toList();
    return _buildPanelContainer(
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    loc.tokensBalanceLabel(_tokenBalance),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _closePanel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.maxScrollExtent <= 0) {
                  return false;
                }
                if (notification is! ScrollUpdateNotification &&
                    notification is! ScrollEndNotification) {
                  return false;
                }
                if (notification.metrics.pixels <
                    notification.metrics.maxScrollExtent - 80) {
                  return false;
                }
                if (_tokenHistoryLoadingMore) return false;
                if (visibleCount >= _tokenLedger.length) return false;
                setState(() {
                  _tokenHistoryPage += 1;
                  _tokenHistoryLoadingMore = true;
                });
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (!mounted) return;
                  setState(() {
                    _tokenHistoryLoadingMore = false;
                  });
                });
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Text(
                    loc.tabUsageTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_tabs.length, (index) {
                    if (index <= 1) return const SizedBox.shrink();
                    final expiry = _tabExpiry[index];
                    final unlocked = _isTabUnlocked(index);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(loc.tabLabelWithIndex(_tabs[index])),
                      subtitle: Text(
                        unlocked && expiry != null
                            ? loc.tabRemainingLabel(_formatRemaining(expiry))
                            : loc.tabLockedLabel,
                      ),
                      trailing: unlocked
                          ? Icon(
                              Icons.lock_open,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : IconButton(
                              icon: Icon(
                                Icons.lock_outline,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => _promptTabSubscription(index),
                              tooltip: loc.subscribeTabPromptTitle,
                            ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    loc.tokenHistoryTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...visibleLedger.map((entry) {
                    final amountPrefix = entry.amount >= 0 ? '+' : '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_ledgerTitle(entry, loc)),
                      subtitle: Text(
                        entry.timestamp.toLocal().toString().split('.').first,
                      ),
                      trailing: Text(
                        '$amountPrefix${entry.amount}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: entry.amount >= 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }),
                  if (_tokenHistoryLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ledgerTitle(TokenLedgerEntry entry, AppLocalizations loc) {
    String? tabLabel;
    final match = RegExp(r'^tab:(\d+)$').firstMatch(entry.description.trim());
    if (match != null) {
      final index = int.tryParse(match.group(1) ?? '');
      if (index != null && index >= 0 && index < _tabs.length) {
        tabLabel = loc.tabLabelWithIndex(_tabs[index]);
      }
    }
    switch (entry.type) {
      case 'purchase':
        return tabLabel == null
            ? loc.ledgerPurchase
            : '${loc.ledgerPurchase} · $tabLabel';
      case 'spend':
        return tabLabel == null
            ? loc.ledgerSpend
            : loc.ledgerSpendWithTab(tabLabel);
      case 'auto_renew':
        return tabLabel == null
            ? loc.ledgerAutoRenew
            : loc.ledgerAutoRenewWithTab(tabLabel);
      default:
        return entry.description;
    }
  }

  Future<void> _ensureFcmReady({bool forceTokenRefresh = false}) async {
    try {
      // Auto-init should remain enabled so FCM keeps the registration up to date.
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (_) {}

    try {
      // On Android 13+ and iOS, permission can be toggled in OS settings.
      // requestPermission() is safe to call; it won't always show a prompt.
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (forceTokenRefresh) {
        debugPrint('FCM ensure ready: token=${_maskToken(token)}');
      }
      await _syncGuestTracking();
    } catch (e) {
      debugPrint('FCM token init failed: $e');
    }
  }

  Future<void> _syncGuestTracking({bool force = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final lastSync = prefs.getInt(_guestSyncAtKey) ?? 0;
      const syncIntervalMs = 6 * 60 * 60 * 1000;
      if (!force && nowMs - lastSync < syncIntervalMs) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      final payload = {'token': token, 'language': _language};
      if (_user != null) {
        await _postWithAuth('/users/guest', payload);
      } else {
        await _postJson('/users/guest', payload, withAuth: false);
      }
      await prefs.setInt(_guestSyncAtKey, nowMs);
    } catch (_) {}
  }

  Future<void> _fcmSubscribe(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('subscribeToTopic($topic) failed: $e');
    }
  }

  Future<void> _fcmUnsubscribe(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('unsubscribeFromTopic($topic) failed: $e');
    }
  }

  Future<void> _syncTopicSubscriptions() async {
    await _ensureFcmReady();
    await _refreshCanonicalKeywords();
    final prefs = await SharedPreferences.getInstance();
    final previousTopics =
        prefs.getStringList('fcmTopics')?.toSet() ?? <String>{};
    final desiredTopics = <String>{};
    final langKeys = _notificationLangs.isNotEmpty
        ? _notificationLangs
        : {_topicLangCode(_language)};
    final breakingRegionKey = _topicRegionCode(_regionForTab(0));
    try {
      final token = await FirebaseMessaging.instance.getToken();
      NotificationSettings? settings;
      try {
        settings = await FirebaseMessaging.instance.getNotificationSettings();
      } catch (_) {}
      debugPrint(
        'FCM sync start: token=${_maskToken(token)} perm=${settings?.authorizationStatus} '
        'break=${_notificationPrefs.breakingEnabled} sev4=${_notificationPrefs.keywordSeverity4} '
        'sev5=${_notificationPrefs.keywordSeverity5} region=$breakingRegionKey '
        'langs=${langKeys.join(",")}',
      );
    } catch (_) {}

    if (_notificationPrefs.breakingEnabled) {
      for (final langKey in langKeys) {
        final criticalTopic = 'critical_${langKey}_$breakingRegionKey';
        if (!desiredTopics.contains(criticalTopic)) {
          await _fcmSubscribe(criticalTopic);
          desiredTopics.add(criticalTopic);
        }
      }
    } else {
      final previousCritical = previousTopics.where(
        (topic) => topic == 'critical' || topic.startsWith('critical_'),
      );
      for (final topic in previousCritical) {
        await _fcmUnsubscribe(topic);
      }
    }

    for (var index = 1; index < _keywords.length; index++) {
      final rawKeyword = _keywords[index].trim();
      if (rawKeyword.isEmpty) continue;
      final canonical = _canonicalKeywords[index];
      final candidates = <String>{};
      if (canonical != null && canonical.isNotEmpty) {
        candidates.add(canonical);
      }
      candidates.add(rawKeyword);
      final regionKey = _topicRegionCode(_regionForTab(index));
      for (final candidate in candidates) {
        final hash = _topicHash(candidate);
        for (final langKey in langKeys) {
          final topic4 = 'kw4_${langKey}_${regionKey}_$hash';
          final topic5 = 'kw5_${langKey}_${regionKey}_$hash';
          if (_notificationPrefs.keywordSeverity4) {
            if (!desiredTopics.contains(topic4)) {
              await _fcmSubscribe(topic4);
              desiredTopics.add(topic4);
            }
          } else {
            await _fcmUnsubscribe(topic4);
          }
          if (_notificationPrefs.keywordSeverity5) {
            if (!desiredTopics.contains(topic5)) {
              await _fcmSubscribe(topic5);
              desiredTopics.add(topic5);
            }
          } else {
            await _fcmUnsubscribe(topic5);
          }
        }
      }
    }

    for (final topic in previousTopics.difference(desiredTopics)) {
      await _fcmUnsubscribe(topic);
    }
    await prefs.setStringList('fcmTopics', desiredTopics.toList());
    try {
      final toRemove = previousTopics.difference(desiredTopics);
      final sample = desiredTopics.take(6).join(',');
      debugPrint(
        'FCM sync done: desired=${desiredTopics.length} remove=${toRemove.length} sample=$sample',
      );
    } catch (_) {}
  }

  Future<void> _unsubscribeKeywordTopics(
    String keyword,
    String region, {
    int? tabIndex,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final langKey = _topicLangCode(_language);
    final regionKey = _topicRegionCode(region);
    final candidates = <String>{};
    final canonical = tabIndex != null
        ? _canonicalKeywords[tabIndex]?.trim() ?? ''
        : '';
    if (canonical.isNotEmpty) {
      candidates.add(canonical);
    }
    candidates.add(trimmed);
    for (final candidate in candidates) {
      final hash = _topicHash(candidate);
      final topic4 = 'kw4_${langKey}_${regionKey}_$hash';
      final topic5 = 'kw5_${langKey}_${regionKey}_$hash';
      await _fcmUnsubscribe(topic4);
      await _fcmUnsubscribe(topic5);
    }
  }

  Future<String?> _resolveCanonicalKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/keyword/resolve'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'keyword': trimmed, 'lang': _language}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final canonical = decoded['canonical']?.toString() ?? '';
          return canonical.isNotEmpty ? canonical : null;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _refreshCanonicalKeywords() async {
    if (_canonicalSyncInFlight) return false;
    final pending = <int, String>{};
    for (var index = 1; index < _keywords.length; index++) {
      final keyword = _keywords[index].trim();
      if (keyword.isEmpty) continue;
      final existing = _canonicalKeywords[index];
      if (existing != null && existing.isNotEmpty) continue;
      pending[index] = keyword;
    }
    if (pending.isEmpty) return false;
    _canonicalSyncInFlight = true;
    final updates = <int, String>{};
    try {
      for (final entry in pending.entries) {
        final canonical = await _resolveCanonicalKeyword(entry.value);
        if (canonical != null && canonical.isNotEmpty) {
          updates[entry.key] = canonical;
        }
      }
    } finally {
      _canonicalSyncInFlight = false;
    }
    if (updates.isEmpty) return false;
    if (mounted) {
      setState(() {
        _canonicalKeywords.addAll(updates);
      });
    } else {
      _canonicalKeywords.addAll(updates);
    }
    await _saveLocalState();
    return true;
  }

  Future<void> _loadKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('tabKeywords');
    final storedRegions = prefs.getStringList('tabRegions');
    final tokenBalance = prefs.getInt('tokenBalance');
    final ledgerRaw = prefs.getString('tokenLedger');
    final expiryRaw = prefs.getString('tabExpiry');
    final notifRaw = prefs.getString('notificationPrefs');
    final canonicalRaw = prefs.getString('canonicalKeywords');
    final historyRaw = prefs.getString('notificationHistory');
    final notifiedRaw = prefs.getString('notifiedUrls');
    final unreadRaw = prefs.getBool('notificationsUnread');
    final autoRenewRaw = prefs.getBool('autoRenewEnabled');
    final savedRaw = prefs.getString('savedArticles');
    final blockedRaw = prefs.getString('blockedDomains');
    final reportedRaw = prefs.getString('reportedUrls');
    setState(() {
      final loadedKeywords = List<String>.filled(_tabs.length, '');
      if (stored != null && stored.isNotEmpty) {
        for (var i = 0; i < _tabs.length; i++) {
          if (i < stored.length) {
            loadedKeywords[i] = stored[i].toString().trim();
          }
        }
      }
      _keywords = loadedKeywords;
      final loadedRegions = List<String>.filled(_tabs.length, 'ALL');
      if (storedRegions != null && storedRegions.isNotEmpty) {
        for (var i = 0; i < _tabs.length; i++) {
          if (i < storedRegions.length) {
            final value = storedRegions[i].toString().trim();
            if (value.isNotEmpty) {
              loadedRegions[i] = value.toUpperCase();
            }
          }
        }
      }
      _tabRegions = loadedRegions;
      if (tokenBalance != null) {
        _tokenBalance = tokenBalance;
      }
      if (ledgerRaw != null && ledgerRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(ledgerRaw) as List<dynamic>;
          _tokenLedger = parsed
              .whereType<Map<String, dynamic>>()
              .map(TokenLedgerEntry.fromJson)
              .toList();
        } catch (_) {}
      }
      if (expiryRaw != null && expiryRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(expiryRaw) as Map<String, dynamic>;
          parsed.forEach((key, value) {
            final index = int.tryParse(key);
            final date = DateTime.tryParse(value.toString());
            if (index != null && date != null) {
              _tabExpiry[index] = date;
            }
          });
        } catch (_) {}
      }
      if (notifRaw != null && notifRaw.isNotEmpty) {
        try {
          _notificationPrefs = NotificationPreferences.fromJson(
            jsonDecode(notifRaw),
          );
        } catch (_) {}
      }
      if (autoRenewRaw != null) {
        _autoRenewEnabled = autoRenewRaw;
      }
      if (canonicalRaw != null && canonicalRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(canonicalRaw) as Map<String, dynamic>;
          parsed.forEach((key, value) {
            final index = int.tryParse(key);
            if (index != null && value != null) {
              _canonicalKeywords[index] = value.toString();
            }
          });
        } catch (_) {}
      }
      if (historyRaw != null && historyRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(historyRaw) as List<dynamic>;
          final loaded = parsed
              .whereType<Map<String, dynamic>>()
              .map(NotificationEntry.fromJson)
              .toList();
          _notificationHistory = _pruneNotificationEntries(loaded);
          if (_notificationHistory.length != loaded.length) {
            prefs.setString(
              'notificationHistory',
              jsonEncode(_notificationHistory.map((e) => e.toJson()).toList()),
            );
          }
        } catch (_) {}
      }
      if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(notifiedRaw) as List<dynamic>;
          _notifiedUrls
            ..clear()
            ..addAll(parsed.map((e) => e.toString()));
        } catch (_) {}
      }
      if (unreadRaw != null) {
        _hasUnreadNotifications = unreadRaw;
      }
      _tokenHistoryPage = 1;
      _tokenHistoryLoadingMore = false;
      if (savedRaw != null && savedRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(savedRaw) as List<dynamic>;
          _savedArticles = parsed
              .whereType<Map<String, dynamic>>()
              .map(SavedArticle.fromJson)
              .toList();
          _savedArticleKeys
            ..clear()
            ..addAll(_savedArticles.map((e) => _savedArticleId(e.item)));
        } catch (_) {}
      }
      if (blockedRaw != null && blockedRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(blockedRaw) as List<dynamic>;
          _blockedDomains
            ..clear()
            ..addAll(parsed.map((e) => e.toString()));
        } catch (_) {}
      }
      if (reportedRaw != null && reportedRaw.isNotEmpty) {
        try {
          final parsed = jsonDecode(reportedRaw) as List<dynamic>;
          _reportedUrls
            ..clear()
            ..addAll(parsed.map((e) => e.toString()));
        } catch (_) {}
      }
      _notificationLangs
        ..clear()
        ..add(_topicLangCode(_language));
      _loading = false;
    });
    await _refreshCanonicalKeywords();
    await _updateNotificationLangHistory();
    await _syncTopicSubscriptions();
    await _applyAutoRenewOnServer();
    await _pruneExpiredTabs(syncServer: false);
  }

  Future<void> _updateNotificationLangHistory() async {
    final langKey = _topicLangCode(_language);
    _notificationLangs
      ..clear()
      ..add(langKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _notificationLangHistoryKey,
      _notificationLangs.toList(),
    );
  }

  void _handleNotificationTick() {
    _reloadNotificationCacheFromPrefs();
  }

  Future<void> _reloadNotificationCacheFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final historyRaw = prefs.getString('notificationHistory');
    final notifiedRaw = prefs.getString('notifiedUrls');
    final unreadRaw = prefs.getBool('notificationsUnread');
    var loaded = <NotificationEntry>[];
    if (historyRaw != null && historyRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(historyRaw) as List<dynamic>;
        loaded = parsed
            .whereType<Map<String, dynamic>>()
            .map(NotificationEntry.fromJson)
            .toList();
      } catch (_) {}
    }
    final pruned = _pruneNotificationEntries(loaded);
    if (pruned.length != loaded.length) {
      prefs.setString(
        'notificationHistory',
        jsonEncode(pruned.map((e) => e.toJson()).toList()),
      );
    }
    final notified = <String>{};
    if (notifiedRaw != null && notifiedRaw.isNotEmpty) {
      try {
        final parsed = jsonDecode(notifiedRaw) as List<dynamic>;
        notified.addAll(parsed.map((e) => e.toString()));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _notificationHistory = pruned;
      _notifiedUrls
        ..clear()
        ..addAll(notified);
      if (unreadRaw != null) {
        _hasUnreadNotifications = unreadRaw;
      }
    });
  }

  Future<void> _saveKeywords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('tabKeywords', _keywords);
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) {
      await prefs.setBool(_pendingKeywordSyncKey(uid), true);
    }
    for (var i = 0; i < _keywords.length; i++) {
      if (_keywords[i].isEmpty) {
        _canonicalKeywords.remove(i);
      }
    }
    await _saveLocalState();
    final synced = await _saveUserStateToFirestore();
    if (synced && uid != null && uid.isNotEmpty) {
      await prefs.setBool(_pendingKeywordSyncKey(uid), false);
    }
    await _syncTopicSubscriptions();
  }

  Future<String?> _updateKeywordSubscription(
    String keyword, {
    required bool add,
    String? regionOverride,
    int? tabIndex,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return null;
    try {
      final feedLang =
          _regionNewsLang[(regionOverride ?? _regionForTab(_currentIndex))
              .toUpperCase()] ??
          _language;
      final region = regionOverride ?? _regionForTab(_currentIndex);
      final response = await http.post(
        Uri.parse('$apiBaseUrl/keyword/subscription'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'keyword': trimmed,
          'lang': _language,
          'region': region,
          'feedLang': feedLang,
          'action': add ? 'add' : 'remove',
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final canonical = decoded['canonical']?.toString() ?? '';
            if (canonical.isNotEmpty && tabIndex != null) {
              final safeIndex = tabIndex.clamp(0, _tabs.length - 1);
              if (_canonicalKeywords[safeIndex] != canonical) {
                if (mounted) {
                  setState(() {
                    _canonicalKeywords[safeIndex] = canonical;
                  });
                } else {
                  _canonicalKeywords[safeIndex] = canonical;
                }
              }
            }
            return canonical.isNotEmpty ? canonical : null;
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _buildPrefetchTask({
    required String keyword,
    required String region,
    required String language,
  }) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return null;
    final regionCode = region.toUpperCase();
    final feedLang = _regionNewsLang[regionCode] ?? language;
    return {
      'keyword': trimmed,
      'region': regionCode,
      'lang': language,
      'feedLang': feedLang,
      'limit': 20,
    };
  }

  Future<void> _requestCachePrefetch(
    List<Map<String, dynamic>> tasks, {
    required String reason,
  }) async {
    if (tasks.isEmpty) return;
    try {
      final payload = await _postJson('/cache/prefetch', {
        'reason': reason,
        'tasks': tasks,
      }, withAuth: _user != null);
      final status =
          int.tryParse(payload?['statusCode']?.toString() ?? '') ?? 0;
      if (status >= 200 && status < 300) {
        final total = int.tryParse(payload?['total']?.toString() ?? '') ?? 0;
        final success =
            int.tryParse(payload?['success']?.toString() ?? '') ?? 0;
        if (total > 0 && success > 0) {
          _schedulePrefetchPolling();
        }
      }
    } catch (_) {}
  }

  void _schedulePrefetchPolling() {
    _prefetchPollTimer?.cancel();
    _prefetchPollRemaining = _prefetchPollAttempts;
    _prefetchPollTimer = Timer.periodic(_prefetchPollInterval, (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _prefetchPollRemaining -= 1;
      _triggerAutoRefresh();
      if (_prefetchPollRemaining <= 0) {
        timer.cancel();
      }
    });
  }

  void _scheduleProcessingPolling() {
    _processingPollTimer?.cancel();
    _processingPollRemaining = _processingPollAttempts;
    _processingPollTimer = Timer.periodic(_processingPollInterval, (
      Timer timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_processingTabs.isEmpty) {
        timer.cancel();
        return;
      }
      _processingPollRemaining -= 1;
      _triggerAutoRefresh();
      if (_processingPollRemaining <= 0) {
        timer.cancel();
      }
    });
  }

  Future<void> _prefetchCachesForLanguage(String language) async {
    final tasks = <Map<String, dynamic>>[];
    final breakingRegion = _regionForTab(0);
    final breakingKeyword = _breakingKeywordForRegion(breakingRegion, language);
    final breakingTask = _buildPrefetchTask(
      keyword: breakingKeyword,
      region: breakingRegion,
      language: language,
    );
    if (breakingTask != null) {
      tasks.add(breakingTask);
    }
    for (var index = 1; index < _keywords.length; index++) {
      final keyword = _keywords[index].trim();
      if (keyword.isEmpty) continue;
      final region = _regionForTab(index);
      final task = _buildPrefetchTask(
        keyword: keyword,
        region: region,
        language: language,
      );
      if (task != null) {
        tasks.add(task);
      }
    }
    await _requestCachePrefetch(tasks, reason: 'language_change');
  }

  Future<void> _prefetchBreakingCache(String region, String language) async {
    final keyword = _breakingKeywordForRegion(region, language);
    final task = _buildPrefetchTask(
      keyword: keyword,
      region: region,
      language: language,
    );
    if (task == null) return;
    await _requestCachePrefetch([task], reason: 'breaking_region_change');
  }

  Future<Map<String, dynamic>?> _activateBreakingTabOnDemand({
    bool force = false,
  }) async {
    final region = _regionForTab(0).toUpperCase();
    final lang = _language;
    final feedLang = _regionNewsLang[region] ?? lang;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final key = '$region::$feedLang::$lang';
    if (!force &&
        key == _breakingActivateLastKey &&
        nowMs - _breakingActivateLastAtMs <
            _breakingActivateCooldown.inMilliseconds) {
      return null;
    }
    _breakingActivateLastKey = key;
    _breakingActivateLastAtMs = nowMs;
    final payload = await _postJson('/breaking/activate', {
      'region': region,
      'lang': lang,
      'feedLang': feedLang,
      'limit': 20,
    }, withAuth: false);
    final status = int.tryParse(payload?['statusCode']?.toString() ?? '') ?? 0;
    if (status < 200 || status >= 300) return null;
    return payload;
  }

  Future<Map<String, dynamic>> _setKeywordSubscription(
    String previousKeyword,
    String nextKeyword, {
    String? regionOverride,
    int? tabIndex,
  }) async {
    final prev = previousKeyword.trim();
    final next = nextKeyword.trim();
    final result = <String, dynamic>{'ok': false, 'canonical': ''};
    if (prev.isEmpty && next.isEmpty) return result;
    final safeIndex = tabIndex ?? _currentIndex;
    final region = regionOverride ?? _regionForTab(safeIndex);
    final feedLang = _regionNewsLang[region.toUpperCase()] ?? _language;
    final payload = await _postWithAuth('/keyword/set', {
      'previousKeyword': prev,
      'keyword': next,
      'lang': _language,
      'region': region,
      'feedLang': feedLang,
      'tabIndex': safeIndex,
    });
    final status = int.tryParse(payload?['statusCode']?.toString() ?? '') ?? 0;
    if (status >= 200 && status < 300) {
      final canonical = payload?['canonical']?.toString() ?? '';
      result['ok'] = true;
      result['canonical'] = canonical;
      if (tabIndex != null) {
        if (canonical.isNotEmpty) {
          if (_canonicalKeywords[tabIndex] != canonical) {
            if (mounted) {
              setState(() {
                _canonicalKeywords[tabIndex] = canonical;
              });
            } else {
              _canonicalKeywords[tabIndex] = canonical;
            }
          }
        } else {
          _canonicalKeywords.remove(tabIndex);
        }
      }
    }
    return result;
  }

  Future<void> _setKeywordForTab() async {
    if (_currentIndex == 0) {
      return;
    }
    final keyword = _keywordController.text.trim();
    final previous = _keywords[_currentIndex].trim();
    if (keyword.isEmpty) {
      _keywordController.clear();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (previous.isNotEmpty) {
        await _clearKeywordForTab();
      }
      return;
    }
    setState(() {
      _keywords[_currentIndex] = keyword;
      if (previous != keyword) {
        _canonicalKeywords.remove(_currentIndex);
      }
    });
    // Persist local keyword change first so app restarts don't lose recent edits.
    await _saveLocalState();
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKeywordSyncKey(uid), true);
    }
    _keywordController.clear();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (previous.isNotEmpty && previous != keyword) {
      final result = await _setKeywordSubscription(
        previous,
        keyword,
        tabIndex: _currentIndex,
      );
      if (result['ok'] != true) {
        await _updateKeywordSubscription(previous, add: false);
        await _updateKeywordSubscription(
          keyword,
          add: true,
          tabIndex: _currentIndex,
        );
      }
      _triggerAutoRefresh();
      await _saveKeywords();
      return;
    }
    final result = await _setKeywordSubscription(
      '',
      keyword,
      tabIndex: _currentIndex,
    );
    if (result['ok'] != true) {
      await _updateKeywordSubscription(
        keyword,
        add: true,
        tabIndex: _currentIndex,
      );
    }
    _triggerAutoRefresh();
    await _saveKeywords();
  }

  Future<void> _clearKeywordForTab() async {
    if (_currentIndex == 0) {
      return;
    }
    final previous = _keywords[_currentIndex].trim();
    setState(() {
      _keywords[_currentIndex] = '';
    });
    _canonicalKeywords.remove(_currentIndex);
    // Persist local clear first so app restarts keep the latest tab state.
    await _saveLocalState();
    final uid = _user?.uid;
    if (uid != null && uid.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pendingKeywordSyncKey(uid), true);
    }
    if (previous.isNotEmpty) {
      final result = await _setKeywordSubscription(
        previous,
        '',
        tabIndex: _currentIndex,
      );
      if (result['ok'] != true) {
        await _updateKeywordSubscription(previous, add: false);
      }
    }
    await _saveKeywords();
  }

  bool _isArticleSaved(NewsItem item) {
    return _savedArticleKeys.contains(_savedArticleId(item));
  }

  Future<void> _toggleSaveArticle(NewsItem item) async {
    final key = _savedArticleId(item);
    final wasSaved = _savedArticleKeys.contains(key);
    setState(() {
      if (wasSaved) {
        _savedArticleKeys.remove(key);
        _savedArticles.removeWhere(
          (entry) => _savedArticleId(entry.item) == key,
        );
      } else {
        _savedArticleKeys.add(key);
        _savedArticles.insert(
          0,
          SavedArticle(item: item, savedAt: DateTime.now()),
        );
      }
    });
    await _saveLocalState();
    if (_user == null) return;
    final ok = await _setSavedArticleOnServer(item, save: !wasSaved);
    if (!ok) {
      await _loadSavedArticlesFromServer();
    }
  }

  Future<bool> _setSavedArticleOnServer(
    NewsItem item, {
    required bool save,
  }) async {
    final keyword = _currentIndex == 0
        ? _breakingKeywordForRegion(_currentRegion, _language)
        : _keywords[_currentIndex].trim();
    final payload = await _postWithAuth('/saved_articles/set', {
      'action': save ? 'save' : 'remove',
      'articleId': _savedArticleId(item),
      'keywordKey': keyword,
      'item': item.toJson(),
    });
    final status = int.tryParse(payload?['statusCode']?.toString() ?? '') ?? 0;
    return status >= 200 && status < 300;
  }

  Future<void> _reportArticle(NewsItem item) async {
    final loc = AppLocalizations.of(context)!;
    final url = item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url;
    if (url.isEmpty) return;
    if (_reportedUrls.add(url)) {
      await _saveLocalState();
      _sendSourceFeedback('report', item);
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.reportedArticleToast)));
    }
  }

  Future<void> _blockSource(NewsItem item) async {
    final loc = AppLocalizations.of(context)!;
    final url = item.sourceUrl.isNotEmpty
        ? item.sourceUrl
        : (item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url);
    final domain = _domainFromUrl(url);
    final sourceName = item.source.trim();
    final useSourceName =
        domain == null || domain.isEmpty || _isGoogleDomain(domain);
    final blockKey = useSourceName && sourceName.isNotEmpty
        ? 'source:${sourceName.toLowerCase()}'
        : (domain ?? '');
    final displayLabel = useSourceName && sourceName.isNotEmpty
        ? sourceName
        : domain ?? '';
    if (blockKey.isEmpty) return;
    final shouldBlock =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(loc.blockSource),
            content: Text(displayLabel),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(loc.confirm),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldBlock) return;
    setState(() {
      _blockedDomains.add(blockKey);
    });
    await _saveLocalState();
    _sendSourceFeedback('block', item);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.blockedSourceToast)));
    }
  }

  Future<void> _unblockSource(String domain) async {
    final loc = AppLocalizations.of(context)!;
    final removed = _blockedDomains.remove(domain);
    if (removed) {
      if (mounted) {
        setState(() {});
      }
      await _saveLocalState();
      await _saveUserStateToFirestore();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.unblockedSourceToast)));
      }
    }
  }

  Future<void> _sendSourceFeedback(String action, NewsItem item) async {
    try {
      final uri = Uri.parse('$apiBaseUrl/source/$action');
      final payload = {
        'sourceName': item.source,
        'sourceUrl': item.sourceUrl,
        'resolvedUrl': item.resolvedUrl,
        'url': item.url,
      };
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {}
  }

  Future<void> _showSavedArticles() async {
    if (_user != null) {
      await _loadSavedArticlesFromServer();
    }
    final loc = AppLocalizations.of(context)!;
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SavedArticlesPage(
          title: loc.savedArticlesTitle,
          articles: _savedArticles,
          isSaved: _isArticleSaved,
          onToggleSave: _toggleSaveArticle,
          language: _language,
        ),
      ),
    );
  }

  void _showKeywordDialog() {
    HapticFeedback.selectionClick();
    final loc = AppLocalizations.of(context)!;
    if (_currentIndex == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.breakingNewsFixed)));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  loc.setKeywordForTab(_tabTitle(loc, _currentIndex)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260),
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(hintText: loc.keywordHint),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _setKeywordForTab(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.cancel),
            ),
            FilledButton(onPressed: _setKeywordForTab, child: Text(loc.save)),
          ],
        );
      },
    );
  }

  void _showManageDialog() {
    HapticFeedback.selectionClick();
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ListView(
          children: List.generate(
            _tabs.length,
            (index) => ListTile(
              title: Text(_tabTitle(loc, index)),
              subtitle: Text(
                index == 0
                    ? loc.fixedLabel(
                        _breakingKeywordForRegion(
                          _regionForTab(index),
                          _language,
                        ),
                      )
                    : (_keywords[index].isEmpty
                          ? loc.noKeyword
                          : _keywords[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  String _tabTitle(AppLocalizations loc, int index) {
    if (index == 0) return loc.breakingTab;
    return _tabs[index];
  }

  String _tabTooltip(AppLocalizations loc, int index) {
    if (index == 0) {
      return _breakingKeywordForRegion(_regionForTab(index), _language);
    }
    const emptyFallback = '';
    final keyword = index >= 0 && index < _keywords.length
        ? _keywords[index].trim()
        : emptyFallback;
    return keyword.isEmpty ? loc.noKeyword : keyword;
  }

  String _tabLabel(AppLocalizations loc, int index) {
    if (index == 0) {
      if (_language.toLowerCase().startsWith('en')) {
        return 'Break';
      }
      return loc.breakingTabShort;
    }
    return _tabs[index];
  }

  String _languageLabel(AppLocalizations loc, String code) {
    switch (code) {
      case 'en-GB':
        return loc.languageEnglishUk;
      case 'ko':
        return loc.languageKorean;
      case 'ja':
        return loc.languageJapanese;
      case 'fr':
        return loc.languageFrench;
      case 'es':
        return loc.languageSpanish;
      case 'ru':
        return loc.languageRussian;
      case 'ar':
        return loc.languageArabic;
      case 'en':
      default:
        return loc.languageEnglish;
    }
  }

  String _regionLabel(AppLocalizations loc, String region) {
    switch (region) {
      case 'ALL':
        return loc.regionAllCountries;
      case 'US':
        return loc.regionUnitedStates;
      case 'UK':
        return loc.regionUnitedKingdom;
      case 'KR':
        return loc.regionKorea;
      case 'JP':
        return loc.regionJapan;
      case 'FR':
        return loc.regionFrance;
      case 'ES':
        return loc.regionSpain;
      case 'RU':
        return loc.regionRussia;
      case 'AE':
        return loc.regionUnitedArabEmirates;
      default:
        return _regionNamesEnglish[region] ?? region;
    }
  }

  Future<void> _setTabRegion(int index, String region) async {
    final safeIndex = index.clamp(0, _tabs.length - 1);
    final previousRegion = _regionForTab(safeIndex);
    final nextRegion = region.toUpperCase();
    final keyword = safeIndex == 0 ? '' : _keywords[safeIndex].trim();
    setState(() {
      _tabRegions[safeIndex] = nextRegion;
    });
    if (_user != null) {
      await _setPendingUserStateSync(true);
    }
    await _saveLocalState();
    if (keyword.isNotEmpty && previousRegion != nextRegion) {
      await _updateKeywordSubscription(
        keyword,
        add: false,
        regionOverride: previousRegion,
        tabIndex: safeIndex,
      );
      await _updateKeywordSubscription(
        keyword,
        add: true,
        regionOverride: nextRegion,
        tabIndex: safeIndex,
      );
      await _unsubscribeKeywordTopics(
        keyword,
        previousRegion,
        tabIndex: safeIndex,
      );
    }
    await _saveUserStateToFirestore();
    await _syncTopicSubscriptions();
    if (safeIndex == 0 && previousRegion != nextRegion) {
      final activateResult = await _activateBreakingTabOnDemand(force: true);
      final hasCache = activateResult?['hasCache'] == true;
      if (!hasCache) {
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          if (_currentIndex != 0) return;
          if (_regionForTab(0) != nextRegion) return;
          _triggerAutoRefresh();
        });
      }
    }
  }

  void _showRegionDialog() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        final currentRegion = _currentRegion;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                loc.regionSettingsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ..._regions.map(
              (region) => ListTile(
                title: Text(_regionLabel(loc, region)),
                trailing: region == currentRegion
                    ? const Icon(Icons.check, color: Color(0xFF0B3D91))
                    : null,
                onTap: () {
                  _setTabRegion(_currentIndex, region);
                  Navigator.of(context).pop();
                },
              ),
            ),
            ListTile(
              title: Text(loc.regionAllCountries),
              trailing: currentRegion == 'ALL'
                  ? const Icon(Icons.check, color: Color(0xFF0B3D91))
                  : null,
              onTap: () {
                _setTabRegion(_currentIndex, 'ALL');
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                loc.languageSettingsTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            ..._languageCodes.map(
              (code) => ListTile(
                title: Text(_languageLabel(loc, code)),
                trailing: code == _language
                    ? const Icon(Icons.check, color: Color(0xFF0B3D91))
                    : null,
                onTap: () {
                  setState(() {
                    _language = code;
                  });
                  widget.onLanguageChanged(code);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showNotificationSettings() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  loc.notificationSettingsTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.notificationBreakingTitle),
                  subtitle: Text(loc.notificationBreakingSubtitle),
                  value: _notificationPrefs.breakingEnabled,
                  onChanged: (value) async {
                    setState(() {
                      _notificationPrefs.breakingEnabled = value;
                    });
                    setModalState(() {});
                    await _ensureFcmReady(forceTokenRefresh: true);
                    await _saveLocalState();
                    await _saveUserStateToFirestore();
                    await _syncTopicSubscriptions();
                  },
                ),
                const Divider(height: 32),
                Text(
                  loc.notificationKeywordTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${loc.notificationSeverity4} (${loc.notificationSeverity4Label})',
                  ),
                  value: _notificationPrefs.keywordSeverity4,
                  onChanged: (value) async {
                    setState(() {
                      _notificationPrefs.keywordSeverity4 = value;
                    });
                    setModalState(() {});
                    await _ensureFcmReady(forceTokenRefresh: true);
                    await _saveLocalState();
                    await _saveUserStateToFirestore();
                    await _syncTopicSubscriptions();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${loc.notificationSeverity5} (${loc.notificationSeverity5Label})',
                  ),
                  value: _notificationPrefs.keywordSeverity5,
                  onChanged: (value) async {
                    setState(() {
                      _notificationPrefs.keywordSeverity5 = value;
                    });
                    setModalState(() {});
                    await _ensureFcmReady(forceTokenRefresh: true);
                    await _saveLocalState();
                    await _saveUserStateToFirestore();
                    await _syncTopicSubscriptions();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showNotificationHistory() {
    final loc = AppLocalizations.of(context)!;
    setState(() {
      _hasUnreadNotifications = false;
    });
    _saveLocalState();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NotificationHistoryPage(
          title: loc.notificationsTitle,
          entries: _notificationHistory,
          onClearAll: () async {
            await _clearNotifications();
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  void _showSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          onToggleTheme: widget.onToggleTheme,
          onShowLanguage: _showLanguageDialog,
          onShowNotifications: _showNotificationSettings,
          autoRenewEnabled: _autoRenewEnabled,
          blockedDomains: _blockedDomains,
          onUnblockSource: _unblockSource,
          onAutoRenewChanged: (value) async {
            final previous = _autoRenewEnabled;
            setState(() {
              _autoRenewEnabled = value;
            });
            if (value) {
              final loc = AppLocalizations.of(context)!;
              final confirm =
                  await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(loc.autoRenewConfirmTitle),
                      content: Text(loc.autoRenewConfirmBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(loc.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(loc.autoRenewConfirmEnable),
                        ),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirm) {
                if (mounted) {
                  setState(() {
                    _autoRenewEnabled = previous;
                  });
                }
                await _saveLocalState();
                await _saveUserStateToFirestore();
                return _autoRenewEnabled;
              }
            }
            await _saveLocalState();
            await _saveUserStateToFirestore();
            if (value) {
              await _applyAutoRenewOnServer();
            }
            return _autoRenewEnabled;
          },
        ),
      ),
    );
  }

  Future<bool> _confirmExit() async {
    final loc = AppLocalizations.of(context)!;
    final shouldExit =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text(loc.exitConfirmTitle),
              content: Text(loc.exitConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(loc.exitConfirmNo),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(loc.exitConfirmYes),
                ),
              ],
            ),
          ),
        ) ??
        false;
    return shouldExit;
  }

  Widget _buildTabIcon(int index) {
    if (index == 0) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFE11D48,
              ).withOpacity(0.6 + 0.4 * _pulseAnimation.value),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFE11D48,
                  ).withOpacity(0.35 + 0.35 * _pulseAnimation.value),
                  blurRadius: 6 + 6 * _pulseAnimation.value,
                ),
              ],
            ),
          );
        },
      );
    }

    if (index >= 2 && !_isTabUnlocked(index)) {
      return Icon(
        Icons.lock_outline,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
    }

    final hasKeyword = _keywords[index].isNotEmpty;
    if (!hasKeyword) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFCBD5E1),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(
              0xFF22C55E,
            ).withOpacity(0.6 + 0.4 * _pulseAnimation.value),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF22C55E,
                ).withOpacity(0.35 + 0.35 * _pulseAnimation.value),
                blurRadius: 6 + 6 * _pulseAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatRegionTime(String region) {
    final offset = _regionOffsets[region.toUpperCase()] ?? 0;
    final now = DateTime.now().toUtc().add(Duration(hours: offset));
    final hours = now.hour.toString().padLeft(2, '0');
    final minutes = now.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  void _closePanel() {
    if (!_showPanel) return;
    _sheetController.reverse().whenComplete(() {
      if (mounted) {
        setState(() {
          _showPanel = false;
        });
      }
    });
  }

  void _openPanel(_PanelType type) {
    if (type == _PanelType.token) {
      _tokenHistoryPage = 1;
      _tokenHistoryLoadingMore = false;
    }
    final key = type == _PanelType.account
        ? _accountButtonKey
        : _tokenButtonKey;
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      setState(() {
        _panelType = type;
        _showPanel = true;
      });
      _sheetController.forward(from: 0);
      return;
    }

    final startOffset = renderBox.localToGlobal(Offset.zero);
    final startSize = renderBox.size;
    _sheetStartRect = Rect.fromLTWH(
      startOffset.dx,
      startOffset.dy,
      startSize.width,
      startSize.height,
    );

    final media = MediaQuery.of(context).size;
    final panelTop = type == _PanelType.token ? 148.0 : 120.0;
    final panelWidth = type == _PanelType.token
        ? media.width - 40
        : media.width - 32;
    _sheetEndRect = Rect.fromLTWH(
      type == _PanelType.token ? 20 : 16,
      panelTop,
      panelWidth,
      media.height * 0.68,
    );
    final center =
        startOffset + Offset(startSize.width / 2, startSize.height / 2);
    final dx =
        ((center.dx - _sheetEndRect!.left) / _sheetEndRect!.width) * 2 - 1;
    final dy =
        ((center.dy - _sheetEndRect!.top) / _sheetEndRect!.height) * 2 - 1;
    _sheetAnchorAlignment = Alignment(dx.clamp(-1, 1), dy.clamp(-1, 1));

    setState(() {
      _panelType = type;
      _showPanel = true;
    });
    _sheetController.forward(from: 0);
  }

  void _togglePanel(_PanelType type) {
    HapticFeedback.selectionClick();
    if (_showPanel) {
      if (_panelType == type) {
        _closePanel();
        return;
      }
      _sheetController.reverse().whenComplete(() {
        if (mounted) {
          _openPanel(type);
        }
      });
      return;
    }
    _openPanel(type);
  }

  void _showAccountSheet() {
    _togglePanel(_PanelType.account);
  }

  Widget _buildAccountButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _accountButtonKey,
        onTap: () => _togglePanel(_PanelType.account),
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF94A3B8)
                    : Theme.of(context).colorScheme.outline,
                width: 2,
              ),
            ),
          ),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.surface,
            backgroundImage: _user?.photoURL != null
                ? NetworkImage(_user!.photoURL!)
                : null,
            child: _user?.photoURL == null
                ? Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildLogoMark(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'SCOOP',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: theme.colorScheme.onBackground,
      ),
    );
  }

  Widget _buildTokenChip(BuildContext context, AppLocalizations loc) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _tokenButtonKey,
        onTap: () => _togglePanel(_PanelType.token),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                loc.tokensLabel(_tokenBalance),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeIndex = _tabs.isEmpty
        ? 0
        : _currentIndex.clamp(0, _tabs.length - 1);
    final loc = AppLocalizations.of(context)!;
    final tabRegion = _regionForTab(safeIndex);
    final isLocked = safeIndex >= 2 && !_isTabUnlocked(safeIndex);
    if (isLocked &&
        safeIndex < _keywords.length &&
        _keywords[safeIndex].trim().isNotEmpty) {
      _scheduleExpiredPrune();
    }
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildLogoMark(context)),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                onPressed: _showSavedArticles,
                                icon: const Icon(Icons.bookmarks_outlined),
                                tooltip: loc.savedArticlesTitle,
                                constraints: const BoxConstraints(
                                  minHeight: 32,
                                  minWidth: 32,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    onPressed: _showNotificationHistory,
                                    icon: const Icon(Icons.notifications),
                                    tooltip: loc.notificationsTitle,
                                    constraints: const BoxConstraints(
                                      minHeight: 32,
                                      minWidth: 32,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  if (_hasUnreadNotifications)
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              IconButton(
                                onPressed: _showSettingsPage,
                                icon: const Icon(Icons.settings),
                                tooltip: loc.settingsTitle,
                                constraints: const BoxConstraints(
                                  minHeight: 32,
                                  minWidth: 32,
                                ),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  _formatRegionTime(_currentRegion),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                              _buildAccountButton(context),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTokenChip(context, loc),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: safeIndex == 0 || isLocked
                                ? null
                                : _showKeywordDialog,
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: safeIndex == 0
                                    ? Colors.transparent
                                    : Theme.of(
                                        context,
                                      ).colorScheme.surface.withOpacity(0.85),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: safeIndex == 0
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      safeIndex == 0
                                          ? _tabTitle(loc, safeIndex)
                                          : (_keywords[safeIndex].isEmpty
                                                ? loc.setKeyword
                                                : _keywords[safeIndex]),
                                      maxLines: safeIndex == 0 ? 2 : 1,
                                      overflow: safeIndex == 0
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                          ),
                                    ),
                                  ),
                                  if (safeIndex != 0) ...[
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            safeIndex == 0
                                ? loc.topBreakingHeadlines(tabRegion)
                                : loc.tapTitleToEditKeyword,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _triggerRefresh,
                              icon: AnimatedRotation(
                                turns: _refreshTurns.toDouble(),
                                duration: const Duration(milliseconds: 500),
                                child: const Icon(Icons.refresh),
                              ),
                              tooltip: loc.refresh,
                              constraints: const BoxConstraints(
                                minHeight: 32,
                                minWidth: 32,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            IconButton(
                              onPressed: _showRegionDialog,
                              icon: const Icon(Icons.filter_alt_outlined),
                              tooltip: loc.regionFilter,
                              constraints: const BoxConstraints(
                                minHeight: 32,
                                minWidth: 32,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        Text(
                          _regionLabel(loc, tabRegion),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutQuart,
                  switchOutCurve: Curves.easeInQuart,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0.18, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: isLocked
                      ? _buildLockedTab(loc, safeIndex)
                      : safeIndex != 0 && _keywords[safeIndex].isEmpty
                      ? Center(
                          key: ValueKey('empty-$safeIndex'),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(loc.noKeywordSet),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _showKeywordDialog,
                                child: Text(loc.setKeyword),
                              ),
                            ],
                          ),
                        )
                      : NewsList(
                          key: ValueKey(
                            '${safeIndex == 0 ? _breakingKeywordForRegion(tabRegion, _language) : _keywords[safeIndex]}::$tabRegion::$_language',
                          ),
                          keyword: safeIndex == 0
                              ? _breakingKeywordForRegion(tabRegion, _language)
                              : _keywords[safeIndex],
                          region: tabRegion,
                          language: _language,
                          feedLanguage: tabRegion == 'ALL'
                              ? 'en'
                              : _regionNewsLang[tabRegion] ?? 'en',
                          limit: safeIndex == 0 ? 20 : 10,
                          refreshToken: _refreshToken,
                          softRefreshToken: _autoRefreshToken,
                          blockedDomains: _blockedDomains,
                          onCanonicalResolved: (canonical) {
                            _updateCanonicalKeyword(safeIndex, canonical);
                          },
                          onItemsLoaded: (items) {
                            _handleItemsLoaded(safeIndex, items);
                          },
                          onManualRefresh: safeIndex == 0
                              ? () async {
                                  await _activateBreakingTabOnDemand(
                                    force: true,
                                  );
                                }
                              : null,
                          isSaved: _isArticleSaved,
                          onToggleSave: _toggleSaveArticle,
                          onReport: _reportArticle,
                          onBlock: _blockSource,
                        ),
                ),
              ),
            ],
          );
    final panelChild = _panelType == _PanelType.account
        ? _buildAccountPanel(loc)
        : _buildTokenPanel(loc);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_showPanel) {
          _closePanel();
          return;
        }
        if (_exitDialogShowing) return;
        _exitDialogShowing = true;
        final shouldExit = await _confirmExit();
        _exitDialogShowing = false;
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            body,
            if (_showPanel)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closePanel,
                  child: Container(
                    color: Colors.black.withOpacity(
                      0.35 * _sheetAnimation.value,
                    ),
                  ),
                ),
              ),
            if (_showPanel)
              AnimatedBuilder(
                animation: _sheetAnimation,
                builder: (context, child) {
                  final end =
                      _sheetEndRect ??
                      Rect.fromLTWH(
                        16,
                        MediaQuery.of(context).padding.top + 24,
                        MediaQuery.of(context).size.width - 32,
                        MediaQuery.of(context).size.height * 0.68,
                      );
                  final scale = 0.1 + 0.9 * _sheetAnimation.value;
                  return Positioned(
                    left: end.left,
                    top: end.top,
                    width: end.width,
                    height: end.height,
                    child: Opacity(
                      opacity: _sheetAnimation.value,
                      child: Transform.scale(
                        alignment: _sheetAnchorAlignment,
                        scale: scale,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: panelChild,
              ),
          ],
        ),
        bottomNavigationBar: _loading
            ? null
            : BottomNavigationBar(
                currentIndex: safeIndex,
                type: BottomNavigationBarType.fixed,
                onTap: (index) {
                  _handleTabTap(index);
                },
                items: List.generate(
                  _tabs.length,
                  (index) => BottomNavigationBarItem(
                    icon: _buildTabIcon(index),
                    label: _tabLabel(loc, index),
                    tooltip: _tabTooltip(loc, index),
                  ),
                ),
              ),
      ),
    );
  }
}

class NewsList extends StatefulWidget {
  const NewsList({
    super.key,
    required this.keyword,
    required this.region,
    this.language,
    required this.feedLanguage,
    this.limit = 10,
    this.refreshToken = 0,
    this.softRefreshToken = 0,
    required this.blockedDomains,
    this.onCanonicalResolved,
    this.onItemsLoaded,
    this.onManualRefresh,
    this.isSaved,
    this.onToggleSave,
    this.onReport,
    this.onBlock,
  });

  final String keyword;
  final String region;
  final String? language;
  final String feedLanguage;
  final int limit;
  final int refreshToken;
  final int softRefreshToken;
  final Set<String> blockedDomains;
  final ValueChanged<String>? onCanonicalResolved;
  final ValueChanged<List<NewsItem>>? onItemsLoaded;
  final Future<void> Function()? onManualRefresh;
  final bool Function(NewsItem)? isSaved;
  final Future<void> Function(NewsItem)? onToggleSave;
  final Future<void> Function(NewsItem)? onReport;
  final Future<void> Function(NewsItem)? onBlock;

  @override
  State<NewsList> createState() => _NewsListState();
}

class _BannerSlot {
  _BannerSlot(this.ad);

  final BannerAd ad;
  bool loaded = false;

  void dispose() {
    ad.dispose();
  }
}

class _NewsListState extends State<NewsList> {
  late Future<List<NewsItem>> _future;
  List<NewsItem> _cachedItems = [];
  static final Map<String, List<NewsItem>> _newsCache = {};
  static final Map<String, int> _processingSinceStore = {};
  int _fetchSequence = 0;
  int _refreshSeed = 0;
  int _rateLimitedUntilMs = 0;
  late final ScrollController _scrollController;
  int _currentLimit = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSoftRefresh = false;
  bool _pullRefreshInProgress = false;
  static const int _bannerInterval = 6;
  static const Duration _adRetryCooldown = Duration(hours: 1);
  static const int _processingEtaStartMinutes = 7;
  static const Duration _processingEtaTick = Duration(minutes: 1);
  static const Duration _processingEtaRetention = Duration(minutes: 30);
  final List<_BannerSlot> _bannerSlots = [];
  int _bannerFailureStreak = 0;
  DateTime? _bannerRetryAfter;
  bool _unityBannerLoaded = false;
  int _unityBannerFailureStreak = 0;
  DateTime? _unityBannerRetryAfter;
  final Map<String, int> _processingSinceMs = {};
  Timer? _processingEtaTimer;

  String get _cacheKey {
    return '${widget.keyword}::${widget.region}::${widget.language ?? 'en'}::${widget.feedLanguage}::$_currentLimit';
  }

  bool get _showAdDebugToastEnabled => kDebugMode || _adsDebugToast;

  void _showAdDebugToast(String message) {
    debugPrint('[AD DEBUG][Feed] $message');
    if (!mounted || !_showAdDebugToastEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showAdDebugToastEnabled) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('[AD] $message'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _syncProcessingEtaTracking(List<NewsItem> items) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final activeKeys = <String>{};
    for (final item in items) {
      final key = _articleKey(item);
      if (key.isEmpty) continue;
      if (!item.processing) {
        _processingSinceStore.remove(key);
        continue;
      }
      activeKeys.add(key);
      final parsedStartedAtMs = _parseIsoDate(
        item.processingStartedAt,
      )?.millisecondsSinceEpoch;
      if (parsedStartedAtMs != null && parsedStartedAtMs > 0) {
        final existingStartedAtMs = _processingSinceStore[key];
        if (existingStartedAtMs == null ||
            parsedStartedAtMs < existingStartedAtMs) {
          _processingSinceStore[key] = parsedStartedAtMs;
        }
      }
      final trackedStartedAtMs = _processingSinceStore.putIfAbsent(
        key,
        () => nowMs,
      );
      _processingSinceMs[key] = trackedStartedAtMs;
    }
    _processingSinceMs.removeWhere((key, _) => !activeKeys.contains(key));
    _processingSinceStore.removeWhere(
      (_, startedAtMs) =>
          nowMs - startedAtMs > _processingEtaRetention.inMilliseconds,
    );
    if (_processingSinceMs.isEmpty) {
      _processingEtaTimer?.cancel();
      _processingEtaTimer = null;
      return;
    }
    if (_processingEtaTimer != null) return;
    _processingEtaTimer = Timer.periodic(_processingEtaTick, (timer) {
      if (!mounted || _processingSinceMs.isEmpty) {
        timer.cancel();
        _processingEtaTimer = null;
        return;
      }
      setState(() {});
    });
  }

  String _localizedProcessingEtaText(int minutes) {
    // ETA text must follow app UI language, not article/feed language.
    return AppLocalizations.of(context)!.processingEtaMinutes(minutes);
  }

  String? _processingEtaTextFor(NewsItem item) {
    if (!item.processing) return null;
    final key = _articleKey(item);
    if (key.isEmpty) return null;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final serverStartedAtMs = _parseIsoDate(
      item.processingStartedAt,
    )?.millisecondsSinceEpoch;
    if (serverStartedAtMs != null && serverStartedAtMs > 0) {
      final existingStartedAtMs = _processingSinceStore[key];
      if (existingStartedAtMs == null ||
          serverStartedAtMs < existingStartedAtMs) {
        _processingSinceStore[key] = serverStartedAtMs;
      }
    }
    final startedAtMs =
        _processingSinceMs[key] ??
        _processingSinceStore[key] ??
        serverStartedAtMs ??
        nowMs;
    final elapsedMinutes = max(
      0,
      (nowMs - startedAtMs) ~/ Duration.millisecondsPerMinute,
    );
    final etaTotalMinutes = item.processingEtaMinutes > 0
        ? item.processingEtaMinutes
        : _processingEtaStartMinutes;
    final remainingMinutes = max(0, etaTotalMinutes - elapsedMinutes);
    return _localizedProcessingEtaText(remainingMinutes);
  }

  @override
  void initState() {
    super.initState();
    _currentLimit = widget.limit;
    _scrollController = ScrollController()..addListener(_handleScroll);
    if (_unityBannerFallbackConfigured) {
      unawaited(_ensureUnityAdsInitialized());
    }
    _cachedItems = _newsCache[_cacheKey] ?? [];
    _syncProcessingEtaTracking(_cachedItems);
    _future = _fetchNews();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    for (final slot in _bannerSlots) {
      slot.dispose();
    }
    _processingEtaTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NewsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keyword != widget.keyword ||
        oldWidget.region != widget.region ||
        oldWidget.language != widget.language ||
        oldWidget.limit != widget.limit) {
      _isSoftRefresh = false;
      _currentLimit = widget.limit;
      _hasMore = true;
      _refreshSeed = 0;
      _cachedItems = _newsCache[_cacheKey] ?? [];
      _syncProcessingEtaTracking(_cachedItems);
      _future = _fetchNews();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() {
        _isSoftRefresh = false;
        _refreshSeed = DateTime.now().millisecondsSinceEpoch;
        _future = _fetchNews();
      });
    } else if (oldWidget.softRefreshToken != widget.softRefreshToken) {
      if (_pullRefreshInProgress) {
        return;
      }
      setState(() {
        _isSoftRefresh = true;
        _refreshSeed = DateTime.now().millisecondsSinceEpoch;
        _future = _fetchNews();
      });
    }
  }

  Future<List<NewsItem>> _fetchNews() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_rateLimitedUntilMs > nowMs) {
      return _cachedItems;
    }
    final requestId = ++_fetchSequence;
    final lang = widget.language ?? 'en';
    final queryParams = <String, String>{
      'keyword': widget.keyword,
      'lang': lang,
      'feedLang': widget.feedLanguage,
      'region': widget.region,
      'limit': _currentLimit.toString(),
    };
    if (_refreshSeed != 0) {
      queryParams['refreshSeed'] = _refreshSeed.toString();
      if (!_isSoftRefresh) {
        queryParams['refresh'] = '1';
      }
    }
    final uri = Uri.parse(
      '$apiBaseUrl/news',
    ).replace(queryParameters: queryParams);
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode == 429) {
        int retryAfter = 5;
        final header = response.headers['retry-after'];
        if (header != null) {
          retryAfter = int.tryParse(header) ?? retryAfter;
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              retryAfter =
                  int.tryParse(decoded['retryAfter']?.toString() ?? '') ??
                  retryAfter;
            }
          } catch (_) {}
        }
        if (mounted) {
          _showRateLimitToast(context, retryAfter);
        }
        _rateLimitedUntilMs =
            DateTime.now().millisecondsSinceEpoch + (retryAfter * 1000);
        return _cachedItems;
      }
      if (response.statusCode != 200) {
        return _cachedItems;
      }
      _rateLimitedUntilMs = 0;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _cachedItems;
      }
      final canonical = decoded['canonical']?.toString();
      if (canonical != null && canonical.isNotEmpty) {
        widget.onCanonicalResolved?.call(canonical);
      }
      final itemsRaw = decoded['items'];
      if (itemsRaw is! List) {
        return _cachedItems;
      }
      final items = itemsRaw
          .whereType<Map<String, dynamic>>()
          .map(NewsItem.fromJson)
          .toList();
      if (items.isEmpty && _cachedItems.isNotEmpty) {
        widget.onItemsLoaded?.call(_cachedItems);
        return _cachedItems;
      }
      if (requestId != _fetchSequence) {
        return _cachedItems;
      }
      items.sort((a, b) {
        final aPinned = a.severity >= 4;
        final bPinned = b.severity >= 4;
        if (aPinned != bPinned) return bPinned ? 1 : -1;
        if (aPinned && bPinned) {
          final sevDiff = b.severity.compareTo(a.severity);
          if (sevDiff != 0) return sevDiff;
        }
        final aTime = DateTime.tryParse(a.publishedAt);
        final bTime = DateTime.tryParse(b.publishedAt);
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      if (_isSoftRefresh && _cachedItems.isNotEmpty) {
        if (_pullRefreshInProgress) {
          _cachedItems = items;
          _newsCache[_cacheKey] = _cachedItems;
          _syncProcessingEtaTracking(_cachedItems);
          _hasMore = items.length >= _currentLimit;
          widget.onItemsLoaded?.call(items);
          return items;
        }
        final oldPixels = _scrollController.hasClients
            ? _scrollController.position.pixels
            : 0.0;
        final oldMax = _scrollController.hasClients
            ? _scrollController.position.maxScrollExtent
            : 0.0;
        final existingKeys = _cachedItems.map(_articleKey).toSet();
        final latestByKey = <String, NewsItem>{};
        for (final item in items) {
          latestByKey[_articleKey(item)] = item;
        }
        final updatedCached = _cachedItems.map((item) {
          final key = _articleKey(item);
          return latestByKey[key] ?? item;
        }).toList();
        final retainedCached = updatedCached.where((item) {
          final key = _articleKey(item);
          if (latestByKey.containsKey(key)) return true;
          // If a processing placeholder disappeared from latest response,
          // drop it so "AI processing" cards don't stick forever.
          return !item.processing;
        }).toList();
        final newItems = items
            .where((item) => !existingKeys.contains(_articleKey(item)))
            .toList();
        final mergeAndDedupe = <NewsItem>[...newItems, ...retainedCached];
        final seenKeys = <String>{};
        final mergedItems = mergeAndDedupe.where((item) {
          final key = _articleKey(item);
          if (seenKeys.contains(key)) return false;
          seenKeys.add(key);
          return true;
        }).toList();
        if (newItems.isNotEmpty) {
          _cachedItems = mergedItems;
          _newsCache[_cacheKey] = _cachedItems;
          _syncProcessingEtaTracking(_cachedItems);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            if (oldPixels <= 0) return;
            final newMax = _scrollController.position.maxScrollExtent;
            final delta = newMax - oldMax;
            if (delta > 0) {
              _scrollController.jumpTo(oldPixels + delta);
            }
          });
        } else {
          _cachedItems = mergedItems;
          _newsCache[_cacheKey] = _cachedItems;
          _syncProcessingEtaTracking(_cachedItems);
        }
      } else {
        _newsCache[_cacheKey] = items;
        _cachedItems = items;
        _syncProcessingEtaTracking(_cachedItems);
      }
      _hasMore = items.length >= _currentLimit;
      widget.onItemsLoaded?.call(items);
      return items;
    } on TimeoutException {
      return _cachedItems;
    } catch (_) {
      return _cachedItems;
    }
  }

  void _handleScroll() {
    if (!_hasMore || _isLoadingMore || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 240) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    setState(() {
      _isSoftRefresh = false;
      _currentLimit += 10;
      _future = _fetchNews();
    });
    try {
      final items = await _future;
      if (mounted) {
        setState(() {
          _hasMore = items.length >= _currentLimit;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      } else {
        _isLoadingMore = false;
      }
    }
  }

  Future<void> _refresh() async {
    try {
      _pullRefreshInProgress = true;
      if (widget.onManualRefresh != null) {
        try {
          await widget.onManualRefresh!();
        } catch (_) {}
      }
      setState(() {
        _isSoftRefresh = true;
        _refreshSeed = DateTime.now().millisecondsSinceEpoch;
        _currentLimit = widget.limit;
        _hasMore = true;
        _future = _fetchNews();
      });
      await _future;
    } catch (_) {
    } finally {
      _pullRefreshInProgress = false;
    }
  }

  List<NewsItem> _filterBlocked(List<NewsItem> items) {
    if (widget.blockedDomains.isEmpty) return items;
    return items.where((item) {
      final url = item.sourceUrl.isNotEmpty
          ? item.sourceUrl
          : (item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url);
      final domain = _domainFromUrl(url);
      final sourceKey = item.source.trim().isEmpty
          ? ''
          : 'source:${item.source.toLowerCase()}';
      if (sourceKey.isNotEmpty && widget.blockedDomains.contains(sourceKey)) {
        return false;
      }
      if (domain == null || domain.isEmpty) return true;
      if (_isGoogleDomain(domain)) return true;
      return !widget.blockedDomains.contains(domain);
    }).toList();
  }

  String _articleKey(NewsItem item) {
    final url = item.resolvedUrl.isNotEmpty ? item.resolvedUrl : item.url;
    if (url.isNotEmpty) return url;
    final seed = '${item.title}::${item.summary}';
    return sha1.convert(utf8.encode(seed)).toString();
  }

  int _bannerCountFor(int itemCount) {
    if (itemCount <= 0) return 0;
    // Show banner every N items and one more under the last article.
    // When itemCount is divisible by N, the "every N" banner is already last.
    return (itemCount / _bannerInterval).ceil();
  }

  void _ensureBannerSlots(int count) {
    if (_forceUnityAdsFallback) {
      if (_bannerSlots.isNotEmpty) {
        for (final slot in _bannerSlots) {
          slot.dispose();
        }
        _bannerSlots.clear();
      }
      return;
    }
    if (_bannerSlots.length > count) {
      final extras = _bannerSlots.sublist(count);
      for (final slot in extras) {
        slot.dispose();
      }
      _bannerSlots.removeRange(count, _bannerSlots.length);
      return;
    }
    final now = DateTime.now();
    if (_bannerRetryAfter != null && now.isBefore(_bannerRetryAfter!)) {
      return;
    }
    while (_bannerSlots.length < count) {
      late _BannerSlot slot;
      _showAdDebugToast('AdMob banner load start');
      final ad = BannerAd(
        size: AdSize.banner,
        adUnitId: _admobBannerId,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() {
              _bannerFailureStreak = 0;
              _bannerRetryAfter = null;
              slot.loaded = true;
            });
            _showAdDebugToast('AdMob banner loaded');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _bannerFailureStreak += 1;
              _bannerRetryAfter = DateTime.now().add(_adRetryCooldown);
              _bannerSlots.remove(slot);
            });
            _showAdDebugToast(
              'AdMob banner failed [${error.code}] ${error.message}. retry in ${_adRetryCooldown.inMinutes}m',
            );
          },
        ),
      );
      slot = _BannerSlot(ad);
      _bannerSlots.add(slot);
      ad.load();
    }
  }

  Widget _buildUnityBannerFallback(BuildContext context) {
    if (!_unityBannerFallbackConfigured) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    if (_unityBannerRetryAfter != null &&
        now.isBefore(_unityBannerRetryAfter!)) {
      return const SizedBox.shrink();
    }
    if (!_unityAdsInitialized) {
      unawaited(
        _ensureUnityAdsInitialized().then((initialized) {
          if (!mounted || !initialized) return;
          setState(() {});
        }),
      );
      return const SizedBox(
        height: 70,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          width: 320,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              UnityBannerAd(
                placementId: _unityBannerPlacementIdAndroid,
                size: BannerSize.standard,
                onLoad: (_) {
                  if (!mounted) return;
                  final shouldNotify = !_unityBannerLoaded;
                  setState(() {
                    _unityBannerLoaded = true;
                    _unityBannerFailureStreak = 0;
                    _unityBannerRetryAfter = null;
                  });
                  if (shouldNotify) {
                    _showAdDebugToast('Unity banner loaded');
                  }
                },
                onFailed: (placementId, error, message) {
                  if (!mounted) return;
                  final nextFailure = _unityBannerFailureStreak + 1;
                  setState(() {
                    _unityBannerLoaded = false;
                    _unityBannerFailureStreak = nextFailure;
                    _unityBannerRetryAfter = DateTime.now().add(
                      _adRetryCooldown,
                    );
                  });
                  _showAdDebugToast(
                    'Unity banner failed [$error] $message. retry in ${_adRetryCooldown.inMinutes}m',
                  );
                },
              ),
              if (!_unityBannerLoaded)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerAd(BuildContext context, _BannerSlot slot) {
    if (!slot.loaded) {
      return SizedBox(
        height: slot.ad.size.height.toDouble(),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          width: slot.ad.size.width.toDouble(),
          height: slot.ad.size.height.toDouble(),
          child: AdWidget(ad: slot.ad),
        ),
      ),
    );
  }

  Widget _buildNewsList(List<NewsItem> items) {
    final visibleItems = _filterBlocked(items);
    final extra = _isLoadingMore ? 1 : 0;
    final desiredBannerCount = _bannerCountFor(visibleItems.length);
    final admobBannerCount = _bannerCountFor(visibleItems.length);
    _ensureBannerSlots(admobBannerCount);
    final effectiveAdmobBannerCount = min(
      admobBannerCount,
      _bannerSlots.length,
    );
    final hasLoadedAdmobBanner = _bannerSlots.any((slot) => slot.loaded);
    final now = DateTime.now();
    final showUnityFallbackBanner =
        _unityBannerFallbackConfigured &&
        (_forceUnityAdsFallback ||
            (_bannerFailureStreak > 0 && !hasLoadedAdmobBanner)) &&
        visibleItems.isNotEmpty &&
        (_unityBannerRetryAfter == null ||
            now.isAfter(_unityBannerRetryAfter!));
    final bannerCount = showUnityFallbackBanner
        ? desiredBannerCount
        : effectiveAdmobBannerCount;
    final contentCount = visibleItems.length + bannerCount;
    final intervalWithAd = _bannerInterval + 1;
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      itemCount: contentCount + extra,
      itemBuilder: (context, index) {
        if (index >= contentCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final isRegularAdSlot =
            bannerCount > 0 && (index + 1) % intervalWithAd == 0;
        final isLastAdSlot = bannerCount > 0 && index == contentCount - 1;
        final isAdSlot = isRegularAdSlot || isLastAdSlot;
        if (isAdSlot) {
          if (showUnityFallbackBanner) {
            return _buildUnityBannerFallback(context);
          }
          final adSlotIndex = (isLastAdSlot && !isRegularAdSlot)
              ? bannerCount - 1
              : (index + 1) ~/ intervalWithAd - 1;
          if (adSlotIndex >= 0 && adSlotIndex < _bannerSlots.length) {
            return _buildBannerAd(context, _bannerSlots[adSlotIndex]);
          }
          return const SizedBox.shrink();
        }
        final adsBefore = bannerCount == 0 ? 0 : index ~/ intervalWithAd;
        final itemIndex = index - adsBefore;
        final item = visibleItems[itemIndex];
        return NewsCard(
          item: item,
          language: widget.language ?? 'en',
          processingEtaText: _processingEtaTextFor(item),
          isSaved: widget.isSaved?.call(item) ?? false,
          onToggleSave: widget.onToggleSave,
          onReport: widget.onReport,
          onBlock: widget.onBlock,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<NewsItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            if (_cachedItems.isNotEmpty) {
              return _buildNewsList(_cachedItems);
            }
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            if (_cachedItems.isNotEmpty) {
              return _buildNewsList(_cachedItems);
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(loc.failedToLoadNews)),
              ],
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            if (_cachedItems.isNotEmpty) {
              return _buildNewsList(_cachedItems);
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(loc.noArticlesFound)),
              ],
            );
          }
          final visibleItems = _filterBlocked(items);
          if (visibleItems.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                Center(child: Text(loc.noArticlesFound)),
              ],
            );
          }
          return _buildNewsList(items);
        },
      ),
    );
  }
}

enum _ArticleMenuAction { save, share, report, block }

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.item,
    required this.language,
    this.processingEtaText,
    this.isSaved = false,
    this.onToggleSave,
    this.onReport,
    this.onBlock,
  });

  final NewsItem item;
  final String language;
  final String? processingEtaText;
  final bool isSaved;
  final Future<void> Function(NewsItem)? onToggleSave;
  final Future<void> Function(NewsItem)? onReport;
  final Future<void> Function(NewsItem)? onBlock;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final severity = item.severity;
    final isCritical = severity >= 5;
    final isHigh = severity == 4;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final domain = _resolveFaviconDomain(item);
    final publishedAt = DateTime.tryParse(item.publishedAt);
    final relativeTime = publishedAt == null
        ? item.publishedAtLabel
        : timeago.format(publishedAt, locale: _timeagoLocale(language));
    final isDark = theme.brightness == Brightness.dark;
    final isLightCritical = isCritical && theme.brightness == Brightness.light;
    final primaryTextColor = isLightCritical
        ? Colors.white
        : colorScheme.onSurface;
    final secondaryTextColor = isLightCritical
        ? Colors.white70
        : colorScheme.onSurfaceVariant;
    final iconColor = isLightCritical
        ? Colors.white
        : colorScheme.onSurfaceVariant;
    final bookmarkColor = isLightCritical
        ? Colors.white
        : (isSaved ? colorScheme.primary : colorScheme.onSurfaceVariant);
    final borderColor = isCritical
        ? Colors.red.shade600
        : isHigh
        ? Colors.orange.shade700
        : colorScheme.outlineVariant;
    final showProcessing = item.processing;
    final processingTextColor = isCritical
        ? Colors.white
        : colorScheme.onSurfaceVariant;
    final processingBackground = isCritical
        ? Colors.white.withOpacity(0.2)
        : colorScheme.surfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isCritical
            ? colorScheme.errorContainer.withOpacity(0.85)
            : colorScheme.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: isCritical || isHigh ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.32 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              _buildSlideFadeRoute(
                ArticlePage(
                  item: item,
                  language: language,
                  isSaved: isSaved,
                  onToggleSave: onToggleSave,
                  onReport: onReport,
                  onBlock: onBlock,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCritical || showProcessing)
                  Row(
                    children: [
                      if (isCritical)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            loc.urgentBadge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isCritical && showProcessing)
                        const SizedBox(width: 8),
                      if (showProcessing)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: processingBackground,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                loc.translatingBadge,
                                style: TextStyle(
                                  color: processingTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if ((processingEtaText ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  processingEtaText!,
                                  style: TextStyle(
                                    color: processingTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                if (isCritical || showProcessing) const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: iconColor),
                    const SizedBox(width: 6),
                    Text(
                      relativeTime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (onToggleSave != null)
                      IconButton(
                        onPressed: () => onToggleSave!(item),
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          size: 20,
                          color: bookmarkColor,
                        ),
                        tooltip: isSaved ? loc.removeSaved : loc.saveArticle,
                        constraints: const BoxConstraints(minWidth: 36),
                        padding: EdgeInsets.zero,
                      ),
                    PopupMenuButton<_ArticleMenuAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _ArticleMenuAction.save:
                            if (onToggleSave != null) {
                              onToggleSave!(item);
                            }
                            break;
                          case _ArticleMenuAction.share:
                            _showShareSheet(context, item);
                            break;
                          case _ArticleMenuAction.report:
                            if (onReport != null) {
                              onReport!(item);
                            }
                            break;
                          case _ArticleMenuAction.block:
                            if (onBlock != null) {
                              onBlock!(item);
                            }
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _ArticleMenuAction.share,
                          child: Text(loc.shareArticle),
                        ),
                        PopupMenuItem(
                          value: _ArticleMenuAction.report,
                          child: Text(loc.reportArticle),
                        ),
                        PopupMenuItem(
                          value: _ArticleMenuAction.block,
                          child: Text(loc.blockSource),
                        ),
                      ],
                      icon: Icon(Icons.more_horiz, size: 20, color: iconColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: isCritical || isHigh
                        ? FontWeight.w800
                        : FontWeight.w700,
                    color: primaryTextColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (domain != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Image.network(
                          _faviconUrl(domain),
                          width: 18,
                          height: 18,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.public,
                              size: 16,
                              color: iconColor,
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          item.source.isNotEmpty
                              ? item.source.characters.first.toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.source,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.severity >= 4) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.summary.isNotEmpty ? item.summary : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PageRouteBuilder<void> _buildSlideFadeRoute(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.18, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

class ArticlePage extends StatefulWidget {
  const ArticlePage({
    super.key,
    required this.item,
    required this.language,
    this.isSaved = false,
    this.onToggleSave,
    this.onReport,
    this.onBlock,
  });

  final NewsItem item;
  final String language;
  final bool isSaved;
  final Future<void> Function(NewsItem)? onToggleSave;
  final Future<void> Function(NewsItem)? onReport;
  final Future<void> Function(NewsItem)? onBlock;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

enum SummaryLength { short, medium, long, full }

enum _RewardAdResult { rewarded, shownNotRewarded, unavailable }

class _TranslationGateResult {
  const _TranslationGateResult({
    required this.used,
    required this.remaining,
    required this.shouldShowAd,
  });

  final int used;
  final int remaining;
  final bool shouldShowAd;
}

class _TranslationCachePayload {
  const _TranslationCachePayload({
    required this.content,
    required this.limited,
    required this.link,
  });

  final String content;
  final bool limited;
  final String link;
}

class _ArticlePageState extends State<ArticlePage> {
  late final WebViewController _webViewController;
  late final String _articleUrl;
  String _currentUrl = '';
  bool _summarizing = false;
  String _summaryContent = "";
  String _summaryNotice = "";
  String _summaryLink = "";
  bool _showSummaryContent = false;
  SummaryLength _summaryLength = SummaryLength.medium;
  late bool _isSaved;
  bool _showAdBadge = false;
  RewardedAd? _rewardedAd;
  bool _rewardedAdLoading = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
    _articleUrl = _upgradeToHttps(
      widget.item.resolvedUrl.isNotEmpty
          ? widget.item.resolvedUrl
          : widget.item.url,
    );
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            _currentUrl = url;
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('http://')) {
              final upgraded = _upgradeToHttps(request.url);
              _currentUrl = upgraded;
              _webViewController.loadRequest(Uri.parse(upgraded));
              return NavigationDecision.prevent;
            }
            _currentUrl = request.url;
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_articleUrl));
    _loadSummaryPreference();
    _syncServerTime();
    _loadRewardedAd();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAdBadge();
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArticlePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSaved != widget.isSaved) {
      _isSaved = widget.isSaved;
    }
  }

  Future<void> _loadSummaryPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('summaryLength') ?? 'medium';
    setState(() {
      _summaryLength = switch (stored) {
        'short' => SummaryLength.short,
        'long' => SummaryLength.long,
        'full' => SummaryLength.full,
        _ => SummaryLength.medium,
      };
    });
  }

  Future<void> _setSummaryPreference(SummaryLength length) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('summaryLength', length.name);
    if (!mounted) return;
    setState(() {
      _summaryLength = length;
      _summaryContent = '';
      _summaryNotice = '';
      _summaryLink = '';
      _showSummaryContent = false;
    });
  }

  Future<void> _refreshAdBadge() async {
    final hasPaidTabs = await _hasActivePaidTabs();
    if (hasPaidTabs) {
      if (mounted) {
        setState(() {
          _showAdBadge = false;
        });
      }
      return;
    }
    final gate = await _loadFreeTranslationGate();
    if (!mounted) return;
    setState(() {
      _showAdBadge = gate.remaining == 0;
    });
  }

  Future<bool> _hasActivePaidTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tabExpiry');
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final now = _serverNow();
      for (final entry in decoded.entries) {
        final index = int.tryParse(entry.key.toString());
        if (index == null || index < 2) continue;
        final expiry = DateTime.tryParse(entry.value.toString());
        if (expiry != null && expiry.isAfter(now)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<_TranslationGateResult> _loadFreeTranslationGate() async {
    await _syncServerTime();
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _localDateKey(_serverNow());
    final storedDate = prefs.getString(_freeTranslationDateKey);
    if (storedDate != todayKey) {
      await prefs.setString(_freeTranslationDateKey, todayKey);
      await prefs.setInt(_freeTranslationUsedKey, 0);
    }
    final used = prefs.getInt(_freeTranslationUsedKey) ?? 0;
    final remaining = (_dailyFreeTranslationLimit - used).clamp(
      0,
      _dailyFreeTranslationLimit,
    );
    final shouldShowAd = remaining == 0;
    return _TranslationGateResult(
      used: used,
      remaining: remaining,
      shouldShowAd: shouldShowAd,
    );
  }

  Future<void> _setFreeTranslationUsed(int used) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = used.clamp(0, _dailyFreeTranslationLimit);
    await prefs.setInt(_freeTranslationUsedKey, clamped);
  }

  Future<void> _showFreeRemainingDialog({
    required int used,
    required int remaining,
  }) async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    final message = remaining > 0
        ? loc.freeTranslationUsage(used, remaining)
        : loc.freeTranslationExhausted;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(loc.freeTranslationTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.confirm),
            ),
          ],
        );
      },
    );
  }

  bool get _showAdDebugToastEnabled => kDebugMode || _adsDebugToast;

  void _showAdDebugToast(String message) {
    debugPrint('[AD DEBUG][Article] $message');
    if (!mounted || !_showAdDebugToastEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showAdDebugToastEnabled) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('[AD] $message'),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _loadRewardedAd() {
    if (_forceUnityAdsFallback) return;
    if (_rewardedAdLoading || _rewardedAd != null) return;
    _rewardedAdLoading = true;
    _showAdDebugToast('AdMob rewarded load start');
    RewardedAd.load(
      adUnitId: _admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAdLoading = false;
          _rewardedAd = ad;
          _showAdDebugToast('AdMob rewarded loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAdLoading = false;
          _rewardedAd = null;
          _showAdDebugToast(
            'AdMob rewarded load failed [${error.code}] ${error.message}',
          );
        },
      ),
    );
  }

  Future<RewardedAd?> _loadRewardedAdOnce() async {
    _showAdDebugToast('AdMob rewarded one-shot load start');
    final completer = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: _admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _showAdDebugToast('AdMob rewarded one-shot loaded');
          completer.complete(ad);
        },
        onAdFailedToLoad: (error) {
          _showAdDebugToast(
            'AdMob rewarded one-shot failed [${error.code}] ${error.message}',
          );
          completer.complete(null);
        },
      ),
    );
    var timedOut = false;
    final ad = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        timedOut = true;
        return null;
      },
    );
    if (timedOut) {
      _showAdDebugToast('AdMob rewarded one-shot timeout');
    }
    return ad;
  }

  Future<bool> _showUnityRewardedAdFallback() async {
    if (!_unityRewardedFallbackConfigured) {
      _showAdDebugToast('Unity rewarded fallback not configured');
      return false;
    }
    _showAdDebugToast('Unity rewarded fallback start');
    final initialized = await _ensureUnityAdsInitialized();
    if (!initialized) {
      _showAdDebugToast('Unity rewarded init failed');
      return false;
    }

    final loadCompleter = Completer<bool>();
    try {
      await UnityAds.load(
        placementId: _unityRewardedPlacementIdAndroid,
        onComplete: (_) {
          _showAdDebugToast('Unity rewarded loaded');
          if (!loadCompleter.isCompleted) {
            loadCompleter.complete(true);
          }
        },
        onFailed: (placementId, error, message) {
          _showAdDebugToast('Unity rewarded load failed [$error] $message');
          if (!loadCompleter.isCompleted) {
            loadCompleter.complete(false);
          }
        },
      );
    } catch (_) {
      _showAdDebugToast('Unity rewarded load exception');
      if (!loadCompleter.isCompleted) {
        loadCompleter.complete(false);
      }
    }

    var loadTimedOut = false;
    final loaded = await loadCompleter.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        loadTimedOut = true;
        return false;
      },
    );
    if (!loaded) {
      if (loadTimedOut) {
        _showAdDebugToast('Unity rewarded load timeout');
      }
      return false;
    }

    final showCompleter = Completer<bool>();
    try {
      await UnityAds.showVideoAd(
        placementId: _unityRewardedPlacementIdAndroid,
        onComplete: (_) {
          _showAdDebugToast('Unity rewarded completed');
          if (!showCompleter.isCompleted) {
            showCompleter.complete(true);
          }
        },
        onSkipped: (_) {
          _showAdDebugToast('Unity rewarded skipped');
          if (!showCompleter.isCompleted) {
            showCompleter.complete(false);
          }
        },
        onFailed: (placementId, error, message) {
          _showAdDebugToast('Unity rewarded show failed [$error] $message');
          if (!showCompleter.isCompleted) {
            showCompleter.complete(false);
          }
        },
      );
    } catch (_) {
      _showAdDebugToast('Unity rewarded show exception');
      if (!showCompleter.isCompleted) {
        showCompleter.complete(false);
      }
    }

    var showTimedOut = false;
    final shown = await showCompleter.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        showTimedOut = true;
        return false;
      },
    );
    if (showTimedOut) {
      _showAdDebugToast('Unity rewarded show timeout');
    }
    return shown;
  }

  String _generateRewardNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  void _showTokenMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Map<String, dynamic>?> _postJson(
    String path,
    Map<String, dynamic> body, {
    required bool withAuth,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (withAuth) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return null;
        final idToken = await user.getIdToken();
        headers['Authorization'] = 'Bearer $idToken';
      }
      final response = await http.post(
        Uri.parse('$apiBaseUrl$path'),
        headers: headers,
        body: jsonEncode(body),
      );
      Map<String, dynamic> result = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          result = Map<String, dynamic>.from(decoded);
        }
      }
      result['statusCode'] = response.statusCode;
      _handleBannedResponse(response.statusCode, result);
      final serverTimeMs = int.tryParse(
        result['serverTimeMs']?.toString() ?? '',
      );
      if (serverTimeMs != null) {
        await _updateServerTimeOffset(serverTimeMs);
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _claimAdReward(String nonce) async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      final payload = await _postJson('/admob/claim', {
        'nonce': nonce,
      }, withAuth: FirebaseAuth.instance.currentUser != null);
      if (payload != null && payload['ok'] == true) {
        return true;
      }
      final error = payload?['error']?.toString() ?? '';
      final statusCode = payload?['statusCode'];
      if (error == 'reward_not_found' || statusCode == 404) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      return false;
    }
    return false;
  }

  Future<_RewardAdResult> _showRewardedAd() async {
    _showAdDebugToast('Reward flow start');
    if (_forceUnityAdsFallback) {
      _showAdDebugToast('Force Unity rewarded fallback enabled');
      final unityRewarded = await _showUnityRewardedAdFallback();
      if (unityRewarded) {
        _showAdDebugToast('Reward flow success via Unity');
        return _RewardAdResult.rewarded;
      }
      _showAdDebugToast('Reward flow unavailable (Unity fallback failed)');
      _showTokenMessage('Ad unavailable. Proceeding without reward.');
      return _RewardAdResult.unavailable;
    }
    RewardedAd? ad = _rewardedAd;
    _rewardedAd = null;
    if (ad == null) {
      _showAdDebugToast('No preloaded AdMob rewarded. Trying one-shot load.');
    } else {
      _showAdDebugToast('Using preloaded AdMob rewarded ad');
    }
    ad ??= await _loadRewardedAdOnce();
    if (ad == null) {
      _showAdDebugToast('AdMob rewarded unavailable. Trying Unity fallback.');
      final unityRewarded = await _showUnityRewardedAdFallback();
      if (unityRewarded) {
        _loadRewardedAd();
        _showAdDebugToast('Reward flow success via Unity fallback');
        return _RewardAdResult.rewarded;
      }
      _loadRewardedAd();
      _showAdDebugToast('Reward flow unavailable (all ad providers failed)');
      _showTokenMessage('Ad unavailable. Proceeding without reward.');
      return _RewardAdResult.unavailable;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final nonce = _generateRewardNonce();
    ad.setServerSideOptions(
      ServerSideVerificationOptions(
        userId: uid.isNotEmpty ? uid : null,
        customData: nonce,
      ),
    );
    final completer = Completer<bool>();
    var adFailedToShow = false;
    var adShown = false;
    var adShowTimedOut = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        adShown = true;
        _showAdDebugToast('AdMob rewarded shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        _showAdDebugToast('AdMob rewarded dismissed');
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        adFailedToShow = true;
        if (!completer.isCompleted) {
          completer.complete(false);
        }
        _showAdDebugToast(
          'AdMob rewarded failed to show [${error.code}] ${error.message}',
        );
        _loadRewardedAd();
      },
    );
    try {
      ad.show(
        onUserEarnedReward: (ad, reward) {
          _showAdDebugToast('AdMob rewarded callback received');
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );
    } catch (error) {
      _showAdDebugToast('AdMob rewarded show exception: $error');
      ad.dispose();
      _loadRewardedAd();
      final unityRewarded = await _showUnityRewardedAdFallback();
      if (unityRewarded) {
        _showAdDebugToast('Reward flow recovered via Unity fallback');
        return _RewardAdResult.rewarded;
      }
      _showTokenMessage('Ad unavailable. Proceeding without reward.');
      return _RewardAdResult.unavailable;
    }
    final rewarded = await completer.future.timeout(
      const Duration(seconds: 55),
      onTimeout: () {
        adShowTimedOut = true;
        return false;
      },
    );
    if (adShowTimedOut) {
      _showAdDebugToast('AdMob rewarded show timeout');
      ad.dispose();
      _loadRewardedAd();
    }
    if (!rewarded) {
      _showAdDebugToast('AdMob rewarded not earned. Trying Unity fallback.');
      final unityRewarded = await _showUnityRewardedAdFallback();
      if (unityRewarded) {
        _showAdDebugToast('Reward flow success via Unity after AdMob miss');
        return _RewardAdResult.rewarded;
      }
      if (adFailedToShow || !adShown) {
        _showAdDebugToast(
          'Reward flow unavailable (AdMob failed/not shown and Unity failed)',
        );
        _showTokenMessage('Ad unavailable. Proceeding without reward.');
        return _RewardAdResult.unavailable;
      }
      _showAdDebugToast('Ad shown but not rewarded');
      return _RewardAdResult.shownNotRewarded;
    }
    _showAdDebugToast('Reward earned. Claiming server reward');
    final claimed = await _claimAdReward(nonce);
    if (!claimed) {
      _showAdDebugToast('Reward verification pending');
      _showTokenMessage('Reward verification pending.');
      return _RewardAdResult.rewarded;
    }
    _showAdDebugToast('Reward claim completed');
    return _RewardAdResult.rewarded;
  }

  String _translationCacheKey(
    String url,
    String language,
    SummaryLength length,
    bool isFull,
  ) {
    final mode = isFull ? 'full' : 'summary';
    final raw = 'v1|${url.trim()}|$language|$mode|${length.name}';
    final bytes = utf8.encode(raw);
    return sha1.convert(bytes).toString();
  }

  Future<_TranslationCachePayload?> _loadTranslationCache({
    required String url,
    required String language,
    required SummaryLength length,
    required bool isFull,
  }) async {
    try {
      final key = _translationCacheKey(url, language, length, isFull);
      final doc = await FirebaseFirestore.instance
          .collection('translationCache')
          .doc(key)
          .get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final content = data['translatedContent']?.toString() ?? '';
      if (content.isEmpty) return null;
      final limited = data['limited'] == true;
      final link = data['link']?.toString() ?? '';
      return _TranslationCachePayload(
        content: content,
        limited: limited,
        link: link,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTranslationCache({
    required String url,
    required String language,
    required SummaryLength length,
    required bool isFull,
    required String content,
    required bool limited,
    required String link,
  }) async {
    if (content.isEmpty) return;
    return;
  }

  Future<void> _summarizeContent() async {
    _showAdDebugToast('Translate button tapped');
    if (!mounted) return;
    if (_showSummaryContent && _summaryContent.isNotEmpty) {
      setState(() {
        _showSummaryContent = false;
      });
      return;
    }
    if (_summarizing) return;
    if (_summaryContent.isNotEmpty) {
      setState(() {
        _showSummaryContent = true;
      });
      return;
    }
    final hasPaidTabs = await _hasActivePaidTabs();
    if (!hasPaidTabs) {
      final gate = await _loadFreeTranslationGate();
      if (!mounted) return;
      _showAdDebugToast(
        'Free translation gate: used=${gate.used}, remaining=${gate.remaining}',
      );
      if (gate.remaining > 0) {
        final usedAfter = (gate.used + 1).clamp(0, _dailyFreeTranslationLimit);
        final remainingAfter = (_dailyFreeTranslationLimit - usedAfter).clamp(
          0,
          _dailyFreeTranslationLimit,
        );
        await _showFreeRemainingDialog(
          used: usedAfter,
          remaining: remainingAfter,
        );
        if (!mounted) return;
        await _setFreeTranslationUsed(usedAfter);
        await _refreshAdBadge();
      } else if (gate.shouldShowAd) {
        _showAdDebugToast('Free quota exhausted. Starting rewarded ad gate.');
        await _showFreeRemainingDialog(used: gate.used, remaining: 0);
        if (!mounted) return;
        final adResult = await _showRewardedAd();
        _showAdDebugToast('Reward gate result: ${adResult.name}');
      }
    }
    if (!mounted) return;
    _showAdDebugToast('Starting translation request');
    setState(() {
      _summarizing = true;
      _summaryNotice = '';
      _summaryLink = '';
    });
    try {
      final targetUrl = _currentUrl.isNotEmpty ? _currentUrl : _articleUrl;
      final isFull = _summaryLength == SummaryLength.full;
      final fallbackText = [
        widget.item.title,
        widget.item.summary,
      ].where((part) => part.trim().isNotEmpty).join('\n');
      final cached = await _loadTranslationCache(
        url: targetUrl,
        language: widget.language,
        length: _summaryLength,
        isFull: isFull,
      );
      if (cached != null) {
        if (!mounted) return;
        _showAdDebugToast('Translation cache hit');
        if (!mounted) return;
        setState(() {
          _summaryContent = cached.content;
          _summaryNotice = cached.limited
              ? AppLocalizations.of(context)!.summaryLimitedNotice
              : '';
          _summaryLink = cached.limited ? cached.link : '';
          if (_summaryContent.isNotEmpty) {
            _showSummaryContent = true;
          }
        });
        return;
      }
      final uri = Uri.parse('$apiBaseUrl/article/translate').replace(
        queryParameters: {
          'url': targetUrl,
          'lang': widget.language,
          if (fallbackText.isNotEmpty) 'fallback': fallbackText,
          if (!isFull) 'mode': 'summary',
          if (!isFull) 'length': _summaryLength.name,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode == 429) {
        _showAdDebugToast('Translation API rate limited (429)');
        int retryAfter = 5;
        final header = response.headers['retry-after'];
        if (header != null) {
          retryAfter = int.tryParse(header) ?? retryAfter;
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              retryAfter =
                  int.tryParse(decoded['retryAfter']?.toString() ?? '') ??
                  retryAfter;
            }
          } catch (_) {}
        }
        if (mounted) {
          _showRateLimitToast(context, retryAfter);
        }
        return;
      }
      if (response.statusCode == 200) {
        _showAdDebugToast('Translation API success (200)');
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final error = (payload['error'] ?? '').toString();
        if (error.isNotEmpty && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        }
        if (!mounted) return;
        setState(() {
          _summaryContent = (payload['translatedContent'] ?? '').toString();
          final limited = payload['limited'] == true;
          final noticeCode = payload['noticeCode']?.toString() ?? '';
          final payloadNotice = payload['notice']?.toString() ?? '';
          if (noticeCode == 'LONG_FALLBACK_SUMMARY') {
            _summaryNotice = AppLocalizations.of(
              context,
            )!.translationLongContentNotice;
          } else if (limited) {
            _summaryNotice = AppLocalizations.of(context)!.summaryLimitedNotice;
          } else {
            _summaryNotice = payloadNotice;
          }
          _summaryLink = limited ? (payload['link'] ?? '').toString() : '';
          if (_summaryContent.isNotEmpty) {
            _showSummaryContent = true;
          }
        });
        await _saveTranslationCache(
          url: targetUrl,
          language: widget.language,
          length: _summaryLength,
          isFull: isFull,
          content: _summaryContent,
          limited: payload['limited'] == true,
          link: (payload['link'] ?? '').toString(),
        );
      } else {
        _showAdDebugToast('Translation API failed (${response.statusCode})');
        _showTokenMessage('Translation failed. Please try again.');
      }
    } catch (error) {
      _showAdDebugToast('Translation exception: $error');
      _showTokenMessage('Translation failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _summarizing = false;
        });
      }
    }
  }

  String _formatSummaryText(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return cleaned;
    if (cleaned.contains('\n')) return cleaned;
    final parts = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
    if (parts.length <= 1) return cleaned;
    return parts.join('\n\n');
  }

  void _showSummarySettings() {
    final loc = AppLocalizations.of(context)!;
    SummaryLength pending = _summaryLength;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(loc.summarySettingsTitle),
                    subtitle: Text(loc.summaryLengthLabel),
                  ),
                  RadioListTile<SummaryLength>(
                    value: SummaryLength.short,
                    groupValue: pending,
                    title: Text(loc.summaryShort),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pending = value;
                      });
                    },
                  ),
                  RadioListTile<SummaryLength>(
                    value: SummaryLength.medium,
                    groupValue: pending,
                    title: Text(loc.summaryMedium),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pending = value;
                      });
                    },
                  ),
                  RadioListTile<SummaryLength>(
                    value: SummaryLength.long,
                    groupValue: pending,
                    title: Text(loc.summaryLong),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pending = value;
                      });
                    },
                  ),
                  RadioListTile<SummaryLength>(
                    value: SummaryLength.full,
                    groupValue: pending,
                    title: Text(loc.summaryFull),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        pending = value;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await _setSummaryPreference(pending);
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(loc.summarySave),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<_ArticleMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _ArticleMenuAction.save:
                  if (widget.onToggleSave != null) {
                    setState(() {
                      _isSaved = !_isSaved;
                    });
                    widget.onToggleSave!(widget.item);
                  }
                  break;
                case _ArticleMenuAction.share:
                  _showShareSheet(context, widget.item);
                  break;
                case _ArticleMenuAction.report:
                  if (widget.onReport != null) {
                    widget.onReport!(widget.item);
                  }
                  break;
                case _ArticleMenuAction.block:
                  if (widget.onBlock != null) {
                    widget.onBlock!(widget.item);
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              if (widget.onToggleSave != null)
                PopupMenuItem(
                  value: _ArticleMenuAction.save,
                  child: Text(_isSaved ? loc.removeSaved : loc.saveArticle),
                ),
              PopupMenuItem(
                value: _ArticleMenuAction.share,
                child: Text(loc.shareArticle),
              ),
              PopupMenuItem(
                value: _ArticleMenuAction.report,
                child: Text(loc.reportArticle),
              ),
              PopupMenuItem(
                value: _ArticleMenuAction.block,
                child: Text(loc.blockSource),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_showSummaryContent && _summaryContent.isNotEmpty)
            Positioned.fill(
              child: Stack(
                children: [
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.45
                            : 0.2,
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(
                                isDark ? 0.6 : 0.95,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withOpacity(isDark ? 0.35 : 0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDark ? 0.2 : 0.08,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showSummaryContent = false;
                                    });
                                  },
                                  icon: const Icon(Icons.article_outlined),
                                  label: Text(loc.openOriginal),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showSummaryContent = false;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.94),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? 0.35
                                        : 0.1,
                                  ),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 96),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatSummaryText(_summaryContent),
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      height: 1.7,
                                      letterSpacing: 0.1,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_summaryNotice.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _summaryNotice,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  if (_summaryLink.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    InkWell(
                                      onTap: () {
                                        _webViewController.loadRequest(
                                          Uri.parse(_summaryLink),
                                        );
                                        setState(() {
                                          _showSummaryContent = false;
                                        });
                                      },
                                      child: Text(
                                        _summaryLink,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: Opacity(
        opacity: 0.78,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  heroTag: 'summary',
                  onPressed: _summarizing ? null : _summarizeContent,
                  child: _summarizing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.summarize),
                ),
                if (_showAdBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'AD',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            FloatingActionButton.small(
              heroTag: 'summarySettings',
              onPressed: _showSummarySettings,
              child: const Icon(Icons.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationHistoryPage extends StatelessWidget {
  const NotificationHistoryPage({
    super.key,
    required this.title,
    required this.entries,
    required this.onClearAll,
  });

  final String title;
  final List<NotificationEntry> entries;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () async {
              await onClearAll();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(loc.notificationsClear),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(child: Text(loc.notificationsEmpty))
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.of(context).padding.bottom,
              ),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const Divider(height: 24),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final time = entry.timestamp
                    .toLocal()
                    .toString()
                    .split('.')
                    .first;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: entry.url.isEmpty
                          ? null
                          : () {
                              final language = Localizations.localeOf(
                                context,
                              ).languageCode;
                              final sourceLabel = entry.source.isNotEmpty
                                  ? entry.source
                                  : (_domainFromUrl(entry.url) ??
                                        'Notification');
                              final item = NewsItem(
                                title: entry.title,
                                summary: entry.body,
                                content: entry.body,
                                url: entry.url,
                                resolvedUrl: entry.url,
                                sourceUrl: entry.url,
                                source: sourceLabel,
                                publishedAt: entry.timestamp.toIso8601String(),
                                severity: entry.severity,
                              );
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ArticlePage(
                                    item: item,
                                    language: language,
                                  ),
                                ),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(entry.body, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 8),
                            Text(
                              entry.isAdmin
                                  ? time
                                  : '${loc.notificationsSeverity} ${entry.severity} · $time',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SavedArticlesPage extends StatefulWidget {
  const SavedArticlesPage({
    super.key,
    required this.title,
    required this.articles,
    required this.isSaved,
    required this.onToggleSave,
    required this.language,
  });

  final String title;
  final List<SavedArticle> articles;
  final bool Function(NewsItem) isSaved;
  final Future<void> Function(NewsItem) onToggleSave;
  final String language;

  @override
  State<SavedArticlesPage> createState() => _SavedArticlesPageState();
}

class _SavedArticlesPageState extends State<SavedArticlesPage> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: widget.articles.isEmpty
          ? Center(child: Text(loc.savedArticlesEmpty))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.articles.length,
              itemBuilder: (context, index) {
                final item = widget.articles[index].item;
                return NewsCard(
                  item: item,
                  language: widget.language,
                  isSaved: widget.isSaved(item),
                  onToggleSave: (article) async {
                    await widget.onToggleSave(article);
                    if (mounted) setState(() {});
                  },
                );
              },
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onToggleTheme,
    required this.onShowLanguage,
    required this.onShowNotifications,
    required this.autoRenewEnabled,
    required this.blockedDomains,
    required this.onUnblockSource,
    required this.onAutoRenewChanged,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onShowLanguage;
  final VoidCallback onShowNotifications;
  final bool autoRenewEnabled;
  final Set<String> blockedDomains;
  final Future<void> Function(String) onUnblockSource;
  final Future<bool> Function(bool) onAutoRenewChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _autoRenewEnabled;
  late Set<String> _blockedDomains;

  @override
  void initState() {
    super.initState();
    _autoRenewEnabled = widget.autoRenewEnabled;
    _blockedDomains = {...widget.blockedDomains};
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRenewEnabled != widget.autoRenewEnabled) {
      _autoRenewEnabled = widget.autoRenewEnabled;
    }
    if (!setEquals(oldWidget.blockedDomains, widget.blockedDomains)) {
      _blockedDomains = {...widget.blockedDomains};
    }
  }

  Widget _buildSettingsSection(Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final blockedDomains = _blockedDomains.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(loc.settingsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 +
              MediaQuery.of(context).padding.bottom +
              kBottomNavigationBarHeight,
        ),
        children: [
          _buildSettingsSection(
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.toggleTheme),
                  trailing: const Icon(Icons.brightness_6_outlined),
                  onTap: widget.onToggleTheme,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.languageSettingsTitle),
                  trailing: const Icon(Icons.language),
                  onTap: widget.onShowLanguage,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.notificationSettingsTitle),
                  trailing: const Icon(Icons.notifications_active_outlined),
                  onTap: widget.onShowNotifications,
                ),
              ],
            ),
          ),
          _buildSettingsSection(
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoRenewEnabled,
              title: Text(loc.autoRenewTitle),
              subtitle: Text(loc.autoRenewSubtitle),
              onChanged: (value) async {
                setState(() {
                  _autoRenewEnabled = value;
                });
                final resolved = await widget.onAutoRenewChanged(value);
                if (!mounted) return;
                if (resolved != _autoRenewEnabled) {
                  setState(() {
                    _autoRenewEnabled = resolved;
                  });
                }
              },
            ),
          ),
          _buildSettingsSection(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.contactSupport),
              trailing: const Icon(Icons.support_agent_outlined),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SupportPage()),
                );
              },
            ),
          ),
          _buildSettingsSection(
            Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.privacyPolicyButton),
                  trailing: const Icon(Icons.policy_outlined),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc.accountDeletionTitle),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AccountDeletionPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildSettingsSection(
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(loc.developerEmailTitle),
              subtitle: const Text('anmt2805@gmail.com'),
              trailing: const Icon(Icons.email_outlined),
            ),
          ),
          _buildSettingsSection(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.blockedSourcesTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (blockedDomains.isEmpty)
                  Text(
                    loc.blockedSourcesEmpty,
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: blockedDomains.length,
                    itemBuilder: (context, index) {
                      final domain = blockedDomains[index];
                      final display = domain.startsWith('source:')
                          ? domain.substring('source:'.length).toUpperCase()
                          : domain;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(display),
                        trailing: TextButton(
                          onPressed: () async {
                            setState(() {
                              _blockedDomains.remove(domain);
                            });
                            await widget.onUnblockSource(domain);
                          },
                          child: Text(loc.unblockSource),
                        ),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const String _supportUrl = 'https://anmt2805.github.io/support/';
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('http://')) {
              final upgraded = request.url.replaceFirst('http://', 'https://');
              _webViewController.loadRequest(Uri.parse(upgraded));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_supportUrl));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.contactSupport)),
      body: WebViewWidget(controller: _webViewController),
    );
  }
}

class PrivacyPolicyContent extends StatefulWidget {
  const PrivacyPolicyContent({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
    this.textStyle,
  });

  final EdgeInsets padding;
  final TextStyle? textStyle;

  @override
  State<PrivacyPolicyContent> createState() => _PrivacyPolicyContentState();
}

class _PrivacyPolicyContentState extends State<PrivacyPolicyContent> {
  final ScrollController _scrollController = ScrollController();
  String _language = "";
  bool _isRtl = false;
  Future<String>? _policyFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_policyFuture == null || _language != language) {
      _language = language;
      _isRtl = _privacyPolicyIsRtl(language);
      _policyFuture = _loadPrivacyPolicyText(language);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<String>(
      future: _policyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snapshot.data ?? '';
        return Directionality(
          textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('privacy_policy_scroll'),
              controller: _scrollController,
              padding: widget.padding,
              child: SelectableText(
                text,
                style: widget.textStyle ?? theme.textTheme.bodyMedium,
              ),
            ),
          ),
        );
      },
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.privacyPolicyTitle)),
      body: const PrivacyPolicyContent(),
    );
  }
}

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({super.key});

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('http://')) {
              final upgraded = request.url.replaceFirst('http://', 'https://');
              _webViewController.loadRequest(Uri.parse(upgraded));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_accountDeletionUrl));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.accountDeletionTitle)),
      body: WebViewWidget(controller: _webViewController),
    );
  }
}

class NewsItem {
  const NewsItem({
    required this.title,
    required this.summary,
    required this.content,
    required this.url,
    required this.resolvedUrl,
    required this.sourceUrl,
    required this.source,
    required this.publishedAt,
    required this.severity,
    this.processing = false,
    this.processingStartedAt = '',
    this.processingEtaMinutes = 0,
  });

  final String title;
  final String summary;
  final String content;
  final String url;
  final String resolvedUrl;
  final String sourceUrl;
  final String source;
  final String publishedAt;
  final int severity;
  final bool processing;
  final String processingStartedAt;
  final int processingEtaMinutes;

  String get publishedAtLabel {
    if (publishedAt.isEmpty) return 'Unknown time';
    return publishedAt.split('T').first;
  }

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    final severityRaw = json['severity'];
    int parsedSeverity = 3;
    if (severityRaw is num) {
      parsedSeverity = severityRaw.toInt();
    } else {
      parsedSeverity = int.tryParse(severityRaw?.toString() ?? '') ?? 3;
    }
    final processingEtaRaw = json['processingEtaMinutes'];
    int parsedProcessingEtaMinutes = 0;
    if (processingEtaRaw is num) {
      parsedProcessingEtaMinutes = processingEtaRaw.toInt();
    } else {
      parsedProcessingEtaMinutes =
          int.tryParse(processingEtaRaw?.toString() ?? '') ?? 0;
    }
    return NewsItem(
      title: (json['title'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      resolvedUrl: (json['resolvedUrl'] ?? '').toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      publishedAt: (json['publishedAt'] ?? '').toString(),
      severity: parsedSeverity.clamp(1, 5),
      processing: json['processing'] == true,
      processingStartedAt: (json['processingStartedAt'] ?? '').toString(),
      processingEtaMinutes: max(0, parsedProcessingEtaMinutes),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'summary': summary,
    'content': content,
    'url': url,
    'resolvedUrl': resolvedUrl,
    'sourceUrl': sourceUrl,
    'source': source,
    'publishedAt': publishedAt,
    'severity': severity,
    'processing': processing,
    'processingStartedAt': processingStartedAt,
    'processingEtaMinutes': processingEtaMinutes,
  };
}

class _TokenPackTile extends StatelessWidget {
  const _TokenPackTile({
    required this.tokens,
    required this.product,
    this.onPressed,
  });

  final int tokens;
  final _StoreProduct product;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final displayPrice = _formatStorePrice(product.price, locale);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.tokenPackLabel(tokens),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              displayPrice,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              loc.perTokenPrice(
                _formatCurrency(
                  product.rawPrice / tokens,
                  product.currencyCode,
                  locale: locale,
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStorePrice(String value, String locale) {
    final raw = value.trim();
    if (raw.isEmpty) return raw;
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(raw)) return raw;
    if (raw.contains(',')) return raw;
    final parsed = num.tryParse(raw);
    if (parsed == null) return raw;
    return _formatNumber(parsed.toDouble(), locale);
  }

  String _formatCurrency(double value, String currencyCode, {String? locale}) {
    if (currencyCode.isEmpty) {
      return value.toStringAsFixed(2);
    }
    try {
      return NumberFormat.simpleCurrency(
        locale: locale,
        name: currencyCode,
      ).format(value);
    } catch (_) {
      return value.toStringAsFixed(2);
    }
  }

  String _formatNumber(double value, String locale) {
    final format = NumberFormat.decimalPattern(locale.isEmpty ? null : locale);
    if (value == value.roundToDouble()) {
      return format.format(value.toInt());
    }
    return format.format(value);
  }
}
