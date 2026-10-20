const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const key = "test-only-lumarush-backend-key-32-bytes";
function loadModule(name, overrides = {}) {
  const context = vm.createContext({});
  const source = fs.readFileSync(path.join(__dirname, "../modules", name), "utf8");
  vm.runInContext(source, context, { filename: name });
  const env = {
    GAME_ID: "lumarush",
    TPX_GAME_ID: "lumarush",
    PLATFORM_IDENTITY_URL: "https://identity.test",
    TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL: "https://identity.test/v1/auth/nakama",
    TPX_NAKAMA_EXCHANGE_KEY: key,
    ...overrides,
  };
  context.MODULE_CONFIG = context.loadConfig({ env });
  const calls = [];
  const nk = {
    httpRequest(url, method, headers, body) {
      calls.push({ url, method, headers, body: JSON.parse(body) });
      return { code: 200, body: JSON.stringify({ session_token: "platform-test-session" }) };
    },
  };
  return { context, calls, nk };
}

for (const name of ["index.js", "lumarush.js"]) {
  test(`${name}: refuses missing/invalid authenticated context before HTTP`, () => {
    const { context, calls, nk } = loadModule(name);
    for (const ctx of [undefined, {}, { userId: "" }, { userId: " " }, { userId: 42 }]) {
      assert.throws(() => context.exchangePlatformSession(ctx, nk), /User session is required/);
    }
    assert.equal(calls.length, 0);
  });

  test(`${name}: fails closed without dedicated credential or configured game`, () => {
    for (const badKey of ["", "short", "invalid-key-with-newline\n", " ".repeat(40)]) {
      const { context, calls, nk } = loadModule(name, { TPX_NAKAMA_EXCHANGE_KEY: badKey, TPX_PLATFORM_INTERNAL_KEY: key, PLATFORM_INTERNAL_KEY: key, TPX_PLATFORM_API_KEY: key });
      assert.throws(() => context.exchangePlatformSession({ userId: "caller" }, nk), /TPX_NAKAMA_EXCHANGE_KEY/);
      assert.equal(calls.length, 0);
    }
    const { context, calls, nk } = loadModule(name);
    context.MODULE_CONFIG.gameId = "";
    assert.throws(() => context.exchangePlatformSession({ userId: "caller" }, nk), /server game ID/);
    assert.equal(calls.length, 0);
  });

  test(`${name}: exchanges authenticated user under server game and dedicated header`, () => {
    const { context, calls, nk } = loadModule(name);
    const session = context.exchangePlatformSession({ userId: "caller", username: "Player", game_id: "other-game", nakama_user_id: "victim", env: { TPX_NAKAMA_EXCHANGE_KEY: "request-key", TPX_GAME_ID: "other-game" } }, nk);
    assert.equal(session, "platform-test-session");
    assert.equal(calls.length, 1);
    assert.equal(calls[0].url, "https://identity.test/v1/auth/nakama");
    assert.equal(calls[0].body.game_id, "lumarush");
    assert.equal(calls[0].body.nakama_user_id, "caller");
    assert.equal(calls[0].headers["x-nakama-exchange-key"], key);
    assert.equal(calls[0].headers["x-admin-key"], undefined);
    assert.equal(calls[0].headers.Authorization, undefined);
    assert.equal(JSON.stringify(calls[0].body).includes(key), false);
  });

  test(`${name}: dedicated credential is not attached to other platform requests`, () => {
    const { context, calls, nk } = loadModule(name);
    if (name === "lumarush.js") {
      context.platformPost(nk, "https://platform.test/unrelated", {}, "", "session");
    } else {
      context.httpPost(nk, "https://platform.test/unrelated", {}, {}, "session");
    }
    assert.equal(calls[0].headers["x-nakama-exchange-key"], undefined);
  });

  test(`${name}: does not return sessions on platform rejection`, () => {
    const { context, nk } = loadModule(name);
    nk.httpRequest = () => ({ code: 401, body: "{}" });
    assert.throws(() => context.exchangePlatformSession({ userId: "caller" }, nk), /exchange failed/);
  });
}

test("template RPC ignores payload-selected user/game/credential and requires authentication", () => {
  const { context, calls, nk } = loadModule("index.js");
  const payload = JSON.stringify({ nakama_user_id: "victim", game_id: "other-game", backendKey: "request-key", TPX_NAKAMA_EXCHANGE_KEY: "request-key" });
  for (const ctx of [undefined, {}, { userId: " " }, { userId: 42 }]) {
    assert.throws(() => context.rpcPlatformAuthExchange(ctx, {}, nk, payload), /User session is required/);
  }
  assert.equal(calls.length, 0);
  context.rpcPlatformAuthExchange({ userId: "caller", username: "Player" }, {}, nk, payload);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].body.nakama_user_id, "caller");
  assert.equal(calls[0].body.game_id, "lumarush");
  assert.equal(calls[0].headers["x-nakama-exchange-key"], key);
});

test("checked-in local and container startup select the tested LumaRush module", () => {
  const local = fs.readFileSync(path.join(__dirname, "../local.yml"), "utf8");
  const startup = fs.readFileSync(path.join(__dirname, "../render/start.sh"), "utf8");
  assert.match(local, /js_entrypoint: "lumarush\.js"/);
  assert.match(startup, /js_entrypoint: "lumarush\.js"/);
  assert.match(startup, /TPX_NAKAMA_EXCHANGE_KEY=\$\{RUNTIME_ENV_TPX_NAKAMA_EXCHANGE_KEY\}/);
});

test("template RPC refuses missing dedicated credential before HTTP", () => {
  const { context, calls, nk } = loadModule("index.js", { TPX_NAKAMA_EXCHANGE_KEY: "" });
  assert.throws(() => context.rpcPlatformAuthExchange({ userId: "caller" }, {}, nk, "{}"), /TPX_NAKAMA_EXCHANGE_KEY/);
  assert.equal(calls.length, 0);
});

test("module initialization independently registers the expected entrypoint RPCs", () => {
  for (const name of ["index.js", "lumarush.js"]) {
    const { context, nk } = loadModule(name);
    const registered = new Map();
    const initializer = new Proxy({}, {
      get(_target, property) {
        if (property === "registerRpc") return (id, handler) => {
          assert.equal(registered.has(id), false, `duplicate RPC ${id} in ${name}`);
          registered.set(id, handler);
        };
        return () => {};
      },
    });
    nk.leaderboardCreate = () => {};
    const logger = { info() {} };
    context.InitModule({ env: {
      GAME_ID: "lumarush", TPX_GAME_ID: "lumarush",
      TPX_NAKAMA_EXCHANGE_KEY: key,
      PLATFORM_IDENTITY_URL: "https://identity.test",
      TPX_PLATFORM_IDENTITY_NAKAMA_AUTH_URL: "https://identity.test/v1/auth/nakama",
    } }, logger, nk, initializer);
    assert.equal(registered.has("platform_auth_exchange"), name === "index.js");
    assert.equal(registered.has("tpx_account_magic_link_start"), true);
    assert.equal(context.exchangePlatformSession({ userId: "caller" }, nk), "platform-test-session");
  }
});
