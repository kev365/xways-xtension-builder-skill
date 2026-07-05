// =============================================================================
//  resource.h — control IDs for the my_xtension wrapper-template dialogs
//
//  Numbering convention:
//    100..199  dialog template + primary control IDs
//    200..299  per-X-Tension labels / extras
//
//  Every ID referenced by SettingsDlgProc / PopulateDialog / the .rc lives
//  here. Add IDs for any tool-specific controls you introduce.
// =============================================================================
#pragma once

// --- Dialog templates ------------------------------------------------------
#define IDD_SETTINGS                       100
#define IDD_ABOUT                          101

// --- Tool binary group -----------------------------------------------------
#define IDC_GROUP_TOOL                     110
#define IDC_LABEL_TOOL_BIN                 111
#define IDC_EDIT_TOOL_BIN                  112
#define IDC_BTN_BROWSE_TOOL                113
#define IDC_LABEL_TOOL_VERSION             114

// --- Input source group ----------------------------------------------------
#define IDC_GROUP_INPUT                    120
#define IDC_LABEL_SELECTED_COUNT           121   // prefix "Items to scan:"
#define IDC_LABEL_SELECTED_COUNT_NUM       122   // bold count "N files"
#define IDC_LABEL_MIN_SIZE                 123
#define IDC_EDIT_MIN_SIZE                  124
#define IDC_LABEL_MAX_SIZE                 125
#define IDC_EDIT_MAX_SIZE                  126
#define IDC_LABEL_EXTRA_ARGS               127
#define IDC_EDIT_EXTRA_ARGS                128

// --- Output handling group -------------------------------------------------
#define IDC_GROUP_OUTPUT                   160
#define IDC_LABEL_OUTPUT_DIR               161
#define IDC_EDIT_OUTPUT_DIR                162
#define IDC_BTN_BROWSE_OUTPUT              163
#define IDC_CHK_ADD_REPORT_TABLE           165   // BS_AUTO3STATE: none / table / table+comment
#define IDC_LABEL_TAG_THRESHOLD            167
#define IDC_EDIT_TAG_THRESHOLD             168
#define IDC_CHK_VERBOSE                    169

// --- Status group + action row ---------------------------------------------
#define IDC_GROUP_STATUS                   179   // wraps the status label + progress bar
#define IDC_LABEL_PROGRESS_STATUS          180
#define IDC_PROGRESS_RUN                   181
#define IDC_BTN_ABOUT                      182
#define IDC_BTN_OPEN_OUTPUT                183
#define IDC_BTN_RUN                        184   // DEFPUSHBUTTON — IDOK role
#define IDC_BTN_OPEN_CFG                   185

// --- About dialog ----------------------------------------------------------
#define IDC_ABOUT_TITLE                    190
#define IDC_ABOUT_DESC                     191
#define IDC_ABOUT_AUTHOR                   192
#define IDC_ABOUT_LABEL_AUTHOR_PREFIX      194   // "Author:" bold prefix
#define IDC_ABOUT_LINK_GITHUB              195
