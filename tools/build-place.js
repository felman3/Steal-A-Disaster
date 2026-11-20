#!/usr/bin/env node
// Builds build/StealADisaster.rbxlx from src/ using the same mapping as
// default.project.json (Rojo conventions):
//   folder            -> Folder
//   name.server.lua   -> Script
//   name.client.lua   -> LocalScript
//   name.lua          -> ModuleScript
// Open the .rbxlx in Roblox Studio and press Play. (If you use Rojo, run
// `rojo serve` instead — the project file is equivalent.)

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const OUT_DIR = path.join(ROOT, "build");
const OUT = path.join(OUT_DIR, "StealADisaster.rbxlx");

let ref = 0;
const nextRef = () => "RBX" + (ref++).toString(16).toUpperCase().padStart(8, "0");

const esc = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
const cdata = (s) => "<![CDATA[" + String(s).split("]]>").join("]]]]><![CDATA[>") + "]]>";

function item(className, props, children = []) {
  const p = props
    .map(([type, name, value]) => {
      if (type === "ProtectedString") return `<ProtectedString name="${name}">${cdata(value)}</ProtectedString>`;
      return `<${type} name="${name}">${esc(value)}</${type}>`;
    })
    .join("");
  return `<Item class="${className}" referent="${nextRef()}"><Properties>${p}</Properties>${children.join("")}</Item>`;
}

function scriptItem(file, name) {
  const source = fs.readFileSync(file, "utf8");
  if (file.endsWith(".server.lua")) {
    return item("Script", [["string", "Name", name], ["bool", "Disabled", "false"], ["token", "RunContext", "0"], ["ProtectedString", "Source", source]]);
  }
  if (file.endsWith(".client.lua")) {
    return item("LocalScript", [["string", "Name", name], ["bool", "Disabled", "false"], ["ProtectedString", "Source", source]]);
  }
  return item("ModuleScript", [["string", "Name", name], ["ProtectedString", "Source", source]]);
}

let counts = { Script: 0, LocalScript: 0, ModuleScript: 0, Folder: 0 };

function dirItems(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir).sort()) {
    const full = path.join(dir, entry);
    if (fs.statSync(full).isDirectory()) {
      counts.Folder++;
      out.push(item("Folder", [["string", "Name", entry]], dirItems(full)));
    } else if (entry.endsWith(".lua")) {
      const name = entry.replace(/\.(server|client)\.lua$/, "").replace(/\.lua$/, "");
      if (entry.endsWith(".server.lua")) counts.Script++;
      else if (entry.endsWith(".client.lua")) counts.LocalScript++;
      else counts.ModuleScript++;
      out.push(scriptItem(full, name));
    }
  }
  return out;
}

function folder(name, dir) {
  counts.Folder++;
  return item("Folder", [["string", "Name", name]], dirItems(path.join(ROOT, dir)));
}

const xml = [
  '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
  "<External>null</External><External>nil</External>",
  item("Workspace", [["string", "Name", "Workspace"], ["bool", "StreamingEnabled", "false"], ["float", "Gravity", "196.2"]]),
  item("Lighting", [
    ["string", "Name", "Lighting"],
    ["token", "Technology", "4"], // Future
    ["float", "Brightness", "2.4"],
    ["float", "ClockTime", "14.2"],
    ["bool", "GlobalShadows", "true"],
  ]),
  item("ReplicatedStorage", [["string", "Name", "ReplicatedStorage"]], [folder("Shared", "src/shared")]),
  item("ServerScriptService", [["string", "Name", "ServerScriptService"]], [folder("Server", "src/server")]),
  item("StarterPlayer", [["string", "Name", "StarterPlayer"]], [
    item("StarterPlayerScripts", [["string", "Name", "StarterPlayerScripts"]], [folder("Client", "src/client")]),
  ]),
  item("Players", [["string", "Name", "Players"], ["int", "MaxPlayers", "8"]]),
  "</roblox>",
].join("\n");

fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(OUT, xml);
// a copy at the repo root so a plain "Download ZIP" from GitHub includes a ready-to-open place
fs.writeFileSync(path.join(ROOT, "StealADisaster.rbxlx"), xml);
console.log(
  `built ${path.relative(ROOT, OUT)} — ${counts.ModuleScript} modules, ${counts.Script} server scripts, ${counts.LocalScript} local scripts, ${counts.Folder} folders (${(xml.length / 1024).toFixed(0)} KB)`
);
