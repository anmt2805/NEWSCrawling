import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  getAuth,
  signInWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  onAuthStateChanged,
  signOut
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";

const firebaseConfig = {
  apiKey: "AIzaSyBu9ey0gWGM5dTetOxGJukDtIpQYRMK3DA",
  authDomain: "news-caebd.firebaseapp.com",
  projectId: "news-caebd",
  storageBucket: "news-caebd.firebasestorage.app",
  messagingSenderId: "442218050266",
  appId: "1:442218050266:android:2b803c2666195ccd262be3"
};

const DEFAULT_API_BASE =
  "https://news-crawl-server-1008445727632.asia-northeast3.run.app";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

const apiBaseInput = document.getElementById("apiBaseUrl");
const reloadBtn = document.getElementById("reloadBtn");
const logoutBtn = document.getElementById("logoutBtn");
const loginCard = document.getElementById("loginCard");
const dashboard = document.getElementById("dashboard");
const loginForm = document.getElementById("loginForm");
const loginMessage = document.getElementById("loginMessage");
const googleLoginBtn = document.getElementById("googleLoginBtn");
const grantForm = document.getElementById("grantForm");
const grantMessage = document.getElementById("grantMessage");
const deductForm = document.getElementById("deductForm");
const deductMessage = document.getElementById("deductMessage");
const tabLookupForm = document.getElementById("tabLookupForm");
const tabLookupMessage = document.getElementById("tabLookupMessage");
const tabSetForm = document.getElementById("tabSetForm");
const tabSetMessage = document.getElementById("tabSetMessage");
const sessionEmail = document.getElementById("sessionEmail");
const statusMessage = document.getElementById("statusMessage");
const sourcesBody = document.getElementById("sourcesBody");
const keywordsBody = document.getElementById("keywordsBody");
const negativeUsersBody = document.getElementById("negativeUsersBody");
const negativeUsersMessage = document.getElementById("negativeUsersMessage");
const metricsContainer = document.getElementById("metrics");
const languageSelect = document.getElementById("languageSelect");
const toggleGoogleNews = document.getElementById("toggleGoogleNews");
const toggleNaver = document.getElementById("toggleNaver");
const toggleGdelt = document.getElementById("toggleGdelt");
const saveCrawlSourcesBtn = document.getElementById("saveCrawlSourcesBtn");
const crawlSourcesMessage = document.getElementById("crawlSourcesMessage");
const crawlSourcesEffective = document.getElementById("crawlSourcesEffective");
const maintenanceEnabled = document.getElementById("maintenanceEnabled");
const maintenanceStartAt = document.getElementById("maintenanceStartAt");
const maintenanceEndAt = document.getElementById("maintenanceEndAt");
const maintenanceStoreAndroid = document.getElementById(
  "maintenanceStoreAndroid"
);
const maintenanceStoreIos = document.getElementById("maintenanceStoreIos");
const saveMaintenanceBtn = document.getElementById("saveMaintenanceBtn");
const maintenanceMessage = document.getElementById("maintenanceMessage");
const maintenanceEffective = document.getElementById("maintenanceEffective");
const pushForm = document.getElementById("pushForm");
const pushScope = document.getElementById("pushScope");
const pushUidRow = document.getElementById("pushUidRow");
const pushUid = document.getElementById("pushUid");
const pushTitleInput = document.getElementById("pushTitle");
const pushInputLang = document.getElementById("pushInputLang");
const pushBodyInput = document.getElementById("pushBody");
const pushDataJson = document.getElementById("pushDataJson");
const pushMessage = document.getElementById("pushMessage");

const storageKey = "adminApiBaseUrl";
apiBaseInput.value = localStorage.getItem(storageKey) || DEFAULT_API_BASE;

apiBaseInput.addEventListener("change", () => {
  const value = apiBaseInput.value.trim();
  if (value) {
    localStorage.setItem(storageKey, value);
  }
});

function setStatus(message) {
  statusMessage.textContent = message;
}

function isAuthError(error) {
  return error && error.message === "auth_error";
}

const translations = {
  en: {
    eyebrow: "News Crawl",
    title: "Admin Console",
    languageLabel: "Language",
    logout: "Log out",
    connectionTitle: "Connection",
    apiBaseLabel: "API Base URL",
    reloadData: "Reload Data",
    corsHint: "Ensure CORS allows this hosting domain to call the server API.",
    loginTitle: "Admin Sign-in",
    emailLabel: "Email",
    passwordLabel: "Password",
    loginAction: "Sign in",
    loginGoogle: "Sign in with Google",
    or: "or",
    metricsTitle: "Metrics",
    navMetrics: "Metrics",
    navNegative: "Negative balances",
    navCrawl: "Crawl",
    navMaintenance: "Maintenance",
    navSources: "Sources",
    navKeywords: "Keywords",
    navTabs: "Tabs",
    navPush: "Push",
    negativeUsersTitle: "Negative Token Balances",
    negativeUsersHint: "Users whose token balance dropped below zero.",
    negativeHeaderUid: "User UID",
    negativeHeaderBalance: "Balance",
    negativeHeaderBanned: "Banned",
    negativeHeaderUpdated: "Updated",
    negativeHeaderAction: "Action",
    noNegativeUsers: "No users with negative balance.",
    banAction: "Ban",
    unbanAction: "Unban",
    banFailed: "Ban update failed: {error}",
    grantTitle: "Grant Tokens",
    uidLabel: "User UID",
    tokensLabel: "Tokens",
    reasonLabel: "Reason (optional)",
    grantAction: "Grant",
    deductAction: "Deduct",
    deductSuccess: "Deducted. New balance: {balance}",
    sourcesTitle: "Sources with Reports",
    sourceHeader: "Source",
    reportsHeader: "Reports",
    blocksHeader: "Blocks",
    deniedHeader: "Denied",
    updatedHeader: "Updated",
    actionHeader: "Action",
    keywordsTitle: "Top Keywords (Subscriptions)",
    rankHeader: "Rank",
    keywordHeader: "Keyword",
    countHeader: "Count",
    idle: "Idle",
    signedOut: "Signed out",
    loading: "Loading admin data...",
    ready: "Ready",
    loadFailed: "Load failed: {error}",
    loginFailed: "Login failed: {error}",
    notAuthorized: "You are not authorized for admin access.",
    grantFailed: "Grant failed: {error}",
    grantSuccess: "Granted. New balance: {balance}",
    invalidGrant: "Enter a valid UID and token amount.",
    noSources: "No reported sources.",
    noKeywords: "No keyword stats.",
    noMetrics: "No metrics available.",
    allow: "Allow",
    deny: "Deny",
    deniedYes: "Yes",
    deniedNo: "No",
    yes: "Yes",
    no: "No",
    metricsPaidTabs: "Paid tabs active",
    metricsActiveUsers: "Active users (last {minutes}m)",
    metricsActiveAuthUsers: "Active logged-in users",
    metricsActiveGuestUsers: "Active guest users",
    metricsUsers: "Users scanned",
    metricsLanguages: "Languages",
    metricsTotalUsers: "Total users",
    metricsTotalDownloads: "Total downloads (tracked)",
    metricsDownloadsBreakdown: "Logged-in: {users} · Guest: {guests}",
    metricsAuthUsers: "Logged-in users",
    metricsGoogleUsers: "Google login users",
    metricsOtherUsers: "Other login users",
    metricsGuestUsers: "Not logged in (guest)",
    unknownLang: "Unknown",
    tabsTitle: "Tab Management",
    tabIndexLabel: "Tab Index (2-6)",
    remainingHoursLabel: "Remaining Hours",
    remainingMinutesLabel: "Remaining Minutes",
    lookupAction: "Lookup",
    setTabAction: "Set Remaining",
    lookupResult: "Active: {active} · Expiry: {expiry} · Remaining: {hours}h",
    lookupMissing: "Enter UID and tab index.",
    setTabMissing: "Enter UID, tab index, and remaining time.",
    setTabSuccess: "Tab expiry updated: {expiry}",
    crawlSourcesTitle: "Crawl Sources",
    crawlSourcesHint: "Only checked sources will be crawled.",
    crawlGoogleNews: "Google News",
    crawlNaver: "Naver",
    crawlGdelt: "GDELT",
    crawlSourcesSave: "Save",
    crawlSourcesSaved: "Saved.",
    crawlSourcesSaveFailed: "Save failed: {error}",
    crawlSourcesEffective: "Effective: {status}",
    maintenanceTitle: "Maintenance Mode",
    maintenanceHint:
      "Schedule a maintenance window. Users will see a blocking notice during the active period.",
    maintenanceEnabledLabel: "Enable Maintenance",
    maintenanceStartLabel: "Start (Local)",
    maintenanceEndLabel: "End (Local)",
    maintenanceStoreAndroidLabel: "Android Store URL",
    maintenanceStoreIosLabel: "iOS Store URL",
    maintenanceSave: "Save",
    maintenanceSaved: "Saved.",
    maintenanceSaveFailed: "Save failed: {error}",
    maintenanceEffective: "Active: {status}",
    pushTitle: "Push Notifications",
    pushHint:
      "Send a manual push to all users (with active tokens) or one specific user.",
    pushTargetLabel: "Target",
    pushTargetAll: "All users",
    pushTargetUser: "Specific user",
    pushTitleLabel: "Title",
    pushInputLangLabel: "Input language",
    pushBodyLabel: "Body",
    pushDataLabel: "Data JSON (optional)",
    pushSendAction: "Send Push",
    pushInvalid: "Enter title/body and target user when required.",
    pushInvalidData: "Data JSON must be a valid object.",
    pushSuccess:
      "Sent: {sent}/{targeted} · Failed: {failed} · Cleaned(stale/invalid): {stale}/{invalid}",
    pushFailed: "Push failed: {error}"
  },
  ko: {
    eyebrow: "뉴스 크롤",
    title: "어드민 콘솔",
    languageLabel: "언어",
    logout: "로그아웃",
    connectionTitle: "연결",
    apiBaseLabel: "API 기본 주소",
    reloadData: "데이터 새로고침",
    corsHint: "이 호스팅 도메인이 서버 API를 호출하도록 CORS를 허용해야 합니다.",
    loginTitle: "관리자 로그인",
    emailLabel: "이메일",
    passwordLabel: "비밀번호",
    loginAction: "로그인",
    loginGoogle: "Google로 로그인",
    or: "또는",
    metricsTitle: "지표",
    navMetrics: "지표",
    navNegative: "음수 잔액",
    navCrawl: "크롤링",
    navMaintenance: "점검",
    navSources: "소스",
    navKeywords: "키워드",
    navTabs: "탭",
    navPush: "푸시",
    negativeUsersTitle: "토큰 음수 사용자",
    negativeUsersHint: "토큰 잔액이 0보다 작은 사용자입니다.",
    negativeHeaderUid: "사용자 UID",
    negativeHeaderBalance: "잔액",
    negativeHeaderBanned: "차단",
    negativeHeaderUpdated: "업데이트",
    negativeHeaderAction: "작업",
    noNegativeUsers: "토큰 음수 사용자가 없습니다.",
    banAction: "차단",
    unbanAction: "해제",
    banFailed: "차단 처리 실패: {error}",
    grantTitle: "토큰 지급",
    uidLabel: "사용자 UID",
    tokensLabel: "토큰",
    reasonLabel: "사유 (선택)",
    grantAction: "지급",
    deductAction: "차감",
    sourcesTitle: "신고 누적 소스",
    sourceHeader: "소스",
    reportsHeader: "신고",
    blocksHeader: "차단",
    deniedHeader: "차단됨",
    updatedHeader: "업데이트",
    actionHeader: "작업",
    keywordsTitle: "구독 키워드 TOP",
    rankHeader: "순위",
    keywordHeader: "키워드",
    countHeader: "구독 수",
    idle: "대기 중",
    signedOut: "로그아웃됨",
    loading: "데이터 불러오는 중...",
    ready: "준비됨",
    loadFailed: "불러오기 실패: {error}",
    loginFailed: "로그인 실패: {error}",
    notAuthorized: "관리자 권한이 없습니다.",
    grantFailed: "지급 실패: {error}",
    grantSuccess: "지급 완료. 새 잔액: {balance}",
    invalidGrant: "UID와 토큰 수량을 확인하세요.",
    noSources: "신고된 소스가 없습니다.",
    noKeywords: "키워드 통계가 없습니다.",
    noMetrics: "지표가 없습니다.",
    allow: "허용",
    deny: "차단",
    deniedYes: "예",
    deniedNo: "아니오",
    yes: "예",
    no: "아니오",
    metricsPaidTabs: "유료 탭 활성 수",
    metricsActiveUsers: "현재 접속 중 (최근 {minutes}분)",
    metricsActiveAuthUsers: "현재 접속(로그인)",
    metricsActiveGuestUsers: "현재 접속(게스트)",
    metricsUsers: "사용자 집계",
    metricsLanguages: "언어",
    metricsTotalUsers: "전체 사용자",
    metricsTotalDownloads: "총 다운로드(추정)",
    metricsDownloadsBreakdown: "로그인: {users} · 게스트: {guests}",
    metricsAuthUsers: "로그인 사용자",
    metricsGoogleUsers: "구글 로그인",
    metricsOtherUsers: "기타 로그인",
    metricsGuestUsers: "로그인 안함(게스트)",
    unknownLang: "미설정",
    tabsTitle: "탭 관리",
    tabIndexLabel: "탭 번호 (2-6)",
    remainingHoursLabel: "잔여 시간(시간)",
    remainingMinutesLabel: "잔여 시간(분)",
    lookupAction: "조회",
    setTabAction: "잔여시간 설정",
    deductSuccess: "차감 완료. 새 잔액: {balance}",
    lookupResult: "활성: {active} · 만료: {expiry} · 남은시간: {hours}h",
    lookupMissing: "조회할 UID/탭 번호를 입력하세요.",
    setTabMissing: "UID/탭 번호/잔여 시간을 입력하세요.",
    setTabSuccess: "탭 만료시간 설정 완료: {expiry}",
    crawlSourcesTitle: "크롤링 소스",
    crawlSourcesHint: "체크된 소스만 크롤링합니다.",
    crawlGoogleNews: "구글 뉴스",
    crawlNaver: "네이버",
    crawlGdelt: "GDELT",
    crawlSourcesSave: "저장",
    crawlSourcesSaved: "저장했습니다.",
    crawlSourcesSaveFailed: "저장 실패: {error}",
    crawlSourcesEffective: "적용됨: {status}",
    maintenanceTitle: "서버 점검",
    maintenanceHint:
      "점검 시간을 설정하면 해당 시간 동안 앱이 점검 화면으로 전환됩니다.",
    maintenanceEnabledLabel: "점검 모드 활성화",
    maintenanceStartLabel: "시작 (로컬 시간)",
    maintenanceEndLabel: "종료 (로컬 시간)",
    maintenanceStoreAndroidLabel: "안드로이드 스토어 URL",
    maintenanceStoreIosLabel: "iOS 스토어 URL",
    maintenanceSave: "저장",
    maintenanceSaved: "저장했습니다.",
    maintenanceSaveFailed: "저장 실패: {error}",
    maintenanceEffective: "현재 상태: {status}",
    pushTitle: "푸시 알림 발송",
    pushHint:
      "활성 토큰이 있는 전체 사용자 또는 특정 사용자에게 수동 푸시를 보냅니다.",
    pushTargetLabel: "대상",
    pushTargetAll: "전체 사용자",
    pushTargetUser: "특정 사용자",
    pushTitleLabel: "제목",
    pushInputLangLabel: "작성 언어",
    pushBodyLabel: "본문",
    pushDataLabel: "데이터 JSON (선택)",
    pushSendAction: "푸시 발송",
    pushInvalid: "제목/본문과 필요한 대상 정보를 입력하세요.",
    pushInvalidData: "데이터 JSON은 객체 형식이어야 합니다.",
    pushSuccess:
      "발송: {sent}/{targeted} · 실패: {failed} · 정리(만료/무효): {stale}/{invalid}",
    pushFailed: "푸시 발송 실패: {error}"
  }
};

function getLanguage() {
  const stored = localStorage.getItem("adminLang");
  if (stored === "ko" || stored === "en") return stored;
  return (navigator.language || "en").toLowerCase().startsWith("ko")
    ? "ko"
    : "en";
}

function setLanguage(lang) {
  const normalized = lang === "ko" ? "ko" : "en";
  localStorage.setItem("adminLang", normalized);
  languageSelect.value = normalized;
  applyTranslations();
}

function t(key, vars) {
  const lang = localStorage.getItem("adminLang") || "en";
  const table = translations[lang] || translations.en;
  let value = table[key] || translations.en[key] || key;
  if (vars) {
    Object.entries(vars).forEach(([token, replacement]) => {
      value = value.replaceAll(`{${token}}`, String(replacement));
    });
  }
  return value;
}

function applyTranslations() {
  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.getAttribute("data-i18n");
    if (!key) return;
    node.textContent = t(key);
  });
  setStatus(t("idle"));
}

async function getIdToken() {
  const user = auth.currentUser;
  if (!user) throw new Error("not_signed_in");
  return user.getIdToken();
}

function apiBase() {
  return apiBaseInput.value.trim().replace(/\/$/, "");
}

async function apiGet(path) {
  const token = await getIdToken();
  const response = await fetch(`${apiBase()}${path}`, {
    headers: {
      Authorization: `Bearer ${token}`
    }
  });
  const data = await response.json().catch(() => ({}));
  if (response.status === 401 || response.status === 403) {
    if (response.status === 403) {
      loginMessage.textContent = t("notAuthorized");
      setStatus(t("notAuthorized"));
    }
    await signOut(auth);
    throw new Error("auth_error");
  }
  if (!response.ok) {
    throw new Error(data.error || "request_failed");
  }
  return data;
}

async function apiPost(path, body) {
  const token = await getIdToken();
  const response = await fetch(`${apiBase()}${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`
    },
    body: JSON.stringify(body || {})
  });
  const data = await response.json().catch(() => ({}));
  if (response.status === 401 || response.status === 403) {
    if (response.status === 403) {
      loginMessage.textContent = t("notAuthorized");
      setStatus(t("notAuthorized"));
    }
    await signOut(auth);
    throw new Error("auth_error");
  }
  if (!response.ok) {
    throw new Error(data.error || "request_failed");
  }
  return data;
}

function renderSources(items) {
  sourcesBody.innerHTML = "";
  if (!items.length) {
    sourcesBody.innerHTML =
      `<tr><td colspan="6">${t("noSources")}</td></tr>`;
    return;
  }
  items.forEach((item) => {
    const tr = document.createElement("tr");
    const denied = item.denied === true;
    tr.innerHTML = `
      <td>${item.sourceKey || item.id}</td>
      <td>${item.reportCount || 0}</td>
      <td>${item.blockCount || 0}</td>
      <td>${denied ? t("deniedYes") : t("deniedNo")}</td>
      <td>${item.updatedAt ? new Date(item.updatedAt).toLocaleString() : ""}</td>
      <td>
        <button class="btn ghost" data-key="${item.sourceKey || ""}" data-denied="${denied}">
          ${denied ? t("allow") : t("deny")}
        </button>
      </td>
    `;
    const button = tr.querySelector("button");
    if (button) {
      button.addEventListener("click", async () => {
        try {
          button.disabled = true;
          await apiPost("/admin/sources/deny", {
            sourceKey: item.sourceKey,
            denied: !denied
          });
          await loadAll();
        } catch (error) {
          setStatus(`Source update failed: ${error.message}`);
        } finally {
          button.disabled = false;
        }
      });
    }
    sourcesBody.appendChild(tr);
  });
}

function renderKeywords(items) {
  keywordsBody.innerHTML = "";
  if (!items.length) {
    keywordsBody.innerHTML =
      `<tr><td colspan="3">${t("noKeywords")}</td></tr>`;
    return;
  }
  items.forEach((item, index) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td>${index + 1}</td>
      <td>${item.canonical || item.keyword || item.id}</td>
      <td>${item.count || 0}</td>
    `;
    keywordsBody.appendChild(tr);
  });
}

function renderNegativeUsers(items) {
  negativeUsersBody.innerHTML = "";
  negativeUsersMessage.textContent = "";
  if (!items.length) {
    negativeUsersBody.innerHTML =
      `<tr><td colspan="5">${t("noNegativeUsers")}</td></tr>`;
    return;
  }
  items.forEach((item) => {
    const uid = item.uid || item.id || "";
    const balance = Number.parseInt(item.tokenBalance, 10) || 0;
    const banned = item.banned === true;
    const updatedAt = item.updatedAt
      ? new Date(item.updatedAt).toLocaleString()
      : "";
    const tr = document.createElement("tr");
    tr.innerHTML = `
      <td class="mono">${uid}</td>
      <td class="${balance < 0 ? "balance-negative" : ""}">${balance}</td>
      <td>${banned ? t("yes") : t("no")}</td>
      <td>${updatedAt}</td>
      <td>
        <button class="btn ${banned ? "ghost" : "danger"}" data-uid="${uid}">
          ${banned ? t("unbanAction") : t("banAction")}
        </button>
      </td>
    `;
    const button = tr.querySelector("button");
    if (button) {
      button.addEventListener("click", async () => {
        button.disabled = true;
        negativeUsersMessage.textContent = "";
        try {
          await apiPost("/admin/users/ban", {
            uid,
            banned: !banned,
            reason: banned ? "admin_unban" : "negative_balance"
          });
          await loadAll();
        } catch (error) {
          if (isAuthError(error)) return;
          negativeUsersMessage.textContent = t("banFailed", {
            error: error.message
          });
        } finally {
          button.disabled = false;
        }
      });
    }
    negativeUsersBody.appendChild(tr);
  });
}

function renderMetrics(metrics) {
  if (!metrics) {
    metricsContainer.textContent = t("noMetrics");
    return;
  }
  const activeMinutes = metrics.activeWindowMinutes || 10;
  const tile = (label, value, sub) => {
    const safeValue = Number.isFinite(Number(value)) ? value : 0;
    const safeSub = sub ? `<div class="metric-sub">${sub}</div>` : "";
    return `
      <div class="metric-tile">
        <div class="metric-k">${label}</div>
        <div class="metric-v">${safeValue}</div>
        ${safeSub}
      </div>
    `;
  };

  const tiles = [];
  tiles.push(
    tile(
      t("metricsActiveUsers", { minutes: activeMinutes }),
      metrics.activeUsers || 0,
      `${t("metricsActiveAuthUsers")}: ${metrics.activeAuthUsers || 0} · ${t(
        "metricsActiveGuestUsers"
      )}: ${metrics.activeGuestUsers || 0}`
    )
  );
  tiles.push(
    tile(
      t("metricsTotalDownloads"),
      metrics.trackedDownloads || 0,
      t("metricsDownloadsBreakdown", {
        users: metrics.scanned || 0,
        guests: metrics.guestUsers || 0
      })
    )
  );
  tiles.push(
    tile(
      t("metricsTotalUsers"),
      metrics.totalUsers || 0,
      `${t("metricsAuthUsers")}: ${metrics.authTotal || 0} · ${t(
        "metricsGuestUsers"
      )}: ${metrics.guestUsers || 0}`
    )
  );
  tiles.push(tile(t("metricsPaidTabs"), metrics.paidTabsCount || 0));
  tiles.push(
    tile(
      t("metricsUsers"),
      metrics.scanned || 0,
      `${t("metricsGoogleUsers")}: ${metrics.googleUsers || 0} · ${t(
        "metricsOtherUsers"
      )}: ${metrics.nonGoogleUsers || 0}`
    )
  );

  const langEntries = Object.entries(metrics.languageCounts || {});
  let langHtml = `<div class="chip-row"><span class="chip">-</span></div>`;
  if (langEntries.length) {
    const sorted = langEntries.sort((a, b) => b[1] - a[1]);
    const chips = sorted
      .map(([lang, count]) => {
        const label = lang === "unknown" ? t("unknownLang") : lang;
        return `<span class="chip"><strong>${label}</strong> <span class="chip-count">${count}</span></span>`;
      })
      .join("");
    langHtml = `<div class="chip-row">${chips}</div>`;
  }
  metricsContainer.innerHTML = `
    <div class="metric-grid">${tiles.join("")}</div>
    <div class="metric-lang">
      <div class="metric-k">${t("metricsLanguages")}</div>
      ${langHtml}
    </div>
  `;
}

function renderCrawlSources(payload) {
  if (!payload) return;
  const sources = payload.sources || {};
  const effective = payload.effective || {};
  toggleGoogleNews.checked = sources.googleNews !== false;
  toggleNaver.checked = sources.naver !== false;
  toggleGdelt.checked = sources.gdelt !== false;

  const status = [
    `${t("crawlGoogleNews")} ${effective.googleNews ? t("yes") : t("no")}`,
    `${t("crawlNaver")} ${effective.naver ? t("yes") : t("no")}`,
    `${t("crawlGdelt")} ${effective.gdelt ? t("yes") : t("no")}`
  ].join(" · ");
  crawlSourcesEffective.textContent = t("crawlSourcesEffective", { status });
}

function toLocalInputValue(isoString) {
  if (!isoString) return "";
  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) return "";
  const offsetMs = date.getTimezoneOffset() * 60000;
  return new Date(date.getTime() - offsetMs).toISOString().slice(0, 16);
}

function fromLocalInputValue(value) {
  const trimmed = (value || "").trim();
  if (!trimmed) return null;
  const date = new Date(trimmed);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString();
}

function renderMaintenance(payload) {
  if (!payload) return;
  const config = payload.config || payload.maintenance || {};
  const status = payload.status || {};
  maintenanceEnabled.checked = config.enabled === true;
  maintenanceStartAt.value = toLocalInputValue(config.startAt);
  maintenanceEndAt.value = toLocalInputValue(config.endAt);
  maintenanceStoreAndroid.value = config.storeUrlAndroid || "";
  maintenanceStoreIos.value = config.storeUrlIos || "";
  const statusLabel = status.active ? t("yes") : t("no");
  maintenanceEffective.textContent = t("maintenanceEffective", {
    status: statusLabel
  });
}

function updatePushTargetUi() {
  const isUser = pushScope.value === "user";
  pushUidRow.hidden = !isUser;
  pushUid.required = isUser;
  if (!isUser) {
    pushUid.value = "";
  }
}

function parsePushDataInput() {
  const raw = (pushDataJson.value || "").trim();
  if (!raw) return {};
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (_) {
    throw new Error("invalid_data_json");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("invalid_data_json");
  }
  return parsed;
}

async function loadAll() {
  setStatus(t("loading"));
  reloadBtn.disabled = true;
  try {
    const [
      reportedSources,
      keywords,
      metrics,
      negativeUsers,
      crawlSources,
      maintenance
    ] = await Promise.all([
      apiGet("/admin/sources?limit=200"),
      apiGet("/admin/keywords?limit=100"),
      apiGet("/admin/metrics"),
      apiGet("/admin/users/negative?limit=200"),
      apiGet("/admin/crawl-sources"),
      apiGet("/admin/maintenance")
    ]);
    renderSources(reportedSources.items || []);
    renderKeywords(keywords.items || []);
    renderMetrics(metrics.metrics || null);
    renderNegativeUsers(negativeUsers.items || []);
    renderCrawlSources(crawlSources);
    renderMaintenance(maintenance);
    setStatus(t("ready"));
  } catch (error) {
    if (isAuthError(error)) return;
    setStatus(t("loadFailed", { error: error.message }));
  } finally {
    reloadBtn.disabled = false;
  }
}

loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  loginMessage.textContent = "";
  const email = document.getElementById("loginEmail").value.trim();
  const password = document.getElementById("loginPassword").value;
  if (!email || !password) return;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) {
    loginMessage.textContent = t("loginFailed", { error: error.message });
  }
});

googleLoginBtn.addEventListener("click", async () => {
  loginMessage.textContent = "";
  const provider = new GoogleAuthProvider();
  try {
    await signInWithPopup(auth, provider);
  } catch (error) {
    loginMessage.textContent = t("loginFailed", { error: error.message });
  }
});

logoutBtn.addEventListener("click", async () => {
  await signOut(auth);
});

reloadBtn.addEventListener("click", () => {
  loadAll();
});

saveCrawlSourcesBtn.addEventListener("click", async () => {
  crawlSourcesMessage.textContent = "";
  saveCrawlSourcesBtn.disabled = true;
  try {
    const payload = await apiPost("/admin/crawl-sources", {
      sources: {
        googleNews: toggleGoogleNews.checked,
        naver: toggleNaver.checked,
        gdelt: toggleGdelt.checked
      }
    });
    renderCrawlSources(payload);
    crawlSourcesMessage.textContent = t("crawlSourcesSaved");
  } catch (error) {
    if (isAuthError(error)) return;
    crawlSourcesMessage.textContent = t("crawlSourcesSaveFailed", {
      error: error.message
    });
  } finally {
    saveCrawlSourcesBtn.disabled = false;
  }
});

saveMaintenanceBtn.addEventListener("click", async () => {
  maintenanceMessage.textContent = "";
  saveMaintenanceBtn.disabled = true;
  try {
    const payload = await apiPost("/admin/maintenance", {
      enabled: maintenanceEnabled.checked,
      startAt: fromLocalInputValue(maintenanceStartAt.value),
      endAt: fromLocalInputValue(maintenanceEndAt.value),
      storeUrlAndroid: maintenanceStoreAndroid.value.trim(),
      storeUrlIos: maintenanceStoreIos.value.trim()
    });
    renderMaintenance(payload);
    maintenanceMessage.textContent = t("maintenanceSaved");
  } catch (error) {
    if (isAuthError(error)) return;
    maintenanceMessage.textContent = t("maintenanceSaveFailed", {
      error: error.message
    });
  } finally {
    saveMaintenanceBtn.disabled = false;
  }
});

grantForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  grantMessage.textContent = "";
  const uid = document.getElementById("grantUid").value.trim();
  const tokens = Number.parseInt(
    document.getElementById("grantTokens").value,
    10
  );
  const reason = document.getElementById("grantReason").value.trim();
  if (!uid || !Number.isFinite(tokens) || tokens <= 0) {
    grantMessage.textContent = t("invalidGrant");
    return;
  }
  try {
    const result = await apiPost("/admin/tokens/grant", {
      uid,
      tokens,
      reason
    });
    grantMessage.textContent = t("grantSuccess", {
      balance: result.tokenBalance
    });
  } catch (error) {
    if (isAuthError(error)) return;
    grantMessage.textContent = t("grantFailed", { error: error.message });
  }
});

deductForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  deductMessage.textContent = "";
  const uid = document.getElementById("deductUid").value.trim();
  const tokens = Number.parseInt(
    document.getElementById("deductTokens").value,
    10
  );
  const reason = document.getElementById("deductReason").value.trim();
  if (!uid || !Number.isFinite(tokens) || tokens <= 0) {
    deductMessage.textContent = t("invalidGrant");
    return;
  }
  try {
    const result = await apiPost("/admin/tokens/deduct", {
      uid,
      tokens,
      reason
    });
    deductMessage.textContent = t("deductSuccess", {
      balance: result.tokenBalance
    });
  } catch (error) {
    if (isAuthError(error)) return;
    deductMessage.textContent = t("grantFailed", { error: error.message });
  }
});

tabLookupForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  tabLookupMessage.textContent = "";
  const uid = document.getElementById("tabLookupUid").value.trim();
  const tabIndex = Number.parseInt(
    document.getElementById("tabLookupIndex").value,
    10
  );
  if (!uid || !Number.isFinite(tabIndex)) {
    tabLookupMessage.textContent = t("lookupMissing");
    return;
  }
  try {
    const result = await apiGet(
      `/admin/tabs/status?uid=${encodeURIComponent(uid)}&tabIndex=${tabIndex}`
    );
    const active = result.active ? t("yes") : t("no");
    const expiry = result.expiry || "-";
    const hours = result.remainingHours || 0;
    tabLookupMessage.textContent = t("lookupResult", {
      active,
      expiry,
      hours
    });
  } catch (error) {
    if (isAuthError(error)) return;
    tabLookupMessage.textContent = t("loadFailed", { error: error.message });
  }
});

tabSetForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  tabSetMessage.textContent = "";
  const uid = document.getElementById("tabSetUid").value.trim();
  const tabIndex = Number.parseInt(
    document.getElementById("tabSetIndex").value,
    10
  );
  const remainingHours = Number(document.getElementById("tabSetHours").value);
  const remainingMinutes = Number(
    document.getElementById("tabSetMinutes").value
  );
  const hasHours = Number.isFinite(remainingHours) && remainingHours > 0;
  const hasMinutes =
    Number.isFinite(remainingMinutes) && remainingMinutes > 0;
  if (!uid || !Number.isFinite(tabIndex) || (!hasHours && !hasMinutes)) {
    tabSetMessage.textContent = t("setTabMissing");
    return;
  }
  try {
    const payload = { uid, tabIndex };
    if (hasMinutes) {
      payload.remainingMinutes = Math.floor(remainingMinutes);
    } else if (hasHours) {
      payload.remainingHours = Math.floor(remainingHours);
    }
    const result = await apiPost("/admin/tabs/set", payload);
    tabSetMessage.textContent = t("setTabSuccess", {
      expiry: result.expiresAt || "-"
    });
  } catch (error) {
    if (isAuthError(error)) return;
    tabSetMessage.textContent = t("loadFailed", { error: error.message });
  }
});

pushScope.addEventListener("change", () => {
  updatePushTargetUi();
});

pushForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  pushMessage.textContent = "";
  const scope = pushScope.value === "user" ? "user" : "all";
  const uid = pushUid.value.trim();
  const title = pushTitleInput.value.trim();
  const inputLang = (pushInputLang.value || "en").trim();
  const body = pushBodyInput.value.trim();
  if (!title || !body || (scope === "user" && !uid)) {
    pushMessage.textContent = t("pushInvalid");
    return;
  }
  let data = {};
  try {
    data = parsePushDataInput();
  } catch (error) {
    pushMessage.textContent = t("pushInvalidData");
    return;
  }
  try {
    const result = await apiPost("/admin/push/send", {
      scope,
      uid,
      title,
      body,
      inputLang,
      data
    });
    pushMessage.textContent = t("pushSuccess", {
      sent: result.sent || 0,
      targeted: result.targeted || 0,
      failed: result.failed || 0,
      stale: result.cleanedStale || 0,
      invalid: result.cleanedInvalid || 0
    });
  } catch (error) {
    if (isAuthError(error)) return;
    pushMessage.textContent = t("pushFailed", { error: error.message });
  }
});

onAuthStateChanged(auth, (user) => {
  if (user) {
    sessionEmail.textContent = user.email || user.uid;
    loginCard.hidden = true;
    dashboard.hidden = false;
    logoutBtn.hidden = false;
    reloadBtn.disabled = false;
    loadAll();
  } else {
    sessionEmail.textContent = "";
    loginCard.hidden = false;
    dashboard.hidden = true;
    logoutBtn.hidden = true;
    reloadBtn.disabled = true;
    setStatus(loginMessage.textContent || t("signedOut"));
  }
});

languageSelect.addEventListener("change", () => {
  setLanguage(languageSelect.value);
  renderSources([]);
  renderKeywords([]);
  renderMetrics(null);
  renderNegativeUsers([]);
  if (auth.currentUser) {
    loadAll();
  }
});

setLanguage(getLanguage());
updatePushTargetUi();
