# SPDX-License-Identifier: MIT
"""
X-Tension template for X-Ways Forensics 21.7 (Python / XT_Python.dll).

Copy this folder to `x-tensions/<your_name>/`, then fill in NAME/VERSION/DESCRIPTION
and implement logic inside the XT_* entry points (delegate to helpers.py where
possible). Official API reference:
    https://www.x-ways.net/forensics/x-tensions/api.html

Patterns borrowed (with attribution):
  - Report-table + Comments-column writes:         CrowdStrike/xwf-yara-scanner (MIT)
  - Sidecar config file next to the .py:           PolitoInc/X-Ways-VirusTotal-Extension
  - nOpType-aware Prepare (RVS vs DBC):            CrowdStrike/xwf-yara-scanner (MIT)
"""

import json
import os
import traceback

import xwf  # provided by XT_Python.dll at runtime
import OutputRedirector  # shipped with the Python X-Tension bundle

import helpers

# --- Identity -----------------------------------------------------------------
NAME = "xtension_template"
VERSION = "0.1.0"
DESCRIPTION = "Template X-Tension. Replace this text."
REPORT_TABLE = "Template Findings"  # shown in X-Ways "Report Table" UI

# --- Logging verbosity --------------------------------------------------------
# Keep VERBOSE = True during development. Flip to False before sharing or
# running on a large snapshot to keep the Messages window quiet. Do not remove
# the _log_verbose call sites -- the flag toggles them at zero cost.
VERBOSE = True

# --- XT_Prepare nOpType — canonical names per X-Tension.h:422-427 ------------
#   See docs/xtension-invocation.md for usage notes per mode.
XT_ACTION_RUN = 0  # Tools -> Run X-Tension on Volume Snapshot
XT_ACTION_RVS = 1  # Volume Snapshot Refinement
XT_ACTION_LSS = 2  # Logical Simultaneous Search
XT_ACTION_PSS = 3  # Physical Simultaneous Search
XT_ACTION_DBC = 4  # Directory Browser Context menu
XT_ACTION_SHC = 5  # Search Hit Context menu

# --- AddComment howToAdd flags (per official API docs) -----------------------
COMMENT_REPLACE = 0
COMMENT_APPEND = 1
COMMENT_PREPEND = 2

# --- Sidecar config -----------------------------------------------------------
# Optional JSON file next to this script; users can tweak behaviour without
# editing code. Format is whatever your X-Tension needs; keep keys stable.
CONFIG_FILENAME = f"{NAME}.config.json"
DEFAULT_CONFIG = {
    "min_item_size_bytes": 1_048_576,
    "add_to_report_table": True,
    "add_comment": True,
}

# --- State --------------------------------------------------------------------
# Populated in XT_Init / XT_Prepare, read in later callbacks.
_state = {
    "processed": 0,
    "flagged": 0,
    "hVolume": None,
    "opType": None,
    "config": dict(DEFAULT_CONFIG),
}


# --- Helper infrastructure ---------------------------------------------------

def _log(msg):
    """Visible in the X-Ways Messages window AND in the console (if allocated)."""
    try:
        xwf.OutputMessage(f"[{NAME}] {msg}", 0)
    except Exception:
        pass
    print(f"[{NAME}] {msg}")


def _log_verbose(msg):
    """Per-item / per-row diagnostics. No-op when VERBOSE is False."""
    if VERBOSE:
        _log(msg)


def _load_config():
    """Load sidecar JSON if present. Missing file = use defaults (no error)."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(script_dir, CONFIG_FILENAME)
    if not os.path.isfile(path):
        return dict(DEFAULT_CONFIG)
    try:
        with open(path, "r", encoding="utf-8") as f:
            merged = dict(DEFAULT_CONFIG)
            merged.update(json.load(f))
            return merged
    except Exception as e:
        _log(f"could not parse {CONFIG_FILENAME}: {e} — using defaults")
        return dict(DEFAULT_CONFIG)


# --- Entry points -------------------------------------------------------------

def XT_Init(nVersion, nFlags, hMainWnd, lpReserved):
    """First call. Set up console/logging. Return 1 to continue, <0 to abort."""
    OutputRedirector.install()
    xwf.AllocConsole()
    _state["config"] = _load_config()
    _log(f"{VERSION} — X-Ways build {nVersion / 100.0:.2f}")
    return 1


def XT_About(hParentWnd, lpReserved):
    """Shown when the user clicks 'About' in the X-Tension dialog."""
    xwf.OutputMessage(f"{NAME} {VERSION}\n{DESCRIPTION}", 0)
    return 0


def XT_Prepare(hVolume, hEvidence, nOpType, lpReserved):
    """Called once before per-item processing begins.
    Return value is a bitmask; common values:
      -1  = abort
       0  = no per-item callbacks
       1  = call XT_ProcessItem for each item
       4  = call XT_ProcessItemEx (receives a read handle)
    """
    _state["hVolume"] = hVolume
    _state["opType"] = nOpType
    _state["processed"] = 0
    _state["flagged"] = 0

    op_name = {XT_ACTION_RUN: "Run", XT_ACTION_RVS: "RVS",
               XT_ACTION_LSS: "LogicalSearch", XT_ACTION_PSS: "PhysicalSearch",
               XT_ACTION_DBC: "Directory-Browser", XT_ACTION_SHC: "Search-Hit"
               }.get(nOpType, f"#{nOpType}")
    vol_name = xwf.GetVolumeName(hVolume, 0) if hVolume else "(no volume)"
    _log(f"XT_Prepare [{op_name}] on volume: {vol_name}")

    # RVS is multi-threaded and high-volume — keep logging minimal there.
    # DBC runs on a user-selected handful of items — safe to be chatty.
    # 0x01 = call per-item callback(s). X-Ways calls whichever you export; both
    # XT_ProcessItem and XT_ProcessItemEx fire if both exist — do the work in ONE
    # (here, XT_ProcessItem below). 0x04 would be EXPECTMOREITEMS, not a callback flag.
    return 1


def XT_ProcessItem(nItem, lpReserved):
    """Per-item callback — lightweight. Return 0 to continue, -1 to abort run."""
    try:
        hit = helpers.evaluate_item(nItem, _state["config"])
        _state["processed"] += 1
        if hit:
            _log_verbose(f"hit on item {nItem}: {hit}")
            _record_hit(nItem, hit)
            _state["flagged"] += 1
    except Exception:
        _log(f"error on item {nItem}:\n{traceback.format_exc()}")
    return 0


def XT_ProcessItemEx(nItem, hItem, lpReserved):
    """Like XT_ProcessItem, but `hItem` is a read-handle to the item's data.
    Use this when you need to read content (xwf.Read(hItem, offset, n)).
    NOTE: both this and XT_ProcessItem fire for every item under 0x01 — the demo
    does its work in XT_ProcessItem, so this stays a stub. If you move work here,
    make XT_ProcessItem a stub (or dedup) so each item is handled exactly once."""
    return 0


def XT_ProcessSearchHit(iSize, nItemID, nRelOfs, nAbsOfs,
                        lpOptionalHitPtr, lpSearchTermID,
                        nLength, nCodePage, nFlags):
    """Called for each search hit when your X-Tension is invoked from a search."""
    return 0


def XT_Finalize(hVolume, hEvidence, nOpType, lpReserved):
    """Last per-volume callback. Summarize results here."""
    _log(f"done — processed {_state['processed']}, flagged {_state['flagged']}")
    return 0


def XT_Done(lpReserved):
    """Absolute last call before Python shuts down."""
    _log("XT_Done")
    return 0


# --- Per-item output helpers (shared by XT_ProcessItem / XT_ProcessItemEx) ---

def _record_hit(nItemID, hit_description):
    """Record a finding: Report Table entry + a Comments-column note."""
    cfg = _state["config"]
    if cfg.get("add_to_report_table", True):
        try:
            xwf.AddToReportTable(nItemID, REPORT_TABLE, 0)
        except Exception as e:
            _log(f"AddToReportTable failed for {nItemID}: {e}")
    if cfg.get("add_comment", True):
        try:
            xwf.AddComment(nItemID, f"[{NAME}] {hit_description}", COMMENT_APPEND)
        except Exception as e:
            _log(f"AddComment failed for {nItemID}: {e}")
