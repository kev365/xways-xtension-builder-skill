# cpp-xtmgr-compatible — manager-compatible C++ X-Tension template

A fork-able starting point for an X-Ways Forensics 21.7+ X-Tension that
works **both** as a standalone X-Tension (X-Ways loads the DLL directly
via Tools → Run X-Tension) **and** as a managed plugin inside
`xways-xt-manager` (a separate project, not yet publicly released; the
manager loads the same DLL and surfaces it as a
tab — see [manager compatibility](../../../docs/conventions/manager-compatibility.md)).

If you don't need manager compatibility, use the regular
[`templates/x-tensions/cpp/`](../cpp/) template instead — it's smaller
and has no contract obligations.

## Files

- `my_xtension.cpp` — entry points (`XT_Init` … `XT_Done`) **plus** the
  `XwaysManagerPluginEntry()` export and supporting lifecycle hooks.
- `my_xtension.def` — exports both the standard XT_* names AND
  `XwaysManagerPluginEntry`.
- `my_xtension.rc` — optional settings dialog template. Designed so the
  same template can be shown standalone (modal) or embedded by the
  manager (child).
- `resource.h` — dialog and control IDs.
- `manager-plugin.h` — the manager plugin contract header (ABI 1). Copy
  verbatim when scaffolding — do not edit; scaffolds are checked against
  the canonical copy in `templates/x-tensions/cpp-xtmgr-compatible/`.
- `build.bat` — MSVC build; compiles the .rc + .cpp and links into
  `xways-<your-name>.dll`.

## Use this template

1. Copy `templates/x-tensions/cpp-xtmgr-compatible/` to
   `x-tensions/xways-<your_name>/`.
2. Rename `my_xtension.*` → `xways-<your_name>.*`.
3. In the `.def` and `build.bat`, change `my_xtension` to your new
   name. **Don't remove `XwaysManagerPluginEntry` from the `.def`** —
   that's the export the manager looks for.
4. In the `.cpp`, update the `NAME` / `VERSION` / `DESCRIPTION`
   constants AND the matching fields inside the
   `XwaysManagerPluginDescriptor` returned by
   `XwaysManagerPluginEntry()`. They drive both the standalone X-Tension
   identity AND the manager's tab caption / tools-list entry.
5. Implement your tool's logic inside `XT_ProcessItem` (or
   `XT_ProcessItemEx`) AND the matching `OnProcessItem` /
   `OnProcessItemEx` callbacks the descriptor points at. **Use the
   same internal functions for both** so standalone and managed modes
   share behaviour.
6. Build with `build.bat`. Drop the resulting folder into
   `<X-Ways install>\xtensions\`. Test standalone first
   (Tools → Run X-Tension); then verify the manager picks it up
   (run xways-xt-manager and check the tab appears).

## The two-mode pattern

Your `.cpp` has TWO sets of exports that wrap the SAME internal logic:

```text
                        ┌─ Standalone mode (X-Ways) ─┐
                        │   XT_Init                  │
   ┌────────────────────┤   XT_Prepare               │
   │                    │   XT_ProcessItem...        │
   │   YOUR LOGIC:      │   XT_Finalize              │
   │  - Discovery       │   XT_Done                  │
   │  - Per-item work   └────────────────────────────┘
   │  - Output emission ┌─ Managed mode (xt-manager) ┐
   │                    │   XwaysManagerPluginEntry  │
   └────────────────────┤   OnInit                   │
                        │   OnPrepare                │
                        │   OnProcessItem...         │
                        │   OnFinalize               │
                        └────────────────────────────┘
```

The `XT_*` exports get called when X-Ways loads the DLL directly. The
`On*` callbacks get called when xways-xt-manager loads the DLL as a
plugin. **Both delegate to the same internal functions** — there's no
behavioural drift between modes.

This is why the template ships with the `XT_Init` / `OnInit` pair both
calling `ResolveFunctionPointers`, the `XT_Prepare` / `OnPrepare` pair
both calling `RunPrepare`, etc.

## Dialog hosting

Two strategies (the manager supports both):

**Option A — single dialog, retrofitted (recommended).**
Ship one settings dialog. The manager strips `WS_POPUP | WS_CAPTION |
WS_SYSMENU | DS_MODALFRAME` and adds `WS_CHILD | DS_CONTROL` at runtime
before embedding it in a tab. Your `.rc` needs no changes.

Tradeoffs:
- Your bottom-row Run / Cancel buttons render inside the tab,
  duplicating the manager's own bottom-row buttons. Cosmetic — the
  manager's buttons drive the lifecycle.
- Zero plugin-author effort beyond setting the descriptor's
  `tab_dialog_resource_id` to your existing standalone dialog ID.

**Option B — second dialog template, native-styled for embedding.**
Define a second `IDD_*` in your `.rc` with `WS_CHILD | DS_CONTROL`
already set (no caption, no border, no Run/Cancel buttons). Set
`tab_dialog_embedded_resource_id` in the descriptor to that ID.
The manager prefers the embedded version when both are present.

Use B if your dialog is complex enough that the Option-A retrofit
looks off, or if you want a polished "no duplicate Run buttons"
visual. Most plugins won't need this.

## What the manager calls and when

| Manager → Plugin callback | When |
| --- | --- |
| `on_init(hPluginModule, hMainWnd, NULL)` | Once at manager's `XT_Init`. Use to resolve `XWF_*` function pointers + any per-DLL setup. Return false to disable this plugin (e.g. required `XWF_*` exports missing on the running X-Ways build). |
| `on_prepare(hVolume, hEvidence, nOpType, NULL)` | When the analyst clicks Run This Plugin or Run All Enabled. Returning false skips this one plugin's run; others still run. |
| `on_process_item(nItemID, NULL, NULL)` | Per snapshot item, iff your descriptor's `on_process_item` field is non-NULL. |
| `on_process_item_ex(nItemID, hItem, NULL)` | Per snapshot item, iff your descriptor's `on_process_item_ex` field is non-NULL. The manager translates X-Ways' per-item-callback flags from your descriptor; you don't return them from `on_prepare`. |
| `on_finalize(hVolume, hEvidence, nOpType, NULL)` | At end of run, after all per-item callbacks. |

All callbacks may be NULL — the manager just skips them. Most plugins
implement at minimum `on_init` + `on_prepare`. Per-item callbacks
only if the work shape requires them.

## See also

- [`manager-plugin.h`](manager-plugin.h) — full contract documentation
- [manager compatibility reference](../../../.claude/skills/xways-xtension-authoring/references/manager-compat.md) — how the `xways-xt-manager` contract works and how to adopt it
- [`../wrapper/`](../wrapper/) — the wrapper template is manager-compatible; a fuller example of this contract wired into a real settings dialog
- [`docs/xtension-dialog-conventions.md`](../../../docs/xtension-dialog-conventions.md) — cross-X-Tension dialog UX patterns
- [`templates/x-tensions/cpp/`](../cpp/) — the simpler template for X-Tensions that don't need manager compatibility
