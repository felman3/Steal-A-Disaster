#!/usr/bin/env node
// Generates the 512x512 PNG icons for the Game Passes / Developer Products
// (assets/icons/*.png). No dependencies: shapes are rasterized with 4x4
// supersampling and encoded with Node's zlib.
//   node tools/make-icons.js

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const SIZE = 512;
const SS = 4; // supersamples per axis

// ---------- geometry helpers (all coords in 0..512 space) ----------
const inCircle = (cx, cy, r) => (x, y) => (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
const inEllipse = (cx, cy, rx, ry) => (x, y) => ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1;
const inRect = (x0, y0, x1, y1) => (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
function inRoundRect(x0, y0, x1, y1, r) {
  return (x, y) => {
    if (x < x0 || x > x1 || y < y0 || y > y1) return false;
    const cx = Math.min(Math.max(x, x0 + r), x1 - r);
    const cy = Math.min(Math.max(y, y0 + r), y1 - r);
    return (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
  };
}
function inPoly(pts) {
  return (x, y) => {
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [xi, yi] = pts[i];
      const [xj, yj] = pts[j];
      if (yi > y !== yj > y && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  };
}
// grow a shape test by `w` (outline) by sampling a ring of offsets
function outline(test, w) {
  const offs = [];
  for (let a = 0; a < 16; a++) offs.push([Math.cos((a / 16) * Math.PI * 2) * w, Math.sin((a / 16) * Math.PI * 2) * w]);
  return (x, y) => test(x, y) || offs.some(([dx, dy]) => test(x + dx, y + dy));
}

// ---------- rendering ----------
// layers: [{ test(x,y) -> bool, color: [r,g,b] | (x,y) => [r,g,b] }], painted in order
function render(layers) {
  const px = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const fx = x + (sx + 0.5) / SS;
          const fy = y + (sy + 0.5) / SS;
          let col = null;
          for (const L of layers) {
            if (L.test(fx, fy)) col = typeof L.color === "function" ? L.color(fx, fy) : L.color;
          }
          if (col) {
            r += col[0]; g += col[1]; b += col[2]; a += 255;
          }
        }
      }
      const n = SS * SS;
      const i = (y * SIZE + x) * 4;
      const cov = a / n;
      // un-premultiply so edges keep their colour
      px[i] = cov ? Math.round((r / n) * (255 / cov)) : 0;
      px[i + 1] = cov ? Math.round((g / n) * (255 / cov)) : 0;
      px[i + 2] = cov ? Math.round((b / n) * (255 / cov)) : 0;
      px[i + 3] = Math.round(cov);
    }
  }
  return px;
}

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(px) {
  const raw = Buffer.alloc((SIZE * 4 + 1) * SIZE);
  for (let y = 0; y < SIZE; y++) {
    raw[y * (SIZE * 4 + 1)] = 0;
    px.copy(raw, y * (SIZE * 4 + 1) + 1, y * SIZE * 4, (y + 1) * SIZE * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(SIZE, 0);
  ihdr.writeUInt32BE(SIZE, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", ihdr),
    chunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

// ---------- shared pieces ----------
const INK = [22, 20, 34];
const WHITE = [255, 255, 255];
const vgrad = (top, bottom) => (x, y) => top.map((t, k) => Math.round(t + (bottom[k] - t) * (y / SIZE)));
function background(top, bottom) {
  const card = inRoundRect(16, 16, 496, 496, 96);
  return [
    { test: card, color: INK },
    { test: inRoundRect(30, 30, 482, 482, 84), color: vgrad(top, bottom) },
    // soft highlight band
    { test: (x, y) => inRoundRect(30, 30, 482, 482, 84)(x, y) && y < 150 && inEllipse(256, 40, 300, 120)(x, y), color: (x, y) => vgrad(top, bottom)(x, y).map((c) => Math.min(255, c + 28)) },
  ];
}
// a filled shape with a thick dark outline
const bold = (test, color, w = 14) => [
  { test: outline(test, w), color: INK },
  { test, color },
];
const bolt = (dx = 0, dy = 0, s = 1) =>
  inPoly([[300, 70], [150, 280], [245, 280], [200, 440], [365, 210], [268, 210], [320, 70]].map(([x, y]) => [256 + (x - 256) * s + dx, 256 + (y - 256) * s + dy]));

// ---------- icons ----------
const ICONS = {
  // orange: a treadmill belt with a big lightning bolt and speed streaks
  TurboTreadmill: () => [
    ...background([255, 176, 60], [235, 100, 20]),
    ...bold(inRoundRect(70, 360, 442, 420, 28), [60, 60, 70]),
    { test: (x, y) => inRoundRect(70, 360, 442, 420, 28)(x, y) && Math.floor((x - 70) / 40) % 2 === 0 && y > 372 && y < 408, color: [255, 220, 60] },
    ...bold(inRect(80, 150, 200, 172), WHITE, 10),
    ...bold(inRect(60, 215, 170, 237), WHITE, 10),
    ...bold(bolt(30, -40, 0.95), [255, 236, 90]),
  ],
  // green: two big gold coins, "x2" feel via a second coin behind
  DoubleCash: () => [
    ...background([110, 225, 110], [30, 150, 70]),
    ...bold(inCircle(200, 210, 120), [240, 180, 30]),
    { test: inCircle(200, 210, 84), color: [255, 214, 60] },
    ...bold(inCircle(318, 310, 130), [240, 180, 30]),
    { test: inCircle(318, 310, 94), color: [255, 214, 60] },
    // embossed bars on the front coin
    { test: inRoundRect(300, 235, 336, 385, 14), color: [215, 150, 20] },
    { test: inRoundRect(270, 268, 366, 292, 10), color: [215, 150, 20] },
    { test: inRoundRect(270, 328, 366, 352, 10), color: [215, 150, 20] },
  ],
  // purple: an egg cracking open with a glow
  InstantHatch: () => [
    ...background([190, 120, 255], [110, 50, 200]),
    { test: inCircle(256, 270, 190), color: (x, y) => [210, 160, 255] },
    ...bold(inEllipse(256, 290, 125, 165), [255, 248, 230]),
    { test: inEllipse(220, 230, 34, 50), color: WHITE },
    // zigzag crack
    { test: inPoly([[140, 250], [190, 220], [225, 262], [265, 215], [300, 258], [340, 222], [372, 250], [372, 268], [340, 242], [300, 280], [265, 236], [225, 284], [190, 242], [140, 270]]), color: INK },
    ...bold(inPoly([[400, 60], [420, 110], [470, 120], [425, 140], [430, 190], [400, 155], [368, 190], [375, 140], [330, 120], [380, 110]]), [255, 236, 90], 8),
  ],
  // blue: a big lightning bolt with a clock tick (temporary)
  SpeedBoost: () => [
    ...background([90, 190, 255], [30, 100, 230]),
    ...bold(inCircle(370, 380, 82), WHITE, 12),
    { test: inRect(364, 330, 376, 386), color: INK },
    { test: inRect(364, 374, 410, 386), color: INK },
    ...bold(bolt(-30, -20, 1.05), [255, 236, 90]),
  ],
  // green: a stack of banknotes
  CashPack: () => {
    const note = (dy, rot) => {
      const c = Math.cos(rot), s = Math.sin(rot);
      const pts = [[-170, -80], [170, -80], [170, 80], [-170, 80]].map(([x, y]) => [256 + x * c - y * s, 300 + dy + x * s + y * c]);
      return inPoly(pts);
    };
    return [
      ...background([120, 230, 120], [40, 160, 80]),
      ...bold(note(40, 0.12), [70, 170, 90]),
      ...bold(note(0, -0.08), [90, 200, 110]),
      ...bold(note(-50, 0.04), [140, 230, 140]),
      { test: inCircle(256, 248, 50), color: [70, 170, 90] },
      { test: inCircle(256, 248, 34), color: [140, 230, 140] },
      { test: inRoundRect(246, 222, 266, 274, 6), color: [50, 130, 70] },
    ];
  },
};

const outDir = path.join(__dirname, "..", "assets", "icons");
fs.mkdirSync(outDir, { recursive: true });
for (const [name, build] of Object.entries(ICONS)) {
  const file = path.join(outDir, name + ".png");
  fs.writeFileSync(file, png(render(build())));
  console.log("wrote", path.relative(process.cwd(), file));
}
