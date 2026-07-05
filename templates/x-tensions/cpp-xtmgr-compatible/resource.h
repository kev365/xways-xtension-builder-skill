#pragma once

// Optional settings dialog. Used as both the standalone modal AND the
// manager-embedded tab (Option A retrofit, set in the descriptor).
//
// If your plugin doesn't need a settings dialog, you can leave this
// file alone and set tab_dialog_resource_id = 0 in the descriptor —
// the manager will render a placeholder tab with just the plugin's
// name and a Run hint.
#define IDD_SETTINGS                100

// Add your own IDC_* control IDs here as you grow the dialog.
