#!/usr/bin/env node
// render.mjs — reads marketing/proof-of-value.config.mjs from a target plugin,
// fills the kind-specific SVG template, rasterizes to assets/proof-of-value.png.
// Invoked by render.sh, which handles the one-time @resvg/resvg-js install.
//
// usage: node render.mjs <path/to/proof-of-value.config.mjs>
//        (output lands at <config-dir>/../assets/proof-of-value.png)

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { resolve, dirname, join, extname } from "node:path";
import { pathToFileURL, fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = dirname(scriptDir);

const configArg = process.argv[2];
if (!configArg) {
  console.error("usage: render.mjs <path/to/proof-of-value.config.mjs>");
  process.exit(2);
}

const configPath = resolve(configArg);
if (!existsSync(configPath)) {
  console.error(`proof-of-value: config not found at ${configPath}`);
  process.exit(2);
}

const { default: config } = await import(pathToFileURL(configPath).href);

// ---- Validate: required fields + reject placeholder strings -------------
const KINDS = new Set([
  "visual", "benchmark", "terminal-diff",
  "output-quality", "coverage", "file-tree",
]);
if (!KINDS.has(config.kind)) {
  console.error(`proof-of-value: invalid kind "${config.kind}". Pick one of: ${[...KINDS].join(", ")}`);
  process.exit(1);
}

const PLACEHOLDER = /PLACEHOLDER|PLUGIN_NAME_PLACEHOLDER|KIND_PLACEHOLDER|CAPTION_PLACEHOLDER/;
for (const k of ["kind", "name", "caption"]) {
  const v = config[k];
  if (typeof v === "string" && PLACEHOLDER.test(v)) {
    console.error(`proof-of-value: ${k} still contains a template placeholder (${JSON.stringify(v)}). Edit ${configPath} before rendering.`);
    process.exit(1);
  }
}

// ---- Theme defaults -----------------------------------------------------
const THEMES = {
  light: {
    bg: "#FFFFFF", fg: "#0A0A0A", muted: "#6B7280",
    panelBg: "#F8FAFC", panelHeader: "#EEF2F7", panelStroke: "#E5E7EB",
    codeFg: "#0F172A",
  },
  dark: {
    bg: "#0B1020", fg: "#F8FAFC", muted: "#94A3B8",
    panelBg: "#111A33", panelHeader: "#17223F", panelStroke: "#1E2A4A",
    codeFg: "#E2E8F0",
  },
};
const theme = config.theme === "dark" ? "dark" : "light";
const defaults = THEMES[theme];
const BAR_OK  = "#22C55E";
const BAR_BAD = "#EF4444";

const escapeXml = (s) => String(s)
  .replace(/&/g, "&amp;")
  .replace(/</g, "&lt;")
  .replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;")
  .replace(/'/g, "&apos;");

// Word-wrap helper — returns lines, caps at maxLines (ellipsis on overflow).
function wrapText(text, maxCharsPerLine = 62, maxLines = 12) {
  const rawLines = String(text ?? "").split("\n");
  const out = [];
  for (const raw of rawLines) {
    const words = raw.split(/\s+/).filter(Boolean);
    if (words.length === 0) { out.push(""); continue; }
    let cur = "";
    for (const w of words) {
      if (!cur) { cur = w; continue; }
      if ((cur + " " + w).length <= maxCharsPerLine) cur += " " + w;
      else { out.push(cur); cur = w; if (out.length >= maxLines) break; }
    }
    if (cur && out.length < maxLines) out.push(cur);
    if (out.length >= maxLines) break;
  }
  if (out.length > maxLines) out.length = maxLines;
  return out.length ? out : [""];
}

function preserveLines(text, maxLines = 20, maxChars = 72) {
  const lines = String(text ?? "").split("\n").slice(0, maxLines);
  return lines.map((l) => l.length > maxChars ? l.slice(0, maxChars - 1) + "…" : l);
}

function tspans(lines, x, dy) {
  return lines
    .map((line, i) => `<tspan x="${x}" dy="${i === 0 ? 0 : dy}">${escapeXml(line) || "&#160;"}</tspan>`)
    .join("");
}

function loadImageDataUri(filePath) {
  if (!existsSync(filePath)) {
    console.error(`proof-of-value: image not found at ${filePath}`);
    process.exit(1);
  }
  const ext = extname(filePath).toLowerCase();
  const mime = ext === ".jpg" || ext === ".jpeg" ? "image/jpeg"
    : ext === ".png" ? "image/png"
    : ext === ".webp" ? "image/webp"
    : null;
  if (!mime) {
    console.error(`proof-of-value: unsupported image type "${ext}" at ${filePath} (use .png, .jpg, or .webp)`);
    process.exit(1);
  }
  const bytes = readFileSync(filePath);
  return `data:${mime};base64,${bytes.toString("base64")}`;
}

// ---- Build the kind-specific variables ---------------------------------
const baseVars = {
  bg: config.bg ?? defaults.bg,
  fg: config.fg ?? defaults.fg,
  muted: config.muted ?? defaults.muted,
  panelBg: defaults.panelBg,
  panelHeader: defaults.panelHeader,
  panelStroke: defaults.panelStroke,
  codeFg: defaults.codeFg,
  accent: config.accent ?? "#5B7CFA",
  name: config.name ?? "",
  caption: config.caption ?? "",
};

let templateName;
const vars = { ...baseVars };

switch (config.kind) {
  case "visual": {
    const v = config.visual ?? {};
    const cfgDir = dirname(configPath);
    templateName = "visual.svg";
    vars.beforeLabel = v.beforeLabel ?? "Before";
    vars.afterLabel = v.afterLabel ?? "After";
    vars.beforeImageHref = loadImageDataUri(resolve(cfgDir, v.beforeImage ?? ""));
    vars.afterImageHref  = loadImageDataUri(resolve(cfgDir, v.afterImage  ?? ""));
    break;
  }

  case "terminal-diff": {
    const t = config.terminalDiff ?? {};
    templateName = "terminal-diff.svg";
    vars.beforeLabel = t.beforeLabel ?? "Without";
    vars.afterLabel  = t.afterLabel  ?? "With";
    vars.beforeTspans = tspans(preserveLines(t.before, 18, 56), 110, 30);
    vars.afterTspans  = tspans(preserveLines(t.after,  18, 56), 850, 30);
    break;
  }

  case "output-quality": {
    const o = config.outputQuality ?? {};
    templateName = "output-quality.svg";
    vars.beforeLabel = o.beforeLabel ?? "Raw LLM";
    vars.afterLabel  = o.afterLabel  ?? `With ${config.name ?? "plugin"}`;
    vars.userPrompt  = o.userPrompt ? `» ${o.userPrompt}` : "";
    vars.beforeTspans = tspans(wrapText(o.before, 46, 16), 110, 34);
    vars.afterTspans  = tspans(wrapText(o.after,  46, 16), 850, 34);
    break;
  }

  case "file-tree": {
    const f = config.fileTree ?? {};
    templateName = "file-tree.svg";
    vars.beforeLabel = f.beforeLabel ?? "Before";
    vars.afterLabel  = f.afterLabel  ?? "After";
    vars.beforeTspans = tspans(preserveLines(f.before, 18, 56), 110, 30);
    vars.afterTspans  = tspans(preserveLines(f.after,  18, 56), 850, 30);
    break;
  }

  case "coverage": {
    const c = config.coverage ?? {};
    templateName = "coverage.svg";
    vars.heading = c.heading ?? `What ${config.name ?? "this plugin"} covers`;
    const rows = (c.rows ?? []).slice(0, 12);
    const rowH = rows.length ? Math.min(68, Math.floor(560 / rows.length)) : 68;
    const startY = 210 + 40;
    let out = "";
    rows.forEach((r, i) => {
      const y = startY + i * rowH;
      const iconFill = r.covered ? BAR_OK : BAR_BAD;
      const iconGlyph = r.covered ? "✓" : "✕";
      out += `<circle cx="130" cy="${y - 12}" r="20" fill="${iconFill}"/>`;
      out += `<text x="130" y="${y - 4}" font-family="Inter, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="26" font-weight="700" fill="#FFFFFF" text-anchor="middle">${iconGlyph}</text>`;
      out += `<text x="180" y="${y - 2}" font-family="Inter, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="28" font-weight="500" fill="${baseVars.fg}">${escapeXml(r.label ?? "")}</text>`;
    });
    vars.coverageRows = out;
    break;
  }

  case "benchmark": {
    const b = config.benchmark ?? {};
    templateName = "benchmark.svg";
    const rows = (b.rows ?? []).slice(0, 6);
    if (rows.length === 0) {
      console.error(`proof-of-value: benchmark kind requires at least one row in config.benchmark.rows`);
      process.exit(1);
    }
    const lowerIsBetter = b.lowerIsBetter !== false;
    const unit = b.unit ? ` ${b.unit}` : "";
    const maxVal = Math.max(...rows.flatMap((r) => [Number(r.before) || 0, Number(r.after) || 0]));
    const chartX = 380;
    const chartW = 900;
    const chartTop = 280;
    const chartH = 480;
    const rowH = Math.floor(chartH / rows.length);
    const barH = Math.min(18, Math.floor((rowH - 10) / 2));

    const totalBefore = rows.reduce((a, r) => a + (Number(r.before) || 0), 0);
    const totalAfter  = rows.reduce((a, r) => a + (Number(r.after)  || 0), 0);
    const deltaPct = totalBefore > 0
      ? Math.round(((totalAfter - totalBefore) / totalBefore) * 100)
      : 0;
    const improved = lowerIsBetter ? deltaPct < 0 : deltaPct > 0;
    const signed = deltaPct > 0 ? `+${deltaPct}%` : `${deltaPct}%`;
    vars.heroLine = `${improved ? "▾" : "▴"} ${signed}${unit ? ` ${b.unit}` : ""} · ${rows.length} case${rows.length === 1 ? "" : "s"}`;
    vars.subLine = lowerIsBetter ? "lower is better" : "higher is better";

    let out = "";
    rows.forEach((r, i) => {
      const yTop = chartTop + i * rowH + 20;
      const yMid = yTop + rowH / 2 - 10;
      const before = Number(r.before) || 0;
      const after  = Number(r.after)  || 0;
      const wBefore = maxVal > 0 ? Math.round((before / maxVal) * chartW) : 0;
      const wAfter  = maxVal > 0 ? Math.round((after  / maxVal) * chartW) : 0;
      const rowImproved = lowerIsBetter ? after < before : after > before;
      const afterColor = rowImproved ? BAR_OK : BAR_BAD;
      out += `<text x="340" y="${yMid - 10}" font-family="Inter, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="22" font-weight="600" fill="${baseVars.fg}" text-anchor="end">${escapeXml(r.label ?? "")}</text>`;
      out += `<rect x="${chartX}" y="${yMid - 18}" width="${wBefore}" height="${barH}" rx="4" ry="4" fill="${baseVars.muted}" fill-opacity="0.55"/>`;
      out += `<text x="${chartX + wBefore + 12}" y="${yMid - 6}" font-family="Inter, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="18" font-weight="500" fill="${baseVars.muted}">${before.toLocaleString()}${unit}</text>`;
      out += `<rect x="${chartX}" y="${yMid + 4}" width="${wAfter}" height="${barH}" rx="4" ry="4" fill="${afterColor}"/>`;
      out += `<text x="${chartX + wAfter + 12}" y="${yMid + 16}" font-family="Inter, -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="18" font-weight="600" fill="${afterColor}">${after.toLocaleString()}${unit}</text>`;
    });
    vars.benchmarkRows = out;
    break;
  }
}

// ---- Fill the template --------------------------------------------------
const tmplPath = join(skillDir, "templates", templateName);
const tmpl = readFileSync(tmplPath, "utf8");

// Two-pass replace: triple-brace is raw SVG (already escaped), double-brace is XML-escaped.
let svg = tmpl.replace(/{{{(\w+)}}}/g, (_m, key) => {
  if (!(key in vars)) throw new Error(`template references unknown raw key: {{{${key}}}}`);
  return vars[key] ?? "";
});
svg = svg.replace(/{{(\w+)}}/g, (_m, key) => {
  if (!(key in vars)) throw new Error(`template references unknown key: {{${key}}}`);
  return escapeXml(vars[key] ?? "");
});

// ---- Rasterize ----------------------------------------------------------
let Resvg;
try {
  ({ Resvg } = await import("@resvg/resvg-js"));
} catch (err) {
  console.error("proof-of-value: @resvg/resvg-js not installed. Run scripts/render.sh instead of calling render.mjs directly (the shell wrapper handles the one-time install).");
  process.exit(1);
}

const resvg = new Resvg(svg, {
  fitTo: { mode: "width", value: 1600 },
  background: vars.bg,
  font: {
    loadSystemFonts: true,
    defaultFontFamily: "Inter",
  },
});

const png = resvg.render().asPng();

const outPath = resolve(dirname(configPath), "..", "assets", "proof-of-value.png");
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, png);

console.log(`proof-of-value: wrote ${outPath} (${png.length} bytes, kind=${config.kind})`);
