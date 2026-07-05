# X-Tension Templates

Reusable starting points for new X-Tensions targeting **X-Ways Forensics 21.7+** (Windows x64).

Don't edit these in place — scaffold a copy with the skill's
[`new-xtension.ps1`](../../.claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1)
(or `/xtension new`), which renames the files and sets the identity constants for you.

## Available

- [`cpp/`](cpp/) — **C++ DLL** (MSVC 2019/2022, x64). The primary template for
  forensic-license-only features (e.g. the Events API). Self-contained: resolves
  `XWF_*` exports via `GetProcAddress`, so it compiles without the SDK header.
- [`cpp-xtmgr-compatible/`](cpp-xtmgr-compatible/) — the C++ template plus
  `xways-xt-manager` compatibility (loads standalone *and* as a manager tab).
  Manager support is **opt-in** — scaffold from this only when you specifically
  want an `xways-xt-manager` tab; otherwise use `cpp`.
- [`python/`](python/) — **Python** skeleton (for `XT_Python.dll`, Python 3.10 or
  3.12). Faster to iterate; use when you don't need APIs the Python bridge omits
  (notably `XWF_AddEvent` / `XWF_GetEvent`, which require C++). Patterns drawn from
  public community X-Tensions (CrowdStrike's YARA scanner, Polito's extensions) —
  see [NOTICE](../../NOTICE).
- [`wrapper/`](wrapper/) — manager-compatible C++ template for **wrapping an
  external CLI tool**: settings dialog + cfg sidecar, helper-exe identity
  verification, Ctrl-to-save, subprocess stdio, and the standard output-dir layout
  already wired in.

## Picking a language

| Need | Pick |
|---|---|
| Events API or other forensic-license-only features | C++ (`cpp` / `cpp-xtmgr-compatible`) |
| Wrapping an external command-line tool | `wrapper` |
| Performance, tight loops over millions of items | C++ |
| Rich libraries (parsing, HTTP), rapid prototyping | Python |

## Entry points (all templates)

`XT_Init` → `XT_About` → `XT_Prepare` → `XT_ProcessItem` / `XT_ProcessItemEx` / `XT_ProcessSearchHit` → `XT_Finalize` → `XT_Done`.

For authoritative signatures, see the official
[X-Ways function reference](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html)
or a locally-downloaded SDK header — see [getting-the-sdk.md](../../docs/getting-the-sdk.md).
This repo does not ship the SDK (copyright).
