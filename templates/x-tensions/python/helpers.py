"""
Pure logic for the X-Tension, kept separate from the XT_* entry points so it is:
  - testable without X-Ways loaded, and
  - easy to port to C++ later if a hot path needs it.

Only import `xwf` inside functions that truly need XWF API calls — never at
module top level here, so this file is importable without X-Ways and unit
tests can stub the `xwf` module.

Return convention for `evaluate_item`: return a short human-readable string
describing the finding, or None if the item is not interesting. The caller
(xtension.py) handles Report Table / Comments writes based on that.
"""


def evaluate_item(nItemID, config):
    """Decide whether this item is a hit. Return a short reason string, or None.

    Example policy (replace with your own): flag any item whose logical size
    exceeds config['min_item_size_bytes'].
    """
    import xwf  # lazy so tests can stub it

    size = xwf.GetItemSize(nItemID)
    if size is None:
        return None

    threshold = config.get("min_item_size_bytes", 1_048_576)
    if size > threshold:
        name = xwf.GetItemName(nItemID) or "<unnamed>"
        return f"large item ({size:,} bytes): {name}"
    return None
