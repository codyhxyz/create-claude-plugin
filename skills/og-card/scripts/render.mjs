#!/usr/bin/env node
// render.mjs — reads marketing/og.config.mjs from a target plugin, fills the
// SVG template, rasterizes to assets/og.png. Invoked by render.sh which
// handles the one-time @resvg/resvg-js install.
//
// usage: node render.mjs <path/to/og.config.mjs>
//        (output lands at <config-dir>/../assets/og.png)

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname, join } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = dirname(scriptDir);

const configArg = process.argv[2];
if (!configArg) {
  console.error("usage: render.mjs <path/to/og.config.mjs>");
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

// ---- Fill the template --------------------------------------------------
const tmplPath = join(skillDir, "templates", `default-${theme}.svg`);
const tmpl = readFileSync(tmplPath, "utf8");

// Two-pass replace: triple-brace is raw (value is pre-escaped SVG), double-brace is XML-escaped.
let svg = tmpl.replace(/{{{(\w+)}}}/g, (_m, key) => {
  if (!(key in vars)) throw new Error(`template references unknown raw key: {{{${key}}}}`);
  return vars[key];
});
svg = svg.replace(/{{(\w+)}}/g, (_m, key) => {
  if (!(key in vars)) throw new Error(`template references unknown key: {{${key}}}`);
  return escapeXml(vars[key]);
});

// ---- Rasterize ----------------------------------------------------------
let Resvg;
try {
  ({ Resvg } = await import("@resvg/resvg-js"));
} catch (err) {
  console.error("og-card: @resvg/resvg-js not installed. Run scripts/render.sh instead of calling render.mjs directly (the shell wrapper handles the one-time install).");
  process.exit(1);
}

const resvg = new Resvg(svg, {
  fitTo: { mode: "width", value: 1200 },
  background: vars.bg,
  font: {
    // Let resvg fall back to system fonts if a named family isn't found.
    // On macOS this picks up Helvetica Neue; on Linux it picks up DejaVu.
    loadSystemFonts: true,
    defaultFontFamily: "Inter",
  },
});

const png = resvg.render().asPng();

const outPath = resolve(dirname(configPath), "..", "assets", "og.png");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, png);

console.log(`og-card: wrote ${outPath} (${png.length} bytes)`);
