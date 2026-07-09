const blockedNames = new Set(["AI帮唱", "长相思2", "K歌", "小说", "游戏"]);

function clean(value) {
  if (Array.isArray(value)) {
    return value
      .map(clean)
      .filter((item) => !(item && typeof item === "object" && blockedNames.has(item.name)));
  }

  if (value && typeof value === "object") {
    for (const key of Object.keys(value)) {
      const child = value[key];
      if (child && typeof child === "object" && blockedNames.has(child.name)) {
        delete value[key];
      } else {
        value[key] = clean(child);
      }
    }
  }

  return value;
}

try {
  const body = $response.body || "";
  const data = JSON.parse(body);
  $done({ body: JSON.stringify(clean(data)) });
} catch (error) {
  $done({});
}
