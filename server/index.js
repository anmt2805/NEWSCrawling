const express = require("express");
const cors = require("cors");
const Parser = require("rss-parser");
const { JSDOM } = require("jsdom");
const { Readability } = require("@mozilla/readability");
const { LRUCache } = require("lru-cache");
const rateLimit = require("express-rate-limit");
const stringSimilarity = require("string-similarity");
const { Firestore, FieldPath, FieldValue } = require("@google-cloud/firestore");
const crypto = require("crypto");
const fs = require("fs");
const admin = require("firebase-admin");
const { google } = require("googleapis");
const { OAuth2Client } = require("google-auth-library");
const { ProxyAgent } = require("undici");

const OPENAI_API_KEY = process.env.OPENAI_API_KEY || "";
const OPENAI_API_KEYS_RAW =
  process.env.OPENAI_API_KEYS ||
  [
    OPENAI_API_KEY,
    process.env.OPENAI_API_KEY_SECONDARY || ""
  ]
    .filter(Boolean)
    .join(",");
const OPENAI_API_KEYS = Array.from(
  new Set(
    OPENAI_API_KEYS_RAW.split(",")
      .map((value) => (value || "").trim())
      .filter(Boolean)
  )
);
const HAS_ANY_OPENAI_KEY =
  Boolean(OPENAI_API_KEY) || OPENAI_API_KEYS.length > 0;
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-4o-mini";
const OPENAI_TRANSLATE_MODEL =
  process.env.OPENAI_TRANSLATE_MODEL || OPENAI_MODEL;
const OPENAI_SUMMARY_MODEL =
  process.env.OPENAI_SUMMARY_MODEL || OPENAI_TRANSLATE_MODEL;
const OPENAI_SEVERITY_MODEL =
  process.env.OPENAI_SEVERITY_MODEL || "gpt-5-nano";
const PORT = process.env.PORT || 8080;
const FIRESTORE_ENABLED = true;
const FCM_TOPIC_CRITICAL = process.env.FCM_TOPIC_CRITICAL || "critical";
const BREAKING_KEYWORD = "breaking news";
const BREAKING_KEYWORDS = [
  "breaking",
  "속보",
  "速報",
  "dernières nouvelles",
  "última hora",
  "срочные новости",
  "أخبار عاجلة"
];
const PUSH_MAX_AGE_MINUTES = 30;
const PUSH_DEBUG = (process.env.PUSH_DEBUG || "").toLowerCase() === "1";
const AI_CACHE_DEBUG = (process.env.AI_CACHE_DEBUG || "").toLowerCase() === "1";
const ENABLE_INTERNAL_CRON =
  (process.env.ENABLE_INTERNAL_CRON || "").toLowerCase() === "1";
const INTERNAL_CRON_INTERVAL_MINUTES = Math.max(
  1,
  parseInt(process.env.INTERNAL_CRON_INTERVAL_MINUTES || "10", 10) || 10
);
const CRON_REFRESH_CONCURRENCY = Math.max(
  1,
  parseInt(process.env.CRON_REFRESH_CONCURRENCY || "4", 10) || 4
);
const PREFETCH_CONCURRENCY = Math.max(
  1,
  Math.min(3, CRON_REFRESH_CONCURRENCY)
);
const PREFETCH_MAX_TASKS = 12;
const ITEM_PROCESS_CONCURRENCY = Math.max(
  1,
  parseInt(process.env.ITEM_PROCESS_CONCURRENCY || "4", 10) || 4
);
const PUSH_CONCURRENCY = Math.max(
  1,
  parseInt(process.env.PUSH_CONCURRENCY || "6", 10) || 6
);
const OPENAI_CONCURRENCY = Math.max(
  1,
  parseInt(process.env.OPENAI_CONCURRENCY || "3", 10) || 3
);
const OPENAI_429_BASE_DELAY_MS = Math.max(
  1000,
  parseInt(process.env.OPENAI_429_BASE_DELAY_MS || "10000", 10) || 10000
);
const OPENAI_429_MAX_DELAY_MS = Math.max(
  OPENAI_429_BASE_DELAY_MS,
  parseInt(process.env.OPENAI_429_MAX_DELAY_MS || "60000", 10) || 60000
);
const TASK_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.TASK_TIMEOUT_MS || "60000", 10) || 60000
);
const RESOLVE_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.RESOLVE_TIMEOUT_MS || "60000", 10) || 60000
);
const TRANSLATE_TIMEOUT_MS = Math.max(
  1000,
  parseInt(process.env.TRANSLATE_TIMEOUT_MS || "60000", 10) || 60000
);
const RETRY_ATTEMPTS = Math.max(
  0,
  parseInt(process.env.TASK_RETRIES || "2", 10) || 2
);
const RETRY_BASE_DELAY_MS = Math.max(
  50,
  parseInt(process.env.TASK_RETRY_BASE_DELAY_MS || "500", 10) || 500
);
const RETRY_MAX_DELAY_MS = Math.max(
  100,
  parseInt(process.env.TASK_RETRY_MAX_DELAY_MS || "1500", 10) || 1500
);
const GOOGLE_NEWS_MIN_INTERVAL_MS = Math.max(
  0,
  parseInt(process.env.GOOGLE_NEWS_MIN_INTERVAL_MS || "2500", 10) || 2500
);
const GOOGLE_NEWS_BACKOFF_BASE_MS = Math.max(
  0,
  parseInt(process.env.GOOGLE_NEWS_BACKOFF_BASE_MS || "2000", 10) || 2000
);
const GOOGLE_NEWS_BACKOFF_MAX_MS = Math.max(
  GOOGLE_NEWS_BACKOFF_BASE_MS,
  parseInt(process.env.GOOGLE_NEWS_BACKOFF_MAX_MS || "60000", 10) || 60000
);
const GOOGLE_NEWS_BACKOFF_JITTER_MS = Math.max(
  0,
  parseInt(process.env.GOOGLE_NEWS_BACKOFF_JITTER_MS || "1000", 10) || 1000
);
const GOOGLE_NEWS_RSS_CACHE_TTL_MS = Math.max(
  60 * 1000,
  parseInt(process.env.GOOGLE_NEWS_RSS_CACHE_TTL_MS || "1800000", 10) ||
    1800000
);
const GOOGLE_NEWS_RSS_SKIP_THRESHOLD = Math.max(
  1,
  parseInt(process.env.GOOGLE_NEWS_RSS_SKIP_THRESHOLD || "2", 10) || 2
);
const GOOGLE_NEWS_RSS_SKIP_MS = Math.max(
  60 * 1000,
  parseInt(process.env.GOOGLE_NEWS_RSS_SKIP_MS || "600000", 10) || 600000
);
const GOOGLE_NEWS_PROXY_AUTO =
  (process.env.GOOGLE_NEWS_PROXY_AUTO || "1").toLowerCase() !== "0";
const GOOGLE_NEWS_PROXY_COOLDOWN_MS = Math.max(
  60 * 1000,
  parseInt(process.env.GOOGLE_NEWS_PROXY_COOLDOWN_MS || "3600000", 10) ||
    3600000
);
const DATAIMPULSE_PROXY_URL =
  process.env.DATAIMPULSE_PROXY_URL || process.env.PROXY_URL || "";
const GOOGLE_NEWS_PROXY_URL =
  process.env.GOOGLE_NEWS_PROXY_URL || DATAIMPULSE_PROXY_URL;
const PROXY_ALL =
  (process.env.PROXY_ALL || "").toLowerCase() === "1";
const PROXY_GOOGLE_NEWS_ONLY =
  (process.env.PROXY_GOOGLE_NEWS_ONLY || "1").toLowerCase() !== "0";
const GOOGLE_NEWS_MAX_FALLBACKS = Math.max(
  0,
  parseInt(process.env.GOOGLE_NEWS_MAX_FALLBACKS || "2", 10) || 2
);
const CRON_LOCK_TTL_MS = Math.max(
  60 * 1000,
  parseInt(process.env.CRON_LOCK_TTL_MS || "900000", 10) || 900000
);
const SOURCE_LISTS_PATH = "./source_lists.json";
const ANDROID_PUBLISHER_PACKAGE_NAME =
  process.env.ANDROID_PUBLISHER_PACKAGE_NAME || "";
const ANDROID_PUBLISHER_CREDENTIALS_JSON =
  process.env.ANDROID_PUBLISHER_CREDENTIALS_JSON || "";
const ANDROID_PUBLISHER_CREDENTIALS_PATH =
  process.env.ANDROID_PUBLISHER_CREDENTIALS_PATH || "";
const IAP_PRODUCT_MAP_RAW = process.env.IAP_PRODUCT_MAP || "";
const PLAY_IAP_PRODUCT_MAP_RAW = process.env.PLAY_IAP_PRODUCT_MAP || "";
const ONESTORE_IAP_PRODUCT_MAP_RAW =
  process.env.ONESTORE_IAP_PRODUCT_MAP || "";
const ONESTORE_CLIENT_ID = process.env.ONESTORE_CLIENT_ID || "";
const ONESTORE_CLIENT_SECRET = process.env.ONESTORE_CLIENT_SECRET || "";
const ONESTORE_API_BASE_URL = (
  process.env.ONESTORE_API_BASE_URL || "https://iap-apis.onestore.net"
)
  .trim()
  .replace(/\/+$/, "");
const ONESTORE_API_TIMEOUT_MS = Math.max(
  3000,
  parseInt(process.env.ONESTORE_API_TIMEOUT_MS || "10000", 10) || 10000
);
const ONESTORE_REFUND_RECONCILE_BATCH = Math.max(
  5,
  Math.min(
    200,
    parseInt(process.env.ONESTORE_REFUND_RECONCILE_BATCH || "25", 10) || 25
  )
);
const ONESTORE_REFUND_RECHECK_INTERVAL_MINUTES = Math.max(
  5,
  parseInt(process.env.ONESTORE_REFUND_RECHECK_INTERVAL_MINUTES || "120", 10) ||
    120
);
const ONESTORE_REFUND_MIN_PURCHASE_AGE_MINUTES = Math.max(
  1,
  parseInt(process.env.ONESTORE_REFUND_MIN_PURCHASE_AGE_MINUTES || "10", 10) ||
    10
);
const ONESTORE_REFUND_RECONCILE_MAX_AGE_DAYS = Math.max(
  1,
  parseInt(process.env.ONESTORE_REFUND_RECONCILE_MAX_AGE_DAYS || "90", 10) || 90
);
const RTDN_TOPIC = process.env.RTDN_TOPIC || "";
const RTDN_SUBSCRIPTION = process.env.RTDN_SUBSCRIPTION || "";
const TAB_MONTHLY_COST = Math.max(
  1,
  parseInt(process.env.TAB_MONTHLY_COST || "2", 10) || 2
);
const TAB_MAX_INDEX = Math.max(
  2,
  parseInt(process.env.TAB_MAX_INDEX || "6", 10) || 6
);
const TAB_COUNT = TAB_MAX_INDEX + 1;
const TAB_RENEW_WINDOW_MINUTES = Math.max(
  1,
  parseInt(process.env.TAB_RENEW_WINDOW_MINUTES || "60", 10) || 60
);
const ADMOB_SSV_KEYS_URL =
  process.env.ADMOB_SSV_KEYS_URL ||
  "https://www.gstatic.com/admob/reward/verifier-keys.json";
const ADMOB_ALLOWED_AD_UNITS_RAW = process.env.ADMOB_ALLOWED_AD_UNITS || "";
const ADMOB_REWARD_TTL_MINUTES = Math.max(
  1,
  parseInt(process.env.ADMOB_REWARD_TTL_MINUTES || "10", 10) || 10
);
const CACHE_DOC_TTL_MS = 1 * 24 * 60 * 60 * 1000;
const AUTO_RENEW_WINDOW_MS = 2 * 60 * 60 * 1000;
const AUTO_RENEW_ATTEMPT_WINDOW_MS = 59 * 60 * 1000;
const AUTO_RENEW_RETRY_INTERVAL_MS = 10 * 60 * 1000;
const USER_FCM_TOKEN_TTL_MS = 60 * 24 * 60 * 60 * 1000;
const ADMIN_PUSH_BATCH_SIZE = Math.max(
  50,
  Math.min(
    500,
    parseInt(process.env.ADMIN_PUSH_BATCH_SIZE || "500", 10) || 500
  )
);
const ADMIN_PUSH_MAX_TITLE_LENGTH = Math.max(
  20,
  parseInt(process.env.ADMIN_PUSH_MAX_TITLE_LENGTH || "120", 10) || 120
);
const ADMIN_PUSH_MAX_BODY_LENGTH = Math.max(
  40,
  parseInt(process.env.ADMIN_PUSH_MAX_BODY_LENGTH || "600", 10) || 600
);
const ADMIN_PUSH_MAX_DATA_KEYS = Math.max(
  0,
  Math.min(20, parseInt(process.env.ADMIN_PUSH_MAX_DATA_KEYS || "10", 10) || 10)
);
const ADMIN_PUSH_MAX_DATA_VALUE_LENGTH = Math.max(
  20,
  parseInt(process.env.ADMIN_PUSH_MAX_DATA_VALUE_LENGTH || "500", 10) || 500
);
const ADMIN_PUSH_SUPPORTED_LANGS = new Set(["en", "ko", "ja", "fr", "es", "ru", "ar"]);
const AUTO_RENEW_FAILURE_NOTIFY_COOLDOWN_MS = 6 * 60 * 60 * 1000;
const USER_MAINTENANCE_BATCH_SIZE = 200;
const MAX_KEYWORD_ALIASES = 6;
const CLOUD_TASKS_QUEUE = process.env.CLOUD_TASKS_QUEUE || "news-refresh-queue";
const CLOUD_TASKS_LOCATION =
  process.env.CLOUD_TASKS_LOCATION || "asia-northeast3";
const CLOUD_TASKS_SERVICE_ACCOUNT =
  process.env.CLOUD_TASKS_SERVICE_ACCOUNT || "";
const CLOUD_TASKS_DISPATCH_DEADLINE_SEC = Math.max(
  0,
  parseInt(process.env.CLOUD_TASKS_DISPATCH_DEADLINE_SEC || "0", 10) || 0
);
const CRAWL_SKIP_ONCE_COLLECTION =
  process.env.CRAWL_SKIP_ONCE_COLLECTION || "crawl_skip_once";
const CRAWL_SKIP_ONCE_TTL_MS = Math.max(
  5 * 60 * 1000,
  parseInt(process.env.CRAWL_SKIP_ONCE_TTL_MS || "21600000", 10) || 21600000
);
const FASTMODE_FALLBACK_COLLECTION =
  process.env.FASTMODE_FALLBACK_COLLECTION || "fastmode_fallback";
const FASTMODE_FALLBACK_COOLDOWN_MS = Math.max(
  60 * 1000,
  parseInt(process.env.FASTMODE_FALLBACK_COOLDOWN_MS || "300000", 10) || 300000
);
const PROCESSING_ETA_DEFAULT_MINUTES = Math.max(
  1,
  parseInt(process.env.PROCESSING_ETA_DEFAULT_MINUTES || "7", 10) || 7
);
const PROCESSING_ETA_MIN_MINUTES = Math.max(
  1,
  parseInt(process.env.PROCESSING_ETA_MIN_MINUTES || "2", 10) || 2
);
const PROCESSING_ETA_MAX_MINUTES = Math.max(
  PROCESSING_ETA_MIN_MINUTES,
  parseInt(process.env.PROCESSING_ETA_MAX_MINUTES || "20", 10) || 20
);
const PROCESSING_OBSERVED_MIN_MS = Math.max(
  1000,
  parseInt(process.env.PROCESSING_OBSERVED_MIN_MS || "30000", 10) || 30000
);
const PROCESSING_OBSERVED_MAX_MS = Math.max(
  PROCESSING_OBSERVED_MIN_MS,
  parseInt(process.env.PROCESSING_OBSERVED_MAX_MS || "3600000", 10) || 3600000
);
const PROCESSING_DURATION_SMOOTHING = Math.min(
  0.9,
  Math.max(
    0,
    Number.parseFloat(process.env.PROCESSING_DURATION_SMOOTHING || "0.35") ||
      0.35
  )
);
const PROCESSING_RECOVERY_TRIGGER_MS = Math.max(
  60 * 1000,
  parseInt(process.env.PROCESSING_RECOVERY_TRIGGER_MS || "600000", 10) ||
    600000
);
const PROCESSING_RECOVERY_COOLDOWN_MS = Math.max(
  60 * 1000,
  parseInt(process.env.PROCESSING_RECOVERY_COOLDOWN_MS || "180000", 10) ||
    180000
);
const SERVICE_URL = process.env.SERVICE_URL || "";
const RTDN_PUSH_AUDIENCE =
  process.env.RTDN_PUSH_AUDIENCE ||
  (SERVICE_URL ? `${SERVICE_URL.replace(/\/+$/, "")}/iap/rtdn` : "");
const RTDN_PUSH_SERVICE_ACCOUNT =
  (process.env.RTDN_PUSH_SERVICE_ACCOUNT || "")
    .trim()
    .toLowerCase();
const ALLOW_UNAUTH_RTDN =
  (process.env.ALLOW_UNAUTH_RTDN || "").toLowerCase() === "1";
const GOOGLE_OIDC_ISSUERS = new Set([
  "https://accounts.google.com",
  "accounts.google.com"
]);
const rtdnOidcClient = new OAuth2Client();
const ENABLE_GDELT = (process.env.ENABLE_GDELT || "").toLowerCase() === "1";
const GDELT_MAX_RECORDS = Math.max(
  5,
  Math.min(100, parseInt(process.env.GDELT_MAX_RECORDS || "30", 10) || 30)
);
const GDELT_TIMESPAN = process.env.GDELT_TIMESPAN || "1d";
const ENABLE_NAVER_NEWS =
  (process.env.ENABLE_NAVER_NEWS || "").toLowerCase() === "1";
const NAVER_CLIENT_ID = process.env.NAVER_CLIENT_ID || "";
const NAVER_CLIENT_SECRET = process.env.NAVER_CLIENT_SECRET || "";
const NAVER_NEWS_DISPLAY = Math.max(
  5,
  Math.min(100, parseInt(process.env.NAVER_NEWS_DISPLAY || "30", 10) || 30)
);
let naverMissingKeyWarned = false;
const ADMIN_UIDS = new Set(
  (process.env.ADMIN_UIDS || "")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean)
);
const ADMIN_EMAILS = new Set(
  (process.env.ADMIN_EMAILS || "")
    .split(",")
    .map((value) => value.trim().toLowerCase())
    .filter(Boolean)
);
const CRAWL_SOURCES_COLLECTION = "admin_config";
const CRAWL_SOURCES_DOC_ID = "crawl_sources";
const CRAWL_SOURCES_CACHE_TTL_MS = 30 * 1000;
const DEFAULT_CRAWL_SOURCES = {
  googleNews: true,
  naver: true,
  gdelt: true
};
const MAINTENANCE_DOC_ID = "maintenance";
const MAINTENANCE_CACHE_TTL_MS = 15 * 1000;
const DEFAULT_MAINTENANCE = {
  enabled: false,
  startAt: null,
  endAt: null,
  storeUrlAndroid: "",
  storeUrlIos: ""
};
let crawlSourcesCache = {
  value: DEFAULT_CRAWL_SOURCES,
  fetchedAt: 0
};
let maintenanceCache = {
  value: DEFAULT_MAINTENANCE,
  fetchedAt: 0
};

const RSS_REQUEST_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  Accept: "application/rss+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Encoding": "gzip, br"
};
const HTML_REQUEST_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
  Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Encoding": "gzip, br"
};
const parser = new Parser({
  headers: RSS_REQUEST_HEADERS
});
const app = express();
// Cloud Run runs behind a known proxy hop. Use a bounded trust proxy value so
// express-rate-limit can safely derive client IP without permissive trust.
app.set("trust proxy", 1);
const CORS_ALLOW_ORIGINS = (process.env.CORS_ALLOW_ORIGINS || "")
  .split(",")
  .map((value) => value.trim())
  .filter(Boolean);
if (CORS_ALLOW_ORIGINS.length) {
  app.use(
    cors({
      origin: CORS_ALLOW_ORIGINS
    })
  );
}
app.use(express.json({ limit: "1mb" }));

const API_RATE_LIMIT_PER_MIN = Math.max(
  100,
  parseInt(process.env.API_RATE_LIMIT_PER_MIN || "300", 10) || 300
);
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: API_RATE_LIMIT_PER_MIN,
  validate: {
    trustProxy: false
  },
  skip: (req) => {
    // '/cron/'으로 시작하는 경로는 스케줄러 작업이므로 제한을 적용하지 않습니다.
    return req.path.startsWith('/cron/');
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res, _next, options) => {
    const resetTime = req.rateLimit?.resetTime;
    const retryAfterMs = resetTime
      ? Math.max(0, resetTime.getTime() - Date.now())
      : options.windowMs;
    const retryAfterSec = Math.max(1, Math.ceil(retryAfterMs / 1000));
    res.set("Retry-After", retryAfterSec.toString());
    res.status(429).json({ error: "rate_limited", retryAfter: retryAfterSec });
  }
});

app.use("/news", apiLimiter);
app.use("/article", apiLimiter);
app.use("/cache/prefetch", apiLimiter);
app.use("/breaking/activate", apiLimiter);

app.get("/time", (req, res) => {
  res.json({ ok: true, serverTimeMs: Date.now() });
});

app.get("/app/status", async (req, res) => {
  try {
    const nowMs = Date.now();
    const config = await getMaintenanceConfig();
    const maintenance = computeMaintenanceStatus(config, nowMs);
    return res.json({ ok: true, serverTimeMs: nowMs, maintenance });
  } catch (error) {
    console.error("[AppStatus] failed", error?.message || error);
    return res
      .status(500)
      .json({ ok: false, error: "status_failed", serverTimeMs: Date.now() });
  }
});

app.get("/iap/products", (req, res) => {
  const requestedStoreType = normalizeIapStoreType(
    req.query?.storeType || req.query?.store || ""
  );
  const productMap = getIapProductMapForStore(requestedStoreType);
  const entries = Object.entries(productMap).map(([productId, tokens]) => ({
    productId,
    tokens
  }));
  if (entries.length === 0) {
    return res.status(503).json({
      ok: false,
      error: "iap_not_configured",
      storeType: requestedStoreType
    });
  }
  return res.json({
    ok: true,
    storeType: requestedStoreType,
    products: entries,
    serverTimeMs: Date.now()
  });
});

app.post("/iap/verify", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const { productId, purchaseToken, platform } = req.body || {};
  const storeType = normalizeIapStoreType(req.body?.storeType || "");
  const marketCode = normalizeOneStoreMarketCode(
    req.body?.marketCode || req.header("x-market-code") || ""
  );
  if (!productId || !purchaseToken) {
    return res.status(400).json({ ok: false, error: "missing_params" });
  }
  if (platform && platform !== "android") {
    return res.status(400).json({ ok: false, error: "unsupported_platform" });
  }
  if (storeType === "play" && !ANDROID_PUBLISHER_PACKAGE_NAME) {
    return res
      .status(503)
      .json({ ok: false, error: "android_package_missing", storeType });
  }
  if (
    storeType === "onestore" &&
    (!ONESTORE_CLIENT_ID || !ONESTORE_CLIENT_SECRET)
  ) {
    return res
      .status(503)
      .json({ ok: false, error: "onestore_not_configured", storeType });
  }
  const tokens = resolveIapTokens(productId, storeType);
  if (!tokens) {
    return res
      .status(404)
      .json({ ok: false, error: "unknown_product", storeType });
  }

  let verifyResult;
  try {
    if (storeType === "onestore") {
      verifyResult = await verifyOneStoreProductPurchase({
        productId,
        purchaseToken,
        marketCode
      });
    } else {
      verifyResult = await verifyAndroidProductPurchase({
        productId,
        purchaseToken
      });
    }
  } catch (error) {
    console.error("IAP purchase verify failed:", error.message || error);
    return res.status(502).json({ ok: false, error: "verify_failed", storeType });
  }
  if (!verifyResult.ok) {
    const detailText =
      verifyResult.data == null
        ? ""
        : (() => {
            try {
              return JSON.stringify(verifyResult.data).slice(0, 2000);
            } catch (_) {
              return String(verifyResult.data).slice(0, 2000);
            }
          })();
    console.warn("[IAP] verify rejected", {
      storeType,
      productId,
      purchaseTokenPrefix: String(purchaseToken || "").slice(0, 12),
      error: verifyResult.error || "invalid_purchase",
      detail: detailText || null
    });
    return res.status(400).json({
      ok: false,
      error: verifyResult.error || "invalid_purchase",
      storeType
    });
  }

  const data = verifyResult.data || {};
  const shouldConsume =
    storeType === "play" && Number.parseInt(data.consumptionState, 10) === 0;

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const now = new Date();
  const entry = {
    timestamp: now.toISOString(),
    amount: tokens,
    type: "purchase",
    description: `iap:${storeType}:${productId}`
  };
  const userRef = db.collection("users").doc(user.uid);
  const purchaseRef = db
    .collection("iapPurchases")
    .doc(buildIapPurchaseDocId({ storeType, purchaseToken }));

  let alreadyProcessed = false;
  let blockedReason = "";
  let newBalance = null;
  let consumePending = shouldConsume;
  try {
    await db.runTransaction(async (tx) => {
      const purchaseSnap = await tx.get(purchaseRef);
      if (purchaseSnap.exists) {
        alreadyProcessed = true;
        const existing = purchaseSnap.data() || {};
        if (existing.voided === true || existing.refundProcessed === true) {
          blockedReason = "voided";
        } else if (existing.canceled === true) {
          blockedReason = "canceled";
        }
        return;
      }
      const userSnap = await tx.get(userRef);
      const userData = userSnap.data() || {};
      const currentBalance = Number.parseInt(userData.tokenBalance, 10) || 0;
      const ledger = Array.isArray(userData.tokenLedger)
        ? userData.tokenLedger.slice()
        : [];
      ledger.unshift(entry);
      newBalance = currentBalance + tokens;
      tx.set(
        userRef,
        {
          tokenBalance: newBalance,
          tokenLedger: ledger,
          updatedAt: now.toISOString()
        },
        { merge: true }
      );
      tx.create(purchaseRef, {
        uid: user.uid,
        productId,
        storeType,
        tokens,
        purchaseToken: String(purchaseToken),
        orderId: data.orderId || "",
        purchaseTimeMillis: data.purchaseTimeMillis || "",
        purchaseState: data.purchaseState,
        consumptionState: data.consumptionState,
        acknowledgementState: data.acknowledgementState,
        marketCode: marketCode || "",
        verificationSource: storeType,
        createdAt: now.toISOString(),
        consumePending: shouldConsume
      });
    });
  } catch (error) {
    console.error("IAP transaction failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "grant_failed" });
  }

  if (alreadyProcessed) {
    if (blockedReason) {
      return res
        .status(400)
        .json({ ok: false, error: `purchase_${blockedReason}`, storeType });
    }
    if (shouldConsume) {
      try {
        await consumeAndroidPurchase({ productId, purchaseToken });
        await purchaseRef.set(
          {
            consumePending: false,
            consumedAt: new Date().toISOString()
          },
          { merge: true }
        );
      } catch (error) {
        console.error(
          "Android purchase consume retry failed:",
          error.message || error
        );
      }
    }
    try {
      const currentSnap = await userRef.get();
      const currentData = currentSnap.data() || {};
      const currentBalance = Number.parseInt(currentData.tokenBalance, 10) || 0;
      return res.json({
        ok: true,
        alreadyProcessed: true,
        tokenBalance: currentBalance,
        storeType,
        serverTimeMs: Date.now()
      });
    } catch (error) {
      console.error("IAP balance read failed:", error.message || error);
      return res.json({
        ok: true,
        alreadyProcessed: true,
        storeType,
        serverTimeMs: Date.now()
      });
    }
  }

  if (shouldConsume) {
    try {
      await consumeAndroidPurchase({ productId, purchaseToken });
      consumePending = false;
      await purchaseRef.set(
        {
          consumePending: false,
          consumedAt: new Date().toISOString()
        },
        { merge: true }
      );
    } catch (error) {
      console.error("Android purchase consume failed:", error.message || error);
      await purchaseRef.set(
        {
          consumePending: true,
          consumeError: String(error?.message || error || "consume_failed")
        },
        { merge: true }
      );
    }
  }

  return res.json({
    ok: true,
    storeType,
    tokenBalance: newBalance,
    tokenLedgerEntry: entry,
    consumePending,
    serverTimeMs: Date.now()
  });
});

function extractBearerToken(req) {
  const authHeader = req.header("Authorization") || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match ? String(match[1]).trim() : "";
}

async function verifyRtdnPushRequest(req) {
  if (ALLOW_UNAUTH_RTDN) {
    return { ok: true, source: "unauth_allowed" };
  }
  if (!RTDN_PUSH_AUDIENCE) {
    return {
      ok: false,
      status: 500,
      error: "missing_rtdn_push_audience"
    };
  }

  const token = extractBearerToken(req);
  if (!token) {
    return { ok: false, status: 401, error: "missing_authorization" };
  }

  let payload = null;
  try {
    const ticket = await rtdnOidcClient.verifyIdToken({
      idToken: token,
      audience: RTDN_PUSH_AUDIENCE
    });
    payload = ticket.getPayload() || null;
  } catch (error) {
    console.warn("[RTDN] OIDC verify failed:", error?.message || error);
    return { ok: false, status: 401, error: "invalid_oidc_token" };
  }

  const issuer = String(payload?.iss || "");
  if (!GOOGLE_OIDC_ISSUERS.has(issuer)) {
    return {
      ok: false,
      status: 403,
      error: "invalid_oidc_issuer"
    };
  }
  const tokenEmail = String(payload?.email || "")
    .trim()
    .toLowerCase();
  if (RTDN_PUSH_SERVICE_ACCOUNT && tokenEmail !== RTDN_PUSH_SERVICE_ACCOUNT) {
    return {
      ok: false,
      status: 403,
      error: "invalid_oidc_service_account"
    };
  }
  if (payload?.email_verified !== undefined && !payload.email_verified) {
    return {
      ok: false,
      status: 403,
      error: "oidc_email_not_verified"
    };
  }

  return { ok: true, source: "oidc", payload };
}

app.post("/iap/rtdn", async (req, res) => {
  const authResult = await verifyRtdnPushRequest(req);
  if (!authResult.ok) {
    return res
      .status(authResult.status || 403)
      .json({ ok: false, error: authResult.error || "unauthorized" });
  }

  const topicHeader = req.header("X-Goog-Topic") || "";
  if (RTDN_TOPIC && topicHeader && topicHeader !== RTDN_TOPIC) {
    return res.status(403).json({ ok: false, error: "invalid_topic" });
  }
  const subscription = req.body?.subscription
    ? String(req.body.subscription)
    : "";
  if (RTDN_SUBSCRIPTION && subscription !== RTDN_SUBSCRIPTION) {
    return res.status(403).json({ ok: false, error: "invalid_subscription" });
  }
  const message = req.body?.message;
  if (!message?.data) {
    return res.status(400).json({ ok: false, error: "missing_message" });
  }
  let payload = null;
  try {
    payload = JSON.parse(
      Buffer.from(message.data, "base64").toString("utf8")
    );
  } catch (error) {
    console.error("RTDN payload parse failed:", error.message || error);
    return res.status(400).json({ ok: false, error: "invalid_payload" });
  }

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const now = new Date();
  const messageId = message.messageId || crypto.randomUUID();
  try {
    await db.collection("iapNotifications").doc(String(messageId)).set(
      {
        payload,
        attributes: message.attributes || {},
        subscription: req.body?.subscription || "",
        receivedAt: now.toISOString()
      },
      { merge: true }
    );
  } catch (error) {
    console.error("RTDN log write failed:", error.message || error);
  }

  const oneTime = payload?.oneTimeProductNotification;
  const notificationType = Number.parseInt(oneTime?.notificationType, 10);
  const purchaseToken = oneTime?.purchaseToken
    ? String(oneTime.purchaseToken)
    : "";
  if (notificationType === 2 && purchaseToken) {
    // OneTimeProductNotification notificationType=2 는 "환불"이 아니라
    // "보류(pending) 구매 취소(ONE_TIME_PRODUCT_CANCELED)" 의미임.
    // 여기서 revoked/refund 처리하면 정상 구매도 토큰이 다시 빠지는 버그 발생.
    const purchaseRef =
      (await resolveIapPurchaseRefByToken({
        db,
        storeType: "play",
        purchaseToken
      })) || db.collection("iapPurchases").doc(purchaseToken);
    await purchaseRef.set(
      {
        rtdnNotificationType: 2,
        canceled: true,
        canceledAt: now.toISOString()
      },
      { merge: true }
    );
    return res.json({ ok: true });
  }

  const voided = payload?.voidedPurchaseNotification;
  const voidedToken = voided?.purchaseToken
    ? String(voided.purchaseToken)
    : "";
  if (voidedToken) {
    const voidedProductType = Number.parseInt(voided?.productType, 10);
    if (
      Number.isFinite(voidedProductType) &&
      voidedProductType !== 2
    ) {
      return res.json({ ok: true });
    }
    const voidedRefundType = Number.parseInt(voided?.refundType, 10);
    const voidedOrderId = voided?.orderId ? String(voided.orderId) : "";
    try {
      const result = await applyIapRefundFromVoidedNotification({
        purchaseToken: voidedToken,
        orderId: voidedOrderId,
        refundType: Number.isFinite(voidedRefundType) ? voidedRefundType : null,
        productType: Number.isFinite(voidedProductType)
          ? voidedProductType
          : null,
        storeType: "play"
      });
      if (!result.ok && result.error !== "purchase_not_found") {
        console.warn("[RTDN] voided refund failed:", result.error);
      }
    } catch (error) {
      console.error(
        "[RTDN] voided refund exception:",
        error?.message || error
      );
    }
    return res.json({ ok: true });
  }

  return res.json({ ok: true });
});

app.post("/tabs/purchase", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const { tabIndex } = req.body || {};
  const index = Number.parseInt(tabIndex, 10);
  if (!Number.isFinite(index) || index < 2) {
    return res.status(400).json({ ok: false, error: "invalid_tab_index" });
  }
  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const now = new Date();
  const userRef = db.collection("users").doc(user.uid);
  let newBalance = null;
  let newExpiry = null;
  let snapshotData = null;
  let entry = null;
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const data = snap.data() || {};
      const currentBalance = Number.parseInt(data.tokenBalance, 10) || 0;
      if (currentBalance < TAB_MONTHLY_COST) {
        throw new Error("insufficient_tokens");
      }
      const expiryRaw = data.tabExpiry || {};
      const expiryKey = String(index);
      const existingExpiry = expiryRaw[expiryKey];
      let baseTime = now;
      if (existingExpiry) {
        const parsedIso = parseDateIso(existingExpiry);
        if (parsedIso) {
          const parsed = new Date(parsedIso);
          if (!Number.isNaN(parsed.getTime()) && parsed > now) {
            baseTime = parsed;
          }
        }
      }
      const expiryDate = new Date(
        baseTime.getTime() + 30 * 24 * 60 * 60 * 1000
      );
      const ledger = Array.isArray(data.tokenLedger)
        ? data.tokenLedger.slice()
        : [];
      entry = {
        timestamp: now.toISOString(),
        amount: -TAB_MONTHLY_COST,
        type: "spend",
        description: `tab:${index}`
      };
      ledger.unshift(entry);
      newBalance = currentBalance - TAB_MONTHLY_COST;
      newExpiry = expiryDate.toISOString();
      tx.set(
        userRef,
        {
          tokenBalance: newBalance,
          tokenLedger: ledger,
          tabExpiry: {
            ...expiryRaw,
            [expiryKey]: newExpiry
          },
          updatedAt: now.toISOString()
        },
        { merge: true }
      );
    });
    try {
      const snap = await userRef.get();
      if (snap.exists) {
        snapshotData = snap.data() || null;
      }
    } catch (_) {}
  } catch (error) {
    if (error.message === "insufficient_tokens") {
      return res.status(400).json({ ok: false, error: "insufficient_tokens" });
    }
    console.error("Tab purchase failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "purchase_failed" });
  }
  return res.json({
    ok: true,
    tokenBalance:
      (snapshotData && Number.parseInt(snapshotData.tokenBalance, 10)) ||
      newBalance,
    tokenLedgerEntry: entry,
    tabExpiry: snapshotData?.tabExpiry || {
      [String(index)]: newExpiry
    },
    serverTimeMs: Date.now()
  });
});

app.post("/tabs/auto-renew", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const now = new Date();
  const userRef = db.collection("users").doc(user.uid);
  const renewedEntries = [];
  let newBalance = null;
  let updatedExpiry = null;
  let currentBalance = null;
  let currentExpiry = null;
  let autoRenewDisabled = false;
  let renewedTabs = 0;
  const renewedTabIndexes = [];
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const data = snap.data() || {};
      if (data.autoRenewEnabled !== true) {
        currentBalance = Number.parseInt(data.tokenBalance, 10) || 0;
        currentExpiry = { ...(data.tabExpiry || {}) };
        return;
      }
      let balance = Number.parseInt(data.tokenBalance, 10) || 0;
      const expiryRaw = data.tabExpiry || {};
      const ledger = Array.isArray(data.tokenLedger)
        ? data.tokenLedger.slice()
        : [];
      currentBalance = balance;
      currentExpiry = { ...expiryRaw };
      const thresholdMs = TAB_RENEW_WINDOW_MINUTES * 60 * 1000;
      let needsPayment = false;
      let changed = false;
      const nextExpiry = { ...expiryRaw };
      const dueTabs = [];
      for (let index = 2; index <= TAB_MAX_INDEX; index += 1) {
        const expiryValue = nextExpiry[String(index)];
        if (!expiryValue) continue;
        const expiryIso = parseDateIso(expiryValue);
        if (!expiryIso) continue;
        const expiry = new Date(expiryIso);
        if (Number.isNaN(expiry.getTime())) continue;
        const diffMs = expiry.getTime() - now.getTime();
        if (diffMs < 0) continue;
        if (diffMs > thresholdMs) continue;
        needsPayment = true;
        dueTabs.push({ index, expiry });
      }
      dueTabs.sort((a, b) => a.expiry.getTime() - b.expiry.getTime());
      for (const item of dueTabs) {
        if (balance < TAB_MONTHLY_COST) continue;
        balance -= TAB_MONTHLY_COST;
        const baseTime = item.expiry > now ? item.expiry : now;
        const extended = new Date(
          baseTime.getTime() + 30 * 24 * 60 * 60 * 1000
        );
        nextExpiry[String(item.index)] = extended.toISOString();
        const entry = {
          timestamp: now.toISOString(),
          amount: -TAB_MONTHLY_COST,
          type: "auto_renew",
          description: `tab:${item.index}`
        };
        ledger.unshift(entry);
        renewedEntries.push(entry);
        renewedTabs += 1;
        renewedTabIndexes.push(item.index);
        changed = true;
      }

      if (needsPayment && renewedTabs === 0 && balance < TAB_MONTHLY_COST) {
        autoRenewDisabled = true;
        newBalance = balance;
        updatedExpiry = currentExpiry;
        return;
      }

      if (!changed) {
        newBalance = balance;
        updatedExpiry = currentExpiry;
        return;
      }
      newBalance = balance;
      updatedExpiry = nextExpiry;
      tx.set(
        userRef,
        {
          tokenBalance: newBalance,
          tokenLedger: ledger,
          tabExpiry: nextExpiry,
          updatedAt: now.toISOString()
        },
        { merge: true }
      );
    });
  } catch (error) {
    console.error("Auto renew failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "auto_renew_failed" });
  }

  const responsePayload = {
    ok: true,
    tokenBalance: newBalance ?? currentBalance,
    tabExpiry: updatedExpiry ?? currentExpiry,
    tokenLedgerEntries: renewedEntries,
    renewedTabs,
    renewedTabIndexes,
    autoRenewDisabled,
    serverTimeMs: Date.now()
  };
  if (renewedTabs > 0) {
    sendAutoRenewPushToUser({
      uid: user.uid,
      success: true,
      renewedTabs,
      renewedTabIndexes
    }).catch((error) => {
      console.error("Auto renew push failed:", error?.message || error);
    });
  } else if (autoRenewDisabled) {
    sendAutoRenewPushToUser({
      uid: user.uid,
      success: false
    }).catch((error) => {
      console.error("Auto renew push failed:", error?.message || error);
    });
  }
  return res.json(responsePayload);
});

app.post("/users/state", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const {
    tabKeywords,
    tabRegions,
    canonicalKeywords,
    notificationPrefs,
    autoRenewEnabled,
    language,
    lang
  } = req.body || {};

  if (!Array.isArray(tabKeywords) || !Array.isArray(tabRegions)) {
    return res.status(400).json({ ok: false, error: "invalid_payload" });
  }

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }

  const safeKeywords = normalizeStringArray(tabKeywords, TAB_COUNT, "");
  const safeRegions = normalizeRegionArray(tabRegions, TAB_COUNT);
  const safeCanonical = normalizeCanonicalKeywords(canonicalKeywords);
  const safePrefs = normalizeNotificationPrefs(notificationPrefs);
  const now = new Date();
  const updatePayload = {
    tabKeywords: safeKeywords,
    tabRegions: safeRegions,
    canonicalKeywords: safeCanonical,
    updatedAt: now.toISOString(),
    lastActiveAt: now.toISOString()
  };
  if (safePrefs) {
    updatePayload.notificationPrefs = safePrefs;
  }
  if (typeof autoRenewEnabled === "boolean") {
    updatePayload.autoRenewEnabled = autoRenewEnabled;
  }
  const languageValue = normalizeLangCode(language || lang || "", "");
  if (languageValue) {
    updatePayload.language = languageValue;
  }

  try {
    await db.collection("users").doc(user.uid).set(updatePayload, { merge: true });
  } catch (error) {
    console.error("User state update failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "update_failed" });
  }

  return res.json({ ok: true, serverTimeMs: now.getTime() });
});

app.post("/users/heartbeat", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const nowIso = new Date().toISOString();
  const languageValue = normalizeLangCode(
    req.body?.language || req.body?.lang || "",
    ""
  );
  const payload = {
    lastActiveAt: nowIso
  };
  if (languageValue) {
    payload.language = languageValue;
  }
  try {
    await db.collection("users").doc(user.uid).set(payload, { merge: true });
    return res.json({ ok: true, serverTimeMs: Date.now() });
  } catch (error) {
    console.error("User heartbeat failed:", error?.message || error);
    return res.status(500).json({ ok: false, error: "heartbeat_failed" });
  }
});

app.post("/users/guest", async (req, res) => {
  try {
    const token = String(req.body?.token || "").trim();
    if (!token) {
      return res.status(400).json({ ok: false, error: "missing_token" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const user = await getOptionalUser(req);
    const linkedUid = user?.uid || "";
    const languageValue = normalizeLangCode(req.body?.language || "", "");
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
    const now = new Date().toISOString();
    const payload = {
      tokenHash,
      lastSeenAt: now
    };
    if (languageValue) {
      payload.language = languageValue;
    }
    if (linkedUid) {
      payload.linkedUid = linkedUid;
      payload.linkedAt = now;
    }
    await db
      .collection("guest_users")
      .doc(tokenHash)
      .set(payload, { merge: true });
    await upsertUserFcmToken(db, linkedUid, token, languageValue);
    return res.json({ ok: true, linked: Boolean(linkedUid), serverTimeMs: Date.now() });
  } catch (error) {
    console.error("[Guest] update failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "guest_update_failed" });
  }
});

app.post("/users/guest_heartbeat", async (req, res) => {
  try {
    const token = String(req.body?.token || "").trim();
    if (!token) {
      return res.status(400).json({ ok: false, error: "missing_token" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const languageValue = normalizeLangCode(req.body?.language || "", "");
    const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
    const nowIso = new Date().toISOString();
    const payload = {
      tokenHash,
      lastSeenAt: nowIso
    };
    if (languageValue) {
      payload.language = languageValue;
    }
    await db
      .collection("guest_users")
      .doc(tokenHash)
      .set(payload, { merge: true });
    await upsertUserFcmToken(db, "", token, languageValue);
    return res.json({ ok: true, serverTimeMs: Date.now() });
  } catch (error) {
    console.error("[GuestHeartbeat] update failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "guest_heartbeat_failed" });
  }
});

app.get("/admob/ssv", async (req, res) => {
  const rawQueryIndex = req.originalUrl.indexOf("?");
  if (rawQueryIndex === -1) {
    return res.status(200).json({ ok: false, error: "missing_query" });
  }
  const customDataParam = (req.query.custom_data || "").toString();
  if (!customDataParam) {
    return res.status(200).json({ ok: true, test: true });
  }
  const testAdUnit = (req.query.ad_unit || "").toString();
  const testTransaction = (req.query.transaction_id || "").toString();
  // AdMob console verification uses dummy values without custom_data/signature.
  if (testAdUnit === "1234567890" && testTransaction === "123456789") {
    return res.status(200).json({ ok: true, test: true });
  }
  const queryString = req.originalUrl.substring(rawQueryIndex + 1);
  let verification;
  try {
    verification = await verifyRewardedSsvSignature({ queryString });
  } catch (error) {
    console.error("AdMob SSV verification error:", error.message || error);
    return res.status(400).json({ ok: false, error: "invalid_signature" });
  }
  if (!verification.ok) {
    return res.status(400).json({ ok: false, error: "invalid_signature" });
  }

  const params = new URLSearchParams(queryString);
  const userId = params.get("user_id") || "";
  const transactionId = params.get("transaction_id") || "";
  const adUnit = params.get("ad_unit") || "";
  const rewardItem = params.get("reward_item") || "";
  const rewardAmount = params.get("reward_amount") || "";
  const customData = params.get("custom_data") || "";

  if (!transactionId || !customData) {
    return res.status(400).json({ ok: false, error: "missing_reward_id" });
  }
  if (ADMOB_ALLOWED_AD_UNITS.size > 0 && !ADMOB_ALLOWED_AD_UNITS.has(adUnit)) {
    return res.status(400).json({ ok: false, error: "unknown_ad_unit" });
  }

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const now = new Date();
  const rewardRef = db.collection("admobRewards").doc(transactionId);
  let alreadyProcessed = false;
  try {
    await db.runTransaction(async (tx) => {
      const rewardSnap = await tx.get(rewardRef);
      if (rewardSnap.exists) {
        alreadyProcessed = true;
        return;
      }
      tx.create(rewardRef, {
        uid: userId || null,
        rewardItem,
        rewardAmount,
        adUnit,
        transactionId,
        customData,
        claimed: false,
        createdAt: now.toISOString()
      });
    });
  } catch (error) {
    console.error("AdMob reward record failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "reward_failed" });
  }

  return res.json({
    ok: true,
    alreadyProcessed,
    serverTimeMs: Date.now()
  });
});

app.post("/admob/claim", async (req, res) => {
  const { nonce } = req.body || {};
  if (!nonce) {
    return res.status(400).json({ ok: false, error: "missing_nonce" });
  }
  let user = null;
  const authHeader = req.headers.authorization || "";
  if (authHeader) {
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (match) {
      const appInstance = initFirebaseAdmin();
      if (appInstance) {
        try {
          user = await admin.auth().verifyIdToken(match[1]);
        } catch (error) {
          console.error("Auth token verify failed:", error.message || error);
          return res.status(401).json({ ok: false, error: "invalid_auth" });
        }
      }
    }
  }

  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  const rewardsRef = db.collection("admobRewards");
  let rewardDoc = null;
  let rewardId = null;
  try {
    const snap = await rewardsRef.where("customData", "==", nonce).limit(1).get();
    if (snap.empty) {
      return res.status(404).json({ ok: false, error: "reward_not_found" });
    }
    rewardDoc = snap.docs[0];
    rewardId = rewardDoc.id;
  } catch (error) {
    console.error("AdMob reward lookup failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "reward_lookup_failed" });
  }

  const data = rewardDoc.data() || {};
  if (data.claimed === true) {
    return res.status(409).json({ ok: false, error: "already_claimed" });
  }
  if (data.uid && user?.uid && data.uid !== user.uid) {
    return res.status(403).json({ ok: false, error: "forbidden" });
  }
  if (data.uid && !user?.uid) {
    return res.status(401).json({ ok: false, error: "auth_required" });
  }
  const createdAt = new Date(data.createdAt || 0);
  const ageMs = Date.now() - createdAt.getTime();
  if (!Number.isNaN(createdAt.getTime())) {
    const maxAgeMs = ADMOB_REWARD_TTL_MINUTES * 60 * 1000;
    if (ageMs > maxAgeMs) {
      return res.status(410).json({ ok: false, error: "reward_expired" });
    }
  }

  try {
    await rewardsRef.doc(rewardId).set(
      {
        claimed: true,
        claimedAt: new Date().toISOString()
      },
      { merge: true }
    );
  } catch (error) {
    console.error("AdMob reward claim failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "claim_failed" });
  }

  return res.json({ ok: true, serverTimeMs: Date.now() });
});

app.get("/users/state_snapshot", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  const db = getFirestore();
  if (!db) {
    return res.status(503).json({ ok: false, error: "firestore_unavailable" });
  }
  try {
    const snap = await db.collection("users").doc(user.uid).get();
    if (!snap.exists) {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    const data = snap.data() || {};
    try {
      await db
        .collection("users")
        .doc(user.uid)
        .set({ lastActiveAt: new Date().toISOString() }, { merge: true });
    } catch (error) {
      console.error("State snapshot lastActiveAt update failed:", error?.message || error);
    }
    return res.json({
      ok: true,
      tokenBalance: Number.parseInt(data.tokenBalance, 10) || 0,
      tokenLedger: Array.isArray(data.tokenLedger) ? data.tokenLedger : [],
      tabExpiry: data.tabExpiry || {},
      autoRenewEnabled: data.autoRenewEnabled === true,
      serverTimeMs: Date.now()
    });
  } catch (error) {
    console.error("State snapshot failed:", error.message || error);
    return res.status(500).json({ ok: false, error: "state_snapshot_failed" });
  }
});

const articleCache = new LRUCache({ max: 500, ttl: 1000 * 60 * 60 });
const translationCache = new LRUCache({ max: 2000, ttl: 1000 * 60 * 60 });
const newsCache = new LRUCache({ max: 200, ttl: 1000 * 60 * 10 });
const rssMetaCache = new LRUCache({
  max: 400,
  ttl: GOOGLE_NEWS_RSS_CACHE_TTL_MS
});
const rssFailureCache = new LRUCache({
  max: 600,
  ttl: Math.max(GOOGLE_NEWS_RSS_SKIP_MS * 2, 30 * 60 * 1000)
});
const googleNewsResolveCache = new LRUCache({
  max: 4000,
  ttl: 1000 * 60 * 60 * 12
});
const hostThrottleState = new Map();
const processingRecoveryCooldown = new Map();
const severityCache = new LRUCache({ max: 2000, ttl: 1000 * 60 * 60 * 6 });
const canonicalCache = new LRUCache({ max: 2000, ttl: 1000 * 60 * 60 * 12 });
const alertCache = new LRUCache({ max: 2000, ttl: 1000 * 60 * 60 * 24 });
const sentNotificationCache = new LRUCache({
  max: 5000,
  ttl: 1000 * 60 * 60 * 24
});
let firestore = null;
let firebaseApp = null;
const userActiveTouchCache = new LRUCache({ max: 50000, ttl: 1000 * 60 * 5 });
const NEWS_CACHE_TTL_MS = 25 * 60 * 1000;
const NEWS_CACHE_REFRESH_INTERVAL_MS = Math.min(
  NEWS_CACHE_TTL_MS,
  8 * 60 * 1000
);
const ON_DEMAND_CACHE_FRESH_MS = Math.max(
  60 * 1000,
  parseInt(
    process.env.ON_DEMAND_CACHE_FRESH_MS || `${NEWS_CACHE_REFRESH_INTERVAL_MS}`,
    10
  ) || NEWS_CACHE_REFRESH_INTERVAL_MS
);
// When fresh cache is unavailable (upstream failures, refresh windows),
// allow serving stale cached items for a limited window to avoid empty feeds.
const NEWS_CACHE_STALE_MAX_MS = Math.min(
  CACHE_DOC_TTL_MS,
  Math.max(
    NEWS_CACHE_TTL_MS,
    Number.parseInt(process.env.NEWS_CACHE_STALE_MAX_MS || "", 10) ||
      24 * 60 * 60 * 1000
  )
);
// `/news` can return more than the base cache size by slicing from the cached
// `limit=20` payload. Keep a hard upper bound to avoid abuse.
const NEWS_API_MAX_LIMIT = Math.max(
  20,
  parseInt(process.env.NEWS_API_MAX_LIMIT || "60", 10) || 60
);
// Store more than 20 items in the base cache doc so clients can "load more"
// without forcing extra refreshes.
const NEWS_CACHE_STORE_LIMIT = Math.max(
  20,
  parseInt(process.env.NEWS_CACHE_STORE_LIMIT || "60", 10) || 60
);
const sourceRatingCache = new LRUCache({ max: 500, ttl: 1000 * 60 * 60 * 24 * 30 });
const sourceModerationCache = new LRUCache({ max: 1000, ttl: 1000 * 60 * 60 * 24 });
let sourceAllowlist = new Set();
let sourceDenylist = new Set();
let regionAllowlist = new Map();
const SOURCE_REPORT_THRESHOLD = 20;
const SOURCE_BLOCK_THRESHOLD = 10;
loadSourceLists();
const DEFAULT_IAP_PRODUCT_MAP = parseIapProductMap(IAP_PRODUCT_MAP_RAW);
const PLAY_IAP_PRODUCT_MAP =
  parseIapProductMap(PLAY_IAP_PRODUCT_MAP_RAW) || {};
const ONESTORE_IAP_PRODUCT_MAP =
  parseIapProductMap(ONESTORE_IAP_PRODUCT_MAP_RAW) || {};

const REGION_FEED_LANG = {
  US: "en",
  UK: "en",
  KR: "ko",
  JP: "ja",
  FR: "fr",
  ES: "es",
  RU: "ru",
  AE: "ar",
  ALL: "en"
};
const BREAKING_REGION_CACHE_TTL_MS = 1000 * 60 * 60;
const DYNAMIC_ALLOWLIST_COLLECTION = "region_dynamic_allowlist";
const DYNAMIC_ALLOWLIST_TTL_MS = Math.max(
  60 * 60 * 1000,
  parseInt(process.env.DYNAMIC_ALLOWLIST_TTL_MS || "86400000", 10) || 86400000
);
const DYNAMIC_ALLOWLIST_MIN_COUNT = Math.max(
  1,
  parseInt(process.env.DYNAMIC_ALLOWLIST_MIN_COUNT || "2", 10) || 2
);
const DYNAMIC_ALLOWLIST_MAX_ENTRIES = Math.max(
  50,
  parseInt(process.env.DYNAMIC_ALLOWLIST_MAX_ENTRIES || "200", 10) || 200
);
const DYNAMIC_ALLOWLIST_CACHE_TTL_MS = Math.max(
  10 * 1000,
  parseInt(process.env.DYNAMIC_ALLOWLIST_CACHE_TTL_MS || "300000", 10) || 300000
);
const REGION_TLD_ALLOWLIST = {
  JP: ["jp", "co.jp", "ne.jp"],
  KR: ["kr", "co.kr", "or.kr"],
  RU: ["ru", "com.ru", "net.ru"],
  FR: ["fr", "com.fr"],
  ES: ["es", "com.es"],
  UK: ["uk", "co.uk", "org.uk"],
  AE: ["ae", "com.ae", "org.ae"],
  US: ["us"]
};
const EXTRA_RSS_SOURCES = [
  {
    id: "AL_JAZEERA",
    name: "Al Jazeera",
    url: "https://www.aljazeera.com/xml/rss/all.xml",
    region: "AE",
    feedLang: "en",
    sourceUrl: "https://www.aljazeera.com"
  },
  {
    id: "FRANCE24",
    name: "France 24",
    url: "https://www.france24.com/en/rss",
    region: "FR",
    feedLang: "en",
    sourceUrl: "https://www.france24.com"
  },
  {
    id: "LE_MONDE",
    name: "Le Monde",
    url: "https://www.lemonde.fr/rss/une.xml",
    region: "FR",
    feedLang: "fr",
    sourceUrl: "https://www.lemonde.fr"
  },
  {
    id: "LE_FIGARO",
    name: "Le Figaro",
    url: "https://www.lefigaro.fr/rss/figaro_actualites.xml",
    region: "FR",
    feedLang: "fr",
    sourceUrl: "https://www.lefigaro.fr"
  },
  {
    id: "LES_ECHOS",
    name: "Les Echos",
    url: "https://services.lesechos.fr/rss/les-echos-une.xml",
    region: "FR",
    feedLang: "fr",
    sourceUrl: "https://www.lesechos.fr"
  },
  {
    id: "LIBERATION",
    name: "Libération",
    url: "https://www.liberation.fr/rss/",
    region: "FR",
    feedLang: "fr",
    sourceUrl: "https://www.liberation.fr"
  },
  {
    id: "EL_PAIS",
    name: "El País",
    url: "https://elpais.com/rss/elpais/in_english.xml",
    region: "ES",
    feedLang: "en",
    sourceUrl: "https://elpais.com"
  },
  {
    id: "YAHOO_JAPAN_TOP",
    name: "Yahoo! Japan",
    url: "https://news.yahoo.co.jp/rss/topics/top-picks.xml",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://news.yahoo.co.jp"
  },
  {
    id: "YAHOO_JAPAN_IT",
    name: "Yahoo! Japan",
    url: "https://news.yahoo.co.jp/rss/topics/it.xml",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://news.yahoo.co.jp"
  },
  {
    id: "NHK",
    name: "NHK",
    url: "https://www.nhk.or.jp/rss/news/cat0.xml",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://www.nhk.or.jp"
  },
  {
    id: "ASAHI",
    name: "The Asahi Shimbun",
    url: "http://www.asahi.com/rss/asahi/newsheadlines.rdf",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://www.asahi.com"
  },
  {
    id: "MAINICHI",
    name: "Mainichi",
    url: "https://mainichi.jp/rss/etc/mainichi-flash.rss",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://mainichi.jp"
  },
  {
    id: "GIZMODO_JP",
    name: "Gizmodo Japan",
    url: "https://www.gizmodo.jp/index.xml",
    region: "JP",
    feedLang: "ja",
    sourceUrl: "https://www.gizmodo.jp"
  },
  {
    id: "TASS",
    name: "TASS",
    url: "https://tass.com/rss/v2.xml",
    region: "RU",
    feedLang: "en",
    sourceUrl: "https://tass.com"
  },
  {
    id: "RIA",
    name: "RIA Novosti",
    url: "https://ria.ru/export/rss2/archive/index.xml",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://ria.ru"
  },
  {
    id: "KOMMERSANT",
    name: "Kommersant",
    url: "https://www.kommersant.ru/RSS/main.xml",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://www.kommersant.ru"
  },
  {
    id: "RBC",
    name: "RBC",
    url: "http://static.feed.rbc.ru/rbc/logical/footer/news.rss",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://www.rbc.ru"
  },
  {
    id: "VEDOMOSTI",
    name: "Vedomosti",
    url: "https://www.vedomosti.ru/rss/news",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://www.vedomosti.ru"
  },
  {
    id: "LENTA",
    name: "Lenta",
    url: "https://lenta.ru/rss",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://lenta.ru"
  },
  {
    id: "IZVESTIA",
    name: "Izvestia",
    url: "https://iz.ru/xml/rss/all.xml",
    region: "RU",
    feedLang: "ru",
    sourceUrl: "https://iz.ru"
  },
  {
    id: "AL_ARABIYA",
    name: "Al Arabiya",
    url: "https://www.alarabiya.net/.mrss/ar/all.xml",
    region: "AE",
    feedLang: "ar",
    sourceUrl: "https://www.alarabiya.net"
  },
  {
    id: "BBC_ARABIC",
    name: "BBC Arabic",
    url: "http://feeds.bbci.co.uk/arabic/rss.xml",
    region: "AE",
    feedLang: "ar",
    sourceUrl: "https://www.bbc.com/arabic"
  },
  {
    id: "SKY_NEWS_ARABIA",
    name: "Sky News Arabia",
    url: "https://www.skynewsarabia.com/rss/news",
    region: "AE",
    feedLang: "ar",
    sourceUrl: "https://www.skynewsarabia.com"
  },
  {
    id: "ASHARQ_AWSAT",
    name: "Asharq Al-Awsat",
    url: "https://aawsat.com/feed",
    region: "AE",
    feedLang: "ar",
    sourceUrl: "https://aawsat.com"
  },
  {
    id: "NYT_HOME",
    name: "The New York Times",
    url: "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.nytimes.com"
  },
  {
    id: "NYT_WORLD",
    name: "The New York Times",
    url: "https://rss.nytimes.com/services/xml/rss/nyt/World.xml",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.nytimes.com"
  },
  {
    id: "CNN_TOP",
    name: "CNN",
    url: "http://rss.cnn.com/rss/cnn_topstories.rss",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.cnn.com"
  },
  {
    id: "CNN_TECH",
    name: "CNN",
    url: "http://rss.cnn.com/rss/cnn_tech.rss",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.cnn.com"
  },
  {
    id: "FOX_LATEST",
    name: "Fox News",
    url: "http://feeds.foxnews.com/foxnews/latest",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.foxnews.com"
  },
  {
    id: "CNBC_TOP",
    name: "CNBC",
    url: "https://www.cnbc.com/id/100003114/device/rss/rss.html",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.cnbc.com"
  },
  {
    id: "THE_VERGE",
    name: "The Verge",
    url: "https://www.theverge.com/rss/index.xml",
    region: "US",
    feedLang: "en",
    sourceUrl: "https://www.theverge.com"
  },
  {
    id: "BBC_NEWS",
    name: "BBC News",
    url: "http://feeds.bbci.co.uk/news/rss.xml",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://www.bbc.com/news"
  },
  {
    id: "BBC_WORLD",
    name: "BBC News",
    url: "http://feeds.bbci.co.uk/news/world/rss.xml",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://www.bbc.com/news/world"
  },
  {
    id: "GUARDIAN_UK",
    name: "The Guardian",
    url: "https://www.theguardian.com/uk/rss",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://www.theguardian.com/uk"
  },
  {
    id: "SKY_NEWS_UK",
    name: "Sky News",
    url: "https://feeds.skynews.com/feeds/rss/home.xml",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://sky.com"
  },
  {
    id: "DAILY_MAIL",
    name: "Daily Mail",
    url: "https://www.dailymail.co.uk/articles.rss",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://www.dailymail.co.uk"
  },
  {
    id: "INDEPENDENT",
    name: "The Independent",
    url: "http://www.independent.co.uk/rss",
    region: "UK",
    feedLang: "en",
    sourceUrl: "https://www.independent.co.uk"
  }
];
const dynamicRegionAllowlist = new Map();
const dynamicRegionAllowlistFetchedAt = new Map();
const proxyAgentCache = new Map();
let googleNewsProxyUntil = 0;

function shouldUseGoogleNewsProxy() {
  if (!GOOGLE_NEWS_PROXY_AUTO) return true;
  return Date.now() < googleNewsProxyUntil;
}

function markGoogleNewsProxyCooldown(reason = "") {
  const nextUntil = Date.now() + GOOGLE_NEWS_PROXY_COOLDOWN_MS;
  if (nextUntil > googleNewsProxyUntil) {
    googleNewsProxyUntil = nextUntil;
    if (reason) {
      console.warn(`[Proxy] Google News proxy enabled for cooldown: ${reason}`);
    } else {
      console.warn("[Proxy] Google News proxy enabled for cooldown");
    }
  }
}

app.post("/source/report", async (req, res) => {
  try {
    const { sourceName, sourceUrl, resolvedUrl, url } = req.body || {};
    const sourceKey = resolveSourceKey({ sourceName, sourceUrl, resolvedUrl, url });
    if (!sourceKey) {
      return res.status(400).json({ ok: false, error: "missing_source" });
    }
    const result = await registerSourceFeedback({
      sourceKey,
      action: "report"
    });
    return res.json({ ok: true, sourceKey, ...(result || {}) });
  } catch (error) {
    console.error("[SourceModeration] report failed", error);
    return res.status(500).json({ ok: false });
  }
});

app.post("/source/block", async (req, res) => {
  try {
    const { sourceName, sourceUrl, resolvedUrl, url } = req.body || {};
    const sourceKey = resolveSourceKey({ sourceName, sourceUrl, resolvedUrl, url });
    if (!sourceKey) {
      return res.status(400).json({ ok: false, error: "missing_source" });
    }
    const result = await registerSourceFeedback({
      sourceKey,
      action: "block"
    });
    return res.json({ ok: true, sourceKey, ...(result || {}) });
  } catch (error) {
    console.error("[SourceModeration] block failed", error);
    return res.status(500).json({ ok: false });
  }
});

app.get("/admin/sources", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const limit = Math.min(parseInt(req.query.limit || "200", 10), 500);
    const snap = await db
      .collection("source_moderation")
      .orderBy("reportCount", "desc")
      .limit(limit)
      .get();
    const items = snap.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() || {})
    }));
    items.sort((a, b) => {
      const reportDiff = (Number(b.reportCount || 0) - Number(a.reportCount || 0));
      if (reportDiff !== 0) return reportDiff;
      const blockDiff = (Number(b.blockCount || 0) - Number(a.blockCount || 0));
      if (blockDiff !== 0) return blockDiff;
      const aTime = Date.parse(a.updatedAt || "") || 0;
      const bTime = Date.parse(b.updatedAt || "") || 0;
      return bTime - aTime;
    });
    return res.json({ ok: true, items });
  } catch (error) {
    console.error("[Admin] sources failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_sources_failed" });
  }
});

app.post("/admin/sources/deny", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const sourceKey = normalizeSourceKey(req.body?.sourceKey || "");
    const denied = typeof req.body?.denied === "boolean"
      ? req.body.denied
      : null;
    if (!sourceKey || denied === null) {
      return res.status(400).json({ ok: false, error: "missing_params" });
    }
    const payload = await setSourceModerationDecision({
      sourceKey,
      denied,
      reason: req.body?.reason || "",
      decrementBlockCount: denied === false
    });
    return res.json({ ok: true, sourceKey, denied, payload });
  } catch (error) {
    console.error("[Admin] source deny failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_source_failed" });
  }
});

app.get("/admin/crawl-sources", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const sources = await getCrawlSourcesConfig({ forceRefresh: true });
    const effective = getEffectiveCrawlSources(sources);
    return res.json({ ok: true, sources, effective });
  } catch (error) {
    console.error("[Admin] crawl sources read failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_crawl_sources_failed" });
  }
});

app.post("/admin/crawl-sources", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const sourcesPayload = req.body?.sources || req.body || {};
    const normalized = normalizeCrawlSources(sourcesPayload);
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    await db
      .collection(CRAWL_SOURCES_COLLECTION)
      .doc(CRAWL_SOURCES_DOC_ID)
      .set(
        {
          ...normalized,
          updatedAt: new Date().toISOString(),
          updatedBy: user.uid || "",
          updatedByEmail: user.email || ""
        },
        { merge: true }
      );
    crawlSourcesCache = { value: normalized, fetchedAt: Date.now() };
    const effective = getEffectiveCrawlSources(normalized);
    return res.json({ ok: true, sources: normalized, effective });
  } catch (error) {
    console.error("[Admin] crawl sources update failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_crawl_sources_failed" });
  }
});

app.get("/admin/maintenance", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const config = await getMaintenanceConfig({ forceRefresh: true });
    const status = computeMaintenanceStatus(config, Date.now());
    return res.json({ ok: true, config, status, serverTimeMs: Date.now() });
  } catch (error) {
    console.error("[Admin] maintenance read failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_maintenance_failed" });
  }
});

app.post("/admin/maintenance", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const payload = normalizeMaintenanceConfig(req.body || {});
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    await db
      .collection(CRAWL_SOURCES_COLLECTION)
      .doc(MAINTENANCE_DOC_ID)
      .set(
        {
          ...payload,
          updatedAt: new Date().toISOString(),
          updatedBy: user.uid || "",
          updatedByEmail: user.email || ""
        },
        { merge: true }
      );
    maintenanceCache = { value: payload, fetchedAt: Date.now() };
    const status = computeMaintenanceStatus(payload, Date.now());
    return res.json({ ok: true, config: payload, status, serverTimeMs: Date.now() });
  } catch (error) {
    console.error("[Admin] maintenance update failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_maintenance_failed" });
  }
});

app.get("/admin/keywords", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const limit = Math.min(parseInt(req.query.limit || "100", 10), 500);
    const snap = await db
      .collection("keyword_subscriptions")
      .orderBy("count", "desc")
      .limit(limit)
      .get();
    const items = snap.docs.map((doc) => ({
      id: doc.id,
      ...(doc.data() || {})
    }));
    return res.json({ ok: true, items });
  } catch (error) {
    console.error("[Admin] keywords failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_keywords_failed" });
  }
});

app.get("/admin/metrics", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const metrics = await collectAdminUserMetrics();
    if (!metrics) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    return res.json({ ok: true, metrics });
  } catch (error) {
    console.error("[Admin] metrics failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_metrics_failed" });
  }
});

app.get("/admin/users/negative", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const limit = Math.min(
      Math.max(Number.parseInt(req.query.limit || "50", 10) || 50, 1),
      200
    );
    const snap = await db
      .collection("users")
      .where("tokenBalance", "<", 0)
      .orderBy("tokenBalance", "asc")
      .limit(limit)
      .get();
    const items = snap.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        uid: doc.id,
        tokenBalance: Number.parseInt(data.tokenBalance, 10) || 0,
        banned: data.banned === true,
        email: data.email || "",
        updatedAt: data.updatedAt || "",
        lastActiveAt: data.lastActiveAt || ""
      };
    });
    return res.json({ ok: true, items });
  } catch (error) {
    console.error("[Admin] negative users failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_users_failed" });
  }
});

app.post("/admin/users/ban", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const uid = String(req.body?.uid || "").trim();
    const banned = req.body?.banned !== false;
    const reason = String(req.body?.reason || "").trim();
    if (!uid) {
      return res.status(400).json({ ok: false, error: "invalid_params" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const userRef = db.collection("users").doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    const nowIso = new Date().toISOString();
    const updatePayload = {
      banned,
      updatedAt: nowIso
    };
    if (banned) {
      updatePayload.bannedAt = nowIso;
      updatePayload.bannedBy = {
        uid: user.uid || "",
        email: user.email || ""
      };
      updatePayload.banReason = reason || "admin_ban";
    } else {
      updatePayload.unbannedAt = nowIso;
      updatePayload.unbannedBy = {
        uid: user.uid || "",
        email: user.email || ""
      };
      updatePayload.unbanReason = reason || "admin_unban";
    }
    await userRef.set(updatePayload, { merge: true });
    if (banned) {
      try {
        await clearUserKeywordsForBan(uid);
      } catch (error) {
        console.error(
          "[Admin] clear user keywords failed",
          uid,
          error?.message || error
        );
      }
    }
    try {
      const appInstance = initFirebaseAdmin();
      if (appInstance) {
        await admin.auth().updateUser(uid, { disabled: banned });
        if (banned) {
          await admin.auth().revokeRefreshTokens(uid);
        }
      }
    } catch (error) {
      console.error("[Admin] auth ban update failed", error?.message || error);
    }
    await db.collection("adminUserBans").add({
      uid,
      banned,
      reason: reason || null,
      adminUid: user.uid || "",
      adminEmail: user.email || "",
      createdAt: nowIso
    });
    return res.json({ ok: true, banned });
  } catch (error) {
    console.error("[Admin] user ban failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_user_ban_failed" });
  }
});

app.post("/admin/tokens/grant", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const uid = String(req.body?.uid || "").trim();
    const tokens = Number.parseInt(req.body?.tokens, 10);
    const reason = String(req.body?.reason || "").trim();
    if (!uid || !Number.isFinite(tokens) || tokens <= 0) {
      return res.status(400).json({ ok: false, error: "invalid_params" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const now = new Date();
    const entry = {
      timestamp: now.toISOString(),
      amount: tokens,
      type: "admin_grant",
      description: reason || "admin_grant",
      adminUid: user.uid || "",
      adminEmail: user.email || ""
    };
    const userRef = db.collection("users").doc(uid);
    let newBalance = null;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new Error("user_not_found");
      }
      const data = snap.data() || {};
      const currentBalance = Number.parseInt(data.tokenBalance, 10) || 0;
      const ledger = Array.isArray(data.tokenLedger)
        ? data.tokenLedger.slice()
        : [];
      ledger.unshift(entry);
      newBalance = currentBalance + tokens;
      tx.set(
        userRef,
        {
          tokenBalance: newBalance,
          tokenLedger: ledger,
          updatedAt: now.toISOString()
        },
        { merge: true }
      );
    });
    await db.collection("adminTokenGrants").add({
      uid,
      tokens,
      reason: reason || null,
      adminUid: user.uid || "",
      adminEmail: user.email || "",
      createdAt: now.toISOString()
    });
    return res.json({
      ok: true,
      tokenBalance: newBalance,
      tokenLedgerEntry: entry
    });
  } catch (error) {
    if (error.message === "user_not_found") {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    console.error("[Admin] token grant failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_token_failed" });
  }
});

app.post("/admin/tokens/deduct", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const uid = String(req.body?.uid || "").trim();
    const tokens = Number.parseInt(req.body?.tokens, 10);
    const reason = String(req.body?.reason || "").trim();
    if (!uid || !Number.isFinite(tokens) || tokens <= 0) {
      return res.status(400).json({ ok: false, error: "invalid_params" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const now = new Date();
    const userRef = db.collection("users").doc(uid);
    let newBalance = null;
    let deducted = 0;
    let clamped = false;
    let entry = null;
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new Error("user_not_found");
      }
      const data = snap.data() || {};
      const currentBalance = Number.parseInt(data.tokenBalance, 10) || 0;
      if (currentBalance <= 0) {
        throw new Error("insufficient_tokens");
      }
      deducted = Math.min(tokens, currentBalance);
      clamped = deducted !== tokens;
      newBalance = currentBalance - deducted;
      const ledger = Array.isArray(data.tokenLedger)
        ? data.tokenLedger.slice()
        : [];
      entry = {
        timestamp: now.toISOString(),
        amount: -deducted,
        type: "admin_deduct",
        description: reason || "admin_deduct",
        adminUid: user.uid || "",
        adminEmail: user.email || ""
      };
      ledger.unshift(entry);
      tx.set(
        userRef,
        {
          tokenBalance: newBalance,
          tokenLedger: ledger,
          updatedAt: now.toISOString()
        },
        { merge: true }
      );
    });
    await db.collection("adminTokenAdjustments").add({
      uid,
      tokensRequested: tokens,
      tokensDeducted: deducted,
      clamped,
      reason: reason || null,
      adminUid: user.uid || "",
      adminEmail: user.email || "",
      createdAt: now.toISOString()
    });
    return res.json({
      ok: true,
      tokenBalance: newBalance,
      tokenLedgerEntry: entry,
      deductedTokens: deducted,
      clamped
    });
  } catch (error) {
    if (error.message === "user_not_found") {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    if (error.message === "insufficient_tokens") {
      return res.status(400).json({ ok: false, error: "insufficient_tokens" });
    }
    console.error("[Admin] token deduct failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_token_failed" });
  }
});

app.get("/admin/tabs/status", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const uid = String(req.query.uid || "").trim();
    const tabIndex = Number.parseInt(req.query.tabIndex, 10);
    if (!uid || !Number.isFinite(tabIndex)) {
      return res.status(400).json({ ok: false, error: "invalid_params" });
    }
    if (tabIndex < 2 || tabIndex > TAB_MAX_INDEX) {
      return res.status(400).json({ ok: false, error: "invalid_tab_index" });
    }
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const snap = await db.collection("users").doc(uid).get();
    if (!snap.exists) {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    const data = snap.data() || {};
    const expiryMap = data.tabExpiry || {};
    const expiryValue = expiryMap[String(tabIndex)] || "";
    const expiryMs = expiryValue ? Date.parse(expiryValue) : Number.NaN;
    const nowMs = Date.now();
    const active =
      !Number.isNaN(expiryMs) && expiryMs > nowMs;
    const remainingMs = active ? Math.max(0, expiryMs - nowMs) : 0;
    const remainingHours = Math.floor(remainingMs / (60 * 60 * 1000));
    return res.json({
      ok: true,
      uid,
      tabIndex,
      expiry: expiryValue || "",
      active,
      remainingMs,
      remainingHours
    });
  } catch (error) {
    console.error("[Admin] tab status failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_tab_failed" });
  }
});

app.post("/admin/tabs/set", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const uid = String(req.body?.uid || "").trim();
    const tabIndex = Number.parseInt(req.body?.tabIndex, 10);
    const remainingHours = Number(req.body?.remainingHours);
    const remainingMinutes = Number(req.body?.remainingMinutes);
    const expiresAtRaw = String(req.body?.expiresAt || "").trim();
    if (!uid || !Number.isFinite(tabIndex)) {
      return res.status(400).json({ ok: false, error: "invalid_params" });
    }
    if (tabIndex < 2 || tabIndex > TAB_MAX_INDEX) {
      return res.status(400).json({ ok: false, error: "invalid_tab_index" });
    }
    let expiryMs = Number.NaN;
    if (expiresAtRaw) {
      expiryMs = Date.parse(expiresAtRaw);
    } else if (Number.isFinite(remainingMinutes) && remainingMinutes > 0) {
      expiryMs = Date.now() + remainingMinutes * 60 * 1000;
    } else if (Number.isFinite(remainingHours) && remainingHours > 0) {
      expiryMs = Date.now() + remainingHours * 60 * 60 * 1000;
    }
    if (!Number.isFinite(expiryMs)) {
      return res.status(400).json({ ok: false, error: "invalid_expiry" });
    }
    const expiryIso = new Date(expiryMs).toISOString();
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) {
        throw new Error("user_not_found");
      }
      const data = snap.data() || {};
      const expiryMap = data.tabExpiry || {};
      const autoRenewed = data.tabAutoRenewedExpiry || {};
      const nextExpiry = { ...expiryMap, [String(tabIndex)]: expiryIso };
      const nextAutoRenewed = { ...autoRenewed };
      delete nextAutoRenewed[String(tabIndex)];
      tx.set(
        userRef,
        {
          tabExpiry: nextExpiry,
          tabAutoRenewedExpiry: nextAutoRenewed,
          updatedAt: new Date().toISOString()
        },
        { merge: true }
      );
    });
    await db.collection("adminTabAdjustments").add({
      uid,
      tabIndex,
      expiresAt: expiryIso,
      adminUid: user.uid || "",
      adminEmail: user.email || "",
      createdAt: new Date().toISOString()
    });
    return res.json({
      ok: true,
      uid,
      tabIndex,
      expiresAt: expiryIso,
      serverTimeMs: Date.now()
    });
  } catch (error) {
    if (error.message === "user_not_found") {
      return res.status(404).json({ ok: false, error: "user_not_found" });
    }
    console.error("[Admin] tab set failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_tab_failed" });
  }
});

app.post("/admin/push/send", async (req, res) => {
  const user = await requireAdmin(req, res);
  if (!user) return;
  try {
    const scope =
      String(req.body?.scope || "all").toLowerCase() === "user"
        ? "user"
        : "all";
    const uid = String(req.body?.uid || "").trim();
    const title = String(req.body?.title || "").trim();
    const body = String(req.body?.body || "").trim();
    const inputLang = String(
      req.body?.inputLang || req.body?.language || req.body?.lang || "en"
    ).trim();
    const data =
      req.body?.data && typeof req.body.data === "object"
        ? req.body.data
        : {};

    const result = await sendAdminPushNotification({
      scope,
      uid,
      title,
      body,
      inputLang,
      data
    });
    if (!result.ok) {
      if (result.error === "uid_required") {
        return res.status(400).json({ ok: false, error: "uid_required" });
      }
      if (result.error === "user_not_found") {
        return res.status(404).json({ ok: false, error: "user_not_found" });
      }
      if (result.error === "title_body_required") {
        return res.status(400).json({ ok: false, error: "title_body_required" });
      }
      if (result.error === "title_too_long") {
        return res.status(400).json({ ok: false, error: "title_too_long" });
      }
      if (result.error === "body_too_long") {
        return res.status(400).json({ ok: false, error: "body_too_long" });
      }
      return res
        .status(503)
        .json({ ok: false, error: result.error || "push_unavailable" });
    }

    const db = getFirestore();
    if (db) {
      try {
        await db.collection("adminPushNotifications").add({
          scope: result.scope,
          uid: result.uid || "",
          title: result.title,
          body: result.body,
          inputLang: result.inputLang || "en",
          translatedLanguages: result.translatedLanguages || [],
          languageBreakdown: result.languageBreakdown || {},
          dataKeys: result.dataKeys || [],
          targeted: result.targeted || 0,
          sent: result.sent || 0,
          failed: result.failed || 0,
          skippedStale: result.skippedStale || 0,
          cleanedStale: result.cleanedStale || 0,
          cleanedInvalid: result.cleanedInvalid || 0,
          adminUid: user.uid || "",
          adminEmail: user.email || "",
          createdAt: new Date().toISOString()
        });
      } catch (error) {
        console.error("[Admin] push log failed", error?.message || error);
      }
    }

    return res.json({
      ok: true,
      scope: result.scope,
      uid: result.uid || "",
      targeted: result.targeted,
      sent: result.sent,
      failed: result.failed,
      skippedStale: result.skippedStale,
      cleanedStale: result.cleanedStale,
      cleanedInvalid: result.cleanedInvalid,
      inputLang: result.inputLang || "en",
      translatedLanguages: result.translatedLanguages || [],
      languageBreakdown: result.languageBreakdown || {}
    });
  } catch (error) {
    console.error("[Admin] push send failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "admin_push_failed" });
  }
});

function loadSourceLists() {
  if (!fs.existsSync(SOURCE_LISTS_PATH)) {
    sourceAllowlist = new Set();
    sourceDenylist = new Set();
    regionAllowlist = new Map();
    return;
  }
  try {
    const raw = fs.readFileSync(SOURCE_LISTS_PATH, "utf8");
    const parsed = JSON.parse(raw || "{}");
    sourceAllowlist = new Set(
      (parsed.allowlist || []).map((v) => String(v).toLowerCase().trim())
    );
    sourceDenylist = new Set(
      (parsed.denylist || []).map((v) => String(v).toLowerCase().trim())
    );
    regionAllowlist = new Map();
    const regionParsed = parsed.regionAllowlist || {};
    for (const [region, list] of Object.entries(regionParsed)) {
      if (!Array.isArray(list)) continue;
      regionAllowlist.set(
        region.toUpperCase(),
        new Set(list.map((v) => String(v).toLowerCase().trim()))
      );
    }
  } catch (error) {
    console.error("[SourceLists] Failed to load source_lists.json", error);
    sourceAllowlist = new Set();
    sourceDenylist = new Set();
    regionAllowlist = new Map();
  }
}

function makeDomainKey(domain) {
  return crypto.createHash("sha1").update(`domain:${domain}`).digest("hex");
}

function normalizeDomainForAllowlist(hostname) {
  const normalized = normalizeHostname(hostname);
  if (!normalized) return "";
  const stripped = stripCommonSubdomain(normalized);
  const registrable = getRegistrableDomain(stripped || normalized);
  return registrable || stripped || normalized;
}

function matchesRegionTld(region, domain) {
  const key = normalizeRegionCode(region || "", "");
  if (!key || key === "ALL") return false;
  const tlds = REGION_TLD_ALLOWLIST[key];
  if (!Array.isArray(tlds) || tlds.length === 0) return false;
  const normalized = normalizeHostname(domain);
  if (!normalized) return false;
  return tlds.some((tld) => normalized === tld || normalized.endsWith(`.${tld}`));
}

function normalizeCountryToken(value) {
  return normalizeWhitespace(String(value || ""))
    .toLowerCase()
    .replace(/[^a-z\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function resolveGdeltRegion(sourceCountry) {
  const token = normalizeCountryToken(sourceCountry);
  if (!token) return "";
  const map = {
    usa: "US",
    us: "US",
    uk: "UK",
    uae: "AE"
  };
  if (map[token]) return map[token];
  if (token.includes("united states")) return "US";
  if (
    token.includes("united kingdom") ||
    token.includes("great britain") ||
    token.includes("britain") ||
    token.includes("england")
  ) {
    return "UK";
  }
  if (
    token.includes("south korea") ||
    token.includes("republic of korea") ||
    (token.includes("korea") && token.includes("south"))
  ) {
    return "KR";
  }
  if (token.includes("japan")) return "JP";
  if (token.includes("france")) return "FR";
  if (token.includes("spain")) return "ES";
  if (token.includes("russian federation") || token.includes("russia")) {
    return "RU";
  }
  if (token.includes("united arab emirates")) return "AE";
  return "";
}

function extractDynamicEntryTimestamp(entry) {
  if (!entry) return 0;
  if (Number.isFinite(entry.lastSeenMs)) return entry.lastSeenMs;
  const raw = entry.lastSeen || entry.updatedAt || entry.timestamp || "";
  const parsed = Date.parse(raw);
  return Number.isNaN(parsed) ? 0 : parsed;
}

function buildDynamicAllowSet(entries, nowMs) {
  const allowSet = new Set();
  if (!entries || typeof entries !== "object") return allowSet;
  for (const entry of Object.values(entries)) {
    const domain = normalizeHostname(entry?.domain || "");
    if (!domain) continue;
    const count = Number(entry?.count || 0);
    const lastSeenMs = extractDynamicEntryTimestamp(entry);
    if (lastSeenMs && nowMs - lastSeenMs > DYNAMIC_ALLOWLIST_TTL_MS) {
      continue;
    }
    if (count >= DYNAMIC_ALLOWLIST_MIN_COUNT) {
      allowSet.add(domain);
    }
  }
  return allowSet;
}

function pruneDynamicAllowEntries(entries, nowMs) {
  const list = [];
  for (const [key, entry] of Object.entries(entries || {})) {
    const domain = normalizeHostname(entry?.domain || "");
    if (!domain) continue;
    const count = Number(entry?.count || 0);
    const lastSeenMs = extractDynamicEntryTimestamp(entry);
    if (lastSeenMs && nowMs - lastSeenMs > DYNAMIC_ALLOWLIST_TTL_MS) {
      continue;
    }
    list.push({
      key,
      domain,
      count,
      lastSeenMs,
      lastSeen: entry?.lastSeen || ""
    });
  }
  list.sort((a, b) => {
    if (b.count !== a.count) return b.count - a.count;
    return (b.lastSeenMs || 0) - (a.lastSeenMs || 0);
  });
  const pruned = {};
  list.slice(0, DYNAMIC_ALLOWLIST_MAX_ENTRIES).forEach((entry) => {
    pruned[entry.key] = {
      domain: entry.domain,
      count: entry.count,
      lastSeen: entry.lastSeen || new Date(entry.lastSeenMs || nowMs).toISOString()
    };
  });
  return pruned;
}

async function loadDynamicRegionAllowlist(region) {
  const key = normalizeRegionCode(region || "", "");
  if (!key || key === "ALL") return new Set();
  const now = Date.now();
  const lastFetched = dynamicRegionAllowlistFetchedAt.get(key) || 0;
  if (now - lastFetched < DYNAMIC_ALLOWLIST_CACHE_TTL_MS) {
    return dynamicRegionAllowlist.get(key) || new Set();
  }
  const db = getFirestore();
  if (!db) {
    return dynamicRegionAllowlist.get(key) || new Set();
  }
  try {
    const doc = await db.collection(DYNAMIC_ALLOWLIST_COLLECTION).doc(key).get();
    const data = doc.exists ? doc.data() || {} : {};
    const entries = data.entries || {};
    const allowSet = buildDynamicAllowSet(entries, now);
    dynamicRegionAllowlist.set(key, allowSet);
    dynamicRegionAllowlistFetchedAt.set(key, now);
    return allowSet;
  } catch (error) {
    console.error("[DynamicAllowlist] load failed", key, error?.message || error);
    return dynamicRegionAllowlist.get(key) || new Set();
  }
}

async function recordDynamicRegionSources(region, domains) {
  const key = normalizeRegionCode(region || "", "");
  if (!key || key === "ALL") return;
  if (!Array.isArray(domains) || domains.length === 0) return;
  const db = getFirestore();
  if (!db) return;
  const normalizedDomains = Array.from(
    new Set(
      domains
        .map((domain) => normalizeDomainForAllowlist(domain))
        .filter(Boolean)
    )
  );
  if (!normalizedDomains.length) return;
  const docRef = db.collection(DYNAMIC_ALLOWLIST_COLLECTION).doc(key);
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  let nextAllowSet = null;
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(docRef);
      const data = snap.exists ? snap.data() || {} : {};
      const entries =
        data.entries && typeof data.entries === "object" ? { ...data.entries } : {};
      normalizedDomains.forEach((domain) => {
        const domainKey = makeDomainKey(domain);
        const prev = entries[domainKey] || {};
        const count = Number(prev.count || 0) + 1;
        entries[domainKey] = { domain, count, lastSeen: nowIso };
      });
      const pruned = pruneDynamicAllowEntries(entries, nowMs);
      nextAllowSet = buildDynamicAllowSet(pruned, nowMs);
      tx.set(
        docRef,
        {
          entries: pruned,
          updatedAt: nowIso
        },
        { merge: true }
      );
    });
    if (nextAllowSet) {
      dynamicRegionAllowlist.set(key, nextAllowSet);
      dynamicRegionAllowlistFetchedAt.set(key, Date.now());
    }
  } catch (error) {
    console.error("[DynamicAllowlist] update failed", key, error?.message || error);
  }
}

function normalizeCrawlSources(input) {
  const value = input && typeof input === "object" ? input : {};
  return {
    googleNews:
      typeof value.googleNews === "boolean"
        ? value.googleNews
        : DEFAULT_CRAWL_SOURCES.googleNews,
    naver:
      typeof value.naver === "boolean"
        ? value.naver
        : DEFAULT_CRAWL_SOURCES.naver,
    gdelt:
      typeof value.gdelt === "boolean"
        ? value.gdelt
        : DEFAULT_CRAWL_SOURCES.gdelt
  };
}

function getEffectiveCrawlSources(input) {
  const normalized = normalizeCrawlSources(input);
  return {
    googleNews: normalized.googleNews !== false,
    naver:
      normalized.naver !== false &&
      ENABLE_NAVER_NEWS &&
      Boolean(NAVER_CLIENT_ID) &&
      Boolean(NAVER_CLIENT_SECRET),
    gdelt: normalized.gdelt !== false && ENABLE_GDELT
  };
}

async function getCrawlSourcesConfig(options = {}) {
  const forceRefresh = options.forceRefresh === true;
  const now = Date.now();
  if (
    !forceRefresh &&
    crawlSourcesCache.value &&
    now - crawlSourcesCache.fetchedAt < CRAWL_SOURCES_CACHE_TTL_MS
  ) {
    return crawlSourcesCache.value;
  }
  const db = getFirestore();
  if (!db) {
    const fallback = crawlSourcesCache.value || DEFAULT_CRAWL_SOURCES;
    return normalizeCrawlSources(fallback);
  }
  try {
    const snap = await db
      .collection(CRAWL_SOURCES_COLLECTION)
      .doc(CRAWL_SOURCES_DOC_ID)
      .get();
    const data = snap.exists ? snap.data() || {} : {};
    const normalized = normalizeCrawlSources(data);
    crawlSourcesCache = { value: normalized, fetchedAt: now };
    return normalized;
  } catch (error) {
    console.error("[CrawlSources] load failed", error?.message || error);
    const fallback = crawlSourcesCache.value || DEFAULT_CRAWL_SOURCES;
    return normalizeCrawlSources(fallback);
  }
}

function normalizeMaintenanceConfig(input) {
  const value = input && typeof input === "object" ? input : {};
  const startAt =
    typeof value.startAt === "string" && value.startAt.trim()
      ? value.startAt.trim()
      : null;
  const endAt =
    typeof value.endAt === "string" && value.endAt.trim()
      ? value.endAt.trim()
      : null;
  return {
    enabled: value.enabled === true,
    startAt,
    endAt,
    storeUrlAndroid:
      typeof value.storeUrlAndroid === "string"
        ? value.storeUrlAndroid.trim()
        : "",
    storeUrlIos:
      typeof value.storeUrlIos === "string" ? value.storeUrlIos.trim() : ""
  };
}

function parseIsoMs(value) {
  if (!value || typeof value !== "string") return null;
  const ms = Date.parse(value);
  return Number.isNaN(ms) ? null : ms;
}

function computeMaintenanceStatus(config, nowMs = Date.now()) {
  const normalized = normalizeMaintenanceConfig(config);
  const startMs = parseIsoMs(normalized.startAt);
  const endMs = parseIsoMs(normalized.endAt);
  let active = normalized.enabled === true;
  if (active && startMs && nowMs < startMs) active = false;
  if (active && endMs && nowMs > endMs) active = false;
  return {
    ...normalized,
    active,
    startAt: startMs ? new Date(startMs).toISOString() : null,
    endAt: endMs ? new Date(endMs).toISOString() : null
  };
}

async function getMaintenanceConfig(options = {}) {
  const forceRefresh = options.forceRefresh === true;
  const now = Date.now();
  if (
    !forceRefresh &&
    maintenanceCache.value &&
    now - maintenanceCache.fetchedAt < MAINTENANCE_CACHE_TTL_MS
  ) {
    return maintenanceCache.value;
  }
  const db = getFirestore();
  if (!db) {
    const fallback = maintenanceCache.value || DEFAULT_MAINTENANCE;
    return normalizeMaintenanceConfig(fallback);
  }
  try {
    const snap = await db
      .collection(CRAWL_SOURCES_COLLECTION)
      .doc(MAINTENANCE_DOC_ID)
      .get();
    const data = snap.exists ? snap.data() || {} : {};
    const normalized = normalizeMaintenanceConfig(data);
    maintenanceCache = { value: normalized, fetchedAt: now };
    return normalized;
  } catch (error) {
    console.error("[Maintenance] load failed", error?.message || error);
    const fallback = maintenanceCache.value || DEFAULT_MAINTENANCE;
    return normalizeMaintenanceConfig(fallback);
  }
}

const languageNames = {
  en: "English",
  ko: "Korean",
  ja: "Japanese",
  fr: "French",
  es: "Spanish",
  ru: "Russian",
  ar: "Arabic"
};

const LATIN_LANGUAGE_HINTS = {
  en: [
    "the",
    "and",
    "for",
    "with",
    "from",
    "to",
    "of",
    "in",
    "on",
    "by",
    "is",
    "are",
    "as",
    "at"
  ],
  fr: [
    "le",
    "la",
    "les",
    "de",
    "des",
    "et",
    "en",
    "une",
    "un",
    "pour",
    "avec",
    "sur",
    "est",
    "au",
    "du"
  ],
  es: [
    "el",
    "la",
    "los",
    "las",
    "de",
    "y",
    "en",
    "para",
    "con",
    "un",
    "una",
    "por",
    "es",
    "del",
    "al"
  ]
};

function resolveLanguageName(code) {
  const key = (code || "en").toLowerCase().split("-")[0];
  return languageNames[key] || "English";
}

function normalizeLangCode(value, fallback = "en") {
  return (value || fallback).toLowerCase().split("-")[0];
}

const LANG_ALIAS_MAP = {
  korean: "ko",
  "한국어": "ko",
  kr: "ko",
  kor: "ko",
  "ko-kr": "ko",
  english: "en",
  eng: "en",
  "en-us": "en",
  "en-gb": "en",
  japanese: "ja",
  jp: "ja",
  "ja-jp": "ja",
  french: "fr",
  "français": "fr",
  spanish: "es",
  "español": "es",
  russian: "ru",
  "русский": "ru",
  arabic: "ar",
  "العربية": "ar",
  chinese: "zh",
  mandarin: "zh",
  cn: "zh",
  "zh-cn": "zh",
  "zh-hans": "zh",
  german: "de",
  deutsch: "de",
  italian: "it",
  portuguese: "pt",
  "pt-br": "pt",
  "brazilian portuguese": "pt"
};

function normalizeLangAlias(value, fallback = "en") {
  const raw = normalizeWhitespace(value || "");
  if (!raw) return fallback;
  const lowered = raw.toLowerCase();
  const mapped = LANG_ALIAS_MAP[lowered];
  return normalizeLangCode(mapped || lowered, fallback);
}

function normalizeRegionCode(value, fallback = "ALL") {
  const normalized = normalizeWhitespace(value || "");
  if (!normalized) return fallback;
  return normalized.toUpperCase();
}

function countWordHits(text, words) {
  let count = 0;
  for (const word of words) {
    const regex = new RegExp(`\\b${word}\\b`, "g");
    const matches = text.match(regex);
    if (matches) count += matches.length;
  }
  return count;
}

function detectLatinLanguage(text) {
  const normalized = normalizeWhitespace(text || "").toLowerCase();
  if (!normalized) return "";
  const scores = {};
  for (const [lang, words] of Object.entries(LATIN_LANGUAGE_HINTS)) {
    scores[lang] = countWordHits(normalized, words);
  }
  const ordered = Object.entries(scores).sort((a, b) => b[1] - a[1]);
  if (!ordered.length) return "";
  const [topLang, topScore] = ordered[0];
  const secondScore = ordered[1] ? ordered[1][1] : 0;
  if (topScore < 2) return "";
  if (topScore < secondScore + 1) return "";
  return topLang;
}

function normalizeIapStoreType(value) {
  const raw = String(value || "")
    .trim()
    .toLowerCase();
  if (raw === "onestore" || raw === "one_store") return "onestore";
  return "play";
}

function normalizeOneStoreMarketCode(value) {
  const code = String(value || "")
    .trim()
    .toUpperCase();
  if (code === "MKT_ONE" || code === "MKT_GLB") return code;
  return "";
}

function normalizeOneStoreApiBaseUrl(value) {
  const url = String(value || "")
    .trim()
    .replace(/\/+$/, "");
  return url;
}

function getOneStoreApiBaseCandidates() {
  const candidates = [
    normalizeOneStoreApiBaseUrl(ONESTORE_API_BASE_URL),
    "https://iap-apis.onestore.net",
    "https://sbpp.onestore.net",
    "https://apis.onestore.co.kr"
  ].filter(Boolean);
  return Array.from(new Set(candidates));
}

function getIapProductMapForStore(storeType) {
  const normalizedStore = normalizeIapStoreType(storeType);
  if (normalizedStore === "onestore") {
    if (Object.keys(ONESTORE_IAP_PRODUCT_MAP).length > 0) {
      return ONESTORE_IAP_PRODUCT_MAP;
    }
    return DEFAULT_IAP_PRODUCT_MAP;
  }
  if (Object.keys(PLAY_IAP_PRODUCT_MAP).length > 0) {
    return PLAY_IAP_PRODUCT_MAP;
  }
  return DEFAULT_IAP_PRODUCT_MAP;
}

function resolveIapTokens(productId, storeType = "play") {
  if (!productId) return null;
  const productMap = getIapProductMapForStore(storeType);
  const tokens = productMap[productId];
  if (!Number.isFinite(tokens) || tokens <= 0) return null;
  return tokens;
}

function buildIapPurchaseDocId({ storeType, purchaseToken }) {
  const normalizedStore = normalizeIapStoreType(storeType);
  const token = String(purchaseToken || "").trim();
  if (!token) return "";
  if (normalizedStore === "play") return token;
  return `${normalizedStore}:${token}`;
}

function buildIapPurchaseDocIdCandidates({ storeType, purchaseToken }) {
  const token = String(purchaseToken || "").trim();
  if (!token) return [];
  const normalizedStore = normalizeIapStoreType(storeType);
  const candidates = [];
  const primaryId = buildIapPurchaseDocId({
    storeType: normalizedStore,
    purchaseToken: token
  });
  if (primaryId) {
    candidates.push(primaryId);
  }
  if (!candidates.includes(token)) {
    candidates.push(token);
  }
  const onestoreId = `onestore:${token}`;
  if (!candidates.includes(onestoreId)) {
    candidates.push(onestoreId);
  }
  return candidates;
}

async function resolveIapPurchaseRefByToken({ db, storeType, purchaseToken }) {
  if (!db) return null;
  const token = String(purchaseToken || "").trim();
  if (!token) return null;
  const normalizedStore = normalizeIapStoreType(storeType);
  const docIds = buildIapPurchaseDocIdCandidates({
    storeType: normalizedStore,
    purchaseToken: token
  });
  for (const docId of docIds) {
    const ref = db.collection("iapPurchases").doc(docId);
    const snap = await ref.get();
    if (snap.exists) return ref;
  }

  try {
    const lookupSnap = await db
      .collection("iapPurchases")
      .where("purchaseToken", "==", token)
      .limit(20)
      .get();
    if (lookupSnap.empty) return null;
    if (normalizedStore === "onestore") {
      const matched = lookupSnap.docs.find(
        (doc) => normalizeIapStoreType(doc.data()?.storeType || "") === "onestore"
      );
      if (matched) return matched.ref;
    }
    return lookupSnap.docs[0].ref;
  } catch (error) {
    console.error(
      "[IAP] purchase token lookup failed:",
      token.slice(0, 12),
      error?.message || error
    );
    return null;
  }
}

function normalizeStringArray(input, size, fallback) {
  const output = [];
  if (Array.isArray(input)) {
    for (const item of input) {
      output.push(String(item || "").trim());
    }
  }
  while (output.length < size) {
    output.push(fallback);
  }
  if (output.length > size) {
    output.length = size;
  }
  return output;
}

function normalizeRegionArray(input, size) {
  const output = normalizeStringArray(input, size, "ALL");
  return output.map((value) => (value ? value.toUpperCase() : "ALL"));
}

function normalizeCanonicalKeywords(input) {
  const output = {};
  if (!input || typeof input !== "object") return output;
  for (const [key, value] of Object.entries(input)) {
    const index = Number.parseInt(key, 10);
    if (!Number.isFinite(index)) continue;
    const trimmed = String(value || "").trim();
    if (trimmed) {
      output[String(index)] = trimmed;
    }
  }
  return output;
}

function normalizeNotificationPrefs(input) {
  if (!input || typeof input !== "object") return null;
  return {
    breakingEnabled: Boolean(input.breakingEnabled),
    keywordSeverity4: Boolean(input.keywordSeverity4),
    keywordSeverity5: Boolean(input.keywordSeverity5)
  };
}

async function verifyAndroidProductPurchase({ productId, purchaseToken }) {
  const service = await getAndroidPublisherService();
  if (!service) {
    return { ok: false, error: "android_publisher_not_configured" };
  }
  const response = await service.purchases.products.get({
    packageName: ANDROID_PUBLISHER_PACKAGE_NAME,
    productId,
    token: purchaseToken
  });
  const data = response?.data || {};
  const purchaseState = data.purchaseState;
  if (purchaseState !== 0) {
    return { ok: false, error: "purchase_not_completed", data };
  }
  return { ok: true, data };
}

async function consumeAndroidPurchase({ productId, purchaseToken }) {
  const service = await getAndroidPublisherService();
  if (!service) {
    return { ok: false, error: "android_publisher_not_configured" };
  }
  await service.purchases.products.consume({
    packageName: ANDROID_PUBLISHER_PACKAGE_NAME,
    productId,
    token: purchaseToken
  });
  return { ok: true };
}

async function getOneStoreAccessToken(baseUrl) {
  if (!ONESTORE_CLIENT_ID || !ONESTORE_CLIENT_SECRET) {
    return { ok: false, error: "onestore_not_configured" };
  }
  const safeBaseUrl = normalizeOneStoreApiBaseUrl(baseUrl);
  if (!safeBaseUrl) {
    return { ok: false, error: "onestore_api_base_missing" };
  }
  const now = Date.now();
  const cachedToken = cachedOneStoreTokenByBaseUrl.get(safeBaseUrl);
  if (cachedToken && cachedToken.expiresAt > now + 60 * 1000) {
    return { ok: true, accessToken: cachedToken.token };
  }

  const endpoint = `${safeBaseUrl}/v7/oauth/token`;
  const params = new URLSearchParams();
  params.set("grant_type", "client_credentials");
  params.set("client_id", ONESTORE_CLIENT_ID);
  params.set("client_secret", ONESTORE_CLIENT_SECRET);

  const response = await fetchWithTimeout(
    endpoint,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
      },
      body: params.toString()
    },
    ONESTORE_API_TIMEOUT_MS
  );
  let payload = null;
  let rawBody = "";
  try {
    rawBody = await response.text();
    payload = rawBody ? JSON.parse(rawBody) : null;
  } catch (_) {
    payload = null;
  }
  const accessToken = String(
    payload?.accessToken || payload?.access_token || ""
  ).trim();
  if (!response.ok || !accessToken) {
    return {
      ok: false,
      error: "onestore_token_failed",
      status: response.status,
      data: payload || rawBody || null
    };
  }
  const expiresInRaw =
    payload?.expiresIn ?? payload?.expires_in ?? payload?.expires ?? "";
  const expiresIn = Number.parseInt(expiresInRaw, 10);
  const ttlMs = Number.isFinite(expiresIn)
    ? Math.max(60, expiresIn) * 1000
    : 60 * 60 * 1000;
  cachedOneStoreTokenByBaseUrl.set(safeBaseUrl, {
    token: accessToken,
    expiresAt: now + ttlMs
  });
  return { ok: true, accessToken, data: payload };
}

async function verifyOneStoreProductPurchase({
  productId,
  purchaseToken,
  marketCode = ""
}) {
  const safeClientId = encodeURIComponent(ONESTORE_CLIENT_ID);
  const safeProductId = encodeURIComponent(String(productId || ""));
  const safeToken = encodeURIComponent(String(purchaseToken || ""));
  const normalizedMarketCode = normalizeOneStoreMarketCode(marketCode);
  const apiBases = getOneStoreApiBaseCandidates();
  const errors = [];

  for (const apiBase of apiBases) {
    const tokenResult = await getOneStoreAccessToken(apiBase);
    if (!tokenResult.ok) {
      errors.push({
        apiBase,
        error: tokenResult.error || "onestore_auth_failed",
        status: tokenResult.status || 0,
        data: tokenResult.data || null
      });
      continue;
    }
    const endpoint =
      `${apiBase}/v7/apps/${safeClientId}/` +
      `purchases/inapp/products/${safeProductId}/${safeToken}`;
    const headers = {
      Authorization: `Bearer ${tokenResult.accessToken}`,
      Accept: "application/json",
      "Content-Type": "application/json"
    };
    if (normalizedMarketCode) {
      headers["x-market-code"] = normalizedMarketCode;
    }

    const response = await fetchWithTimeout(
      endpoint,
      { method: "GET", headers },
      ONESTORE_API_TIMEOUT_MS
    );
    let payload = null;
    try {
      payload = await response.json();
    } catch (_) {
      payload = null;
    }
    if (!response.ok) {
      const apiErrorCode =
        payload?.error?.code || payload?.result?.code || payload?.code || "";
      errors.push({
        apiBase,
        error: `onestore_http_${response.status}`,
        status: response.status,
        apiErrorCode: String(apiErrorCode || ""),
        data: payload
      });
      continue;
    }

    const statusCode = Number.parseInt(payload?.status, 10);
    if (Number.isFinite(statusCode) && statusCode !== 0) {
      errors.push({
        apiBase,
        error: `onestore_status_${statusCode}`,
        data: payload
      });
      continue;
    }

    const purchaseState = Number.parseInt(payload?.purchaseState, 10);
    if (Number.isFinite(purchaseState) && purchaseState !== 0) {
      return { ok: false, error: "purchase_not_completed", data: payload };
    }

    return {
      ok: true,
      data: {
        orderId: payload?.purchaseId || payload?.orderId || "",
        purchaseTimeMillis:
          payload?.purchaseTime || payload?.purchaseTimeMillis || "",
        purchaseState: payload?.purchaseState,
        consumptionState: payload?.consumptionState,
        acknowledgementState: payload?.acknowledgeState,
        apiBaseUrl: apiBase,
        raw: payload
      }
    };
  }

  const firstError = errors[0] || {};
  return {
    ok: false,
    error: firstError.error || "onestore_verify_failed",
    data: { errors }
  };
}

async function applyIapRefundFromVoidedNotification({
  purchaseToken,
  orderId = "",
  refundType = null,
  productType = null,
  source = "rtdn_voided",
  storeType = "play"
}) {
  const db = getFirestore();
  if (!db) return { ok: false, error: "firestore_unavailable" };
  const normalizedStore = normalizeIapStoreType(storeType);
  const token = String(purchaseToken || "").trim();
  if (!token) return { ok: false, error: "missing_purchase_token" };

  const nowIso = new Date().toISOString();
  const fallbackDocId =
    buildIapPurchaseDocId({
      storeType: normalizedStore,
      purchaseToken: token
    }) || token;
  const purchaseRef =
    (await resolveIapPurchaseRefByToken({
      db,
      storeType: normalizedStore,
      purchaseToken: token
    })) || db.collection("iapPurchases").doc(fallbackDocId);
  let result = { ok: false };

  await db.runTransaction(async (tx) => {
    const purchaseSnap = await tx.get(purchaseRef);
    if (!purchaseSnap.exists) {
      tx.set(
        purchaseRef,
        {
          voided: true,
          voidedAt: nowIso,
          voidedOrderId: orderId || "",
          voidedRefundType: Number.isFinite(refundType) ? refundType : null,
          voidedProductType: Number.isFinite(productType) ? productType : null,
          refundProcessed: true,
          refundProcessedAt: nowIso,
          refundSource: source,
          refundError: "purchase_not_found",
          purchaseToken: token,
          storeType: normalizedStore
        },
        { merge: true }
      );
      result = {
        ok: false,
        error: "purchase_not_found",
        stored: true,
        storeType: normalizedStore
      };
      return;
    }
    const purchase = purchaseSnap.data() || {};
    if (purchase.refundProcessed || purchase.voided === true) {
      result = { ok: true, alreadyProcessed: true, storeType: normalizedStore };
      return;
    }
    const uid = String(purchase.uid || "").trim();
    const tokens = Number.parseInt(purchase.tokens, 10) || 0;
    if (!uid || tokens <= 0) {
      tx.set(
        purchaseRef,
        {
          voided: true,
          voidedAt: nowIso,
          voidedOrderId: orderId || purchase.orderId || "",
          voidedRefundType: Number.isFinite(refundType) ? refundType : null,
          voidedProductType: Number.isFinite(productType) ? productType : null,
          refundProcessed: true,
          refundProcessedAt: nowIso,
          refundSource: source,
          refundError: !uid ? "missing_uid" : "invalid_tokens",
          storeType: normalizeIapStoreType(purchase.storeType || normalizedStore),
          purchaseToken: token
        },
        { merge: true }
      );
      result = {
        ok: false,
        error: "invalid_purchase_record",
        storeType: normalizedStore
      };
      return;
    }
    const userRef = db.collection("users").doc(uid);
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      tx.set(
        purchaseRef,
        {
          voided: true,
          voidedAt: nowIso,
          voidedOrderId: orderId || purchase.orderId || "",
          voidedRefundType: Number.isFinite(refundType) ? refundType : null,
          voidedProductType: Number.isFinite(productType) ? productType : null,
          refundProcessed: true,
          refundProcessedAt: nowIso,
          refundSource: source,
          refundError: "user_not_found",
          storeType: normalizeIapStoreType(purchase.storeType || normalizedStore),
          purchaseToken: token
        },
        { merge: true }
      );
      result = { ok: false, error: "user_not_found", storeType: normalizedStore };
      return;
    }
    const userData = userSnap.data() || {};
    const currentBalance = Number.parseInt(userData.tokenBalance, 10) || 0;
    const ledger = Array.isArray(userData.tokenLedger)
      ? userData.tokenLedger.slice()
      : [];
    const entry = {
      timestamp: nowIso,
      amount: -tokens,
      type: "refund",
      description: purchase.productId
        ? `refund:${normalizeIapStoreType(
            purchase.storeType || normalizedStore
          )}:${purchase.productId}`
        : "refund",
      purchaseToken: token,
      orderId: orderId || purchase.orderId || ""
    };
    if (Number.isFinite(refundType)) {
      entry.refundType = refundType;
    }
    if (Number.isFinite(productType)) {
      entry.productType = productType;
    }
    ledger.unshift(entry);
    const newBalance = currentBalance - tokens;
    tx.set(
      userRef,
      {
        tokenBalance: newBalance,
        tokenLedger: ledger,
        updatedAt: nowIso
      },
      { merge: true }
    );
    tx.set(
      purchaseRef,
      {
        voided: true,
        voidedAt: nowIso,
        voidedOrderId: orderId || purchase.orderId || "",
        voidedRefundType: Number.isFinite(refundType) ? refundType : null,
        voidedProductType: Number.isFinite(productType) ? productType : null,
        refundProcessed: true,
        refundProcessedAt: nowIso,
        refundSource: source,
        refundedTokens: tokens,
        storeType: normalizeIapStoreType(purchase.storeType || normalizedStore),
        purchaseToken: token
      },
      { merge: true }
    );
    result = {
      ok: true,
      refundedTokens: tokens,
      uid,
      newBalance,
      storeType: normalizeIapStoreType(purchase.storeType || normalizedStore)
    };
  });

  return result;
}

function normalizeAdmobSignature(value) {
  if (!value) return "";
  let normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padding = normalized.length % 4;
  if (padding) {
    normalized += "=".repeat(4 - padding);
  }
  return normalized;
}

function parseRewardedSsvQuery(queryString) {
  const signatureParam = "signature=";
  const keyIdParam = "key_id=";
  const sigIndex = queryString.indexOf(signatureParam);
  if (sigIndex === -1) {
    throw new Error("missing_signature");
  }
  const contentEndIndex =
    sigIndex > 0 && queryString[sigIndex - 1] === "&"
      ? sigIndex - 1
      : sigIndex;
  const content = queryString.substring(0, contentEndIndex);
  const sigAndKeyId = queryString.substring(sigIndex);
  const keyIndex = sigAndKeyId.indexOf(keyIdParam);
  if (keyIndex === -1) {
    throw new Error("missing_key_id");
  }
  const signature = sigAndKeyId.substring(
    signatureParam.length,
    keyIndex - 1
  );
  const keyId = Number.parseInt(
    sigAndKeyId.substring(keyIndex + keyIdParam.length),
    10
  );
  if (!Number.isFinite(keyId)) {
    throw new Error("invalid_key_id");
  }
  return { content, signature, keyId };
}

async function verifyRewardedSsvSignature({ queryString }) {
  const { content, signature, keyId } = parseRewardedSsvQuery(queryString);
  const keys = await loadAdmobPublicKeys();
  const publicKey = keys.get(keyId);
  if (!publicKey) {
    return { ok: false, error: "unknown_key" };
  }
  const normalizedSignature = normalizeAdmobSignature(signature);
  const signatureBytes = Buffer.from(normalizedSignature, "base64");
  const dataBytes = Buffer.from(content, "utf8");
  const valid = crypto.verify("sha256", dataBytes, publicKey, signatureBytes);
  return { ok: valid, error: valid ? null : "invalid_signature" };
}

function normalizeGoogleRegion(region) {
  const upper = (region || "").toUpperCase();
  if (!upper || upper === "ALL") return upper;
  if (upper === "UK") return "GB";
  return upper;
}

function buildGoogleNewsUrl(keyword, lang, region) {
  const safeLang = (lang || "en").split("-")[0];
  const safeRegion = normalizeGoogleRegion(region) || "US";
  let query = encodeURIComponent(keyword);
  const isBreaking = isBreakingKeyword(keyword);
  query += isBreaking ? "+when:6h" : "+when:1d";
  if (!safeRegion || safeRegion === "ALL") {
    return `https://news.google.com/rss/search?q=${query}&hl=${safeLang}`;
  }
  return `https://news.google.com/rss/search?q=${query}&hl=${safeLang}-${safeRegion}&gl=${safeRegion}&ceid=${safeRegion}:${safeLang}`;
}

function buildGoogleTopStoriesUrl(lang, region) {
  const safeLang = (lang || "en").split("-")[0];
  const safeRegion = normalizeGoogleRegion(region) || "US";
  if (!safeRegion || safeRegion === "ALL") {
    return `https://news.google.com/rss?hl=${safeLang}`;
  }
  return `https://news.google.com/rss?hl=${safeLang}-${safeRegion}&gl=${safeRegion}&ceid=${safeRegion}:${safeLang}`;
}

function isBreakingKeyword(keyword) {
  const lower = (keyword || "").toLowerCase();
  return BREAKING_KEYWORDS.some((value) =>
    lower.includes(String(value).toLowerCase())
  );
}

async function resolveSearchKeyword(keyword, canonicalKeyword, feedLang) {
  const feedLangKey = (feedLang || "en").toLowerCase().split("-")[0];
  const baseKeyword = canonicalKeyword || keyword;
  if (!feedLangKey || feedLangKey === "en") {
    return baseKeyword || keyword;
  }
  const toTranslate = baseKeyword || keyword;
  if (!toTranslate) return keyword;
  try {
    const translated = await withRetries(
      () => translateText(toTranslate, feedLangKey),
      { label: "keyword_translate", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
    return translated || keyword;
  } catch (error) {
    console.error("[KeywordTranslate] failed", error);
    return keyword;
  }
}

function normalizeWhitespace(text) {
  return (text || "")
    .replace(/\s+/g, " ")
    .replace(/\u00a0/g, " ")
    .trim();
}

function hostFromUrl(value) {
  try {
    const parsed = new URL(value);
    const host = parsed.hostname || "";
    return host.startsWith("www.") ? host.slice(4) : host;
  } catch {
    return "";
  }
}

function isGoogleNewsHost(hostname) {
  if (!hostname) return false;
  const host = hostname.toLowerCase();
  return host === "news.google.com" || host.endsWith(".news.google.com");
}

function getProxyDispatcher(proxyUrl) {
  if (!proxyUrl) return null;
  const cached = proxyAgentCache.get(proxyUrl);
  if (cached) return cached;
  try {
    const agent = new ProxyAgent(proxyUrl);
    proxyAgentCache.set(proxyUrl, agent);
    return agent;
  } catch (error) {
    console.error("[Proxy] invalid proxy url", error?.message || error);
    return null;
  }
}

function resolveProxyDispatcher(url, options = {}) {
  const forceProxy = options.useProxy === true;
  if (options.useProxy === false) return null;
  const explicitProxy =
    typeof options.proxyUrl === "string" ? options.proxyUrl.trim() : "";
  if (explicitProxy) {
    return getProxyDispatcher(explicitProxy);
  }
  if (PROXY_ALL && DATAIMPULSE_PROXY_URL) {
    return getProxyDispatcher(DATAIMPULSE_PROXY_URL);
  }
  if (!PROXY_GOOGLE_NEWS_ONLY) return null;
  if (!GOOGLE_NEWS_PROXY_URL) return null;
  const host = hostFromUrl(url);
  if (isGoogleNewsHost(host)) {
    if (forceProxy) {
      return getProxyDispatcher(GOOGLE_NEWS_PROXY_URL);
    }
    if (shouldUseGoogleNewsProxy()) {
      return getProxyDispatcher(GOOGLE_NEWS_PROXY_URL);
    }
    return null;
  }
  return null;
}

function upgradeToHttps(url) {
  if (!url) return "";
  return url.startsWith("http://") ? `https://${url.slice(7)}` : url;
}

function deriveSourceUrl(item) {
  const source = item && item.source;
  return (
    source?.url ||
    source?.href ||
    source?.link ||
    source?.id ||
    ""
  );
}

function deriveSourceNameFromTitle(title) {
  if (!title) return "";
  const parts = title.split(" - ").map((part) => part.trim()).filter(Boolean);
  if (parts.length < 2) return "";
  const name = parts[parts.length - 1];
  const stripped = name.replace(/\s+뉴스$/, "");
  return stripped || name;
}

function resolveSourceFromItemFallback(options = {}) {
  const item = options.item || {};
  const baseUrl = options.url || "";
  const resolvedUrl = options.resolvedUrl || "";
  const rawSource = normalizeWhitespace(
    item.source?.title || item.source || item.creator || ""
  );
  if (rawSource && normalizeSourceKey(rawSource) !== "google news") {
    return rawSource;
  }
  const titleSource = deriveSourceNameFromTitle(
    normalizeWhitespace(item.title || "")
  );
  if (titleSource && normalizeSourceKey(titleSource) !== "google news") {
    return titleSource;
  }
  const derivedSourceUrl = upgradeToHttps(
    options.sourceUrl || deriveSourceUrl(item)
  );
  const rssExternalUrl = extractExternalUrlFromRssItem(item);
  const hostCandidates = [
    hostFromUrl(resolvedUrl),
    hostFromUrl(rssExternalUrl),
    hostFromUrl(derivedSourceUrl),
    hostFromUrl(baseUrl)
  ];
  for (const host of hostCandidates) {
    if (!host || isGoogleHost(host)) continue;
    return formatSourceLabel(host);
  }
  return rawSource || "Unknown Source";
}

function isGoogleHost(hostname) {
  if (!hostname) return false;
  const host = hostname.toLowerCase();
  return host.includes("news.google.com") || host.endsWith(".google.com");
}

const SECOND_LEVEL_TLDS = new Set([
  "co.uk",
  "co.jp",
  "co.kr",
  "co.in",
  "co.nz",
  "com.au",
  "com.br",
  "com.mx",
  "com.tr",
  "com.sa",
  "com.cn",
  "com.tw",
  "com.fr",
  "com.es",
  "com.ru",
  "net.ru",
  "com.ae",
  "com.eg",
  "com.qa",
  "org.ae",
  "ne.jp",
  "or.kr",
  "org.uk",
  "com.sg",
  "com.my"
]);

function normalizeHostname(hostname) {
  return String(hostname || "")
    .toLowerCase()
    .trim()
    .replace(/\.+$/, "");
}

function stripCommonSubdomain(hostname) {
  return String(hostname || "").replace(/^(www\d*|m)\./, "");
}

function getRegistrableDomain(hostname) {
  if (!hostname) return "";
  const parts = String(hostname).toLowerCase().split(".").filter(Boolean);
  if (parts.length <= 2) return parts.join(".");
  const lastTwo = parts.slice(-2).join(".");
  if (SECOND_LEVEL_TLDS.has(lastTwo) && parts.length >= 3) {
    return parts.slice(-3).join(".");
  }
  return parts.slice(-2).join(".");
}

function getHostnameVariants(hostname) {
  const normalized = normalizeHostname(hostname);
  if (!normalized) return [];
  const variants = new Set([normalized]);
  const stripped = stripCommonSubdomain(normalized);
  if (stripped) {
    variants.add(stripped);
  }
  const registrable = getRegistrableDomain(stripped || normalized);
  if (registrable) {
    variants.add(registrable);
  }
  return Array.from(variants);
}

function extractRootDomain(hostname) {
  if (!hostname) return "";
  const parts = hostname.toLowerCase().split(".").filter(Boolean);
  if (parts.length <= 2) return parts[0] || "";
  const lastTwo = parts.slice(-2).join(".");
  if (SECOND_LEVEL_TLDS.has(lastTwo)) {
    return parts[parts.length - 3] || "";
  }
  return parts[parts.length - 2] || "";
}

function formatSourceLabel(hostname) {
  const root = extractRootDomain(hostname);
  if (!root) return hostname || "";
  const words = root.split(/[-_]/g).filter(Boolean);
  if (!words.length) return hostname || "";
  const label = words
    .map((word) => {
      if (word.length <= 4) return word.toUpperCase();
      return word.charAt(0).toUpperCase() + word.slice(1);
    })
    .join(" ");
  return label || hostname || "";
}

function stripHtmlTags(value) {
  return (value || "").replace(/<[^>]*>/g, " ");
}

function decodeHtmlEntities(value) {
  if (!value) return "";
  const named = {
    amp: "&",
    lt: "<",
    gt: ">",
    quot: "\"",
    apos: "'",
    nbsp: " "
  };
  return value.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (match, code) => {
    if (!code) return match;
    if (code[0] === "#") {
      const hex = code[1] && code[1].toLowerCase() === "x";
      const raw = hex ? code.slice(2) : code.slice(1);
      const parsed = parseInt(raw, hex ? 16 : 10);
      if (!Number.isFinite(parsed)) return match;
      return String.fromCodePoint(parsed);
    }
    const mapped = named[code.toLowerCase()];
    return mapped !== undefined ? mapped : match;
  });
}

function normalizeHtmlText(value) {
  return normalizeWhitespace(decodeHtmlEntities(stripHtmlTags(value)));
}

function parseGdeltDateToIso(value) {
  const match = String(value || "").match(
    /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/
  );
  if (!match) return "";
  const [, year, month, day, hour, minute, second] = match;
  const iso = new Date(
    Date.UTC(
      Number(year),
      Number(month) - 1,
      Number(day),
      Number(hour),
      Number(minute),
      Number(second)
    )
  ).toISOString();
  return iso || "";
}

function shouldUseNaverNews(region, feedLang, query) {
  if (!ENABLE_NAVER_NEWS) return false;
  if (!NAVER_CLIENT_ID || !NAVER_CLIENT_SECRET) {
    if (!naverMissingKeyWarned) {
      console.warn("[Naver] missing client id/secret");
      naverMissingKeyWarned = true;
    }
    return false;
  }
  const normalizedRegion = (region || "").toUpperCase();
  const langKey = normalizeLangCode(feedLang || "en");
  if (normalizedRegion === "KR") return Boolean(query);
  if (langKey.startsWith("ko")) return Boolean(query);
  return false;
}

function buildGdeltUrl(query, maxRecords, timespan) {
  const safeQuery = encodeURIComponent(query || "");
  const safeMax = Math.max(1, Math.min(250, Number(maxRecords) || 30));
  const safeTimespan = encodeURIComponent(timespan || "1d");
  return `https://api.gdeltproject.org/api/v2/doc/doc?query=${safeQuery}&mode=artlist&format=json&maxrecords=${safeMax}&timespan=${safeTimespan}&sort=datedesc`;
}

function getBreakingRegionTerms(region, feedLang) {
  const key = normalizeRegionCode(region || "", "");
  const lang = normalizeLangCode(feedLang || "");
  const terms = new Set();
  terms.add("breaking news");
  terms.add("breaking");
  if (key === "KR" || lang === "ko") terms.add("속보");
  if (key === "JP" || lang === "ja") terms.add("速報");
  if (key === "FR" || lang === "fr") terms.add("dernières nouvelles");
  if (key === "ES" || lang === "es") terms.add("última hora");
  if (key === "RU" || lang === "ru") terms.add("срочные новости");
  if (key === "AE" || lang === "ar") terms.add("أخبار عاجلة");
  return Array.from(terms).filter(Boolean);
}

function normalizeGdeltTerm(term) {
  const normalized = normalizeWhitespace(term || "");
  if (!normalized) return "";
  const needsQuotes = /\s/.test(normalized);
  if (needsQuotes) {
    return `"${normalized.replace(/"/g, "")}"`;
  }
  return normalized;
}

function buildGdeltQuery({ keyword, searchKeyword, region, feedLang, breakingRequest }) {
  const terms = new Set();
  const cleanKeyword = normalizeWhitespace(keyword || "");
  const cleanSearch = normalizeWhitespace(searchKeyword || "");
  if (breakingRequest) {
    getBreakingRegionTerms(region, feedLang).forEach((term) => terms.add(term));
  } else {
    if (cleanKeyword) terms.add(cleanKeyword);
    if (cleanSearch && cleanSearch !== cleanKeyword) terms.add(cleanSearch);
  }
  const normalizedTerms = Array.from(terms)
    .map((term) => normalizeGdeltTerm(term))
    .filter(Boolean);
  if (!normalizedTerms.length) return "news";
  return normalizedTerms.slice(0, 5).join(" OR ");
}

function buildNaverNewsUrl(query, display, sort = "date") {
  const safeQuery = encodeURIComponent(query || "");
  const safeDisplay = Math.max(1, Math.min(100, Number(display) || 10));
  const safeSort = (sort || "date").toLowerCase() === "sim" ? "sim" : "date";
  return `https://openapi.naver.com/v1/search/news.json?query=${safeQuery}&display=${safeDisplay}&start=1&sort=${safeSort}`;
}

async function fetchGdeltItems({ query, maxRecords, timespan }) {
  const cleanQuery = normalizeWhitespace(query || "");
  if (!cleanQuery) return [];
  const url = buildGdeltUrl(cleanQuery, maxRecords, timespan);
  const response = await fetchWithTimeout(
    url,
    {
      headers: {
        "User-Agent": "news-crawl-server"
      }
    },
    TASK_TIMEOUT_MS
  );
  if (!response.ok) {
    throw new Error(`gdelt_status_${response.status}`);
  }
  const data = await response.json();
  const articles = Array.isArray(data?.articles) ? data.articles : [];
  return articles
    .map((article) => {
      const title = normalizeWhitespace(article?.title || "");
      const link = upgradeToHttps(article?.url || "");
      if (!title || !link) return null;
      const domain = normalizeWhitespace(article?.domain || "");
      const sourceHost = domain || hostFromUrl(link);
      const sourceLabel = sourceHost ? formatSourceLabel(sourceHost) : "";
      const source = sourceHost
        ? {
            title: sourceLabel || sourceHost,
            url: `https://${sourceHost}`
          }
        : { title: sourceLabel || "Unknown Source" };
      const gdeltSourceCountry = normalizeWhitespace(article?.sourcecountry || "");
      return {
        title,
        link,
        contentSnippet: "",
        content: "",
        isoDate: parseGdeltDateToIso(article?.seendate || ""),
        source,
        gdeltSourceCountry,
        gdeltRegion: resolveGdeltRegion(gdeltSourceCountry),
        gdeltLanguage: normalizeWhitespace(article?.language || "")
      };
    })
    .filter(Boolean);
}

async function fetchNaverNewsItems({ query, display, sort }) {
  const cleanQuery = normalizeWhitespace(query || "");
  if (!cleanQuery) return [];
  const url = buildNaverNewsUrl(cleanQuery, display, sort);
  const response = await fetchWithTimeout(
    url,
    {
      headers: {
        "User-Agent": "news-crawl-server",
        "X-Naver-Client-Id": NAVER_CLIENT_ID,
        "X-Naver-Client-Secret": NAVER_CLIENT_SECRET
      }
    },
    TASK_TIMEOUT_MS
  );
  if (!response.ok) {
    throw new Error(`naver_status_${response.status}`);
  }
  const data = await response.json();
  const items = Array.isArray(data?.items) ? data.items : [];
  return items
    .map((item) => {
      const title = normalizeHtmlText(item?.title || "");
      const description = normalizeHtmlText(item?.description || "");
      const link = upgradeToHttps(item?.originallink || item?.link || "");
      if (!title || !link) return null;
      const sourceHost = hostFromUrl(link);
      const sourceLabel = sourceHost ? formatSourceLabel(sourceHost) : "";
      const source = sourceHost
        ? {
            title: sourceLabel || sourceHost,
            url: `https://${sourceHost}`
          }
        : { title: sourceLabel || "Unknown Source" };
      return {
        title,
        link,
        contentSnippet: description,
        content: "",
        pubDate: item?.pubDate || "",
        source
      };
    })
    .filter(Boolean);
}

function shouldIncludeStaticRssSource(source, region) {
  if (!source || !source.url) return false;
  const normalizedRegion = normalizeRegionCode(region || "ALL", "ALL");
  const sourceRegion = normalizeRegionCode(source.region || "ALL", "ALL");
  if (normalizedRegion === "ALL") return true;
  return sourceRegion === normalizedRegion;
}

async function fetchStaticRssItems(source) {
  if (!source || !source.url) return [];
  const feed = await fetchRssFeed(source.url, {
    timeoutMs: TASK_TIMEOUT_MS,
    lang: source.feedLang || "",
    region: source.region || ""
  });
  const items = Array.isArray(feed?.items) ? feed.items : [];
  if (!items.length) return [];
  const sourceTitle = normalizeWhitespace(source.name || source.id || "");
  const sourceUrl = upgradeToHttps(source.sourceUrl || "") || source.url;
  return items.map((item) => ({
    ...item,
    source: {
      title: sourceTitle || item?.source?.title || item?.creator || "Unknown Source",
      url:
        sourceUrl ||
        item?.source?.url ||
        item?.source?.link ||
        item?.source?.href ||
        ""
    },
    sourceRegion: normalizeRegionCode(source.region || "", "")
  }));
}

async function fetchExtraNewsItems(options = {}) {
  const keyword = normalizeWhitespace(options.keyword || "");
  const searchKeyword = normalizeWhitespace(options.searchKeyword || keyword);
  const region = normalizeRegionCode(options.region || "ALL", "ALL");
  const feedLang = normalizeLangCode(options.feedLang || "en");
  const limit = Math.min(parseInt(options.limit || "10", 10), 20);
  const isBreaking = options.breakingRequest === true;
  const extraQuery = normalizeWhitespace(searchKeyword || keyword);
  const sources = getEffectiveCrawlSources(options.sources);
  const tasks = [];
  if (sources.gdelt && extraQuery) {
    const maxRecords = Math.max(10, Math.min(GDELT_MAX_RECORDS, limit * 3));
    const gdeltQuery = buildGdeltQuery({
      keyword,
      searchKeyword: extraQuery,
      region,
      feedLang,
      breakingRequest: isBreaking
    });
    const timespan = isBreaking
      ? (gdeltQuery === "news" ? "6h" : "1d")
      : GDELT_TIMESPAN;
    tasks.push({
      label: "gdelt_fetch",
      task: () =>
        fetchGdeltItems({
          query: gdeltQuery,
          maxRecords,
          timespan
        })
    });
  }
  if (sources.naver && shouldUseNaverNews(region, feedLang, extraQuery)) {
    const display = Math.max(10, Math.min(NAVER_NEWS_DISPLAY, limit * 3));
    tasks.push({
      label: "naver_fetch",
      task: () =>
        fetchNaverNewsItems({
          query: extraQuery,
          display,
          sort: "date"
        })
    });
  }
  if (!tasks.length) return [];
  const results = await Promise.allSettled(
    tasks.map((entry) =>
      withRetries(entry.task, {
        label: entry.label,
        timeoutMs: TASK_TIMEOUT_MS
      })
    )
  );
  const merged = [];
  for (let index = 0; index < results.length; index += 1) {
    const result = results[index];
    const label = tasks[index]?.label || "extra_fetch";
    if (result.status === "fulfilled" && Array.isArray(result.value)) {
      merged.push(...result.value);
      if (label === "gdelt_fetch") {
        try {
          const domains = Array.from(
            new Set(
              result.value
                .filter((item) => {
                  const itemRegion = normalizeRegionCode(
                    item?.gdeltRegion || "",
                    ""
                  );
                  if (!itemRegion) return false;
                  return itemRegion === normalizeRegionCode(region || "", "");
                })
                .map((item) => {
                  const sourceUrl = item?.source?.url || "";
                  const link = item?.link || "";
                  const host = hostFromUrl(sourceUrl) || hostFromUrl(link);
                  const domain = normalizeDomainForAllowlist(host);
                  return domain;
                })
                .filter(Boolean)
            )
          );
          if (domains.length) {
            await recordDynamicRegionSources(region, domains);
          }
        } catch (error) {
          console.error("[DynamicAllowlist] gdelt record failed", error?.message || error);
        }
      }
      continue;
    }
    const error =
      result.status === "rejected" ? result.reason : "unknown_error";
    console.error(`[ExtraSource] ${label} failed`, error?.message || error);
  }
  return merged;
}

async function fetchStaticFallbackRssItems(options = {}) {
  const keyword = normalizeWhitespace(options.keyword || "");
  const searchKeyword = normalizeWhitespace(options.searchKeyword || keyword);
  const region = normalizeRegionCode(options.region || "ALL", "ALL");
  const limit = Math.min(parseInt(options.limit || "10", 10), 20);
  const isBreaking = options.breakingRequest === true;
  const fastMode = options.fastMode === true;
  const extraQuery = normalizeWhitespace(searchKeyword || keyword);

  if (fastMode) return [];
  if (!region || region === "ALL") return [];

  const tasks = [];
  EXTRA_RSS_SOURCES.forEach((source) => {
    if (!shouldIncludeStaticRssSource(source, region)) return;
    tasks.push({
      label: `rss_${source.id}`,
      task: async () => {
        const items = await fetchStaticRssItems(source);
        if (isBreaking || !extraQuery) return items;
        return items.filter((item) => {
          const title = normalizeWhitespace(item?.title || "");
          const summary = normalizeWhitespace(
            item?.contentSnippet || item?.content || ""
          );
          return keywordRelevanceScore(extraQuery, title, summary) > 0;
        });
      }
    });
  });
  if (!tasks.length) return [];

  const results = await Promise.allSettled(
    tasks.map((entry) =>
      withRetries(entry.task, {
        label: entry.label,
        timeoutMs: TASK_TIMEOUT_MS
      })
    )
  );
  const merged = [];
  for (let index = 0; index < results.length; index += 1) {
    const result = results[index];
    const label = tasks[index]?.label || "rss_fetch";
    if (result.status === "fulfilled" && Array.isArray(result.value)) {
      merged.push(...result.value);
      continue;
    }
    const error =
      result.status === "rejected" ? result.reason : "unknown_error";
    console.error(`[StaticRSS] ${label} failed`, error?.message || error);
  }

  // Cap to avoid excessive downstream processing when many feeds are enabled.
  // This is called only when we're already below the target `limit`.
  const cap = Math.max(20, Math.min(40, limit * 2));
  return merged.length > cap ? merged.slice(0, cap) : merged;
}

function normalizeSourceKey(value) {
  return String(value || "").toLowerCase().trim();
}

function buildAcceptLanguageHeader(lang, region) {
  const parts = [];
  const normalizedLang = normalizeLangCode(lang || "");
  const normalizedRegion = normalizeRegionCode(region || "");
  if (normalizedLang) {
    if (normalizedRegion) {
      parts.push(`${normalizedLang}-${normalizedRegion}`);
    }
    parts.push(normalizedLang);
  }
  if (normalizedLang !== "en") {
    parts.push("en-US");
    parts.push("en");
  }
  if (normalizedLang !== "ko") {
    parts.push("ko-KR");
    parts.push("ko");
  }
  const unique = Array.from(new Set(parts.filter(Boolean)));
  if (!unique.length) return "";
  return unique
    .map((value, index) => (index === 0 ? value : `${value};q=${(1 - index * 0.1).toFixed(1)}`))
    .join(",");
}

function isAllowlistedByNameInSet(normalizedName, allowSet) {
  if (!normalizedName) return false;
  for (const entry of allowSet) {
    if (!entry || entry.includes(".")) continue;
    if (normalizedName.includes(entry)) return true;
  }
  return false;
}

function isAllowlistedByName(normalizedName) {
  return isAllowlistedByNameInSet(normalizedName, sourceAllowlist);
}

function isSourceAllowedForRegion(
  region,
  { sourceName, sourceUrl, resolvedUrl, sourceRegion }
) {
  const key = (region || "").toUpperCase();
  if (!key || key === "ALL") return true;
  const normalizedSourceRegion = normalizeRegionCode(sourceRegion || "", "");
  if (normalizedSourceRegion && normalizedSourceRegion === key) {
    return true;
  }
  const allowSet = regionAllowlist.get(key);
  const dynamicSet = dynamicRegionAllowlist.get(key);
  if (
    (!allowSet || allowSet.size === 0) &&
    (!dynamicSet || dynamicSet.size === 0)
  ) {
    return true;
  }

  const sourceDomain = hostFromUrl(sourceUrl);
  if (sourceDomain) {
    const variants = getHostnameVariants(sourceDomain);
    if (variants.some((value) => allowSet?.has(value) || dynamicSet?.has(value))) {
      return true;
    }
  }
  const resolvedDomain = hostFromUrl(resolvedUrl);
  if (resolvedDomain) {
    const variants = getHostnameVariants(resolvedDomain);
    if (variants.some((value) => allowSet?.has(value) || dynamicSet?.has(value))) {
      return true;
    }
  }

  const normalizedName = normalizeSourceKey(sourceName);
  if (!normalizedName) return false;
  if (allowSet?.has(normalizedName)) return true;
  if (allowSet) {
    return isAllowlistedByNameInSet(normalizedName, allowSet);
  }
  return false;
}

function makeSourceDocId(key) {
  return crypto.createHash("sha256").update(`source::${key}`).digest("hex");
}

async function getSourceModerationDecision(sourceKey) {
  if (!sourceKey) return null;
  const cached = sourceModerationCache.get(sourceKey);
  if (cached !== undefined) return cached;
  const db = getFirestore();
  if (!db) return null;
  try {
    const docId = makeSourceDocId(sourceKey);
    const doc = await db.collection("source_moderation").doc(docId).get();
    if (!doc.exists) {
      sourceModerationCache.set(sourceKey, null);
      return null;
    }
    const data = doc.data() || {};
    if (data.denied === true) {
      sourceModerationCache.set(sourceKey, false);
      return false;
    }
    if (data.allowed === true) {
      sourceModerationCache.set(sourceKey, true);
      return true;
    }
  } catch (error) {
    console.error("[SourceModeration] read failed", error);
  }
  sourceModerationCache.set(sourceKey, null);
  return null;
}

async function evaluateSourceWithAI(sourceLabel) {
  if (!sourceLabel) return true;
  const cacheKey = normalizeSourceKey(sourceLabel);
  if (sourceRatingCache.has(cacheKey)) {
    return sourceRatingCache.get(cacheKey);
  }
  if (sourceAllowlist.has(cacheKey)) {
    sourceRatingCache.set(cacheKey, true);
    return true;
  }
  if (isAllowlistedByName(cacheKey)) {
    sourceRatingCache.set(cacheKey, true);
    return true;
  }
  if (sourceDenylist.has(cacheKey)) {
    sourceRatingCache.set(cacheKey, false);
    return false;
  }

  try {
    const response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_MODEL,
        messages: [
          {
            role: "system",
            content:
              "You are a news media evaluator. The user will give you a news source name or domain. If it is a major, reliable, credible, or well-known niche publication (Grade A or B), reply with 'PASS'. If it is a tabloid, spam, promotional, clickbait, or unknown low-quality source (Grade C), reply with 'FAIL'. Reply ONLY with 'PASS' or 'FAIL'."
          },
          { role: "user", content: sourceLabel }
        ],
        temperature: 0,
        max_tokens: 5
      },
      { label: "source_eval", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
    if (!response.ok) {
      const errorBody = await response.text().catch(() => "");
      console.error(
        `[AI Judge] error ${response.status}: ${errorBody.slice(0, 200)}`
      );
      return true;
    }
    const data = await response.json();
    const result =
      data?.choices?.[0]?.message?.content?.trim()?.toUpperCase() || "";
    const isTrusted = result.includes("PASS");
    sourceRatingCache.set(cacheKey, isTrusted);
    return isTrusted;
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`[AI Judge] Error ${JSON.stringify(payload)}`);
    return true;
  }
}

async function isTrustedSource({ sourceName, sourceUrl, resolvedUrl }) {
  const sourceDomain = hostFromUrl(sourceUrl);
  if (sourceDomain && !isGoogleHost(sourceDomain)) {
    const decision = await getSourceModerationDecision(sourceDomain);
    if (decision !== null) return decision;
    return evaluateSourceWithAI(sourceDomain);
  }
  const resolvedDomain = hostFromUrl(resolvedUrl);
  if (resolvedDomain && !isGoogleHost(resolvedDomain)) {
    const decision = await getSourceModerationDecision(resolvedDomain);
    if (decision !== null) return decision;
    return evaluateSourceWithAI(resolvedDomain);
  }
  const normalizedName = normalizeSourceKey(sourceName);
  if (!normalizedName) return true;
  const decision = await getSourceModerationDecision(normalizedName);
  if (decision !== null) return decision;
  return evaluateSourceWithAI(normalizedName);
}

const BLACKLIST_KEYWORDS = [
  "free money",
  "risk-free",
  "porn",
  "xxx",
  "sex",
  "camgirl",
  "escort",
  "click here",
  "buy now",
  "subscribe now",
  "limited time",
  "promo code",
  "sponsored content",
  "press release",
  "giveaway",
  "advertorial",
  "advertisement",
  "promo",
  "coupon",
  "coupon code",
  "deal",
  "sponsored",
  "paid content",
  "casino bonus",
  "odds",
  "sportsbook",
  "bookmaker",
  "바카라",
  "홀덤",
  "릴게임",
  "슬롯",
  "파워볼",
  "야동",
  "19금",
  "조건만남",
  "출장안마",
  "유흥",
  "구독",
  "이벤트",
  "홍보",
  "협찬",
  "쿠폰",
  "딜",
  "특별가",
  "리딩방",
  "추천주",
  "급등주",
  "수익률 보장",
  "무료추천",
  "종목추천",
  "대박주",
  "상한가"
];

const BLACKLIST_ALLOWLIST = [
  "accident",
  "crash",
  "fatal",
  "killed",
  "death",
  "policy",
  "regulation",
  "ban",
  "crackdown",
  "lawsuit",
  "trial",
  "arrest",
  "investigation",
  "fraud",
  "scam",
  "court",
  "사고",
  "사망",
  "사망자",
  "정책",
  "규제",
  "단속",
  "수사",
  "재판",
  "법원",
  "금지"
];

function isBlacklisted(title, summary) {
  const text = normalizeWhitespace(`${title || ""} ${summary || ""}`).toLowerCase();
  if (!text) return false;
  const hit = BLACKLIST_KEYWORDS.some((keyword) => text.includes(keyword));
  if (!hit) return false;
  const allow = BLACKLIST_ALLOWLIST.some((keyword) => text.includes(keyword));
  return !allow;
}

function keywordKey(keyword) {
  return normalizeWhitespace(keyword).toLowerCase();
}

function makeKeywordDocId(keyword) {
  return crypto.createHash("sha256").update(keywordKey(keyword)).digest("hex");
}

function makeNewsCacheId(keyword, region, feedLang, lang, limit) {
  const safeRegion = normalizeRegionCode(region, "ALL");
  const safeFeedLang = normalizeLangCode(feedLang || lang || "en");
  const safeLang = normalizeLangCode(lang || "en");
  const key = `${keywordKey(keyword)}::${safeRegion}::${safeFeedLang}::${safeLang}::${limit}`;
  return crypto.createHash("sha256").update(key).digest("hex");
}

async function getCachedNewsMeta(cacheId) {
  const db = getFirestore();
  if (!db) return null;
  const doc = await db.collection("news_cache").doc(cacheId).get();
  if (!doc.exists) return null;
  const data = doc.data();
  const fetchedAt = data?.fetchedAt ? Date.parse(data.fetchedAt) : null;
  if (!fetchedAt || Number.isNaN(fetchedAt)) return null;
  const ageMs = Date.now() - fetchedAt;
  return { data, ageMs };
}

async function getCachedNews(cacheId) {
  const meta = await getCachedNewsMeta(cacheId);
  if (!meta) return null;
  if (meta.ageMs > NEWS_CACHE_TTL_MS) return null;
  return meta.data;
}

async function setCachedNews(cacheId, payload) {
  const db = getFirestore();
  if (!db) return;
  const nowMs = Date.now();
  await db.collection("news_cache").doc(cacheId).set(
    {
      ...payload,
      fetchedAt: new Date(nowMs).toISOString(),
      expiresAt: cacheExpiresAt(nowMs)
    },
    { merge: true }
  );
}

async function acquireCronLock(lockId, ttlMs = CRON_LOCK_TTL_MS) {
  const db = getFirestore();
  if (!db) return { ok: false, error: "firestore_unavailable" };
  const ref = db.collection("cron_locks").doc(lockId);
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const runId = crypto.randomBytes(16).toString("hex");
  let locked = false;
  let existing = null;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() || {} : {};
    const lockedAtMs = data.lockedAt ? Date.parse(data.lockedAt) : 0;
    const expired =
      !lockedAtMs || Number.isNaN(lockedAtMs) || nowMs - lockedAtMs > ttlMs;
    if (data.locked && !expired) {
      locked = true;
      existing = data;
      return;
    }
    tx.set(
      ref,
      {
        locked: true,
        lockedAt: nowIso,
        expiresAt: new Date(nowMs + ttlMs).toISOString(),
        runId
      },
      { merge: true }
    );
  });

  if (locked) {
    return {
      ok: false,
      error: "locked",
      lockedAt: existing?.lockedAt || null,
      expiresAt: existing?.expiresAt || null,
      runId: existing?.runId || null
    };
  }

  return { ok: true, runId };
}

async function releaseCronLock(lockId, runId) {
  const db = getFirestore();
  if (!db) return;
  const ref = db.collection("cron_locks").doc(lockId);
  const nowIso = new Date().toISOString();
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data() || {};
    if (data.runId && data.runId !== runId) return;
    tx.set(
      ref,
      {
        locked: false,
        unlockedAt: nowIso
      },
      { merge: true }
    );
  });
}

async function cleanupOldNewsCache(options = {}) {
  const db = getFirestore();
  if (!db) return { deleted: 0 };
  const batchSize = Math.min(Math.max(Number(options.batchSize) || 300, 50), 500);
  const cutoffIso = new Date(
    Date.now() - 3 * 24 * 60 * 60 * 1000
  ).toISOString();
  let deleted = 0;

  while (true) {
    const snap = await db
      .collection("news_cache")
      .where("fetchedAt", "<", cutoffIso)
      .limit(batchSize)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
    if (snap.size < batchSize) break;
  }

  return { deleted, cutoffIso };
}

function parseDateIso(value) {
  if (!value) return "";
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return "";
    return value.toISOString();
  }
  if (typeof value?.toDate === "function") {
    const date = value.toDate();
    if (date instanceof Date && !Number.isNaN(date.getTime())) {
      return date.toISOString();
    }
  }
  if (typeof value === "object") {
    const seconds = Number(value.seconds ?? value._seconds);
    const nanos = Number(value.nanoseconds ?? value._nanoseconds) || 0;
    if (Number.isFinite(seconds) && seconds > 0) {
      const ms = seconds * 1000 + Math.floor(nanos / 1e6);
      return new Date(ms).toISOString();
    }
  }
  const parsed = Date.parse(String(value));
  if (Number.isNaN(parsed)) return "";
  return new Date(parsed).toISOString();
}

function parsePositiveMs(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return null;
  return Math.round(parsed);
}

function estimateProcessingEtaMinutes(processingDurationMs) {
  const durationMs = parsePositiveMs(processingDurationMs);
  if (!durationMs) return PROCESSING_ETA_DEFAULT_MINUTES;
  const estimated = Math.ceil(durationMs / (60 * 1000));
  return Math.max(
    PROCESSING_ETA_MIN_MINUTES,
    Math.min(PROCESSING_ETA_MAX_MINUTES, estimated)
  );
}

function blendProcessingDurationMs(previousDurationMs, observedDurationMs) {
  const previous = parsePositiveMs(previousDurationMs);
  const observed = parsePositiveMs(observedDurationMs);
  if (!observed) return previous;
  if (!previous) return observed;
  return Math.round(
    previous * (1 - PROCESSING_DURATION_SMOOTHING) +
      observed * PROCESSING_DURATION_SMOOTHING
  );
}

function computeObservedProcessingDurationMsFromItems(items, nowMs = Date.now()) {
  if (!Array.isArray(items) || !items.length) return null;
  const durations = [];
  for (const item of items) {
    if (!item?.processing) continue;
    const startedAtIso = parseDateIso(item.processingStartedAt);
    if (!startedAtIso) continue;
    const startedAtMs = Date.parse(startedAtIso);
    if (!Number.isFinite(startedAtMs)) continue;
    const elapsedMs = nowMs - startedAtMs;
    if (elapsedMs < PROCESSING_OBSERVED_MIN_MS) continue;
    if (elapsedMs > PROCESSING_OBSERVED_MAX_MS) continue;
    durations.push(elapsedMs);
  }
  if (!durations.length) return null;
  durations.sort((a, b) => a - b);
  const middleIndex = Math.floor((durations.length - 1) / 2);
  return Math.round(durations[middleIndex]);
}

function normalizeTabExpiryMap(raw) {
  const output = {};
  if (!raw || typeof raw !== "object") return output;
  for (const [key, value] of Object.entries(raw)) {
    const index = Number.parseInt(key, 10);
    if (!Number.isFinite(index)) continue;
    const iso = parseDateIso(value);
    if (iso) {
      output[String(index)] = iso;
    }
  }
  return output;
}

function normalizeAutoRenewedExpiryMap(raw) {
  const output = {};
  if (!raw || typeof raw !== "object") return output;
  for (const [key, value] of Object.entries(raw)) {
    const index = Number.parseInt(key, 10);
    if (!Number.isFinite(index)) continue;
    const iso = parseDateIso(value);
    if (iso) {
      output[String(index)] = iso;
    }
  }
  return output;
}

function normalizeAutoRenewAttemptMap(raw) {
  const output = {};
  if (!raw || typeof raw !== "object") return output;
  for (const [key, value] of Object.entries(raw)) {
    const index = Number.parseInt(key, 10);
    if (!Number.isFinite(index)) continue;
    const iso = parseDateIso(value);
    if (iso) {
      output[String(index)] = iso;
    }
  }
  return output;
}

function formatAutoRenewTabLabel(lang, index) {
  const label = String(index);
  switch (lang) {
    case "ko":
      return `${label}번 탭`;
    case "ja":
      return `${label}タブ`;
    case "fr":
      return `Onglet ${label}`;
    case "es":
      return `Pestaña ${label}`;
    case "ru":
      return `Вкладка ${label}`;
    case "ar":
      return `تبويب ${label}`;
    default:
      return `Tab ${label}`;
  }
}

function formatAutoRenewCountLabel(lang, count) {
  switch (lang) {
    case "ko":
      return `${count}개 탭`;
    case "ja":
      return `${count}タブ`;
    case "fr":
      return `${count} onglets`;
    case "es":
      return `${count} pestañas`;
    case "ru":
      return `${count} вкладки`;
    case "ar":
      return `${count} تبويب`;
    default:
      return `${count} tabs`;
  }
}

function formatAutoRenewTabs(lang, indexes) {
  if (!Array.isArray(indexes) || !indexes.length) return "";
  const labels = indexes.map((index) => formatAutoRenewTabLabel(lang, index));
  return labels.join(", ");
}

const AUTO_RENEW_PUSH_TEXT = {
  en: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "Auto renewal failed",
    failureBody: "Auto renewal failed due to insufficient tokens."
  },
  ko: {
    successTitle: "자동 결제 성공",
    successBody: (tabs) => `${tabs} 자동 결제 성공, 30일 연장되었습니다.`,
    failureTitle: "자동 결제 실패",
    failureBody: "토큰이 부족하여 자동 결제가 실패했습니다."
  },
  es: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "Fallo de renovación automática",
    failureBody: "La renovación automática falló por falta de tokens."
  },
  fr: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "Renouvellement automatique échoué",
    failureBody: "Le renouvellement automatique a échoué faute de jetons."
  },
  ja: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "自動更新に失敗",
    failureBody: "トークン不足のため自動更新に失敗しました。"
  },
  ru: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "Автопродление не удалось",
    failureBody: "Автопродление не удалось из-за нехватки токенов."
  },
  ar: {
    successTitle: "Auto renewal success",
    successBody: (tabs) => `${tabs} auto renewal succeeded and extended 30 days.`,
    failureTitle: "فشل التجديد التلقائي",
    failureBody: "الرموز غير كافية، تم إيقاف التجديد التلقائي."
  }
};

async function upsertUserFcmToken(db, uid, token, languageValue) {
  if (!db || !token) return;
  const safeUid = normalizeWhitespace(uid || "");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");
  const payload = {
    token,
    lastSeenAt: new Date().toISOString()
  };
  if (safeUid) {
    payload.uid = safeUid;
  }
  if (languageValue) {
    payload.language = languageValue;
  }
  await db.collection("user_fcm_tokens").doc(tokenHash).set(payload, { merge: true });
}

async function sendAutoRenewPushToUser(options = {}) {
  const uid = String(options.uid || "").trim();
  if (!uid) return;
  const db = getFirestore();
  const messaging = getFirebaseMessaging();
  if (!db || !messaging) return;
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return;
  const userData = userSnap.data() || {};
  const lang = normalizeLangCode(
    options.lang || userData.language || userData.lang || "en"
  );
  const success = options.success === true;
  if (!success) {
    const lastFail = Date.parse(userData.autoRenewFailureNotifiedAt || "");
    if (
      lastFail &&
      Date.now() - lastFail < AUTO_RENEW_FAILURE_NOTIFY_COOLDOWN_MS
    ) {
      return;
    }
  }
  const tokenSnap = await db
    .collection("user_fcm_tokens")
    .where("uid", "==", uid)
    .limit(50)
    .get();
  if (tokenSnap.empty) return;
  const cutoff = Date.now() - USER_FCM_TOKEN_TTL_MS;
  const tokens = [];
  const tokenDocIds = [];
  const staleDocIds = [];
  for (const doc of tokenSnap.docs) {
    const data = doc.data() || {};
    const lastSeenMs = Date.parse(data.lastSeenAt || "");
    if (lastSeenMs && lastSeenMs < cutoff) {
      staleDocIds.push(doc.id);
      continue;
    }
    const token = data.token;
    if (!token) continue;
    tokens.push(token);
    tokenDocIds.push(doc.id);
  }
  if (!tokens.length) return;
  const renewedTabs = Number(options.renewedTabs || 0);
  const renewedTabIndexes = Array.isArray(options.renewedTabIndexes)
    ? options.renewedTabIndexes
    : [];
  const tabsLabel = formatAutoRenewTabs(lang, renewedTabIndexes);
  const fallbackLabel = formatAutoRenewCountLabel(lang, renewedTabs);
  const resolvedTabs = tabsLabel || fallbackLabel;
  const texts = AUTO_RENEW_PUSH_TEXT[lang] || AUTO_RENEW_PUSH_TEXT.en;
  const title = success ? texts.successTitle : texts.failureTitle;
  const body = success ? texts.successBody(resolvedTabs) : texts.failureBody;
  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: {
      pushType: "auto_renew",
      result: success ? "success" : "failure",
      tabs: resolvedTabs,
      count: String(renewedTabs || 0),
      lang
    }
  });
  const invalidCodes = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token"
  ]);
  response.responses.forEach((res, index) => {
    if (res.success) return;
    const code = res.error?.code;
    if (code && invalidCodes.has(code)) {
      staleDocIds.push(tokenDocIds[index]);
    }
  });
  if (staleDocIds.length) {
    const batch = db.batch();
    staleDocIds.forEach((docId) =>
      batch.delete(db.collection("user_fcm_tokens").doc(docId))
    );
    await batch.commit();
  }
  if (!success) {
    await db
      .collection("users")
      .doc(uid)
      .set({ autoRenewFailureNotifiedAt: new Date().toISOString() }, { merge: true });
  }
}

function sanitizeAdminPushData(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const output = {};
  const entries = Object.entries(raw).slice(0, ADMIN_PUSH_MAX_DATA_KEYS);
  for (const [rawKey, rawValue] of entries) {
    const key = normalizeWhitespace(rawKey || "");
    if (!key) continue;
    if (rawValue === undefined || rawValue === null) continue;
    const value = String(rawValue).slice(0, ADMIN_PUSH_MAX_DATA_VALUE_LENGTH);
    output[key] = value;
  }
  return output;
}

function normalizeAdminPushLanguage(value, fallback = "en") {
  const normalized = normalizeLangAlias(value || "", fallback);
  if (ADMIN_PUSH_SUPPORTED_LANGS.has(normalized)) {
    return normalized;
  }
  return fallback;
}

async function deleteTokenDocsById(db, docIds) {
  if (!db || !Array.isArray(docIds) || !docIds.length) return 0;
  let deleted = 0;
  const unique = Array.from(new Set(docIds.filter(Boolean)));
  for (let index = 0; index < unique.length; index += 450) {
    const chunk = unique.slice(index, index + 450);
    if (!chunk.length) continue;
    const batch = db.batch();
    chunk.forEach((docId) =>
      batch.delete(db.collection("user_fcm_tokens").doc(docId))
    );
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

async function loadUserLanguageMapForTokenDocs(db, docs) {
  if (!db || !Array.isArray(docs) || !docs.length) return new Map();
  const uidSet = new Set();
  for (const doc of docs) {
    const item = doc?.data?.() || {};
    const uid = normalizeWhitespace(item.uid || "");
    if (uid) uidSet.add(uid);
  }
  if (!uidSet.size) return new Map();

  const uidList = Array.from(uidSet);
  const languageMap = new Map();
  for (let index = 0; index < uidList.length; index += 200) {
    const chunk = uidList.slice(index, index + 200);
    if (!chunk.length) continue;
    const refs = chunk.map((uid) => db.collection("users").doc(uid));
    let snaps = [];
    try {
      snaps = await db.getAll(...refs);
    } catch (error) {
      console.error("[AdminPush] user language lookup failed", error?.message || error);
      continue;
    }
    for (const snap of snaps) {
      if (!snap?.exists) continue;
      const data = snap.data() || {};
      const userLang = normalizeAdminPushLanguage(
        data.language || data.lang || "",
        ""
      );
      if (!userLang) continue;
      languageMap.set(snap.id, userLang);
    }
  }
  return languageMap;
}

async function sendAdminPushNotification(options = {}) {
  const db = getFirestore();
  const messaging = getFirebaseMessaging();
  if (!db || !messaging) {
    return { ok: false, error: "push_unavailable" };
  }

  const scope = options.scope === "user" ? "user" : "all";
  const uid = scope === "user" ? String(options.uid || "").trim() : "";
  if (scope === "user" && !uid) {
    return { ok: false, error: "uid_required" };
  }
  const title = String(options.title || "").trim();
  const body = String(options.body || "").trim();
  if (!title || !body) {
    return { ok: false, error: "title_body_required" };
  }
  if (title.length > ADMIN_PUSH_MAX_TITLE_LENGTH) {
    return { ok: false, error: "title_too_long" };
  }
  if (body.length > ADMIN_PUSH_MAX_BODY_LENGTH) {
    return { ok: false, error: "body_too_long" };
  }
  const inputLang = normalizeAdminPushLanguage(
    options.inputLang || options.language || options.lang || "en",
    "en"
  );
  const baseData = sanitizeAdminPushData(options.data);
  const nowIso = new Date().toISOString();
  const defaultPushType =
    normalizeWhitespace(String(baseData.pushType || "")) || "breaking";
  const rawSeverity = normalizeWhitespace(String(baseData.severity || ""));
  const defaultSeverity = /^[1-5]$/.test(rawSeverity) ? rawSeverity : "4";
  const data = {
    ...baseData,
    pushType: defaultPushType,
    severity: defaultSeverity,
    adminScope: scope,
    inputLang,
    sentAt: nowIso
  };

  const invalidCodes = new Set([
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token"
  ]);
  const staleDocIds = new Set();
  const invalidDocIds = new Set();

  let targeted = 0;
  let sent = 0;
  let failed = 0;
  let skippedStale = 0;
  const languageBreakdown = {};
  const cutoffMs = Date.now() - USER_FCM_TOKEN_TTL_MS;
  const localizedMessages = new Map();
  localizedMessages.set(inputLang, {
    title: title.slice(0, ADMIN_PUSH_MAX_TITLE_LENGTH),
    body: body.slice(0, ADMIN_PUSH_MAX_BODY_LENGTH)
  });
  const translatedLanguages = new Set([inputLang]);

  const resolveLocalizedMessage = async (targetLang) => {
    const normalizedTarget = normalizeAdminPushLanguage(targetLang, inputLang);
    const cached = localizedMessages.get(normalizedTarget);
    if (cached) return cached;

    let translatedTitle = title;
    let translatedBody = body;
    try {
      [translatedTitle, translatedBody] = await Promise.all([
        translateText(title, normalizedTarget),
        translateText(body, normalizedTarget)
      ]);
    } catch (error) {
      console.error(
        "[AdminPush] translate failed",
        normalizedTarget,
        error?.message || error
      );
    }
    const localized = {
      title:
        (normalizeWhitespace(translatedTitle) || title).slice(
          0,
          ADMIN_PUSH_MAX_TITLE_LENGTH
        ),
      body:
        (normalizeWhitespace(translatedBody) || body).slice(
          0,
          ADMIN_PUSH_MAX_BODY_LENGTH
        )
    };
    localizedMessages.set(normalizedTarget, localized);
    translatedLanguages.add(normalizedTarget);
    return localized;
  };

  const dispatchDocs = async (docs) => {
    const userLanguageMap = await loadUserLanguageMapForTokenDocs(db, docs);
    const groups = new Map();
    for (const doc of docs) {
      const item = doc.data() || {};
      const lastSeenMs = Date.parse(item.lastSeenAt || "");
      if (
        Number.isFinite(lastSeenMs) &&
        lastSeenMs > 0 &&
        lastSeenMs < cutoffMs
      ) {
        staleDocIds.add(doc.id);
        skippedStale += 1;
        continue;
      }
      const token = String(item.token || "").trim();
      if (!token) {
        staleDocIds.add(doc.id);
        continue;
      }
      const uid = normalizeWhitespace(item.uid || "");
      const userLang = uid ? userLanguageMap.get(uid) || "" : "";
      const targetLang = normalizeAdminPushLanguage(
        userLang || item.language || item.lang || inputLang,
        inputLang
      );
      if (!groups.has(targetLang)) {
        groups.set(targetLang, { tokens: [], tokenDocIds: [] });
      }
      const group = groups.get(targetLang);
      group.tokens.push(token);
      group.tokenDocIds.push(doc.id);
    }
    if (!groups.size) return;

    for (const [targetLang, group] of groups.entries()) {
      const { tokens, tokenDocIds } = group;
      if (!tokens.length) continue;
      const localized = await resolveLocalizedMessage(targetLang);
      targeted += tokens.length;
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: localized.title,
          body: localized.body
        },
        data: {
          ...data,
          lang: targetLang
        }
      });
      const langSent = response.successCount || 0;
      const langFailed = response.failureCount || 0;
      sent += langSent;
      failed += langFailed;
      const bucket = languageBreakdown[targetLang] || {
        targeted: 0,
        sent: 0,
        failed: 0
      };
      bucket.targeted += tokens.length;
      bucket.sent += langSent;
      bucket.failed += langFailed;
      languageBreakdown[targetLang] = bucket;
      response.responses.forEach((entry, index) => {
        if (entry.success) return;
        const code = entry.error?.code || "";
        if (invalidCodes.has(code)) {
          const docId = tokenDocIds[index];
          if (docId) invalidDocIds.add(docId);
        }
      });
    }
  };

  if (scope === "user") {
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
      return { ok: false, error: "user_not_found" };
    }
    const snap = await db
      .collection("user_fcm_tokens")
      .where("uid", "==", uid)
      .limit(200)
      .get();
    await dispatchDocs(snap.docs);
  } else {
    let lastDoc = null;
    while (true) {
      let query = db
        .collection("user_fcm_tokens")
        .orderBy(FieldPath.documentId())
        .limit(ADMIN_PUSH_BATCH_SIZE);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }
      const snap = await query.get();
      if (snap.empty) break;
      await dispatchDocs(snap.docs);
      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < ADMIN_PUSH_BATCH_SIZE) break;
    }
  }

  const cleanedStale = await deleteTokenDocsById(db, Array.from(staleDocIds));
  const cleanedInvalid = await deleteTokenDocsById(
    db,
    Array.from(invalidDocIds)
  );

  return {
    ok: true,
    scope,
    uid: uid || "",
    targeted,
    sent,
    failed,
    skippedStale,
    cleanedStale,
    cleanedInvalid,
    title,
    body,
    inputLang,
    translatedLanguages: Array.from(translatedLanguages),
    languageBreakdown,
    dataKeys: Object.keys(data)
  };
}

async function maintainUserTabs(docRef, nowMs) {
  const db = getFirestore();
  if (!db) return { updated: false, expiredKeywords: [], renewedTabs: 0 };
  const nowIso = new Date(nowMs).toISOString();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(docRef);
    if (!snap.exists) {
      return { updated: false, expiredKeywords: [], renewedTabs: 0 };
    }
    const data = snap.data() || {};
    const expiryMap = normalizeTabExpiryMap(data.tabExpiry);
    const tabKeywords = normalizeStringArray(data.tabKeywords, TAB_COUNT, "");
    const canonicalKeywords = normalizeCanonicalKeywords(data.canonicalKeywords);
    const autoRenewEnabled = data.autoRenewEnabled === true;
    const autoRenewed = normalizeAutoRenewedExpiryMap(data.tabAutoRenewedExpiry);
    const autoRenewAttempts = normalizeAutoRenewAttemptMap(
      data.tabAutoRenewAttemptedAt
    );
    const tokenBalance = Number.parseInt(data.tokenBalance, 10) || 0;
    const tokenLedger = Array.isArray(data.tokenLedger)
      ? data.tokenLedger.slice()
      : [];
    let balance = tokenBalance;
    let needsPayment = false;
    let autoRenewDisabled = false;
    let renewedTabs = 0;
    let dueTabs = 0;
    const renewedTabIndexes = [];
    const expiredKeywords = [];
    const nextExpiry = { ...expiryMap };
    const nextKeywords = tabKeywords.slice();
    const nextCanonical = { ...canonicalKeywords };
    const nextAutoRenewed = { ...autoRenewed };
    const nextAutoRenewAttempts = { ...autoRenewAttempts };
    let keywordsChanged = false;
    let expiryChanged = false;
    let autoRenewedChanged = false;
    let autoRenewAttemptChanged = false;
    let ledgerChanged = false;

    for (let index = 2; index <= TAB_MAX_INDEX; index += 1) {
      const key = String(index);
      const expiryIso = expiryMap[key];
      if (!expiryIso) continue;
      const expiryMs = Date.parse(expiryIso);
      if (Number.isNaN(expiryMs)) continue;

      if (expiryMs <= nowMs) {
        const keyword = normalizeWhitespace(
          nextCanonical[key] || nextKeywords[index] || ""
        );
        if (keyword) {
          expiredKeywords.push(keyword);
        }
        nextKeywords[index] = "";
        delete nextCanonical[key];
        delete nextExpiry[key];
        delete nextAutoRenewed[key];
        keywordsChanged = true;
        expiryChanged = true;
        autoRenewedChanged = true;
        continue;
      }

      if (!autoRenewEnabled) continue;
      if (expiryMs > nowMs + AUTO_RENEW_ATTEMPT_WINDOW_MS) continue;
      const lastAttemptIso = nextAutoRenewAttempts[key];
      const lastAttemptMs = lastAttemptIso ? Date.parse(lastAttemptIso) : NaN;
      if (
        !Number.isNaN(lastAttemptMs) &&
        nowMs - lastAttemptMs < AUTO_RENEW_RETRY_INTERVAL_MS
      ) {
        continue;
      }
      nextAutoRenewAttempts[key] = nowIso;
      autoRenewAttemptChanged = true;
      const expiryKey = new Date(expiryMs).toISOString();
      if (nextAutoRenewed[key] === expiryKey) continue;
      needsPayment = true;
      dueTabs += 1;
      if (balance < TAB_MONTHLY_COST) {
        continue;
      }
      balance -= TAB_MONTHLY_COST;
      const extended = new Date(expiryMs + 30 * 24 * 60 * 60 * 1000);
      nextExpiry[key] = extended.toISOString();
      nextAutoRenewed[key] = expiryKey;
      tokenLedger.unshift({
        timestamp: nowIso,
        amount: -TAB_MONTHLY_COST,
        type: "auto_renew",
        description: `tab:${index}`
      });
      renewedTabs += 1;
      renewedTabIndexes.push(index);
      expiryChanged = true;
      autoRenewedChanged = true;
      ledgerChanged = true;
    }

    if (autoRenewEnabled && needsPayment && dueTabs > renewedTabs) {
      autoRenewDisabled = true;
    }

    if (
      !keywordsChanged &&
      !expiryChanged &&
      !autoRenewedChanged &&
      !autoRenewAttemptChanged &&
      !ledgerChanged
    ) {
      return {
        updated: false,
        expiredKeywords,
        renewedTabs,
        renewedTabIndexes,
        autoRenewDisabled
      };
    }

    const updatePayload = {
      updatedAt: nowIso
    };
    if (keywordsChanged) {
      updatePayload.tabKeywords = nextKeywords;
      updatePayload.canonicalKeywords = nextCanonical;
    }
    if (expiryChanged) {
      updatePayload.tabExpiry = nextExpiry;
    }
    if (autoRenewedChanged) {
      updatePayload.tabAutoRenewedExpiry = nextAutoRenewed;
    }
    if (autoRenewAttemptChanged) {
      updatePayload.tabAutoRenewAttemptedAt = nextAutoRenewAttempts;
    }
    if (ledgerChanged) {
      updatePayload.tokenBalance = balance;
      updatePayload.tokenLedger = tokenLedger;
    }
    tx.set(docRef, updatePayload, { merge: true });
    return {
      updated: true,
      expiredKeywords,
      renewedTabs,
      renewedTabIndexes,
      autoRenewDisabled
    };
  });
}

async function processUserMaintenance(options = {}) {
  const db = getFirestore();
  if (!db) return { processed: 0, updated: 0, renewedTabs: 0, expiredTabs: 0 };
  const batchSize = Math.min(
    Math.max(Number(options.batchSize) || USER_MAINTENANCE_BATCH_SIZE, 50),
    500
  );
  const stateRef = db.collection("cron_state").doc("user_maintenance");
  const stateSnap = await stateRef.get();
  const lastUserId = stateSnap.exists ? String(stateSnap.data()?.lastUserId || "") : "";
  let query = db.collection("users").orderBy(FieldPath.documentId()).limit(batchSize);
  if (lastUserId) {
    query = query.startAfter(lastUserId);
  }

  const snap = await query.get();
  if (snap.empty) {
    if (lastUserId) {
      await stateRef.set(
        { lastUserId: "", updatedAt: new Date().toISOString() },
        { merge: true }
      );
    }
    return { processed: 0, updated: 0, renewedTabs: 0, expiredTabs: 0, reset: true };
  }

  const expiredKeywordCounts = new Map();
  let updated = 0;
  let renewedTabs = 0;
  let expiredTabs = 0;
  const nowMs = Date.now();

  for (const doc of snap.docs) {
    try {
      const result = await maintainUserTabs(doc.ref, nowMs);
      if (result?.updated) {
        updated += 1;
      }
      if (result?.renewedTabs > 0) {
        await sendAutoRenewPushToUser({
          uid: doc.id,
          success: true,
          renewedTabs: result.renewedTabs,
          renewedTabIndexes: result.renewedTabIndexes
        });
      } else if (result?.autoRenewDisabled) {
        await sendAutoRenewPushToUser({
          uid: doc.id,
          success: false
        });
      }
      if (Array.isArray(result?.expiredKeywords)) {
        for (const keyword of result.expiredKeywords) {
          expiredTabs += 1;
          const key = normalizeWhitespace(keyword);
          if (!key) continue;
          expiredKeywordCounts.set(key, (expiredKeywordCounts.get(key) || 0) + 1);
        }
      }
      renewedTabs += Number(result?.renewedTabs || 0);
    } catch (error) {
      console.error(
        "[UserMaintenance] failed",
        doc.id,
        error?.message || error
      );
    }
  }

  const lastDocId = snap.docs[snap.docs.length - 1].id;
  await stateRef.set(
    { lastUserId: lastDocId, updatedAt: new Date().toISOString() },
    { merge: true }
  );

  for (const [keyword, count] of expiredKeywordCounts.entries()) {
    try {
      await updateKeywordSubscription(keyword, -count, { allowMeta: false });
    } catch (error) {
      console.error(
        "[UserMaintenance] keyword decrement failed",
        keyword,
        error?.message || error
      );
    }
  }

  return {
    processed: snap.size,
    updated,
    renewedTabs,
    expiredTabs
  };
}

function stringifyOneStoreVerifyDetail(verifyResult) {
  try {
    return JSON.stringify(verifyResult?.data || null).slice(0, 2000);
  } catch (_) {
    return String(verifyResult?.data || "").slice(0, 2000);
  }
}

function shouldMarkOneStorePurchaseRefunded(verifyResult) {
  if (!verifyResult || verifyResult.ok) {
    return { shouldRefund: false, reason: "active" };
  }
  const errorRaw = String(verifyResult.error || "").trim();
  const error = errorRaw.toLowerCase();
  const terminalErrors = new Set([
    "purchase_not_completed",
    "onestore_http_404",
    "onestore_http_410",
    "onestore_status_404",
    "onestore_status_410"
  ]);
  if (terminalErrors.has(error)) {
    return { shouldRefund: true, reason: error };
  }

  const purchaseState = Number.parseInt(verifyResult?.data?.purchaseState, 10);
  if (Number.isFinite(purchaseState) && purchaseState !== 0) {
    return { shouldRefund: true, reason: `purchase_state_${purchaseState}` };
  }

  const nestedErrors = Array.isArray(verifyResult?.data?.errors)
    ? verifyResult.data.errors
    : [];
  for (const item of nestedErrors) {
    const nestedError = String(item?.error || "")
      .trim()
      .toLowerCase();
    if (terminalErrors.has(nestedError)) {
      return { shouldRefund: true, reason: nestedError };
    }
    const status = Number.parseInt(item?.status, 10);
    if (status === 404 || status === 410) {
      return { shouldRefund: true, reason: `onestore_http_${status}` };
    }
    const apiErrorCode = String(item?.apiErrorCode || "").trim();
    if (apiErrorCode === "404" || apiErrorCode === "410") {
      return { shouldRefund: true, reason: `onestore_status_${apiErrorCode}` };
    }
  }

  return { shouldRefund: false, reason: error || "verify_failed" };
}

async function reconcileOneStoreRefunds(options = {}) {
  const db = getFirestore();
  if (!db) {
    return {
      processed: 0,
      checked: 0,
      refunded: 0,
      skipped: 0,
      errors: 0,
      skippedReason: "firestore_unavailable"
    };
  }
  if (!ONESTORE_CLIENT_ID || !ONESTORE_CLIENT_SECRET) {
    return {
      processed: 0,
      checked: 0,
      refunded: 0,
      skipped: 0,
      errors: 0,
      skippedReason: "onestore_not_configured"
    };
  }

  const batchSize = Math.max(
    1,
    Math.min(
      200,
      Number.parseInt(options.batchSize, 10) || ONESTORE_REFUND_RECONCILE_BATCH
    )
  );
  const recheckMs = ONESTORE_REFUND_RECHECK_INTERVAL_MINUTES * 60 * 1000;
  const minPurchaseAgeMs = ONESTORE_REFUND_MIN_PURCHASE_AGE_MINUTES * 60 * 1000;
  const maxPurchaseAgeMs = ONESTORE_REFUND_RECONCILE_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();

  const stateRef = db.collection("cron_state").doc("onestore_refund_reconcile");
  const stateSnap = await stateRef.get();
  const lastDocId = stateSnap.exists
    ? String(stateSnap.data()?.lastDocId || "")
    : "";

  const fetchBatch = async (cursor = "") => {
    let query = db
      .collection("iapPurchases")
      .where("storeType", "==", "onestore")
      .orderBy(FieldPath.documentId())
      .limit(batchSize);
    if (cursor) {
      query = query.startAfter(cursor);
    }
    return query.get();
  };

  let wrapped = false;
  let snap = await fetchBatch(lastDocId);
  if (snap.empty && lastDocId) {
    await stateRef.set(
      {
        lastDocId: "",
        updatedAt: nowIso
      },
      { merge: true }
    );
    snap = await fetchBatch("");
    wrapped = true;
  }
  if (snap.empty) {
    return {
      processed: 0,
      checked: 0,
      refunded: 0,
      skipped: 0,
      errors: 0,
      reset: true,
      wrapped
    };
  }

  let processed = 0;
  let checked = 0;
  let refunded = 0;
  let skipped = 0;
  let errors = 0;

  for (const doc of snap.docs) {
    processed += 1;
    const data = doc.data() || {};
    if (data.refundProcessed === true || data.voided === true || data.canceled === true) {
      skipped += 1;
      continue;
    }
    const purchaseToken = String(data.purchaseToken || "").trim();
    const productId = String(data.productId || "").trim();
    if (!purchaseToken || !productId) {
      skipped += 1;
      continue;
    }

    const createdAtMs = Date.parse(
      String(data.createdAt || data.purchaseTimeMillis || "")
    );
    if (Number.isFinite(createdAtMs)) {
      const ageMs = nowMs - createdAtMs;
      if (ageMs < minPurchaseAgeMs || ageMs > maxPurchaseAgeMs) {
        skipped += 1;
        continue;
      }
    }

    const lastCheckedMs = Date.parse(String(data.oneStoreLastStatusCheckedAt || ""));
    if (Number.isFinite(lastCheckedMs) && nowMs - lastCheckedMs < recheckMs) {
      skipped += 1;
      continue;
    }

    const marketCode = normalizeOneStoreMarketCode(data.marketCode || "");
    let verifyResult = null;
    try {
      verifyResult = await verifyOneStoreProductPurchase({
        productId,
        purchaseToken,
        marketCode
      });
      checked += 1;
    } catch (error) {
      errors += 1;
      await doc.ref.set(
        {
          oneStoreLastStatusCheckedAt: nowIso,
          oneStoreLastStatus: "verify_exception",
          oneStoreLastError: String(error?.message || error || "verify_exception").slice(
            0,
            160
          )
        },
        { merge: true }
      );
      continue;
    }

    if (verifyResult.ok) {
      await doc.ref.set(
        {
          oneStoreLastStatusCheckedAt: nowIso,
          oneStoreLastStatus: "active",
          oneStoreLastError: "",
          oneStoreLastErrorDetail: ""
        },
        { merge: true }
      );
      continue;
    }

    const decision = shouldMarkOneStorePurchaseRefunded(verifyResult);
    const verifyDetail = stringifyOneStoreVerifyDetail(verifyResult);
    if (!decision.shouldRefund) {
      await doc.ref.set(
        {
          oneStoreLastStatusCheckedAt: nowIso,
          oneStoreLastStatus: "verify_failed",
          oneStoreLastError: String(verifyResult.error || "").slice(0, 160),
          oneStoreLastErrorDetail: verifyDetail
        },
        { merge: true }
      );
      continue;
    }

    try {
      const refundResult = await applyIapRefundFromVoidedNotification({
        purchaseToken,
        orderId: String(data.orderId || ""),
        productType: 2,
        source: `onestore_reconcile:${decision.reason}`,
        storeType: "onestore"
      });
      const refundSucceeded = Boolean(refundResult?.ok || refundResult?.alreadyProcessed);
      if (refundSucceeded) {
        refunded += 1;
      } else {
        errors += 1;
      }
      await doc.ref.set(
        {
          oneStoreLastStatusCheckedAt: nowIso,
          oneStoreLastStatus: refundSucceeded
            ? "refunded"
            : "refund_failed",
          oneStoreLastError: refundSucceeded
            ? ""
            : String(refundResult?.error || "refund_failed").slice(0, 160),
          oneStoreLastErrorDetail: verifyDetail,
          oneStoreRefundReason: decision.reason
        },
        { merge: true }
      );
    } catch (error) {
      errors += 1;
      await doc.ref.set(
        {
          oneStoreLastStatusCheckedAt: nowIso,
          oneStoreLastStatus: "refund_exception",
          oneStoreLastError: String(error?.message || error || "refund_exception").slice(
            0,
            160
          ),
          oneStoreLastErrorDetail: verifyDetail,
          oneStoreRefundReason: decision.reason
        },
        { merge: true }
      );
    }
  }

  const nextDocId = snap.docs[snap.docs.length - 1].id;
  await stateRef.set(
    {
      lastDocId: nextDocId,
      updatedAt: nowIso
    },
    { merge: true }
  );

  return {
    processed,
    checked,
    refunded,
    skipped,
    errors,
    lastDocId: nextDocId,
    wrapped
  };
}

async function collectBreakingRegionsFromUsers(db, options = {}) {
  if (!db) return { regions: new Set(["ALL"]), scanned: 0 };
  const batchSize = Math.min(
    Math.max(Number(options.batchSize) || 400, 50),
    1000
  );
  const limit = Math.max(Number(options.limit) || 2000, 1);
  let scanned = 0;
  let lastDoc = null;
  let query = db
    .collection("users")
    .orderBy(FieldPath.documentId())
    .select("tabRegions")
    .limit(batchSize);
  const regions = new Set();

  while (true) {
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const tabRegions = normalizeRegionArray(doc.data()?.tabRegions, TAB_COUNT);
      const breakingRegion = String(tabRegions[0] || "ALL").toUpperCase();
      if (breakingRegion) {
        regions.add(breakingRegion);
      }
      if (scanned >= limit) break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize || scanned >= limit) break;
  }

  if (!regions.size) {
    regions.add("ALL");
  }
  return { regions, scanned };
}

async function resolveBreakingRegions(db, fallbackRegions) {
  const fallbackSet = new Set();
  if (fallbackRegions && typeof fallbackRegions.forEach === "function") {
    fallbackRegions.forEach((value) => {
      const region = String(value || "").toUpperCase();
      if (region) fallbackSet.add(region);
    });
  }

  if (!db) {
    return fallbackSet.size ? fallbackSet : new Set(["ALL"]);
  }

  const stateRef = db.collection("cron_state").doc("breaking_regions");
  const nowMs = Date.now();
  try {
    const stateSnap = await stateRef.get();
    if (stateSnap.exists) {
      const data = stateSnap.data() || {};
      const updatedAt = Date.parse(data.updatedAt || "");
      if (updatedAt && nowMs - updatedAt < BREAKING_REGION_CACHE_TTL_MS) {
        const cached = Array.isArray(data.regions) ? data.regions : [];
        const cachedSet = new Set(
          cached
            .map((value) => String(value || "").toUpperCase())
            .filter(Boolean)
        );
        if (cachedSet.size) {
          return new Set([...cachedSet, ...fallbackSet]);
        }
      }
    }
  } catch (error) {
    console.error("[BreakingRegions] cache read failed", error?.message || error);
  }

  let resolved = fallbackSet;
  try {
    const collected = await collectBreakingRegionsFromUsers(db);
    if (collected && collected.regions && collected.regions.size) {
      resolved = new Set([...fallbackSet, ...collected.regions]);
      await stateRef.set(
        {
          regions: Array.from(resolved),
          scanned: collected.scanned,
          updatedAt: new Date().toISOString()
        },
        { merge: true }
      );
    }
  } catch (error) {
    console.error("[BreakingRegions] scan failed", error?.message || error);
  }

  if (!resolved.size) {
    resolved.add("ALL");
  }
  return resolved;
}

async function collectBreakingTargetsFromUsers(db, options = {}) {
  if (!db) return { targets: new Set(), scanned: 0 };
  const batchSize = Math.min(
    Math.max(Number(options.batchSize) || 400, 50),
    1000
  );
  const limit = Math.max(Number(options.limit) || 2000, 1);
  let scanned = 0;
  let lastDoc = null;
  let query = db
    .collection("users")
    .orderBy(FieldPath.documentId())
    .select("tabRegions", "notificationPrefs", "language", "lang")
    .limit(batchSize);
  const targets = new Set();

  while (true) {
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const prefs = data.notificationPrefs || {};
      const hasBreakingPref =
        prefs && Object.prototype.hasOwnProperty.call(prefs, "breakingEnabled");
      const breakingEnabled = hasBreakingPref ? Boolean(prefs.breakingEnabled) : true;
      if (!breakingEnabled) continue;
      const tabRegions = normalizeRegionArray(data.tabRegions, TAB_COUNT);
      const region = String(tabRegions[0] || "ALL").toUpperCase();
      const lang = normalizeLangCode(data.language || data.lang || "", "en");
      targets.add(`${region}::${lang}`);
      if (scanned >= limit) break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize || scanned >= limit) break;
  }

  return { targets, scanned };
}

async function resolveBreakingTargets(db) {
  if (!db) return new Set();
  const stateRef = db.collection("cron_state").doc("breaking_targets");
  const nowMs = Date.now();
  let cachedSet = null;
  try {
    const stateSnap = await stateRef.get();
    if (stateSnap.exists) {
      const data = stateSnap.data() || {};
      const updatedAt = Date.parse(data.updatedAt || "");
      const cached = Array.isArray(data.targets) ? data.targets : [];
      if (cached.length) {
        const normalized = cached
          .map((value) => {
            const raw = String(value || "");
            if (!raw) return "";
            const parts = raw.split("::");
            if (parts.length < 2) return "";
            const region = String(parts[0] || "ALL").toUpperCase();
            const lang = normalizeLangCode(parts[1] || "", "en");
            return `${region}::${lang}`;
          })
          .filter(Boolean);
        cachedSet = normalized.length ? new Set(normalized) : null;
      }
      if (updatedAt && nowMs - updatedAt < BREAKING_REGION_CACHE_TTL_MS) {
        return cachedSet || new Set();
      }
    }
  } catch (error) {
    console.error("[BreakingTargets] cache read failed", error?.message || error);
  }

  try {
    const collected = await collectBreakingTargetsFromUsers(db);
    const resolved = collected.targets || new Set();
    await stateRef.set(
      {
        targets: Array.from(resolved),
        scanned: collected.scanned,
        updatedAt: new Date().toISOString()
      },
      { merge: true }
    );
    return resolved;
  } catch (error) {
    console.error("[BreakingTargets] collect failed", error?.message || error);
    return cachedSet || new Set();
  }
}

function makeSubscriptionDocId(keyword) {
  return keywordKey(keyword);
}

function makeLegacySubscriptionDocId(keyword) {
  return crypto.createHash("sha256").update(keywordKey(keyword)).digest("hex");
}

async function deleteKeywordCache(canonical, keywordKeyValue) {
  const db = getFirestore();
  if (!db) return;
  while (true) {
    const snap = await db
      .collection("news_cache")
      .where("keywordKey", "==", keywordKeyValue)
      .limit(200)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    if (snap.size < 200) break;
  }
  while (canonical) {
    const snap = await db
      .collection("news_cache")
      .where("canonical", "==", canonical)
      .limit(200)
      .get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    if (snap.size < 200) break;
  }
}

async function updateKeywordSubscription(keyword, delta, options = {}) {
  const db = getFirestore();
  if (!db) return null;
  const allowMeta = options.allowMeta !== false;
  const region = allowMeta && options.region ? String(options.region).toUpperCase() : "";
  const lang = allowMeta ? normalizeLangCode(options.lang || "en") : "";
  const feedLang = allowMeta
    ? normalizeLangCode(options.feedLang || options.lang || "en")
    : "";
  const alias = allowMeta ? normalizeWhitespace(options.alias || "") : "";
  const key = keywordKey(keyword);
  const docId = makeSubscriptionDocId(keyword);
  const legacyDocId = makeLegacySubscriptionDocId(keyword);
  const ref = db.collection("keyword_subscriptions").doc(docId);
  const legacyRef =
    legacyDocId === docId
      ? null
      : db.collection("keyword_subscriptions").doc(legacyDocId);
  let newCount = 0;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const legacySnap = legacyRef ? await tx.get(legacyRef) : null;
    const current = snap.exists ? Number(snap.data()?.count || 0) : 0;
    const legacyCount = legacySnap?.exists
      ? Number(legacySnap.data()?.count || 0)
      : 0;
    const baseCount = Math.max(current, legacyCount);
    newCount = Math.max(0, baseCount + delta);
    if (newCount <= 0) {
      if (delta !== 0) {
        tx.delete(ref);
        if (legacyRef) {
          tx.delete(legacyRef);
        }
      }
      return;
    } else {
      const currentRegions = Array.isArray(snap.data()?.regions)
        ? snap.data().regions
        : [];
      const legacyRegions = Array.isArray(legacySnap?.data()?.regions)
        ? legacySnap.data().regions
        : [];
      const currentLangs = Array.isArray(snap.data()?.langs)
        ? snap.data().langs
        : [];
      const legacyLangs = Array.isArray(legacySnap?.data()?.langs)
        ? legacySnap.data().langs
        : [];
      const currentAliases = Array.isArray(snap.data()?.aliases)
        ? snap.data().aliases
        : [];
      const legacyAliases = Array.isArray(legacySnap?.data()?.aliases)
        ? legacySnap.data().aliases
        : [];
      const combinedRegions = new Set([
        ...currentRegions,
        ...legacyRegions
      ]);
      const combinedLangs = new Set([...currentLangs, ...legacyLangs]);
      const combinedAliases = new Set([...currentAliases, ...legacyAliases]);
      const currentRegionLangs =
        (snap.data()?.regionLangs && typeof snap.data().regionLangs === "object")
          ? snap.data().regionLangs
          : {};
      const legacyRegionLangs =
        (legacySnap?.data()?.regionLangs &&
          typeof legacySnap.data().regionLangs === "object")
          ? legacySnap.data().regionLangs
          : {};
      const combinedRegionLangs = {
        ...legacyRegionLangs,
        ...currentRegionLangs
      };
      const updates = {
        canonical: keyword,
        key,
        count: newCount,
        updatedAt: new Date().toISOString()
      };
      if (region) {
        combinedRegions.add(region);
        combinedRegionLangs[region] = feedLang;
      }
      if (lang) {
        combinedLangs.add(lang);
      }
      if (alias) {
        combinedAliases.add(alias);
      }
      if (combinedRegions.size) {
        updates.regions = Array.from(combinedRegions);
      }
      if (combinedLangs.size) {
        updates.langs = Array.from(combinedLangs);
      }
      if (combinedAliases.size) {
        updates.aliases = Array.from(combinedAliases).slice(0, MAX_KEYWORD_ALIASES);
      }
      if (Object.keys(combinedRegionLangs).length) {
        updates.regionLangs = combinedRegionLangs;
      }
      tx.set(
        ref,
        updates,
        { merge: true }
      );
      if (legacyRef) {
        tx.delete(legacyRef);
      }
    }
  });
  if (newCount <= 0 && delta !== 0) {
    await deleteKeywordCache(keyword, key);
  }
  return newCount;
}

async function clearUserKeywordsForBan(uid) {
  const db = getFirestore();
  if (!db) return { ok: false, error: "firestore_unavailable" };
  if (!uid) return { ok: false, error: "missing_uid" };

  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) return { ok: false, error: "user_not_found" };

  const data = snap.data() || {};
  const tabKeywords = normalizeStringArray(data.tabKeywords, TAB_COUNT, "");
  const canonicalKeywords = normalizeCanonicalKeywords(data.canonicalKeywords);
  const keywords = [];

  for (let index = 0; index < tabKeywords.length; index += 1) {
    const canonical = normalizeWhitespace(canonicalKeywords[String(index)] || "");
    const raw = normalizeWhitespace(tabKeywords[index] || "");
    const keyword = canonical || raw;
    if (!keyword) continue;
    keywords.push(keyword);
  }

  const counts = new Map();
  for (const keyword of keywords) {
    counts.set(keyword, (counts.get(keyword) || 0) + 1);
  }

  const clearedKeywords = Array.from({ length: TAB_COUNT }, () => "");
  await userRef.set(
    {
      tabKeywords: clearedKeywords,
      canonicalKeywords: {},
      updatedAt: new Date().toISOString()
    },
    { merge: true }
  );

  for (const [keyword, count] of counts.entries()) {
    try {
      await updateKeywordSubscription(keyword, -count, { allowMeta: false });
    } catch (error) {
      console.error(
        "[Admin] keyword decrement failed",
        keyword,
        error?.message || error
      );
    }
  }

  return { ok: true, removed: keywords.length, unique: counts.size };
}

async function setKeywordSubscriptionForUser(options = {}) {
  const db = getFirestore();
  if (!db) return null;
  const uid = options.uid;
  if (!uid) return null;
  const previousRaw = normalizeWhitespace(options.previousKeyword || "");
  const nextRaw = normalizeWhitespace(options.nextKeyword || "");
  if (!previousRaw && !nextRaw) return null;

  const lang = normalizeLangCode(options.lang || "en");
  const region = options.region ? String(options.region).toUpperCase() : "";
  const feedLang = normalizeLangCode(options.feedLang || lang);
  const tabIndex = Number.parseInt(options.tabIndex, 10);
  const hasTabIndex =
    Number.isFinite(tabIndex) && tabIndex >= 0 && tabIndex < TAB_COUNT;

  const previousCanonical = previousRaw
    ? await getCanonicalKeyword(previousRaw, lang, { allowModel: false })
    : "";
  const nextCanonical = nextRaw
    ? await getCanonicalKeyword(nextRaw, lang, { allowModel: true })
    : "";
  const previousSafe = normalizeWhitespace(previousCanonical || previousRaw);
  const nextSafe = normalizeWhitespace(nextCanonical || nextRaw);
  const previousKey = previousSafe ? keywordKey(previousSafe) : "";
  const nextKey = nextSafe ? keywordKey(nextSafe) : "";
  const sameKey = previousKey && nextKey && previousKey === nextKey;

  const previousDocId = previousKey ? makeSubscriptionDocId(previousSafe) : "";
  const nextDocId = nextKey ? makeSubscriptionDocId(nextSafe) : "";
  const previousRef = previousKey
    ? db.collection("keyword_subscriptions").doc(previousDocId)
    : null;
  const nextRef = nextKey
    ? db.collection("keyword_subscriptions").doc(nextDocId)
    : null;
  const previousLegacyId = previousKey
    ? makeLegacySubscriptionDocId(previousSafe)
    : "";
  const nextLegacyId = nextKey
    ? makeLegacySubscriptionDocId(nextSafe)
    : "";
  const previousLegacyRef =
    previousKey && previousLegacyId !== previousDocId
      ? db.collection("keyword_subscriptions").doc(previousLegacyId)
      : null;
  const nextLegacyRef =
    nextKey && nextLegacyId !== nextDocId
      ? db.collection("keyword_subscriptions").doc(nextLegacyId)
      : null;
  const userRef = db.collection("users").doc(uid);

  const nowIso = new Date().toISOString();
  let previousCount = null;
  let nextCount = null;
  let nextConditionAdded = false;

  await db.runTransaction(async (tx) => {
    let txNextConditionAdded = false;
    let previousSnap = null;
    let nextSnap = null;
    let previousLegacySnap = null;
    let nextLegacySnap = null;
    let userSnap = null;

    if (hasTabIndex) {
      userSnap = await tx.get(userRef);
    }

    if (previousRef) {
      previousSnap = await tx.get(previousRef);
    }
    if (previousLegacyRef) {
      if (previousRef && previousLegacyRef.path === previousRef.path) {
        previousLegacySnap = previousSnap;
      } else {
        previousLegacySnap = await tx.get(previousLegacyRef);
      }
    }
    if (nextRef) {
      if (previousRef && previousRef.path === nextRef.path) {
        nextSnap = previousSnap;
      } else {
        nextSnap = await tx.get(nextRef);
      }
    }
    if (nextLegacyRef) {
      if (nextRef && nextLegacyRef.path === nextRef.path) {
        nextLegacySnap = nextSnap;
      } else if (previousLegacyRef && nextLegacyRef.path === previousLegacyRef.path) {
        nextLegacySnap = previousLegacySnap;
      } else {
        nextLegacySnap = await tx.get(nextLegacyRef);
      }
    }

    const mergeArrays = (a, b) => Array.from(new Set([...(a || []), ...(b || [])]));
    const mergeRegionLangs = (a, b) => ({ ...(a || {}), ...(b || {}) });
    const baseCountFrom = (snap, legacySnap) => {
      const current = snap?.exists ? Number(snap.data()?.count || 0) : 0;
      const legacy = legacySnap?.exists ? Number(legacySnap.data()?.count || 0) : 0;
      return Math.max(current, legacy);
    };
    const mergedMeta = (snap, legacySnap) => {
      const currentRegions = Array.isArray(snap?.data()?.regions)
        ? snap.data().regions
        : [];
      const legacyRegions = Array.isArray(legacySnap?.data()?.regions)
        ? legacySnap.data().regions
        : [];
      const currentLangs = Array.isArray(snap?.data()?.langs)
        ? snap.data().langs
        : [];
      const legacyLangs = Array.isArray(legacySnap?.data()?.langs)
        ? legacySnap.data().langs
        : [];
      const currentAliases = Array.isArray(snap?.data()?.aliases)
        ? snap.data().aliases
        : [];
      const legacyAliases = Array.isArray(legacySnap?.data()?.aliases)
        ? legacySnap.data().aliases
        : [];
      const currentRegionLangs =
        (snap?.data()?.regionLangs && typeof snap.data().regionLangs === "object")
          ? snap.data().regionLangs
          : {};
      const legacyRegionLangs =
        (legacySnap?.data()?.regionLangs &&
          typeof legacySnap.data().regionLangs === "object")
          ? legacySnap.data().regionLangs
          : {};
      return {
        regions: mergeArrays(currentRegions, legacyRegions),
        langs: mergeArrays(currentLangs, legacyLangs),
        regionLangs: mergeRegionLangs(legacyRegionLangs, currentRegionLangs),
        aliases: mergeArrays(currentAliases, legacyAliases)
      };
    };

    if (previousRef && previousKey && !sameKey) {
      const baseCount = baseCountFrom(previousSnap, previousLegacySnap);
      previousCount = Math.max(0, baseCount - 1);
      if (previousCount <= 0) {
        tx.delete(previousRef);
      } else {
        const meta = mergedMeta(previousSnap, previousLegacySnap);
        const payload = {
          canonical: previousSafe,
          key: previousKey,
          count: previousCount,
          updatedAt: nowIso
        };
        if (meta.regions.length) {
          payload.regions = meta.regions;
        }
        if (meta.langs.length) {
          payload.langs = meta.langs;
        }
        if (meta.aliases.length) {
          payload.aliases = meta.aliases.slice(0, MAX_KEYWORD_ALIASES);
        }
        if (Object.keys(meta.regionLangs).length) {
          payload.regionLangs = meta.regionLangs;
        }
        if (previousCount === 0) {
          payload.inactiveAt = nowIso;
        }
        tx.set(previousRef, payload, { merge: true });
      }
      if (previousLegacyRef) {
        tx.delete(previousLegacyRef);
      }
    } else if (previousRef && sameKey) {
      const baseCount = baseCountFrom(previousSnap, previousLegacySnap);
      previousCount = baseCount;
    }

    if (nextRef && nextKey) {
      const baseCount = baseCountFrom(nextSnap, nextLegacySnap);
      nextCount = sameKey ? baseCount : baseCount + 1;
      const meta = mergedMeta(nextSnap, nextLegacySnap);
      const hasRegionBefore = region
        ? meta.regions.includes(region) &&
          normalizeLangCode(meta.regionLangs?.[region] || "", "") === feedLang
        : true;
      const hasLangBefore = lang ? meta.langs.includes(lang) : true;
      const hadConditionBefore = baseCount > 0 && hasRegionBefore && hasLangBefore;
      if (region) {
        meta.regions = mergeArrays(meta.regions, [region]);
        meta.regionLangs[region] = feedLang;
      }
      if (lang) {
        meta.langs = mergeArrays(meta.langs, [lang]);
      }
      if (nextRaw) {
        meta.aliases = mergeArrays(meta.aliases, [nextRaw]);
      }
      const payload = {
        canonical: nextSafe,
        key: nextKey,
        count: Math.max(0, nextCount),
        updatedAt: nowIso
      };
      if (nextCount <= 0) {
        tx.delete(nextRef);
        if (nextLegacyRef) {
          tx.delete(nextLegacyRef);
        }
      } else {
        if (meta.regions.length) {
          payload.regions = meta.regions;
        }
        if (meta.langs.length) {
          payload.langs = meta.langs;
        }
        if (meta.aliases.length) {
          payload.aliases = meta.aliases.slice(0, MAX_KEYWORD_ALIASES);
        }
        if (Object.keys(meta.regionLangs).length) {
          payload.regionLangs = meta.regionLangs;
        }
        payload.inactiveAt = FieldValue.delete();
        tx.set(nextRef, payload, { merge: true });
        if (nextLegacyRef) {
          tx.delete(nextLegacyRef);
        }
        if (!hadConditionBefore) {
          txNextConditionAdded = true;
        }
      }
    }

    if (hasTabIndex) {
      const userData = userSnap.exists ? userSnap.data() || {} : {};
      const tabKeywords = normalizeStringArray(
        userData.tabKeywords,
        TAB_COUNT,
        ""
      );
      tabKeywords[tabIndex] = nextRaw;
      const canonicalMap = normalizeCanonicalKeywords(userData.canonicalKeywords);
      if (nextSafe) {
        canonicalMap[String(tabIndex)] = nextSafe;
      } else {
        delete canonicalMap[String(tabIndex)];
      }
      tx.set(
        userRef,
        {
          tabKeywords,
          canonicalKeywords: canonicalMap,
          updatedAt: nowIso
        },
        { merge: true }
      );
    }
    nextConditionAdded = txNextConditionAdded;
  });

  return {
    previousCanonical: previousSafe,
    nextCanonical: nextSafe,
    previousCount,
    nextCount,
    nextConditionAdded,
    nextRegion: region,
    nextLang: lang,
    nextFeedLang: feedLang
  };
}

function makeSavedArticleId(payload = {}) {
  const url = (payload.resolvedUrl || payload.url || "").toString().trim();
  const title = (payload.title || "").toString().trim();
  const summary = (payload.summary || "").toString().trim();
  const seed = url || `${title}::${summary}`;
  return crypto.createHash("sha1").update(seed).digest("hex");
}

function makeArticleId(item = {}) {
  const url = (item.resolvedUrl || item.url || "").toString().trim();
  const source = (item.source || "").toString().trim();
  const title = (item.title || "").toString().trim();
  const summary = (item.summary || "").toString().trim();
  const seed =
    (url ? [url, source].filter(Boolean).join("::") : "") ||
    [title, summary, source].filter(Boolean).join("::") ||
    `${title}::${summary}`;
  return crypto.createHash("sha1").update(seed).digest("hex");
}

function normalizeCacheUrl(rawUrl = "") {
  const url = (rawUrl || "").toString().trim();
  if (!url) return "";
  try {
    const parsed = new URL(url);
    parsed.hash = "";
    parsed.search = "";
    parsed.hostname = parsed.hostname.toLowerCase();
    const normalized = parsed.toString().replace(/\/$/, "");
    return normalized;
  } catch {
    return url;
  }
}

function normalizePublishedDateKey(publishedAt) {
  const ts = Date.parse(publishedAt || "");
  if (Number.isNaN(ts)) return "";
  return new Date(ts).toISOString().slice(0, 10);
}

function buildArticleCacheSeed({
  resolvedUrl,
  url,
  source,
  title,
  summary,
  publishedAt
} = {}) {
  const urlKey = normalizeCacheUrl(resolvedUrl || url);
  if (urlKey) return `url::${urlKey}`;
  const parts = [];
  const safeSource = normalizeWhitespace(source || "").toLowerCase();
  const safeTitle = normalizeWhitespace(title || "").toLowerCase();
  const safeSummary = normalizeWhitespace(summary || "").toLowerCase();
  if (safeSource) parts.push(safeSource);
  if (safeTitle) parts.push(safeTitle);
  if (safeSummary) parts.push(safeSummary);
  const dateKey = normalizePublishedDateKey(publishedAt);
  if (dateKey) parts.push(dateKey);
  if (!parts.length) return "";
  return `meta::${parts.join("::")}`;
}

function makeContentKey(item = {}) {
  const title = normalizeWhitespace(item.title || "");
  const summary = normalizeWhitespace(item.summary || "");
  const source = normalizeWhitespace(item.source || "");
  if (!title && !summary && !source) return "";
  return [title, summary, source].filter(Boolean).join("::");
}

function makeSentNotificationId(seed) {
  return crypto.createHash("sha1").update(seed).digest("hex");
}

async function getSentNotification(docId) {
  const db = getFirestore();
  if (!db) return null;
  const doc = await db.collection("sent_notifications").doc(docId).get();
  if (!doc.exists) return null;
  return doc.data() || null;
}

async function setSentNotification(docId, payload = {}) {
  const db = getFirestore();
  if (!db) return;
  await db.collection("sent_notifications").doc(docId).set(
    {
      ...payload,
      sentAt: new Date().toISOString()
    },
    { merge: true }
  );
}

async function setKeywordMapping(original, canonical, lang) {
  const docId = makeKeywordDocId(original);
  const db = getFirestore();
  if (!db) return;
  await db.collection("keywords").doc(docId).set(
    {
      original,
      canonical,
      language: lang || "unknown",
      updatedAt: new Date().toISOString(),
      lastSeenAt: new Date().toISOString(),
      originals: FieldValue.arrayUnion(original)
    },
    { merge: true }
  );
}

function extractParagraphText(doc) {
  const candidates = [];
  const selectors = [
    "article",
    "main",
    "section",
    "div[itemprop='articleBody']",
    "div[class*='article']",
    "div[class*='content']",
    "div[class*='story']"
  ];

  for (const selector of selectors) {
    const node = doc.querySelector(selector);
    if (!node) continue;
    const text = Array.from(node.querySelectorAll("p"))
      .map((p) => p.textContent || "")
      .join(" ");
    candidates.push(text);
  }

  const bodyText = Array.from(doc.querySelectorAll("body p"))
    .map((p) => p.textContent || "")
    .join(" ");
  if (bodyText) {
    candidates.push(bodyText);
  }

  const longest = candidates.reduce((acc, cur) => {
    return cur.length > acc.length ? cur : acc;
  }, "");
  return normalizeWhitespace(longest);
}

function summarizeText(text, maxSentences = 3) {
  const cleaned = normalizeWhitespace(text);
  if (!cleaned) return "";
  const sentences = cleaned.split(/(?<=[.?!])\s+/);
  if (sentences.length === 1) {
    return cleaned.slice(0, 420);
  }
  return sentences.slice(0, maxSentences).join(" ").trim();
}

function summarySentenceCount(length) {
  switch ((length || "").toLowerCase()) {
    case "short":
      return 3;
    case "long":
      return 10;
    case "medium":
    default:
      return 6;
  }
}

let cachedServiceAccount = null;

function loadServiceAccount() {
  if (cachedServiceAccount) return cachedServiceAccount;
  try {
    const serviceJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const servicePath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (serviceJson) {
      cachedServiceAccount = JSON.parse(serviceJson);
      return cachedServiceAccount;
    }
    if (servicePath && fs.existsSync(servicePath)) {
      const raw = fs.readFileSync(servicePath, "utf8");
      cachedServiceAccount = JSON.parse(raw);
      return cachedServiceAccount;
    }
  } catch (error) {
    console.error("Firebase service account parse failed:", error.message || error);
  }
  return null;
}

let cachedPublisherCredentials = null;
let cachedAndroidPublisher = null;
const cachedOneStoreTokenByBaseUrl = new Map();

function loadAndroidPublisherCredentials() {
  if (cachedPublisherCredentials) return cachedPublisherCredentials;
  if (ANDROID_PUBLISHER_CREDENTIALS_JSON) {
    try {
      cachedPublisherCredentials = JSON.parse(ANDROID_PUBLISHER_CREDENTIALS_JSON);
      return cachedPublisherCredentials;
    } catch (error) {
      console.error(
        "Android Publisher credentials JSON parse failed:",
        error.message || error
      );
    }
  }
  if (ANDROID_PUBLISHER_CREDENTIALS_PATH) {
    try {
      const raw = fs.readFileSync(ANDROID_PUBLISHER_CREDENTIALS_PATH, "utf8");
      cachedPublisherCredentials = JSON.parse(raw || "{}");
      return cachedPublisherCredentials;
    } catch (error) {
      console.error(
        "Android Publisher credentials file read failed:",
        error.message || error
      );
    }
  }
  return null;
}

function parseIapProductMap(raw) {
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object") return {};
    const cleaned = {};
    for (const [key, value] of Object.entries(parsed)) {
      const tokens = Number.parseInt(value, 10);
      if (!key || Number.isNaN(tokens) || tokens <= 0) continue;
      cleaned[String(key)] = tokens;
    }
    return cleaned;
  } catch (error) {
    console.error("IAP product map parse failed:", error.message || error);
    return {};
  }
}

function parseAllowedAdUnits(raw) {
  if (!raw) return new Set();
  return new Set(
    raw
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean)
  );
}

const ADMOB_ALLOWED_AD_UNITS = parseAllowedAdUnits(ADMOB_ALLOWED_AD_UNITS_RAW);
let cachedAdmobKeys = null;
let cachedAdmobKeysAt = 0;

async function loadAdmobPublicKeys() {
  const now = Date.now();
  if (cachedAdmobKeys && now - cachedAdmobKeysAt < 12 * 60 * 60 * 1000) {
    return cachedAdmobKeys;
  }
  const response = await fetch(ADMOB_SSV_KEYS_URL);
  if (!response.ok) {
    throw new Error(`admob_key_fetch_failed:${response.status}`);
  }
  const payload = await response.json();
  const keys = new Map();
  if (payload && Array.isArray(payload.keys)) {
    for (const item of payload.keys) {
      const keyId = Number.parseInt(item.keyId, 10);
      if (!Number.isFinite(keyId)) continue;
      if (item.pem) {
        keys.set(keyId, item.pem);
      } else if (item.base64) {
        const pem = [
          "-----BEGIN PUBLIC KEY-----",
          item.base64,
          "-----END PUBLIC KEY-----"
        ].join("\n");
        keys.set(keyId, pem);
      }
    }
  }
  if (keys.size === 0) {
    throw new Error("admob_key_parse_failed");
  }
  cachedAdmobKeys = keys;
  cachedAdmobKeysAt = now;
  return keys;
}

async function getAndroidPublisherService() {
  if (cachedAndroidPublisher) return cachedAndroidPublisher;
  if (!ANDROID_PUBLISHER_PACKAGE_NAME) return null;
  const credentials = loadAndroidPublisherCredentials();
  if (!credentials) return null;
  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"]
  });
  const client = await auth.getClient();
  cachedAndroidPublisher = google.androidpublisher({
    version: "v3",
    auth: client
  });
  return cachedAndroidPublisher;
}

function getFirestore() {
  if (!FIRESTORE_ENABLED) return null;
  if (firestore) return firestore;
  const serviceAccount = loadServiceAccount();
  if (serviceAccount?.client_email && serviceAccount?.private_key) {
    firestore = new Firestore({
      projectId: serviceAccount.project_id,
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key
      }
    });
  } else {
    firestore = new Firestore();
  }
  return firestore;
}

function initFirebaseAdmin() {
  if (firebaseApp) return firebaseApp;
  try {
    const serviceAccount = loadServiceAccount();
    if (serviceAccount) {
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
      return firebaseApp;
    }
  } catch (error) {
    console.error("Firebase admin init failed:", error.message || error);
  }
  return null;
}

function getFirebaseMessaging() {
  const appInstance = initFirebaseAdmin();
  if (!appInstance) return null;
  return admin.messaging();
}

async function touchUserLastActive(db, uid) {
  if (!db || !uid) return;
  if (userActiveTouchCache.has(uid)) return;
  userActiveTouchCache.set(uid, true);
  try {
    await db
      .collection("users")
      .doc(uid)
      .set({ lastActiveAt: new Date().toISOString() }, { merge: true });
  } catch (error) {
    console.error("touchUserLastActive failed:", uid, error?.message || error);
  }
}

async function getVerifiedUser(req, res) {
  const authHeader = req.headers.authorization || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    res.status(401).json({ ok: false, error: "missing_auth" });
    return null;
  }
  const appInstance = initFirebaseAdmin();
  if (!appInstance) {
    res.status(503).json({ ok: false, error: "auth_unavailable" });
    return null;
  }
  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    if (!decoded || !decoded.uid) {
      return decoded;
    }
    if (isAdminUser(decoded)) {
      return decoded;
    }
    const db = getFirestore();
    if (db) {
      try {
        const userSnap = await db.collection("users").doc(decoded.uid).get();
        const userData = userSnap.data() || {};
        if (userData.banned === true) {
          res.status(403).json({ ok: false, error: "user_banned" });
          return null;
        }
        touchUserLastActive(db, decoded.uid);
      } catch (error) {
        console.error("Auth ban check failed:", error?.message || error);
      }
    }
    return decoded;
  } catch (error) {
    console.error("Auth token verify failed:", error.message || error);
    res.status(401).json({ ok: false, error: "invalid_auth" });
    return null;
  }
}

function isAdminUser(user) {
  if (!user) return false;
  if (user.admin === true) return true;
  if (user.uid && ADMIN_UIDS.has(user.uid)) return true;
  const email = (user.email || "").toLowerCase();
  if (email && ADMIN_EMAILS.has(email)) return true;
  return false;
}

async function requireAdmin(req, res) {
  const user = await getVerifiedUser(req, res);
  if (!user) return null;
  if (!isAdminUser(user)) {
    res.status(403).json({ ok: false, error: "forbidden" });
    return null;
  }
  return user;
}

function clampSeverity(value) {
  const parsed = Number.parseInt(value, 10);
  if (Number.isNaN(parsed)) return 3;
  return Math.min(5, Math.max(1, parsed));
}

function fallbackSeverityScore(text) {
  const lower = (text || "").toLowerCase();
  if (!lower) return 3;
  const criticalSignals = [
    "war",
    "assassination",
    "earthquake",
    "tsunami",
    "pandemic",
    "global market crash",
    "nuclear",
    "missile",
    "mass casualties",
    "state of emergency",
    // ko/ja/fr/es/ru/ar
    "전쟁",
    "암살",
    "지진",
    "쓰나미",
    "팬데믹",
    "핵",
    "미사일",
    "대규모 사상",
    "비상사태",
    "戦争",
    "暗殺",
    "地震",
    "津波",
    "パンデミック",
    "核",
    "ミサイル",
    "非常事態",
    "guerre",
    "assassinat",
    "séisme",
    "tremblement de terre",
    "pandémie",
    "nucléaire",
    "victimes massives",
    "état d'urgence",
    "guerra",
    "asesinato",
    "terremoto",
    "pandemia",
    "nuclear",
    "víctimas masivas",
    "estado de emergencia",
    "война",
    "убийство",
    "землетрясение",
    "пандемия",
    "ядер",
    "ракета",
    "массовые жертвы",
    "чрезвычайное положение",
    "حرب",
    "اغتيال",
    "زلزال",
    "جائحة",
    "نووي",
    "صاروخ",
    "ضحايا",
    "حالة الطوارئ"
  ];
  if (criticalSignals.some((word) => lower.includes(word))) return 5;

  const highSignals = [
    "election result",
    "president election",
    "policy change",
    "bankruptcy",
    "merger",
    "plane crash",
    "interest rate",
    "rate hike",
    "rate cut",
    "major accident",
    // ko/ja/fr/es/ru/ar
    "선거 결과",
    "대선",
    "정책 변경",
    "파산",
    "합병",
    "항공기 사고",
    "금리",
    "금리 인상",
    "금리 인하",
    "대형 사고",
    "選挙結果",
    "大統領選",
    "政策変更",
    "破産",
    "合併",
    "航空機事故",
    "金利",
    "利上げ",
    "利下げ",
    "重大事故",
    "résultat électoral",
    "élection présidentielle",
    "changement de politique",
    "faillite",
    "fusion",
    "crash d'avion",
    "taux d'intérêt",
    "hausse des taux",
    "baisse des taux",
    "accident majeur",
    "resultado electoral",
    "elección presidencial",
    "cambio de política",
    "bancarrota",
    "fusión",
    "accidente aéreo",
    "tasa de interés",
    "subida de tipos",
    "bajada de tipos",
    "accidente grave",
    "результаты выборов",
    "президентские выборы",
    "изменение политики",
    "банкротство",
    "слияние",
    "авиакатастрофа",
    "процентная ставка",
    "повышение ставки",
    "снижение ставки",
    "крупная авария",
    "نتائج الانتخابات",
    "انتخابات رئاسية",
    "تغيير السياسة",
    "إفلاس",
    "اندماج",
    "حادث طائرة",
    "سعر الفائدة",
    "رفع الفائدة",
    "خفض الفائدة",
    "حادث كبير"
  ];
  if (highSignals.some((word) => lower.includes(word))) return 4;

  const moderateSignals = [
    "stock",
    "earnings",
    "product launch",
    "sports final",
    "lawsuit",
    "acquisition",
    "award",
    // ko/ja/fr/es/ru/ar
    "주식",
    "실적",
    "신제품",
    "결승",
    "소송",
    "인수",
    "수상",
    "株",
    "決算",
    "新製品",
    "決勝",
    "訴訟",
    "買収",
    "受賞",
    "action",
    "résultats",
    "lancement de produit",
    "finale",
    "procès",
    "acquisition",
    "prix",
    "acción",
    "resultados",
    "lanzamiento",
    "final",
    "demanda",
    "adquisición",
    "premio",
    "акции",
    "прибыль",
    "запуск продукта",
    "финал",
    "иск",
    "поглощение",
    "награда",
    "أسهم",
    "أرباح",
    "إطلاق منتج",
    "النهائي",
    "دعوى",
    "استحواذ",
    "جائزة"
  ];
  if (moderateSignals.some((word) => lower.includes(word))) return 3;

  const lowSignals = [
    "weather",
    "forecast",
    "entertainment",
    "dating",
    "local crime",
    "movie",
    "drama",
    // ko/ja/fr/es/ru/ar
    "날씨",
    "예보",
    "연예",
    "연애",
    "지역 범죄",
    "영화",
    "드라마",
    "天気",
    "予報",
    "芸能",
    "恋愛",
    "地域犯罪",
    "映画",
    "ドラマ",
    "météo",
    "prévision",
    "divertissement",
    "rencontre",
    "crime local",
    "film",
    "série",
    "clima",
    "pronóstico",
    "entretenimiento",
    "citas",
    "crimen local",
    "película",
    "drama",
    "погода",
    "прогноз",
    "развлечения",
    "знакомства",
    "местное преступление",
    "фильм",
    "драма",
    "الطقس",
    "توقعات",
    "ترفيه",
    "مواعدة",
    "جريمة محلية",
    "فيلم",
    "دراما"
  ];
  if (lowSignals.some((word) => lower.includes(word))) return 2;

  const minorSignals = [
    "gossip",
    "rumor",
    "tips",
    "best 10",
    "listicle",
    "funny",
    // ko/ja/fr/es/ru/ar
    "가십",
    "루머",
    "팁",
    "베스트",
    "리스트",
    "웃긴",
    "ゴシップ",
    "噂",
    "ヒント",
    "ベスト",
    "リスト",
    "面白い",
    "ragot",
    "rumeur",
    "astuces",
    "meilleur",
    "liste",
    "drôle",
    "chisme",
    "rumor",
    "consejos",
    "mejor",
    "lista",
    "divertido",
    "сплетни",
    "слухи",
    "советы",
    "лучшие",
    "список",
    "смешно",
    "شائعة",
    "إشاعة",
    "نصائح",
    "أفضل",
    "قائمة",
    "مضحك"
  ];
  if (minorSignals.some((word) => lower.includes(word))) return 1;

  return 3;
}

function keywordRelevanceScore(keyword, title, summary) {
  const key = normalizeWhitespace(keyword || "").toLowerCase();
  if (!key) return 0;
  const titleText = normalizeWhitespace(title || "").toLowerCase();
  const summaryText = normalizeWhitespace(summary || "").toLowerCase();
  if (titleText.includes(key) || summaryText.includes(key)) return 18;
  return 0;
}

async function getCanonicalKeyword(keyword, lang, options = {}) {
  if (isBreakingKeyword(keyword)) {
    return BREAKING_KEYWORD;
  }
  const allowModel = options.allowModel !== false;
  const normalized = keywordKey(keyword);
  if (!normalized) return keyword;
  const cached = canonicalCache.get(normalized);
  if (cached) return cached;

  const db = getFirestore();
  if (db) {
    const docId = makeKeywordDocId(keyword);
    try {
      const doc = await db.collection("keywords").doc(docId).get();
      if (doc.exists) {
        const canonical = doc.data()?.canonical;
        if (canonical) {
          canonicalCache.set(normalized, canonical);
          return canonical;
        }
      }
    } catch (error) {
      console.error("Canonical keyword lookup failed:", error?.message || error);
    }
  }

  if (!allowModel) {
    canonicalCache.set(normalized, keyword);
    return keyword;
  }

  if (!HAS_ANY_OPENAI_KEY) {
    canonicalCache.set(normalized, keyword);
    return keyword;
  }

  const prompt = [
    "Normalize a search keyword across languages into a single canonical keyword.",
    "Return a JSON object with exactly one key: canonical.",
    "Rules:",
    "- Use English if possible.",
    "- 1 to 3 words, lowercase unless a proper noun.",
    "- No punctuation, quotes, or extra text.",
    "- If it is already a proper name, keep the name."
  ].join(" ");

  let response;
  try {
    response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_TRANSLATE_MODEL,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You normalize keywords for global news search."
          },
          {
            role: "user",
            content: `${prompt}\nKeyword: ${keyword}\nLanguage hint: ${lang || "unknown"}`
          }
        ]
      },
      { label: "keyword_canonical", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`OpenAI canonical keyword timeout/error ${JSON.stringify(payload)}`);
    canonicalCache.set(normalized, keyword);
    return keyword;
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    const keyTag = response.__keyTag || null;
    console.error(
      `OpenAI canonical keyword error ${response.status} (${keyTag || "unknown"}): ${errorBody.slice(0, 400)}`
    );
    canonicalCache.set(normalized, keyword);
    return keyword;
  }

  const data = await response.json();
  const raw = data?.choices?.[0]?.message?.content?.trim();
  try {
    const parsed = JSON.parse(raw);
    const canonical = normalizeWhitespace(parsed.canonical || keyword);
    const safeCanonical = canonical || keyword;
    canonicalCache.set(normalized, safeCanonical);
    await setKeywordMapping(keyword, safeCanonical, lang);
    return safeCanonical;
  } catch {
    canonicalCache.set(normalized, keyword);
    return keyword;
  }
}

async function getCachedSeverity(docId) {
  const db = getFirestore();
  if (!db) return null;
  const doc = await db.collection("severity").doc(docId).get();
  if (!doc.exists) return null;
  return doc.data()?.value ?? null;
}

function cacheExpiresAt(nowMs = Date.now()) {
  return new Date(nowMs + CACHE_DOC_TTL_MS);
}

async function setCachedSeverity(docId, value) {
  const db = getFirestore();
  if (!db) return;
  const nowMs = Date.now();
  await db.collection("severity").doc(docId).set(
    {
      value,
      updatedAt: new Date(nowMs).toISOString(),
      expiresAt: cacheExpiresAt(nowMs)
    },
    { merge: true }
  );
}

async function getCachedAlert(docId) {
  const db = getFirestore();
  if (!db) return null;
  const doc = await db.collection("alerts").doc(docId).get();
  if (!doc.exists) return null;
  return doc.data() || null;
}

async function setCachedAlert(docId, payload) {
  const db = getFirestore();
  if (!db) return;
  const nowMs = Date.now();
  await db.collection("alerts").doc(docId).set(
    {
      ...payload,
      sentAt: new Date(nowMs).toISOString(),
      expiresAt: cacheExpiresAt(nowMs)
    },
    { merge: true }
  );
}

let cachedProjectId = null;
let cachedTasksClient = null;
let cloudTasksAvailable = true;

async function resolveProjectId() {
  if (cachedProjectId) return cachedProjectId;
  const envProject =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    process.env.PROJECT_ID ||
    "";
  if (envProject) {
    cachedProjectId = envProject;
    return cachedProjectId;
  }
  try {
    cachedProjectId = await google.auth.getProjectId();
  } catch (error) {
    console.error("[CloudTasks] project id resolve failed", error?.message || error);
  }
  return cachedProjectId;
}

async function getCloudTasksClient() {
  if (cachedTasksClient) return cachedTasksClient;
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-tasks"]
  });
  const client = await auth.getClient();
  cachedTasksClient = google.cloudtasks({ version: "v2", auth: client });
  return cachedTasksClient;
}

function buildServiceUrl(req) {
  if (SERVICE_URL) return SERVICE_URL;
  const proto =
    req.headers["x-forwarded-proto"] ||
    req.protocol ||
    "https";
  const host = req.get("host");
  return `${proto}://${host}`;
}

function isCloudTasksRequest(req) {
  return Boolean(req.headers["x-cloudtasks-queuename"]);
}

async function enqueueCrawlTasks(tasks, req) {
  if (!cloudTasksAvailable) {
    return { ok: false, error: "cloud_tasks_unavailable", enqueued: 0 };
  }
  const projectId = await resolveProjectId();
  if (!projectId) {
    cloudTasksAvailable = false;
    return { ok: false, error: "project_id_missing", enqueued: 0 };
  }
  let client;
  try {
    client = await getCloudTasksClient();
  } catch (error) {
    cloudTasksAvailable = false;
    console.error("[CloudTasks] client init failed", error?.message || error);
    return { ok: false, error: "client_init_failed", enqueued: 0 };
  }

  const parent = `projects/${projectId}/locations/${CLOUD_TASKS_LOCATION}/queues/${CLOUD_TASKS_QUEUE}`;
  const baseUrl = buildServiceUrl(req);
  const url = `${baseUrl}/tasks/crawl`;
  let enqueued = 0;
  let failed = 0;
  try {
    await client.projects.locations.queues.get({ name: parent });
  } catch (error) {
    cloudTasksAvailable = false;
    console.error("[CloudTasks] queue unavailable", error?.message || error);
    return { ok: false, error: "queue_unavailable", enqueued: 0 };
  }
  await mapWithLimit(tasks, 6, async (task) => {
    try {
      const payload = {
        keyword: task.keyword,
        canonicalKeyword: task.keyword,
        lang: task.lang,
        feedLang: task.feedLang,
        region: task.region,
        limit: task.limit || 20,
        aliases: task.aliases || []
      };
      const body = Buffer.from(JSON.stringify(payload)).toString("base64");
      const httpRequest = {
        httpMethod: "POST",
        url,
        headers: { "Content-Type": "application/json" },
        body
      };
      if (CLOUD_TASKS_SERVICE_ACCOUNT) {
        httpRequest.oidcToken = {
          serviceAccountEmail: CLOUD_TASKS_SERVICE_ACCOUNT
        };
      }
      const taskRequest = { httpRequest };
      if (CLOUD_TASKS_DISPATCH_DEADLINE_SEC > 0) {
        taskRequest.dispatchDeadline = `${CLOUD_TASKS_DISPATCH_DEADLINE_SEC}s`;
      }
      await client.projects.locations.queues.tasks.create({
        parent,
        requestBody: {
          task: taskRequest
        }
      });
      enqueued += 1;
    } catch (error) {
      failed += 1;
      console.error("[CloudTasks] enqueue failed", error?.message || error);
    }
  });
  if (failed && failed === tasks.length) {
    cloudTasksAvailable = false;
    return { ok: false, error: "enqueue_failed", enqueued };
  }
  return { ok: true, enqueued, failed };
}

function normalizeCrawlTaskIdentity(task = {}) {
  const keyword = normalizeWhitespace(
    task.keyword || task.canonicalKeyword || ""
  );
  if (!keyword) return null;
  const region = normalizeRegionCode(task.region || "ALL", "ALL");
  const lang = normalizeLangCode(task.lang || "en");
  const feedLang = normalizeLangCode(task.feedLang || lang);
  const key = `${keywordKey(keyword)}::${region}::${feedLang}::${lang}`;
  return { key, keyword, region, feedLang, lang };
}

function makeCrawlSkipOnceDocId(task = {}) {
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) return "";
  return crypto.createHash("sha256").update(identity.key).digest("hex");
}

async function markSkipNextScheduledCrawl(task, options = {}) {
  const db = getFirestore();
  if (!db) return false;
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) return false;
  const docId = makeCrawlSkipOnceDocId(identity);
  if (!docId) return false;
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const reason = normalizeWhitespace(options.reason || "");
  await db
    .collection(CRAWL_SKIP_ONCE_COLLECTION)
    .doc(docId)
    .set(
      {
        key: identity.key,
        keyword: identity.keyword,
        region: identity.region,
        feedLang: identity.feedLang,
        lang: identity.lang,
        skipCount: 1,
        reason,
        createdAt: nowIso,
        updatedAt: nowIso,
        expiresAt: new Date(nowMs + CRAWL_SKIP_ONCE_TTL_MS).toISOString()
      },
      { merge: true }
    );
  return true;
}

async function consumeScheduledSkipOnce(tasks = []) {
  if (!Array.isArray(tasks) || tasks.length === 0) {
    return { tasks: [], skipped: 0 };
  }
  const db = getFirestore();
  if (!db) return { tasks, skipped: 0 };

  const entries = tasks.map((task) => {
    const identity = normalizeCrawlTaskIdentity(task);
    if (!identity) return { task, identity: null, docId: "" };
    const docId = makeCrawlSkipOnceDocId(identity);
    return { task, identity, docId };
  });
  const uniqueRefMap = new Map();
  for (const entry of entries) {
    if (!entry.docId || uniqueRefMap.has(entry.docId)) continue;
    uniqueRefMap.set(
      entry.docId,
      db.collection(CRAWL_SKIP_ONCE_COLLECTION).doc(entry.docId)
    );
  }
  if (uniqueRefMap.size === 0) {
    return { tasks, skipped: 0 };
  }

  let snapshots = [];
  try {
    snapshots = await db.getAll(...Array.from(uniqueRefMap.values()));
  } catch (error) {
    console.error("[CrawlSkipOnce] read failed", error?.message || error);
    return { tasks, skipped: 0 };
  }
  const snapshotById = new Map();
  snapshots.forEach((snap) => {
    snapshotById.set(snap.id, snap);
  });

  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const output = [];
  let skipped = 0;
  let writeCount = 0;
  const batch = db.batch();

  for (const entry of entries) {
    if (!entry.docId) {
      output.push(entry.task);
      continue;
    }
    const snap = snapshotById.get(entry.docId);
    if (!snap || !snap.exists) {
      output.push(entry.task);
      continue;
    }
    const data = snap.data() || {};
    const expiresAtMs = Date.parse(data.expiresAt || "");
    const expired = Number.isFinite(expiresAtMs) && expiresAtMs <= nowMs;
    const skipCount = Math.max(0, Number(data.skipCount || 1));
    if (expired || skipCount <= 0) {
      batch.delete(snap.ref);
      writeCount += 1;
      output.push(entry.task);
      continue;
    }
    skipped += 1;
    if (skipCount <= 1) {
      batch.delete(snap.ref);
    } else {
      batch.set(
        snap.ref,
        {
          skipCount: skipCount - 1,
          consumedAt: nowIso,
          updatedAt: nowIso
        },
        { merge: true }
      );
    }
    writeCount += 1;
  }

  if (writeCount > 0) {
    try {
      await batch.commit();
    } catch (error) {
      console.error("[CrawlSkipOnce] write failed", error?.message || error);
    }
  }

  return { tasks: output, skipped };
}

async function hasCachedItemsForTask(task = {}) {
  const cacheState = await getTaskCacheState(task);
  return cacheState.exists;
}

function summarizeTaskCachedItems(items = [], nowMs = Date.now()) {
  const safeItems = Array.isArray(items) ? items : [];
  if (!safeItems.length) {
    return {
      exists: false,
      count: 0,
      hasProcessing: false,
      hasProcessed: false,
      onlyProcessing: false,
      processingAgeMs: null
    };
  }
  let hasProcessing = false;
  let hasProcessed = false;
  let oldestProcessingMs = null;
  for (const item of safeItems) {
    if (!item) continue;
    if (item.processing) {
      hasProcessing = true;
      const startedAtIso = parseDateIso(item.processingStartedAt);
      const startedAtMs = Date.parse(startedAtIso || "");
      if (Number.isFinite(startedAtMs)) {
        if (oldestProcessingMs === null || startedAtMs < oldestProcessingMs) {
          oldestProcessingMs = startedAtMs;
        }
      }
    } else {
      hasProcessed = true;
    }
  }
  const processingAgeMs =
    oldestProcessingMs === null ? null : Math.max(0, nowMs - oldestProcessingMs);
  return {
    exists: safeItems.length > 0,
    count: safeItems.length,
    hasProcessing,
    hasProcessed,
    onlyProcessing: hasProcessing && !hasProcessed,
    processingAgeMs
  };
}

async function getTaskCacheState(task = {}) {
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) {
    return {
      identity: null,
      exists: false,
      hasAnyCache: false,
      count: 0,
      hasProcessing: false,
      hasProcessed: false,
      onlyProcessing: false,
      processingAgeMs: null,
      cacheAgeMs: null
    };
  }
  const cacheId = makeNewsCacheId(
    identity.keyword,
    identity.region,
    identity.feedLang,
    identity.lang,
    20
  );
  const cachedMeta = await getCachedNewsMeta(cacheId);
  const cachedItems =
    cachedMeta && Array.isArray(cachedMeta.data?.items) ? cachedMeta.data.items : [];
  const summary = summarizeTaskCachedItems(cachedItems);
  const cacheAgeMs = Number.isFinite(cachedMeta?.ageMs) ? cachedMeta.ageMs : null;
  const fresh = cacheAgeMs !== null && cacheAgeMs <= ON_DEMAND_CACHE_FRESH_MS;
  const processingAgeMs =
    Number.isFinite(summary.processingAgeMs)
      ? summary.processingAgeMs
      : summary.hasProcessing && Number.isFinite(cacheAgeMs)
        ? cacheAgeMs
        : null;
  return {
    identity,
    ...summary,
    hasAnyCache: summary.exists,
    exists: summary.exists && fresh,
    processingAgeMs,
    cacheAgeMs
  };
}

function isProcessingRecoveryCoolingDown(identityKey, nowMs = Date.now()) {
  if (!identityKey) return false;
  const coolingUntilMs = Number(processingRecoveryCooldown.get(identityKey) || 0);
  return Number.isFinite(coolingUntilMs) && coolingUntilMs > nowMs;
}

function markProcessingRecoveryQueued(identityKey, nowMs = Date.now()) {
  if (!identityKey) return;
  processingRecoveryCooldown.set(
    identityKey,
    nowMs + PROCESSING_RECOVERY_COOLDOWN_MS
  );
  if (processingRecoveryCooldown.size <= 500) return;
  for (const [key, coolingUntilMs] of processingRecoveryCooldown.entries()) {
    if (!Number.isFinite(coolingUntilMs) || coolingUntilMs <= nowMs) {
      processingRecoveryCooldown.delete(key);
    }
  }
}

async function enqueueProcessingRecoveryIfNeeded(task = {}, req, options = {}) {
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) return { ok: false, reason: "invalid_task" };
  const nowMs = Date.now();
  if (isProcessingRecoveryCoolingDown(identity.key, nowMs)) {
    return { ok: false, reason: "cooldown" };
  }
  const cacheSummary = summarizeTaskCachedItems(options.items, nowMs);
  let cacheState = cacheSummary.exists
    ? { identity, ...cacheSummary }
    : await getTaskCacheState(identity);
  if (
    cacheState.onlyProcessing &&
    !Number.isFinite(cacheState.processingAgeMs)
  ) {
    const persistedCacheState = await getTaskCacheState(identity);
    if (persistedCacheState.onlyProcessing) {
      cacheState = persistedCacheState;
    }
  }
  if (!cacheState.onlyProcessing) {
    return { ok: false, reason: "not_processing_only", cacheState };
  }
  const force = options.force === true;
  if (
    !force &&
    (!Number.isFinite(cacheState.processingAgeMs) ||
      cacheState.processingAgeMs < PROCESSING_RECOVERY_TRIGGER_MS)
  ) {
    return { ok: false, reason: "processing_recent", cacheState };
  }
  const crawlResult = await runCrawlTasks(
    [
      {
        keyword: identity.keyword,
        canonicalKeyword: identity.keyword,
        region: identity.region,
        feedLang: identity.feedLang,
        lang: identity.lang,
        limit: 20
      }
    ],
    req
  );
  const queuedByTasks =
    crawlResult?.mode === "tasks" &&
    Number(crawlResult?.enqueued || 0) > 0;
  const completedInline =
    crawlResult?.mode === "inline" &&
    Number(crawlResult?.success || 0) > 0;
  if (queuedByTasks || completedInline) {
    markProcessingRecoveryQueued(identity.key, nowMs);
    await markSkipNextScheduledCrawl(identity, {
      reason: "processing_recovery"
    });
    return {
      ok: true,
      reason: "queued",
      mode: completedInline ? "inline" : "tasks",
      cacheState
    };
  }
  return {
    ok: false,
    reason:
      crawlResult?.error ||
      (crawlResult?.mode === "inline" ? "inline_failed" : "enqueue_failed"),
    cacheState
  };
}

async function canRunFastModeFallback(task = {}) {
  const db = getFirestore();
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) return { ok: false, reason: "invalid_task" };
  const cacheState = await getTaskCacheState(identity);
  if (cacheState.exists) {
    return { ok: false, reason: "cache_exists", cacheState };
  }
  if (cacheState.hasAnyCache) {
    return { ok: false, reason: "stale_cache_exists", cacheState };
  }
  if (!db) return { ok: true, reason: "no_firestore" };

  const docId = makeCrawlSkipOnceDocId(identity);
  if (!docId) return { ok: false, reason: "invalid_task" };
  const ref = db.collection(FASTMODE_FALLBACK_COLLECTION).doc(docId);
  const snap = await ref.get();
  const nowMs = Date.now();
  if (snap.exists) {
    const data = snap.data() || {};
    const lastTriggeredAtMs = Date.parse(data.lastTriggeredAt || "");
    if (
      Number.isFinite(lastTriggeredAtMs) &&
      nowMs - lastTriggeredAtMs < FASTMODE_FALLBACK_COOLDOWN_MS
    ) {
      return { ok: false, reason: "cooldown" };
    }
  }
  return { ok: true, reason: "cache_empty", ref };
}

async function markFastModeFallbackTriggered(task = {}, options = {}) {
  const db = getFirestore();
  if (!db) return false;
  const identity = normalizeCrawlTaskIdentity(task);
  if (!identity) return false;
  const docId = makeCrawlSkipOnceDocId(identity);
  if (!docId) return false;
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const reason = normalizeWhitespace(options.reason || "");
  await db
    .collection(FASTMODE_FALLBACK_COLLECTION)
    .doc(docId)
    .set(
      {
        key: identity.key,
        keyword: identity.keyword,
        region: identity.region,
        feedLang: identity.feedLang,
        lang: identity.lang,
        lastTriggeredAt: nowIso,
        reason,
        updatedAt: nowIso,
        expiresAt: new Date(
          nowMs + Math.max(FASTMODE_FALLBACK_COOLDOWN_MS * 3, 60 * 60 * 1000)
        ).toISOString()
      },
      { merge: true }
    );
  return true;
}

function resolveSourceKey({ sourceName, sourceUrl, resolvedUrl, url }) {
  const domain =
    hostFromUrl(sourceUrl) || hostFromUrl(resolvedUrl) || hostFromUrl(url) || "";
  if (domain && !isGoogleHost(domain)) {
    return normalizeSourceKey(domain);
  }
  return normalizeSourceKey(sourceName);
}

async function registerSourceFeedback({ sourceKey, action }) {
  if (!sourceKey) return null;
  const db = getFirestore();
  if (!db) return null;
  const docId = makeSourceDocId(sourceKey);
  const ref = db.collection("source_moderation").doc(docId);
  const now = new Date().toISOString();
  try {
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};
      const reportCount = (data.reportCount || 0) + (action === "report" ? 1 : 0);
      const blockCount = (data.blockCount || 0) + (action === "block" ? 1 : 0);
      let denied = data.denied === true;
      tx.set(
        ref,
        {
          sourceKey,
          reportCount,
          blockCount,
          denied,
          updatedAt: now
        },
        { merge: true }
      );
      return { reportCount, blockCount, denied };
    });
    if (result?.denied) {
      sourceDenylist.add(sourceKey);
      sourceModerationCache.set(sourceKey, false);
      sourceRatingCache.set(sourceKey, false);
    } else {
      sourceModerationCache.set(sourceKey, null);
    }
    return result;
  } catch (error) {
    console.error("[SourceModeration] update failed", error);
    return null;
  }
}

async function setSourceModerationDecision({
  sourceKey,
  denied,
  allowed,
  reason,
  decrementBlockCount
}) {
  if (!sourceKey) return null;
  const db = getFirestore();
  if (!db) return null;
  const normalizedKey = normalizeSourceKey(sourceKey);
  const docId = makeSourceDocId(normalizedKey);
  const ref = db.collection("source_moderation").doc(docId);
  const nowIso = new Date().toISOString();
  let payload = {
    sourceKey: normalizedKey,
    updatedAt: nowIso
  };
  if (typeof denied === "boolean") {
    payload.denied = denied;
  }
  if (typeof allowed === "boolean") {
    payload.allowed = allowed;
  }
  if (reason) {
    payload.reason = String(reason);
  }
  if (decrementBlockCount) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.exists ? snap.data() || {} : {};
      const currentBlocks = Number(data.blockCount || 0) || 0;
      payload = {
        ...payload,
        blockCount: Math.max(0, currentBlocks - 1)
      };
      tx.set(ref, payload, { merge: true });
    });
  } else {
    await ref.set(payload, { merge: true });
  }
  if (typeof denied === "boolean") {
    if (denied) {
      sourceDenylist.add(normalizedKey);
      sourceModerationCache.set(normalizedKey, false);
      sourceRatingCache.set(normalizedKey, false);
    } else {
      sourceDenylist.delete(normalizedKey);
      sourceModerationCache.set(
        normalizedKey,
        typeof allowed === "boolean" ? allowed : null
      );
    }
  } else if (typeof allowed === "boolean") {
    sourceModerationCache.set(normalizedKey, allowed);
  }
  return payload;
}

async function getOptionalUser(req) {
  const authHeader = req.headers.authorization || "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) return null;
  const appInstance = initFirebaseAdmin();
  if (!appInstance) return null;
  try {
    const decoded = await admin.auth().verifyIdToken(match[1]);
    return decoded;
  } catch {
    return null;
  }
}

async function collectAuthUserMetrics(options = {}) {
  const appInstance = initFirebaseAdmin();
  if (!appInstance) return null;
  const auth = admin.auth();
  const pageSize = Math.min(Math.max(Number(options.pageSize) || 1000, 100), 1000);
  let pageToken = undefined;
  let total = 0;
  let google = 0;
  let email = 0;
  let anonymous = 0;
  let other = 0;
  do {
    // eslint-disable-next-line no-await-in-loop
    const result = await auth.listUsers(pageSize, pageToken);
    result.users.forEach((userRecord) => {
      total += 1;
      const providers = Array.isArray(userRecord.providerData)
        ? userRecord.providerData.map((entry) => entry.providerId)
        : [];
      if (providers.includes("google.com")) {
        google += 1;
      }
      if (providers.includes("password")) {
        email += 1;
      }
      if (providers.length === 0) {
        anonymous += 1;
      }
      if (
        providers.length > 0 &&
        !providers.includes("google.com") &&
        !providers.includes("password")
      ) {
        other += 1;
      }
    });
    pageToken = result.pageToken;
  } while (pageToken);

  return {
    total,
    google,
    email,
    anonymous,
    other
  };
}

async function collectAdminUserMetrics(options = {}) {
  const db = getFirestore();
  if (!db) return null;
  const batchSize = Math.min(
    Math.max(Number(options.batchSize) || 500, 100),
    1000
  );
  const activeWindowMinutes = Math.min(
    60,
    Math.max(Number(options.activeWindowMinutes) || 10, 1)
  );
  const activeCutoffMs = Date.now() - activeWindowMinutes * 60 * 1000;
  let query = db
    .collection("users")
    .orderBy(FieldPath.documentId())
    .select("tabExpiry", "language", "lang", "lastActiveAt")
    .limit(batchSize);
  let lastDoc = null;
  let scanned = 0;
  const nowMs = Date.now();
  let paidTabsCount = 0;
  const userLanguageCounts = {};
  let activeAuthUsers = 0;

  while (true) {
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      const expiryMap = data.tabExpiry || {};
      for (let index = 2; index <= TAB_MAX_INDEX; index += 1) {
        const expiryValue = expiryMap[String(index)];
        if (!expiryValue) continue;
        const parsed = Date.parse(expiryValue);
        if (Number.isNaN(parsed)) continue;
        if (parsed > nowMs) {
          paidTabsCount += 1;
        }
      }
      const rawLang = data.language || data.lang || "";
      const normalizedLang = normalizeLangCode(rawLang || "", "");
      const langKey = normalizedLang || "unknown";
      userLanguageCounts[langKey] = (userLanguageCounts[langKey] || 0) + 1;

      const lastActiveMs = Date.parse(data.lastActiveAt || "");
      if (!Number.isNaN(lastActiveMs) && lastActiveMs >= activeCutoffMs) {
        activeAuthUsers += 1;
      }
    }
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize) break;
  }

  // Guest users (not logged in) tracked by token hash.
  let guestCount = 0;
  const guestLanguageCounts = {};
  let activeGuestUsers = 0;
  let guestQuery = db
    .collection("guest_users")
    .orderBy(FieldPath.documentId())
    .select("language", "linkedUid", "lastSeenAt")
    .limit(batchSize);
  let lastGuest = null;
  while (true) {
    if (lastGuest) {
      guestQuery = guestQuery.startAfter(lastGuest);
    }
    const snap = await guestQuery.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      if (data.linkedUid) continue;
      guestCount += 1;
      const rawLang = data.language || "";
      const normalizedLang = normalizeLangCode(rawLang || "", "");
      const langKey = normalizedLang || "unknown";
      guestLanguageCounts[langKey] = (guestLanguageCounts[langKey] || 0) + 1;

      const lastSeenMs = Date.parse(data.lastSeenAt || "");
      if (!Number.isNaN(lastSeenMs) && lastSeenMs >= activeCutoffMs) {
        activeGuestUsers += 1;
      }
    }
    lastGuest = snap.docs[snap.docs.length - 1];
    if (snap.size < batchSize) break;
  }

  const mergedLanguageCounts = { ...userLanguageCounts };
  Object.entries(guestLanguageCounts).forEach(([lang, count]) => {
    mergedLanguageCounts[lang] = (mergedLanguageCounts[lang] || 0) + count;
  });

  const authMetrics = await collectAuthUserMetrics();
  const authTotal = authMetrics?.total || 0;
  const googleUsers = authMetrics?.google || 0;
  const nonGoogleUsers = Math.max(0, authTotal - googleUsers);
  const totalUsers = authTotal + guestCount;
  const trackedDownloads = scanned + guestCount;
  const activeUsers = activeAuthUsers + activeGuestUsers;

  return {
    scanned,
    paidTabsCount,
    languageCounts: mergedLanguageCounts,
    auth: authMetrics,
    authTotal,
    googleUsers,
    nonGoogleUsers,
    guestUsers: guestCount,
    totalUsers,
    trackedDownloads,
    activeUsers,
    activeAuthUsers,
    activeGuestUsers,
    activeWindowMinutes
  };
}

async function fetchOnceWithTimeout(url, options = {}, timeoutMs = 10000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const dispatcher =
      options.dispatcher || resolveProxyDispatcher(url, options);
    const fetchOptions = { ...options, signal: controller.signal };
    delete fetchOptions.proxyUrl;
    delete fetchOptions.useProxy;
    if (dispatcher) {
      fetchOptions.dispatcher = dispatcher;
    }
    const response = await fetch(url, fetchOptions);
    return { response, proxyUsed: Boolean(dispatcher) };
  } finally {
    clearTimeout(timeout);
  }
}

function shouldRetryGoogleNewsWithProxyStatus(status) {
  if (!Number.isFinite(status)) return false;
  if (status >= 500) return true;
  return status === 403 || status === 408 || status === 425 || status === 429;
}

function isGoogleNewsProxyFallbackCandidate(url, options = {}) {
  if (!PROXY_GOOGLE_NEWS_ONLY || !GOOGLE_NEWS_PROXY_URL) return false;
  if (PROXY_ALL) return false;
  if (options.useProxy === false || options.useProxy === true) return false;
  if (options.dispatcher || options.proxyUrl) return false;
  return isGoogleNewsHost(hostFromUrl(url));
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 10000) {
  const host = hostFromUrl(url);
  const googleNewsHost = isGoogleNewsHost(host);
  const shouldTryProxyFallback = isGoogleNewsProxyFallbackCandidate(url, options);

  const firstOptions = shouldTryProxyFallback
    ? { ...options, useProxy: false }
    : options;

  try {
    const firstAttempt = await fetchOnceWithTimeout(url, firstOptions, timeoutMs);
    const firstResponse = firstAttempt.response;

    if (
      GOOGLE_NEWS_PROXY_AUTO &&
      googleNewsHost &&
      !firstAttempt.proxyUsed &&
      firstResponse?.status === 503
    ) {
      markGoogleNewsProxyCooldown("503");
    }

    if (
      shouldTryProxyFallback &&
      !firstAttempt.proxyUsed &&
      shouldRetryGoogleNewsWithProxyStatus(firstResponse?.status)
    ) {
      console.warn(
        `[Proxy] Google News fallback retry via proxy (status=${firstResponse.status})`
      );
      if (GOOGLE_NEWS_PROXY_AUTO) {
        markGoogleNewsProxyCooldown(`status_${firstResponse.status}`);
      }
      try {
        await firstResponse?.body?.cancel?.();
      } catch {}
      const retryAttempt = await fetchOnceWithTimeout(
        url,
        { ...options, useProxy: true },
        timeoutMs
      );
      return retryAttempt.response;
    }
    return firstResponse;
  } catch (error) {
    if (!shouldTryProxyFallback) {
      throw error;
    }
    console.warn(
      `[Proxy] Google News fallback retry via proxy (error=${
        error?.name || "fetch_failed"
      })`
    );
    if (GOOGLE_NEWS_PROXY_AUTO) {
      markGoogleNewsProxyCooldown(`error_${error?.name || "fetch_failed"}`);
    }
    const retryAttempt = await fetchOnceWithTimeout(
      url,
      { ...options, useProxy: true },
      timeoutMs
    );
    return retryAttempt.response;
  }
}

function getHostThrottleConfig(host) {
  if (!host) return null;
  const normalized = host.toLowerCase();
  if (normalized === "news.google.com" || normalized.endsWith(".news.google.com")) {
    return {
      minIntervalMs: GOOGLE_NEWS_MIN_INTERVAL_MS,
      backoffBaseMs: GOOGLE_NEWS_BACKOFF_BASE_MS,
      backoffMaxMs: GOOGLE_NEWS_BACKOFF_MAX_MS,
      backoffJitterMs: GOOGLE_NEWS_BACKOFF_JITTER_MS,
      skipThreshold: GOOGLE_NEWS_RSS_SKIP_THRESHOLD,
      skipMs: GOOGLE_NEWS_RSS_SKIP_MS
    };
  }
  return null;
}

function getHostThrottleState(host) {
  let state = hostThrottleState.get(host);
  if (!state) {
    state = { lastRequestAt: 0, backoffUntil: 0, consecutiveFailures: 0 };
    hostThrottleState.set(host, state);
  }
  return state;
}

async function applyHostThrottle(host, timeoutMs) {
  const config = getHostThrottleConfig(host);
  if (!config) return;
  const state = getHostThrottleState(host);
  const now = Date.now();
  const waitUntil = Math.max(
    state.lastRequestAt + config.minIntervalMs,
    state.backoffUntil || 0
  );
  if (waitUntil > now) {
    const waitMs = waitUntil - now;
    if (Number.isFinite(timeoutMs) && waitMs > timeoutMs) {
      const error = new Error("rss_throttle_skip");
      error.code = "rss_skip";
      error.skipUntil = waitUntil;
      throw error;
    }
    await sleep(waitMs);
  }
}

function recordHostResult(host, status) {
  const config = getHostThrottleConfig(host);
  if (!config) return;
  const state = getHostThrottleState(host);
  const now = Date.now();
  state.lastRequestAt = now;
  const ok = status >= 200 && status < 400;
  if (ok) {
    state.consecutiveFailures = 0;
    state.backoffUntil = 0;
    return;
  }
  state.consecutiveFailures += 1;
  if (status === 429 || status === 503) {
    const backoff = Math.min(
      config.backoffMaxMs,
      config.backoffBaseMs * Math.pow(2, Math.max(0, state.consecutiveFailures - 1))
    );
    const jitter = Math.floor(Math.random() * config.backoffJitterMs);
    state.backoffUntil = now + backoff + jitter;
  }
}

function getRssCacheKey(url) {
  return `rss::${url}`;
}

function getRssSkipUntil(cacheKey) {
  const entry = rssFailureCache.get(cacheKey);
  return entry?.skipUntil || 0;
}

function recordRssFailure(cacheKey, host) {
  const config = getHostThrottleConfig(host);
  if (!config) return;
  const now = Date.now();
  const entry = rssFailureCache.get(cacheKey) || {
    count: 0,
    lastFailAt: 0,
    skipUntil: 0
  };
  if (now - entry.lastFailAt > config.skipMs) {
    entry.count = 0;
    entry.skipUntil = 0;
  }
  entry.count += 1;
  entry.lastFailAt = now;
  if (entry.count >= config.skipThreshold) {
    entry.skipUntil = now + config.skipMs;
  }
  rssFailureCache.set(cacheKey, entry);
}

function clearRssFailure(cacheKey) {
  rssFailureCache.delete(cacheKey);
}

function isRssSkipError(error) {
  return error?.code === "rss_skip";
}

function isRssRateLimitedError(error) {
  const status = Number(error?.status);
  return status === 429 || status === 503;
}

function isRetryableRssError(error) {
  if (isRssSkipError(error)) return false;
  const status = Number(error?.status);
  if (status === 304) return false;
  if (!status) return true;
  if (status === 429 || status >= 500) return true;
  return false;
}

async function fetchRssFeed(url, options = {}) {
  const timeoutMs = Number.isFinite(options.timeoutMs)
    ? options.timeoutMs
    : TASK_TIMEOUT_MS;
  const lang = normalizeLangCode(options.lang || "");
  const region = normalizeRegionCode(options.region || "");
  const host = hostFromUrl(url);
  const cacheKey = getRssCacheKey(url);
  const skipUntil = getRssSkipUntil(cacheKey);
  if (skipUntil && skipUntil > Date.now()) {
    const error = new Error("rss_skip");
    error.code = "rss_skip";
    error.url = url;
    error.skipUntil = skipUntil;
    throw error;
  }

  try {
    await applyHostThrottle(host, timeoutMs);
  } catch (error) {
    if (error?.code === "rss_skip") {
      error.url = url;
    }
    throw error;
  }

  const cached = rssMetaCache.get(cacheKey);
  const headers = { ...RSS_REQUEST_HEADERS };
  const acceptLanguage = buildAcceptLanguageHeader(lang, region);
  if (acceptLanguage) {
    headers["Accept-Language"] = acceptLanguage;
  }
  if (cached?.etag) {
    headers["If-None-Match"] = cached.etag;
  }
  if (cached?.lastModified) {
    headers["If-Modified-Since"] = cached.lastModified;
  }

  let response;
  try {
    response = await fetchWithTimeout(url, { headers }, timeoutMs);
  } catch (error) {
    recordHostResult(host, 0);
    recordRssFailure(cacheKey, host);
    throw error;
  }

  recordHostResult(host, response.status);
  if (response.status === 304) {
    if (cached?.feed) {
      clearRssFailure(cacheKey);
      return cached.feed;
    }
    const error = new Error("rss_not_modified_without_cache");
    error.status = 304;
    error.url = url;
    throw error;
  }
  if (!response.ok) {
    recordRssFailure(cacheKey, host);
    const error = new Error(`rss_status_${response.status}`);
    error.status = response.status;
    error.url = url;
    throw error;
  }

  const body = await response.text();
  let feed;
  try {
    feed = await parser.parseString(body);
  } catch (error) {
    recordRssFailure(cacheKey, host);
    if (cached?.feed) {
      console.error("[Feed] parse failed, using cached feed", url, error?.message || error);
      return cached.feed;
    }
    throw error;
  }

  const etag = response.headers.get("etag") || "";
  const lastModified = response.headers.get("last-modified") || "";
  rssMetaCache.set(cacheKey, {
    etag: etag || cached?.etag || "",
    lastModified: lastModified || cached?.lastModified || "",
    feed
  });
  clearRssFailure(cacheKey);
  return feed;
}

function createLimiter(limit) {
  let active = 0;
  const queue = [];
  return (task) =>
    new Promise((resolve, reject) => {
      const run = () => {
        active += 1;
        Promise.resolve()
          .then(task)
          .then(resolve, reject)
          .finally(() => {
            active -= 1;
            if (queue.length) {
              const next = queue.shift();
              next();
            }
          });
      };
      if (active < limit) {
        run();
      } else {
        queue.push(run);
      }
    });
}

const openaiLimit = createLimiter(OPENAI_CONCURRENCY);
let openaiKeyIndex = 0;

function formatApiKeyTag(apiKey) {
  const value = (apiKey || "").trim();
  if (!value) return "none";
  const head = value.slice(0, 6);
  const tail = value.slice(-4);
  return `${head}...${tail}`;
}

async function fetchOpenAI(body, timeoutMs = 60000, apiKey = OPENAI_API_KEY) {
  return fetchWithTimeout(
    "https://api.openai.com/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify(body)
    },
    timeoutMs
  );
}

function isRetryableOpenAIStatus(status) {
  return status === 429 || (status >= 500 && status <= 599);
}

async function fetchOpenAIWithRetries(body, options = {}) {
  const timeoutMs = Number.isFinite(options.timeoutMs)
    ? options.timeoutMs
    : TRANSLATE_TIMEOUT_MS;
  const label = options.label || "openai";
  const retries = Number.isFinite(options.retries)
    ? options.retries
    : RETRY_ATTEMPTS;
  const keys = OPENAI_API_KEYS.length ? OPENAI_API_KEYS : [OPENAI_API_KEY];
  let attempt = 0;
  while (true) {
    try {
      const apiKey = keys[openaiKeyIndex] || OPENAI_API_KEY;
      const keyTag = formatApiKeyTag(apiKey);
      const response = await runWithTimeout(
        () => openaiLimit(() => fetchOpenAI(body, timeoutMs, apiKey)),
        timeoutMs,
        label
      );
      if (isRetryableOpenAIStatus(response.status)) {
        const errorBody = await response.text().catch(() => "");
        const error = new Error(`openai_${response.status}`);
        error.status = response.status;
        error.body = errorBody;
        error.keyTag = keyTag;
        throw error;
      }
      response.__keyTag = keyTag;
      return response;
    } catch (error) {
      if (!error?.keyTag) {
        const apiKey =
          keys[openaiKeyIndex] || keys[0] || OPENAI_API_KEY || "";
        error.keyTag = formatApiKeyTag(apiKey);
      }
      if (attempt >= retries) throw error;
      const status = error?.status;
      if (status === 429 && keys.length > 1) {
        openaiKeyIndex = (openaiKeyIndex + 1) % keys.length;
      }
      let backoff;
      if (status === 429) {
        backoff = Math.min(
          OPENAI_429_MAX_DELAY_MS,
          OPENAI_429_BASE_DELAY_MS * Math.pow(2, attempt)
        );
      } else {
        backoff = Math.min(
          RETRY_MAX_DELAY_MS,
          RETRY_BASE_DELAY_MS * Math.pow(2, attempt)
        );
      }
      const jitter = Math.floor(Math.random() * 200);
      await sleep(backoff + jitter);
      attempt += 1;
    }
  }
}

function extractExternalLink(doc) {
  const candidates = Array.from(doc.querySelectorAll("a"))
    .map((a) => a.getAttribute("href"))
    .filter(Boolean)
    .map((href) => href.trim())
    .filter((href) => href.startsWith("http"));
  return candidates.find((href) => !href.includes("news.google.com")) || null;
}

function isGoogleNewsArticleUrl(url) {
  return /news\.google\.com\/(rss\/)?articles\//i.test(url || "");
}

function normalizeGoogleNewsArticleUrl(url) {
  if (!url) return url;
  if (url.includes("/rss/articles/")) {
    return url.replace("/rss/articles/", "/articles/");
  }
  return url;
}

async function fetchGoogleNewsHtml(url, timeoutMs) {
  let currentUrl = url;
  for (let attempt = 0; attempt < 3; attempt++) {
    const response = await fetchWithTimeout(
      currentUrl,
      {
        redirect: "manual",
        headers: {
          ...HTML_REQUEST_HEADERS,
          "Accept-Language": "en-US,en;q=0.9"
        }
      },
      timeoutMs
    );

    const location = response.headers.get("location");
    if (location) {
      const nextUrl = new URL(location, currentUrl).toString();
      if (!nextUrl.includes("news.google.com")) {
        return { externalUrl: nextUrl };
      }
      currentUrl = nextUrl;
      if (response.status >= 300 && response.status < 400) {
        continue;
      }
    }

    const html = await response.text();
    return { html, finalUrl: currentUrl };
  }

  const finalResponse = await fetchWithTimeout(
    currentUrl,
    {
      redirect: "manual",
      headers: {
        ...HTML_REQUEST_HEADERS,
        "Accept-Language": "en-US,en;q=0.9"
      }
    },
    timeoutMs
  );
  const html = await finalResponse.text();
  return { html, finalUrl: currentUrl };
}

function decodeBatchUrl(rawUrl) {
  return rawUrl
    .replace(/\\u003d/g, "=")
    .replace(/\\u0026/g, "&")
    .replace(/\\u003f/g, "?")
    .replace(/\\u003a/g, ":")
    .replace(/\\u002f/g, "/");
}

function unescapeBatchValue(value) {
  return decodeBatchUrl(value)
    .replace(/\\\\/g, "\\")
    .replace(/\\\//g, "/")
    .replace(/\\"/g, '"');
}

function extractExternalUrlFromBatch(text) {
  const candidates = new Set();
  const rawMatches =
    text.match(/https?:\\\/\\\/[^"\\\s]+/g) ||
    text.match(/https?:\/\/[^\s"]+/g) ||
    [];

  for (const match of rawMatches) {
    candidates.add(unescapeBatchValue(match).trim());
  }

  const decodedText = unescapeBatchValue(text);
  const decodedMatches = decodedText.match(/https?:\/\/[^\s"]+/g) || [];
  for (const match of decodedMatches) {
    candidates.add(match.trim());
  }

  for (const candidate of candidates) {
    if (!candidate.includes("news.google.com") && !candidate.includes("google.com")) {
      return candidate;
    }
  }
  return null;
}

function extractExternalUrlFromText(text) {
  if (!text) return null;
  const candidates = new Set();
  const directMatches = text.match(/https?:\/\/[^\s"'<>]+/g) || [];
  for (const match of directMatches) {
    candidates.add(match.trim());
  }
  const encodedMatches =
    text.match(/https%3A%2F%2F[^\s"'<>]+/g) ||
    text.match(/https%3a%2f%2f[^\s"'<>]+/g) ||
    [];
  for (const match of encodedMatches) {
    try {
      candidates.add(decodeURIComponent(match).trim());
    } catch {
      candidates.add(match.trim());
    }
  }
  for (const candidate of candidates) {
    if (!candidate.includes("news.google.com") && !candidate.includes("google.com")) {
      return candidate;
    }
  }
  return null;
}

function extractExternalUrlFromRssItem(item) {
  if (!item || typeof item !== "object") return null;
  const fields = [
    item.content,
    item.contentSnippet,
    item.summary,
    item["content:encoded"],
    item["content:encodedSnippet"]
  ];
  for (const value of fields) {
    const text = typeof value === "string" ? value : "";
    if (!text) continue;
    const extracted = extractExternalUrlFromText(text);
    if (extracted) return extracted;
  }
  return null;
}

function extractBatchAtToken(html) {
  const atMatch =
    html.match(/"at"\s*:\s*"([^"]+)"/) ||
    html.match(/\["at"\s*,\s*"([^"]+)"\]/);
  if (atMatch) {
    return atMatch[1];
  }
  const fallback = html.match(/ASDl[0-9A-Za-z_-]+/);
  return fallback ? fallback[0] : null;
}

function extractGoogleNewsDataFromHtml(html) {
  let id = html.match(/data-n-a-id="([^"]+)"/)?.[1] || null;
  let ts = html.match(/data-n-a-ts="([^"]+)"/)?.[1] || null;
  let sig = html.match(/data-n-a-sg="([^"]+)"/)?.[1] || null;
  let externalUrl = null;

  if (!id || !ts || !sig) {
    const dataP = html.match(/data-p="([^"]+)"/)?.[1] || "";
    if (dataP) {
      const decoded = dataP
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/&amp;/g, "&");
      if (!externalUrl) {
        externalUrl = extractExternalUrlFromText(decoded);
      }
      if (!id) {
        id =
          decoded.match(/"(CBMi[^"]+)"/)?.[1] ||
          decoded.match(/"(CAAQ[^"]+)"/)?.[1] ||
          id;
      }
      if (!ts) {
        ts = decoded.match(/,(\d{9,13}),/)?.[1] || ts;
      }
      if (!sig) {
        sig = decoded.match(/ASDl[0-9A-Za-z_-]+/)?.[0] || sig;
      }
    }
  }

  if (!externalUrl) {
    externalUrl = extractExternalUrlFromText(html);
  }

  return { id, ts, sig, externalUrl };
}

function buildGoogleNewsBatchBodies(articleId, articleTs, articleSig, atToken) {
  if (!articleId || !articleTs || !articleSig) return [];
  const tsString = String(articleTs);
  const tsNumber = /^\d+$/.test(tsString) ? Number(tsString) : articleTs;
  const innerVariants = [
    { label: "ts:number", value: JSON.stringify([articleId, tsNumber, articleSig]) },
    { label: "ts:string", value: JSON.stringify([articleId, tsString, articleSig]) }
  ];
  const rpcVariants = [
    { label: "rpc:generic", value: "generic" },
    { label: "rpc:1", value: "1" }
  ];
  const atTokens = [];
  if (atToken) atTokens.push({ label: "at:token", value: atToken });
  if (articleSig && articleSig !== atToken) {
    atTokens.push({ label: "at:sig", value: articleSig });
  }
  if (atTokens.length === 0) {
    atTokens.push({ label: "at:empty", value: "" });
  }
  const bodies = [];
  for (const inner of innerVariants) {
    for (const rpc of rpcVariants) {
      const req = JSON.stringify([[[ "Fbv4je", inner.value, null, rpc.value ]]]);
      for (const at of atTokens) {
        const body = `f.req=${encodeURIComponent(req)}&at=${encodeURIComponent(at.value)}`;
        bodies.push({ body, label: `${inner.label}/${rpc.label}/${at.label}` });
      }
    }
  }
  return bodies;
}

async function resolveGoogleNewsUrl(url, timeoutMs = 10000) {
  const fetchUrl = normalizeGoogleNewsArticleUrl(url);
  const cacheKey = normalizeCacheUrl(fetchUrl);
  const cached = cacheKey ? googleNewsResolveCache.get(cacheKey) : null;
  if (cached) {
    return cached;
  }
  const cacheResolved = (value, ttlMs) => {
    if (!cacheKey || !value) return;
    if (ttlMs) {
      googleNewsResolveCache.set(cacheKey, value, { ttl: ttlMs });
    } else {
      googleNewsResolveCache.set(cacheKey, value);
    }
  };
  const fetchResult = await fetchGoogleNewsHtml(fetchUrl, timeoutMs);
  if (fetchResult.externalUrl) {
    cacheResolved(fetchResult.externalUrl);
    return fetchResult.externalUrl;
  }
  const html = fetchResult.html || "";
  const dom = new JSDOM(html);
  const doc = dom.window.document;

  const dataNode = doc.querySelector("[data-n-a-id]");
  let articleId = dataNode?.getAttribute("data-n-a-id") || null;
  let articleTs = dataNode?.getAttribute("data-n-a-ts") || null;
  let articleSig = dataNode?.getAttribute("data-n-a-sg") || null;

  if (!articleId || !articleTs || !articleSig) {
    const parsed = extractGoogleNewsDataFromHtml(html);
    if (!articleId) articleId = parsed.id;
    if (!articleTs) articleTs = parsed.ts;
    if (!articleSig) articleSig = parsed.sig;
    if (parsed.externalUrl) {
      cacheResolved(parsed.externalUrl);
      return parsed.externalUrl;
    }
  }

  if (!articleId || !articleTs || !articleSig) {
    console.error("Google News resolve: missing data attributes", {
      url: fetchUrl,
      hasId: Boolean(articleId),
      hasTs: Boolean(articleTs),
      hasSig: Boolean(articleSig)
    });
  }

  let atToken = extractBatchAtToken(html);
  if (!atToken && articleSig) {
    atToken = articleSig;
  }
  if (!atToken) {
    console.error("Google News resolve: missing at token");
  }

  const batchBodies = buildGoogleNewsBatchBodies(
    articleId,
    articleTs,
    articleSig,
    atToken
  );
  for (const attempt of batchBodies) {
    const batchResponse = await fetchWithTimeout(
      "https://news.google.com/_/DotsSplashUi/data/batchexecute?rpcids=Fbv4je",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "Origin": "https://news.google.com",
          "Referer": fetchUrl
        },
        body: attempt.body
      },
      timeoutMs
    );
    if (batchResponse.ok) {
      const batchText = await batchResponse.text();
      const resolved = extractExternalUrlFromBatch(batchText);
      if (resolved) {
        cacheResolved(resolved);
        return resolved;
      }
      const snippet = batchText.slice(0, 240);
      console.error(
        "Google News resolve: no external URL found in batch response",
        `len=${batchText.length} attempt=${attempt.label} snippet=${snippet}`
      );
    } else {
      console.error("Google News resolve: batch request failed", {
        status: batchResponse.status,
        attempt: attempt.label
      });
    }
  }

  const ogUrl = doc.querySelector('meta[property="og:url"]');
  const ogHref = ogUrl?.getAttribute("content");
  if (ogHref && !ogHref.includes("news.google.com")) {
    cacheResolved(ogHref);
    return ogHref;
  }
  const canonical = doc.querySelector('link[rel="canonical"]');
  const canonicalHref = canonical?.getAttribute("href");
  if (canonicalHref && !canonicalHref.includes("news.google.com")) {
    cacheResolved(canonicalHref);
    return canonicalHref;
  }

  const dataLink = doc.querySelector("a[data-n-au]");
  const dataHref = dataLink?.getAttribute("data-n-au");
  if (dataHref && dataHref.startsWith("http")) {
    cacheResolved(dataHref);
    return dataHref;
  }

  const external = extractExternalLink(doc);
  if (external) {
    cacheResolved(external);
    return external;
  }

  cacheResolved(url, 30 * 60 * 1000);
  return url;
}

async function resolveArticleUrl(url, timeoutMs = 10000) {
  if (isGoogleNewsArticleUrl(url)) {
    return resolveGoogleNewsUrl(url, timeoutMs);
  }
  const response = await fetchWithTimeout(
    url,
    {
      redirect: "manual",
      headers: {
        ...HTML_REQUEST_HEADERS
      }
    },
    timeoutMs
  );

  const location = response.headers.get("location");
  if (location && location.startsWith("http") && !location.includes("news.google.com")) {
    return location;
  }

  if (response.url && !response.url.includes("news.google.com")) {
    return response.url;
  }

  const html = await response.text();
  const dom = new JSDOM(html);
  const ogUrl = dom.window.document.querySelector('meta[property="og:url"]');
  const ogHref = ogUrl?.getAttribute("content");
  if (ogHref && !ogHref.includes("news.google.com")) {
    return ogHref;
  }
  const canonical = dom.window.document.querySelector('link[rel="canonical"]');
  const canonicalHref = canonical?.getAttribute("href");
  if (canonicalHref && !canonicalHref.includes("news.google.com")) {
    return canonicalHref;
  }

  const dataLink = dom.window.document.querySelector("a[data-n-au]");
  const dataHref = dataLink?.getAttribute("data-n-au");
  if (dataHref && dataHref.startsWith("http")) {
    return dataHref;
  }

  const external = extractExternalLink(dom.window.document);
  if (external) {
    return external;
  }

  return url;
}

async function extractArticle(url) {
  const cached = articleCache.get(url);
  if (cached) return cached;

  const resolvedUrl = await resolveArticleUrl(url);
  const response = await fetchWithTimeout(resolvedUrl, {
    headers: {
      ...HTML_REQUEST_HEADERS
    }
  });
  if (!response.ok) {
    throw new Error(`Failed to fetch article: ${response.status}`);
  }
  const html = await response.text();
  const dom = new JSDOM(html, { url: resolvedUrl });
  const reader = new Readability(dom.window.document);
  const parsed = reader.parse();

  let title = parsed?.title || dom.window.document.title || "";
  let content = parsed?.textContent || "";
  const paragraphText = extractParagraphText(dom.window.document);
  if (!content || content.length < 400) {
    content = dom.window.document.body?.textContent || content || "";
  }
  if (!content || content.length < 400) {
    if (paragraphText.length > content.length) {
      content = paragraphText;
    }
  }
  const endsWithEllipsis =
    content.trim().endsWith("...") || content.trim().endsWith("…");
  if (
    paragraphText.length > content.length &&
    (endsWithEllipsis || paragraphText.length > content.length * 1.2)
  ) {
    content = paragraphText;
  }
  title = normalizeWhitespace(title);
  content = normalizeWhitespace(content);

  const result = { title, content, resolvedUrl };
  articleCache.set(url, result);
  return result;
}

async function translateFields({ title, summary, url, cacheSeed }, targetLang) {
  const target = (targetLang || "en").toLowerCase().split("-")[0];
  if (!HAS_ANY_OPENAI_KEY) {
    return { title, summary };
  }

  const seed =
    cacheSeed || buildArticleCacheSeed({ url, title, summary });
  const cacheKey = `${target}::${title}::${summary}`;
  const cached = translationCache.get(cacheKey);
  if (cached) {
    if (AI_CACHE_DEBUG) {
      console.log("[AICache] translate_fields mem_hit", {
        target,
        seed: seed || "",
        hasUrl: Boolean(url)
      });
    }
    return cached;
  }
  if (seed) {
    const docId = makeTranslationDocIdFromSeed(seed, target, "summary");
    const stored = await getCachedTranslation(docId);
    if (stored) {
      if (AI_CACHE_DEBUG) {
        console.log("[AICache] translate_fields store_hit", {
          target,
          seed
        });
      }
      const parsed = JSON.parse(stored);
      return {
        title: parsed.title || title,
        summary: parsed.summary || summary
      };
    }
  }
  if (url) {
    const legacyDocId = makeTranslationDocId(url, target, "summary");
    const stored = await getCachedTranslation(legacyDocId);
    if (stored) {
      if (AI_CACHE_DEBUG) {
        console.log("[AICache] translate_fields legacy_hit", {
          target,
          seed: seed || "",
          url
        });
      }
      const parsed = JSON.parse(stored);
      return {
        title: parsed.title || title,
        summary: parsed.summary || summary
      };
    }
  }
  if (AI_CACHE_DEBUG) {
    console.log("[AICache] translate_fields miss", {
      target,
      seed: seed || "",
      url
    });
  }

  const languageName = resolveLanguageName(target);
  const prompt = [
    "You are a professional international news translator.",
    "Translate the title and summary into the target language in a formal news report style.",
    "Return a JSON object with exactly these keys: title, summary.",
    "Do not add extra text."
  ].join(" ");

  let response;
  try {
    response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_TRANSLATE_MODEL,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content:
              "You are a professional international news translator. Translate in a formal news report style."
          },
          {
            role: "user",
            content: `${prompt}\nTarget language: ${languageName}\nTitle: ${title}\nSummary: ${summary}`
          }
        ]
      },
      { label: "translate_fields", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`OpenAI translateFields timeout/error ${JSON.stringify(payload)}`);
    return { title, summary };
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    const keyTag = response.__keyTag || null;
    console.error(
      `OpenAI translateFields error ${response.status} (${keyTag || "unknown"}): ${errorBody.slice(0, 400)}`
    );
    return { title, summary };
  }
  const data = await response.json();
  const raw = data?.choices?.[0]?.message?.content?.trim();
  try {
    const parsed = JSON.parse(raw);
    const translated = {
      title: parsed.title || title,
      summary: parsed.summary || summary
    };
    if (seed) {
      const docId = makeTranslationDocIdFromSeed(seed, target, "summary");
      await setCachedTranslation(docId, JSON.stringify(translated));
    } else if (url) {
      const docId = makeTranslationDocId(url, target, "summary");
      await setCachedTranslation(docId, JSON.stringify(translated));
    }
    translationCache.set(cacheKey, translated);
    return translated;
  } catch {
    return { title, summary };
  }
}

function shouldTranslateSameLang(targetLang, title, summary) {
  const target = normalizeLangCode(targetLang || "en");
  const text = normalizeWhitespace(`${title || ""} ${summary || ""}`);
  if (!text) return false;
  const hangulCount = (text.match(/[가-힣]/g) || []).length;
  const kanaCount = (text.match(/[\u3040-\u30ff]/g) || []).length;
  const kanjiCount = (text.match(/[\u4e00-\u9fff]/g) || []).length;
  const cyrillicCount = (text.match(/[А-Яа-яЁё]/g) || []).length;
  const arabicCount = (text.match(/[\u0600-\u06ff]/g) || []).length;
  const latinCount = (text.match(/[A-Za-z]/g) || []).length;
  const minLatin = 6;
  const cjkCount = kanaCount + kanjiCount;
  const nonLatinCount = hangulCount + cjkCount + cyrillicCount + arabicCount;
  switch (target) {
    case "ko":
      return latinCount >= Math.max(minLatin, hangulCount * 2);
    case "ja":
      return latinCount >= Math.max(minLatin, cjkCount * 2);
    case "ru":
      return latinCount >= Math.max(minLatin, cyrillicCount * 2);
    case "ar":
      return latinCount >= Math.max(minLatin, arabicCount * 2);
    case "en":
    case "fr":
    case "es":
      if (nonLatinCount >= minLatin) return true;
      const detected = detectLatinLanguage(text);
      return Boolean(detected && detected !== target);
    default:
      return false;
  }
}

function shouldTranslateFields(lang, feedLang, title, summary) {
  const target = normalizeLangCode(lang || "en");
  const source = normalizeLangCode(feedLang || target);
  if (target !== source) return true;
  return shouldTranslateSameLang(target, title, summary);
}

function resolveTranslationPolicy(severity, breakingRequest) {
  const sev = Number.isFinite(severity) ? severity : 0;
  if (breakingRequest || sev >= 5) {
    return { allowTranslate: true, allowFallback: true, translateSummary: true };
  }
  if (sev >= 4) {
    return { allowTranslate: true, allowFallback: false, translateSummary: true };
  }
  return { allowTranslate: false, allowFallback: false, translateSummary: false };
}

function makeTranslationDocId(url, lang, kind) {
  const key = `v2::${kind}::${lang}::${url}`;
  return crypto.createHash("sha256").update(key).digest("hex");
}

function makeTranslationDocIdFromSeed(seed, lang, kind) {
  const key = `v3::${kind}::${lang}::${seed}`;
  return crypto.createHash("sha256").update(key).digest("hex");
}

function makeAppTranslationCacheKey(url, lang, mode, length) {
  const safeUrl = (url || "").toString().trim();
  const safeLang = (lang || "en").toString();
  const safeMode = (mode || "summary").toString();
  const safeLength = (length || "medium").toString();
  const raw = `v1|${safeUrl}|${safeLang}|${safeMode}|${safeLength}`;
  return crypto.createHash("sha1").update(raw, "utf8").digest("hex");
}

async function setAppTranslationCache({
  url,
  lang,
  mode,
  length,
  translatedContent,
  limited,
  link
}) {
  const safeUrl = (url || "").toString().trim();
  if (!safeUrl || !translatedContent) return;
  const db = getFirestore();
  if (!db) return;
  const docId = makeAppTranslationCacheKey(
    safeUrl,
    lang || "en",
    mode || "summary",
    length || "medium"
  );
  const nowMs = Date.now();
  await db.collection("translationCache").doc(docId).set(
    {
      translatedContent: translatedContent,
      limited: Boolean(limited),
      link: link || "",
      url: safeUrl,
      lang: lang || "",
      mode: mode || "",
      length: length || "",
      updatedAt: new Date(nowMs).toISOString(),
      expiresAt: cacheExpiresAt(nowMs)
    },
    { merge: true }
  );
}

function topicForKeyword(keyword, severity, lang, region) {
  const safe = keywordKey(keyword);
  const hash = crypto.createHash("sha1").update(safe).digest("hex");
  const safeLang = normalizeLangCode(lang || "en");
  const safeRegion = (region || "ALL").toUpperCase();
  return `kw${severity}_${safeLang}_${safeRegion}_${hash}`;
}

function criticalTopicForRegion(region, lang) {
  const safeRegion = (region || "ALL").toUpperCase();
  const safeLang = normalizeLangCode(lang || "en");
  return `${FCM_TOPIC_CRITICAL}_${safeLang}_${safeRegion}`;
}

function logPushDebug(label, payload = {}) {
  if (!PUSH_DEBUG) return;
  try {
    console.log(`[PushDebug] ${label} ${JSON.stringify(payload)}`);
  } catch (error) {
    console.log(`[PushDebug] ${label}`);
  }
}

function logPushSent(payload = {}) {
  try {
    console.log(`[PushSent] ${JSON.stringify(payload)}`);
  } catch (error) {
    console.log("[PushSent]");
  }
}

async function getCachedTranslation(docId) {
  const db = getFirestore();
  if (!db) return null;
  const doc = await db.collection("translations").doc(docId).get();
  if (!doc.exists) return null;
  return doc.data()?.text || null;
}

async function setCachedTranslation(docId, text) {
  const db = getFirestore();
  if (!db) return;
  const nowMs = Date.now();
  await db.collection("translations").doc(docId).set(
    {
      text,
      updatedAt: new Date(nowMs).toISOString(),
      expiresAt: cacheExpiresAt(nowMs)
    },
    { merge: true }
  );
}

function chunkText(text, chunkSize) {
  const chunks = [];
  let start = 0;
  while (start < text.length) {
    chunks.push(text.slice(start, start + chunkSize));
    start += chunkSize;
  }
  return chunks;
}

async function translateText(text, targetLang) {
  const target = (targetLang || "en").toLowerCase().split("-")[0];
  if (!HAS_ANY_OPENAI_KEY) {
    return text;
  }

  const cacheKey = `${target}::text::${text}`;
  const cached = translationCache.get(cacheKey);
  if (cached) return cached;

  const languageName = resolveLanguageName(target);
  let response;
  try {
    response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_SUMMARY_MODEL,
        temperature: 0,
        messages: [
          {
            role: "system",
            content:
              "You are a professional international news translator. Translate in a formal news report style."
          },
          {
            role: "user",
            content: `Translate the following text into ${languageName} in a formal news report style. Return only the translated text.\n\n${text}`
          }
        ]
      },
      { label: "translate_text", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`OpenAI translateText timeout/error ${JSON.stringify(payload)}`);
    return text;
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    const keyTag = response.__keyTag || null;
    const errorMessage = `OpenAI error ${response.status} (${keyTag || "unknown"}): ${errorBody.slice(0, 400)}`;
    console.error(errorMessage);
    return text;
  }
  const data = await response.json();
  const translated = data?.choices?.[0]?.message?.content?.trim() || text;
  translationCache.set(cacheKey, translated);
  return translated;
}

async function translateLongText(text, targetLang) {
  const normalized = normalizeWhitespace(text);
  if (!normalized) return "";
  const chunks = chunkText(normalized, 1800);
  const translatedChunks = [];
  for (const chunk of chunks) {
    // Translate sequentially to avoid rate spikes.
    // This keeps translation order stable.
    const translated = await translateText(chunk, targetLang);
    translatedChunks.push(translated);
  }
  return translatedChunks.join(" ").trim();
}

async function translateArticleContent(url, content, targetLang, cacheSeed) {
  const target = (targetLang || "en").toLowerCase().split("-")[0];
  if (!HAS_ANY_OPENAI_KEY) {
    return content;
  }

  const seed =
    cacheSeed || buildArticleCacheSeed({ url });
  if (seed) {
    const docId = makeTranslationDocIdFromSeed(seed, target, "content");
    const cached = await getCachedTranslation(docId);
    if (cached) return cached;
  }
  if (url) {
    const legacyDocId = makeTranslationDocId(url, target, "content");
    const cached = await getCachedTranslation(legacyDocId);
    if (cached) return cached;
  }

  try {
    const translated = await translateLongText(content, targetLang);
    if (seed) {
      const docId = makeTranslationDocIdFromSeed(seed, target, "content");
      await setCachedTranslation(docId, translated);
    } else if (url) {
      const docId = makeTranslationDocId(url, target, "content");
      await setCachedTranslation(docId, translated);
    }
    return translated;
  } catch (error) {
    console.error("Translate article content failed:", error.message || error);
    throw error;
  }
}

async function summarizeArticleContent(url, content, targetLang, length, cacheSeed) {
  const target = (targetLang || "en").toLowerCase().split("-")[0];
  const sentenceCount = summarySentenceCount(length);
  const fallback = summarizeText(content, sentenceCount);
  if (!HAS_ANY_OPENAI_KEY) {
    return fallback;
  }

  const seed =
    cacheSeed || buildArticleCacheSeed({ url });
  if (seed) {
    const docId = makeTranslationDocIdFromSeed(
      seed,
      target,
      `summary-${length || "medium"}`
    );
    const cached = await getCachedTranslation(docId);
    if (cached) return cached;
  }
  if (url) {
    const legacyDocId = makeTranslationDocId(
      url,
      target,
      `summary-${length || "medium"}`
    );
    const cached = await getCachedTranslation(legacyDocId);
    if (cached) return cached;
  }

  const languageName = resolveLanguageName(target);
  const normalized = normalizeWhitespace(content);
  const trimmed = normalized.slice(0, 6000);
  const prompt = [
    "You are a professional international news editor.",
    `Summarize the article into ${sentenceCount} sentences in ${languageName}.`,
    "Use formal news report style.",
    "Put each sentence on its own line.",
    "Return only the summary text."
  ].join(" ");

  let response;
  try {
    response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_SUMMARY_MODEL,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content:
              "You are a professional international news editor. Summarize in a formal news report style."
          },
          {
            role: "user",
            content: `${prompt}\n\n${trimmed}`
          }
        ]
      },
      { label: "summary", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`OpenAI summary timeout/error ${JSON.stringify(payload)}`);
    return fallback;
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    const keyTag = response.__keyTag || null;
    const errorMessage = `OpenAI summary error ${response.status} (${keyTag || "unknown"}): ${errorBody.slice(0, 400)}`;
    console.error(errorMessage);
    return fallback;
  }

  const data = await response.json();
  const summary = data?.choices?.[0]?.message?.content?.trim() || fallback;
  if (seed) {
    const docId = makeTranslationDocIdFromSeed(
      seed,
      target,
      `summary-${length || "medium"}`
    );
    await setCachedTranslation(docId, summary);
  } else if (url) {
    const docId = makeTranslationDocId(
      url,
      target,
      `summary-${length || "medium"}`
    );
    await setCachedTranslation(docId, summary);
  }
  return summary;
}

async function classifySeverity({ title, summary, url, cacheSeed }) {
  const merged = normalizeWhitespace(`${title || ""} ${summary || ""}`);
  if (!merged) return 3;

  const cacheKey = `sev::${cacheSeed || url || merged}`;
  const cached = severityCache.get(cacheKey);
  if (cached) {
    if (AI_CACHE_DEBUG) {
      console.log("[AICache] severity mem_hit", {
        cacheKey,
        seed: cacheSeed || "",
        hasUrl: Boolean(url)
      });
    }
    return cached;
  }

  const seed = cacheSeed || buildArticleCacheSeed({ url, title, summary });
  if (seed) {
    const docId = makeTranslationDocIdFromSeed(seed, "global", "severity");
    const stored = await getCachedSeverity(docId);
    if (stored) {
      if (AI_CACHE_DEBUG) {
        console.log("[AICache] severity store_hit", { seed });
      }
      const severity = clampSeverity(stored);
      severityCache.set(cacheKey, severity);
      return severity;
    }
  }
  if (url) {
    const legacyDocId = makeTranslationDocId(url, "global", "severity");
    const stored = await getCachedSeverity(legacyDocId);
    if (stored) {
      if (AI_CACHE_DEBUG) {
        console.log("[AICache] severity legacy_hit", { seed: seed || "", url });
      }
      const severity = clampSeverity(stored);
      severityCache.set(cacheKey, severity);
      return severity;
    }
  }

  if (!HAS_ANY_OPENAI_KEY) {
    const severity = fallbackSeverityScore(merged);
    severityCache.set(cacheKey, severity);
    return severity;
  }

  const prompt = [
    "Evaluate the severity on a scale of 1 to 5 based on global impact and urgency.",
    "5 (Critical): War declaration, head of state assassination, major earthquake/tsunami with mass casualties, pandemic declaration, global market crash, nuclear threat.",
    "4 (High): Major election results, major policy change, large accident, large corporation bankruptcy or merger, major interest rate change.",
    "3 (Moderate): Stock fluctuation, product launch, sports finals, major lawsuit, earnings report.",
    "2 (Low): Entertainment, regular sports, weather forecasts, local crime, minor incidents.",
    "1 (Minor): Gossip, rumors, tips, listicles.",
    "Return a JSON object with exactly one key: severity (integer 1-5)."
  ].join(" ");

  let response;
  try {
    if (AI_CACHE_DEBUG) {
      console.log("[AICache] severity miss", { seed: seed || "", url });
    }
    response = await fetchOpenAIWithRetries(
      {
        model: OPENAI_MODEL,
        temperature: 0,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: "You are a global news editor who assigns severity ratings."
          },
          {
            role: "user",
            content: `${prompt}\nTitle: ${title}\nSummary: ${summary}`
          }
        ]
      },
      { label: "severity", timeoutMs: TRANSLATE_TIMEOUT_MS }
    );
  } catch (error) {
    const cause = error?.cause;
    const payload = {
      message: error?.message || String(error),
      status: error?.status || null,
      code: error?.code || cause?.code || null,
      body: error?.body ? String(error.body).slice(0, 200) : null,
      cause: cause?.message || null,
      keyTag: error?.keyTag || null
    };
    console.error(`OpenAI severity timeout/error ${JSON.stringify(payload)}`);
    const fallback = fallbackSeverityScore(merged);
    severityCache.set(cacheKey, fallback);
    return fallback;
  }

  if (!response.ok) {
    const errorBody = await response.text().catch(() => "");
    const keyTag = response.__keyTag || null;
    console.error(
      `OpenAI severity error ${response.status} (${keyTag || "unknown"}): ${errorBody.slice(0, 400)}`
    );
    const fallback = fallbackSeverityScore(merged);
    severityCache.set(cacheKey, fallback);
    return fallback;
  }

  const data = await response.json();
  const raw = data?.choices?.[0]?.message?.content?.trim();
  let severity = fallbackSeverityScore(merged);
  try {
    const parsed = JSON.parse(raw);
    severity = clampSeverity(parsed.severity);
  } catch {
    severity = fallbackSeverityScore(merged);
  }

  if (url) {
    if (seed) {
      const docId = makeTranslationDocIdFromSeed(seed, "global", "severity");
      await setCachedSeverity(docId, severity);
    } else if (url) {
      const docId = makeTranslationDocId(url, "global", "severity");
      await setCachedSeverity(docId, severity);
    }
  }
  severityCache.set(cacheKey, severity);
  return severity;
}

function degradeSeverityByAge(item) {
  const publishedAt =
    typeof item.publishedAt === "string" ? Date.parse(item.publishedAt) : null;
  if (!publishedAt || Number.isNaN(publishedAt)) return item.severity;
  const ageMs = Date.now() - publishedAt;
  const twelveHours = 12 * 60 * 60 * 1000;
  if (ageMs > twelveHours && item.severity >= 4) {
    return 3;
  }
  return item.severity;
}

function shouldKeepPinnedItem(item, maxAgeHours = 12) {
  const severity = Number(item?.severity || 0);
  if (severity < 4) return false;
  const publishedAt =
    typeof item?.publishedAt === "string" ? Date.parse(item.publishedAt) : null;
  if (!publishedAt || Number.isNaN(publishedAt)) return false;
  const ageMs = Date.now() - publishedAt;
  return ageMs <= maxAgeHours * 60 * 60 * 1000;
}

function isRecentForPush(item, maxMinutes = PUSH_MAX_AGE_MINUTES) {
  const publishedAt =
    typeof item?.publishedAt === "string" ? Date.parse(item.publishedAt) : null;
  if (!publishedAt || Number.isNaN(publishedAt)) {
    return Boolean(item?.publishedAtFallbackOk);
  }
  const ageMs = Date.now() - publishedAt;
  return ageMs <= maxMinutes * 60 * 1000;
}

function normalizePublishedAt(item) {
  const raw = item?.isoDate || item?.pubDate || "";
  if (!raw) return "";
  const parsed = Date.parse(raw);
  if (!parsed || Number.isNaN(parsed)) return "";
  return new Date(parsed).toISOString();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function runWithTimeout(task, timeoutMs, label) {
  if (!timeoutMs) return task();
  let timeoutId;
  const timeoutPromise = new Promise((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${label || "task"}_timeout`));
    }, timeoutMs);
  });
  try {
    return await Promise.race([task(), timeoutPromise]);
  } finally {
    if (timeoutId) clearTimeout(timeoutId);
  }
}

async function withRetries(task, options = {}) {
  const retries = Number.isFinite(options.retries)
    ? options.retries
    : RETRY_ATTEMPTS;
  const timeoutMs = Number.isFinite(options.timeoutMs)
    ? options.timeoutMs
    : TASK_TIMEOUT_MS;
  const label = options.label || "task";
  const shouldRetry =
    typeof options.shouldRetry === "function" ? options.shouldRetry : null;
  let attempt = 0;
  while (true) {
    try {
      return await runWithTimeout(task, timeoutMs, label);
    } catch (error) {
      if (attempt >= retries) throw error;
      if (shouldRetry && !shouldRetry(error)) throw error;
      const backoff = Math.min(
        RETRY_MAX_DELAY_MS,
        RETRY_BASE_DELAY_MS * Math.pow(2, attempt)
      );
      const jitter = Math.floor(Math.random() * 200);
      await sleep(backoff + jitter);
      attempt += 1;
    }
  }
}

async function sendCriticalPushIfNeeded(item, options = {}) {
  const force = Boolean(options.force);
  const region = options.region || "ALL";
  const lang = normalizeLangCode(options.lang || "en");
  const severity = degradeSeverityByAge(item);
  if (!item || severity !== 5) return;
  const url = item.resolvedUrl || item.url;
  const articleId = item.articleId || makeArticleId(item);
  if (!isRecentForPush(item)) {
    logPushDebug("critical_skip_recent", {
      articleId,
      region,
      lang,
      publishedAt: item?.publishedAt || ""
    });
    return;
  }
  if (!url) {
    logPushDebug("critical_skip_url", { articleId, region, lang });
    return;
  }
  const dedupeSeed = `critical::${lang}::${region}::${articleId}`;
  const dedupeId = makeSentNotificationId(dedupeSeed);
  if (!force) {
    if (sentNotificationCache.get(dedupeId)) {
      logPushDebug("critical_skip_dedupe_mem", { articleId, region, lang });
      return;
    }
    const sent = await getSentNotification(dedupeId);
    if (sent?.sentAt) {
      sentNotificationCache.set(dedupeId, true);
      logPushDebug("critical_skip_dedupe_store", { articleId, region, lang });
      return;
    }
  }
  const docId = makeTranslationDocId(url, `${lang}_${region}`, "alert-critical");
  if (!force) {
    if (alertCache.get(docId)) {
      logPushDebug("critical_skip_alert_mem", { articleId, region, lang });
      return;
    }
    const stored = await getCachedAlert(docId);
    if (stored?.sentAt) {
      alertCache.set(docId, true);
      logPushDebug("critical_skip_alert_store", { articleId, region, lang });
      return;
    }
  }

  const messaging = getFirebaseMessaging();
  if (!messaging) {
    return;
  }

  const title = item.title || "Breaking News";
  const body = (item.summary || "").slice(0, 160);

  try {
    const messageId = await withRetries(
      () =>
        messaging.send({
          topic: criticalTopicForRegion(region, lang),
          notification: {
            title,
            body
          },
          data: {
            pushType: "breaking",
            severity: severity.toString(),
            url,
            title: item.title,
            summary: item.summary,
            source: item.source,
            publishedAt: item.publishedAt,
            lang
          }
        }),
      { label: "push_critical", timeoutMs: TASK_TIMEOUT_MS }
    );
    logPushSent({
      type: "critical",
      messageId,
      articleId,
      region,
      lang,
      severity
    });
  } catch (error) {
    console.error("[Push] critical failed", error?.message || error);
    return;
  }

  if (!force) {
    await setCachedAlert(docId, { url, title });
    alertCache.set(docId, true);
    await setSentNotification(dedupeId, {
      type: "critical",
      articleId,
      url,
      title,
      lang,
      region
    });
    sentNotificationCache.set(dedupeId, true);
  }
}

async function sendKeywordPushIfNeeded(
  item,
  canonicalKeyword,
  severity,
  lang,
  region,
  options = {}
) {
  const force = Boolean(options.force);
  const aliasKeywords = Array.isArray(options.aliasKeywords)
    ? options.aliasKeywords
    : [];
  if (!item || severity < 4) return;
  if (!canonicalKeyword) return;
  const articleId = item.articleId || makeArticleId(item);
  if (!isRecentForPush(item)) {
    logPushDebug("keyword_skip_recent", {
      articleId,
      region,
      lang,
      severity,
      publishedAt: item?.publishedAt || ""
    });
    return;
  }
  const url = item.resolvedUrl || item.url;
  if (!url) {
    logPushDebug("keyword_skip_url", { articleId, region, lang, severity });
    return;
  }
  const keywordKeyValue = keywordKey(canonicalKeyword);
  const dedupeSeed = `keyword::${keywordKeyValue}::${articleId}`;
  const dedupeId = makeSentNotificationId(dedupeSeed);
  if (!force) {
    if (sentNotificationCache.get(dedupeId)) {
      logPushDebug("keyword_skip_dedupe_mem", {
        articleId,
        region,
        lang,
        severity
      });
      return;
    }
    const sent = await getSentNotification(dedupeId);
    if (sent?.sentAt) {
      sentNotificationCache.set(dedupeId, true);
      logPushDebug("keyword_skip_dedupe_store", {
        articleId,
        region,
        lang,
        severity
      });
      return;
    }
  }

  const topic = topicForKeyword(canonicalKeyword, severity, lang, region);
  const docId = makeTranslationDocId(url, topic, "alert-keyword");
  if (!force) {
    if (alertCache.get(docId)) {
      logPushDebug("keyword_skip_alert_mem", {
        articleId,
        region,
        lang,
        severity
      });
      return;
    }
    const stored = await getCachedAlert(docId);
    if (stored?.sentAt) {
      alertCache.set(docId, true);
      logPushDebug("keyword_skip_alert_store", {
        articleId,
        region,
        lang,
        severity
      });
      return;
    }
  }

  const messaging = getFirebaseMessaging();
  if (!messaging) return;

  const baseTitle = item.title || "News update";
  const baseSummary = item.summary || "";
  const cacheSeed = buildArticleCacheSeed({
    resolvedUrl: item.resolvedUrl,
    url,
    source: item.source,
    title: baseTitle,
    summary: baseSummary,
    publishedAt: item.publishedAt
  });
  const translationPolicy = resolveTranslationPolicy(severity, false);
  let translated = { title: baseTitle, summary: baseSummary };
  if (
    translationPolicy.allowTranslate &&
    shouldTranslateSameLang(lang, baseTitle, baseSummary)
  ) {
    const summaryInput = translationPolicy.translateSummary ? baseSummary : "";
    try {
      translated = await withRetries(
        () =>
          translateFields(
            { title: baseTitle, summary: summaryInput, url, cacheSeed },
            lang
          ),
        { label: "push_translate", timeoutMs: TRANSLATE_TIMEOUT_MS }
      );
    } catch (error) {
      console.error("[Push] translate failed", error?.message || error);
      translated = { title: baseTitle, summary: baseSummary };
    }
    if (!translationPolicy.translateSummary) {
      translated.summary = baseSummary;
    }
    const titleSame =
      normalizeWhitespace(translated.title) === normalizeWhitespace(baseTitle);
    const summarySame =
      translationPolicy.translateSummary &&
      normalizeWhitespace(translated.summary) === normalizeWhitespace(baseSummary);
    const titleNeeds =
      shouldTranslateSameLang(lang, translated.title || "", "");
    const summaryNeeds =
      translationPolicy.translateSummary &&
      shouldTranslateSameLang(lang, "", translated.summary || "");
    if (
      translationPolicy.allowFallback &&
      (titleSame || summarySame || titleNeeds || summaryNeeds)
    ) {
      try {
        const fallbackTitle = (titleSame || titleNeeds) && baseTitle
          ? await withRetries(
              () => translateText(baseTitle, lang),
              { label: "push_translate_title", timeoutMs: TRANSLATE_TIMEOUT_MS }
            )
          : translated.title;
        const fallbackSummary =
          translationPolicy.translateSummary && (summarySame || summaryNeeds) && baseSummary
            ? await withRetries(
                () => translateText(baseSummary, lang),
                { label: "push_translate_summary", timeoutMs: TRANSLATE_TIMEOUT_MS }
              )
            : translated.summary;
        translated = {
          title: fallbackTitle || translated.title,
          summary: translationPolicy.translateSummary
            ? fallbackSummary || translated.summary
            : baseSummary
        };
      } catch (error) {
        console.error("[Push] translate fallback failed", error?.message || error);
      }
    }
  }
  const pushTitle = translated.title || baseTitle;
  const pushSummary = translated.summary || baseSummary;
  const body = (pushSummary || pushTitle || "").slice(0, 160);

  const aliasTopics = [];
  for (const alias of aliasKeywords) {
    const trimmed = normalizeWhitespace(alias || "");
    if (!trimmed) continue;
    if (keywordKey(trimmed) === keywordKeyValue) continue;
    const aliasTopic = topicForKeyword(trimmed, severity, lang, region);
    if (aliasTopic && aliasTopic !== topic) {
      aliasTopics.push(aliasTopic);
    }
  }
  let sendTarget = { topic };
  if (aliasTopics.length) {
    const unique = Array.from(new Set([topic, aliasTopics[0]]));
    if (unique.length > 1) {
      sendTarget = {
        condition: `'${unique[0]}' in topics || '${unique[1]}' in topics`
      };
    }
  }

  const messageId = await withRetries(
    () =>
      messaging.send({
        ...sendTarget,
        notification: {
          title: pushTitle,
          body
        },
        data: {
          pushType: "keyword",
          severity: severity.toString(),
          url,
          title: pushTitle,
          summary: pushSummary,
          source: item.source,
          canonicalKeyword,
          publishedAt: item.publishedAt,
          lang
        }
      }),
    { label: "push_keyword", timeoutMs: TASK_TIMEOUT_MS }
  );
  logPushSent({
    type: "keyword",
    messageId,
    articleId,
    keyword: canonicalKeyword,
    region,
    lang,
    severity,
    target: sendTarget.topic || sendTarget.condition || ""
  });

  if (!force) {
    await setCachedAlert(docId, { url, title: pushTitle });
    alertCache.set(docId, true);
    await setSentNotification(dedupeId, {
      type: "keyword",
      articleId,
      url,
      title,
      keywordKey: keywordKeyValue,
      canonicalKeyword,
      severity
    });
    sentNotificationCache.set(dedupeId, true);
  }
}

async function mapWithLimit(items, limit, mapper) {
  const results = [];
  let index = 0;

  async function worker() {
    while (index < items.length) {
      const current = index++;
      results[current] = await mapper(items[current]);
    }
  }

  const workers = Array.from({ length: limit }, () => worker());
  await Promise.all(workers);
  return results;
}

function dedupeByTitleSimilarity(items, threshold = 0.85){
  const uniqueItems = [];
  for (const item of items) {
    const currentTitle = normalizeWhitespace(item?.title || "");
    if (!currentTitle) {
      uniqueItems.push(item);
      continue;
    }
    const isDuplicate = uniqueItems.some((existing) => {
      const existingTitle = normalizeWhitespace(existing?.title || "");
      if (!existingTitle) return false;
      const similarity = stringSimilarity.compareTwoStrings(
        currentTitle,
        existingTitle
      );
      return similarity >= threshold;
    });
    if (!isDuplicate) uniqueItems.push(item);
  }
  return uniqueItems;
}

function dedupeByArticleId(items) {
  const seen = new Set();
  const output = [];
  for (const item of items) {
    const articleId = item?.articleId || makeArticleId(item || {});
    if (!articleId || seen.has(articleId)) continue;
    seen.add(articleId);
    output.push(item);
  }
  return output;
}

function dedupeByContentKey(items) {
  const seen = new Set();
  const output = [];
  for (const item of items) {
    const key = makeContentKey(item);
    if (key && seen.has(key)) continue;
    if (key) seen.add(key);
    output.push(item);
  }
  return output;
}

function buildCachedItemLookup(items = []) {
  const lookup = new Map();
  for (const item of items) {
    if (!item) continue;
    const keys = [];
    const urlKey = normalizeCacheUrl(item.url || "");
    const resolvedKey = normalizeCacheUrl(item.resolvedUrl || "");
    if (urlKey) keys.push(urlKey);
    if (resolvedKey) keys.push(resolvedKey);
    for (const key of keys) {
      const existing = lookup.get(key);
      if (!existing || existing.processing) {
        lookup.set(key, item);
      }
    }
  }
  return lookup;
}

app.get("/health", (req, res) => {
  res.json({ ok: true });
});

app.post("/keyword/subscription", async (req, res) => {
  try {
    const keyword = (req.body?.keyword || "").toString().trim();
    if (!keyword) {
      return res.status(400).json({ error: "keyword is required" });
    }
    const lang = (req.body?.lang || "").toString();
    const region = (req.body?.region || "").toString();
    const feedLang = (req.body?.feedLang || "").toString();
    const action = (req.body?.action || "add").toString().toLowerCase();
    const isRemove = action === "remove";
    const canonicalKeyword = await getCanonicalKeyword(keyword, lang, {
      allowModel: !isRemove
    });
    const delta = isRemove ? -1 : 1;
    const count = await updateKeywordSubscription(canonicalKeyword, delta, {
      region,
      lang,
      feedLang,
      alias: !isRemove ? keyword : ""
    });
    let onDemandQueued = false;
    let onDemandReason = "";
    let onDemandMode = "";
    let fastModeFallbackRan = false;
    let fastModeFallbackReason = "";
    if (!isRemove && canonicalKeyword) {
      const effectiveLang = normalizeLangCode(lang || "en");
      const effectiveFeedLang = normalizeLangCode(feedLang || lang || "en");
      const effectiveRegion = normalizeRegionCode(region || "ALL", "ALL");
      const onDemandTask = {
        keyword: canonicalKeyword,
        canonicalKeyword,
        lang: effectiveLang,
        feedLang: effectiveFeedLang,
        region: effectiveRegion,
        limit: 20
      };
      const cacheState = await getTaskCacheState(onDemandTask);
      const shouldQueueOnDemand =
        !cacheState.hasAnyCache || cacheState.onlyProcessing;
      if (shouldQueueOnDemand) {
        try {
          const crawlResult = await runCrawlTasks([onDemandTask], req);
          const queuedByTasks =
            crawlResult?.mode === "tasks" &&
            Number(crawlResult?.enqueued || 0) > 0;
          const completedInline =
            crawlResult?.mode === "inline" &&
            Number(crawlResult?.success || 0) > 0;
          if (queuedByTasks || completedInline) {
            onDemandQueued = true;
            onDemandMode = completedInline ? "inline" : "tasks";
            onDemandReason = cacheState.onlyProcessing
              ? "processing_recovery"
              : "cache_empty";
            await markSkipNextScheduledCrawl(onDemandTask, {
              reason: "keyword_subscription_on_demand"
            });
            console.log(
              `[KeywordSubscription] on-demand crawl ${onDemandMode} ${canonicalKeyword} ${effectiveRegion}/${effectiveLang} feed=${effectiveFeedLang}`
            );
          } else {
            onDemandReason =
              crawlResult?.error ||
              (crawlResult?.mode === "inline"
                ? "inline_failed"
                : "enqueue_failed");
            console.warn(
              `[KeywordSubscription] on-demand queue unavailable ${canonicalKeyword} ${effectiveRegion}/${effectiveLang}`,
              onDemandReason || "unknown"
            );
          }
        } catch (error) {
          onDemandReason = "enqueue_failed";
          console.error(
            "[KeywordSubscription] on-demand enqueue failed",
            canonicalKeyword,
            error?.message || error
          );
        }
      } else {
        onDemandReason = "cache_exists";
      }
      const refreshTimeoutMs = Math.max(60000, TASK_TIMEOUT_MS * 6);
      if (!cacheState.hasAnyCache && onDemandMode !== "inline") {
        try {
          const fastModeDecision = await canRunFastModeFallback(onDemandTask);
          fastModeFallbackReason = fastModeDecision.reason || "";
          if (fastModeDecision.ok) {
            const fastModePayload = await runWithTimeout(
              () =>
                refreshNewsCacheFromSource({
                  keyword: canonicalKeyword,
                  canonicalKeyword,
                  lang: effectiveLang,
                  feedLang: effectiveFeedLang,
                  region: effectiveRegion,
                  limit: 20,
                  skipPush: true,
                  fastMode: true
                }),
              refreshTimeoutMs,
              "keyword_refresh"
            );
            const hasFastItems =
              Array.isArray(fastModePayload?.items) &&
              fastModePayload.items.length > 0;
            if (hasFastItems) {
              fastModeFallbackRan = true;
              await markFastModeFallbackTriggered(onDemandTask, {
                reason: "keyword_subscription_cache_empty"
              });
            } else {
              fastModeFallbackReason = "empty_fastmode_result";
            }
          }
        } catch (error) {
          console.error(
            "[KeywordSubscription] refresh failed",
            canonicalKeyword,
            error?.message || error
          );
        }
      } else if (cacheState.hasAnyCache) {
        fastModeFallbackReason = "cache_exists";
      } else if (onDemandMode === "inline") {
        fastModeFallbackReason = "inline_on_demand";
      }
    }
    res.json({
      keyword,
      canonical: canonicalKeyword,
      count: count ?? null,
      onDemandQueued,
      onDemandReason,
      onDemandMode,
      fastModeFallbackRan,
      fastModeFallbackReason
    });
  } catch (error) {
    res.status(500).json({ error: "failed to update keyword subscription" });
  }
});

app.post("/keyword/set", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  try {
    const previousKeyword = (req.body?.previousKeyword || req.body?.previous || "")
      .toString()
      .trim();
    const nextKeyword = (req.body?.nextKeyword || req.body?.keyword || "")
      .toString()
      .trim();
    if (!previousKeyword && !nextKeyword) {
      return res.status(400).json({ error: "keyword is required" });
    }
    const lang = (req.body?.lang || "").toString();
    const region = (req.body?.region || "").toString();
    const feedLang = (req.body?.feedLang || "").toString();
    const tabIndex = req.body?.tabIndex;
    const result = await setKeywordSubscriptionForUser({
      uid: user.uid,
      previousKeyword,
      nextKeyword,
      lang,
      region,
      feedLang,
      tabIndex
    });
    if (!result) {
      return res.status(503).json({ error: "firestore_unavailable" });
    }
    const nextCanonical = normalizeWhitespace(result.nextCanonical || nextKeyword);
    const previousCanonical = normalizeWhitespace(
      result.previousCanonical || previousKeyword
    );
    const nextKey = nextCanonical ? keywordKey(nextCanonical) : "";
    const shouldEvaluateOnDemand = Boolean(nextKey);
    let onDemandQueued = false;
    let onDemandReason = "";
    let onDemandMode = "";
    let fastModeFallbackRan = false;
    let fastModeFallbackReason = "";
    if (shouldEvaluateOnDemand) {
      const effectiveLang = normalizeLangCode(result.nextLang || lang || "en");
      const effectiveFeedLang = normalizeLangCode(
        result.nextFeedLang || feedLang || lang || "en"
      );
      const effectiveRegion = normalizeRegionCode(
        result.nextRegion || region || "ALL",
        "ALL"
      );
      const onDemandTask = {
        keyword: nextCanonical,
        canonicalKeyword: nextCanonical,
        lang: effectiveLang,
        feedLang: effectiveFeedLang,
        region: effectiveRegion,
        limit: 20
      };
      const cacheState = await getTaskCacheState(onDemandTask);
      const shouldTriggerOnDemand =
        Boolean(result.nextConditionAdded) ||
        !cacheState.hasAnyCache ||
        cacheState.onlyProcessing;
      if (shouldTriggerOnDemand) {
        try {
          const crawlResult = await runCrawlTasks([onDemandTask], req);
          const queuedByTasks =
            crawlResult?.mode === "tasks" &&
            Number(crawlResult?.enqueued || 0) > 0;
          const completedInline =
            crawlResult?.mode === "inline" &&
            Number(crawlResult?.success || 0) > 0;
          if (queuedByTasks || completedInline) {
            onDemandQueued = true;
            onDemandMode = completedInline ? "inline" : "tasks";
            onDemandReason = cacheState.onlyProcessing
              ? "processing_recovery"
              : !cacheState.hasAnyCache
                ? "cache_empty"
                : "condition_added";
            await markSkipNextScheduledCrawl(onDemandTask, {
              reason: "keyword_set_on_demand"
            });
            console.log(
              `[KeywordSet] on-demand crawl ${onDemandMode} ${nextCanonical} ${effectiveRegion}/${effectiveLang} feed=${effectiveFeedLang}`
            );
          } else {
            onDemandReason =
              crawlResult?.error ||
              (crawlResult?.mode === "inline"
                ? "inline_failed"
                : "enqueue_failed");
            console.warn(
              `[KeywordSet] on-demand queue unavailable ${nextCanonical} ${effectiveRegion}/${effectiveLang}`,
              onDemandReason || "unknown"
            );
          }
        } catch (error) {
          onDemandReason = "enqueue_failed";
          console.error(
            "[KeywordSet] on-demand enqueue failed",
            nextCanonical,
            error?.message || error
          );
        }
      } else {
        onDemandReason = "cache_exists";
      }

      const refreshTimeoutMs = Math.max(60000, TASK_TIMEOUT_MS * 6);
      if (!cacheState.hasAnyCache && onDemandMode !== "inline") {
        try {
          const fastModeDecision = await canRunFastModeFallback(onDemandTask);
          fastModeFallbackReason = fastModeDecision.reason || "";
          if (fastModeDecision.ok) {
            const fastModePayload = await runWithTimeout(
              () =>
                refreshNewsCacheFromSource({
                  keyword: nextCanonical,
                  canonicalKeyword: nextCanonical,
                  lang: effectiveLang,
                  feedLang: effectiveFeedLang,
                  region: effectiveRegion,
                  limit: 20,
                  skipPush: true,
                  fastMode: true
                }),
              refreshTimeoutMs,
              "keyword_fastmode_fallback"
            );
            const hasFastItems =
              Array.isArray(fastModePayload?.items) &&
              fastModePayload.items.length > 0;
            if (hasFastItems) {
              fastModeFallbackRan = true;
              await markFastModeFallbackTriggered(onDemandTask, {
                reason: "keyword_set_cache_empty"
              });
              console.log(
                `[KeywordSet] fastMode fallback ran ${nextCanonical} ${effectiveRegion}/${effectiveLang} feed=${effectiveFeedLang}`
              );
            } else {
              fastModeFallbackReason = "empty_fastmode_result";
            }
          }
        } catch (error) {
          console.error(
            "[KeywordSet] fastMode fallback failed",
            nextCanonical,
            error?.message || error
          );
        }
      } else if (cacheState.hasAnyCache) {
        fastModeFallbackReason = "cache_exists";
      } else if (onDemandMode === "inline") {
        fastModeFallbackReason = "inline_on_demand";
      }
    }
    res.json({
      ok: true,
      previous: previousKeyword,
      keyword: nextKeyword,
      canonical: nextCanonical || "",
      previousCanonical: previousCanonical || "",
      count: result.nextCount ?? null,
      onDemandQueued,
      onDemandReason,
      onDemandMode,
      fastModeFallbackRan,
      fastModeFallbackReason
    });
  } catch (error) {
    console.error("[KeywordSet] failed", error?.message || error);
    res.status(500).json({ error: "failed to set keyword subscription" });
  }
});

app.post("/keyword/resolve", async (req, res) => {
  try {
    const keyword = (req.body?.keyword || "").toString().trim();
    if (!keyword) {
      return res.status(400).json({ error: "keyword is required" });
    }
    const lang = (req.body?.lang || "").toString();
    const canonicalKeyword = await getCanonicalKeyword(keyword, lang, {
      allowModel: true
    });
    res.json({
      keyword,
      canonical: canonicalKeyword
    });
  } catch (error) {
    res.status(500).json({ error: "failed to resolve keyword" });
  }
});

app.post("/cache/prefetch", async (req, res) => {
  try {
    const rawTasks = Array.isArray(req.body?.tasks) ? req.body.tasks : [];
    if (!rawTasks.length) {
      return res.json({ ok: true, total: 0, success: 0 });
    }
    const reason = (req.body?.reason || "").toString().trim();
    const tasks = [];
    const seen = new Set();
    for (const raw of rawTasks.slice(0, PREFETCH_MAX_TASKS)) {
      const keyword = (raw?.keyword || "").toString().trim();
      if (!keyword) continue;
      const region = normalizeRegionCode(raw?.region, "ALL");
      const lang = normalizeLangCode(raw?.lang || "en");
      const feedLang = normalizeLangCode(raw?.feedLang || lang);
      const limit = Math.min(
        20,
        Math.max(1, parseInt(raw?.limit || "20", 10) || 20)
      );
      const key = `${keywordKey(keyword)}::${region}::${feedLang}::${lang}::${limit}`;
      if (seen.has(key)) continue;
      seen.add(key);
      tasks.push({ keyword, region, lang, feedLang, limit });
    }
    if (!tasks.length) {
      return res.json({ ok: true, total: 0, success: 0 });
    }
    const refreshTimeoutMs = Math.max(60000, TASK_TIMEOUT_MS * 6);
    const results = await mapWithLimit(
      tasks,
      PREFETCH_CONCURRENCY,
      async (task) => {
        try {
          const canonical = normalizeWhitespace(
            (await getCanonicalKeyword(task.keyword, task.lang, {
              allowModel: false
            })) || task.keyword
          );
          const breakingRequest =
            isBreakingKeyword(task.keyword) || isBreakingKeyword(canonical);
          const canonicalKeyword = breakingRequest ? BREAKING_KEYWORD : canonical;
          if (!breakingRequest) {
            try {
              await updateKeywordSubscription(canonicalKeyword, 0, {
                region: task.region,
                lang: task.lang,
                feedLang: task.feedLang,
                alias: task.keyword
              });
            } catch (error) {
              console.error(
                "[Prefetch] subscription update failed",
                canonicalKeyword,
                error?.message || error
              );
            }
          }
          await runWithTimeout(
            () =>
              refreshNewsCacheFromSource({
                keyword: canonicalKeyword,
                canonicalKeyword,
                lang: task.lang,
                feedLang: task.feedLang,
                region: task.region,
                limit: task.limit,
                skipPush: true,
                fastMode: true
              }),
            refreshTimeoutMs,
            "prefetch"
          );
          return { ok: true };
        } catch (error) {
          console.error(
            "[Prefetch] failed",
            task.keyword,
            `${task.region}/${task.lang}`,
            error?.message || error
          );
          return { ok: false };
        }
      }
    );
    const success = results.filter((entry) => entry && entry.ok).length;
    const payload = { ok: true, total: tasks.length, success };
    if (reason) {
      payload.reason = reason;
    }
    res.json(payload);
  } catch (error) {
    console.error("[Prefetch] failed", error?.message || error);
    res.status(500).json({ ok: false, error: "prefetch_failed" });
  }
});

app.post("/breaking/activate", async (req, res) => {
  try {
    const region = normalizeRegionCode(req.body?.region || "ALL", "ALL");
    const lang = normalizeLangCode(req.body?.lang || "en");
    const feedLang = normalizeLangCode(
      req.body?.feedLang || REGION_FEED_LANG[region] || lang
    );
    const limit = Math.min(
      20,
      Math.max(1, parseInt(req.body?.limit || "20", 10) || 20)
    );
    const task = {
      keyword: BREAKING_KEYWORD,
      canonicalKeyword: BREAKING_KEYWORD,
      region,
      lang,
      feedLang,
      limit
    };
    const cacheState = await getTaskCacheState(task);
    const shouldQueueOnDemand =
      !cacheState.exists || cacheState.onlyProcessing;
    let onDemandQueued = false;
    let onDemandMode = "";
    let onDemandReason = shouldQueueOnDemand ? "cache_empty" : "cache_exists";
    let processingRecoveryQueued = false;
    if (shouldQueueOnDemand) {
      try {
        const crawlResult = await runCrawlTasks([task], req);
        const queuedByTasks =
          crawlResult?.mode === "tasks" &&
          Number(crawlResult?.enqueued || 0) > 0;
        const completedInline =
          crawlResult?.mode === "inline" &&
          Number(crawlResult?.success || 0) > 0;
        if (queuedByTasks || completedInline) {
          onDemandQueued = true;
          onDemandMode = completedInline ? "inline" : "tasks";
          if (cacheState.onlyProcessing) {
            onDemandReason = "processing_recovery";
            processingRecoveryQueued = true;
            if (cacheState.identity?.key) {
              markProcessingRecoveryQueued(cacheState.identity.key);
            }
          }
          await markSkipNextScheduledCrawl(task, {
            reason: `breaking_activate_${onDemandReason}`
          });
        } else {
          onDemandReason =
            crawlResult?.error ||
            (crawlResult?.mode === "inline"
              ? "inline_failed"
              : "enqueue_failed");
        }
      } catch (error) {
        onDemandReason = "enqueue_failed";
        console.error(
          "[BreakingActivate] enqueue failed",
          error?.message || error
        );
      }
    }

    let fastModeFallbackRan = false;
    let fastModeFallbackReason = "";
    if (!cacheState.exists && onDemandMode !== "inline") {
      const refreshTimeoutMs = Math.max(60000, TASK_TIMEOUT_MS * 6);
      try {
        const fastModeDecision = await canRunFastModeFallback(task);
        fastModeFallbackReason = fastModeDecision.reason || "";
        if (fastModeDecision.ok) {
          const fastModePayload = await runWithTimeout(
            () =>
              refreshNewsCacheFromSource({
                keyword: BREAKING_KEYWORD,
                canonicalKeyword: BREAKING_KEYWORD,
                lang,
                feedLang,
                region,
                limit,
                skipPush: true,
                fastMode: true
              }),
            refreshTimeoutMs,
            "breaking_fastmode_activate"
          );
          const hasFastItems =
            Array.isArray(fastModePayload?.items) &&
            fastModePayload.items.length > 0;
          if (hasFastItems) {
            fastModeFallbackRan = true;
            await markFastModeFallbackTriggered(task, {
              reason: "breaking_activate_cache_empty"
            });
          } else {
            fastModeFallbackReason = "empty_fastmode_result";
          }
        }
      } catch (error) {
        console.error(
          "[BreakingActivate] fastMode fallback failed",
          error?.message || error
        );
      }
    } else if (cacheState.exists) {
      fastModeFallbackReason = "cache_exists";
    } else if (onDemandMode === "inline") {
      fastModeFallbackReason = "inline_on_demand";
    }

    return res.json({
      ok: true,
      keyword: BREAKING_KEYWORD,
      region,
      lang,
      feedLang,
      hasCache: cacheState.exists,
      hasAnyCache: cacheState.hasAnyCache,
      cacheAgeMs: cacheState.cacheAgeMs,
      cacheOnlyProcessing: cacheState.onlyProcessing,
      cacheProcessingAgeMs: cacheState.processingAgeMs,
      onDemandQueued,
      onDemandMode,
      onDemandReason,
      processingRecoveryQueued,
      fastModeFallbackRan,
      fastModeFallbackReason
    });
  } catch (error) {
    console.error("[BreakingActivate] failed", error?.message || error);
    return res.status(500).json({
      ok: false,
      error: "breaking_activate_failed"
    });
  }
});

app.get("/saved_articles", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const limit = Math.min(parseInt(req.query.limit || "200", 10), 500);
    const ref = db
      .collection("users")
      .doc(user.uid)
      .collection("saved_articles")
      .orderBy("savedAt", "desc")
      .limit(limit);
    const snap = await ref.get();
    const items = snap.docs.map((doc) => ({
      id: doc.id,
      ...doc.data()
    }));
    res.json({ ok: true, items });
  } catch (error) {
    res.status(500).json({ ok: false, error: "saved_articles_failed" });
  }
});

app.post("/saved_articles/set", async (req, res) => {
  const user = await getVerifiedUser(req, res);
  if (!user) return;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(503).json({ ok: false, error: "firestore_unavailable" });
    }
    const action = (req.body?.action || "").toString().toLowerCase();
    const saved = req.body?.saved;
    const shouldSave =
      action !== "remove" &&
      action !== "delete" &&
      action !== "unsave" &&
      saved !== false;

    const article = req.body?.item || req.body?.article || {};
    const payload = {
      title: (article.title || "").toString(),
      summary: (article.summary || "").toString(),
      source: (article.source || "").toString(),
      publishedAt: (article.publishedAt || "").toString(),
      url: (article.url || "").toString(),
      resolvedUrl: (article.resolvedUrl || "").toString(),
      sourceUrl: (article.sourceUrl || "").toString(),
      severity: Number(article.severity || 0) || 0
    };
    if (
      shouldSave &&
      !payload.title &&
      !payload.summary &&
      !payload.url &&
      !payload.resolvedUrl
    ) {
      return res.status(400).json({ ok: false, error: "invalid_article" });
    }

    const keywordRaw =
      (req.body?.keywordKey || article.keywordKey || req.body?.keyword || "")
        .toString()
        .trim();
    const keywordKeyValue = keywordRaw ? keywordKey(keywordRaw) : "";
    const articleId =
      (req.body?.articleId || "").toString().trim() ||
      makeSavedArticleId(payload);
    const ref = db
      .collection("users")
      .doc(user.uid)
      .collection("saved_articles")
      .doc(articleId);

    if (!shouldSave) {
      await ref.delete();
      return res.json({ ok: true, action: "remove", articleId });
    }

    const savedAt = new Date().toISOString();
    await ref.set(
      {
        ...payload,
        keywordKey: keywordKeyValue,
        savedAt
      },
      { merge: true }
    );
    res.json({ ok: true, action: "save", articleId, savedAt });
  } catch (error) {
    res.status(500).json({ ok: false, error: "saved_articles_failed" });
  }
});

async function refreshNewsCacheFromSource(options = {}) {
  const keyword = (options.keyword || "").toString();
  const lang = normalizeLangCode(options.lang || "en");
  const feedLang = normalizeLangCode(options.feedLang || lang);
  const region = normalizeRegionCode(options.region || "US", "US");
  const limit = Math.min(parseInt(options.limit || "10", 10), 20);
  const skipPush = options.skipPush === true;
  const fastMode = options.fastMode === true;
  const aliasKeywords = Array.isArray(options.aliases)
    ? options.aliases
    : [];
  const canonicalKeyword =
    normalizeWhitespace(
      options.canonicalKeyword ||
        (await getCanonicalKeyword(keyword, lang)) ||
        keyword
    ) || keyword;
  const cacheId = makeNewsCacheId(
    canonicalKeyword,
    region,
    feedLang,
    lang,
    limit
  );
  const cacheKey = `${canonicalKeyword}::${lang}::${feedLang}::${region}::${limit}`;
  const skipIfFresh = options.skipIfFresh !== false && options.forceRefresh !== true;
  const cachedMeta = skipIfFresh || fastMode ? await getCachedNewsMeta(cacheId) : null;
  const cachedItems = cachedMeta && Array.isArray(cachedMeta.data?.items)
    ? cachedMeta.data.items
    : [];
  const nowMs = Date.now();
  const nowIso = new Date(nowMs).toISOString();
  const cachedProcessingDurationMs = parsePositiveMs(
    cachedMeta?.data?.processingDurationMs
  );
  const resolveProcessingStartedAt = (cachedHit) => {
    if (cachedHit?.processing) {
      const cachedStartedAt = parseDateIso(cachedHit.processingStartedAt);
      if (cachedStartedAt) return cachedStartedAt;
    }
    return nowIso;
  };
  const cachedItemLookup = buildCachedItemLookup(cachedItems);
  const cachedHasProcessing = cachedItems.some((item) => item?.processing);
  const cachedHasProcessed = cachedItems.some((item) => !item?.processing);
  if (fastMode && cachedHasProcessed) {
    const payload = {
      keyword: cachedMeta?.data?.keyword || keyword,
      canonical: cachedMeta?.data?.canonical || canonicalKeyword,
      lang: cachedMeta?.data?.lang || lang,
      items: cachedItems,
      processingDurationMs: cachedProcessingDurationMs,
      processingEtaMinutes: estimateProcessingEtaMinutes(
        cachedProcessingDurationMs
      )
    };
    newsCache.set(cacheKey, payload);
    return payload;
  }
  if (skipIfFresh && cachedMeta) {
    if (
      cachedMeta.ageMs < NEWS_CACHE_REFRESH_INTERVAL_MS &&
      cachedItems.length &&
      (fastMode || !cachedHasProcessing)
    ) {
      const payload = {
        keyword: cachedMeta.data.keyword || keyword,
        canonical: cachedMeta.data.canonical || canonicalKeyword,
        lang: cachedMeta.data.lang || lang,
        items: cachedItems,
        processingDurationMs: cachedProcessingDurationMs,
        processingEtaMinutes: estimateProcessingEtaMinutes(
          cachedProcessingDurationMs
        )
      };
      newsCache.set(cacheKey, payload);
      return payload;
    }
  }

  const breakingRequest = isBreakingKeyword(keyword);
  const crawlSources = getEffectiveCrawlSources(
    await getCrawlSourcesConfig()
  );
  const googleNewsEnabled = crawlSources.googleNews;
  const isJapanRegion = region.toUpperCase() === "JP";
  const searchKeyword = await resolveSearchKeyword(
    keyword,
    canonicalKeyword,
    feedLang
  );
  const searchKeywordEn = isJapanRegion
    ? await resolveSearchKeyword(keyword, canonicalKeyword, "en")
    : "";
  let maxAgeMs = breakingRequest
    ? 6 * 60 * 60 * 1000
    : 24 * 60 * 60 * 1000;
  let feedUrl = "";
  let feed = { items: [] };
  let feedError = null;
  let feedLabelUsed = "";
  const feedCandidates = [];
  if (googleNewsEnabled) {
    if (breakingRequest) {
      feedCandidates.push({
        url: buildGoogleTopStoriesUrl(feedLang, region),
        label: "breaking_primary"
      });
      feedCandidates.push({
        url: buildGoogleNewsUrl(searchKeyword, feedLang, region),
        label: "breaking_search"
      });
      if ((region || "ALL").toUpperCase() !== "ALL") {
        feedCandidates.push({
          url: buildGoogleTopStoriesUrl(feedLang, "ALL"),
          label: "breaking_all_top"
        });
        feedCandidates.push({
          url: buildGoogleNewsUrl(searchKeyword, feedLang, "ALL"),
          label: "breaking_all_search"
        });
      }
      feedCandidates.push({
        url: buildGoogleTopStoriesUrl("en", "ALL"),
        label: "breaking_global"
      });
    } else {
      feedCandidates.push({
        url: buildGoogleNewsUrl(searchKeyword, feedLang, region),
        label: "search"
      });
    }
  }

  let fallbacksUsed = 0;
  let skipGoogleFallbacks = false;
  for (let index = 0; index < feedCandidates.length; index += 1) {
    const candidate = feedCandidates[index];
    if (index > 0) {
      if (skipGoogleFallbacks) break;
      if (fallbacksUsed >= GOOGLE_NEWS_MAX_FALLBACKS) break;
      fallbacksUsed += 1;
    }
    feedUrl = candidate.url;
    try {
      feed = await withRetries(
        () =>
          fetchRssFeed(feedUrl, {
            timeoutMs: TASK_TIMEOUT_MS,
            lang: feedLang,
            region
          }),
        {
          label: candidate.label || "rss_fetch",
          timeoutMs: TASK_TIMEOUT_MS,
          shouldRetry: isRetryableRssError
        }
      );
      feedError = null;
    } catch (error) {
      feedError = error;
      feed = { items: [] };
      console.error(
        `[Feed] ${candidate.label || "fetch"} failed`,
        feedUrl,
        error?.message || error
      );
      if (isRssRateLimitedError(error) || isRssSkipError(error)) {
        skipGoogleFallbacks = true;
      }
    }
    const rssItems = Array.isArray(feed?.items) ? feed.items : [];
    if (rssItems.length) {
      feedLabelUsed = candidate.label || "";
      break;
    }
    if (feedError && skipGoogleFallbacks) break;
  }
  const primaryRssItems = Array.isArray(feed?.items) ? feed.items : [];
  let extraRssItems = [];
  if (googleNewsEnabled && isJapanRegion && searchKeywordEn && !skipGoogleFallbacks) {
    const extraUrls = [
      {
        url: buildGoogleNewsUrl(searchKeywordEn, "en", region),
        label: breakingRequest ? "breaking_search_en" : "search_en"
      },
      {
        url: buildGoogleNewsUrl(searchKeywordEn, "en", "ALL"),
        label: breakingRequest ? "breaking_search_en_all" : "search_en_all"
      }
    ];
    for (const extra of extraUrls) {
      const extraUrl = extra.url;
      if (!extraUrl || extraUrl === feedUrl) continue;
      try {
        const enFeed = await withRetries(
          () =>
            fetchRssFeed(extraUrl, {
              timeoutMs: TASK_TIMEOUT_MS,
              lang: "en",
              region: extraUrl.includes("ceid=") ? region : "ALL"
            }),
          {
            label: extra.label,
            timeoutMs: TASK_TIMEOUT_MS,
            shouldRetry: isRetryableRssError
          }
        );
        const enItems = Array.isArray(enFeed?.items) ? enFeed.items : [];
        if (enItems.length) {
          extraRssItems = extraRssItems.concat(enItems);
        }
      } catch (error) {
        console.error(
          `[Feed] ${extra.label} failed`,
          extraUrl,
          error?.message || error
        );
      }
    }
  }
  const rssItems = primaryRssItems.concat(extraRssItems);
  let extraItems = [];
  try {
    extraItems = await fetchExtraNewsItems({
      keyword,
      searchKeyword,
      feedLang,
      region,
      limit,
      breakingRequest,
      fastMode,
      sources: crawlSources
    });
  } catch (error) {
    console.error("[ExtraSource] fetch failed", error?.message || error);
  }
  if (breakingRequest && rssItems.length === 0) {
    // When breaking feeds fail, allow fallback sources to use a wider window.
    maxAgeMs = 24 * 60 * 60 * 1000;
  }
  await loadDynamicRegionAllowlist(region);
  const shouldRecordDynamic =
    breakingRequest &&
    (feedLabelUsed === "breaking_primary" ||
      feedLabelUsed === "breaking_all_top");
  const rssUrlKeys = shouldRecordDynamic
    ? new Set(
        primaryRssItems
          .map((item) => normalizeCacheUrl(upgradeToHttps(item.link)))
          .filter(Boolean)
      )
    : null;
  const baseRawItems = dedupeByTitleSimilarity(rssItems.concat(extraItems));
  const dynamicGoogleDomains = shouldRecordDynamic ? new Set() : null;
  const recordDynamicHost = (host, urlKey) => {
    if (!shouldRecordDynamic || !dynamicGoogleDomains) return;
    if (rssUrlKeys && (!urlKey || !rssUrlKeys.has(urlKey))) return;
    if (!host) return;
    if (isGoogleHost(host) || host.endsWith("google.com")) return;
    const domain = normalizeDomainForAllowlist(host);
    if (domain && !domain.endsWith("google.com")) {
      dynamicGoogleDomains.add(domain);
    }
  };

  const seenUrlKeys = new Set();
  const buildResults = async (rawItems, enforceRegion) =>
    mapWithLimit(rawItems, ITEM_PROCESS_CONCURRENCY, async (item) => {
      try {
        const url = upgradeToHttps(item.link);
        const urlKey = normalizeCacheUrl(url);
        let cachedHit = null;
        if (urlKey) {
          if (seenUrlKeys.has(urlKey)) {
            return null;
          }
          seenUrlKeys.add(urlKey);
          cachedHit = cachedItemLookup.get(urlKey);
          if (cachedHit && !cachedHit.processing) {
            const cachedHost = hostFromUrl(
              cachedHit.resolvedUrl || cachedHit.url || ""
            );
            recordDynamicHost(cachedHost, urlKey);
            return cachedHit;
          }
        }
        let title = normalizeWhitespace(item.title || "");
        let summary = "";
        let content = "";
        const rssExternalUrl = extractExternalUrlFromRssItem(item);
        const hasRssExternalUrl = Boolean(rssExternalUrl);
        let resolvedUrl = hasRssExternalUrl ? rssExternalUrl : url;
        const publishedAt = normalizePublishedAt(item);
        let sourceUrl = upgradeToHttps(deriveSourceUrl(item));
        let source = normalizeWhitespace(item.source?.title || item.creator || "");
        const sourceLower = normalizeSourceKey(source);
        const urlHost = hostFromUrl(url);
        let sourceHost = hostFromUrl(sourceUrl);
        const needsSourceResolution =
          !hasRssExternalUrl &&
          !source ||
          sourceLower === "google news" ||
          isGoogleNewsArticleUrl(url) ||
          isGoogleHost(urlHost) ||
          isGoogleHost(sourceHost);
        if (!fastMode && needsSourceResolution) {
          try {
            resolvedUrl = await withRetries(
              () => resolveArticleUrl(url, RESOLVE_TIMEOUT_MS),
              { label: "resolve_url", timeoutMs: RESOLVE_TIMEOUT_MS }
            );
          } catch (error) {
            console.error("[SourceResolve] failed", url, error?.message || error);
          }
        }

        if (rssExternalUrl && isGoogleHost(hostFromUrl(resolvedUrl || ""))) {
          resolvedUrl = rssExternalUrl;
        }
        const resolvedHost = hostFromUrl(resolvedUrl);
        if (
          (!sourceUrl || isGoogleHost(sourceHost)) &&
          resolvedHost &&
          !isGoogleHost(resolvedHost)
        ) {
          sourceUrl = resolvedUrl;
          sourceHost = resolvedHost;
        }
        recordDynamicHost(resolvedHost || sourceHost || urlHost, urlKey);
        const fromTitle = deriveSourceNameFromTitle(title);
        const resolvedLabel =
          resolvedHost && !isGoogleHost(resolvedHost)
            ? formatSourceLabel(resolvedHost)
            : "";
        const sourceUrlLabel =
          sourceHost && !isGoogleHost(sourceHost)
            ? formatSourceLabel(sourceHost)
            : "";
        if (
          !source ||
          sourceLower === "google news" ||
          isGoogleHost(sourceHost) ||
          isGoogleHost(urlHost)
        ) {
          const titleLabel =
            fromTitle && normalizeSourceKey(fromTitle) !== "google news"
              ? fromTitle
              : "";
          source = resolvedLabel || sourceUrlLabel || titleLabel || source;
        }
        if (!source || normalizeSourceKey(source) === "google news") {
          const fallbackHost = resolvedHost || sourceHost || urlHost;
          if (fallbackHost && !isGoogleHost(fallbackHost)) {
            source = formatSourceLabel(fallbackHost);
          }
        }
        if (!source) {
          source = "Unknown Source";
        }

      summary = normalizeWhitespace(item.contentSnippet || item.content || "");
      if (summary) {
        summary = summarizeText(summary, 2);
      }

      const cacheSeed = buildArticleCacheSeed({
        resolvedUrl,
        url,
        source,
        title,
        summary,
        publishedAt
      });

      if (!fastMode && publishedAt) {
        const publishedMs = Date.parse(publishedAt);
        if (!Number.isNaN(publishedMs)) {
          const ageMs = Date.now() - publishedMs;
          if (ageMs > maxAgeMs) {
            return null;
          }
        }
      }

      if (!fastMode && !breakingRequest) {
        const preSeverity = fallbackSeverityScore(`${title} ${summary}`);
        const relevanceScore = keywordRelevanceScore(keyword, title, summary);
        if (preSeverity <= 2 && relevanceScore < 18) {
          if (process.env.PRESEV_DEBUG === "1") {
            console.log("[PreSev] drop", {
              dropReason: ["LOW_SEV_12"],
              keyword,
              preSeverity,
              relevanceScore,
              title
            });
          }
          return null;
        }
      }

        let severity;
        if (fastMode) {
          severity = 3;
        } else {
          try {
            severity = await withRetries(
              () => classifySeverity({ title, summary, url, cacheSeed }),
              { label: "severity", timeoutMs: TASK_TIMEOUT_MS }
            );
          } catch (error) {
            console.error("[Severity] failed", error?.message || error);
            severity = fallbackSeverityScore(`${title} ${summary}`);
          }
        }
      if (!fastMode && !breakingRequest && severity === 1) {
        return null;
      }

        const shouldEnforceRegion = enforceRegion;
        if (shouldEnforceRegion) {
          if (
            !isSourceAllowedForRegion(region, {
              sourceName: source,
              sourceUrl,
              resolvedUrl,
              sourceRegion: item?.sourceRegion || item?.gdeltRegion || ""
            })
          ) {
            console.log(
              `[Filtered] Region ${region} Source: ${source || "unknown"}`
            );
            return null;
          }
        }

        if (!fastMode && !breakingRequest && severity < 4) {
          const trustedSource = await isTrustedSource({
            sourceName: source,
            sourceUrl,
            resolvedUrl
          });
          if (!trustedSource) {
            console.log(`[Filtered] Low Quality Source: ${source || "unknown"}`);
            return null;
          }
        }

        const displaySummary = summary;
        let translated = { title, summary: displaySummary };
        const translationPolicy = resolveTranslationPolicy(
          severity,
          breakingRequest
        );
        const shouldTranslate =
          severity >= 4 &&
          translationPolicy.allowTranslate &&
          shouldTranslateFields(lang, feedLang, title, displaySummary);
        if (shouldTranslate) {
          const summaryInput = displaySummary;
          try {
            translated = await withRetries(
              () =>
                translateFields(
                  { title, summary: summaryInput, url, cacheSeed },
                  lang
                ),
              { label: "translate", timeoutMs: TRANSLATE_TIMEOUT_MS }
            );
          } catch (error) {
            console.error("[Translate] failed", error?.message || error);
            translated = { title, summary: displaySummary };
          }
          if (!translated.summary) {
            translated.summary = displaySummary;
          }
          const titleSame =
            normalizeWhitespace(translated.title) === normalizeWhitespace(title);
          const summarySame =
            normalizeWhitespace(translated.summary) ===
              normalizeWhitespace(displaySummary);
          const titleNeeds =
            shouldTranslateSameLang(lang, translated.title || "", "");
          const summaryNeeds =
            shouldTranslateSameLang(lang, "", translated.summary || "");
          if (
            translationPolicy.allowFallback &&
            (titleSame || titleNeeds || summarySame || summaryNeeds)
          ) {
            try {
              const fallbackTitle = (titleSame || titleNeeds) && title
                ? await withRetries(
                    () => translateText(title, lang),
                    { label: "translate_title_fallback", timeoutMs: TRANSLATE_TIMEOUT_MS }
                  )
                : translated.title;
              const fallbackSummary =
                (summarySame || summaryNeeds) && displaySummary
                  ? await withRetries(
                      () => translateText(displaySummary, lang),
                      { label: "translate_summary_fallback", timeoutMs: TRANSLATE_TIMEOUT_MS }
                    )
                  : translated.summary;
              translated = {
                title: fallbackTitle || translated.title,
                summary: fallbackSummary || translated.summary || displaySummary
              };
            } catch (error) {
              console.error("[Translate] fallback failed", error?.message || error);
            }
          }
        }

      const normalized = {
        title: translated.title,
        summary: translated.summary || displaySummary || "",
        content,
        url,
        resolvedUrl,
        sourceUrl,
        source,
        publishedAt,
        publishedAtFallbackOk: !publishedAt,
        severity,
        processing: Boolean(fastMode),
        processingStartedAt: fastMode
          ? resolveProcessingStartedAt(cachedHit)
          : "",
        processingEtaMinutes: fastMode
          ? estimateProcessingEtaMinutes(cachedProcessingDurationMs)
          : 0
      };
        const finalSeverity = degradeSeverityByAge(normalized);
        normalized.severity = finalSeverity;
        normalized.articleId = makeArticleId(normalized);
        if (!skipPush) {
          await sendCriticalPushIfNeeded(normalized, { region, lang });
        }
        return normalized;
      } catch (error) {
        console.error("[Item] failed", error?.message || error);
        return null;
      }
    });

  let results = await buildResults(baseRawItems, true);
  let filteredResults = results.filter(Boolean);

  if (!fastMode && filteredResults.length < limit) {
    try {
      const staticRawItems = await fetchStaticFallbackRssItems({
        keyword,
        searchKeyword,
        region,
        limit,
        breakingRequest,
        fastMode
      });
      if (staticRawItems.length) {
        const staticDeduped = dedupeByTitleSimilarity(staticRawItems);
        const staticResults = await buildResults(staticDeduped, true);
        filteredResults = filteredResults.concat(staticResults.filter(Boolean));
      }
    } catch (error) {
      console.error(
        "[StaticRSS] fallback failed",
        error?.message || error
      );
    }
  }

  if (fastMode && filteredResults.length === 0 && baseRawItems.length) {
    const fallbackItems = baseRawItems.slice(0, limit);
    const fallbackResults = await mapWithLimit(
      fallbackItems,
      ITEM_PROCESS_CONCURRENCY,
      async (item) => {
        const url = upgradeToHttps(item.link);
        if (!url) return null;
        const urlKey = normalizeCacheUrl(url);
        const cachedHit = urlKey ? cachedItemLookup.get(urlKey) : null;
        const title = normalizeWhitespace(item.title || "") || "Untitled";
        let summary = normalizeWhitespace(item.contentSnippet || item.content || "");
        if (summary) {
          summary = summarizeText(summary, 2);
        }
        const publishedAt = normalizePublishedAt(item);
        const source = resolveSourceFromItemFallback({
          item,
          url,
          resolvedUrl: url,
          sourceUrl: deriveSourceUrl(item)
        });
        const cacheSeed = buildArticleCacheSeed({
          url,
          source,
          title,
          summary,
          publishedAt
        });
        const displaySummary = summary;
        let translated = { title, summary: displaySummary };
        const translationPolicy = resolveTranslationPolicy(
          3,
          breakingRequest
        );
        const shouldTranslate = false;
        if (shouldTranslate) {
          try {
            const summaryInput = displaySummary;
            translated = await withRetries(
              () =>
                translateFields(
                  {
                    title,
                    summary: summaryInput,
                    url,
                    cacheSeed
                  },
                  lang
                ),
              { label: "translate_fallback", timeoutMs: TRANSLATE_TIMEOUT_MS }
            );
          } catch (error) {
            console.error("[Translate] fallback failed", error?.message || error);
          }
          if (!translated.summary) {
            translated.summary = displaySummary;
          }
          const titleSame =
            normalizeWhitespace(translated.title) === normalizeWhitespace(title);
          const summarySame =
            normalizeWhitespace(translated.summary) ===
              normalizeWhitespace(displaySummary);
          const titleNeeds =
            shouldTranslateSameLang(lang, translated.title || "", "");
          const summaryNeeds =
            shouldTranslateSameLang(lang, "", translated.summary || "");
          if (
            translationPolicy.allowFallback &&
            (titleSame || titleNeeds || summarySame || summaryNeeds)
          ) {
            try {
              const fallbackTitle = (titleSame || titleNeeds) && title
                ? await withRetries(
                    () => translateText(title, lang),
                    { label: "translate_title_fallback", timeoutMs: TRANSLATE_TIMEOUT_MS }
                  )
                : translated.title;
              const fallbackSummary =
                (summarySame || summaryNeeds) && displaySummary
                  ? await withRetries(
                      () => translateText(displaySummary, lang),
                      { label: "translate_summary_fallback", timeoutMs: TRANSLATE_TIMEOUT_MS }
                    )
                  : translated.summary;
              translated = {
                title: fallbackTitle || translated.title,
                summary: fallbackSummary || translated.summary || displaySummary
              };
            } catch (error) {
              console.error("[Translate] fallback text failed", error?.message || error);
            }
          }
        }
        const normalized = {
          title: translated.title,
          summary: translated.summary || displaySummary || "",
          content: "",
          url,
          resolvedUrl: url,
          sourceUrl: "",
          source,
          publishedAt,
          publishedAtFallbackOk: !publishedAt,
          severity: 3,
          processing: true,
          processingStartedAt: resolveProcessingStartedAt(cachedHit),
          processingEtaMinutes: estimateProcessingEtaMinutes(
            cachedProcessingDurationMs
          )
        };
        normalized.articleId = makeArticleId(normalized);
        return normalized;
      }
    );
    filteredResults = fallbackResults.filter(Boolean);
  }

  if (!fastMode) {
    let previousItems = [];
    const cachedMemory = newsCache.get(cacheKey);
    if (cachedMemory && Array.isArray(cachedMemory.items)) {
      previousItems = cachedMemory.items;
    } else {
      const cachedDb = await getCachedNews(cacheId);
      if (cachedDb && Array.isArray(cachedDb.items)) {
        previousItems = cachedDb.items;
      }
    }
    if (previousItems.length) {
      const pinnedCarry = previousItems
        .filter((item) => shouldKeepPinnedItem(item))
        .map((item) =>
          item && item.processing
            ? {
                ...item,
                processing: false,
                processingStartedAt: "",
                processingEtaMinutes: 0
              }
            : item
        );
      if (pinnedCarry.length) {
        filteredResults = filteredResults.concat(pinnedCarry);
      }
    }
  }

  const pinnedResults = filteredResults.filter((item) => item.severity >= 4);
  const normalResults = filteredResults.filter((item) => item.severity < 4);
  // Store more than the requested limit only for the base cache (`limit=20`).
  // `/news` can slice from this cache to serve larger limits without extra refreshes.
  const capped =
    limit === 20
      ? Math.max(limit, pinnedResults.length, NEWS_CACHE_STORE_LIMIT)
      : Math.max(limit, pinnedResults.length);
  filteredResults = pinnedResults.concat(normalResults).slice(0, capped);
  const sortedResults = filteredResults.sort((a, b) => {
    const sevDiff = (b.severity || 0) - (a.severity || 0);
    if (sevDiff !== 0) return sevDiff;
    const aTime = Date.parse(a.publishedAt || "");
    const bTime = Date.parse(b.publishedAt || "");
    if (Number.isNaN(aTime) && Number.isNaN(bTime)) return 0;
    if (Number.isNaN(aTime)) return 1;
    if (Number.isNaN(bTime)) return -1;
    return bTime - aTime;
  });
  const dedupedResults = dedupeByArticleId(sortedResults);
  const contentDeduped = dedupeByContentKey(dedupedResults);
  const observedProcessingDurationMs = fastMode
    ? null
    : computeObservedProcessingDurationMsFromItems(cachedItems, nowMs);
  const processingDurationMs = blendProcessingDurationMs(
    cachedProcessingDurationMs,
    observedProcessingDurationMs
  );
  const processingEtaMinutes = estimateProcessingEtaMinutes(
    processingDurationMs
  );
  if (shouldRecordDynamic && dynamicGoogleDomains && dynamicGoogleDomains.size) {
    try {
      await recordDynamicRegionSources(
        region,
        Array.from(dynamicGoogleDomains)
      );
    } catch (error) {
      console.error(
        "[DynamicAllowlist] google top stories record failed",
        error?.message || error
      );
    }
  }

  if (contentDeduped.length === 0) {
    let fallbackItems = cachedItems;
    if (!fallbackItems || fallbackItems.length === 0) {
      const cachedMemory = newsCache.get(cacheKey);
      if (cachedMemory && Array.isArray(cachedMemory.items) && cachedMemory.items.length) {
        fallbackItems = cachedMemory.items;
      } else {
        const cachedMeta = await getCachedNewsMeta(cacheId);
        if (
          cachedMeta &&
          cachedMeta.ageMs <= NEWS_CACHE_STALE_MAX_MS &&
          Array.isArray(cachedMeta.data?.items) &&
          cachedMeta.data.items.length
        ) {
          fallbackItems = cachedMeta.data.items;
        }
      }
    }
    if (fallbackItems && fallbackItems.length) {
      let filteredFallback = fallbackItems;
      if (region.toUpperCase() !== "ALL") {
        const enforced = fallbackItems.filter((item) =>
          isSourceAllowedForRegion(region, {
            sourceName: item?.source,
            sourceUrl: item?.sourceUrl,
            resolvedUrl: item?.resolvedUrl
          })
        );
        // If the allowlist got stricter since the last cache, fall back to the
        // previous items anyway rather than returning an empty feed.
        if (enforced.length) {
          filteredFallback = enforced;
        }
      }
      const fallbackState = summarizeTaskCachedItems(filteredFallback);
      const staleProcessingOnly =
        !fastMode &&
        fallbackState.onlyProcessing &&
        Number.isFinite(fallbackState.processingAgeMs) &&
        fallbackState.processingAgeMs >= PROCESSING_RECOVERY_TRIGGER_MS;
      const nonFastProcessingOnly =
        !fastMode && fallbackState.onlyProcessing;
      if (staleProcessingOnly) {
        console.warn(
          `[CacheFallback] convert stale processing-only cache ${canonicalKeyword} ${region}/${lang} feed=${feedLang} ageMs=${fallbackState.processingAgeMs}`
        );
        const completedFallback = filteredFallback.map((item) =>
          item && item.processing
            ? {
                ...item,
                processing: false,
                processingStartedAt: "",
                processingEtaMinutes: 0
              }
            : item
        );
        const payload = {
          keyword,
          canonical: canonicalKeyword,
          lang,
          items: completedFallback,
          processingDurationMs,
          processingEtaMinutes
        };
        newsCache.set(cacheKey, payload);
        try {
          await setCachedNews(cacheId, {
            keyword,
            canonical: canonicalKeyword,
            keywordKey: keywordKey(canonicalKeyword),
            aliases: aliasKeywords,
            lang,
            feedLang,
            region,
            limit,
            items: completedFallback,
            processingDurationMs,
            processingEtaMinutes
          });
        } catch (error) {
          console.error(
            "[CacheFallback] persist stale-completed fallback failed",
            error?.message || error
          );
        }
        return payload;
      } else if (nonFastProcessingOnly) {
        // Non-fast refresh has completed but still produced no finalized items.
        // Convert placeholder-only cache to completed cards to avoid
        // indefinitely showing "AI processing" badges.
        const completedFallback = filteredFallback.map((item) =>
          item && item.processing
            ? {
                ...item,
                processing: false,
                processingStartedAt: "",
                processingEtaMinutes: 0
              }
            : item
        );
        const payload = {
          keyword,
          canonical: canonicalKeyword,
          lang,
          items: completedFallback,
          processingDurationMs,
          processingEtaMinutes
        };
        newsCache.set(cacheKey, payload);
        try {
          await setCachedNews(cacheId, {
            keyword,
            canonical: canonicalKeyword,
            keywordKey: keywordKey(canonicalKeyword),
            aliases: aliasKeywords,
            lang,
            feedLang,
            region,
            limit,
            items: completedFallback,
            processingDurationMs,
            processingEtaMinutes
          });
        } catch (error) {
          console.error(
            "[CacheFallback] persist completed fallback failed",
            error?.message || error
          );
        }
        return payload;
      } else {
        const payload = {
          keyword,
          canonical: canonicalKeyword,
          lang,
          items: filteredFallback,
          processingDurationMs,
          processingEtaMinutes
        };
        newsCache.set(cacheKey, payload);
        try {
          await setCachedNews(cacheId, {
            keyword,
            canonical: canonicalKeyword,
            keywordKey: keywordKey(canonicalKeyword),
            aliases: aliasKeywords,
            lang,
            feedLang,
            region,
            limit,
            items: filteredFallback,
            processingDurationMs,
            processingEtaMinutes
          });
        } catch (error) {
          console.error(
            "[CacheFallback] persist fallback failed",
            error?.message || error
          );
        }
        return payload;
      }
    }
  }

  if (!breakingRequest && !skipPush) {
    const pushCandidates = contentDeduped.filter(
      (item) => (item?.severity || 0) >= 4
    );

    await mapWithLimit(pushCandidates, PUSH_CONCURRENCY, async (item) => {
      const severity = item.severity || 0;
      try {
        await sendKeywordPushIfNeeded(
          item,
          canonicalKeyword,
          severity,
          lang,
          region,
          { force: false, aliasKeywords }
        );
      } catch (error) {
        console.error("[Push] failed", error?.message || error);
      }
      return null;
    });
  }

  if (!skipPush) {
    const keywordTrigger = keyword.toLowerCase().includes("비상");
    if (keywordTrigger && Array.isArray(contentDeduped)) {
      const testItem = contentDeduped.find(
        (item) => item && item.url === "https://example.com/emergency-test"
      );
      if (testItem) {
        await sendCriticalPushIfNeeded(testItem, { force: false, region, lang });
      }
    }
  }

  const payload = {
    keyword,
    canonical: canonicalKeyword,
    lang,
    items: contentDeduped,
    processingDurationMs,
    processingEtaMinutes
  };
  const shouldPersistCache = Array.isArray(contentDeduped) && contentDeduped.length > 0;
  if (sortedResults.length) {
    newsCache.set(cacheKey, payload);
  }
  if (shouldPersistCache) {
    await setCachedNews(cacheId, {
      keyword,
      canonical: canonicalKeyword,
      keywordKey: keywordKey(canonicalKeyword),
      aliases: aliasKeywords,
      lang,
      feedLang,
      region,
      limit,
      items: contentDeduped,
      processingDurationMs,
      processingEtaMinutes
    });
  } else {
    console.log(
      `[CacheSkipWrite] empty result ${canonicalKeyword} ${region}/${lang} feed=${feedLang} fast=${fastMode ? "1" : "0"}`
    );
  }
  return payload;
}

app.get("/news", async (req, res) => {
  try {
    const keyword = (req.query.keyword || "").toString().trim();
    if (!keyword) {
      return res.status(400).json({ error: "keyword is required" });
    }

    const lang = normalizeLangCode(req.query.lang || "en");
    const feedLang = normalizeLangCode(req.query.feedLang || lang);
    const region = normalizeRegionCode(req.query.region || "US", "US");
    const limitRaw = parseInt(req.query.limit || "10", 10);
    const limit = Math.max(
      1,
      Math.min(Number.isFinite(limitRaw) ? limitRaw : 10, NEWS_API_MAX_LIMIT)
    );
    const refresh = (req.query.refresh || "").toString().toLowerCase();
    const refreshSeed = (req.query.refreshSeed || "").toString().trim();
    const skipMemoryCache =
      refresh === "1" || refresh === "true" || Boolean(refreshSeed);
    const refreshRequested = skipMemoryCache;
    const canonicalKeyword =
      normalizeWhitespace((await getCanonicalKeyword(keyword, lang)) || keyword) ||
      keyword;
    const cacheKey = `${canonicalKeyword}::${lang}::${feedLang}::${region}::${limit}`;
    const cached = !skipMemoryCache ? newsCache.get(cacheKey) : null;
    if (cached && Array.isArray(cached.items) && cached.items.length) {
      const slicedItems =
        cached.items.length > limit ? cached.items.slice(0, limit) : cached.items;
      return res.json({ ...cached, items: slicedItems });
    }

    const cacheId = makeNewsCacheId(
      canonicalKeyword,
      region,
      feedLang,
      lang,
      limit
    );
    let items = null;
    const cachedMeta = await getCachedNewsMeta(cacheId);
    if (
      cachedMeta &&
      cachedMeta.ageMs <= NEWS_CACHE_STALE_MAX_MS &&
      Array.isArray(cachedMeta.data?.items) &&
      cachedMeta.data.items.length
    ) {
      items = cachedMeta.data.items;
    }
    if (items && items.length) {
      items = dedupeByContentKey(dedupeByArticleId(items));
      if (items.length > limit) {
        items = items.slice(0, limit);
      }
    }

    if (!items && limit !== 20) {
      const fallbackLimit = 20;
      const fallbackKey = `${canonicalKeyword}::${lang}::${feedLang}::${region}::${fallbackLimit}`;
      const cachedFallback = newsCache.get(fallbackKey);
      if (
        cachedFallback &&
        Array.isArray(cachedFallback.items) &&
        cachedFallback.items.length
      ) {
        items = cachedFallback.items;
      }
      if (!items) {
        const fallbackCacheId = makeNewsCacheId(
          canonicalKeyword,
          region,
          feedLang,
          lang,
          fallbackLimit
        );
        const fallbackMeta = await getCachedNewsMeta(fallbackCacheId);
        if (
          fallbackMeta &&
          fallbackMeta.ageMs <= NEWS_CACHE_STALE_MAX_MS &&
          Array.isArray(fallbackMeta.data?.items) &&
          fallbackMeta.data.items.length
        ) {
          items = fallbackMeta.data.items;
        }
      }
      if (items && items.length > limit) {
        items = items.slice(0, limit);
      }
    }

    if (!items || !items.length) {
      const onDemandTask = {
        keyword: canonicalKeyword,
        canonicalKeyword,
        region,
        lang,
        feedLang,
        limit: 20
      };
      const cacheState = await getTaskCacheState(onDemandTask);
      const shouldQueueOnDemand =
        !cacheState.hasAnyCache || cacheState.onlyProcessing;
      if (shouldQueueOnDemand) {
        enqueueCrawlTasks([onDemandTask], req)
          .then(async (queued) => {
            if (queued?.ok && Number(queued.enqueued || 0) > 0) {
              await markSkipNextScheduledCrawl(onDemandTask, {
                reason: "news_request_on_demand"
              });
              console.log(
                `[News] on-demand queued ${canonicalKeyword} ${region}/${lang} feed=${feedLang}`
              );
            }
          })
          .catch((error) => {
            console.error(
              "[News] on-demand enqueue failed",
              canonicalKeyword,
              error?.message || error
            );
          });
      }

      if (refreshRequested) {
        const refreshTimeoutMs = Math.min(
          12000,
          Math.max(8000, TASK_TIMEOUT_MS)
        );
        try {
          const fastModeDecision = await canRunFastModeFallback(onDemandTask);
          if (fastModeDecision.ok) {
            const fastModePayload = await runWithTimeout(
              () =>
                refreshNewsCacheFromSource({
                  keyword: canonicalKeyword,
                  canonicalKeyword,
                  lang,
                  feedLang,
                  region,
                  limit: 20,
                  skipPush: true,
                  fastMode: true
                }),
              refreshTimeoutMs,
              "news_fastmode_fallback"
            );
            if (
              Array.isArray(fastModePayload?.items) &&
              fastModePayload.items.length
            ) {
              items = fastModePayload.items;
              if (items.length > limit) {
                items = items.slice(0, limit);
              }
              await markFastModeFallbackTriggered(onDemandTask, {
                reason: "news_request_cache_empty"
              });
              console.log(
                `[News] fastMode fallback served ${canonicalKeyword} ${region}/${lang} feed=${feedLang}`
              );
            }
          }
        } catch (error) {
          console.error(
            "[News] fastMode fallback failed",
            canonicalKeyword,
            error?.message || error
          );
        }
      }
    }

    if (items && items.length && items.some((item) => item?.processing)) {
      const onlyProcessing = items.every((item) => item?.processing === true);
      enqueueProcessingRecoveryIfNeeded(
        {
          keyword: canonicalKeyword,
          canonicalKeyword,
          region,
          lang,
          feedLang,
          limit: 20
        },
        req,
        {
          items,
          force: refreshRequested && onlyProcessing
        }
      )
        .then((result) => {
          if (result?.ok && result.reason === "queued") {
            console.log(
              `[News] processing recovery queued ${canonicalKeyword} ${region}/${lang} feed=${feedLang}`
            );
          }
        })
        .catch((error) => {
          console.error(
            "[News] processing recovery failed",
            canonicalKeyword,
            error?.message || error
          );
        });
    }

    const payload = {
      keyword,
      canonical: canonicalKeyword,
      lang,
      items: items || []
    };
    if (Array.isArray(payload.items) && payload.items.length) {
      newsCache.set(cacheKey, payload);
    }
    res.json(payload);
  } catch (error) {
    const message = error?.stack || error?.message || String(error);
    const context = [
      `keyword=${req.query.keyword}`,
      `lang=${req.query.lang}`,
      `feedLang=${req.query.feedLang}`,
      `region=${req.query.region}`,
      `limit=${req.query.limit}`,
      `refresh=${req.query.refresh}`,
      `cron=${req.query.cron}`
    ].join(" ");
    console.error(`[News] failed ${message} ${context}`);
    res.status(500).json({ error: "failed to fetch news" });
  }
});

async function buildCrawlTasksFromSubscriptions(db) {
  const snap = await db.collection("keyword_subscriptions").get();
  const tasks = new Map();
  if (!snap.empty) {
    snap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const canonical = normalizeWhitespace(data.canonical || "");
      if (!canonical) return;
      const count = Number(data.count || 0);
      if (!Number.isFinite(count) || count <= 0) return;
      const regions = Array.isArray(data.regions) && data.regions.length
        ? data.regions
        : ["ALL"];
      const langs = Array.isArray(data.langs) && data.langs.length
        ? data.langs
        : ["en"];
      const regionLangs = data.regionLangs || {};
      const aliases = Array.isArray(data.aliases)
        ? data.aliases.map((value) => normalizeWhitespace(value || "")).filter(Boolean)
        : [];

      for (const regionValue of regions) {
        const region = String(regionValue || "ALL").toUpperCase();
        const feedLang = normalizeLangCode(
          regionLangs[region] ||
            REGION_FEED_LANG[region] ||
            REGION_FEED_LANG.ALL ||
            "en"
        );
        for (const langValue of langs) {
          const lang = normalizeLangCode(langValue || "en");
          const key = `${canonical}::${region}::${feedLang}::${lang}`;
          if (!tasks.has(key)) {
            tasks.set(key, { keyword: canonical, region, feedLang, lang, aliases });
          }
        }
      }
    });
  }

  const breakingTargets = await resolveBreakingTargets(db);
  for (const target of breakingTargets) {
    const parts = String(target || "").split("::");
    if (parts.length < 2) continue;
    const region = String(parts[0] || "ALL").toUpperCase();
    const lang = normalizeLangCode(parts[1] || "en");
    const feedLang = normalizeLangCode(
      REGION_FEED_LANG[region] || REGION_FEED_LANG.ALL || "en"
    );
    const key = `${BREAKING_KEYWORD}::${region}::${feedLang}::${lang}`;
    if (!tasks.has(key)) {
      tasks.set(key, { keyword: BREAKING_KEYWORD, region, feedLang, lang });
    }
  }

  const builtTasks = Array.from(tasks.values());
  const skipApplied = await consumeScheduledSkipOnce(builtTasks);
  if (skipApplied.skipped > 0) {
    console.log(
      `[CronCrawl] skip-once applied skipped=${skipApplied.skipped} remaining=${skipApplied.tasks.length}`
    );
  }
  return skipApplied.tasks;
}

async function runCrawlTasksInline(taskList) {
  const cacheLimit = 20;
  const results = await mapWithLimit(
    taskList,
    CRON_REFRESH_CONCURRENCY,
    async (task) => {
      try {
        await refreshNewsCacheFromSource({
          keyword: task.keyword,
          canonicalKeyword: task.keyword,
          lang: task.lang,
          feedLang: task.feedLang,
          region: task.region,
          limit: cacheLimit,
          aliases: task.aliases,
          skipPush: true
        });
        return { ok: true };
      } catch (error) {
        console.error(
          `[CronCrawl] failed ${task.keyword} ${task.region}/${task.lang}`,
          error?.message || error
        );
        return { ok: false };
      }
    }
  );
  const success = results.filter((entry) => entry && entry.ok).length;
  return { mode: "inline", total: taskList.length, success };
}

async function runCrawlTasks(taskList, req) {
  if (taskList.length === 0) {
    return { mode: "none", total: 0, success: 0 };
  }
  const cacheLimit = 20;
  const enriched = taskList.map((task) => ({
    ...task,
    limit: task.limit || cacheLimit
  }));
  const queued = await enqueueCrawlTasks(enriched, req);
  if (queued.ok) {
    return {
      mode: "tasks",
      total: taskList.length,
      enqueued: queued.enqueued,
      failed: queued.failed
    };
  }
  return runCrawlTasksInline(taskList);
}

async function sendPushFromCacheDoc(data) {
  const items = Array.isArray(data.items) ? data.items : [];
  if (!items.length) return 0;
  const canonical = normalizeWhitespace(data.canonical || data.keyword || "");
  const keyword = normalizeWhitespace(data.keyword || canonical);
  const lang = normalizeLangCode(data.lang || "en");
  const region = String(data.region || "ALL").toUpperCase();
  const aliases = Array.isArray(data.aliases) ? data.aliases : [];
  const breakingRequest = isBreakingKeyword(keyword);
  let pushed = 0;

  if (breakingRequest) {
    const criticalItems = items.filter((item) => (item?.severity || 0) >= 5);
    await mapWithLimit(criticalItems, PUSH_CONCURRENCY, async (item) => {
      try {
        await sendCriticalPushIfNeeded(item, { region, lang });
        pushed += 1;
      } catch (error) {
        console.error("[CronPush] critical failed", error?.message || error);
      }
      return null;
    });
    return pushed;
  }

  if (!canonical) return 0;
  const candidates = items.filter((item) => (item?.severity || 0) >= 4);
  await mapWithLimit(candidates, PUSH_CONCURRENCY, async (item) => {
    const severity = item?.severity || 0;
    try {
      await sendKeywordPushIfNeeded(
        item,
        canonical,
        severity,
        lang,
        region,
        { force: false, aliasKeywords: aliases }
      );
      pushed += 1;
    } catch (error) {
      console.error("[CronPush] keyword failed", error?.message || error);
    }
    return null;
  });
  return pushed;
}

async function runPushFromRecentCaches() {
  const db = getFirestore();
  if (!db) {
    return { ok: false, error: "firestore_unavailable" };
  }
  const cutoffIso = new Date(
    Date.now() - PUSH_MAX_AGE_MINUTES * 60 * 1000
  ).toISOString();
  let query = db
    .collection("news_cache")
    .where("fetchedAt", ">=", cutoffIso)
    .orderBy("fetchedAt")
    .limit(200);
  let scanned = 0;
  let pushed = 0;
  while (true) {
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      scanned += 1;
      const data = doc.data() || {};
      pushed += await sendPushFromCacheDoc(data);
    }
    if (snap.size < 200) break;
    const last = snap.docs[snap.docs.length - 1];
    query = db
      .collection("news_cache")
      .where("fetchedAt", ">=", cutoffIso)
      .orderBy("fetchedAt")
      .startAfter(last)
      .limit(200);
  }
  console.log(
    `[CronPush] scanned=${scanned} pushed=${pushed} cutoff=${cutoffIso}`
  );
  return { ok: true, scanned, pushed, cutoffIso };
}

app.get("/cron/refresh", async (req, res) => {
  let lockRunId = null;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(500).json({ ok: false, error: "firestore_unavailable" });
    }
    const lock = await acquireCronLock("news_refresh", CRON_LOCK_TTL_MS);
    if (!lock.ok) {
      const status = lock.error === "locked" ? 429 : 503;
      return res.status(status).json({
        ok: false,
        error: "cron_locked",
        lockedAt: lock.lockedAt || null,
        expiresAt: lock.expiresAt || null
      });
    }
    lockRunId = lock.runId;
    const taskList = await buildCrawlTasksFromSubscriptions(db);
    const crawlResult = await runCrawlTasks(taskList, req);
    const pushResult = await runPushFromRecentCaches();

    try {
      const cleanup = await cleanupOldNewsCache({ batchSize: 300 });
      if (cleanup.deleted > 0) {
        console.log(
          `[CronRefresh] cleanup deleted=${cleanup.deleted} cutoff=${cleanup.cutoffIso}`
        );
      }
    } catch (error) {
      console.error("[CronRefresh] cleanup failed", error?.message || error);
    }

    let maintenance = null;
    try {
      maintenance = await processUserMaintenance({
        batchSize: USER_MAINTENANCE_BATCH_SIZE
      });
      if (maintenance && maintenance.processed > 0) {
        console.log(
          `[CronRefresh] userMaintenance processed=${maintenance.processed} updated=${maintenance.updated} renewedTabs=${maintenance.renewedTabs} expiredTabs=${maintenance.expiredTabs}`
        );
      }
    } catch (error) {
      console.error("[CronRefresh] userMaintenance failed", error?.message || error);
    }

    let onestoreRefunds = null;
    try {
      onestoreRefunds = await reconcileOneStoreRefunds();
      if (
        onestoreRefunds &&
        (onestoreRefunds.checked > 0 ||
          onestoreRefunds.refunded > 0 ||
          onestoreRefunds.errors > 0)
      ) {
        console.log(
          `[CronRefresh] onestoreRefunds processed=${onestoreRefunds.processed} checked=${onestoreRefunds.checked} refunded=${onestoreRefunds.refunded} skipped=${onestoreRefunds.skipped} errors=${onestoreRefunds.errors}`
        );
      }
    } catch (error) {
      console.error(
        "[CronRefresh] onestoreRefunds failed",
        error?.message || error
      );
    }

    const payload = { ok: true, crawl: crawlResult, push: pushResult };
    if (maintenance) {
      payload.maintenance = maintenance;
    }
    if (onestoreRefunds) {
      payload.onestoreRefunds = onestoreRefunds;
    }
    res.json(payload);
  } catch (error) {
    console.error("[CronRefresh] failed", error);
    res.status(500).json({ ok: false, error: "cron_failed" });
  } finally {
    if (lockRunId) {
      try {
        await releaseCronLock("news_refresh", lockRunId);
      } catch (error) {
        console.error("[CronRefresh] unlock failed", error?.message || error);
      }
    }
  }
});

app.get("/cron/crawl", async (req, res) => {
  let lockRunId = null;
  try {
    const db = getFirestore();
    if (!db) {
      return res.status(500).json({ ok: false, error: "firestore_unavailable" });
    }
    const lock = await acquireCronLock("news_crawl", CRON_LOCK_TTL_MS);
    if (!lock.ok) {
      const status = lock.error === "locked" ? 429 : 503;
      return res.status(status).json({
        ok: false,
        error: "cron_locked",
        lockedAt: lock.lockedAt || null,
        expiresAt: lock.expiresAt || null
      });
    }
    lockRunId = lock.runId;
    const taskList = await buildCrawlTasksFromSubscriptions(db);
    const crawlResult = await runCrawlTasks(taskList, req);

    try {
      const cleanup = await cleanupOldNewsCache({ batchSize: 300 });
      if (cleanup.deleted > 0) {
        console.log(
          `[CronCrawl] cleanup deleted=${cleanup.deleted} cutoff=${cleanup.cutoffIso}`
        );
      }
    } catch (error) {
      console.error("[CronCrawl] cleanup failed", error?.message || error);
    }

    let maintenance = null;
    try {
      maintenance = await processUserMaintenance({
        batchSize: USER_MAINTENANCE_BATCH_SIZE
      });
      if (maintenance && maintenance.processed > 0) {
        console.log(
          `[CronCrawl] userMaintenance processed=${maintenance.processed} updated=${maintenance.updated} renewedTabs=${maintenance.renewedTabs} expiredTabs=${maintenance.expiredTabs}`
        );
      }
    } catch (error) {
      console.error("[CronCrawl] userMaintenance failed", error?.message || error);
    }

    let onestoreRefunds = null;
    try {
      onestoreRefunds = await reconcileOneStoreRefunds();
      if (
        onestoreRefunds &&
        (onestoreRefunds.checked > 0 ||
          onestoreRefunds.refunded > 0 ||
          onestoreRefunds.errors > 0)
      ) {
        console.log(
          `[CronCrawl] onestoreRefunds processed=${onestoreRefunds.processed} checked=${onestoreRefunds.checked} refunded=${onestoreRefunds.refunded} skipped=${onestoreRefunds.skipped} errors=${onestoreRefunds.errors}`
        );
      }
    } catch (error) {
      console.error(
        "[CronCrawl] onestoreRefunds failed",
        error?.message || error
      );
    }

    const payload = { ok: true, crawl: crawlResult };
    if (maintenance) {
      payload.maintenance = maintenance;
    }
    if (onestoreRefunds) {
      payload.onestoreRefunds = onestoreRefunds;
    }
    res.json(payload);
  } catch (error) {
    console.error("[CronCrawl] failed", error);
    res.status(500).json({ ok: false, error: "cron_failed" });
  } finally {
    if (lockRunId) {
      try {
        await releaseCronLock("news_crawl", lockRunId);
      } catch (error) {
        console.error("[CronCrawl] unlock failed", error?.message || error);
      }
    }
  }
});

app.get("/cron/onestore-refunds", async (req, res) => {
  let lockRunId = null;
  try {
    const lock = await acquireCronLock(
      "onestore_refund_reconcile",
      CRON_LOCK_TTL_MS
    );
    if (!lock.ok) {
      const status = lock.error === "locked" ? 429 : 503;
      return res.status(status).json({
        ok: false,
        error: "cron_locked",
        lockedAt: lock.lockedAt || null,
        expiresAt: lock.expiresAt || null
      });
    }
    lockRunId = lock.runId;
    const batchSize = Number.parseInt(req.query.batchSize || "", 10);
    const result = await reconcileOneStoreRefunds({
      batchSize: Number.isFinite(batchSize) ? batchSize : undefined
    });
    return res.json({ ok: true, onestoreRefunds: result });
  } catch (error) {
    console.error("[CronOneStoreRefunds] failed", error?.message || error);
    return res.status(500).json({ ok: false, error: "cron_failed" });
  } finally {
    if (lockRunId) {
      try {
        await releaseCronLock("onestore_refund_reconcile", lockRunId);
      } catch (error) {
        console.error(
          "[CronOneStoreRefunds] unlock failed",
          error?.message || error
        );
      }
    }
  }
});

app.get("/cron/push", async (req, res) => {
  let lockRunId = null;
  try {
    const lock = await acquireCronLock("news_push", CRON_LOCK_TTL_MS);
    if (!lock.ok) {
      const status = lock.error === "locked" ? 429 : 503;
      return res.status(status).json({
        ok: false,
        error: "cron_locked",
        lockedAt: lock.lockedAt || null,
        expiresAt: lock.expiresAt || null
      });
    }
    lockRunId = lock.runId;
    const pushResult = await runPushFromRecentCaches();
    res.json({ ok: true, push: pushResult });
  } catch (error) {
    console.error("[CronPush] failed", error);
    res.status(500).json({ ok: false, error: "cron_failed" });
  } finally {
    if (lockRunId) {
      try {
        await releaseCronLock("news_push", lockRunId);
      } catch (error) {
        console.error("[CronPush] unlock failed", error?.message || error);
      }
    }
  }
});

app.post("/tasks/crawl", async (req, res) => {
  try {
    if (!isCloudTasksRequest(req)) {
      return res.status(403).json({ ok: false, error: "forbidden" });
    }
    const keyword = (req.body?.keyword || "").toString().trim();
    if (!keyword) {
      return res.status(400).json({ ok: false, error: "keyword_required" });
    }
    const canonicalKeyword = normalizeWhitespace(
      req.body?.canonicalKeyword || keyword
    );
    const lang = normalizeLangCode(req.body?.lang || "en");
    const feedLang = normalizeLangCode(req.body?.feedLang || lang);
    const region = (req.body?.region || "ALL").toString().toUpperCase();
    const limit = Math.min(parseInt(req.body?.limit || "20", 10), 20);
    const aliases = Array.isArray(req.body?.aliases) ? req.body.aliases : [];

    await refreshNewsCacheFromSource({
      keyword: canonicalKeyword,
      canonicalKeyword,
      lang,
      feedLang,
      region,
      limit,
      aliases,
      skipPush: true
    });
    res.json({ ok: true });
  } catch (error) {
    console.error("[Tasks] crawl failed", error?.message || error);
    res.status(500).json({ ok: false, error: "task_failed" });
  }
});

app.get("/article", async (req, res) => {
  try {
    const url = (req.query.url || "").toString().trim();
    if (!url) {
      return res.status(400).json({ error: "url is required" });
    }
    const article = await extractArticle(url);
    const summary = summarizeText(article.content, 3);

    res.json({
      url,
      title: article.title,
      summary,
      content: article.content,
      resolvedUrl: article.resolvedUrl || url
    });
  } catch {
    res.json({
      url: req.query.url || "",
      title: "",
      summary: "",
      content: ""
    });
  }
});

app.get("/article/translate", async (req, res) => {
  try {
    const url = (req.query.url || "").toString().trim();
    if (!url) {
      return res.status(400).json({ error: "url is required" });
    }
    const langRaw = (req.query.lang || "en").toString();
    const lang = normalizeLangAlias(langRaw, "en");
    const fallback = (req.query.fallback || "").toString();
    const mode = (req.query.mode || "translate").toString();
    const length = (req.query.length || "medium").toString();
    let baseContent = "";
    let articleTitle = "";
    let resolvedUrl = url;
    let usedFallback = false;
    let limited = false;
    try {
      const article = await extractArticle(url);
      baseContent = article.content || "";
      articleTitle = article.title || "";
      resolvedUrl = article.resolvedUrl || url;
    } catch (error) {
      const message = (error && error.message) || "";
      if (message.includes("403")) {
        limited = true;
      }
    }
    if (baseContent.length < 200 && fallback) {
      baseContent = fallback;
      usedFallback = true;
    }
    baseContent = normalizeWhitespace(baseContent);
    const baseLen = baseContent.length;
    let reason = "";
    let notice = "";
    let noticeCode = "";
    const cacheSeed = buildArticleCacheSeed({
      resolvedUrl,
      url,
      title: articleTitle
    });
    const isTimeoutLike = (message) => {
      const text = String(message || "");
      return (
        text.includes("timeout") ||
        text.includes("AbortError") ||
        text.includes("translate_text_timeout")
      );
    };

    let translatedContent = "";
    if (limited) {
      if (mode === "summary") {
        translatedContent = summarizeText(
          baseContent,
          summarySentenceCount(length)
        );
      } else {
        translatedContent = baseContent;
      }
      reason = "LIMITED_403";
      notice = "Content access limited (403). Showing original text.";
    } else {
      if (mode === "summary") {
        if (usedFallback) {
          const fallbackSummary = summarizeText(
            baseContent,
            summarySentenceCount(length)
          );
          translatedContent = shouldTranslateSameLang(
            lang,
            fallbackSummary,
            ""
          )
            ? await translateText(fallbackSummary, lang)
            : fallbackSummary;
        } else {
          translatedContent = await summarizeArticleContent(
            url,
            baseContent,
            lang,
            length,
            cacheSeed
          );
        }
      } else if (usedFallback) {
        try {
          translatedContent = await translateLongText(baseContent, lang);
        } catch (error) {
          if (isTimeoutLike(error?.message)) {
            const fallbackSummary = summarizeText(
              baseContent,
              summarySentenceCount("medium")
            );
            if (shouldTranslateSameLang(lang, fallbackSummary, "")) {
              try {
                translatedContent = await translateText(fallbackSummary, lang);
              } catch (_) {
                translatedContent = fallbackSummary;
              }
            } else {
              translatedContent = fallbackSummary;
            }
            noticeCode = "LONG_FALLBACK_SUMMARY";
          } else {
            throw error;
          }
        }
      } else {
        try {
          translatedContent = await translateArticleContent(
            url,
            baseContent,
            lang,
            cacheSeed
          );
        } catch (error) {
          if (isTimeoutLike(error?.message)) {
            const fallbackSummary = summarizeText(
              baseContent,
              summarySentenceCount("medium")
            );
            if (shouldTranslateSameLang(lang, fallbackSummary, "")) {
              try {
                translatedContent = await translateText(fallbackSummary, lang);
              } catch (_) {
                translatedContent = fallbackSummary;
              }
            } else {
              translatedContent = fallbackSummary;
            }
            noticeCode = "LONG_FALLBACK_SUMMARY";
          } else {
            throw error;
          }
        }
      }
    }

    const cacheMode = mode === "summary" ? "summary" : "full";
    const cacheLength = cacheMode === "summary" ? length : "full";
    try {
      await setAppTranslationCache({
        url,
        lang: langRaw,
        mode: cacheMode,
        length: cacheLength,
        translatedContent,
        limited,
        link: limited ? url : ""
      });
    } catch (error) {
      console.error(
        "[TranslationCache] write failed",
        error?.message || error
      );
    }

    res.json({
      ok: true,
      url,
      translatedContent,
      limited,
      link: limited ? url : "",
      reason,
      notice,
      noticeCode,
      mode,
      usedFallback,
      baseLen,
      langRaw,
      langNormalized: lang
    });
  } catch (error) {
    console.error("Translate endpoint failed:", error.message || error);
    res.json({
      ok: false,
      url: req.query.url || "",
      translatedContent: "",
      error: (error && error.message) || "translation_failed",
      mode: (req.query.mode || "translate").toString(),
      langRaw: (req.query.lang || "en").toString(),
      langNormalized: normalizeLangAlias(req.query.lang || "en", "en")
    });
  }
});

let internalCronInFlight = false;
async function triggerInternalCronRefresh() {
  if (internalCronInFlight) return;
  internalCronInFlight = true;
  try {
    const url = `http://127.0.0.1:${PORT}/cron/refresh`;
    await fetchWithTimeout(url, {}, 20000);
  } catch (error) {
    console.error("[InternalCron] refresh failed", error?.message || error);
  } finally {
    internalCronInFlight = false;
  }
}

app.listen(PORT, () => {
  console.log(`server listening on ${PORT}`);
  if (ENABLE_INTERNAL_CRON) {
    console.log(
      `[InternalCron] enabled every ${INTERNAL_CRON_INTERVAL_MINUTES} minutes`
    );
    setTimeout(triggerInternalCronRefresh, 5000);
    setInterval(
      triggerInternalCronRefresh,
      INTERNAL_CRON_INTERVAL_MINUTES * 60 * 1000
    );
  }
});
