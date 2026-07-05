# Versioning

X-Tensions use a **semver-style `MAJOR.MINOR.PATCH`** string with a **`-beta`
pre-release suffix until the first public release**. New scaffolds start at
`0.1.0-beta`.

## The beta rule

- While an X-Tension is **pre-public** (not yet published to its public GitHub
  repo / Releases for general use), its version carries a `-beta` suffix:
  `0.1.0-beta`, `0.4.0-beta`.
- At the **first public release**, drop the suffix (`0.4.0-beta` → `0.4.0`).
- After going public, bump normally. Reach **`1.0.0`** when the interface and
  output format are stable enough to promise compatibility.

Sub-1.0 (`0.y.z`) signals "still pre-1.0, expect change"; the `-beta` suffix
adds "not yet released publicly." Both can be true at once.

## One version, three places — keep them in sync

| Where | What |
|---|---|
| `<name>.cpp` | `static const wchar_t* VERSION = L"0.1.0-beta";` (the scaffold sets this) |
| `<name>.rc` | `StringFileInfo` `FileVersion` / `ProductVersion` + the About-box text |
| `README.md` | the `Status: <version>` line under the title |

!!! note "`.rc` numeric vs string version"
    The numeric `FILEVERSION` / `PRODUCTVERSION` fields are `n,n,n,n` and
    **cannot** hold `-beta`. Put `0,1,0,0` there and the human-readable
    `0.1.0-beta` in the `StringFileInfo` `FileVersion` / `ProductVersion`
    strings and the About text.

## Bumping

- **Patch** (`0.1.0` → `0.1.1`): bug fixes, no behavior change.
- **Minor** (`0.1.1` → `0.2.0`): new features, backward-compatible.
- **Major** (`0.x` → `1.0.0`): first stable public contract; breaking changes
  afterwards.

Update all three places in the same commit. The scaffold only stamps the `.cpp`
constant — sync the `.rc` and README by hand.

## Do / Don't

- **Do** start new X-Tensions at `0.1.0-beta`.
- **Do** drop `-beta` exactly when the tool first goes public.
- **Don't** let the `.cpp`, `.rc`, and README versions drift apart.

**Source of truth:** the scaffold default in
`.claude/skills/xways-xtension-authoring/scripts/new-xtension.ps1`
(`-Version 0.1.0-beta`).
