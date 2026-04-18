# Marketing copy rubric

Load this in Phase 5.5 before drafting a README or launch tweet. It's a drafting guide, not a style reference — every principle here ends in "do this / don't do that."

---

## Supply-side principles

**The reader is scrolling.** The first screen decides whether they install. Optimize for the first 200 words, then the rest can be a spec sheet.

1. **Describe outcomes, not artifacts.** A bullet that names a file is an artifact. A bullet that names what the user now *has* is an outcome. `"Scaffolds plugin.json"` → artifact. `"A validated plugin that passes `claude plugin validate`"` → outcome.
2. **Lead with the end state.** The first paragraph is where the reader ends up, not what the tool is. `"After: plugin validated, repo live, submission clipboard staged."` beats `"This plugin scaffolds a Claude Code plugin."`
3. **Before → After must be concrete and user-voiced.** `"Before: 'I have a skill in ~/.claude and no idea how to share it.'"` — quoted user pain. `"After: ~20 minutes, submission form open with every field staged."` — the reader can see themselves there.
4. **Tagline = category + unique move.** One sentence. Names *what kind of thing* it is and *the one move no competitor makes*. `"A Claude plugin that helps you ship Claude plugins"` — category (Claude plugin) + move (recursive/self-referential). Not `"A comprehensive suite of tools…"`.
5. **Bullets earn their spot.** If you can remove a bullet without the reader losing information, remove it. Four strong beats six weak.
6. **Name the stop.** Tell the reader what the plugin *won't* do. Self-limiting plugins feel more honest and let the reader map it to their problem faster.

## Anti-patterns — reject these

- "comprehensive suite of tools for…" / "everything you need to…" — vague, unfalsifiable
- "simply", "just", "easily" — these signal the writer, not the reader. The reader decides what's easy
- Emoji headers (`## 🚀 Getting Started`) — visual noise, breaks skim patterns
- Bullet lists that enumerate filenames instead of outcomes (`- SKILL.md` → `- A validated skill that passes \`claude plugin validate\``)
- Badges above the tagline — the tagline earns the first visual, not a row of shields.io links
- "Built with ❤️" — meaningless
- "Contributions welcome!" without saying what kind — dead text
- Feature lists that restate each heading in the README ("Has a README! Has a CHANGELOG!") — padding
- Leading with architecture diagrams — the reader doesn't care how it's built yet; they care what they get

## Tagline rubric

One sentence. Structure: `[category noun], [one-line unique move].`

- ✅ `A Claude plugin that helps you ship Claude plugins — scaffold, test, publish, submit, all in one session.`
- ✅ `A code-review agent for monorepos — reads the whole PR, not just the diff.`
- ❌ `The ultimate comprehensive toolkit for all your plugin needs.` (vague, superlative)
- ❌ `Claude plugin scaffolder.` (no unique move)
- ❌ `🚀 Ship Claude plugins fast 🔥` (emoji-as-excitement, empty)

No adjectives except those that carry information ("recursive", "local-first", "zero-config"). "Powerful" / "comprehensive" / "modern" carry none.

## Launch tweet rubric

Constraints:
- ≤ 280 characters
- Hook in first 10 words — the tweet preview cuts off around word 12
- One concrete outcome (numeric if possible: "~20 minutes", "one command", "zero config")
- One link — the repo, not a blog post about the repo
- Max 1 emoji
- No hashtag spam. Zero hashtags is fine. One is fine. Three is spam
- Use `@you` as a placeholder for the author handle — don't ask the user for theirs

Structure that works:
```
[Hook — names the pain or the outcome]

[One line of what it does, outcome-framed]

[One concrete signal — number, timeline, or "it just works"]

[Link]
```

Examples:
- ✅ `Shipped `create-claude-plugin`: a Claude plugin that helps you ship Claude plugins. Scaffold → validate → push → submit to the official store in ~20 min, all in-session. github.com/you/create-claude-plugin`
- ❌ `Check out my new project! 🚀🔥 I built a comprehensive plugin scaffolder for Claude Code that has everything you need to easily create plugins! #claude #ai #plugins #opensource #tools link`

## MARKETING.md layout

```markdown
# Marketing copy for <plugin-name>

## Launch tweet

<the tweet, ≤280 chars, `@you` placeholder>

## Alt tweets

<0–3 alternates — optional, each ≤280 chars>

<!-- TODO: og-card — generate a 1200×630 social-preview image.
Candidates: satori with a templated React component, or a
headless-browser screenshot of an HTML card. Drop at assets/og.png
and reference from README + plugin.json homepage. -->
```

## Worked examples

### Example 1 — `create-claude-plugin` (this plugin)

**Tagline (✓):** `A Claude plugin that helps you ship Claude plugins — scaffold, test, publish, and submit to the official Anthropic marketplace in one session.`

Why it works: names the category (Claude plugin), names the unique move (recursive / self-referential), lists the outcome chain without adjectives.

**Before → After (✓):**
> **Before:** "I have a skill in `~/.claude/` and no idea how to share it."
> **After:** Plugin validated with `claude plugin validate`. Repo live on GitHub. `/plugin marketplace add owner/repo` verified in a fresh session. Submission form open in your browser with every field already on your clipboard. ~20 minutes.

Why it works: Before is quoted user pain. After is five concrete end-states chained by periods, with a numeric outcome (~20 minutes). No adjectives. No `simply`.

**What you walk away with (✓):**
- A validated plugin — passes `claude plugin validate`, tested in-session
- A live GitHub repo — one-command install flow verified end-to-end
- A filled-in submission — clipboard pre-loaded, browser opened, fields grouped by form page

Why it works: each bullet is a thing the user *has* after, not a thing the plugin *does*. Em-dash separates the outcome from the proof.

### Example 2 — rewriting a bad README

**Before (spec-sheet style, anti-pattern):**
```
# plugin-name

A comprehensive suite of tools for Claude Code development. Simply install
and you'll have everything you need to easily build plugins!

## Features
- plugin.json generator
- marketplace.json generator
- README template
- CHANGELOG template
- GitHub push script
- Submission checker script
```

**After (supply-side rewrite):**
```
# plugin-name

> One Claude session from "I have an idea" to "it's in the official marketplace."

Scaffold, test, push, and submit in the same session — the CLI catches
what's broken, this skill decides what to build.

## Before → After

Before: you have a skill in ~/.claude/ and no idea how to share it.
After: repo live, `/plugin install` verified, submission form staged.

## What you walk away with

- A validated plugin (not a folder of templates)
- A live GitHub repo with the install flow tested
- A filled-in submission, paste-ready
```

Diff: removed 6 filename bullets, replaced with 3 outcome bullets. Removed 3 banned adjectives ("comprehensive", "simply", "easily"). Added Before → After. Tagline now names the unique move.

### Example 3 — launch tweet rewrite

**Before (anti-pattern):**
```
🚀🔥 Excited to launch my new project! It's a comprehensive plugin
scaffolder for Claude Code that has everything you need to easily
create and ship plugins. Check it out!
#claude #ai #plugins #opensource #tools #developer #productivity
link.com
```
Problems: 2 emojis, 7 hashtags, two banned words, zero concrete outcomes, no hook in first 10 words, vague verb ("check it out").

**After:**
```
Shipped `create-claude-plugin`: a Claude plugin that helps you ship
Claude plugins. Scaffold → validate → push → submit to the official
store in ~20 min, all in-session. No context switches, no lost state.

github.com/you/create-claude-plugin
```
Fix: hook in first 6 words, outcome is the chain `scaffold → validate → push → submit` + time-bound signal (~20 min), one link, 1 emoji allowed but none used, zero hashtags.

---

## Final check before shipping

Grep the draft for these strings. If any are present, rewrite:

- `simply`
- `just` (used as filler: "just install and…" — ok when it means "only")
- `easily`
- `comprehensive`
- `everything you need`
- `a suite of`
- `powerful` (unless followed by a specific capability)

Also check: does the first paragraph describe the end state the user ends up in, or does it describe the tool? If it's the tool, rewrite.
