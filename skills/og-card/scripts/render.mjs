#!/usr/bin/env node
// render.mjs — reads marketing/og.config.mjs from a target plugin, fills the
// SVG template, rasterizes to assets/og.png. Invoked by render.sh which
// handles the one-time @resvg/resvg-js install.
//
// usage: node render.mjs <path/to/og.config.mjs> [--video]
//        (output lands at <config-dir>/../assets/og.png)
//
// --video also writes assets/og.mp4: a silent H.264 loop for og:video. The
// template is animated by a phase in [0, 1); every animated value is periodic
// and equals the static card at phase 0, so og.png is frame 0 (the poster)
// and the last frame flows back into the first with no cut.

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from "node:fs";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { resolve, dirname, join } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = dirname(scriptDir);

const args = process.argv.slice(2);
const wantVideo = args.includes("--video");
const configArg = args.find((a) => !a.startsWith("--"));
if (!configArg) {
  console.error("usage: render.mjs <path/to/og.config.mjs> [--video]");
  process.exit(2);
}

const configPath = resolve(configArg);
if (!existsSync(configPath)) {
  console.error(`og-card: config not found at ${configPath}`);
  process.exit(2);
}

const { default: config } = await import(pathToFileURL(configPath).href);

// ---- Validate: reject placeholder strings up front ----------------------
const PLACEHOLDER = /PLACEHOLDER|YOUR_TAGLINE|YOUR_SUBTITLE|PLUGIN_NAME_PLACEHOLDER|CATEGORY_PLACEHOLDER|OWNER\/REPO/;
for (const [k, v] of Object.entries(config)) {
  if (typeof v === "string" && PLACEHOLDER.test(v)) {
    console.error(`og-card: ${k} still contains a template placeholder (${JSON.stringify(v)}). Edit marketing/og.config.mjs before rendering.`);
    process.exit(1);
  }
}

// ---- Theme defaults -----------------------------------------------------
const THEMES = {
  light: { bg: "#FFFFFF", fg: "#0A0A0A", muted: "#6B7280" },
  dark:  { bg: "#0B1020", fg: "#F8FAFC", muted: "#94A3B8" },
};
const theme = config.theme === "dark" ? "dark" : "light";
const defaults = THEMES[theme];

const escapeXml = (s) => String(s)
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&apos;");

// Word-wrap helper — caps subtitle at 2 lines, truncates overflow with ellipsis.
function wrapSubtitle(text, maxCharsPerLine = 62, maxLines = 2) {
  const words = String(text).split(/\s+/).filter(Boolean);
  const lines = [];
  let current = "";
  for (const word of words) {
    if (!current) { current = word; continue; }
    if ((current + " " + word).length <= maxCharsPerLine) {
      current += " " + word;
    } else {
      lines.push(current);
      current = word;
      if (lines.length >= maxLines) break;
    }
  }
  if (current && lines.length < maxLines) lines.push(current);
  if (lines.length === maxLines && words.join(" ").length > lines.join(" ").length) {
    const last = lines[maxLines - 1];
    lines[maxLines - 1] = last.length > maxCharsPerLine - 1
      ? last.slice(0, maxCharsPerLine - 1) + "…"
      : last + "…";
  }
  return lines.length ? lines : [""];
}

const vars = {
  bg:     config.bg     ?? defaults.bg,
  fg:     config.fg     ?? defaults.fg,
  muted:  config.muted  ?? defaults.muted,
  accent: config.accent ?? "#5B7CFA",
  name:         config.name         ?? "",
  label:        (config.label       ?? "").toUpperCase(),
  taglineLine1: config.taglineLine1 ?? "",
  taglineLine2: config.taglineLine2 ?? "",
  footer:       config.footer       ?? "",
};

// Pre-computed raw SVG fragment for the subtitle — emitted via {{{subtitleTspans}}}
// which bypasses XML escaping (triple-brace mustache convention).
const subtitleLines = wrapSubtitle(config.subtitle ?? "");
vars.subtitleTspans = subtitleLines
  .map((line, i) => `<tspan x="80" dy="${i === 0 ? 0 : 40}">${escapeXml(line)}</tspan>`)
  .join("");

// ---- Animation ----------------------------------------------------------
// Each value is a function of phase p in [0, 1) and equals its static value at
// p = 0. sin/cos of 2πp keep the loop seamless; "pulse" is 0 at both ends so
// the shimmer and sweep are invisible on the poster frame.
function motion(p) {
  const a = 2 * Math.PI * p;
  const pulse = (1 - Math.cos(a)) / 2;
  return {
    glowCx: (85 + 6 * Math.sin(a)).toFixed(3),
    glowCy: (20 + 5 * Math.sin(2 * a)).toFixed(3),
    glowOpacity: (0.35 + 0.08 * Math.sin(a)).toFixed(4),
    shimmerY: (-160 + 950 * p).toFixed(2),
    shimmerOpacity: (0.55 * pulse).toFixed(4),
    sweepX: (80 + 1040 * p - 120).toFixed(2),
    sweepOpacity: (0.9 * pulse).toFixed(4),
  };
}

// ---- Fill the template --------------------------------------------------
const tmplPath = join(skillDir, "templates", `default-${theme}.svg`);
const tmpl = readFileSync(tmplPath, "utf8");

// Two-pass replace: triple-brace is raw (value is pre-escaped SVG), double-brace is XML-escaped.
function svgAt(phase) {
  const v = { ...vars, ...motion(phase) };
  let svg = tmpl.replace(/{{{(\w+)}}}/g, (_m, key) => {
    if (!(key in v)) throw new Error(`template references unknown raw key: {{{${key}}}}`);
    return v[key];
  });
  return svg.replace(/{{(\w+)}}/g, (_m, key) => {
    if (!(key in v)) throw new Error(`template references unknown key: {{${key}}}`);
    return escapeXml(v[key]);
  });
}

// ---- Rasterize ----------------------------------------------------------
let Resvg;
try {
  ({ Resvg } = await import("@resvg/resvg-js"));
} catch (err) {
  console.error("og-card: @resvg/resvg-js not installed. Run scripts/render.sh instead of calling render.mjs directly (the shell wrapper handles the one-time install).");
  process.exit(1);
}

const rasterize = (phase) => new Resvg(svgAt(phase), {
  fitTo: { mode: "width", value: 1200 },
  background: vars.bg,
  font: {
    // Let resvg fall back to system fonts if a named family isn't found.
    // On macOS this picks up Helvetica Neue; on Linux it picks up DejaVu.
    loadSystemFonts: true,
    defaultFontFamily: "Inter",
  },
}).render();

const png = rasterize(0).asPng();

const outPath = resolve(dirname(configPath), "..", "assets", "og.png");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, png);

console.log(`og-card: wrote ${outPath} (${png.length} bytes)`);

if (!wantVideo) process.exit(0);

// ---- Video --------------------------------------------------------------
// Encoding follows what Messages, Discord and Telegram play inline: silent
// H.264 High, yuv420p, BT.709, moov atom first (+faststart).
const VIDEO_BUDGET = 2.5 * 1024 * 1024;
const seconds = config.video?.seconds ?? 4;
const fps = config.video?.fps ?? 30;
const frames = Math.round(seconds * fps);

const first = rasterize(0);
if (!rasterize(1).pixels.equals(first.pixels)) {
  console.error("og-card: animation does not return to frame 0 at the end of the loop; every motion() value must be periodic.");
  process.exit(1);
}

const videoPath = resolve(dirname(outPath), "og.mp4");
const ffmpeg = spawn("ffmpeg", [
  "-y", "-loglevel", "error",
  "-f", "rawvideo", "-pix_fmt", "rgba", "-s", `${first.width}x${first.height}`, "-r", String(fps), "-i", "-",
  "-an", "-c:v", "libx264", "-profile:v", "high", "-preset", "veryslow", "-crf", "28",
  "-pix_fmt", "yuv420p", "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709",
  "-movflags", "+faststart", videoPath,
], { stdio: ["pipe", "inherit", "inherit"] });
ffmpeg.on("error", (err) => {
  console.error(err.code === "ENOENT"
    ? "og-card: --video needs ffmpeg on PATH (macOS: brew install ffmpeg)."
    : `og-card: ffmpeg failed to start: ${err.message}`);
  process.exit(1);
});

for (let i = 0; i < frames; i++) {
  const frame = i === 0 ? first : rasterize(i / frames);
  if (!ffmpeg.stdin.write(frame.pixels)) await once(ffmpeg.stdin, "drain");
}
ffmpeg.stdin.end();
const [code] = await once(ffmpeg, "close");
if (code !== 0) {
  console.error(`og-card: ffmpeg exited with ${code}`);
  process.exit(1);
}

const videoBytes = statSync(videoPath).size;
if (videoBytes > VIDEO_BUDGET) {
  console.error(`og-card: ${videoPath} is ${videoBytes} bytes, over the ${VIDEO_BUDGET}-byte budget. Shorten video.seconds or lower video.fps.`);
  process.exit(1);
}
console.log(`og-card: wrote ${videoPath} (${videoBytes} bytes, ${frames} frames at ${fps} fps, loops to frame 0)`);
