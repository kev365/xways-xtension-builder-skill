---
type: guide
last_updated: 2026-06-06
author: project
---

# Getting the X-Ways X-Tension SDK

This repository does **not** ship the X-Ways X-Tension SDK (the `X-Tension.h`
header and sample projects) or the X-Ways manuals — they are copyright X-Ways
Software Technology AG and are not ours to redistribute.

You do **not** strictly need the SDK to *compile*: the templates here follow the
project convention of **self-declaring** the `XWF_*` function-pointer typedefs
they use and resolving them at runtime via `GetProcAddress` (so they build with
just `windows.h`). You **do** need the SDK — or the live API page — as the
**authoritative reference** for the correct signatures, flags, and property
numbers whenever you add a new `XWF_*` call. That is exactly what the skill's API
guardrail enforces.

## What's useful to have

- **`X-Tension.h`** — the C/C++ X-Tension API header. The canonical reference for
  every `XWF_*` signature, flag bit, and struct. (Mirror its types when you
  declare a new typedef — don't invent one.)
- *(optional)* the Delphi (`XT_API.pas`) or Python SDK pieces, if you target
  those languages.
- *(optional)* the X-Ways Forensics manual / *X-Ways Forensics: Practitioner's
  Guide* for deeper reference.

## Where to get it

- **Official X-Tension API page** —
  <https://www.x-ways.net/forensics/x-tensions/api.html> — links to the SDK and
  documents the API. The live function reference is
  <https://www.x-ways.net/forensics/x-tensions/XWF_functions.html>.
- **SourceForge** — the `xwf-api` project mirrors the SDK:
  <https://sourceforge.net/projects/xwf-api/>.
- The manuals come with your licensed X-Ways Forensics / WinHex install, or from
  x-ways.net.

X-Ways explicitly permits writing and distributing X-Tensions: per
[their X-Tension API page](https://www.x-ways.net/forensics/x-tensions/api.html)
you may distribute X-Tensions and their source
["under whatever license terms you see fit,"](https://www.x-ways.net/forensics/x-tensions/api.html)
with no royalty. This project does that under the MIT License — but the **SDK
itself stays with X-Ways**; acquire it from the links above.

## Where to put it

The build scripts and the API guardrail look for an **optional** local SDK header
under `references/api/` (this folder is git-ignored — never commit the SDK):

```text
references/
└── api/
    └── <sdk-folder>/
        └── src/
            └── X-Tension.h
```

If you keep the header elsewhere, point your build at it (edit the `build.bat`
include path in your scaffolded X-Tension). The header is only needed at
**compile** time.

> The API guardrail's source priority is: the distilled notes in `docs/` → the
> live HTML API page → (optional) your locally-downloaded `X-Tension.h`. See
> [api-guardrail.md](../.claude/skills/xways-xtension-authoring/references/api-guardrail.md).
