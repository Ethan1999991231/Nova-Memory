# NovaMemory UI Polish and Maintenance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add persistent appearance customization, in-app prompts, precise startup management, selectable rows, a smoother memory graph, and a Start Menu shortcut action to the existing native EXE.

**Architecture:** Keep the current single-file Win32/GDI+ architecture and extend the existing JSON config. Use app-drawn controls and modal cards for all prompts, standard Windows locations/APIs only for startup discovery and the current-user shortcut, and a 250ms memory sampler for the 60-second graph.

**Tech Stack:** C++17, Win32, GDI+, Shell COM (`IShellLink`/`IPersistFile`), existing PowerShell/MSVC build scripts.

---

## Files

- Modify `native/main.cpp`: config/palette, settings tabs, app-drawn prompts, maintenance lists, shortcut, and chart.
- Read/update `README.md`: document appearance persistence, Start Menu shortcut scope, and output executable.
- Do not add runtime dependencies or modify the old executable while it is running. Build the candidate as `outputs\NovaMemory-final.exe`.

## Tasks

### Task 1: Persistent appearance model

**Test first:** Add a small PowerShell source-contract check for JSON keys `theme`, `opacity`, and `accent`, valid bounds (theme 0–2, opacity 70–100, RGB 0–16777215), and load/save round-trip paths. Confirm it fails before implementation because the current config has none of these keys.

- [ ] Extend `Config`, `LoadConfig`, and `SaveConfig` with those three values and safe defaults.
- [ ] Replace fixed surface/accent constants with an applied palette; define three named palettes and derive accent hover/dark colors from the selected RGB value.
- [ ] Apply the loaded palette and alpha before first paint; keep secondary text/button contrast readable in the light theme.
- [ ] Run the source-contract check and compile `native\main.cpp` with the existing MSVC flags to a temporary candidate EXE.

### Task 2: Appearance settings and preview

**Test first:** Extend the source-contract check to assert all three themes, opacity bounds, RGB channel controls, preview application, and SaveConfig persistence. Verify it fails before adding the UI.

- [ ] Divide Settings into General and Appearance sections without changing the existing General control behavior.
- [ ] Add three theme choices, a 70–100% transparency slider, and three 0–255 RGB sliders with a live accent swatch.
- [ ] Preview draft appearance immediately; restore saved appearance when leaving without saving; persist drafts on Save.
- [ ] Verify slider hit-testing, live preview, save, and reload through the native UI.

### Task 3: In-app notices and confirmation cards

**Test first:** Assert there are no `MessageBoxW` calls or separate native code-prompt window, and that registry/process confirmations route through the in-app prompt state. Verify the current source fails those assertions.

- [ ] Keep brief success/failure feedback in the existing in-app toast style.
- [ ] Add an owner-drawn modal card for safe registry cleanup preview and process termination confirmation, with custom Cancel/Continue buttons and Escape/Enter handling.
- [ ] Convert startup permission failures and empty-scan/completion results to in-app notices.
- [ ] Remove the obsolete six-digit code window because the Deep Clean action will open Registry Editor instead of modifying the registry.
- [ ] Search `native\main.cpp` for `MessageBoxW` and native modal-window creation; expected: none for app prompts.

### Task 4: Registry editor action and Start Menu shortcut

**Test first:** Use a temporary-directory shortcut test and verify the shortcut target equals the running EXE path; verify no shortcut is written until the UI action is invoked.

- [ ] Change the Deep Clean button to launch `regedit.exe` directly; leave safe cleanup preview/backup/confirmation unchanged.
- [ ] Add a General Settings button that creates a NovaMemory `.lnk` under the current user's Start Menu Programs folder using Shell COM.
- [ ] Show success/failure in-app; do not add an HKCU Run entry, system-wide shortcut, or elevation request.
- [ ] Verify the generated shortcut's target and displayed name, then remove only the temporary test shortcut.

### Task 5: Process/startup checkboxes and startup coverage

**Test first:** Assert process rows render checkbox state from the selected-PID set and startup rows render enabled state; assert discovery includes HKCU/HKLM Run/RunOnce, 32/64-bit views, and both startup folders. Confirm the current source misses RunOnce.

- [ ] Draw a square checkbox at the right edge of each process row; preserve multi-select and batch termination behavior.
- [ ] Draw a square enabled-state checkbox at the right edge of each startup row; clicking it directly toggles that item and reports permission failure in-app.
- [ ] Read current-user/system Run and RunOnce keys in both registry views, plus current-user/common Startup folders; show source labels and preserve same-named entries from distinct sources.
- [ ] Verify the row checkbox hit areas, enabled/disabled visual states, and source labels without modifying real startup entries.

### Task 6: Smooth live memory chart

**Test first:** Assert a 240-point history, 250ms sampling interval, fractional physical-memory percentage, and curve drawing path; confirm the source currently has 60 integer points and a 1s timer.

- [ ] Store 240 floating-point samples over 60 seconds using used-physical-bytes / total-physical-bytes.
- [ ] Change the sampling timer to 250ms while preserving the integer headline percentage and auto-optimization cooldown.
- [ ] Draw the series with a smoothed GDI+ curve and retain the existing 60-second scale labels.
- [ ] Verify no flicker, no UI-thread blocking, and that the chart advances smoothly in the native UI.

### Task 7: Final verification and handoff

- [ ] Run the source-contract checks for config, prompts, startup coverage, and chart sampling.
- [ ] Build `outputs\NovaMemory-final.exe` with the existing MSVC include/library flags; expect exit code 0 and no compiler/linker errors.
- [ ] Launch the candidate and verify settings, toasts, checkboxes, theme preview, and chart visually; do not terminate processes or alter real startup entries during QA.
- [ ] Update `README.md` with current native EXE output and the current-user-only Start Menu shortcut behavior.
- [ ] Confirm the output candidate is a standalone EXE and no Python artifacts are required.
