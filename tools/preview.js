#!/usr/bin/env node
// HEADLESS MOCK PREVIEW (not Roblox Studio!). Boots the real server code in the
// test harness, populates two bases, dumps every visible part and renders
// approximate views with three.js in headless Chromium. Materials, lighting,
// particles and GUIs are NOT represented — this is only for checking layout,
// silhouettes, scale and composition. Real visual verification needs Studio.
//
//   node tools/preview.js            -> build/preview/*.png
//   node tools/preview.js zone 4     -> only views whose name contains "zone 4"

const fs = require("fs");
const path = require("path");
const { LuaFactory } = require("wasmoon");
const { chromium } = require("playwright");

const ROOT = path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "build", "preview");

const DUMP_LUA = `
local HOST = {
  readFile = HOST_readFile,
  listDir = function(p) local out = {} for n in string.gmatch(HOST_listDir(p), "[^\\n]+") do table.insert(out, n) end return out end,
  isDir = HOST_isDir, root = HOST_root,
}
local function loadFile(p, ...)
  local chunk, err = load(HOST.readFile(p), "@" .. p, "t", _ENV)
  if not chunk then error(err) end
  return chunk(...)
end
local Env = loadFile(HOST.root .. "/tests/harness/env.lua", HOST)
local env = Env.new({ mode = "server" })
env.runScript("ServerScriptService.Server.Main")
env.advance(0.5)
local S = env.G.StealADisaster
local a = env.addPlayer("Alice")
local b = env.addPlayer("Bob")
env.advance(1)
local da = S.PlayerDataService:get(a)
da.upgrades.Pods = 6
da.upgrades.Pedestals = 12
da.upgrades.Treadmill = 12
da.upgrades.Carry = 3
local Config = env.require("ReplicatedStorage.Shared.Config.GameConfig")
local ids = {}
for id in pairs(Config.Disasters) do table.insert(ids, id) end
table.sort(ids)
S.BaseService:refresh(a)
for i = 1, 12 do
  local d = ids[(i * 3) % #ids + 1]
  S.DisasterCollectionService:place(a, { c = Config.CoreByDisaster[d], m = (i % 4 == 0) and "Golden" or nil, z = 1, p = 999 })
end
for _, c in ipairs({ "TornadoCore", "BlizzardCore", "MeteorCore", "BlackHoleCore", "ChaosCore" }) do
  S.IncubatorService:receive(a, { c = c, z = 1, p = 5 })
end
S.IncubatorService:receive(b, { c = "GustCore", z = 1 })
S.DisasterCollectionService:place(b, { c = "HailCore", z = 1, p = 999 })
env.advance(1)
if #env.errors > 0 then error(table.concat(env.errors, "\\n")) end
local out = {}
local function f(x) return string.format("%.3f", x) end
for _, d in ipairs(env.G.workspace:GetDescendants()) do
  if d:IsA("BasePart") and d.Transparency < 0.98 and d.Name ~= "HumanoidRootPart" then
    local shape = "Block"
    if d.ClassName == "WedgePart" then shape = "Wedge"
    elseif d.ClassName == "CornerWedgePart" then shape = "CornerWedge"
    elseif d.ClassName == "Part" then shape = d.Shape.Name end
    local c = d.CFrame
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
    -- account for Model:ScaleTo used on collectibles
    local scale = 1
    local m = d:FindFirstAncestorOfClass("Model")
    local s = d.Size
    table.insert(out, table.concat({ shape, f(x), f(y), f(z), f(r00), f(r01), f(r02), f(r10), f(r11), f(r12), f(r20), f(r21), f(r22),
      f(s.X), f(s.Y), f(s.Z), f(d.Color.R), f(d.Color.G), f(d.Color.B), f(d.Transparency), d.Material.Name, d:GetFullName() }, ","))
  end
end
return table.concat(out, "\\n")
`;

const VIEWS = [
  { name: "hub overview", eye: [0, 230, -330], target: [0, 0, 20] },
  { name: "base close", eye: [-40, 45, -150], target: [-118, 4, -150] },
  { name: "base pedestals", eye: [-88, 18, -132], target: [-112, 4, -150] },
  { name: "route aerial", eye: [260, 520, 900], target: [0, 0, 1300] },
];
for (let i = 1; i <= 9; i++) {
  const z0 = 200 + (i - 1) * 260;
  VIEWS.push({ name: `zone ${i} gate`, eye: [0, 16, z0 - 30], target: [0, 8, z0 + 140] });
  VIEWS.push({ name: `zone ${i} aerial`, eye: [120, 150, z0 - 40], target: [0, 0, z0 + 150] });
}

(async () => {
  // custom view: node tools/preview.js --eye x,y,z --target x,y,z --name label
  const args = process.argv.slice(2);
  const ei = args.indexOf("--eye");
  if (ei >= 0) {
    const ti = args.indexOf("--target");
    const ni = args.indexOf("--name");
    VIEWS.length = 0;
    VIEWS.push({ name: ni >= 0 ? args[ni + 1] : "custom", eye: args[ei + 1].split(",").map(Number), target: args[ti + 1].split(",").map(Number) });
  }
  const filter = ei >= 0 ? "" : args.join(" ");
  const lua = await new LuaFactory().createEngine();
  lua.global.set("HOST_readFile", (p) => fs.readFileSync(p, "utf8"));
  lua.global.set("HOST_listDir", (p) => fs.readdirSync(p).sort().join("\n"));
  lua.global.set("HOST_isDir", (p) => fs.statSync(p).isDirectory());
  lua.global.set("HOST_root", ROOT);
  const dump = await lua.doString(DUMP_LUA);
  lua.global.close();
  const parts = String(dump).split("\n").filter(Boolean);
  console.log(`dumped ${parts.length} visible parts`);

  fs.mkdirSync(OUT, { recursive: true });
  const three = fs.readFileSync(path.join(ROOT, "node_modules/three/build/three.min.js"), "utf8");
  const html = `<!doctype html><html><body style="margin:0;background:#9cc6ff"><script>${three}</script><script>
  const W = 1280, H = 720;
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setSize(W, H);
  renderer.shadowMap.enabled = true;
  document.body.appendChild(renderer.domElement);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x9cc6ff);
  scene.fog = new THREE.Fog(0x9cc6ff, 600, 2600);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x556070, 0.75));
  const sun = new THREE.DirectionalLight(0xffffff, 0.75);
  sun.position.set(300, 600, -200);
  scene.add(sun);
  const box = new THREE.BoxGeometry(1, 1, 1);
  const ball = new THREE.SphereGeometry(0.5, 18, 12);
  const cyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 20); cyl.rotateZ(Math.PI / 2);
  function wedgeGeom() {
    // Roblox WedgePart: full height at +Z (back), slope down to the -Z front edge at the bottom
    const g = new THREE.BufferGeometry();
    const v = [
      [-0.5,-0.5,-0.5],[0.5,-0.5,-0.5],[0.5,-0.5,0.5],[-0.5,-0.5,0.5],[-0.5,0.5,0.5],[0.5,0.5,0.5]
    ];
    const tris = [[0,2,1],[0,3,2],[3,4,5],[3,5,2],[0,1,5],[0,5,4],[0,4,3],[1,2,5]];
    const pos = [];
    tris.forEach(t => t.forEach(i => pos.push(...v[i])));
    g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
    g.computeVertexNormals();
    return g;
  }
  const wedge = wedgeGeom();
  const mats = new Map();
  function mat(r, g, b, t, m) {
    const key = [r, g, b, t, m].join("|");
    if (mats.has(key)) return mats.get(key);
    const color = new THREE.Color(r, g, b);
    let opacity = 1 - t;
    if (m === "Glass") opacity = Math.min(opacity, 0.55);
    if (m === "ForceField") opacity = Math.min(opacity, 0.3);
    const mm = new THREE.MeshLambertMaterial({ color, transparent: opacity < 0.99, opacity });
    if (m === "Neon") { mm.emissive = color; mm.emissiveIntensity = 0.9; }
    mats.set(key, mm);
    return mm;
  }
  window.loadParts = (lines) => {
    for (const line of lines) {
      const p = line.split(",");
      const shape = p[0];
      const n = p.slice(1, 20).map(Number);
      const geom = shape === "Ball" ? ball : shape === "Cylinder" ? cyl : (shape === "Wedge" || shape === "CornerWedge") ? wedge : box;
      const mesh = new THREE.Mesh(geom, mat(n[15], n[16], n[17], n[18], p[20]));
      const m = new THREE.Matrix4();
      m.set(n[3], n[4], n[5], n[0], n[6], n[7], n[8], n[1], n[9], n[10], n[11], n[2], 0, 0, 0, 1);
      let sx = n[12], sy = n[13], sz = n[14];
      if (shape === "Ball") { const d = Math.min(sx, sy, sz); sx = sy = sz = d; }
      if (shape === "Cylinder") { const d = Math.min(sy, sz); sy = sz = d; }
      m.multiply(new THREE.Matrix4().makeScale(sx, sy, sz));
      mesh.matrixAutoUpdate = false;
      mesh.matrix.copy(m);
      scene.add(mesh);
    }
  };
  const camera = new THREE.PerspectiveCamera(60, W / H, 0.5, 5000);
  window.shot = (eye, target) => {
    camera.position.set(eye[0], eye[1], eye[2]);
    camera.lookAt(target[0], target[1], target[2]);
    renderer.render(scene, camera);
    return renderer.domElement.toDataURL("image/png");
  };
  </script></body></html>`;
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.evaluate((lines) => window.loadParts(lines), parts);
  for (const v of VIEWS) {
    if (filter && !v.name.includes(filter)) continue;
    const data = await page.evaluate(([e, t]) => window.shot(e, t), [v.eye, v.target]);
    const file = path.join(OUT, v.name.replace(/\s+/g, "_") + ".png");
    fs.writeFileSync(file, Buffer.from(data.split(",")[1], "base64"));
    console.log("wrote " + path.relative(ROOT, file));
  }
  await browser.close();
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
