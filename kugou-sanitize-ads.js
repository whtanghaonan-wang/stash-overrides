const arrayFields = new Set([
  "ad_info",
  "ad_list",
  "adlist",
  "ads",
  "advertisements",
  "boot_ads",
  "front_ads",
  "least_ads",
  "retry_ads",
  "retry_local_ads",
  "splash",
  "splash_ads",
  "splash_list",
]);

const nullFields = new Set(["popup", "popups"]);
const disabledFields = new Set([
  "ad_enabled",
  "ad_switch",
  "enable_ad",
  "fail_process",
  "show_ad",
  "show_ads",
  "splash_switch",
]);

function clean(value) {
  if (Array.isArray(value)) {
    return value.map(clean);
  }

  if (typeof value === "string") {
    const trimmed = value.trim();
    if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
      try {
        return JSON.stringify(clean(JSON.parse(value)));
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  if (!value || typeof value !== "object") {
    return value;
  }

  for (const key of Object.keys(value)) {
    if (arrayFields.has(key)) {
      value[key] = [];
    } else if (nullFields.has(key)) {
      value[key] = null;
    } else if (disabledFields.has(key)) {
      value[key] = typeof value[key] === "boolean" ? false : 0;
    } else {
      value[key] = clean(value[key]);
    }
  }

  return value;
}

const adOnlyUrl = /\/v\d+\/mobile_splash(?:_sort)?(?:\?|$)|\/(?:adp\/ad|ads\.gateway)\//;

try {
  const url = $request.url;
  const data = clean(JSON.parse($response.body || "{}"));

  if (/\/mfx-kugoulive\/room\/list(?:\?|$)/.test(url)) {
    if (Array.isArray(data.data)) {
      data.data = [];
    } else if (data.data && typeof data.data === "object") {
      for (const key of ["items", "list", "room_list", "rooms"]) {
        if (Array.isArray(data.data[key])) data.data[key] = [];
      }
    }
  }

  if (/\/video\/mo\/gateway\/api\/config(?:\?|$)/.test(url) && data.data) {
    data.data.addrs = [];
    data.data.open = 0;
  }

  $done({ body: JSON.stringify(data) });
} catch (error) {
  const url = typeof $request === "object" && $request ? String($request.url || "") : "";
  console.log(`[kugou-sanitize-ads] sanitize failed for ${url}: ${error}`);
  if (adOnlyUrl.test(url)) {
    // Never pass an unparsed payload through on ad-only endpoints: one leaked
    // response re-caches splash creatives for the next cold start.
    $done({ body: JSON.stringify({ status: 1, error_code: 0, errcode: 0, code: 0, data: {} }) });
  } else {
    $done({});
  }
}
