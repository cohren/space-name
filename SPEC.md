# SpaceName — Spec

A macOS menu-bar utility that shows a user-defined, colored name for the current desktop Space, centered on the menu bar. macOS doesn't let you rename Spaces; this puts the name where you'll see it.

Status: **v1 implemented** (2026-09-28).

## Goals

- See at a glance which Space you're on, by name and color.
- Name and color every Space from one menu, without switching to it first.
- Zero interference: never blocks clicks, never appears in the Dock or ⌘-Tab.

## Non-goals (v1)

- Mac App Store distribution (impossible — requires private APIs).
- Labels in Mission Control thumbnails (needs Dock injection + SIP disabled).
- Labels on full-screen app Spaces.
- iCloud sync, JSON import/export.
- Global hotkey for renaming.
- Per-app hide rules or label offset.

## Platform & distribution

- Deployment target: macOS 14+. Developed and tested on macOS 27, single external display, no notch.
- Native Swift and AppKit (overlay window, menu bar item, rename dialog). No third-party dependencies.
- Built locally from source. Signing is ad-hoc by default; set your own team in `Local.xcconfig` (see README). Structured so notarized DMG distribution is possible later without rework.
- Menu-bar-only app (`LSUIElement = YES`): no Dock icon, not in ⌘-Tab.
- Project: Xcode project **SpaceName**, generated from `project.yml` with XcodeGen.

## Space detection

- Uses private CoreGraphics/SkyLight APIs: `CGSMainConnectionID`, `CGSCopyManagedDisplaySpaces`, declared via `@_silgen_name`.
- `CGSCopyManagedDisplaySpaces` returns, per display: the display identifier, the current Space, and the ordered list of Spaces (each with `uuid`, `ManagedSpaceID`, and `type` — 0 = desktop, 4 = full-screen).
- Refresh triggers:
  - `NSWorkspace.activeSpaceDidChangeNotification`
  - `NSApplication.didChangeScreenParametersNotification` (displays added/removed/rearranged)
  - App launch.
- **Identity:** labels are keyed by Space **UUID** (the original desktop of a display reports an empty UUID; it's keyed `default:<display UUID>`), so a label follows its Space when Spaces are reordered in Mission Control. Deleting a Space orphans its label (kept in storage, never shown; no pruning in v1).
- Ordinal ("Desktop N") is computed from the Space's position among *desktop-type* Spaces on its display, matching Mission Control's numbering.

## Overlay label

- One borderless, transparent `NSPanel` per display, positioned at the horizontal center of that display's menu bar area.
- Window level above the menu bar (`.statusBar` + 1 or equivalent) so it draws on top of it; `ignoresMouseEvents = true` (fully click-through); `collectionBehavior` includes `.canJoinAllSpaces`, `.stationary`, `.ignoresCycle`, `.fullScreenNone`.
- Appearance:
  - Rounded pill (fully rounded ends), ~18pt tall, vertically centered in the menu bar (menu bar height read from `NSScreen.frame.maxY - visibleFrame.maxY`, not hard-coded).
  - Width fits the text + horizontal padding (~10pt each side).
  - Text: system font at menu bar size, bold.
  - Text color auto-chosen black/white: white when WCAG relative luminance < 0.3 (≥3:1, fine for bold text), else black. Pure max-contrast picked black on system blue/red/purple, which looked wrong.
- Unnamed Space: shows `Desktop N` on a neutral gray background.
- Full-screen Space (type 4) active on a display: that display's label is hidden.
- Space switch: label swaps instantly (the original ~150ms crossfade felt slow).
- Multi-display: each display with separate Spaces shows the label for its own current Space. Panels are created/destroyed as displays connect/disconnect. (Tested on a single display only in v1.)

## Menu bar item (editing UI)

A standard `NSStatusItem` on the right side of the menu bar. Icon: small SF Symbol (e.g. `rectangle.3.group` or `tag`). Menu contents:

```
Current: Email                      (disabled header, current Space name)
Rename This Space…                  (opens rename field)
Color ▸ [● ● ● ● ● ● ● ● ● ●]  Custom…
────────────────
All Spaces ▸
   Display: <display name>          (header, only shown if >1 display)
   1  Mail          ●  ▸  Rename…, Color ▸, Clear
   2  Code          ●  ▸  …
   3  Desktop 3     ○  ▸  …         (✓ marks current)
────────────────
✓ Launch at Login
Quit SpaceName
```

- **Rename:** an `NSAlert` with a text field, prefilled with the current name; Return saves, Esc cancels. Empty string = clear back to default.
- **Color presets:** ~10 swatches (e.g. red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, gray). Rendered as a custom menu item view with clickable circles.
- **Custom…:** opens `NSColorPanel`; live-updates the label as you pick.
- **All Spaces:** every desktop Space on every display, in Mission Control order, each with its own Rename/Color/Clear submenu — edit any Space without switching to it.
- Changes apply to the overlay immediately.

## Persistence

- `UserDefaults` (app's own domain), one dictionary: `labels: [spaceUUID: { name: String?, color: hex String? }]`.
- No sync, no export in v1.

## Launch at login

- `SMAppService.mainApp.register()`; enabled on first launch; toggle in the menu reflects `SMAppService.mainApp.status`.

## Permissions

- The app itself needs **no** TCC permissions (the private Space APIs and drawing over the menu bar don't require any).
- Verification scripts (below) may trigger one-time Accessibility (for keystroke-driven Space switching) and Screen Recording (for screenshots) prompts for the terminal.

## Edge cases

| Case | Behavior |
|---|---|
| Spaces reordered in Mission Control | Label follows the Space (UUID). "Desktop N" defaults renumber. |
| Space deleted | Its label is kept in storage, never shown. |
| New Space created | Shows `Desktop N` gray until named. |
| Full-screen app Space | Label hidden on that display. |
| Display connected/disconnected | Panels rebuilt; labels per display. |
| Menu bar auto-hide | Not in use on target machine; label may float over content when bar is hidden. Not handled in v1. |
| App menus/status items reaching center | Label draws on top but is click-through. Not handled further in v1. |
| Private API returns unexpected data (OS update) | Fail soft: hide overlay, show "Space detection unavailable" in menu; no crash. |
| Very long name | Truncate with ellipsis at ~40% of screen width. |

## Verification plan

1. `xcodebuild` Release build; copy to `/Applications`; launch.
2. Via `defaults write`, seed distinct names/colors for the first 3 Spaces.
3. Script Space switches with AppleScript Ctrl+→ / Ctrl+←; after each, `screencapture` the top strip of the display.
4. Inspect screenshots: correct name, color, contrast, centering, and pill appearance per Space; unnamed Space shows gray `Desktop N`.
5. Confirm click-through: click the menu bar under the label, confirm nothing is intercepted.
6. Confirm no Dock icon, launch-at-login registered.
7. Name the remaining Spaces via the menu.

## Code layout

```
SpaceName/
  main.swift                  app entry, notifications, launch at login
  CGSPrivate.swift            @_silgen_name declarations
  SpaceMonitor.swift          reads display/Space layout via the private API
  LabelStore.swift            UUID → {name, color}, UserDefaults-backed
  OverlayController.swift     one click-through panel per display
  LabelView.swift             the pill
  StatusMenuController.swift  NSStatusItem + menu, swatch row, rename dialog
  Color+Contrast.swift        hex <-> NSColor, luminance → text color
```
