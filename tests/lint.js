#!/usr/bin/env node
// Static checks for every .lua file under src/:
//  1. Compiles in Lua 5.4 (wasmoon) — guarantees the Luau/Lua5.4 common subset.
//  2. No undefined globals (luaparse scope analysis against an allowlist of
//     Lua + Roblox globals). Catches typos like `Vector3.nwe` -> no, but catches
//     `Vectr3`, forgotten `local`, and accidental global writes.
//  3. Forbidden patterns: bare `unpack(`, `wait(` / `spawn(` / `delay(` (use task.*).

const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { LuaFactory } = require("wasmoon");

const ROOT = path.resolve(__dirname, "..");
const SRC = path.join(ROOT, "src");

const ALLOWED = new Set([
  // Lua
  "assert", "error", "getmetatable", "ipairs", "next", "pairs", "pcall", "print", "rawequal", "rawget", "rawlen",
  "rawset", "select", "setmetatable", "tonumber", "tostring", "type", "xpcall", "_G", "_VERSION", "math", "string",
  "table", "coroutine", "os", "debug", "utf8", "require",
  // Roblox
  "game", "workspace", "script", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim", "UDim2", "Enum",
  "NumberRange", "NumberSequence", "NumberSequenceKeypoint", "ColorSequence", "ColorSequenceKeypoint", "TweenInfo",
  "PhysicalProperties", "Rect", "Ray", "RaycastParams", "OverlapParams", "BrickColor", "Font", "Random", "typeof",
  "task", "warn", "tick", "time", "shared", "DateTime", "buffer",
]);

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir)) {
    const full = path.join(dir, e);
    if (fs.statSync(full).isDirectory()) walk(full, out);
    else if (e.endsWith(".lua")) out.push(full);
  }
  return out;
}

function globalsUsed(src) {
  const issues = [];
  const ast = luaparse.parse(src, { luaVersion: "5.3", scope: true, locations: true });
  const visit = (node) => {
    if (!node || typeof node !== "object") return;
    if (Array.isArray(node)) {
      node.forEach(visit);
      return;
    }
    if (node.type === "Identifier" && node.isLocal === false && !ALLOWED.has(node.name)) {
      issues.push(`${node.loc.start.line}: global '${node.name}'`);
    }
    for (const key of Object.keys(node)) {
      if (key === "loc" || key === "range") continue;
      // `a.b` / `a:b` member names and `{ key = v }` keys are not variable references
      if (node.type === "MemberExpression" && key === "identifier") continue;
      if (node.type === "TableKeyString" && key === "key") continue;
      visit(node[key]);
    }
  };
  visit(ast);
  return [...new Set(issues)];
}

(async () => {
  const files = walk(SRC);
  const factory = new LuaFactory();
  let problems = 0;
  for (const file of files) {
    const rel = path.relative(ROOT, file);
    const src = fs.readFileSync(file, "utf8");
    const lua = await factory.createEngine();
    lua.global.set("SRC", src);
    lua.global.set("CHUNK", "@" + rel);
    const err = await lua.doString("local f, e = load(SRC, CHUNK, 't') return e or ''");
    lua.global.close();
    if (err) {
      problems++;
      console.log(`✗ ${rel}: syntax: ${err}`);
      continue;
    }
    let globals = [];
    try {
      globals = globalsUsed(src);
    } catch (e) {
      problems++;
      console.log(`✗ ${rel}: luaparse: ${e.message}`);
      continue;
    }
    for (const g of globals) {
      problems++;
      console.log(`✗ ${rel}:${g}`);
    }
    const lines = src.split("\n");
    lines.forEach((line, i) => {
      const code = line.replace(/--.*$/, "");
      if (/(^|[^.\w:])unpack\(/.test(code)) {
        problems++;
        console.log(`✗ ${rel}:${i + 1}: use table.unpack`);
      }
      if (/(^|[^.\w:])(wait|spawn|delay)\(/.test(code)) {
        problems++;
        console.log(`✗ ${rel}:${i + 1}: use task.wait/task.spawn/task.delay`);
      }
    });
  }
  console.log(problems === 0 ? `lint ok — ${files.length} files` : `\n${problems} problem(s) in ${files.length} files`);
  process.exit(problems === 0 ? 0 : 1);
})();
