// marketing/proof-of-value.config.mjs — self-hosted proof for create-claude-plugin.
// The plugin's value prop is a *checklist of things a first-time plugin author
// forgets* — so the right kind here is `coverage`. Eight phases, eight things
// the skill catches before you ship.

export default {
  kind: "coverage",
  name: "create-claude-plugin",
  caption: "Eight phases, zero skipped — the skill walks each one before letting you hit submit.",
  theme: "light",
  accent: "#D97706",
  coverage: {
    heading: "What create-claude-plugin covers",
    rows: [
      { label: "Resume-or-update detection for existing plugins",    covered: true  },
      { label: "Plugin vs standalone decision + component picking",  covered: true  },
      { label: "Scaffold: manifests, LICENSE, README, CLAUDE.md",    covered: true  },
      { label: "claude plugin validate green before you move on",    covered: true  },
      { label: "Supply-side README + launch-tweet drafting",         covered: true  },
      { label: "og-card + proof-of-value artifacts",                 covered: true  },
      { label: "GitHub push + /plugin marketplace add verified live", covered: true  },
      { label: "Submission pre-flight with clipboard-staged fields", covered: true  },
      { label: "Your plugin's actual behavior",                      covered: false },
    ],
  },
};
