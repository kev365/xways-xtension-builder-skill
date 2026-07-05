---
type: registry
last_updated: 2026-07-03
author: project
---

# Exemplars

X-Tensions worth studying when you build your own. **None are bundled in this
repo** — clone the ones you want to read. Scaffold new work from the
[templates](../templates/x-tensions/) (`-Template wrapper` for a CLI-tool
wrapper) and use these as references to read and port patterns from (with
attribution), not as copy-targets.

Before porting from an older X-Tension, sanity-check that its `XWF_*` calls still
exist on X-Ways 21+ — see [api-guardrail](../.claude/skills/xways-xtension-authoring/references/api-guardrail.md)
and [xways-api-recency-research.md](xways-api-recency-research.md).

## Reference X-Tensions by the skill's maintainer

Public X-Tensions by this skill's maintainer — the `wrapper` template
implements the same conventions these demonstrate:

- [xways-updater](https://github.com/kev365/xways-updater) — installs/updates
  X-Ways + resources from inside an existing install (DPAPI credential storage,
  HTTP basic auth).
- [xways-trufflehog](https://github.com/kev365/xways-trufflehog) — a TruffleHog
  secret-scanner wrapper and the **canonical tool-wrap reference**: filter-aware
  item collection, a full settings dialog, helper-exe identity verification,
  per-detector report tables, and a consolidated CSV. The `wrapper` template
  follows the same conventions.
- [xways-ual-timeliner](https://github.com/kev365/xways-ual-timeliner) — a UAL
  (Unified Audit Log) timeliner wrapper: multi-mode (auto + selected items),
  helper-binary subprocess invocation, and a working reference for the
  Ctrl-to-save gesture and helper-exe identity verification.
- [xways-bulk_extractor](https://github.com/kev365/xways-bulk_extractor) — a
  `bulk_extractor` wrapper (helper-exe verification, Ctrl-to-save, WSL subprocess
  mode, selected-items export→tag mapping).
- [xways-linux-logs](https://github.com/kev365/xways-linux-logs) — a native
  Linux-log parser (no external tool): systemd journal, utmp/wtmp/btmp, lastlog,
  and text syslog, via a pluggable parser registry with vendored decompressors
  and hand-rolled XLSX output.

## Community X-Tensions

Public projects you can clone and study. Licenses vary — **"None"** means the
repo has no license file (you may read it, but reuse/redistribution isn't
granted), so check each repo before porting. URLs are given where known; the
rest are findable by name on GitHub.

| Project | Lang | License |
|---|---|---|
| [x-tension-c-sharp](https://github.com/jp-slackspace/x-tension-c-sharp) | C# | GPL-3.0 |
| [x-tensions (C# API)](https://github.com/chadgough/x-tensions) | C# | None |
| [X-Ways-DHFS4_1-X-Tension](https://github.com/dw2102/X-Ways-DHFS4_1-X-Tension) | C++ | BSD-3-Clause |
| [X-Ways-HIKVISION-X-Tension](https://github.com/dw2102/X-Ways-HIKVISION-X-Tension) | C++ | BSD-3-Clause |
| X-Ways-XT---DQT-Parser | C++ | None |
| [XMBRSum](https://github.com/bridgeythegeek/XMBRSum) | C | X-Ways AG (header files) |
| XT_CaseInfo | C# | None |
| XT_Duplicates | C# | None |
| XT_inguisher | C# | None |
| XT_olk15DataExtraction | C# | None |
| [XT_RefineSearchTerm](https://github.com/JamieSharpe/XT_RefineSearchTerm) | C++ | GPL-3.0 |
| [XT_XWF-2-RT](https://github.com/hmrc/XT_XWF-2-RT) | Delphi | Apache-2.0 + OGL-3.0 |
| [XT_XWF-AutoCTR](https://github.com/hmrc/XT_XWF-AutoCTR) | Delphi | Apache-2.0 + OGL-3.0 |
| [XT_XWF-CaseSummaryGenerator](https://github.com/hmrc/XT_XWF-CaseSummaryGenerator) | Delphi | Apache-2.0 + OGL-3.0 |
| [XT_XWF-OCR](https://github.com/hmrc/XT_XWF-OCR) | Delphi/FPC | Apache-2.0 + OGL-3.0 |
| XTension_template | C# | None |
| [xtv_asl](https://github.com/a5hlynx/xtv_asl) | C++ | AGPL-3.0 |
| xways-audiotranslate | C++ | MIT |
| [xwf-api-rs](https://github.com/ThomasVogl/xwf-api-rs) | Rust | LGPL-3.0 |
| [xwf-yara-scanner](https://github.com/CrowdStrike/xwf-yara-scanner) | C++ | MIT |
| [xt-gexpo](https://github.com/Naufragous/xt-gexpo) | C | AGPL-3.0 |
| [xt-pdfcomp](https://github.com/Naufragous/xt-pdfcomp) | C | AGPL-3.0 |
| [xt_entropy](https://github.com/a5hlynx/xt_entropy) | C++ | AGPL-3.0 |
| [xt_fuzzy](https://github.com/a5hlynx/xt_fuzzy) | C++ | AGPL-3.0 |

## Related tooling & research (not X-Tensions)

Adjacent projects worth knowing about when building or automating X-Tensions:

- [X-Ways-MCP](https://github.com/Donovoi/X-Ways-MCP) (Python + PowerShell + C,
  MIT) — an MCP (Model Context Protocol) server that exposes X-Ways Forensics to
  AI agents: headless/CLI orchestration with read-only defaults (execution gated
  behind an env var **and** a per-call confirm), a local manual cache, PowerShell
  cmdlets wrapping the `XWF_*` surface as JSONL requests, and an in-process
  X-Tension "bridge" scaffold (`xtensions/xwf-path-export`, one-shot JSONL
  metadata export). Notable for X-Tension authors: its
  `data/xwf-external-surface/` dataset — a PE + Ghidra inventory of **`xwb64.exe`
  21.8's exports (77 `XWF_*` present vs 85 documented**, analyzed-exe SHA256
  recorded) with cross-reference CSVs — an independent complement to
  [xways-api-recency-research.md](xways-api-recency-research.md).
  *Static review, 2026-07-03 (not executed — vet before use on a case):* the
  bridge's 12 `XWF_*` calls are all genuine API (none invented), resolved via
  `GetProcAddress(GetModuleHandleW(NULL))`, and `XT_Init` uses the current
  4-parameter `LicenseInfo*` signature. A young project (first released
  2026-05-31); the bridge X-Tension is a scaffold (fixed-size path-segment
  array, uneven evidence-handle cleanup on error paths) — review robustness
  before deploying, and read it for patterns and the API dataset.

See also the official [X-Ways third-party X-Tensions list](https://www.x-ways.net/forensics/x-tensions.html).
