---
source: X-Ways 21.6 manual §3.10 + empirical
type: official-doc + empirical-finding
last_updated: 2026-06-06
author: project notes
---

# `X-Tensions.txt` — remembered X-Tension list

## File location

`<X-Ways install>\X-Tensions.txt` — sits next to `WinHex.cfg`. The X-Ways
21.6 manual mentions it in the §3.10 *Command Line Parameters* note about
the `Cfg:` parameter:

> a few settings are stored in other files, e.g. "X-Tensions.txt" and
> "Unwanted Metadata.txt"

## Format

One DLL per line. Tab-separated:

```text
<flags>\t<absolute path to DLL>
```

Real example:

```text
0	C:\Tools\X-Ways\xtensions\xways-mytool.dll
1	C:\Tools\X-Ways\xtensions\xways-bulk_extractor\xtensions\xways-bulk_extractor.dll
1	C:\Tools\X-Ways\xtensions\xways-tagger\xways-tagger.dll
8	C:\Tools\X-Ways\xtensions\xways-updater\xtensions\xways-updater\xways-updater.dll
```

Each line is one DLL the user has previously added via
**Tools → Run X-Tensions → +**. X-Ways persists these paths so the menu
remembers the list across sessions.

## What the leading number means (tentative)

Best read: **bit flags for the X-Tension *action contexts* the user has
checked** for that DLL in the menu. The action codes come from the X-Ways SDK header (see [getting-the-sdk.md](getting-the-sdk.md)):

| Bit | Value | `XT_ACTION_*` | UI checkbox in the X-Tensions dialog |
| --- | --- | --- | --- |
| 0 | 1 | `RUN` | Run X-Tensions on Volume Snapshot (Tools menu) |
| 1 | 2 | `RVS` | During Refine Volume Snapshot |
| 2 | 4 | `LSS` | During Logical Simultaneous Search |
| 3 | 8 | `PSS` | During Physical Simultaneous Search |
| 4 | 16 | `DBC` | Directory Browser context-menu command |
| 5 | 32 | `SHC` | Search-hit context-menu command |

So the example above translates to:

| Value | Bits set | Selected contexts |
| --- | --- | --- |
| 0 | none | DLL is registered but disabled in every context (greyed checkboxes) |
| 1 | bit 0 | enabled for "Run X-Tensions on Volume Snapshot" (the most common case) |
| 8 | bit 3 | enabled for "Physical Simultaneous Search" only — usually a misclick |

Compound values are possible (e.g. `9` = `1 | 8` = both *Run* and *PSS*).

## Forwarding behaviour in `xways-updater`

The "Copy custom configs" checkbox in xways-updater pulls `X-Tensions.txt`
forward into the new install. Because the paths inside are **absolute and
old-install-rooted**, the new install's menu will list DLLs whose paths
no longer exist. Re-run `Tools → Run X-Tensions → +` once in the new
install to add the DLL paths under the new install root. xways-updater
logs a note to the Messages window when it copies the file as a reminder.

## Open questions

- Does X-Ways validate paths on load and prune missing entries? (Test:
  delete a referenced DLL, restart X-Ways, see if the entry survives.)
- What's the precise behaviour when two installs both write to `X-Tensions.txt`
  concurrently? (Probably last-writer-wins.)
- Does `XT_INIT_*` flags returned by `XT_Init` influence how X-Ways
  populates the menu checkboxes (e.g. does an X-Tension that returns
  `XT_INIT_QUICKCHECK` stay always-zero)? Untested.

## Related

- [docs/xtension-invocation.md](xtension-invocation.md) — entry-point + action-code reference
- [docs/xways-command-line.md](xways-command-line.md) — CLI parameters that hit `X-Tensions.txt`
