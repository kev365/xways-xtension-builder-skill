# X-Tension Templates

Reusable starting points for new X-Tensions targeting **X-Ways Forensics 21.7+** (Windows x64).

Don't edit these in place — scaffold a copy with the skill's
[`new-xtension.ps1`](../../scripts/new-xtension.ps1)
(or `/xtension new`), which renames the files and sets the identity constants for you.

## Available

- [`cpp/`](cpp/) — **C++ DLL** (MSVC 2019/2022, x64). The primary template for
  forensic-license-only features (e.g. the Events API). Self-contained: resolves
  `XWF_*` exports via `GetProcAddress`, so it compiles without the SDK header.
- [`python/`](python/) — **Python** skeleton (for `XT_Python.dll`; the current
  bundle links Python 3.12 and needs a matching **system-wide** install).
  Faster to iterate; use when you don't need APIs
  the Python bridge omits — the full 46-method inventory of what it *does*
  expose is in [xways-python-bridge.md](../../docs/xways-python-bridge.md)
  (notably `XWF_AddEvent` / `XWF_GetEvent`, which require C++). Two hard
  constraints (verified live 2026-08-16, details in the
  [python README](python/README.md)): the script's file stem must be a legal
  module name (**underscores, never hyphens** — the bridge loads via
  `import <filestem>`), and the `.py` files deploy into the **X-Ways main
  folder**, not an `xtensions\` subfolder. Patterns drawn from
  public community X-Tensions (CrowdStrike's YARA scanner, Polito's extensions) —
  see [NOTICE](../../NOTICE).
- [`wrapper/`](wrapper/) — C++ template for **wrapping an
  external CLI tool**: settings dialog + cfg sidecar, helper-exe identity
  verification, Ctrl-to-save, subprocess stdio, and the standard output-dir layout
  already wired in.

## Picking a language

| Need | Pick |
|---|---|
| Events API or other forensic-license-only features | C++ (`cpp` / `wrapper`) |
| Wrapping an external command-line tool | `wrapper` |
| Performance, tight loops over millions of items | C++ |
| Rich libraries (parsing, HTTP), rapid prototyping | Python |

## Entry points (all templates)

`XT_Init` → `XT_About` → `XT_Prepare` → `XT_ProcessItem` / `XT_ProcessItemEx` / `XT_ProcessSearchHit` → `XT_Finalize` → `XT_Done`.

All entry points are *implemented* in every template, but the C++ `.def` files
**export selectively**: X-Ways drives behaviour off the export table (export
both per-item callbacks and both fire for every item — the "2N" trap), so each
template exports only the callback it does its work in, with the rest
`;`-commented for one-line re-enable. See the notes inside each `.def`.

For authoritative signatures, see the official
[X-Ways function reference](https://www.x-ways.net/forensics/x-tensions/XWF_functions.html)
or a locally-downloaded SDK header — see [getting-the-sdk.md](../../docs/getting-the-sdk.md).
This repo does not ship the SDK (copyright).
