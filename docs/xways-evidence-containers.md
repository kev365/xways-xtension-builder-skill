---
source: https://www.x-ways.net/forensics/x-tensions/XWF_functions.html (official, fetched 2026-08-13) + XT_API.pas (hmrc/XT_XWF-AutoCTR, Apache-2.0) for the constant names
type: official-doc
fetched: 2026-08-13
last_updated: 2026-08-13
author: X-Ways Software Technology AG (distilled); project notes
---

# Evidence file containers — `XWF_CreateContainer` / `XWF_CopyToContainer` / `XWF_CloseContainer`

Three functions let an X-Tension write an **evidence file container** — X-Ways'
native portable format for handing a subset of a case to someone else. Available
since **v16.5**. This page exists because the `XWF_CTR_*` family was one of two
constant groups the [coverage map](xways-api-coverage-map.md) flagged as
undocumented here.

The shape is a stream, not a collection: open one container, copy files into it
one at a time, close it.

## Contents

- The one-container rule
- `XWF_CreateContainer` and the `XWF_CTR_*` flags
- `XWF_CopyToContainer` — flags and modes
- `XWF_CloseContainer`
- What this is not

## The one-container rule

> "Currently only 1 container can be open at a time for filling. If a container
> is open already when this function is called, that other container will be
> closed automatically."

**Creating a second container silently closes the first.** There is no error and
no warning — the handle you were holding simply stops being the open container.
An X-Tension that writes one container per evidence object must therefore close
each one before creating the next, and must not hold two handles expecting to
interleave writes between them.

## `XWF_CreateContainer` and the `XWF_CTR_*` flags

```c
HANDLE XWF_CreateContainer(LPWSTR lpFileName, DWORD nFlags, LPVOID pReserved);
```

Creates a new container, or opens an existing one, in its native raw format.
Returns a handle, or **0** on failure.

| Flag | Value | Meaning |
| --- | --- | --- |
| `XWF_CTR_OPEN` | `0x0001` | **Open an existing container.** All other flags are ignored. Works in v19.1 SR-10, v19.2 SR-8, v19.3 SR-8, v19.4 SR-4 and later. |
| `XWF_CTR_RESERVED` | `0x0002` | **Do not use.** |
| `XWF_CTR_SECURE` | `0x0004` | Mark the container as to be filled indirectly / securely. |
| `XWF_CTR_TOPLEVELDIR_COMPLETE` | `0x0008` | Include evidence-object names as the top directory level. |
| `XWF_CTR_INCLDIRDATA` | `0x0010` | Include original directory data structures. |
| `XWF_CTR_FILEPARENTS` | `0x0020` | Allow files as parents of files. |
| `XWF_CTR_USERREPORTTABLES` | `0x0100` | Export associations with **user-created** labels / report tables. |
| `XWF_CTR_SYSTEMREPORTTABLES` | `0x0200` | Export associations with **system-created** labels. **Currently requires `0x0100` as well.** |
| `XWF_CTR_ALLCOMMENTS` | `0x0800` | Always pass comments on — **v18.9 and earlier**. |
| `XWF_CTR_TOPLEVELDIR_PARTIAL` | `0x1000` | Include the direct evidence-object name as the top directory level. |

Two of these are traps in opposite directions. `0x0002` is reserved and must be
left alone. `0x0800` is documented for **v18.9 and earlier** only — passing it on
a modern host is at best inert, so do not rely on it to carry comments; that job
belongs to `XWF_CopyToContainer`'s `0x0010` flag.

The two top-level-directory flags (`0x0008` and `0x1000`) are alternatives, not a
pair: *complete* uses the full evidence-object names, *partial* the direct name.

## `XWF_CopyToContainer` — flags and modes

```c
LONG XWF_CopyToContainer(HANDLE hContainer, HANDLE hItem, DWORD nFlags,
                         DWORD nMode, INT64 nStartOfs, INT64 nEndOfs,
                         LPVOID pReserved);
```

Returns **0** on success, otherwise an error code. **A negative return means
stop** — the official page says you should not try to fill the container
further. Treat "negative" as fatal to the whole container, not to the one file.

`nFlags`:

| Bit | Meaning |
| --- | --- |
| `0x0001` | recreate the full original path |
| `0x0002` | include parent item data — **requires `0x0001`** |
| `0x0004` | store the hash value in the container |
| `0x0010` | store the comment, if any (v19.0+) |
| `0x0020` | store extracted metadata, if available (v19.0+) |

`nMode`:

| Mode | Copies |
| ---: | --- |
| `0` | logical file contents only |
| `1` | physical file contents — **not supported** |
| `2` | logical contents and file slack, separately |
| `3` | slack only |
| `4` | a byte range, from `nStartOfs` to `nEndOfs` |
| `5` | metadata only |

**Pass `-1` for `nStartOfs` and `nEndOfs` in every mode except 4.** They are not
ignored-by-default; the page specifies `-1` as the value for "unused".

Mode `1` is declared and does not work. Mode `5` is the useful surprise: it
records an item in the container without copying its bytes, which is how you
build a container that documents what was found without exporting content.

## `XWF_CloseContainer`

```c
LONG XWF_CloseContainer(HANDLE hContainer, LPVOID pReserved);
```

Returns **1** if successful — note that this is the opposite polarity to
`XWF_CopyToContainer`, where 0 is success. Getting these two backwards is easy
and produces an X-Tension that reports failure on every successful copy.

## What this is not

A container is not an output directory. If the goal is "write files somewhere the
analyst can look at them", the project convention is a plain folder under the
case root — see [output-dir](conventions/output-dir.md). Reach for a container
when the artefact needs to be **imported
back into X-Ways** as an evidence object, with labels, comments and metadata
attached.

## See also

- [xways-snapshot-mutation.md](xways-snapshot-mutation.md) — the other write-side
  surface: creating items inside the current snapshot rather than exporting them.
- [xways-reading-events-and-items.md](xways-reading-events-and-items.md) — how to
  select the items worth copying in the first place.
- Official reference: <https://www.x-ways.net/forensics/x-tensions/XWF_functions.html>
