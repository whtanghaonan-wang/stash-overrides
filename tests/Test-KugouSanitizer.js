const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const scriptPath = path.join(__dirname, "..", "kugou-sanitize-ads.js");
const source = fs.readFileSync(scriptPath, "utf8");

function sanitize(body, url = "http://adserviceretry.kglink.cn/v4/mobile_splash_sort") {
  let result;
  const context = {
    $request: { url },
    $response: { body: JSON.stringify(body) },
    $done: (value) => {
      result = value;
    },
    console,
  };

  vm.runInNewContext(source, context);
  return JSON.parse(result.body);
}

const input = {
  code: 0,
  status: 1,
  data: {
    boot_ads: [{ id: 1 }],
    front_ads: [{ id: 2 }],
    least_ads: [{ id: 3 }],
    splash_ads: [{ id: 4 }],
    ads: [{ id: 5 }],
    retry_ads: [{ id: 8 }],
    retry_local_ads: [{ id: 9 }],
    fail_process: 1,
    popup: { title: "promotion" },
    normal_config: { enabled: true },
    nested: {
      ad_info: [{ id: 6 }],
      ordinary_list: [{ id: 7 }],
    },
  },
};

const output = sanitize(input);

assert.equal(output.code, 0);
assert.equal(output.status, 1);
assert.deepEqual(output.data.boot_ads, []);
assert.deepEqual(output.data.front_ads, []);
assert.deepEqual(output.data.least_ads, []);
assert.deepEqual(output.data.splash_ads, []);
assert.deepEqual(output.data.ads, []);
assert.deepEqual(output.data.retry_ads, []);
assert.deepEqual(output.data.retry_local_ads, []);
assert.equal(output.data.fail_process, 0);
assert.equal(output.data.popup, null);
assert.deepEqual(output.data.nested.ad_info, []);
assert.equal(output.data.normal_config.enabled, true);
assert.equal(output.data.nested.ordinary_list[0].id, 7);

const roomList = sanitize(
  { code: 0, data: { rooms: [{ id: 1 }], title: "keep" } },
  "http://acshow2.kugou.com/mfx-kugoulive/room/list",
);
assert.deepEqual(roomList.data.rooms, []);
assert.equal(roomList.data.title, "keep");

const gateway = sanitize(
  { code: 0, data: { addrs: [{ host: "120.232.67.73", port: 8080 }], open: 1 } },
  "http://service3.fanxing.kugou.com/video/mo/gateway/api/config",
);
assert.deepEqual(gateway.data.addrs, []);
assert.equal(gateway.data.open, 0);

console.log("Kugou sanitizer checks passed");
