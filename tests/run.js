#!/usr/bin/env node
// Headless test runner: runs tests/specs/*.spec.lua inside a Lua 5.4 VM
// (wasmoon) with a mock Roblox DataModel (tests/harness).
//
//   node tests/run.js            # all specs
//   node tests/run.js loop       # specs whose filename contains "loop"
//   VERBOSE=1 node tests/run.js  # echo game print/warn output

const fs = require("fs");
const path = require("path");
const { LuaFactory } = require("wasmoon");

const ROOT = path.resolve(__dirname, "..");
const SPEC_DIR = path.join(__dirname, "specs");

async function runSpec(factory, file) {
  const lua = await factory.createEngine({ injectObjects: false, enableProxy: false, traceAllocations: false });
  const host = {
    readFile: (p) => fs.readFileSync(p, "utf8"),
    listDir: (p) => fs.readdirSync(p).sort(),
    isDir: (p) => fs.statSync(p).isDirectory(),
    root: ROOT,
  };
  lua.global.set("HOST_readFile", host.readFile);
  lua.global.set("HOST_listDir", (p) => host.listDir(p).join("\n"));
  lua.global.set("HOST_isDir", host.isDir);
  lua.global.set("HOST_root", ROOT);
  lua.global.set("SPEC_PATH", file);
  lua.global.set("VERBOSE", !!process.env.VERBOSE);
  const boot = `
    local HOST = {
      readFile = HOST_readFile,
      listDir = function(p)
        local s = HOST_listDir(p)
        local out = {}
        for name in string.gmatch(s, "[^\\n]+") do table.insert(out, name) end
        return out
      end,
      isDir = HOST_isDir,
      root = HOST_root,
    }
    local function loadFile(p, ...)
      local chunk, err = load(HOST.readFile(p), "@" .. p:sub(#HOST.root + 2), "t", _ENV)
      if not chunk then error(err) end
      return chunk(...)
    end
    local Env = loadFile(HOST.root .. "/tests/harness/env.lua", HOST)
    local T = loadFile(HOST.root .. "/tests/harness/testlib.lua")
    local specEnv = setmetatable({
      describe = T.describe, it = T.it, expect = T.expect,
      Env = Env, HOST = HOST, VERBOSE = VERBOSE,
    }, { __index = _G })
    local chunk, err = load(HOST.readFile(SPEC_PATH), "@" .. SPEC_PATH:sub(#HOST.root + 2), "t", specEnv)
    if not chunk then
      return "LOADFAIL\\t" .. tostring(err)
    end
    local ok, e = xpcall(chunk, debug.traceback)
    if not ok then
      return "LOADFAIL\\t" .. tostring(e)
    end
    local lines = {}
    for _, r in ipairs(T.results) do
      table.insert(lines, (r.ok and "PASS" or "FAIL") .. "\\t" .. r.name .. "\\t" .. (r.err and tostring(r.err):gsub("\\n", "\\r") or ""))
    end
    return table.concat(lines, "\\n")
  `;
  let out;
  try {
    out = await lua.doString(boot);
  } catch (e) {
    out = "LOADFAIL\t" + String(e && e.message ? e.message : e);
  } finally {
    lua.global.close();
  }
  return String(out || "");
}

(async () => {
  const filter = process.argv[2];
  const files = fs
    .readdirSync(SPEC_DIR)
    .filter((f) => f.endsWith(".spec.lua") && (!filter || f.includes(filter)))
    .sort()
    .map((f) => path.join(SPEC_DIR, f));
  const factory = new LuaFactory();
  let pass = 0;
  let fail = 0;
  for (const file of files) {
    const rel = path.relative(ROOT, file);
    const out = await runSpec(factory, file);
    console.log(`\n# ${rel}`);
    for (const line of out.split("\n").filter(Boolean)) {
      const [status, name, err] = line.split("\t");
      if (status === "LOADFAIL") {
        fail++;
        console.log(`  ✗ failed to load: ${name}`);
        continue;
      }
      if (status === "PASS") {
        pass++;
        console.log(`  ✓ ${name}`);
      } else {
        fail++;
        console.log(`  ✗ ${name}\n      ${String(err || "").replace(/\r/g, "\n      ")}`);
      }
    }
  }
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail > 0 ? 1 : 0);
})();
