# Helper-exe identity verification

!!! warning "Required for any X-Tension that wraps an external CLI tool"
    Path resolution alone (cfg / bundled / PATH / Browse) is not enough — a renamed or rogue exe
    at the expected path would be launched with this X-Tension's CLI shape. Verify identity
    **before** spawning, at **every** resolution site.

**Accept on an OR of two gates:**

1. **PE VERSIONINFO substring** — scan `InternalName` / `OriginalFilename` / `ProductName` /
   `FileDescription` for the helper's needle (case-insensitive).
2. **`<exe> --version` banner** — first non-empty line contains the needle; discard
   `usage:` / `error:` / `unrecognized arguments` banners.

Reject hard: empty the resolved path and log the reason verbatim.

**Source of truth:** the `wrapper` template (`templates/x-tensions/wrapper/my_xtension.cpp`) →
`VerifyHelperIdentity`, `PeIdentityContains`, `DetectHelperVersionFromFlag`.

## In-dialog rejection UI (no MessageBox)

Full rejected path in the readout; the Version slot becomes a **bold-red
`Not a valid <helper>.exe file`** that flashes bright/dark red (~250 ms) for ~2 s, then stays
solid red; Run disabled until a valid Browse pick clears it.
**Source:** `ShowHelperRejection` / `ClearHelperRejection`, plus the `WM_CTLCOLORSTATIC` and
`WM_TIMER` handlers in the same file.

## Do / Don't

- **Do** apply the check at cfg, bundled, PATH, Browse, and RVS-silent resolution sites.
- **Do** surface rejection on the dialog (flash UI) — headless paths just log and bail.
- **Don't** accept a `--version` output that is actually a usage/error banner.
